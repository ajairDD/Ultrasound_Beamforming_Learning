%% compare_carotid_fi_cf_gcf_oneclick.m
% Chapter 2 - One-click in-vivo carotid comparison for DAS / CF / GCF.
%
% DATASETS
% --------
%   ../../data/L7_FI_carotid_cross_1.uff
%   ../../data/L7_FI_carotid_cross_2.uff
%
% DEFAULT ALGORITHMS
% ------------------
%   DAS
%   CF          = GCF with M0 = 0
%   GCF         = M0 = 1, i.e. aperture FFT bins {-1,0,+1}
%
% PURPOSE
% -------
% Run two independent in-vivo focused-imaging carotid acquisitions through
% the SAME manual Tx/Rx delay, interpolation, receive-aperture, CF and GCF
% definitions used earlier in Chapter 2.
%
% This script requires NO manual pixel/ROI selection.
%
% It automatically:
%   1) checks that each UFF file is compatible with the current RF/FI core;
%   2) reconstructs CF and GCF;
%   3) verifies that the CF and GCF cores reproduce the same DAS baseline;
%   4) prints acquisition and coherence statistics;
%   5) plots DAS / DAS×CF / DAS×GCF for both acquisitions;
%   6) plots CF / GCF weight maps;
%   7) plots GCF-CF weight differences.
%
% IMPORTANT DISPLAY RULE
% ----------------------
% Each DATASET ROW uses that dataset's own DAS global peak as the common
% 0-dB reference for DAS, CF and GCF in that row.
%
% Do NOT compare absolute brightness between cross_1 and cross_2, because
% they are separate acquisitions.
%
% Run:
%   addpath(genpath('D:/USTB'));
%   cd matlab/02_CF_GCF
%   compare_carotid_fi_cf_gcf_oneclick
%
% Optional overrides before running:
%   M0 = 1;
%   n_z = 512;
%   z_min = 5e-3;
%   z_max = 45e-3;
%   receive_f_number = 1.7;

clearvars -except M0 n_z z_min z_max receive_f_number;
clc;
close all;

%% ------------------------------------------------------------------------
% 0. User-adjustable defaults
% -------------------------------------------------------------------------
if ~exist('M0','var')
    M0 = 1;
end
if ~exist('n_z','var')
    n_z = 512;
end
if ~exist('z_min','var')
    z_min = 5e-3;
end
if ~exist('z_max','var')
    z_max = 45e-3;
end
if ~exist('receive_f_number','var')
    receive_f_number = 1.7;
end

datasets = { ...
    '../../data/L7_FI_carotid_cross_1.uff', ...
    '../../data/L7_FI_carotid_cross_2.uff'};

dataset_names = { ...
    'L7 FI carotid cross 1', ...
    'L7 FI carotid cross 2'};

assert(~isempty(which('uff.read_object')), ...
    ['USTB / UFF reader was not found. ' ...
     'Run addpath(genpath(''YOUR_USTB_PATH'')) first.']);

assert(~isempty(which('reconstruct_fi_cf_manual')), ...
    'reconstruct_fi_cf_manual.m was not found on the MATLAB path.');

assert(~isempty(which('reconstruct_fi_gcf_manual')), ...
    'reconstruct_fi_gcf_manual.m was not found on the MATLAB path.');

assert(M0 >= 1 && M0 == round(M0), ...
    'For this comparison use an integer GCF M0 >= 1.');

N = numel(datasets);

CF = cell(N,1);
GCF = cell(N,1);
meta = cell(N,1);

summary = table( ...
    strings(N,1), ...
    zeros(N,1), ...
    zeros(N,1), ...
    zeros(N,1), ...
    zeros(N,1), ...
    zeros(N,1), ...
    zeros(N,1), ...
    zeros(N,1), ...
    zeros(N,1), ...
    zeros(N,1), ...
    'VariableNames',{ ...
        'dataset', ...
        'N_samples', ...
        'N_channels', ...
        'N_waves', ...
        'fs_MHz', ...
        'CF_median', ...
        'CF_mean', ...
        'GCF_median', ...
        'GCF_mean', ...
        'DAS_core_scaled_error'});

fprintf('============================================================\n');
fprintf(' ONE-CLICK IN-VIVO CAROTID: DAS vs CF vs GCF\n');
fprintf('============================================================\n');
fprintf('GCF M0       : %d\n',M0);
fprintf('Rx F-number  : %.3f\n',receive_f_number);
fprintf('z range      : %.1f to %.1f mm\n',z_min*1e3,z_max*1e3);
fprintf('n_z          : %d\n\n',n_z);

%% ------------------------------------------------------------------------
% 1. Process both carotid acquisitions
% -------------------------------------------------------------------------
for k = 1:N

    filename = datasets{k};

    assert(exist(filename,'file') == 2, ...
        'File not found: %s',filename);

    fprintf('------------------------------------------------------------\n');
    fprintf('%s\n',dataset_names{k});
    fprintf('------------------------------------------------------------\n');

    % Read metadata once for explicit compatibility checks.
    cd = uff.read_object(filename,'/channel_data');

    assert(abs(cd.modulation_frequency) < eps, ...
        ['Current teaching core expects real RF data. ' ...
         '%s has modulation_frequency = %.12g Hz.'], ...
        filename,cd.modulation_frequency);

    assert(isreal(cd.data), ...
        'Current teaching core expects real RF channel data: %s',filename);

    assert(cd.N_channels == cd.probe.N_elements, ...
        'N_channels does not match probe.N_elements in %s',filename);

    for iw = 1:cd.N_waves
        assert(cd.sequence(iw).wavefront == uff.wavefront.spherical, ...
            'Wave %d in %s is not spherical focused imaging.',iw,filename);

        assert(cd.sequence(iw).source.z > 0, ...
            'Wave %d in %s does not have a positive-z focused source.', ...
            iw,filename);
    end

    meta{k} = struct();
    meta{k}.N_samples = size(cd.data,1);
    meta{k}.N_channels = cd.N_channels;
    meta{k}.N_waves = cd.N_waves;
    meta{k}.fs = cd.sampling_frequency;
    meta{k}.sound_speed = cd.sound_speed;
    meta{k}.modulation_frequency = cd.modulation_frequency;

    fprintf('Metadata check passed\n');
    fprintf('  RF size      : [%d samples x %d channels x %d waves ...]\n', ...
        meta{k}.N_samples,meta{k}.N_channels,meta{k}.N_waves);
    fprintf('  fs           : %.6f MHz\n',meta{k}.fs/1e6);
    fprintf('  sound speed  : %.3f m/s\n',meta{k}.sound_speed);
    fprintf('  Tx mode      : spherical focused imaging\n');

    common = struct();
    common.z_min = z_min;
    common.z_max = z_max;
    common.n_z = n_z;
    common.receive_aperture_mode = 'f_number';
    common.receive_f_number = receive_f_number;
    common.display_dynamic_range_db = 60;
    common.verbose = false;

    fprintf('Reconstructing CF ... ');
    tic;
    CF{k} = reconstruct_fi_cf_manual(filename,common);
    fprintf('%.2f s\n',toc);

    gopts = common;
    gopts.M0 = M0;

    fprintf('Reconstructing GCF(M0=%d) ... ',M0);
    tic;
    GCF{k} = reconstruct_fi_gcf_manual(filename,gopts);
    fprintf('%.2f s\n',toc);

    % The only intended difference is the coherence weighting.
    delta = CF{k}.das_analytic-GCF{k}.das_analytic;

    max_abs_error = max(abs(delta(:)));
    reference_scale = max(abs(CF{k}.das_analytic(:)));

    scaled_error = ...
        max_abs_error/(reference_scale+eps);

    assert(scaled_error < 1e-10, ...
        ['CF and GCF cores do not reproduce the same DAS baseline for ' ...
         '%s. Scaled error = %.3e'], ...
        filename,scaled_error);

    % CF is the M0=0 special case: check it once per dataset.
    dc_opts = common;
    dc_opts.M0 = 0;

    fprintf('Checking GCF(M0=0) == CF ... ');
    GCF0 = reconstruct_fi_gcf_manual(filename,dc_opts);

    identity_error = ...
        max(abs(CF{k}.cf_map(:)-GCF0.gcf_map(:)));

    fprintf('max error %.3e\n',identity_error);

    assert(identity_error < 1e-10, ...
        'GCF(M0=0) does not reproduce CF for %s.',filename);

    summary.dataset(k) = string(dataset_names{k});
    summary.N_samples(k) = meta{k}.N_samples;
    summary.N_channels(k) = meta{k}.N_channels;
    summary.N_waves(k) = meta{k}.N_waves;
    summary.fs_MHz(k) = meta{k}.fs/1e6;

    summary.CF_median(k) = median(CF{k}.cf_map(:));
    summary.CF_mean(k) = mean(CF{k}.cf_map(:));

    summary.GCF_median(k) = median(GCF{k}.gcf_map(:));
    summary.GCF_mean(k) = mean(GCF{k}.gcf_map(:));

    summary.DAS_core_scaled_error(k) = scaled_error;

    fprintf('CF  median / mean : %.4f / %.4f\n', ...
        summary.CF_median(k),summary.CF_mean(k));

    fprintf('GCF median / mean : %.4f / %.4f\n\n', ...
        summary.GCF_median(k),summary.GCF_mean(k));
end

fprintf('============================================================\n');
fprintf(' SUMMARY TABLE\n');
fprintf('============================================================\n');
disp(summary);

%% ------------------------------------------------------------------------
% 2. DAS / CF / GCF images
%
% Each ROW uses its own DAS peak as the common reference.
% -------------------------------------------------------------------------
figure('Color','w','Position',[30 30 1650 900]);

for k = 1:N

    row_offset = (k-1)*3;

    subplot(N,3,row_offset+1);
    imagesc( ...
        CF{k}.x_axis*1e3, ...
        CF{k}.z_axis*1e3, ...
        CF{k}.das_db);
    set(gca,'YDir','reverse');
    axis image;
    xlabel('x (mm)');
    ylabel('z (mm)');
    title(sprintf('%s | DAS',dataset_names{k}));
    caxis([-60 0]);
    colorbar;

    subplot(N,3,row_offset+2);
    imagesc( ...
        CF{k}.x_axis*1e3, ...
        CF{k}.z_axis*1e3, ...
        CF{k}.cf_db_common);
    set(gca,'YDir','reverse');
    axis image;
    xlabel('x (mm)');
    ylabel('z (mm)');
    title(sprintf('%s | DAS × CF',dataset_names{k}));
    caxis([-60 0]);
    colorbar;

    subplot(N,3,row_offset+3);
    imagesc( ...
        GCF{k}.x_axis*1e3, ...
        GCF{k}.z_axis*1e3, ...
        GCF{k}.gcf_db_common);
    set(gca,'YDir','reverse');
    axis image;
    xlabel('x (mm)');
    ylabel('z (mm)');
    title(sprintf('%s | DAS × GCF, M0=%d',dataset_names{k},M0));
    caxis([-60 0]);
    colorbar;
end

colormap gray;

sgtitle({ ...
    'In-vivo focused-imaging carotid comparison', ...
    'Within each row, DAS / CF / GCF share that acquisition''s DAS 0-dB reference'});

%% ------------------------------------------------------------------------
% 3. CF / GCF weight maps
% -------------------------------------------------------------------------
figure('Color','w','Position',[60 60 1250 900]);

for k = 1:N

    row_offset = (k-1)*2;

    subplot(N,2,row_offset+1);
    imagesc( ...
        CF{k}.x_axis*1e3, ...
        CF{k}.z_axis*1e3, ...
        CF{k}.cf_map);
    set(gca,'YDir','reverse');
    axis image;
    xlabel('x (mm)');
    ylabel('z (mm)');
    title(sprintf('%s | CF map',dataset_names{k}));
    caxis([0 1]);
    colorbar;

    subplot(N,2,row_offset+2);
    imagesc( ...
        GCF{k}.x_axis*1e3, ...
        GCF{k}.z_axis*1e3, ...
        GCF{k}.gcf_map);
    set(gca,'YDir','reverse');
    axis image;
    xlabel('x (mm)');
    ylabel('z (mm)');
    title(sprintf('%s | GCF map, M0=%d',dataset_names{k},M0));
    caxis([0 1]);
    colorbar;
end

colormap gray;

sgtitle('Receive-domain coherence weights on two in-vivo acquisitions');

%% ------------------------------------------------------------------------
% 4. GCF - CF weight difference
% -------------------------------------------------------------------------
figure('Color','w','Position',[100 100 1200 520]);

for k = 1:N

    subplot(1,N,k);

    difference = GCF{k}.gcf_map-CF{k}.cf_map;

    imagesc( ...
        CF{k}.x_axis*1e3, ...
        CF{k}.z_axis*1e3, ...
        difference);

    set(gca,'YDir','reverse');
    axis image;

    xlabel('x (mm)');
    ylabel('z (mm)');
    title(sprintf('%s | GCF - CF',dataset_names{k}));

    caxis([0 1]);
    colorbar;
end

sgtitle(sprintf( ...
    'Additional low-spatial-frequency energy admitted by GCF, M0=%d',M0));

%% ------------------------------------------------------------------------
% 5. Compact interpretation prompts
% -------------------------------------------------------------------------
fprintf('\n============================================================\n');
fprintf(' WHAT TO INSPECT VISUALLY\n');
fprintf('============================================================\n');

fprintf(['1) Lumen:\n' ...
         '   Does CF reduce residual lumen clutter more strongly than GCF?\n\n']);

fprintf(['2) Vessel wall:\n' ...
         '   Does aggressive CF weighting break or thin wall continuity?\n\n']);

fprintf(['3) Tissue speckle:\n' ...
         '   Does CF strongly reshape normal tissue texture?\n' ...
         '   Does GCF(M0=%d) preserve more of that texture?\n\n'],M0);

fprintf(['4) Cross-acquisition repeatability:\n' ...
         '   Are the same qualitative CF/GCF differences visible in BOTH\n' ...
         '   carotid_cross_1 and carotid_cross_2?\n\n']);

fprintf(['Do not compare absolute brightness between the two rows. They are\n' ...
         'independent acquisitions and each row uses its own DAS reference.\n']);
