%% experiment_gcf_m0_sweep.m
% Chapter 2 - GCF low-frequency bandwidth experiment.
%
% Compare:
%
%   M0 = 0  -> DC only -> ordinary CF
%   M0 = 1  -> {-1,0,+1}
%   M0 = 2  -> {-2,-1,0,+1,+2}
%   M0 = 4  -> {-4,...,0,...,+4}
%
% The goal is NOT to find a universal "best M0".
% The goal is to see how widening the accepted low-spatial-frequency band
% changes:
%
%   - median / mean coherence weight;
%   - background suppression;
%   - preservation of diffuse speckle;
%   - visual similarity to ordinary DAS.
%
% To keep this parameter study reasonably fast, n_z defaults to 256.
% After understanding the trend, rerun a chosen M0 at n_z=512 if desired.
%
% Run:
%   addpath(genpath('D:/USTB'));
%   cd matlab/02_CF_GCF
%   experiment_gcf_m0_sweep

clearvars -except filename z_min z_max n_z receive_f_number M0_values;
clc;
close all;

if ~exist('filename','var')
    filename = '../../data/L7_FI_TheGB.uff';
end
if ~exist('z_min','var')
    z_min = 5e-3;
end
if ~exist('z_max','var')
    z_max = 45e-3;
end
if ~exist('n_z','var')
    n_z = 256;
end
if ~exist('receive_f_number','var')
    receive_f_number = 1.7;
end
if ~exist('M0_values','var')
    M0_values = [0 1 2 4];
end

assert(all(M0_values >= 0 & M0_values == round(M0_values)), ...
    'M0_values must contain non-negative integers.');

base = struct();
base.z_min = z_min;
base.z_max = z_max;
base.n_z = n_z;
base.receive_aperture_mode = 'f_number';
base.receive_f_number = receive_f_number;
base.display_dynamic_range_db = 60;
base.verbose = false;

N = numel(M0_values);
results = cell(N,1);

stats = table( ...
    M0_values(:), ...
    zeros(N,1), ...
    zeros(N,1), ...
    zeros(N,1), ...
    zeros(N,1), ...
    'VariableNames', ...
    {'M0','min_weight','median_weight','mean_weight','max_weight'});

fprintf('============================================================\n');
fprintf(' GCF M0 SWEEP\n');
fprintf('============================================================\n');
fprintf('n_z = %d\n',n_z);
fprintf('Rx F# = %.3f\n\n',receive_f_number);

for k = 1:N

    opts = base;
    opts.M0 = M0_values(k);

    fprintf('M0 = %d ... ',opts.M0);
    tic;
    results{k} = reconstruct_fi_gcf_manual(filename,opts);
    elapsed = toc;
    fprintf('%.2f s\n',elapsed);

    w = results{k}.gcf_map(:);

    stats.min_weight(k) = min(w);
    stats.median_weight(k) = median(w);
    stats.mean_weight(k) = mean(w);
    stats.max_weight(k) = max(w);
end

disp(stats);

%% ------------------------------------------------------------------------
% 1. Common-reference GCF-weighted images
% -------------------------------------------------------------------------
n_cols = 2;
n_rows = ceil(N/n_cols);

figure('Color','w','Position',[60 60 1250 900]);

for k = 1:N

    subplot(n_rows,n_cols,k);

    imagesc( ...
        results{k}.x_axis*1e3, ...
        results{k}.z_axis*1e3, ...
        results{k}.gcf_db_common);

    set(gca,'YDir','reverse');
    axis image;

    xlabel('x (mm)');
    ylabel('z (mm)');

    if M0_values(k) == 0
        title('M0=0: DC only = CF');
    else
        title(sprintf('GCF M0=%d',M0_values(k)));
    end

    caxis([-60 0]);
    colorbar;
end

colormap gray;

sgtitle({ ...
    'GCF low-frequency bandwidth sweep', ...
    'All panels use the SAME DAS amplitude reference'});

%% ------------------------------------------------------------------------
% 2. Weight maps
% -------------------------------------------------------------------------
figure('Color','w','Position',[80 80 1250 900]);

for k = 1:N

    subplot(n_rows,n_cols,k);

    imagesc( ...
        results{k}.x_axis*1e3, ...
        results{k}.z_axis*1e3, ...
        results{k}.gcf_map);

    set(gca,'YDir','reverse');
    axis image;

    xlabel('x (mm)');
    ylabel('z (mm)');

    if M0_values(k) == 0
        title('M0=0: CF weight');
    else
        title(sprintf('GCF weight, M0=%d',M0_values(k)));
    end

    caxis([0 1]);
    colorbar;
end

colormap gray;

sgtitle('Receive-domain coherence weights');

%% ------------------------------------------------------------------------
% 3. Weight statistics versus M0
% -------------------------------------------------------------------------
figure('Color','w','Position',[150 150 900 520]);

plot( ...
    stats.M0, ...
    stats.median_weight, ...
    'o-', ...
    'LineWidth',1.5);

hold on;

plot( ...
    stats.M0, ...
    stats.mean_weight, ...
    's-', ...
    'LineWidth',1.5);

xlabel('M0');
ylabel('Coherence weight');
title('How widening the low-frequency band changes GCF weight');
legend('Median','Mean','Location','best');
ylim([0 1]);
grid on;

fprintf('\nInterpretation:\n');
fprintf(['  M0=0 is ordinary CF.\n' ...
         '  Increasing M0 admits more neighboring spatial-frequency energy.\n' ...
         '  Therefore GCF weights should be non-decreasing for a fixed pixel.\n']);
fprintf(['  A visually cleaner image at smaller M0 is not automatically a\n' ...
         '  universally better image: larger M0 intentionally preserves more\n' ...
         '  low-order aperture structure and diffuse speckle.\n']);
fprintf(['  Choose M0 only after deciding what metric matters: point-target\n' ...
         '  suppression, contrast, speckle preservation, aberration robustness,\n' ...
         '  or another task-specific criterion.\n']);
