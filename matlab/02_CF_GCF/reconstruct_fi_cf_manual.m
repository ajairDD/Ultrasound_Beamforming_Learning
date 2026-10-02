function out = reconstruct_fi_cf_manual(filename,opts)
%RECONSTRUCT_FI_CF_MANUAL Manual receive-domain coherence-factor imaging.
%
% Chapter 2 teaching core.
%
% For every conventional focused-imaging pixel:
%
%   1) compute the SAME Tx/Rx delays as Chapter 1;
%   2) linearly interpolate the analytic RF on each receive channel;
%   3) apply the receive aperture;
%   4) form the ordinary DAS coherent sum;
%   5) compute receive-domain Coherence Factor (CF);
%   6) multiply the complex DAS pixel by CF.
%
% The CF definition used here is
%
%   CF = |sum_m s_m|^2 / (M * sum_m |s_m|^2)
%
% where s_m are the delay-aligned ACTIVE receive-channel samples and M is
% the number of active channels for that pixel.
%
% INPUT
% -----
% filename : UFF file path
%
% opts fields
%   z_min                    [m], default 5e-3
%   z_max                    [m], default 45e-3
%   n_z                      default 512
%   frame_index              default 1
%   receive_aperture_mode    'full' or 'f_number', default 'f_number'
%   receive_f_number         default 1.7
%   display_dynamic_range_db default 60
%   verbose                  true/false, default false
%
% OUTPUT
% ------
% out.das_analytic           [z, scanline], complex
% out.das_envelope           [z, scanline]
% out.das_db                 [z, scanline]
%
% out.cf_map                 [z, scanline], real, nominally [0,1]
%
% out.cf_analytic            [z, scanline], complex
% out.cf_envelope            [z, scanline]
% out.cf_db_self             [z, scanline], each CF image normalized to its peak
% out.cf_db_common           [z, scanline], normalized to DAS peak
%
% out.active_channel_count   [z, scanline]
% out.x_axis                 [scanline,1], m
% out.z_axis                 [z,1], m
%
% SCIENTIFIC SCOPE
% ----------------
% This is RECEIVE-DOMAIN CF on conventional FI.
%
% It intentionally does NOT include:
%   - RTB transmit-domain coherence;
%   - GCF;
%   - SLSC / DMAS / MVDR;
%   - non-binary receive apodization.
%
% The receive aperture is currently boxcar/full, matching Chapter 1.

    if nargin < 1 || isempty(filename)
        filename = '../../data/L7_FI_TheGB.uff';
    end

    if nargin < 2 || isempty(opts)
        opts = struct();
    end

    opts = apply_defaults(opts);

    assert(exist(filename,'file') == 2, ...
        'File not found: %s',filename);

    assert(~isempty(which('uff.read_object')), ...
        ['USTB / UFF reader was not found on the MATLAB path. ' ...
         'Run addpath(genpath(''YOUR_USTB_PATH'')) first.']);

    %% 1. Read UFF
    cd = uff.read_object(filename,'/channel_data');

    assert(opts.frame_index >= 1 && ...
           opts.frame_index <= cd.N_frames, ...
        'frame_index is outside the available frame range.');

    assert(abs(cd.modulation_frequency) < eps, ...
        ['This teaching implementation is intentionally RF-only. ' ...
         'modulation_frequency = %.12g Hz.'], ...
        cd.modulation_frequency);

    assert(isreal(cd.data), ...
        'This teaching implementation currently expects real RF data.');

    probe = cd.probe;
    sequence = cd.sequence;

    N_channels = cd.N_channels;
    N_waves = cd.N_waves;

    assert(N_channels == probe.N_elements, ...
        'N_channels does not match probe.N_elements.');

    %% 2. Confirm conventional focused-imaging geometry
    source_x = zeros(N_waves,1);
    source_y = zeros(N_waves,1);
    source_z = zeros(N_waves,1);

    for iw = 1:N_waves

        assert(sequence(iw).wavefront == uff.wavefront.spherical, ...
            'Wave %d is not spherical focused imaging.',iw);

        assert(sequence(iw).source.z > 0, ...
            'Wave %d does not have a positive-z focused source.',iw);

        source_x(iw) = sequence(iw).source.x;
        source_y(iw) = sequence(iw).source.y;
        source_z(iw) = sequence(iw).source.z;
    end

    assert(max(abs(source_y)) < 1e-9, ...
        'This teaching implementation assumes a 2-D x-z imaging plane.');

    x_axis = source_x;
    z_axis = linspace(opts.z_min,opts.z_max,opts.n_z).';

    fs = cd.sampling_frequency;
    t0 = cd.initial_time;

    %% 3. Allocate outputs
    das_analytic = complex(zeros(opts.n_z,N_waves));
    cf_map = zeros(opts.n_z,N_waves);
    active_channel_count = zeros(opts.n_z,N_waves);

    %% 4. Pixel-by-pixel receive-domain CF
    for iw = 1:N_waves

        if opts.verbose && ...
                mod(iw-1,max(1,floor(N_waves/10))) == 0
            fprintf('CF reconstruction wave %d / %d ...\n',iw,N_waves);
        end

        % [sample, receive_channel]
        rf_wave = double(cd.data(:,:,iw,opts.frame_index));

        % Keep phase: CF must operate on complex aligned samples.
        analytic_wave = analytic_signal_fft(rf_wave);

        x_line = x_axis(iw);

        for iz = 1:opts.n_z

            z_pixel = z_axis(iz);

            % Same conventional-FI Tx model as Chapter 1.
            tau_tx = focused_tx_delay_spherical( ...
                sequence(iw),x_line,0,z_pixel);

            % One Rx delay per receive element.
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
                probe.x(:).', ...
                x_line, ...
                z_pixel, ...
                opts.receive_aperture_mode, ...
                opts.receive_f_number);

            weights(~valid) = 0;

            active = weights > 0;
            M = nnz(active);

            active_channel_count(iz,iw) = M;

            if M == 0
                das_analytic(iz,iw) = 0;
                cf_map(iz,iw) = 0;
                continue;
            end

            % Because Chapter 2 currently uses only binary boxcar/full
            % receive weights, the aligned active aperture vector is simply:
            s = focused_samples(active);

            coherent_sum = sum(s);
            channel_energy = sum(abs(s).^2);

            das_analytic(iz,iw) = coherent_sum;

            if channel_energy <= 0
                cf_value = 0;
            else
                cf_value = ...
                    abs(coherent_sum).^2 / ...
                    (M*channel_energy);
            end

            % Cauchy-Schwarz gives 0 <= CF <= 1 mathematically.
            % Allow tiny floating-point overshoot only.
            assert(cf_value >= -1e-12 && cf_value <= 1+1e-10, ...
                'CF outside expected range at z index %d, wave %d: %.12g', ...
                iz,iw,cf_value);

            cf_map(iz,iw) = min(max(real(cf_value),0),1);
        end
    end

    %% 5. CF weighting
    cf_analytic = cf_map .* das_analytic;

    das_env = abs(das_analytic);
    cf_env = abs(cf_analytic);

    das_peak = max(das_env(:));
    cf_peak = max(cf_env(:));

    assert(das_peak > 0,'DAS image is all zero.');
    assert(cf_peak > 0,'CF-weighted image is all zero.');

    das_db = to_db(das_env,das_peak,opts.display_dynamic_range_db);

    % Self-normalized: morphology / apparent PSF.
    cf_db_self = to_db( ...
        cf_env,cf_peak,opts.display_dynamic_range_db);

    % Common DAS reference: shows real suppression introduced by CF.
    cf_db_common = to_db( ...
        cf_env,das_peak,opts.display_dynamic_range_db);

    %% 6. Return
    out = struct();

    out.das_analytic = das_analytic;
    out.das_envelope = das_env;
    out.das_db = das_db;

    out.cf_map = cf_map;

    out.cf_analytic = cf_analytic;
    out.cf_envelope = cf_env;
    out.cf_db_self = cf_db_self;
    out.cf_db_common = cf_db_common;

    out.active_channel_count = active_channel_count;

    out.x_axis = x_axis;
    out.z_axis = z_axis;

    out.N_channels = N_channels;
    out.N_waves = N_waves;

    out.fs = fs;
    out.initial_time = t0;
    out.sound_speed = cd.sound_speed;

    out.source_x = source_x;
    out.source_z = source_z;

    out.options = opts;
end

%% =========================================================================
% Local helpers
% =========================================================================

function opts = apply_defaults(opts)

    defaults = struct( ...
        'z_min',5e-3, ...
        'z_max',45e-3, ...
        'n_z',512, ...
        'frame_index',1, ...
        'receive_aperture_mode','f_number', ...
        'receive_f_number',1.7, ...
        'display_dynamic_range_db',60, ...
        'verbose',false);

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

    assert(any(strcmpi(opts.receive_aperture_mode,{'full','f_number'})), ...
        'receive_aperture_mode must be full or f_number.');
end

function tau_tx = focused_tx_delay_spherical(wave,x,y,z)

    sx = wave.source.x;
    sy = wave.source.y;
    sz = wave.source.z;

    d = sqrt( ...
        (sx-x).^2 + ...
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

function [values,valid] = sample_channels_linear_uniform( ...
    channel_data,t0,fs,query_time)

    N_samples = size(channel_data,1);
    N_channels = size(channel_data,2);

    assert(numel(query_time) == N_channels, ...
        'query_time must contain one value per receive channel.');

    u = (query_time-t0)*fs + 1;

    i0 = floor(u);
    alpha = u-i0;

    valid = i0 >= 1 & i0 < N_samples;

    values = complex(zeros(1,N_channels));

    ch = 1:N_channels;

    idx0 = sub2ind( ...
        size(channel_data), ...
        i0(valid), ...
        ch(valid));

    idx1 = sub2ind( ...
        size(channel_data), ...
        i0(valid)+1, ...
        ch(valid));

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
                'receive_f_number must be positive and finite.');

            aperture_width = z_pixel/f_number;
            half_width = aperture_width/2;

            w = double( ...
                abs(element_x-x_pixel) <= half_width);

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

function db = to_db(env,reference_peak,dynamic_range)

    db = 20*log10(env/(reference_peak+eps)+eps);

    db(db < -dynamic_range) = -dynamic_range;
    db(db > 0) = 0;
end
