function out = reconstruct_fi_gcf_manual(filename,opts)
%RECONSTRUCT_FI_GCF_MANUAL Manual receive-domain GCF imaging.
%
% Chapter 2 teaching implementation of the Generalized Coherence Factor
% (GCF) for conventional focused imaging.
%
% For every pixel:
%
%   1) compute the same Tx/Rx delays as Chapter 1;
%   2) interpolate the complex analytic RF on each receive channel;
%   3) keep the active receive aperture;
%   4) form ordinary DAS;
%   5) FFT the aligned active aperture vector along receive-channel index;
%   6) compute the fraction of spectral energy inside a low-spatial-
%      frequency band around DC;
%   7) multiply the complex DAS pixel by that GCF weight.
%
% IMPORTANT PARAMETER CONVENTION
% ------------------------------
% opts.M0 follows the USTB OMHR-style convention used for validation:
%
%   M0 <= 1 : only DC is included -> this reduces to ordinary CF
%   M0 = 2  : FFT bins {-2,-1,0,+1,+2}
%   M0 = 4  : FFT bins {-4,...,0,...,+4}
%
% Thus for M0 >= 2, M0 is the low-spatial-frequency half-width in bins.
%
% This differs slightly from the previous pure teaching demo, where K=1
% meant {-1,0,+1}. The production teaching core keeps the USTB-compatible
% convention so that later reference validation is unambiguous.
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
%   M0                       default 2
%   display_dynamic_range_db default 60
%   verbose                  true/false, default false
%
% OUTPUT
% ------
% out.das_analytic
% out.das_envelope
% out.das_db
%
% out.gcf_map
%
% out.gcf_analytic
% out.gcf_envelope
% out.gcf_db_self
% out.gcf_db_common
%
% out.active_channel_count
% out.x_axis
% out.z_axis

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

    %% 3. Allocate
    das_analytic = complex(zeros(opts.n_z,N_waves));
    gcf_map = zeros(opts.n_z,N_waves);
    active_channel_count = zeros(opts.n_z,N_waves);

    %% 4. Pixel-by-pixel GCF
    for iw = 1:N_waves

        if opts.verbose && ...
                mod(iw-1,max(1,floor(N_waves/10))) == 0
            fprintf('GCF reconstruction wave %d / %d ...\n',iw,N_waves);
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
                continue;
            end

            s = focused_samples(active);

            coherent_sum = sum(s);
            das_analytic(iz,iw) = coherent_sum;

            % USTB OMHR-style behavior:
            % if the active aperture is too small for the requested low-
            % frequency region, set the GCF weight to zero.
            if M <= opts.M0
                gcf_value = 0;
            else
                X = fft(s);
                spectral_energy = abs(X).^2;
                total_energy = sum(spectral_energy);

                if total_energy <= 0
                    gcf_value = 0;
                else
                    idx = low_frequency_indices(M,opts.M0);

                    gcf_value = ...
                        sum(spectral_energy(idx)) / ...
                        total_energy;
                end
            end

            assert(gcf_value >= -1e-12 && gcf_value <= 1+1e-10, ...
                'GCF outside expected range at z index %d, wave %d: %.12g', ...
                iz,iw,gcf_value);

            gcf_map(iz,iw) = min(max(real(gcf_value),0),1);
        end
    end

    %% 5. GCF weighting
    gcf_analytic = gcf_map .* das_analytic;

    das_env = abs(das_analytic);
    gcf_env = abs(gcf_analytic);

    das_peak = max(das_env(:));
    gcf_peak = max(gcf_env(:));

    assert(das_peak > 0,'DAS image is all zero.');
    assert(gcf_peak > 0,'GCF-weighted image is all zero.');

    das_db = to_db(das_env,das_peak,opts.display_dynamic_range_db);

    gcf_db_self = to_db( ...
        gcf_env,gcf_peak,opts.display_dynamic_range_db);

    gcf_db_common = to_db( ...
        gcf_env,das_peak,opts.display_dynamic_range_db);

    %% 6. Return
    out = struct();

    out.das_analytic = das_analytic;
    out.das_envelope = das_env;
    out.das_db = das_db;

    out.gcf_map = gcf_map;

    out.gcf_analytic = gcf_analytic;
    out.gcf_envelope = gcf_env;
    out.gcf_db_self = gcf_db_self;
    out.gcf_db_common = gcf_db_common;

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
        'M0',2, ...
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

    assert(opts.M0 >= 0 && opts.M0 == round(opts.M0), ...
        'M0 must be a non-negative integer.');

    assert(any(strcmpi(opts.receive_aperture_mode,{'full','f_number'})), ...
        'receive_aperture_mode must be full or f_number.');
end

function idx = low_frequency_indices(M,M0)

    if M0 <= 1
        % USTB legacy convention: M0 <= 1 -> DC only.
        idx = 1;
        return;
    end

    assert(2*M0+1 <= M, ...
        'Requested M0=%d is too large for active aperture M=%d.',M0,M);

    % MATLAB FFT ordering:
    %   index 1       -> DC
    %   2...          -> positive spatial frequencies
    %   ...end        -> negative spatial frequencies
    %
    % Include {-M0,...,-1,0,+1,...,+M0}.
    idx = [1:(M0+1), (M-M0+1):M];
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
