function out = reconstruct_fi_mvdr_manual(filename,opts)
%RECONSTRUCT_FI_MVDR_MANUAL Manual receive-domain MVDR/Capon beamforming.
%
% Chapter 3 teaching core for conventional focused imaging.
%
% DATA FLOW FOR EACH PIXEL
% ------------------------
% raw RF
%   -> same Tx/Rx delay model as Chapter 1
%   -> fractional interpolation
%   -> active receive aperture s = [s1 ... sM]
%   -> ordinary DAS = sum(s)
%   -> overlapping spatial subarrays
%   -> sample covariance R
%   -> diagonal loading
%   -> MVDR weights
%   -> average subarray outputs
%
% After delay alignment, the desired focal signal has steering vector
%
%   a = ones(L,1)
%
% and the MVDR weights solve
%
%   min_w  w^H R w
%   s.t.   w^H a = 1
%
% giving
%
%   w = R^{-1}a / (a^H R^{-1}a).
%
% SPATIAL SMOOTHING
% -----------------
% A single pixel provides only one M-channel aperture snapshot. To estimate
% a covariance matrix more robustly, the active aperture is split into
% overlapping length-L subarrays:
%
%   X = [x_1, x_2, ... , x_P],  P = M-L+1
%
% and
%
%   R = X*X^H / P.
%
% DIAGONAL LOADING
% ----------------
% The loaded covariance is
%
%   R_loaded = R + delta * trace(R)/L * I
%
% where delta = opts.diagonal_loading.
%
% AMPLITUDE CONVENTION
% --------------------
% MVDR has unit gain for the desired steering vector. A perfectly coherent
% aligned aperture with per-channel amplitude A therefore produces A before
% scaling, whereas DAS produces M*A. For direct common-reference comparison
% with DAS, this teaching implementation multiplies the averaged MVDR
% subarray output by M.
%
% INPUT
% -----
% filename : UFF file path
%
% opts fields
%   z_min                    [m], default 5e-3
%   z_max                    [m], default 45e-3
%   n_z                      default 256
%   frame_index              default 1
%   receive_aperture_mode    'full' or 'f_number', default 'f_number'
%   receive_f_number         default 1.7
%   subarray_fraction        L/M, default 0.5
%   diagonal_loading         delta, default 0.01
%   forward_backward         logical, default false
%   display_dynamic_range_db default 60
%   verbose                  true/false, default false
%
% OUTPUT
% ------
% out.das_analytic           [z,scanline] complex
% out.mvdr_analytic          [z,scanline] complex
% out.das_envelope
% out.mvdr_envelope
% out.das_db
% out.mvdr_db_self           self-normalized MVDR image
% out.mvdr_db_common         MVDR normalized to DAS global peak
% out.active_channel_count
% out.subarray_length_map
% out.x_axis
% out.z_axis
%
% SCIENTIFIC SCOPE
% ----------------
% This is receive-domain MVDR on conventional FI.
%
% Intentionally excluded from the main teaching core:
%   - axial/temporal covariance averaging;
%   - eigenspace projection;
%   - robust steering-vector optimization;
%   - transmit-domain MV;
%   - RTB cross-transmit MV.
%
% Those are discussed as extensions after the core algorithm is understood.

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

    % Linear-array / uniform-pitch check.
    px = probe.x(:);
    assert(max(abs(probe.y(:)-probe.y(1))) < 1e-12, ...
        'This teaching core assumes a 1-D linear array.');
    assert(max(abs(probe.z(:)-probe.z(1))) < 1e-12, ...
        'This teaching core assumes a 1-D linear array.');

    dp = diff(px);
    assert(max(abs(dp-median(dp))) < 1e-8, ...
        'This teaching core assumes approximately uniform element pitch.');

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
    mvdr_analytic = complex(zeros(opts.n_z,N_waves));

    active_channel_count = zeros(opts.n_z,N_waves);
    subarray_length_map = zeros(opts.n_z,N_waves);

    %% 4. Pixel-by-pixel DAS + MVDR
    for iw = 1:N_waves

        if opts.verbose && ...
                mod(iw-1,max(1,floor(N_waves/10))) == 0
            fprintf('MVDR reconstruction wave %d / %d ...\n',iw,N_waves);
        end

        rf_wave = double(cd.data(:,:,iw,opts.frame_index));

        % Preserve phase intentionally.
        analytic_wave = analytic_signal_fft(rf_wave);

        x_line = x_axis(iw);

        for iz = 1:opts.n_z

            z_pixel = z_axis(iz);

            % Same focused Tx delay as Chapter 1.
            tau_tx = focused_tx_delay_spherical( ...
                sequence(iw),x_line,0,z_pixel);

            % One receive delay per array element.
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

            active_idx = find(weights > 0);
            M = numel(active_idx);

            active_channel_count(iz,iw) = M;

            if M == 0
                continue;
            end

            % Spatial smoothing assumes neighboring entries represent
            % neighboring physical elements.
            if M > 1
                assert(all(diff(active_idx) == 1), ...
                    ['Active receive aperture is not contiguous at ' ...
                     'z index %d, wave %d.'],iz,iw);
            end

            s = focused_samples(active_idx);

            % Ordinary DAS baseline.
            das_value = sum(s);
            das_analytic(iz,iw) = das_value;

            if M < 3
                % Not enough aperture for a meaningful adaptive covariance.
                mvdr_analytic(iz,iw) = das_value;
                subarray_length_map(iz,iw) = M;
                continue;
            end

            L = floor(opts.subarray_fraction*M);
            L = max(2,L);
            L = min(L,M-1);

            subarray_length_map(iz,iw) = L;

            mvdr_analytic(iz,iw) = mvdr_pixel( ...
                s,L,opts.diagonal_loading,opts.forward_backward);
        end
    end

    %% 5. Display products
    das_env = abs(das_analytic);
    mvdr_env = abs(mvdr_analytic);

    das_peak = max(das_env(:));
    mvdr_peak = max(mvdr_env(:));

    assert(das_peak > 0,'DAS image is all zero.');
    assert(mvdr_peak > 0,'MVDR image is all zero.');

    das_db = to_db( ...
        das_env,das_peak,opts.display_dynamic_range_db);

    mvdr_db_self = to_db( ...
        mvdr_env,mvdr_peak,opts.display_dynamic_range_db);

    mvdr_db_common = to_db( ...
        mvdr_env,das_peak,opts.display_dynamic_range_db);

    %% 6. Return
    out = struct();

    out.das_analytic = das_analytic;
    out.mvdr_analytic = mvdr_analytic;

    out.das_envelope = das_env;
    out.mvdr_envelope = mvdr_env;

    out.das_db = das_db;
    out.mvdr_db_self = mvdr_db_self;
    out.mvdr_db_common = mvdr_db_common;

    out.active_channel_count = active_channel_count;
    out.subarray_length_map = subarray_length_map;

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
% Local MVDR core
% =========================================================================

function y = mvdr_pixel(s,L,diagonal_loading,do_forward_backward)

    M = numel(s);
    P = M-L+1;

    assert(P >= 2, ...
        'Need at least two overlapping subarrays.');

    % X shape = [L, P].
    starts = 1:P;
    index_matrix = (0:L-1).' + starts;
    X = s(index_matrix);

    % Spatially smoothed covariance.
    R = (X*X')/P;

    if do_forward_backward
        J = fliplr(eye(L));
        R = 0.5*(R + J*conj(R)*J);
    end

    mean_power = real(trace(R))/L;

    if ~(isfinite(mean_power) && mean_power > 0)
        y = sum(s);
        return;
    end

    R_loaded = ...
        R + ...
        diagonal_loading*mean_power*eye(L);

    a = ones(L,1);

    % Solve instead of explicitly forming inv(R).
    Ria = R_loaded\a;

    denom = a'*Ria;

    if ~(isfinite(real(denom)) && isfinite(imag(denom))) || ...
            abs(denom) < eps
        y = sum(s);
        return;
    end

    w = Ria/denom;

    % Distortionless-constraint numerical check.
    constraint_error = abs(w'*a-1);

    assert(constraint_error < 1e-8, ...
        'MVDR distortionless constraint failed: %.3e',constraint_error);

    % Average the overlapping subarray estimates.
    subarray_output = w'*X;
    y_unit_gain = mean(subarray_output);

    % Match coherent DAS amplitude convention:
    % perfectly aligned A*ones(1,M) -> M*A.
    y = M*y_unit_gain;
end

%% =========================================================================
% Shared teaching helpers
% =========================================================================

function opts = apply_defaults(opts)

    defaults = struct( ...
        'z_min',5e-3, ...
        'z_max',45e-3, ...
        'n_z',256, ...
        'frame_index',1, ...
        'receive_aperture_mode','f_number', ...
        'receive_f_number',1.7, ...
        'subarray_fraction',0.5, ...
        'diagonal_loading',0.01, ...
        'forward_backward',false, ...
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

    assert(opts.receive_f_number > 0, ...
        'receive_f_number must be positive.');

    assert(opts.subarray_fraction > 0 && ...
           opts.subarray_fraction < 1, ...
        'subarray_fraction must lie strictly between 0 and 1.');

    assert(opts.diagonal_loading > 0 && ...
           isfinite(opts.diagonal_loading), ...
        'diagonal_loading must be positive and finite.');

    assert(islogical(opts.forward_backward) || ...
           ismember(opts.forward_backward,[0 1]), ...
        'forward_backward must be logical.');

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
