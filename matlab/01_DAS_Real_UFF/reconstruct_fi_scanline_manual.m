function out = reconstruct_fi_scanline_manual(filename, opts, channel_data)
%RECONSTRUCT_FI_SCANLINE_MANUAL Manual conventional FI scanline DAS.
%
% This is the reusable Chapter-1 DAS CORE.
%
% USTB is used only to read the UFF object and metadata. The beamforming
% operations below are implemented explicitly in this repository:
%   - RF -> analytic signal
%   - focused spherical Tx delay
%   - geometric Rx delay
%   - fractional-sample linear interpolation
%   - receive-aperture selection
%   - coherent receive summation
%   - envelope and dB conversion
%
% INPUT
% -----
% filename : path to a UFF file
%
% opts : optional struct with fields
%   z_min                   [m], default 5e-3
%   z_max                   [m], default 45e-3
%   n_z                     default 1024
%   frame_index             default 1
%   receive_aperture_mode   'full' or 'f_number', default 'full'
%   receive_f_number        default 1.7
%   tx_time_offsets         [s], [] or one value per original Tx event;
%                           added to RF query time before interpolation.
%   display_dynamic_range_db default 60
%   verbose                 true/false, default false
%
% OUTPUT
% ------
% out.das_analytic          [z, scanline], complex
% out.envelope              [z, scanline], real
% out.image_db              [z, scanline], real
% out.x_axis                [scanline, 1], m
% out.z_axis                [z, 1], m
% out.active_channel_count  [z, scanline]
% out.N_channels
% out.probe_x_min / out.probe_x_max
% out.fs / out.initial_time / out.sound_speed
% out.n_out_of_range / out.n_requested
% out.phantom_points        [] if unavailable
%
% TIMING CONVENTION
% -----------------
% A common channel-data time axis is used:
%
%   t[n] = initial_time + (n-1)/fs
%
% Therefore sequence(i_wave).delay is included explicitly in tau_tx.
% Do not combine this with channel_data.time(i_wave), because that USTB
% helper already includes wave.delay.
%
% SCIENTIFIC SCOPE
% ----------------
% This first reusable implementation is intentionally limited to:
%   - conventional focused imaging;
%   - spherical virtual-source Tx model;
%   - RF input (modulation_frequency == 0);
%   - one focused Tx -> one output scanline.
%
% RTB is deliberately NOT implemented here.
% A third argument can supply an already-read uff.channel_data object.

    if nargin < 1 || isempty(filename)
        filename = '../../data/L7_FI_Verasonics_CIRS_points.uff';
    end

    if nargin < 2 || isempty(opts)
        opts = struct();
    end

    opts = apply_defaults(opts);

    assert(exist(filename, 'file') == 2, ...
        'File not found: %s', filename);

    assert(~isempty(which('uff.read_object')), ...
        ['USTB / UFF reader was not found on the MATLAB path. ' ...
         'Run addpath(genpath(''YOUR_USTB_PATH'')) first.']);

    %% 1. Read UFF
    if nargin < 3 || isempty(channel_data)
        channel_data = uff.read_object(filename, '/channel_data');
    end

    assert(opts.frame_index >= 1 && ...
           opts.frame_index <= channel_data.N_frames, ...
        'frame_index is outside the available frame range.');

    assert(abs(channel_data.modulation_frequency) < eps, ...
        ['This first teaching implementation is intentionally RF-only. ' ...
         'The file reports modulation_frequency = %.12g Hz.'], ...
         channel_data.modulation_frequency);

    assert(isreal(channel_data.data), ...
        ['The file reports RF (modulation_frequency == 0), but data is ' ...
         'complex. Inspect the file semantics before continuing.']);

    probe = channel_data.probe;
    sequence = channel_data.sequence;

    N_samples = channel_data.N_samples;
    N_channels = channel_data.N_channels;
    N_waves = channel_data.N_waves;

    tx_time_offsets = opts.tx_time_offsets;
    if isempty(tx_time_offsets)
        tx_time_offsets = zeros(N_waves,1);
    end
    assert(isnumeric(tx_time_offsets) && isreal(tx_time_offsets) && ...
        isvector(tx_time_offsets) && numel(tx_time_offsets) == N_waves && ...
        all(isfinite(tx_time_offsets(:))), ...
        'tx_time_offsets must contain one finite real offset [s] per Tx.');
    tx_time_offsets = double(tx_time_offsets(:));

    assert(N_channels == probe.N_elements, ...
        'N_channels does not match probe.N_elements.');

    %% 2. Confirm focused-imaging geometry
    source_x = zeros(N_waves,1);
    source_y = zeros(N_waves,1);
    source_z = zeros(N_waves,1);

    for iw = 1:N_waves
        assert(sequence(iw).wavefront == uff.wavefront.spherical, ...
            'Wave %d is not spherical. This core is for focused FI.', iw);

        assert(sequence(iw).source.z > 0, ...
            'Wave %d does not have a positive-z focused source.', iw);

        source_x(iw) = sequence(iw).source.x;
        source_y(iw) = sequence(iw).source.y;
        source_z(iw) = sequence(iw).source.z;
    end

    assert(max(abs(source_y)) < 1e-9, ...
        ['This implementation assumes a 2-D x-z imaging plane. ' ...
         'Non-zero source.y was detected.']);

    x_axis = source_x;
    z_axis = linspace(opts.z_min, opts.z_max, opts.n_z).';

    %% 3. Common acquisition-time axis
    fs = channel_data.sampling_frequency;
    t0 = channel_data.initial_time;

    if opts.verbose
        fprintf('============================================================\n');
        fprintf(' Manual conventional FI-DAS core\n');
        fprintf('============================================================\n');
        fprintf('File                  : %s\n', filename);
        fprintf('Data size [T C W F]   : [%d %d %d %d]\n', ...
            size(channel_data.data,1), ...
            size(channel_data.data,2), ...
            size(channel_data.data,3), ...
            size(channel_data.data,4));
        fprintf('fs                    : %.3f MHz\n', fs/1e6);
        fprintf('initial_time          : %.6f us\n', t0*1e6);
        fprintf('sound speed           : %.3f m/s\n', ...
            channel_data.sound_speed);
        fprintf('N scanlines / waves   : %d\n', N_waves);
        fprintf('receive aperture mode : %s\n', ...
            opts.receive_aperture_mode);
        if strcmpi(opts.receive_aperture_mode,'f_number')
            fprintf('receive F-number      : %.3f\n', ...
                opts.receive_f_number);
        end
        fprintf('\n');
    end

    %% 4. Allocate
    das_analytic = complex(zeros(opts.n_z, N_waves));
    active_channel_count = zeros(opts.n_z, N_waves);

    n_out_of_range = 0;
    n_requested = 0;

    %% 5. Beamform
    for iw = 1:N_waves

        if opts.verbose && ...
                mod(iw-1, max(1,floor(N_waves/10))) == 0
            fprintf('Beamforming wave %d / %d ...\n', iw, N_waves);
        end

        % Shape: [sample, receive_channel]
        rf_wave = double( ...
            channel_data.data(:,:,iw,opts.frame_index));

        analytic_wave = analytic_signal_fft(rf_wave);

        x_line = x_axis(iw);

        for iz = 1:opts.n_z
            z_pixel = z_axis(iz);

            % Focused spherical Tx delay.
            tau_tx = focused_tx_delay_spherical( ...
                sequence(iw), x_line, 0, z_pixel);
            tau_tx = tau_tx + tx_time_offsets(iw);

            % Rx delay to every receive element.
            rx_distance = sqrt( ...
                (probe.x(:).' - x_line).^2 + ...
                (probe.y(:).' - 0).^2 + ...
                (probe.z(:).' - z_pixel).^2);

            tau_rx = rx_distance / channel_data.sound_speed;

            tau_total = tau_tx + tau_rx;

            [focused_samples, valid] = ...
                sample_channels_linear_uniform( ...
                    analytic_wave, t0, fs, tau_total);

            weights = receive_weights( ...
                probe.x(:).', ...
                x_line, ...
                z_pixel, ...
                opts.receive_aperture_mode, ...
                opts.receive_f_number);

            weights(~valid) = 0;

            active_channel_count(iz,iw) = nnz(weights);
            n_out_of_range = n_out_of_range + nnz(~valid);
            n_requested = n_requested + N_channels;

            % Deliberately not normalized by sum(weights), matching the
            % already validated baseline convention.
            das_analytic(iz,iw) = ...
                sum(weights .* focused_samples);
        end
    end

    %% 6. Envelope / dB
    env = abs(das_analytic);

    peak_value = max(env(:));
    assert(peak_value > 0, 'Beamformed image is all zero.');

    image_db = 20*log10(env / peak_value + eps);
    image_db( ...
        image_db < -opts.display_dynamic_range_db) = ...
        -opts.display_dynamic_range_db;

    %% 7. Return explicit outputs
    out = struct();

    out.das_analytic = das_analytic;
    out.envelope = env;
    out.image_db = image_db;

    out.x_axis = x_axis;
    out.z_axis = z_axis;

    out.active_channel_count = active_channel_count;

    out.N_channels = N_channels;
    out.N_waves = N_waves;

    out.probe_x_min = min(probe.x(:));
    out.probe_x_max = max(probe.x(:));

    out.fs = fs;
    out.initial_time = t0;
    out.sound_speed = channel_data.sound_speed;

    out.n_out_of_range = n_out_of_range;
    out.n_requested = n_requested;

    out.source_x = source_x;
    out.source_z = source_z;
    out.tx_time_offsets = tx_time_offsets;

    out.phantom_points = [];
    if isprop(channel_data,'phantom') && ...
            ~isempty(channel_data.phantom) && ...
            isprop(channel_data.phantom,'points') && ...
            ~isempty(channel_data.phantom.points)
        out.phantom_points = channel_data.phantom.points;
    end
end

%% =========================================================================
% Local functions
% =========================================================================

function opts = apply_defaults(opts)

    defaults = struct( ...
        'z_min', 5e-3, ...
        'z_max', 45e-3, ...
        'n_z', 1024, ...
        'frame_index', 1, ...
        'receive_aperture_mode', 'full', ...
        'receive_f_number', 1.7, ...
        'tx_time_offsets', [], ...
        'display_dynamic_range_db', 60, ...
        'verbose', false);

    names = fieldnames(defaults);

    for k = 1:numel(names)
        name = names{k};
        if ~isfield(opts,name) || isempty(opts.(name))
            opts.(name) = defaults.(name);
        end
    end

    assert(opts.z_max > opts.z_min, ...
        'z_max must be greater than z_min.');

    assert(opts.n_z >= 2 && opts.n_z == round(opts.n_z), ...
        'n_z must be an integer >= 2.');
end

function tau_tx = focused_tx_delay_spherical(wave, x, y, z)
%FOCUSED_TX_DELAY_SPHERICAL Focused-wave Tx delay on USTB convention.
%
% USTB's focused spherical reference uses source.distance:
%
%   source.distance = norm(source.xyz)
%
% For a source in front of the probe, distance from source to candidate
% pixel is signed negative before the focus and positive after the focus.
%
% The UFF data used here has already been validated against USTB's own DAS
% with this timing convention.

    sx = wave.source.x;
    sy = wave.source.y;
    sz = wave.source.z;

    d = sqrt((sx-x).^2 + ...
             (sy-y).^2 + ...
             (sz-z).^2);

    if z < sz
        signed_d = -d;
    else
        signed_d = d;
    end

    source_reference_distance = wave.source.distance;

    tau_tx = ...
        (signed_d + source_reference_distance) ...
        / wave.sound_speed ...
        - wave.delay;
end

function [values, valid] = sample_channels_linear_uniform( ...
    channel_data, t0, fs, query_time)
%SAMPLE_CHANNELS_LINEAR_UNIFORM Linear interpolation.
%
% channel_data: [sample, receive_channel]
% query_time:   [1, receive_channel]
% values:       [1, receive_channel]

    N_samples = size(channel_data,1);
    N_channels = size(channel_data,2);

    assert(numel(query_time) == N_channels, ...
        'query_time must contain one value per receive channel.');

    u = (query_time - t0) * fs + 1;

    i0 = floor(u);
    alpha = u - i0;

    valid = (i0 >= 1) & (i0 < N_samples);
    values = complex(zeros(1,N_channels));

    ch = 1:N_channels;

    idx0 = sub2ind( ...
        size(channel_data), i0(valid), ch(valid));

    idx1 = sub2ind( ...
        size(channel_data), i0(valid)+1, ch(valid));

    values(valid) = ...
        (1-alpha(valid)).*channel_data(idx0) + ...
        alpha(valid).*channel_data(idx1);
end

function w = receive_weights( ...
    element_x, x_pixel, z_pixel, mode, f_number)
%RECEIVE_WEIGHTS Receive-aperture selection.
%
% full:
%   all receive elements active.
%
% f_number:
%   dynamic boxcar aperture
%
%       D(z) = z / F#
%
%   centered on the current scanline x position.

    switch lower(mode)
        case 'full'
            w = ones(size(element_x));

        case 'f_number'
            assert(isfinite(f_number) && f_number > 0, ...
                'receive_f_number must be positive and finite.');

            aperture_width = z_pixel / f_number;
            half_width = aperture_width / 2;

            w = double( ...
                abs(element_x - x_pixel) <= half_width);

            if ~any(w)
                [~,idx] = min(abs(element_x - x_pixel));
                w(idx) = 1;
            end

        otherwise
            error('Unknown receive_aperture_mode: %s', mode);
    end
end

function xa = analytic_signal_fft(x)
%ANALYTIC_SIGNAL_FFT Analytic signal along time dimension.
%
% x shape: [time, channel]

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

    xa = ifft(X .* h,[],1);
end
