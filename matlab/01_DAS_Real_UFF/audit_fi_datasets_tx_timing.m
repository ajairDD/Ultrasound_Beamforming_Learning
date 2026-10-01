%% audit_fi_datasets_tx_timing.m
% Chapter 1 - Cross-dataset audit of focused-imaging Tx timing.
%
% PURPOSE
% -------
% Determine whether the right-edge inter-Tx timing/coherence loss observed
% in L7_FI_Verasonics_CIRS_points.uff is:
%
%   A) specific to that acquisition / conversion, or
%   B) repeatable across other focused-imaging datasets.
%
% IMPORTANT
% ---------
% This script applies NO timing correction.
% It does NOT call right_edge_tx_time_offsets().
%
% The CIRS-specific 16-element hypothesis must not be generalized to other
% datasets before the uncorrected data show a comparable timing pattern.
%
% DEFAULT DATASETS
% ----------------
%   L7_FI_Verasonics_CIRS_points.uff   reference problem
%   L7_FI_TheGB.uff                    same L7 / Verasonics family
%   L7_FI_carotid_cross_1.uff          in-vivo FI
%   L7_FI_carotid_cross_2.uff          independent in-vivo FI
%   Alpinion_L3-8_FI_hypoechoic.uff    different platform / probe control
%
% The audit compares, for each compatible dataset:
%   1) matched conventional FI-DAS vs uncorrected blended RTB;
%   2) RTB/FI absolute envelope ratio in left / center / right regions;
%   3) RTB Tx coherence in left / center / right regions;
%   4) adjacent-Tx complex correlation phase across Tx index;
%   5) left / middle / right-edge adjacent-Tx phase statistics.
%
% To reduce runtime, defaults use n_z=256 and x_upsample=2. Timing behavior
% should not depend on display-grid density. Increase later if needed.
%
% Run:
%   addpath(genpath('D:/USTB'));
%   cd matlab/01_DAS_Real_UFF
%   audit_fi_datasets_tx_timing

clearvars -except data_dir n_z x_upsample output_dir;
clc;
close all;

if ~exist('data_dir','var')
    data_dir = '../../data';
end
if ~exist('n_z','var')
    n_z = 256;
end
if ~exist('x_upsample','var')
    x_upsample = 2;
end
if ~exist('output_dir','var')
    output_dir = fullfile( ...
        fileparts(mfilename('fullpath')), ...
        '..','..','artifacts','fi_timing_audit');
end

if ~exist(output_dir,'dir')
    mkdir(output_dir);
end

dataset_names = { ...
    'L7_FI_Verasonics_CIRS_points.uff', ...
    'L7_FI_TheGB.uff', ...
    'L7_FI_carotid_cross_1.uff', ...
    'L7_FI_carotid_cross_2.uff', ...
    'Alpinion_L3-8_FI_hypoechoic.uff'};

N_dataset = numel(dataset_names);

summary_rows = cell(N_dataset,1);
phase_results = cell(N_dataset,1);
status_rows = cell(N_dataset,1);

fprintf('============================================================\n');
fprintf(' FOCUSED-IMAGING CROSS-DATASET TX TIMING AUDIT\n');
fprintf('============================================================\n');
fprintf('No per-Tx timing correction is applied.\n\n');

for id = 1:N_dataset

    name = dataset_names{id};
    filename = fullfile(data_dir,name);

    fprintf('\n============================================================\n');
    fprintf(' DATASET %d / %d\n',id,N_dataset);
    fprintf(' %s\n',name);
    fprintf('============================================================\n');

    if exist(filename,'file') ~= 2
        fprintf('SKIP: file not found.\n');
        status_rows{id} = {name,'SKIP','file not found'};
        continue;
    end

    try
        cd = uff.read_object(filename,'/channel_data',false);

        compatibility = check_fi_compatibility(cd);

        if ~compatibility.ok
            fprintf('SKIP: %s\n',compatibility.reason);
            status_rows{id} = {name,'SKIP',compatibility.reason};
            continue;
        end

        % ---------------------------------------------------------------
        % Metadata
        % ---------------------------------------------------------------
        sx = arrayfun(@(w) double(w.source.x),cd.sequence(:));
        sz = arrayfun(@(w) double(w.source.z),cd.sequence(:));
        wdelay = arrayfun(@(w) double(w.delay),cd.sequence(:));

        focus_z = median(sz);
        x_min = min(sx);
        x_max = max(sx);
        x_span = x_max-x_min;

        pitch = median(diff(double(cd.probe.x(:))));

        fprintf('N waves             : %d\n',cd.N_waves);
        fprintf('N channels          : %d\n',cd.N_channels);
        fprintf('fs                  : %.4f MHz\n', ...
            double(cd.sampling_frequency)/1e6);
        fprintf('pitch               : %.4f mm\n',pitch*1e3);
        fprintf('median focus depth  : %.4f mm\n',focus_z*1e3);
        fprintf('source x range      : %.4f to %.4f mm\n', ...
            x_min*1e3,x_max*1e3);
        fprintf('wave.delay range    : %.3f to %.3f ns\n', ...
            min(wdelay)*1e9,max(wdelay)*1e9);

        % ---------------------------------------------------------------
        % Use a pre-focus depth band relative to each acquisition's focus.
        % CIRS 10-27 mm corresponds approximately to 0.34-0.91 z_focus.
        % ---------------------------------------------------------------
        z_low = max(5e-3,0.35*focus_z);
        z_high = 0.90*focus_z;

        % Respect actual recorded time range approximately. Reconstruction
        % itself will count out-of-range queries; this band remains safely
        % before focus for the timing audit.
        assert(z_high > z_low, ...
            'Invalid relative timing-audit depth band.');

        z_recon_min = max(3e-3,0.15*focus_z);
        z_recon_max = max(1.35*focus_z,z_high+2e-3);

        % ---------------------------------------------------------------
        % Matched conventional FI
        % ---------------------------------------------------------------
        copt = struct();
        copt.z_min = z_recon_min;
        copt.z_max = z_recon_max;
        copt.n_z = n_z;
        copt.receive_aperture_mode = 'f_number';
        copt.receive_f_number = 1.7;
        copt.tx_time_offsets = [];  % explicitly NO correction
        copt.verbose = false;

        conv = reconstruct_fi_scanline_manual( ...
            filename,copt,cd);

        % ---------------------------------------------------------------
        % Uncorrected blended RTB
        % ---------------------------------------------------------------
        ropt = struct();
        ropt.z_min = z_recon_min;
        ropt.z_max = z_recon_max;
        ropt.n_z = n_z;
        ropt.x_upsample = x_upsample;

        ropt.tx_delay_model = 'blended';
        ropt.blending_power = 0.5;

        ropt.tx_f_number = 2;
        ropt.tx_min_aperture = 3e-3;
        ropt.tx_window = 'tukey25';

        ropt.rx_aperture_mode = 'f_number';
        ropt.rx_f_number = 1.7;

        ropt.wave_stride = 1;
        ropt.normalize_tx_weights = true;
        ropt.tx_time_offsets = [];  % explicitly NO correction
        ropt.verbose = false;

        rtb = reconstruct_fi_rtb_manual( ...
            filename,ropt,cd);

        % ---------------------------------------------------------------
        % Put conventional envelope on RTB x grid for matched statistics.
        % This is ONLY statistical interpolation, not RTB.
        % ---------------------------------------------------------------
        conv_env = interp1( ...
            conv.x_axis, ...
            conv.envelope.', ...
            rtb.x_axis, ...
            'linear',nan).';

        depth_mask = ...
            rtb.z_axis >= z_low & ...
            rtb.z_axis <= z_high;

        x = rtb.x_axis;

        region_half_width = max(0.8e-3,0.025*x_span);

        left_center = x_min + 0.08*x_span;
        mid_center = (x_min+x_max)/2;
        right_center = x_max - 0.08*x_span;

        centers = [left_center mid_center right_center];

        ratio_db = nan(1,3);
        coherence = nan(1,3);

        for k = 1:3
            xm = abs(x-centers(k)) <= region_half_width;

            a = rtb.envelope(depth_mask,xm);
            b = conv_env(depth_mask,xm);
            q = rtb.tx_coherence(depth_mask,xm);

            valid = isfinite(a) & isfinite(b) & b > 0;

            ratio_db(k) = 20*log10( ...
                median(a(valid)) / ...
                median(b(valid)));

            coherence(k) = median(q(isfinite(q)));
        end

        % ---------------------------------------------------------------
        % Adjacent-Tx phase audit on common inter-scanline pixels.
        % ---------------------------------------------------------------
        phase_depths = linspace(z_low,z_high,48).';

        adjacent = adjacent_tx_correlation_generic( ...
            cd,phase_depths);

        abs_phase_deg = abs(angle(adjacent))*180/pi;

        n_pair = numel(adjacent);
        edge_n = min(16,max(4,floor(n_pair/8)));

        left_pairs = 1:edge_n;

        mid0 = floor((n_pair-edge_n)/2)+1;
        middle_pairs = mid0:(mid0+edge_n-1);

        right_pairs = (n_pair-edge_n+1):n_pair;

        phase_left = median(abs_phase_deg(left_pairs));
        phase_mid = median(abs_phase_deg(middle_pairs));
        phase_right = median(abs_phase_deg(right_pairs));

        corrmag_left = median(abs(adjacent(left_pairs)));
        corrmag_mid = median(abs(adjacent(middle_pairs)));
        corrmag_right = median(abs(adjacent(right_pairs)));

        fprintf('\nRTB/FI ratio [left | center | right] dB:\n');
        fprintf('  %.3f | %.3f | %.3f\n',ratio_db);

        fprintf('RTB Tx coherence [left | center | right]:\n');
        fprintf('  %.3f | %.3f | %.3f\n',coherence);

        fprintf('Adjacent-Tx |phase| median [left | middle | right] deg:\n');
        fprintf('  %.3f | %.3f | %.3f\n', ...
            phase_left,phase_mid,phase_right);

        fprintf('Adjacent-Tx |corr| median [left | middle | right]:\n');
        fprintf('  %.3f | %.3f | %.3f\n', ...
            corrmag_left,corrmag_mid,corrmag_right);

        summary_rows{id} = { ...
            name, ...
            cd.N_waves, ...
            cd.N_channels, ...
            pitch*1e3, ...
            focus_z*1e3, ...
            min(wdelay)*1e9, ...
            max(wdelay)*1e9, ...
            ratio_db(1),ratio_db(2),ratio_db(3), ...
            coherence(1),coherence(2),coherence(3), ...
            phase_left,phase_mid,phase_right, ...
            corrmag_left,corrmag_mid,corrmag_right};

        status_rows{id} = {name,'OK',''};

        phase_results{id} = struct( ...
            'name',name, ...
            'adjacent_correlation',adjacent, ...
            'abs_phase_deg',abs_phase_deg, ...
            'z_low',z_low, ...
            'z_high',z_high, ...
            'edge_n',edge_n);

        % ---------------------------------------------------------------
        % Per-dataset plots
        % ---------------------------------------------------------------
        fig = figure('Color','w','Position',[50 50 1400 700]);

        subplot(2,2,1);
        imagesc( ...
            conv.x_axis*1e3, ...
            conv.z_axis*1e3, ...
            to_db(conv.envelope,60));
        set(gca,'YDir','reverse');
        axis image;
        xlabel('x (mm)');
        ylabel('z (mm)');
        title('Conventional FI');
        caxis([-60 0]);
        colorbar;

        subplot(2,2,2);
        imagesc( ...
            rtb.x_axis*1e3, ...
            rtb.z_axis*1e3, ...
            to_db(rtb.envelope,60));
        set(gca,'YDir','reverse');
        axis image;
        xlabel('x (mm)');
        ylabel('z (mm)');
        title('Uncorrected blended RTB');
        caxis([-60 0]);
        colorbar;

        subplot(2,2,3);
        plot(1:n_pair, ...
            angle(adjacent)*180/pi, ...
            'LineWidth',1.2);
        yline(0,':');
        xlabel('Adjacent Tx pair index');
        ylabel('Phase (deg)');
        title(sprintf( ...
            'Adjacent-Tx phase, z %.1f-%.1f mm', ...
            z_low*1e3,z_high*1e3));
        grid on;

        subplot(2,2,4);
        plot(1:n_pair,abs(adjacent),'LineWidth',1.2);
        xlabel('Adjacent Tx pair index');
        ylabel('|correlation|');
        title('Adjacent-Tx correlation magnitude');
        ylim([0 1]);
        grid on;

        colormap gray;

        safe_name = regexprep(name,'[^A-Za-z0-9_-]','_');

        exportgraphics( ...
            fig, ...
            fullfile(output_dir,[safe_name '_audit.png']));

        close(fig);

    catch ME
        fprintf('ERROR: %s\n',ME.message);
        status_rows{id} = {name,'ERROR',ME.message};
    end
end

%% ------------------------------------------------------------------------
% Summary tables
% -------------------------------------------------------------------------
ok = ~cellfun(@isempty,summary_rows);

if any(ok)
    summary = vertcat(summary_rows{ok});

    summary_table = cell2table( ...
        summary, ...
        'VariableNames',{ ...
        'dataset', ...
        'N_waves', ...
        'N_channels', ...
        'pitch_mm', ...
        'focus_z_mm', ...
        'wave_delay_min_ns', ...
        'wave_delay_max_ns', ...
        'RTB_minus_FI_left_dB', ...
        'RTB_minus_FI_center_dB', ...
        'RTB_minus_FI_right_dB', ...
        'RTB_coherence_left', ...
        'RTB_coherence_center', ...
        'RTB_coherence_right', ...
        'adj_phase_left_deg', ...
        'adj_phase_middle_deg', ...
        'adj_phase_right_deg', ...
        'adj_corr_left', ...
        'adj_corr_middle', ...
        'adj_corr_right'});

    disp(summary_table);

    writetable( ...
        summary_table, ...
        fullfile(output_dir,'fi_timing_audit_summary.csv'));
else
    summary_table = table();
end

status_ok = ~cellfun(@isempty,status_rows);

status_table = cell2table( ...
    vertcat(status_rows{status_ok}), ...
    'VariableNames',{'dataset','status','reason'});

writetable( ...
    status_table, ...
    fullfile(output_dir,'fi_timing_audit_status.csv'));

save( ...
    fullfile(output_dir,'fi_timing_audit.mat'), ...
    'summary_table','status_table','phase_results');

fprintf('\n============================================================\n');
fprintf(' AUDIT COMPLETE\n');
fprintf('============================================================\n');
fprintf('Output directory:\n  %s\n',output_dir);

fprintf(['\nHow to interpret:\n' ...
    '  - A CIRS-like problem means the RIGHT side has much lower RTB/FI\n' ...
    '    ratio and Tx coherence, together with larger adjacent-Tx phase\n' ...
    '    drift than left/middle.\n' ...
    '  - If only CIRS shows this pattern, treat the timing correction as\n' ...
    '    dataset-specific.\n' ...
    '  - If several L7/Verasonics FI datasets show the same right-edge\n' ...
    '    pattern, investigate a shared acquisition/UFF timing convention.\n' ...
    '  - Do NOT apply the CIRS 16-element correction merely because a\n' ...
    '    different dataset is also focused imaging.\n']);

%% =========================================================================
% Helpers
% =========================================================================

function out = check_fi_compatibility(cd)

    out = struct('ok',false,'reason','');

    if abs(double(cd.modulation_frequency)) > eps
        out.reason = sprintf( ...
            'IQ/demodulated data: modulation_frequency = %.6g Hz', ...
            double(cd.modulation_frequency));
        return;
    end

    if ~isreal(cd.data)
        out.reason = 'complex channel data; current audit expects real RF';
        return;
    end

    if cd.N_waves < 8
        out.reason = 'too few Tx waves for edge timing statistics';
        return;
    end

    for iw = 1:cd.N_waves
        w = cd.sequence(iw);

        if w.wavefront ~= uff.wavefront.spherical
            out.reason = sprintf( ...
                'wave %d is not spherical focused imaging',iw);
            return;
        end

        if double(w.source.z) <= 0
            out.reason = sprintf( ...
                'wave %d has non-positive focused source depth',iw);
            return;
        end
    end

    py = double(cd.probe.y(:));
    pz = double(cd.probe.z(:));

    if max(abs(py)) > 1e-9 || max(abs(pz)) > 1e-9
        out.reason = ...
            'current audit expects a 2-D linear array in the z=0 plane';
        return;
    end

    out.ok = true;
end

function cor = adjacent_tx_correlation_generic(cd,depths)
%ADJACENT_TX_CORRELATION_GENERIC
% Correlate adjacent focused transmit events on the SAME candidate pixels.
%
% This function measures the data as stored. It fits NO timing offsets and
% applies NO correction.

    N_pair = cd.N_waves-1;

    cor = complex(zeros(N_pair,1));

    px = double(cd.probe.x(:)).';
    py = double(cd.probe.y(:)).';
    pz = double(cd.probe.z(:)).';

    c = double(cd.sound_speed);

    rf_a = analytic_rf(double(cd.data(:,:,1,1)));

    sx = arrayfun(@(w) double(w.source.x),cd.sequence(:));
    scanline_spacing = median(abs(diff(sx)));

    lateral_offsets = [-1 0 1] * ...
        max(0.25e-3,scanline_spacing);

    for iw = 1:N_pair

        rf_b = analytic_rf( ...
            double(cd.data(:,:,iw+1,1)));

        midpoint = ...
            (double(cd.sequence(iw).source.x) + ...
             double(cd.sequence(iw+1).source.x))/2;

        [xx,zz] = meshgrid( ...
            midpoint+lateral_offsets, ...
            depths);

        xx = xx(:);
        zz = zz(:);

        rx = sqrt( ...
            (xx-px).^2 + ...
            py.^2 + ...
            (zz-pz).^2) / c;

        weights = double( ...
            abs(xx-px) <= zz/(2*1.7));

        a = beam_samples( ...
            rf_a,cd,iw,xx,zz,rx,weights);

        b = beam_samples( ...
            rf_b,cd,iw+1,xx,zz,rx,weights);

        denom = sqrt( ...
            sum(abs(a).^2) * ...
            sum(abs(b).^2));

        cor(iw) = ...
            sum(conj(a).*b) / ...
            max(denom,realmin);

        rf_a = rf_b;
    end
end

function values = beam_samples( ...
    rf,cd,iw,x,z,rx,weights)

    w = cd.sequence(iw);

    sx = double(w.source.x);
    sz = double(w.source.z);

    distance = sqrt( ...
        (x-sx).^2 + ...
        (z-sz).^2);

    distance(z<sz) = -distance(z<sz);

    tx = ...
        (double(w.source.distance)+distance) ...
        / double(w.sound_speed) ...
        - double(w.delay);

    u = ...
        (tx+rx-double(cd.initial_time)) ...
        * double(cd.sampling_frequency) + 1;

    i0 = floor(u);
    fraction = u-i0;

    valid = ...
        i0 >= 1 & ...
        i0 < size(rf,1);

    ch = repmat( ...
        1:size(rf,2), ...
        size(u,1),1);

    samples = complex(zeros(size(u)));

    if any(valid(:))
        ind = sub2ind( ...
            size(rf), ...
            i0(valid), ...
            ch(valid));

        samples(valid) = ...
            (1-fraction(valid)).*rf(ind) + ...
            fraction(valid).*rf(ind+1);
    end

    values = sum(weights.*samples,2);
end

function rf = analytic_rf(rf)

    n = size(rf,1);

    h = zeros(n,1);
    h(1) = 1;

    if mod(n,2)==0
        h(2:n/2) = 2;
        h(n/2+1) = 1;
    else
        h(2:(n+1)/2) = 2;
    end

    rf = ifft( ...
        fft(rf,[],1).*h, ...
        [],1);
end

function db = to_db(env,dynamic_range)

    db = 20*log10( ...
        env/(max(env(:))+eps) + eps);

    db(db < -dynamic_range) = ...
        -dynamic_range;
end
