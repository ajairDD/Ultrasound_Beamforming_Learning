function prep = prepare_fi_mvdr_input(filename,opts)
%PREPARE_FI_MVDR_INPUT Build delay-aligned receive data for FI MVDR.
%
% This helper performs ONLY the already validated front-end:
%   RF -> analytic signal -> Tx/Rx delay -> interpolation -> Rx aperture.
%
% OUTPUT SHAPES
%   prep.aligned_samples      [Nz, N_channels, N_waves] complex
%   prep.active_mask          [Nz, N_channels, N_waves] logical
%   prep.das_analytic         [Nz, N_waves] complex
%   prep.active_channel_count [Nz, N_waves]
%
% Conventional FI convention:
%   wave iw -> output scanline iw.
%
% The MVDR stage is deliberately separated so parameter sweeps can reuse
% the expensive delay/interpolation result instead of repeating it.

    if nargin < 1 || isempty(filename)
        filename = '../../data/L7_FI_TheGB.uff';
    end
    if nargin < 2 || isempty(opts)
        opts = struct();
    end

    opts = apply_defaults(opts);

    assert(exist(filename,'file') == 2,'File not found: %s',filename);
    assert(~isempty(which('uff.read_object')), ...
        'USTB / UFF reader was not found on the MATLAB path.');

    cd = uff.read_object(filename,'/channel_data');

    assert(abs(cd.modulation_frequency) < eps, ...
        'This teaching implementation currently expects RF input.');
    assert(isreal(cd.data), ...
        'This teaching implementation currently expects real RF data.');

    probe = cd.probe;
    sequence = cd.sequence;

    N_channels = cd.N_channels;
    N_waves = cd.N_waves;

    assert(N_channels == probe.N_elements, ...
        'N_channels does not match probe.N_elements.');

    source_x = zeros(N_waves,1);
    source_y = zeros(N_waves,1);

    for iw = 1:N_waves
        assert(sequence(iw).wavefront == uff.wavefront.spherical, ...
            'Wave %d is not spherical focused imaging.',iw);
        assert(sequence(iw).source.z > 0, ...
            'Wave %d does not have a positive-z focus.',iw);

        source_x(iw) = sequence(iw).source.x;
        source_y(iw) = sequence(iw).source.y;
    end

    assert(max(abs(source_y)) < 1e-9, ...
        'This implementation assumes a 2-D x-z imaging plane.');

    x_axis = source_x;
    z_axis = linspace(opts.z_min,opts.z_max,opts.n_z).';

    fs = cd.sampling_frequency;
    t0 = cd.initial_time;

    aligned_samples = complex(zeros( ...
        opts.n_z,N_channels,N_waves));

    active_mask = false(opts.n_z,N_channels,N_waves);
    das_analytic = complex(zeros(opts.n_z,N_waves));
    active_channel_count = zeros(opts.n_z,N_waves);

    for iw = 1:N_waves

        if opts.verbose && mod(iw-1,max(1,floor(N_waves/10))) == 0
            fprintf('Preparing aligned aperture wave %d / %d ...\n', ...
                iw,N_waves);
        end

        rf_wave = double(cd.data(:,:,iw,opts.frame_index));
        analytic_wave = analytic_signal_fft(rf_wave);

        x_line = x_axis(iw);

        for iz = 1:opts.n_z

            z_pixel = z_axis(iz);

            tau_tx = focused_tx_delay_spherical( ...
                sequence(iw),x_line,0,z_pixel);

            rx_distance = sqrt( ...
                (probe.x(:).' - x_line).^2 + ...
                (probe.y(:).' - 0).^2 + ...
                (probe.z(:).' - z_pixel).^2);

            tau_rx = rx_distance / cd.sound_speed;
            query_time = tau_tx + tau_rx;

            [focused_samples,valid] = ...
                sample_channels_linear_uniform( ...
                    analytic_wave,t0,fs,query_time);

            weights = receive_weights( ...
                probe.x(:).',x_line,z_pixel, ...
                opts.receive_aperture_mode, ...
                opts.receive_f_number);

            weights(~valid) = 0;
            active = weights > 0;

            aligned_samples(iz,:,iw) = focused_samples;
            active_mask(iz,:,iw) = active;

            active_channel_count(iz,iw) = nnz(active);

            das_analytic(iz,iw) = ...
                sum(focused_samples(active));
        end
    end

    prep = struct();

    prep.aligned_samples = aligned_samples;
    prep.active_mask = active_mask;

    prep.das_analytic = das_analytic;
    prep.das_envelope = abs(das_analytic);

    prep.active_channel_count = active_channel_count;

    prep.x_axis = x_axis;
    prep.z_axis = z_axis;

    prep.N_channels = N_channels;
    prep.N_waves = N_waves;

    prep.fs = fs;
    prep.initial_time = t0;
    prep.sound_speed = cd.sound_speed;

    prep.filename = filename;
    prep.options = opts;
end

function opts = apply_defaults(opts)

    defaults = struct( ...
        'z_min',5e-3, ...
        'z_max',45e-3, ...
        'n_z',256, ...
        'frame_index',1, ...
        'receive_aperture_mode','f_number', ...
        'receive_f_number',1.7, ...
        'verbose',false);

    names = fieldnames(defaults);

    for k = 1:numel(names)
        name = names{k};

        if ~isfield(opts,name) || isempty(opts.(name))
            opts.(name) = defaults.(name);
        end
    end
end

function tau_tx = focused_tx_delay_spherical(wave,x,y,z)

    sx = wave.source.x;
    sy = wave.source.y;
    sz = wave.source.z;

    d = sqrt((sx-x).^2 + (sy-y).^2 + (sz-z).^2);

    if z < sz
        signed_d = -d;
    else
        signed_d = d;
    end

    tau_tx = ...
        (signed_d + wave.source.distance) ...
        / wave.sound_speed ...
        - wave.delay;
end

function [values,valid] = sample_channels_linear_uniform( ...
    channel_data,t0,fs,query_time)

    N_samples = size(channel_data,1);
    N_channels = size(channel_data,2);

    u = (query_time-t0)*fs + 1;

    i0 = floor(u);
    alpha = u-i0;

    valid = i0 >= 1 & i0 < N_samples;

    values = complex(zeros(1,N_channels));

    ch = 1:N_channels;

    idx0 = sub2ind( ...
        size(channel_data),i0(valid),ch(valid));

    idx1 = sub2ind( ...
        size(channel_data),i0(valid)+1,ch(valid));

    values(valid) = ...
        (1-alpha(valid)).*channel_data(idx0) + ...
        alpha(valid).*channel_data(idx1);
end

function w = receive_weights( ...
    element_x,x_pixel,z_pixel,mode,f_number)

    switch lower(mode)

        case 'full'
            w = ones(size(element_x));

        case 'f_number'
            assert(isfinite(f_number) && f_number > 0, ...
                'receive_f_number must be positive.');

            aperture_width = z_pixel/f_number;
            half_width = aperture_width/2;

            w = double(abs(element_x-x_pixel) <= half_width);

            if ~any(w)
                [~,idx] = min(abs(element_x-x_pixel));
                w(idx) = 1;
            end

        otherwise
            error('Unknown receive_aperture_mode: %s',mode);
    end
end

function xa = analytic_signal_fft(x)

    N = size(x,1);
    X = fft(x,[],1);

    h = zeros(N,1);

    if mod(N,2) == 0
        h(1) = 1;
        h(N/2+1) = 1;
        h(2:N/2) = 2;
    else
        h(1) = 1;
        h(2:(N+1)/2) = 2;
    end

    xa = ifft(X.*h,[],1);
end
