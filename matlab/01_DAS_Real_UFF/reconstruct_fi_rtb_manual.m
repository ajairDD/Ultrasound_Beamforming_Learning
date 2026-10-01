function out = reconstruct_fi_rtb_manual(filename, opts, channel_data)
%RECONSTRUCT_FI_RTB_MANUAL Manual retrospective transmit beamforming (RTB).
%
% Chapter 1 RTB core for focused-imaging UFF channel data.
%
% USTB is used ONLY to read UFF objects / metadata. RTB itself is explicit:
%
%   for each focused transmit t
%       receive-DAS -> S_t(x,z)
%       Tx weight   -> w_t(x,z)
%   end
%
%   S_RTB(x,z) =
%       sum_t w_t(x,z) * S_t(x,z) / sum_t w_t(x,z)
%
% This differs from conventional scanline FI-DAS:
%   conventional : one Tx -> one output scanline
%   RTB          : one Tx -> many pixels in its insonified region;
%                  many Tx can contribute coherently to one pixel.
%
% DEFAULTS FOLLOW THE IUS-2018 USTB RTB EXAMPLE CLOSELY:
%   lateral upsampling / MLA factor = 4
%   Tx F-number                     = 2
%   Tx Tukey25 weighting
%   minimum Tx aperture             = 3 mm
%   hybrid Tx delay model
%   plane-wave margin around focus  = 1 mm
%   Rx boxcar F-number              = 1.7
%
% INPUT
% -----
% filename : UFF file
%
% opts fields (all optional)
%   z_min                  [m], default 5e-3
%   z_max                  [m], default 45e-3
%   n_z                    default 512
%   frame_index            default 1
%
%   x_upsample             default 4
%   n_x                    [] -> N_waves*x_upsample
%
%   tx_delay_model         'spherical' / 'hybrid' / 'blended', default 'hybrid'
%   pw_margin              [m], default 1e-3 (hybrid only)
%   blending_power         default 0.5 (blended only)
%   tx_f_number            default 2
%   tx_min_aperture        [m], default 3e-3
%   tx_window              'tukey25' or 'boxcar', default 'tukey25'
%
%   rx_aperture_mode       'f_number' or 'full', default 'f_number'
%   rx_f_number            default 1.7
%
%   wave_stride            default 1
%                          1=all Tx, 2=every second Tx, ...
%
%   normalize_tx_weights   default true
%   tx_time_offsets        [s], [] or one value per original Tx event.
%                          Added to the RF query time, before interpolation.
%   display_dynamic_range_db default 60
%   inspect_wave_index     [] or original wave index
%   verbose                default false
%
% OUTPUT
% ------
% out.rtb_analytic         [z, x], complex
% out.envelope             [z, x]
% out.image_db             [z, x]
% out.x_axis / out.z_axis  [m]
% out.tx_weight_sum        [z, x]
% out.active_tx_count      [z, x]
% out.selected_waves
% out.options
% out.tx_coherence         |sum(w*S)| / sum(w*|S|), [z, x]
% out.incoherent_envelope  sum(w*|S|) / sum(w), [z, x]
% A third argument can supply an already-read uff.channel_data object.
%
% Optional diagnostic maps for inspect_wave_index:
% out.single_tx_unweighted
% out.single_tx_weighted
% out.single_tx_delay
%
% SCIENTIFIC LIMITS
% -----------------
% This implementation is intentionally for 2-D linear-array focused
% imaging. It assumes the focused beams are represented by positive-z
% spherical virtual sources. For the current L7 FI dataset, this is the
% geometry used by the USTB publication examples.
%
% The 'hybrid' model replaces spherical Tx delay with locally plane
% propagation inside a hard focal-depth band. This removes the simple
% spherical discontinuity at z = z_focus, but the hard switch can create
% visible seams at the band boundaries.
%
% The newer USTB 'blended' model mixes spherical and plane delays
% continuously and is therefore useful for testing whether such seams are
% caused by the hard hybrid transition.

    if nargin < 1 || isempty(filename)
        filename = '../../data/L7_FI_Verasonics_CIRS_points.uff';
    end
    if nargin < 2 || isempty(opts)
        opts = struct();
    end
    opts = apply_defaults(opts);

    assert(exist(filename,'file') == 2, ...
        'File not found: %s',filename);
    assert(~isempty(which('uff.read_object')), ...
        ['USTB / UFF reader was not found. ' ...
         'Run addpath(genpath(''YOUR_USTB_PATH'')) first.']);

    %% --------------------------------------------------------------------
    % 1. Read and validate UFF
    % ---------------------------------------------------------------------
    if nargin < 3 || isempty(channel_data)
        channel_data = uff.read_object(filename,'/channel_data');
    end

    assert(opts.frame_index >= 1 && ...
           opts.frame_index <= channel_data.N_frames, ...
        'frame_index is outside the available frame range.');

    assert(abs(channel_data.modulation_frequency) < eps, ...
        ['This teaching RTB implementation is currently RF-only. ' ...
         'modulation_frequency = %.12g Hz.'], ...
         channel_data.modulation_frequency);

    assert(isreal(channel_data.data), ...
        ['modulation_frequency == 0 but channel data is complex. ' ...
         'Inspect UFF semantics before continuing.']);

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
        'This RTB implementation assumes the x-z imaging plane.');

    %% --------------------------------------------------------------------
    % 2. RTB reconstruction grid
    % ---------------------------------------------------------------------
    if isempty(opts.n_x)
        N_x = N_waves * opts.x_upsample;
    else
        N_x = opts.n_x;
    end

    x_axis = linspace(min(source_x),max(source_x),N_x).';
    z_axis = linspace(opts.z_min,opts.z_max,opts.n_z).';

    selected_waves = 1:opts.wave_stride:N_waves;

    fs = channel_data.sampling_frequency;
    t0 = channel_data.initial_time;
    c = channel_data.sound_speed;

    if opts.verbose
        fprintf('============================================================\n');
        fprintf(' Manual focused-imaging RTB\n');
        fprintf('============================================================\n');
        fprintf('File                : %s\n',filename);
        fprintf('Data [T C W F]      : [%d %d %d %d]\n', ...
            size(channel_data.data,1), ...
            size(channel_data.data,2), ...
            size(channel_data.data,3), ...
            size(channel_data.data,4));
        fprintf('Output grid [z x]   : [%d %d]\n',opts.n_z,N_x);
        fprintf('Original Tx waves   : %d\n',N_waves);
        fprintf('Used Tx waves       : %d (stride %d)\n', ...
            numel(selected_waves),opts.wave_stride);
        fprintf('x spacing           : %.6f mm\n', ...
            median(abs(diff(x_axis)))*1e3);
        fprintf('Tx delay model      : %s\n',opts.tx_delay_model);
        fprintf('Tx F-number         : %.3f\n',opts.tx_f_number);
        fprintf('Tx minimum aperture : %.3f mm\n', ...
            opts.tx_min_aperture*1e3);
        fprintf('Tx window           : %s\n',opts.tx_window);
        fprintf('PW margin           : %.3f mm\n',opts.pw_margin*1e3);
        fprintf('Blending power      : %.3f\n',opts.blending_power);
        fprintf('Rx aperture         : %s\n',opts.rx_aperture_mode);
        if strcmpi(opts.rx_aperture_mode,'f_number')
            fprintf('Rx F-number         : %.3f\n',opts.rx_f_number);
        end
        fprintf('\n');
    end

    %% --------------------------------------------------------------------
    % 3. Allocate RTB accumulators
    % ---------------------------------------------------------------------
    coherent_sum = complex(zeros(opts.n_z,N_x));
    incoherent_sum = zeros(opts.n_z,N_x);
    tx_weight_sum = zeros(opts.n_z,N_x);
    active_tx_count = zeros(opts.n_z,N_x);

    n_requested = 0;
    n_out_of_range = 0;

    inspect_enabled = ~isempty(opts.inspect_wave_index);
    single_tx_unweighted = [];
    single_tx_weighted = [];
    single_tx_delay = [];

    if inspect_enabled
        assert(opts.inspect_wave_index >= 1 && ...
               opts.inspect_wave_index <= N_waves, ...
            'inspect_wave_index is outside the wave range.');

        single_tx_unweighted = complex(zeros(opts.n_z,N_x));
        single_tx_weighted = complex(zeros(opts.n_z,N_x));
        single_tx_delay = nan(opts.n_z,N_x);
    end

    %% --------------------------------------------------------------------
    % 4. Retrospective transmit beamforming
    % ---------------------------------------------------------------------
    for kk = 1:numel(selected_waves)
        iw = selected_waves(kk);
        wave = sequence(iw);

        if opts.verbose && ...
                mod(kk-1,max(1,floor(numel(selected_waves)/10))) == 0
            fprintf('RTB wave %d / %d (original index %d) ...\n', ...
                kk,numel(selected_waves),iw);
        end

        % Shape [sample, Rx channel].
        rf_wave = double( ...
            channel_data.data(:,:,iw,opts.frame_index));

        analytic_wave = analytic_signal_fft(rf_wave);

        for iz = 1:opts.n_z
            z_pixel = z_axis(iz);

            % Pixel-dependent Tx weights identify the region where this
            % focused transmit is considered useful.
            tx_weights_all = transmit_weights_focused_wave( ...
                wave,x_axis,z_pixel,opts);

            active_x = find(tx_weights_all > 0);

            if isempty(active_x)
                continue;
            end

            x_pixels = x_axis(active_x);

            % Tx delay for every active lateral pixel.
            tau_tx = focused_tx_delay_rtb( ...
                wave,x_pixels,z_pixel,opts);
            tau_tx = tau_tx + tx_time_offsets(iw);

            % Rx propagation delay: [active pixel, receive channel].
            rx_distance = sqrt( ...
                (x_pixels - probe.x(:).').^2 + ...
                (0 - probe.y(:).').^2 + ...
                (z_pixel - probe.z(:).').^2);

            tau_rx = rx_distance / c;

            query_time = tau_tx + tau_rx;

            [samples,valid] = sample_matrix_linear_uniform( ...
                analytic_wave,t0,fs,query_time);

            rx_weights = receive_weights_matrix( ...
                probe.x(:).',x_pixels,z_pixel, ...
                opts.rx_aperture_mode,opts.rx_f_number);

            rx_weights(~valid) = 0;

            n_requested = n_requested + numel(valid);
            n_out_of_range = n_out_of_range + nnz(~valid);

            % Receive DAS for this Tx -> one low-quality image sample
            % per active output pixel.
            single_tx_values = sum(rx_weights .* samples,2);

            txw = tx_weights_all(active_x);

            weighted_values = txw .* single_tx_values;
            incoherent_sum(iz,active_x) = ...
                incoherent_sum(iz,active_x) + abs(weighted_values).';

            coherent_sum(iz,active_x) = ...
                coherent_sum(iz,active_x) + weighted_values.';

            tx_weight_sum(iz,active_x) = ...
                tx_weight_sum(iz,active_x) + txw.';

            active_tx_count(iz,active_x) = ...
                active_tx_count(iz,active_x) + double(txw.' > 0);

            if inspect_enabled && iw == opts.inspect_wave_index
                single_tx_unweighted(iz,active_x) = ...
                    single_tx_values.';
                single_tx_weighted(iz,active_x) = ...
                    weighted_values.';
                single_tx_delay(iz,active_x) = tau_tx.';
            end
        end
    end

    %% --------------------------------------------------------------------
    % 5. Normalize overlapping transmit contributions
    % ---------------------------------------------------------------------
    rtb_analytic = coherent_sum;

    if opts.normalize_tx_weights
        valid_tx = tx_weight_sum > eps;
        rtb_analytic(valid_tx) = ...
            rtb_analytic(valid_tx) ./ tx_weight_sum(valid_tx);
        rtb_analytic(~valid_tx) = 0;
    end

    env = abs(rtb_analytic);

    peak = max(env(:));
    assert(peak > 0,'RTB image is all zero.');

    image_db = 20*log10(env/(peak+eps) + eps);
    image_db(image_db < -opts.display_dynamic_range_db) = ...
        -opts.display_dynamic_range_db;

    %% --------------------------------------------------------------------
    % 6. Return results
    % ---------------------------------------------------------------------
    out = struct();

    out.rtb_analytic = rtb_analytic;
    out.envelope = env;
    out.image_db = image_db;

    out.x_axis = x_axis;
    out.z_axis = z_axis;

    out.tx_weight_sum = tx_weight_sum;
    out.active_tx_count = active_tx_count;
    out.tx_time_offsets = tx_time_offsets;
    out.tx_coherence = abs(coherent_sum) ./ max(incoherent_sum,realmin);
    out.incoherent_envelope = incoherent_sum ./ max(tx_weight_sum,realmin);

    out.selected_waves = selected_waves;
    out.N_channels = N_channels;
    out.N_waves = N_waves;

    out.fs = fs;
    out.initial_time = t0;
    out.sound_speed = c;

    out.source_x = source_x;
    out.source_z = source_z;

    out.n_requested = n_requested;
    out.n_out_of_range = n_out_of_range;

    out.options = opts;

    out.single_tx_unweighted = single_tx_unweighted;
    out.single_tx_weighted = single_tx_weighted;
    out.single_tx_delay = single_tx_delay;
end

%% =========================================================================
% Options
% =========================================================================
function opts = apply_defaults(opts)

    defaults = struct( ...
        'z_min',5e-3, ...
        'z_max',45e-3, ...
        'n_z',512, ...
        'frame_index',1, ...
        'x_upsample',4, ...
        'n_x',[], ...
        'tx_delay_model','hybrid', ...
        'pw_margin',1e-3, ...
        'blending_power',0.5, ...
        'tx_f_number',2, ...
        'tx_min_aperture',3e-3, ...
        'tx_window','tukey25', ...
        'rx_aperture_mode','f_number', ...
        'rx_f_number',1.7, ...
        'wave_stride',1, ...
        'normalize_tx_weights',true, ...
        'tx_time_offsets',[], ...
        'display_dynamic_range_db',60, ...
        'inspect_wave_index',[], ...
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

    assert(opts.x_upsample >= 1, ...
        'x_upsample must be >= 1.');

    assert(opts.tx_f_number > 0, ...
        'tx_f_number must be positive.');

    assert(opts.rx_f_number > 0, ...
        'rx_f_number must be positive.');

    assert(opts.tx_min_aperture >= 0, ...
        'tx_min_aperture must be non-negative.');

    assert(opts.pw_margin >= 0, ...
        'pw_margin must be non-negative.');

    assert(opts.blending_power > 0, ...
        'blending_power must be positive.');

    assert(opts.wave_stride >= 1 && ...
           opts.wave_stride == round(opts.wave_stride), ...
        'wave_stride must be a positive integer.');

    valid_models = {'spherical','hybrid','blended'};
    assert(any(strcmpi(opts.tx_delay_model,valid_models)), ...
        'tx_delay_model must be spherical, hybrid, or blended.');

    valid_tx_windows = {'boxcar','tukey25'};
    assert(any(strcmpi(opts.tx_window,valid_tx_windows)), ...
        'tx_window must be boxcar or tukey25.');

    valid_rx_modes = {'full','f_number'};
    assert(any(strcmpi(opts.rx_aperture_mode,valid_rx_modes)), ...
        'rx_aperture_mode must be full or f_number.');
end

%% =========================================================================
% Tx delay
% =========================================================================
function tau_tx = focused_tx_delay_rtb(wave,x,z,opts)
%FOCUSED_TX_DELAY_RTB Pixel-based focused-wave Tx delay.
%
% x is [N_pixel,1], z is scalar.
%
% SPHERICAL MODEL
% ----------------
% Treat the focused wave as a virtual spherical source at the focus:
%
%   before focus: source.distance - |source -> pixel|
%   after focus : source.distance + |source -> pixel|
%
% For off-axis pixels this model has a discontinuity across focal depth.
%
% HYBRID MODEL
% ------------
% Use spherical delay away from focus and locally plane propagation inside
% a hard |z-source.z| <= pw_margin band. The hard transition may itself
% create seams at the band boundaries.
%
% BLENDED MODEL
% -------------
% Continuously mix spherical and plane paths using the current USTB
% blended-model definition, avoiding a hard z-boundary switch.

    sx = wave.source.x;
    sy = wave.source.y;
    sz = wave.source.z;

    spherical_distance = sqrt( ...
        (x-sx).^2 + ...
        (0-sy).^2 + ...
        (z-sz).^2);

    if z < sz
        signed_spherical = -spherical_distance;
    else
        signed_spherical = spherical_distance;
    end

    spherical_path = ...
        wave.source.distance + signed_spherical;

    % Plane propagation through the focal region for a linear scan.
    % This is independent of x in the USTB hybrid/blended linear-scan
    % convention.
    signed_axial = z - sz;

    plane_path = ...
        wave.source.distance + ...
        signed_axial .* ones(size(x));

    switch lower(opts.tx_delay_model)

        case 'spherical'
            path_length = spherical_path;

        case 'hybrid'
            % Hard replacement inside a focal-depth band.
            %
            % IMPORTANT:
            % spherical_path and plane_path are generally NOT equal at
            % z = sz +/- pw_margin for off-axis pixels. Therefore this
            % model can move the original focal discontinuity to the two
            % band boundaries and create horizontal seams.
            if abs(z-sz) <= opts.pw_margin
                path_length = plane_path;
            else
                path_length = spherical_path;
            end

        case 'blended'
            % Match current USTB blended model:
            %
            % normalized_distance =
            %   min(abs(source.distance - |pixel_from_global_origin|)
            %       / source.distance, 1)
            %
            % alpha = normalized_distance ^ blending_power
            %
            % path = alpha*spherical + (1-alpha)*plane
            %
            % Close to the focal spherical shell alpha -> 0, so the plane
            % model dominates. Far away alpha -> 1, so spherical dominates.
            pixel_radius = sqrt(x.^2 + z.^2);

            normalized_distance = min( ...
                abs(wave.source.distance - pixel_radius) ...
                / wave.source.distance, ...
                1);

            alpha = normalized_distance .^ opts.blending_power;

            path_length = ...
                alpha .* spherical_path + ...
                (1-alpha) .* plane_path;

        otherwise
            error('Unsupported tx_delay_model: %s', ...
                opts.tx_delay_model);
    end

    tau_tx = path_length / wave.sound_speed - wave.delay;
end

%% =========================================================================
% Tx apodization / insonification weight
% =========================================================================
function w = transmit_weights_focused_wave(wave,x_axis,z,opts)
%TRANSMIT_WEIGHTS_FOCUSED_WAVE Pixel-dependent Tx weight for one wave.
%
% The beam is represented in local coordinates about the virtual source.
% For the current linear focused dataset, origin is expected on the probe
% plane below the virtual source. If UFF origin is still [0,0,0], we apply
% the same focused-wave fallback concept as USTB's fix_origin_from_source.
%
% The F-number aperture condition is
%
%   ratio = F# * |x_local| / |z_local|
%
% with support ratio <= 0.5.
%
% tx_min_aperture prevents the Tx support from collapsing to zero width
% close to the virtual source.

    [ox,oz] = resolve_focused_origin(wave);

    sx = wave.source.x;
    sz = wave.source.z;

    axis_vec = [sx-ox, sz-oz];
    axis_norm = norm(axis_vec);

    assert(axis_norm > eps, ...
        'Focused wave origin and source are coincident.');

    zu = axis_vec / axis_norm;

    % 2-D unit vector perpendicular to beam axis.
    xu = [zu(2), -zu(1)];

    dx = x_axis - sx;
    dz = z - sz;

    x_local = dx*xu(1) + dz*xu(2);
    z_local = dx*zu(1) + dz*zu(2);

    z_eff = max( ...
        abs(z_local), ...
        opts.tx_min_aperture * opts.tx_f_number);

    ratio = opts.tx_f_number .* abs(x_local) ./ z_eff;

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
%RESOLVE_FOCUSED_ORIGIN Resolve beam-axis origin for focused linear FI.

    ox = wave.origin.x;
    oz = wave.origin.z;

    if all(abs(wave.origin.xyz) < eps) && ...
            any(abs(wave.source.xyz) > eps)

        % Focused-wave fallback: probe-plane point below virtual source.
        ox = wave.source.x;
        oz = 0;
    end
end

function w = tukey_ratio_window(ratio,roll)
%TUKEY_RATIO_WINDOW USTB-style Tukey window on F-number ratio.
%
% Support:
%   ratio <= 0.5
%
% Flat central region:
%   ratio <= 0.5*(1-roll)

    w = zeros(size(ratio));

    flat = ratio <= 0.5*(1-roll);

    taper = ...
        ratio > 0.5*(1-roll) & ...
        ratio < 0.5;

    w(flat) = 1;

    r = ratio(taper);

    w(taper) = 0.5 .* ...
        (1 + cos( ...
            2*pi/roll .* ...
            (r - roll/2 - 1/2)));
end

%% =========================================================================
% Receive aperture
% =========================================================================
function w = receive_weights_matrix( ...
    element_x,x_pixels,z_pixel,mode,f_number)
%RECEIVE_WEIGHTS_MATRIX Receive weights [pixel, Rx channel].

    Np = numel(x_pixels);
    M = numel(element_x);

    switch lower(mode)
        case 'full'
            w = ones(Np,M);

        case 'f_number'
            aperture_width = z_pixel / f_number;
            half_width = aperture_width / 2;

            w = double( ...
                abs(x_pixels - element_x) <= half_width);

            empty_rows = ~any(w,2);

            if any(empty_rows)
                rows = find(empty_rows);
                for k = 1:numel(rows)
                    [~,idx] = min( ...
                        abs(element_x - x_pixels(rows(k))));
                    w(rows(k),idx) = 1;
                end
            end

        otherwise
            error('Unsupported rx_aperture_mode: %s',mode);
    end
end

%% =========================================================================
% Uniform-time linear interpolation
% =========================================================================
function [values,valid] = sample_matrix_linear_uniform( ...
    channel_data,t0,fs,query_time)
%SAMPLE_MATRIX_LINEAR_UNIFORM One query time per pixel/channel pair.
%
% channel_data : [sample, channel]
% query_time   : [pixel, channel]
% values       : [pixel, channel]

    [N_samples,N_channels] = size(channel_data);

    assert(size(query_time,2) == N_channels, ...
        'query_time channel dimension does not match channel_data.');

    u = (query_time-t0)*fs + 1;

    i0 = floor(u);
    alpha = u-i0;

    valid = i0 >= 1 & i0 < N_samples;

    values = complex(zeros(size(query_time)));

    if ~any(valid(:))
        return;
    end

    channel_index = repmat( ...
        1:N_channels, ...
        size(query_time,1),1);

    idx0 = sub2ind( ...
        [N_samples,N_channels], ...
        i0(valid), ...
        channel_index(valid));

    idx1 = sub2ind( ...
        [N_samples,N_channels], ...
        i0(valid)+1, ...
        channel_index(valid));

    values(valid) = ...
        (1-alpha(valid)).*channel_data(idx0) + ...
        alpha(valid).*channel_data(idx1);
end

%% =========================================================================
% RF analytic signal
% =========================================================================
function xa = analytic_signal_fft(x)
%ANALYTIC_SIGNAL_FFT Analytic signal along first dimension.

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
