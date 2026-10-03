%% analyze_carotid_cf_gcf_depth_dependence.m
% Chapter 2 - In-vivo carotid CF/GCF depth dependence.
%
% PURPOSE
% -------
% The carotid DAS/CF/GCF comparison shows much stronger suppression than
% the TheGB phantom. This script checks whether coherence weight changes
% systematically with depth.
%
% It processes:
%   L7_FI_carotid_cross_1.uff
%   L7_FI_carotid_cross_2.uff
%
% and plots, versus depth:
%
%   1) median CF / GCF weight over the central lateral field;
%   2) interquartile range of CF / GCF weight;
%   3) median DAS envelope level;
%   4) median active receive-channel count.
%
% Why central lateral field?
% --------------------------
% We exclude the outer 10% of scanlines on each side to reduce probe-edge
% aperture truncation as a confound.
%
% IMPORTANT
% ---------
% A depth trend in CF/GCF does NOT identify a unique mechanism.
% Possible contributors include:
%   - lower SNR / attenuation at depth;
%   - sound-speed mismatch / aberration;
%   - diffuse-scattering statistics;
%   - residual clutter / reverberation;
%   - aperture-size changes from dynamic F-number.
%
% Run:
%   addpath(genpath('D:/USTB'));
%   cd matlab/02_CF_GCF
%   analyze_carotid_cf_gcf_depth_dependence

clearvars -except M0 n_z z_min z_max receive_f_number;
clc;
close all;

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
    'carotid cross 1', ...
    'carotid cross 2'};

N = numel(datasets);

CF = cell(N,1);
GCF = cell(N,1);

fprintf('============================================================\n');
fprintf(' CAROTID CF/GCF DEPTH DEPENDENCE\n');
fprintf('============================================================\n');
fprintf('GCF M0 = %d\n',M0);
fprintf('Rx F#  = %.3f\n\n',receive_f_number);

base = struct();
base.z_min = z_min;
base.z_max = z_max;
base.n_z = n_z;
base.receive_aperture_mode = 'f_number';
base.receive_f_number = receive_f_number;
base.display_dynamic_range_db = 60;
base.verbose = false;

for k = 1:N

    fprintf('%s\n',dataset_names{k});

    CF{k} = reconstruct_fi_cf_manual(datasets{k},base);

    gopts = base;
    gopts.M0 = M0;

    GCF{k} = reconstruct_fi_gcf_manual(datasets{k},gopts);

    delta = CF{k}.das_analytic-GCF{k}.das_analytic;
    scale = max(abs(CF{k}.das_analytic(:)));

    assert(max(abs(delta(:)))/(scale+eps) < 1e-10, ...
        'CF and GCF DAS baselines differ.');
end

%% ------------------------------------------------------------------------
% 1. Build depth profiles
% -------------------------------------------------------------------------
profiles = cell(N,1);

for k = 1:N

    x = CF{k}.x_axis;
    z = CF{k}.z_axis;

    Nx = numel(x);

    ix1 = max(1,1+floor(0.10*Nx));
    ix2 = min(Nx,Nx-floor(0.10*Nx));

    lateral_idx = ix1:ix2;

    cf = CF{k}.cf_map(:,lateral_idx);
    gcf = GCF{k}.gcf_map(:,lateral_idx);

    das_env = CF{k}.das_envelope(:,lateral_idx);
    active_M = CF{k}.active_channel_count(:,lateral_idx);

    p = struct();

    p.z = z;
    p.x_range = [x(ix1),x(ix2)];

    p.cf_median = median(cf,2);
    p.cf_q25 = prctile(cf,25,2);
    p.cf_q75 = prctile(cf,75,2);

    p.gcf_median = median(gcf,2);
    p.gcf_q25 = prctile(gcf,25,2);
    p.gcf_q75 = prctile(gcf,75,2);

    das_med = median(das_env,2);
    p.das_median_db = ...
        20*log10(das_med/(max(das_med)+eps)+eps);

    p.active_M_median = median(active_M,2);

    profiles{k} = p;
end

%% ------------------------------------------------------------------------
% 2. Plot depth profiles
% -------------------------------------------------------------------------
figure('Color','w','Position',[80 60 1400 900]);

for k = 1:N

    p = profiles{k};

    % -------------------------------------------------------------
    % Weight profile
    % -------------------------------------------------------------
    subplot(N,2,(k-1)*2+1);
    hold on;

    fill( ...
        [p.cf_q25; flipud(p.cf_q75)], ...
        [p.z; flipud(p.z)]*1e3, ...
        0.85*ones(1,3), ...
        'EdgeColor','none', ...
        'FaceAlpha',0.45);

    fill( ...
        [p.gcf_q25; flipud(p.gcf_q75)], ...
        [p.z; flipud(p.z)]*1e3, ...
        0.65*ones(1,3), ...
        'EdgeColor','none', ...
        'FaceAlpha',0.35);

    plot(p.cf_median,p.z*1e3,'LineWidth',1.6);
    plot(p.gcf_median,p.z*1e3,'LineWidth',1.6);

    set(gca,'YDir','reverse');

    xlabel('Coherence weight');
    ylabel('z (mm)');
    xlim([0 1]);
    ylim([z_min z_max]*1e3);

    title(sprintf('%s | CF/GCF vs depth',dataset_names{k}));
    legend('CF IQR','GCF IQR','CF median','GCF median', ...
        'Location','best');
    grid on;

    % -------------------------------------------------------------
    % DAS level + active aperture
    % -------------------------------------------------------------
    subplot(N,2,(k-1)*2+2);

    yyaxis left;
    plot(p.das_median_db,p.z*1e3,'LineWidth',1.5);
    xlabel('Median DAS envelope (dB, depth-profile normalized)');
    ylabel('z (mm)');
    xlim([-60 0]);

    yyaxis right;
    plot(p.active_M_median,p.z*1e3,'LineWidth',1.5);
    xlabel('Median DAS level / active Rx count');
    ylabel('z (mm)');

    set(gca,'YDir','reverse');
    ylim([z_min z_max]*1e3);

    title(sprintf('%s | signal level and active aperture',dataset_names{k}));
    grid on;
end

sgtitle({ ...
    'In-vivo carotid: depth dependence of receive coherence', ...
    'Central 80% lateral field; outer scanlines excluded'});

%% ------------------------------------------------------------------------
% 3. Depth-band summary
% -------------------------------------------------------------------------
bands_mm = [ ...
     5 15; ...
    15 25; ...
    25 35; ...
    35 45];

for k = 1:N

    p = profiles{k};

    fprintf('\n============================================================\n');
    fprintf('%s\n',dataset_names{k});
    fprintf('central lateral x range: %.2f to %.2f mm\n', ...
        p.x_range(1)*1e3,p.x_range(2)*1e3);
    fprintf('============================================================\n');

    for b = 1:size(bands_mm,1)

        z1 = bands_mm(b,1)*1e-3;
        z2 = bands_mm(b,2)*1e-3;

        iz = p.z >= z1 & p.z < z2;

        if ~any(iz)
            continue;
        end

        fprintf('%2d-%2d mm:\n',bands_mm(b,1),bands_mm(b,2));
        fprintf('  CF median across depth profile  : %.4f\n', ...
            median(p.cf_median(iz)));
        fprintf('  GCF median across depth profile : %.4f\n', ...
            median(p.gcf_median(iz)));
        fprintf('  DAS median level                : %.2f dB\n', ...
            median(p.das_median_db(iz)));
        fprintf('  active Rx median                : %.1f\n', ...
            median(p.active_M_median(iz)));
    end
end

fprintf('\nInterpretation boundary:\n');
fprintf(['  If CF/GCF fall with depth while DAS level also falls, lower SNR /\n' ...
         '  attenuation is a plausible contributor, but not a proven cause.\n']);
fprintf(['  If active-channel count changes strongly with depth, aperture size is\n' ...
         '  another confound. Do not attribute the trend to one mechanism\n' ...
         '  without a controlled experiment.\n']);
