%% analyze_gcf_speckle_roi.m
% Chapter 2 - Speckle preservation versus suppression for DAS / CF / GCF.
%
% PURPOSE
% -------
% Point-target experiments showed that increasing M0 mostly changes lateral
% suppression while barely changing the coherent target peak.
%
% This experiment asks the complementary question:
%
%   What happens inside a visually homogeneous speckle region?
%
% Compare:
%   DAS
%   M0=0 -> CF
%   M0=1 -> 3-bin GCF
%   M0=2 -> 5-bin GCF
%   M0=4 -> 9-bin GCF
%
% Metrics inside a user-selected homogeneous ROI:
%
%   1) mean envelope relative to DAS       [dB]
%   2) envelope standard deviation ratio
%   3) speckle SNR = mean(envelope)/std(envelope)
%   4) coefficient of variation = std/mean
%   5) Pearson correlation with DAS envelope texture
%
% IMPORTANT
% ---------
% These metrics describe how the adaptive weighting changes the selected
% ROI. They do NOT prove that the ROI follows an ideal Rayleigh speckle
% model, and they do NOT establish diagnostic image quality.
%
% Use a reasonably homogeneous diffuse-scattering region. Avoid:
%   - point targets
%   - strong boundaries
%   - obvious cyst/lesion boundaries
%   - probe edges
%
% Run:
%   addpath(genpath('D:/USTB'));
%   cd matlab/02_CF_GCF
%   analyze_gcf_speckle_roi

clearvars -except filename z_min z_max n_z receive_f_number M0_values roi_corners_mm;
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
    n_z = 512;
end
if ~exist('receive_f_number','var')
    receive_f_number = 1.7;
end
if ~exist('M0_values','var')
    M0_values = [0 1 2 4];
end

base = struct();
base.z_min = z_min;
base.z_max = z_max;
base.n_z = n_z;
base.receive_aperture_mode = 'f_number';
base.receive_f_number = receive_f_number;
base.display_dynamic_range_db = 60;
base.verbose = false;

N = numel(M0_values);
R = cell(N,1);

fprintf('============================================================\n');
fprintf(' GCF SPECKLE-ROI ANALYSIS\n');
fprintf('============================================================\n');

for k = 1:N
    opts = base;
    opts.M0 = M0_values(k);

    fprintf('Reconstructing M0=%d ... ',opts.M0);
    tic;
    R{k} = reconstruct_fi_gcf_manual(filename,opts);
    fprintf('%.2f s\n',toc);
end

% Verify identical DAS baseline.
for k = 2:N
    err = max(abs(R{k}.das_analytic(:)-R{1}.das_analytic(:)));
    scale = max(abs(R{1}.das_analytic(:)));
    assert(err/(scale+eps) < 1e-10, ...
        'DAS baseline changed between GCF reconstructions.');
end

x = R{1}.x_axis;
z = R{1}.z_axis;
das_env = R{1}.das_envelope;

%% ------------------------------------------------------------------------
% 1. Select homogeneous ROI using two opposite corners
% -------------------------------------------------------------------------
figure('Color','w','Position',[100 100 900 700]);

imagesc(x*1e3,z*1e3,R{1}.das_db);
set(gca,'YDir','reverse');
axis image;

xlabel('x (mm)');
ylabel('z (mm)');
title({ ...
    'Select TWO opposite corners of a homogeneous speckle ROI', ...
    'Avoid point targets, strong boundaries, lesions, and probe edges'});

caxis([-60 0]);
colorbar;
colormap gray;

% For lecture export, use two reproducible [x,z] corners instead of clicks.
if exist('roi_corners_mm','var')
    assert(isequal(size(roi_corners_mm),[2 2]) && ...
        all(isfinite(roi_corners_mm(:))), ...
        'roi_corners_mm must contain two finite [x,z] corners in mm.');
    x_click_mm = roi_corners_mm(:,1);
    z_click_mm = roi_corners_mm(:,2);
else
    [x_click_mm,z_click_mm] = ginput(2);
end

x_min = min(x_click_mm)*1e-3;
x_max = max(x_click_mm)*1e-3;

z_min_roi = min(z_click_mm)*1e-3;
z_max_roi = max(z_click_mm)*1e-3;

ix = find(x >= x_min & x <= x_max);
iz = find(z >= z_min_roi & z <= z_max_roi);

assert(numel(ix) >= 5 && numel(iz) >= 5, ...
    'ROI is too small; select a larger homogeneous region.');

hold on;

rectangle( ...
    'Position',[ ...
        min(x(ix))*1e3, ...
        min(z(iz))*1e3, ...
        (max(x(ix))-min(x(ix)))*1e3, ...
        (max(z(iz))-min(z(iz)))*1e3], ...
    'EdgeColor','r', ...
    'LineWidth',1.5);

fprintf('\nSelected ROI\n');
fprintf('  x: %.3f to %.3f mm\n', ...
    min(x(ix))*1e3,max(x(ix))*1e3);
fprintf('  z: %.3f to %.3f mm\n', ...
    min(z(iz))*1e3,max(z(iz))*1e3);
fprintf('  size: %d z samples x %d scanlines = %d pixels\n', ...
    numel(iz),numel(ix),numel(iz)*numel(ix));

%% ------------------------------------------------------------------------
% 2. DAS ROI baseline
% -------------------------------------------------------------------------
das_roi = das_env(iz,ix);
das_vec = das_roi(:);

das_mean = mean(das_vec);
das_std = std(das_vec);

assert(das_mean > 0, ...
    'Selected DAS ROI has zero mean envelope.');

%% ------------------------------------------------------------------------
% 3. Metrics
% -------------------------------------------------------------------------
names = cell(N+1,1);
mean_rel_db = zeros(N+1,1);
std_ratio = zeros(N+1,1);
speckle_snr = zeros(N+1,1);
cv = zeros(N+1,1);
corr_to_das = zeros(N+1,1);

names{1} = 'DAS';
mean_rel_db(1) = 0;
std_ratio(1) = 1;
speckle_snr(1) = das_mean/(das_std+eps);
cv(1) = das_std/(das_mean+eps);
corr_to_das(1) = 1;

roi_vectors = cell(N+1,1);
roi_vectors{1} = das_vec;

for k = 1:N

    roi = R{k}.gcf_envelope(iz,ix);
    v = roi(:);

    mu = mean(v);
    sigma = std(v);

    names{k+1} = sprintf('M0=%d',M0_values(k));

    mean_rel_db(k+1) = ...
        20*log10(mu/(das_mean+eps)+eps);

    std_ratio(k+1) = ...
        sigma/(das_std+eps);

    speckle_snr(k+1) = ...
        mu/(sigma+eps);

    cv(k+1) = ...
        sigma/(mu+eps);

    C = corrcoef(das_vec,v);

    if numel(C) >= 4 && all(isfinite(C(:)))
        corr_to_das(k+1) = C(1,2);
    else
        corr_to_das(k+1) = NaN;
    end

    roi_vectors{k+1} = v;
end

metrics = table( ...
    names, ...
    mean_rel_db, ...
    std_ratio, ...
    speckle_snr, ...
    cv, ...
    corr_to_das, ...
    'VariableNames',{ ...
        'method', ...
        'mean_vs_DAS_dB', ...
        'std_vs_DAS', ...
        'speckle_SNR', ...
        'CV', ...
        'corr_with_DAS'});

disp(metrics);

%% ------------------------------------------------------------------------
% 4. Common-reference ROI images
% -------------------------------------------------------------------------
das_peak = max(das_env(:));

n_methods = N+1;
n_cols = 3;
n_rows = ceil(n_methods/n_cols);

figure('Color','w','Position',[60 60 1400 850]);

for k = 1:n_methods

    subplot(n_rows,n_cols,k);

    if k == 1
        roi = das_roi;
        title_text = 'DAS';
    else
        roi = reshape( ...
            roi_vectors{k}, ...
            size(das_roi));
        title_text = names{k};
    end

    roi_db = 20*log10(roi/(das_peak+eps)+eps);
    roi_db(roi_db < -60) = -60;

    imagesc( ...
        x(ix)*1e3, ...
        z(iz)*1e3, ...
        roi_db);

    set(gca,'YDir','reverse');
    axis image;

    xlabel('x (mm)');
    ylabel('z (mm)');
    title(title_text);

    caxis([-60 0]);
    colorbar;
end

colormap gray;

sgtitle({ ...
    'Homogeneous speckle ROI', ...
    'All panels use the same global DAS amplitude reference'});

%% ------------------------------------------------------------------------
% 5. Envelope histograms normalized by each ROI mean
%
% Mean normalization removes simple gain differences and emphasizes how
% weighting changes the ROI texture distribution.
% -------------------------------------------------------------------------
figure('Color','w','Position',[120 120 950 600]);
hold on;

edges = linspace(0,3,80);

for k = 1:n_methods

    v = roi_vectors{k};

    vn = v/(mean(v)+eps);

    histogram( ...
        vn, ...
        edges, ...
        'Normalization','pdf', ...
        'DisplayStyle','stairs', ...
        'LineWidth',1.4);
end

xlabel('Envelope / ROI mean');
ylabel('Probability density');
title('Mean-normalized envelope distribution');
legend(names,'Location','best');
xlim([0 3]);
grid on;

fprintf('\nInterpretation:\n');
fprintf(['  mean_vs_DAS_dB quantifies how strongly each method suppresses the\n' ...
         '  average envelope in the selected diffuse ROI.\n']);
fprintf(['  corr_with_DAS describes how much of the original DAS speckle texture\n' ...
         '  is preserved after adaptive weighting.\n']);
fprintf(['  speckle_SNR and CV describe ROI statistics, but do not by themselves\n' ...
         '  prove ideal Rayleigh speckle or diagnostic superiority.\n']);
