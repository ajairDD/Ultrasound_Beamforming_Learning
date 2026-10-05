function out = reconstruct_fi_rtb_mvdr_manual(filename,opts)
%RECONSTRUCT_FI_RTB_MVDR_MANUAL Manual RTB-DAS and RTB + Rx-MVDR.
%
% PURPOSE
% -------
% Compare two reconstructions on the SAME RTB grid and with the SAME
% transmit model:
%
%   RTB-DAS:
%       per Tx/pixel delayed Rx aperture -> equal-weight sum
%
%   RTB-MVDR:
%       per Tx/pixel delayed Rx aperture
%       -> spatial + axial covariance estimation
%       -> MVDR receive weights
%       -> complex weighted sum
%
% Both branches then use IDENTICAL Tx apodization and coherent
% cross-transmit combination.
%
% This isolates the effect of receive-domain MVDR from the effect of RTB.
%
% DATA FLOW FOR EACH TX / PIXEL
% -----------------------------
% RF
%   -> RTB Tx delay
%   -> Rx delay
%   -> complex interpolation
%   -> active receive aperture
%      |-> DAS sum
%      |-> MVDR covariance / weights / weighted sum
%   -> same Tx weight
%   -> coherent accumulation across Tx
%
% DEFAULTS
% --------
% RTB:
%   x_upsample              4
%   tx_delay_model          'blended'
%   tx_f_number             2
%   tx_min_aperture         3 mm
%   tx_window               'tukey25'
%   rx_f_number             1.7
%
% MVDR:
%   subarray_fraction       0.5
%   diagonal_loading        0.01
%   axial_averaging_lambda  1.5
%   forward_backward        false
%
% ROI OPTIONS
% -----------
%   x_min / x_max can restrict the lateral grid for fast point-target tests.
%   Full-frame RTB+MVDR is computationally expensive in this teaching code.
%
% OUTPUT
% ------
% out.rtb_das_analytic       [z,x] complex
% out.rtb_mvdr_analytic      [z,x] complex
% out.rtb_das_envelope
% out.rtb_mvdr_envelope
% out.rtb_das_db
% out.rtb_mvdr_db_common     normalized to RTB-DAS peak
% out.rtb_mvdr_db_self       self-normalized
% out.x_axis / out.z_axis
% out.tx_weight_sum
% out.active_tx_count
% out.options
%
% SCIENTIFIC SCOPE
% ----------------
% - 2-D linear-array focused imaging only
% - real RF input -> analytic signal internally
% - receive-domain MVDR only
% - spatial smoothing + optional axial covariance averaging
% - MVDR is applied before cross-Tx coherent RTB compounding
%
% The code intentionally prioritizes transparency over speed.

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

    %% 1. Read / validate UFF
    cd = uff.read_object(filename,'/channel_data');

    assert(opts.frame_index >= 1 && ...
           opts.frame_index <= cd.N_frames, ...
        'frame_index is outside the available frame range.');

    assert(abs(cd.modulation_frequency) < eps, ...
        ['This teaching implementation currently expects RF input. ' ...
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

    % 1-D linear array / approximately uniform pitch.
    px = probe.x(:);
    assert(max(abs(probe.y(:)-probe.y(1))) < 1e-12, ...
        'This teaching core assumes a 1-D linear array.');
    assert(max(abs(probe.z(:)-probe.z(1))) < 1e-12, ...
        'This teaching core assumes a 1-D linear array.');

    dp = diff(px);
    assert(max(abs(dp-median(dp))) < 1e-8, ...
        'This teaching core assumes approximately uniform element pitch.');

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
        'This implementation assumes a 2-D x-z imaging plane.');

    %% 2. Reconstruction grid
    if isempty(opts.n_x)
        N_x = N_waves*opts.x_upsample;
    else
        N_x = opts.n_x;
    end

    x_lo = min(source_x);
    x_hi = max(source_x);

    if ~isempty(opts.x_min)
        x_lo = opts.x_min;
    end
    if ~isempty(opts.x_max)
        x_hi = opts.x_max;
    end

    assert(x_hi > x_lo, ...
        'x_max must be greater than x_min.');

    assert(x_lo >= min(source_x)-1e-12 && ...
           x_hi <= max(source_x)+1e-12, ...
        ['Requested RTB x ROI must lie inside focused-Tx span ' ...
         '[%.3f, %.3f] mm.'], ...
        min(source_x)*1e3,max(source_x)*1e3);

    x_axis = linspace(x_lo,x_hi,N_x).';
    z_axis = linspace(opts.z_min,opts.z_max,opts.n_z).';

    selected_waves = 1:opts.wave_stride:N_waves;

    fs = cd.sampling_frequency;
    t0 = cd.initial_time;
    c = cd.sound_speed;

    wavelength = cd.lambda;

    assert(isnumeric(wavelength) && isscalar(wavelength) && ...
           isfinite(wavelength) && wavelength > 0, ...
        'channel_data.lambda must be a positive finite scalar.');

    dz = median(diff(z_axis));
    axial_half_window_samples = round( ...
        opts.axial_averaging_lambda*wavelength/dz);

    if opts.verbose
        fprintf('============================================================\n');
        fprintf(' Manual RTB-DAS vs RTB + Rx-MVDR\n');
        fprintf('============================================================\n');
        fprintf('File                    : %s\n',filename);
        fprintf('Grid [z x]              : [%d %d]\n', ...
            opts.n_z,N_x);
        fprintf('x spacing               : %.6f mm\n', ...
            median(abs(diff(x_axis)))*1e3);
        fprintf('z spacing               : %.6f mm\n', ...
            median(abs(diff(z_axis)))*1e3);
        fprintf('Used Tx waves           : %d / %d\n', ...
            numel(selected_waves),N_waves);
        fprintf('Tx delay model          : %s\n', ...
            opts.tx_delay_model);
        fprintf('Rx F#                   : %.3f\n', ...
            opts.rx_f_number);
        fprintf('MVDR L/M                : %.3f\n', ...
            opts.subarray_fraction);
        fprintf('MVDR diagonal loading   : %.4g\n', ...
            opts.diagonal_loading);
        fprintf('MVDR axial avg          : +/- %.2f lambda (%d samples)\n', ...
            opts.axial_averaging_lambda, ...
            axial_half_window_samples);
        fprintf('\n');
    end

    %% 3. Allocate cross-Tx accumulators
    das_coherent_sum = complex(zeros(opts.n_z,N_x));
    mvdr_coherent_sum = complex(zeros(opts.n_z,N_x));

    tx_weight_sum = zeros(opts.n_z,N_x);
    active_tx_count = zeros(opts.n_z,N_x);

    mvdr_fallback_count = 0;
    mvdr_pixel_count = 0;

    %% 4. Process each focused transmit
    for kk = 1:numel(selected_waves)

        iw = selected_waves(kk);
        wave = sequence(iw);

        if opts.verbose && ...
                mod(kk-1,max(1,floor(numel(selected_waves)/10))) == 0
            fprintf('RTB+MVDR Tx %d / %d (wave %d) ...\n', ...
                kk,numel(selected_waves),iw);
        end

        rf_wave = double(cd.data(:,:,iw,opts.frame_index));
        analytic_wave = analytic_signal_fft(rf_wave);

        % Process one output lateral column at a time. This keeps memory
        % modest while retaining the full axial neighborhood needed by
        % covariance averaging.
        for ix = 1:N_x

            x_pixel = x_axis(ix);

            % Tx support / apodization versus depth for this Tx/x.
            txw_z = transmit_weights_focused_wave_depth( ...
                wave,x_pixel,z_axis,opts);

            if ~any(txw_z > 0)
                continue;
            end

            % Pixel-dependent RTB Tx delay [Nz,1].
            tau_tx = focused_tx_delay_rtb_depth( ...
                wave,x_pixel,z_axis,opts);

            % Receive delay [Nz,N_channels].
            rx_distance = sqrt( ...
                (x_pixel - probe.x(:).').^2 + ...
                (0 - probe.y(:).').^2 + ...
                (z_axis - probe.z(:).').^2);

            tau_rx = rx_distance/c;
            query_time = tau_tx + tau_rx;

            [samples,valid] = sample_matrix_linear_uniform( ...
                analytic_wave,t0,fs,query_time);

            % Dynamic boxcar receive aperture [Nz,N_channels].
            rx_active = receive_active_depth( ...
                probe.x(:).',x_pixel,z_axis, ...
                opts.rx_aperture_mode,opts.rx_f_number);

            rx_active = rx_active & valid;

            % RTB-DAS contribution versus depth.
            das_by_z = sum(samples .* rx_active,2);

            active_z = find(txw_z > 0);

            for jj = 1:numel(active_z)

                iz = active_z(jj);
                txw = txw_z(iz);

                active_idx = find(rx_active(iz,:));
                M = numel(active_idx);

                if M == 0
                    continue;
                end

                assert(M == 1 || all(diff(active_idx) == 1), ...
                    ['Active receive aperture is not contiguous at ' ...
                     'z index %d, x index %d, wave %d.'], ...
                     iz,ix,iw);

                das_value = das_by_z(iz);

                if M < 3
                    mvdr_value = das_value;
                    mvdr_fallback_count = mvdr_fallback_count + 1;
                else
                    L = floor(opts.subarray_fraction*M);
                    L = max(2,L);
                    L = min(L,M-1);

                    iz_lo = max(1,iz-axial_half_window_samples);
                    iz_hi = min(opts.n_z,iz+axial_half_window_samples);

                    center_s = samples(iz,active_idx);

                    [mvdr_value,used_fallback] = mvdr_pixel( ...
                        center_s, ...
                        samples(iz_lo:iz_hi,active_idx), ...
                        valid(iz_lo:iz_hi,active_idx), ...
                        txw_z(iz_lo:iz_hi) > 0, ...
                        L, ...
                        opts.diagonal_loading, ...
                        opts.forward_backward);

                    mvdr_fallback_count = ...
                        mvdr_fallback_count + double(used_fallback);
                end

                mvdr_pixel_count = mvdr_pixel_count + 1;

                das_coherent_sum(iz,ix) = ...
                    das_coherent_sum(iz,ix) + txw*das_value;

                mvdr_coherent_sum(iz,ix) = ...
                    mvdr_coherent_sum(iz,ix) + txw*mvdr_value;

                tx_weight_sum(iz,ix) = ...
                    tx_weight_sum(iz,ix) + txw;

                active_tx_count(iz,ix) = ...
                    active_tx_count(iz,ix) + 1;
            end
        end
    end

    %% 5. Same cross-Tx normalization for DAS and MVDR
    rtb_das = das_coherent_sum;
    rtb_mvdr = mvdr_coherent_sum;

    if opts.normalize_tx_weights
        ok = tx_weight_sum > eps;

        rtb_das(ok) = ...
            rtb_das(ok)./tx_weight_sum(ok);

        rtb_mvdr(ok) = ...
            rtb_mvdr(ok)./tx_weight_sum(ok);

        rtb_das(~ok) = 0;
        rtb_mvdr(~ok) = 0;
    end

    %% 6. Envelope / dB
    das_env = abs(rtb_das);
    mvdr_env = abs(rtb_mvdr);

    das_peak = max(das_env(:));
    mvdr_peak = max(mvdr_env(:));

    assert(das_peak > 0,'RTB-DAS image is all zero.');
    assert(mvdr_peak > 0,'RTB-MVDR image is all zero.');

    das_db = to_db( ...
        das_env,das_peak,opts.display_dynamic_range_db);

    mvdr_db_common = to_db( ...
        mvdr_env,das_peak,opts.display_dynamic_range_db);

    mvdr_db_self = to_db( ...
        mvdr_env,mvdr_peak,opts.display_dynamic_range_db);

    %% 7. Return
    out = struct();

    out.rtb_das_analytic = rtb_das;
    out.rtb_mvdr_analytic = rtb_mvdr;

    out.rtb_das_envelope = das_env;
    out.rtb_mvdr_envelope = mvdr_env;

    out.rtb_das_db = das_db;
    out.rtb_mvdr_db_common = mvdr_db_common;
    out.rtb_mvdr_db_self = mvdr_db_self;

    out.x_axis = x_axis;
    out.z_axis = z_axis;

    out.tx_weight_sum = tx_weight_sum;
    out.active_tx_count = active_tx_count;

    out.selected_waves = selected_waves;

    out.N_channels = N_channels;
    out.N_waves = N_waves;

    out.fs = fs;
    out.initial_time = t0;
    out.sound_speed = c;
    out.wavelength = wavelength;

    out.axial_half_window_samples = axial_half_window_samples;

    out.mvdr_fallback_count = mvdr_fallback_count;
    out.mvdr_pixel_count = mvdr_pixel_count;

    out.options = opts;
end

%% =========================================================================
% MVDR pixel
% =========================================================================
function [y,used_fallback] = mvdr_pixel( ...
    center_s,axial_samples,axial_valid,axial_tx_support,L, ...
    diagonal_loading,do_forward_backward)

    used_fallback = false;

    M = numel(center_s);
    P = M-L+1;

    if P < 2
        y = sum(center_s);
        used_fallback = true;
        return;
    end

    starts = 1:P;
    index_matrix = (0:L-1).' + starts;

    X_center = center_s(index_matrix);

    R = complex(zeros(L,L));
    n_snapshots = 0;

    for iq = 1:size(axial_samples,1)

        if ~axial_tx_support(iq)
            continue;
        end

        sq = axial_samples(iq,:);
        vq = axial_valid(iq,:);

        Xq = sq(index_matrix);
        Vq = vq(index_matrix);

        keep = all(Vq,1);

        if any(keep)
            Xq = Xq(:,keep);
            R = R + Xq*Xq';
            n_snapshots = n_snapshots + size(Xq,2);
        end
    end

    if n_snapshots < 1
        y = sum(center_s);
        used_fallback = true;
        return;
    end

    R = R/n_snapshots;

    if do_forward_backward
        J = fliplr(eye(L));
        R = 0.5*(R + J*conj(R)*J);
    end

    mean_power = real(trace(R))/L;

    if ~(isfinite(mean_power) && mean_power > 0)
        y = sum(center_s);
        used_fallback = true;
        return;
    end

    R_loaded = ...
        R + diagonal_loading*mean_power*eye(L);

    a = ones(L,1);

    Ria = R_loaded\a;
    denom = a'*Ria;

    if ~(isfinite(real(denom)) && ...
         isfinite(imag(denom)) && ...
         abs(denom) > eps)
        y = sum(center_s);
        used_fallback = true;
        return;
    end

    w = Ria/denom;

    assert(abs(w'*a-1) < 1e-8, ...
        'MVDR distortionless constraint failed.');

    subarray_output = w'*X_center;
    y_unit_gain = mean(subarray_output);

    % Match the coherent receive-DAS amplitude convention.
    y = M*y_unit_gain;
end

%% =========================================================================
% RTB Tx delay versus depth for one x
% =========================================================================
function tau_tx = focused_tx_delay_rtb_depth(wave,x,z,opts)

    sx = wave.source.x;
    sy = wave.source.y;
    sz = wave.source.z;

    z = z(:);

    spherical_distance = sqrt( ...
        (x-sx).^2 + ...
        (0-sy).^2 + ...
        (z-sz).^2);

    signed_spherical = spherical_distance;
    signed_spherical(z < sz) = ...
        -signed_spherical(z < sz);

    spherical_path = ...
        wave.source.distance + signed_spherical;

    plane_path = ...
        wave.source.distance + (z-sz);

    switch lower(opts.tx_delay_model)

        case 'spherical'
            path_length = spherical_path;

        case 'plane'
            path_length = plane_path;

        case 'hybrid'
            path_length = spherical_path;
            inside = abs(z-sz) <= opts.pw_margin;
            path_length(inside) = plane_path(inside);

        case 'blended'
            pixel_radius = sqrt(x.^2 + z.^2);

            normalized_distance = min( ...
                abs(wave.source.distance-pixel_radius) ...
                / wave.source.distance, ...
                1);

            alpha = normalized_distance.^opts.blending_power;

            path_length = ...
                alpha.*spherical_path + ...
                (1-alpha).*plane_path;

        otherwise
            error('Unsupported tx_delay_model: %s', ...
                opts.tx_delay_model);
    end

    tau_tx = path_length/wave.sound_speed - wave.delay;
end

%% =========================================================================
% RTB Tx support versus depth for one x
% =========================================================================
function w = transmit_weights_focused_wave_depth( ...
    wave,x,z,opts)

    [ox,oz] = resolve_focused_origin(wave);

    sx = wave.source.x;
    sz = wave.source.z;

    axis_vec = [sx-ox, sz-oz];
    axis_norm = norm(axis_vec);

    assert(axis_norm > eps, ...
        'Focused wave origin and source are coincident.');

    zu = axis_vec/axis_norm;
    xu = [zu(2),-zu(1)];

    z = z(:);

    dx = x-sx;
    dz = z-sz;

    x_local = dx*xu(1) + dz*xu(2);
    z_local = dx*zu(1) + dz*zu(2);

    z_eff = max( ...
        abs(z_local), ...
        opts.tx_min_aperture*opts.tx_f_number);

    ratio = opts.tx_f_number.*abs(x_local)./z_eff;

    switch lower(opts.tx_window)
        case 'boxcar'
            w = double(ratio <= 0.5);

        case 'tukey25'
            w = tukey_ratio_window(ratio,0.25);

        otherwise
            error('Unsupported tx_window: %s',opts.tx_window);
    end
end

function [ox,oz] = resolve_focused_origin(wave)

    ox = wave.origin.x;
    oz = wave.origin.z;

    if all(abs(wave.origin.xyz) < eps) && ...
            any(abs(wave.source.xyz) > eps)
        ox = wave.source.x;
        oz = 0;
    end
end

function w = tukey_ratio_window(ratio,roll)

    w = zeros(size(ratio));

    flat = ratio <= 0.5*(1-roll);

    taper = ...
        ratio > 0.5*(1-roll) & ...
        ratio < 0.5;

    w(flat) = 1;

    r = ratio(taper);

    w(taper) = 0.5.* ...
        (1 + cos( ...
            2*pi/roll.* ...
            (r-roll/2-1/2)));
end

%% =========================================================================
% Receive aperture versus depth
% =========================================================================
function active = receive_active_depth( ...
    element_x,x_pixel,z_axis,mode,f_number)

    z_axis = z_axis(:);
    element_x = element_x(:).';

    switch lower(mode)

        case 'full'
            active = true(numel(z_axis),numel(element_x));

        case 'f_number'
            half_width = z_axis/(2*f_number);

            active = ...
                abs(element_x-x_pixel) <= half_width;

            empty_rows = ~any(active,2);

            if any(empty_rows)
                rows = find(empty_rows);

                [~,nearest] = min(abs(element_x-x_pixel));

                active(rows,nearest) = true;
            end

        otherwise
            error('Unsupported rx_aperture_mode: %s',mode);
    end
end

%% =========================================================================
% Uniform-time interpolation [depth,channel]
% =========================================================================
function [values,valid] = sample_matrix_linear_uniform( ...
    channel_data,t0,fs,query_time)

    [N_samples,N_channels] = size(channel_data);

    assert(size(query_time,2) == N_channels, ...
        'query_time channel dimension mismatch.');

    u = (query_time-t0)*fs + 1;

    i0 = floor(u);
    alpha = u-i0;

    valid = i0 >= 1 & i0 < N_samples;

    values = complex(zeros(size(query_time)));

    if ~any(valid(:))
        return;
    end

    channel_index = repmat( ...
        1:N_channels,size(query_time,1),1);

    idx0 = sub2ind( ...
        [N_samples,N_channels], ...
        i0(valid),channel_index(valid));

    idx1 = sub2ind( ...
        [N_samples,N_channels], ...
        i0(valid)+1,channel_index(valid));

    values(valid) = ...
        (1-alpha(valid)).*channel_data(idx0) + ...
        alpha(valid).*channel_data(idx1);
end

%% =========================================================================
% Analytic signal
% =========================================================================
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

%% =========================================================================
% Options
% =========================================================================
function opts = apply_defaults(opts)

    defaults = struct( ...
        'z_min',5e-3, ...
        'z_max',45e-3, ...
        'n_z',256, ...
        'frame_index',1, ...
        'x_upsample',4, ...
        'n_x',[], ...
        'x_min',[], ...
        'x_max',[], ...
        'tx_delay_model','blended', ...
        'pw_margin',1e-3, ...
        'blending_power',0.5, ...
        'tx_f_number',2, ...
        'tx_min_aperture',3e-3, ...
        'tx_window','tukey25', ...
        'rx_aperture_mode','f_number', ...
        'rx_f_number',1.7, ...
        'wave_stride',1, ...
        'normalize_tx_weights',true, ...
        'subarray_fraction',0.5, ...
        'diagonal_loading',0.01, ...
        'axial_averaging_lambda',1.5, ...
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

    assert(isnumeric(opts.z_min) && isscalar(opts.z_min) && ...
           isfinite(opts.z_min), ...
        'z_min must be a finite numeric scalar.');

    assert(isnumeric(opts.z_max) && isscalar(opts.z_max) && ...
           isfinite(opts.z_max) && opts.z_max > opts.z_min, ...
        'z_max must be finite and greater than z_min.');

    assert(isnumeric(opts.n_z) && isscalar(opts.n_z) && ...
           isfinite(opts.n_z) && opts.n_z >= 2 && ...
           opts.n_z == round(opts.n_z), ...
        'n_z must be an integer scalar >= 2.');

    if ~isempty(opts.n_x)
        assert(isnumeric(opts.n_x) && isscalar(opts.n_x) && ...
               isfinite(opts.n_x) && opts.n_x >= 2 && ...
               opts.n_x == round(opts.n_x), ...
            'n_x must be an integer scalar >= 2 when provided.');
    end

    if ~isempty(opts.x_min)
        assert(isnumeric(opts.x_min) && isscalar(opts.x_min) && ...
               isfinite(opts.x_min), ...
            'x_min must be a finite numeric scalar.');
    end

    if ~isempty(opts.x_max)
        assert(isnumeric(opts.x_max) && isscalar(opts.x_max) && ...
               isfinite(opts.x_max), ...
            'x_max must be a finite numeric scalar.');
    end

    if ~isempty(opts.x_min) && ~isempty(opts.x_max)
        assert(opts.x_max > opts.x_min, ...
            'x_max must be greater than x_min.');
    end

    assert(isnumeric(opts.subarray_fraction) && ...
           isscalar(opts.subarray_fraction) && ...
           isfinite(opts.subarray_fraction) && ...
           opts.subarray_fraction > 0 && ...
           opts.subarray_fraction < 1, ...
        'subarray_fraction must be one scalar in (0,1).');

    assert(isnumeric(opts.diagonal_loading) && ...
           isscalar(opts.diagonal_loading) && ...
           isfinite(opts.diagonal_loading) && ...
           opts.diagonal_loading > 0, ...
        'diagonal_loading must be a positive scalar.');

    assert(isnumeric(opts.axial_averaging_lambda) && ...
           isscalar(opts.axial_averaging_lambda) && ...
           isfinite(opts.axial_averaging_lambda) && ...
           opts.axial_averaging_lambda >= 0, ...
        'axial_averaging_lambda must be a scalar >= 0.');

    assert(opts.tx_f_number > 0 && ...
           opts.rx_f_number > 0, ...
        'Tx/Rx F-numbers must be positive.');

    assert(opts.tx_min_aperture >= 0, ...
        'tx_min_aperture must be non-negative.');

    assert(opts.pw_margin >= 0, ...
        'pw_margin must be non-negative.');

    assert(opts.blending_power > 0, ...
        'blending_power must be positive.');

    assert(opts.wave_stride >= 1 && ...
           opts.wave_stride == round(opts.wave_stride), ...
        'wave_stride must be a positive integer.');

    valid_models = {'spherical','plane','hybrid','blended'};
    assert(any(strcmpi(opts.tx_delay_model,valid_models)), ...
        'Unsupported tx_delay_model.');

    valid_tx_windows = {'boxcar','tukey25'};
    assert(any(strcmpi(opts.tx_window,valid_tx_windows)), ...
        'tx_window must be boxcar or tukey25.');

    valid_rx_modes = {'full','f_number'};
    assert(any(strcmpi(opts.rx_aperture_mode,valid_rx_modes)), ...
        'rx_aperture_mode must be full or f_number.');
end

function db = to_db(env,reference_peak,dynamic_range)

    db = 20*log10(env/(reference_peak+eps)+eps);

    db(db < -dynamic_range) = -dynamic_range;
    db(db > 0) = 0;
end
