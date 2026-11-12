%% compare_full_fov_rtb_das_vs_nsi.m
% Chapter 6 - Full-FOV RTB-DAS versus receive-domain NSI.
%
% ONE-CLICK DEFAULT:
%   TheGB phantom + first independent in-vivo carotid cross-section.
%   The second carotid acquisition is optional.
%
% Run from matlab/06_NSI:
%   addpath(genpath('D:/YOUR_USTB_PATH'));
%   compare_full_fov_rtb_das_vs_nsi
%
% All datasets: focused FI, real RF UFF, auto-detected lateral focused-Tx
% span, 5-45 mm depth, SAME RTB geometry and receive aperture for DAS/NSI.
%
% Quick full-FOV preview defaults: 257 lateral x 385 axial, Tx stride=2.
% This is enough for overall tissue morphology but NOT for measuring an
% extremely narrow NSI point-target FWHM.
%
% Optional:
%   dataset_indices = [1 2 3]; % TheGB + carotid cross 1 + cross 2
%   wave_stride = 1;           % use all 128 focused transmissions
%   n_x = 385; n_z = 513;      % denser final morphological comparison
%   dc_offset = 0.2;           % keep the prior point-target setting
%   compare_full_fov_rtb_das_vs_nsi
%
% Output:
%   Figure 1: RTB-DAS and RTB-NSI common-reference B-mode (one row/dataset).
%   Figure 2: relative NSI/DAS amplitude ratio [0,1] for meaningful DAS
%             pixels. No self-normalization or invented quantitative CR/CNR.
%   Console : peak change, foreground ratio / strong suppression fraction.
%
% NSI is bounded pointwise: 0 <= E_NSI/dc <= |RTB-DAS|.
% It is NORMAL for NSI to be much darker. Whether that is beneficial
% cannot be decided from these images alone.
%
% To avoid re-running a full RTB reconstruction twice, Chapter-1 complex
% DAS regression is disabled by default in this FULL-FOV script. It is
% available via run_rtb_reference_check=true; the point-target experiment
% compare_rtb_das_vs_nsi already includes the regression by default.

clearvars -except dataset_indices n_x n_z wave_stride dc_offset ...
    z_min z_max run_rtb_reference_check;
clc;
close all;

%% ------------------------------------------------------------------------
% 1. User-editable defaults
% -------------------------------------------------------------------------
if ~exist('dataset_indices','var') || isempty(dataset_indices)
    dataset_indices = [1 2];
end
assert(isnumeric(dataset_indices) && isvector(dataset_indices) && ...
       all(ismember(dataset_indices,[1 2 3])) && ...
       numel(unique(dataset_indices))==numel(dataset_indices), ...
    'dataset_indices must contain unique values from [1 2 3].');

if ~exist('n_x','var') || ~isnumeric(n_x) || ~isscalar(n_x) || ...
        ~isfinite(n_x) || n_x<2 || n_x~=round(n_x)
    n_x=257;
end
if ~exist('n_z','var') || ~isnumeric(n_z) || ~isscalar(n_z) || ...
        ~isfinite(n_z) || n_z<2 || n_z~=round(n_z)
    n_z=385;
end
if ~exist('wave_stride','var') || ~isnumeric(wave_stride) || ...
        ~isscalar(wave_stride) || ~isfinite(wave_stride) || ...
        wave_stride<1 || wave_stride~=round(wave_stride)
    wave_stride=2;
end
if ~exist('dc_offset','var') || ~isnumeric(dc_offset) || ...
        ~isscalar(dc_offset) || ~isfinite(dc_offset) || dc_offset<=0
    dc_offset=0.2;
end
if ~exist('z_min','var') || ~isnumeric(z_min) || ...
        ~isscalar(z_min) || ~isfinite(z_min)
    z_min=5e-3;
end
if ~exist('z_max','var') || ~isnumeric(z_max) || ...
        ~isscalar(z_max) || ~isfinite(z_max)
    z_max=45e-3;
end
if ~exist('run_rtb_reference_check','var') || ...
        ~isscalar(run_rtb_reference_check)
    run_rtb_reference_check=false;
end
assert(z_max>z_min,'z_max must exceed z_min.');

datasets = { ...
    '../../data/L7_FI_TheGB.uff', ...
    '../../data/L7_FI_carotid_cross_1.uff', ...
    '../../data/L7_FI_carotid_cross_2.uff'};

names = { ...
    'TheGB 体模', ...
    '颈动脉横断面 1', ...
    '颈动脉横断面 2'};

ncase=numel(dataset_indices);
results=cell(ncase,1);
reports=cell(ncase,1);
fig_x=cell(ncase,1);
fig_z=cell(ncase,1);

fprintf('============================================================\n');
fprintf(' Full-FOV RTB-DAS vs receive NSI\n');
fprintf('============================================================\n');
fprintf('Cases            : %s\n',mat2str(dataset_indices));
fprintf('Grid [z, x]      : [%d, %d]\n',n_z,n_x);
fprintf('Depth [mm]       : %.2f to %.2f\n',z_min*1e3,z_max*1e3);
fprintf('DC offset        : %.3f\n',dc_offset);
fprintf('Tx wave stride   : %d\n',wave_stride);
fprintf('RTB reference    : %d\n',logical(run_rtb_reference_check));

%% ------------------------------------------------------------------------
% 2. Reconstruct each independent acquisition
% -------------------------------------------------------------------------
for k=1:ncase

    id=dataset_indices(k);
    filename=datasets{id};
    label=names{id};

    assert(exist(filename,'file')==2, ...
        'Missing dataset %s (%s)',label,filename);

    opts=struct();

    opts.use_full_tx_span=true; % derive x_min/x_max from UFF source.x
    opts.n_x=n_x;
    opts.z_min=z_min;
    opts.z_max=z_max;
    opts.n_z=n_z;

    opts.dc_offset=dc_offset;
    opts.wave_stride=wave_stride;

    % Chapter-1 RTB baseline is unchanged:
    opts.tx_f_number=2;
    opts.tx_min_aperture=3e-3;
    opts.tx_window='tukey25';
    opts.blending_power=0.5;
    opts.rx_f_number=1.7;

    opts.display_dynamic_range_db=60;
    opts.verbose=true;

    fprintf('\n------------------------------------------------------------\n');
    fprintf(' Case %d/%d: %s\n',k,ncase,label);
    fprintf('------------------------------------------------------------\n');

    t_case=tic;
    out=reconstruct_fi_rtb_nsi_manual(filename,opts);
    runtime=toc(t_case);

    x=out.x_axis*1e3;
    z=out.z_axis*1e3;
    fig_x{k}=x;
    fig_z{k}=z;

    % Optional independent Chapter-1 complex RTB-DAS regression.
    scaled_error=NaN;
    if run_rtb_reference_check
        if isempty(which('reconstruct_fi_rtb_manual'))
            addpath('../01_DAS_Real_UFF');
        end
        assert(~isempty(which('reconstruct_fi_rtb_manual')), ...
            'Cannot locate Chapter-1 RTB core for regression check.');

        refopts=struct();
        refopts.x_min=out.x_axis(1);
        refopts.x_max=out.x_axis(end);
        refopts.n_x=n_x;
        refopts.z_min=z_min;
        refopts.z_max=z_max;
        refopts.n_z=n_z;
        refopts.wave_stride=wave_stride;
        refopts.tx_delay_model='blended';
        refopts.blending_power=opts.blending_power;
        refopts.tx_f_number=opts.tx_f_number;
        refopts.tx_min_aperture=opts.tx_min_aperture;
        refopts.tx_window=opts.tx_window;
        refopts.rx_aperture_mode='f_number';
        refopts.rx_f_number=opts.rx_f_number;
        refopts.normalize_tx_weights=true;
        refopts.verbose=false;
        ref=reconstruct_fi_rtb_manual(filename,refopts);
        err=out.rtb_das_analytic-ref.rtb_analytic;
        scaled_error=max(abs(err(:)))/(max(abs(ref.rtb_analytic(:)))+eps);
        fprintf('Chapter-1 RTB-DAS scaled complex error: %.6e\n', ...
            scaled_error);
        assert(scaled_error<1e-10, ...
            'Chapter-6 full-FOV DAS differs from Chapter-1 RTB core.');
    end

    das=out.das_envelope;
    nsi=out.nsi_envelope_das_scale;

    das_peak=max(das(:));
    nsi_peak=max(nsi(:));
    ratio=nsi./max(das,eps(das_peak));
    ratio=max(0,min(1,ratio));

    % Exclude display-floor and Tx-uncovered pixels from the statistics.
    foreground=out.das_db>=-40 & out.tx_weight_sum>eps;

    if any(foreground(:))
        r=ratio(foreground);
        median_ratio=median(r);
        fraction_quarter=nnz(r<0.25)/numel(r);
    else
        median_ratio=NaN;
        fraction_quarter=NaN;
    end

    peak_change_db=20*log10((nsi_peak+eps)/(das_peak+eps));

    reports{k}=struct( ...
        'dataset',label, ...
        'reference_complex_error',scaled_error, ...
        'runtime_s',runtime, ...
        'dx_mm',median(diff(x)), ...
        'dz_mm',median(diff(z)), ...
        'peak_change_db',peak_change_db, ...
        'median_ratio',median_ratio, ...
        'fraction_below_quarter',fraction_quarter, ...
        'foreground_pixel_count',nnz(foreground), ...
        'total_pixel_count',numel(foreground));

    out.ratio_map=ratio;
    out.ratio_mask=foreground;
    results{k}=out;

    fprintf('\nFULL-FOV SUMMARY: %s\n',label);
    fprintf('  runtime                     : %.2f s\n',runtime);
    fprintf('  lateral / axial spacing     : %.4f / %.4f mm\n', ...
        reports{k}.dx_mm,reports{k}.dz_mm);
    fprintf('  NSI global peak vs DAS      : %.3f dB\n',peak_change_db);
    fprintf('  foreground pixels           : %d / %d\n', ...
        reports{k}.foreground_pixel_count, ...
        reports{k}.total_pixel_count);
    fprintf('  median NSI/DAS ratio        : %.4f (DAS >= -40dB)\n', ...
        median_ratio);
    fprintf('  foreground ratio < 0.25     : %.1f%%\n', ...
        100*fraction_quarter);
end

%% ------------------------------------------------------------------------
% 3. Full-FOV common-reference images.
% Each DATASET ROW uses its OWN RTB-DAS peak as the 0-dB reference.
% Within a row, the two algorithms share that reference and dynamic range.
% -------------------------------------------------------------------------
figure('Color','w', ...
       'Position',[40 30 1500 max(600,560*ncase)], ...
       'DefaultAxesFontName','Microsoft YaHei','DefaultTextFontName','Microsoft YaHei');

for k=1:ncase
    out=results{k};
    label=reports{k}.dataset;

    subplot(ncase,2,2*k-1);
    imagesc(fig_x{k},fig_z{k},out.das_db);
    set(gca,'YDir','reverse');
    axis image;
    caxis([-60 0]);
    colormap gray;
    colorbar;
    xlabel('横向 x（mm）'); ylabel('深度 z（mm）');
    title(sprintf('%s | RTB-DAS',label));

    subplot(ncase,2,2*k);
    imagesc(fig_x{k},fig_z{k},out.nsi_db_common);
    set(gca,'YDir','reverse');
    axis image;
    caxis([-60 0]);
    colormap gray;
    colorbar;
    xlabel('横向 x（mm）'); ylabel('深度 z（mm）');
    title(sprintf('%s | RTB-NSI，δ = %.2f',label,dc_offset));
end

sgtitle({ ...
    '完整聚焦 Tx 横向范围，z = 5–45 mm；每行两图共用该数据的 DAS 参考', ...
    sprintf('Tx 步长 = %d，n_x = %d，n_z = %d；不跨数据集比较绝对亮度', ...
        wave_stride,n_x,n_z)});

%% ------------------------------------------------------------------------
% 4. Diagnostic NSI/DAS amplitude preservation ratio (NOT CNR).
% The analytic NSI construction ensures ratio in [0,1].
% -------------------------------------------------------------------------
figure('Color','w', ...
       'Position',[60 70 max(650,600*ncase) 800], ...
       'DefaultAxesFontName','Microsoft YaHei','DefaultTextFontName','Microsoft YaHei');

for k=1:ncase
    out=results{k};
    subplot(1,ncase,k);
    im=imagesc(fig_x{k},fig_z{k},out.ratio_map);
    set(im,'AlphaData',double(out.ratio_mask));
    set(gca,'Color',[0.94 0.94 0.94]);
    set(gca,'YDir','reverse');
    axis image;
    caxis([0 1]);
    colormap parula;
    colorbar;
    xlabel('横向 x（mm）'); ylabel('深度 z（mm）');
    title({reports{k}.dataset,sprintf('δ = %.2f；保留比中位数 = %.2f', ...
        dc_offset,reports{k}.median_ratio)});
end
% The caption defines the common mask; short panel titles avoid crowding.

fprintf('\n============================================================\n');
fprintf(' Interpretation\n');
fprintf('============================================================\n');
fprintf('  - Strong dark holes in NSI are expected for c=0.2, not proof of clutter removal.\n');
fprintf('  - Vessel lumen can become darker, but check BOTH vessel walls and tissue speckle.\n');
fprintf('  - TheGB phantom and carotid acquisitions use their OWN DAS 0-dB reference.\n');
fprintf('  - Quick grid/Tx stride is for morphology, not accurate NSI lateral FWHM.\n');
fprintf('  - The ratio map describes algorithm suppression, not ground-truth image quality.\n');
fprintf('\n');
fprintf('Optional second carotid acquisition: dataset_indices=[1 2 3];\n');
fprintf('Optional all-Tx run: wave_stride=1; compare_full_fov_rtb_das_vs_nsi\n');
