%% compare_rtb_spherical_plane_blended.m
% Chapter 1 - Why RTB needs a blended Tx-delay model.
%
% This experiment changes ONLY the Tx-delay model:
%
%   1) spherical : use the virtual-source spherical path everywhere
%   2) plane     : use the local plane approximation everywhere
%   3) blended   : use more plane behavior near focus and more spherical
%                  behavior away from focus
%
% Everything else is identical:
%   same UFF data
%   same output grid
%   same Tx F-number / Tukey window
%   same Rx F-number
%   same interpolation
%   same Tx-overlap normalization
%
% The global 'plane' mode is intentionally a teaching-only model. It is
% NOT the recommended RTB reconstruction.
%
% Run:
%   addpath(genpath('D:/USTB'));
%   cd matlab/01_DAS_Real_UFF
%   compare_rtb_spherical_plane_blended

clearvars -except filename z_min z_max n_z x_upsample;
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
    n_z = 384;
end
if ~exist('x_upsample','var')
    x_upsample = 4;
end

%% ------------------------------------------------------------------------
% 1. Common reconstruction settings
% -------------------------------------------------------------------------
base = struct();

base.z_min = z_min;
base.z_max = z_max;
base.n_z = n_z;
base.x_upsample = x_upsample;

base.blending_power = 0.5;

base.tx_f_number = 2;
base.tx_min_aperture = 3e-3;
base.tx_window = 'tukey25';

base.rx_aperture_mode = 'f_number';
base.rx_f_number = 1.7;

base.wave_stride = 1;
base.normalize_tx_weights = true;
base.display_dynamic_range_db = 60;
base.verbose = false;

models = {'spherical','plane','blended'};
labels = { ...
    'All spherical', ...
    'All plane (teaching-only)', ...
    'Blended (recommended)'};

results = cell(3,1);

%% ------------------------------------------------------------------------
% 2. Reconstruct three cases
% -------------------------------------------------------------------------
fprintf('============================================================\n');
fprintf(' RTB TX-DELAY MODEL TEACHING COMPARISON\n');
fprintf('============================================================\n');

for k = 1:3
    opts = base;
    opts.tx_delay_model = models{k};

    fprintf('Reconstructing %-10s ... ',models{k});
    tic;
    results{k} = reconstruct_fi_rtb_manual(filename,opts);
    elapsed = toc;
    fprintf('%.2f s\n',elapsed);
end

spherical = results{1};
plane = results{2};
blended = results{3};

assert(isequal(size(spherical.envelope),size(blended.envelope)), ...
    'Model outputs must share the same grid.');
assert(isequal(size(plane.envelope),size(blended.envelope)), ...
    'Model outputs must share the same grid.');

x = blended.x_axis;
z = blended.z_axis;

%% ------------------------------------------------------------------------
% 3. Normalized envelopes and simple metrics
% -------------------------------------------------------------------------
env_norm = cell(3,1);

for k = 1:3
    env_norm{k} = results{k}.envelope / ...
        (max(results{k}.envelope(:))+eps);
end

blend_vec = env_norm{3}(:);

corr_spherical = corr(env_norm{1}(:),blend_vec);
corr_plane = corr(env_norm{2}(:),blend_vec);

mae_spherical = mean(abs(env_norm{1}(:)-blend_vec));
mae_plane = mean(abs(env_norm{2}(:)-blend_vec));

focus_z = median(blended.source_z);

fprintf('\nReference: blended RTB\n');
fprintf('Median Tx focus depth : %.3f mm\n',focus_z*1e3);
fprintf('Spherical vs blended  : corr %.6f | MAE %.6e\n', ...
    corr_spherical,mae_spherical);
fprintf('Plane vs blended      : corr %.6f | MAE %.6e\n', ...
    corr_plane,mae_plane);

%% ------------------------------------------------------------------------
% 4. Figure 1 - morphology comparison
%
% Each panel is normalized to its OWN peak. This isolates morphology /
% focusing artifacts from overall gain.
% -------------------------------------------------------------------------
figure('Color','w','Position',[80 80 1600 620]);

for k = 1:3
    subplot(1,3,k);

    imagesc( ...
        x*1e3, ...
        z*1e3, ...
        to_db_self(results{k}.envelope,60));

    set(gca,'YDir','reverse');
    axis image;

    xlabel('x (mm)');
    ylabel('z (mm)');
    title(labels{k});

    caxis([-60 0]);
    colorbar;
end

colormap gray;

sgtitle({ ...
    'RTB Tx-delay model comparison', ...
    'Each image normalized to its own peak: compare morphology, not gain'});

%% ------------------------------------------------------------------------
% 5. Figure 2 - common-reference brightness comparison
%
% All three use the BLENDED peak as a common amplitude reference.
% This reveals model-dependent brightness changes that self-normalization
% can hide.
% -------------------------------------------------------------------------
ref_peak = max(blended.envelope(:));

figure('Color','w','Position',[80 80 1600 620]);

for k = 1:3
    subplot(1,3,k);

    image_db = 20*log10( ...
        results{k}.envelope/(ref_peak+eps) + eps);

    image_db(image_db < -60) = -60;
    image_db(image_db > 0) = 0;

    imagesc(x*1e3,z*1e3,image_db);

    set(gca,'YDir','reverse');
    axis image;

    xlabel('x (mm)');
    ylabel('z (mm)');
    title(labels{k});

    caxis([-60 0]);
    colorbar;
end

colormap gray;

sgtitle({ ...
    'Same amplitude reference for all three models', ...
    'Reference peak = blended RTB peak'});

%% ------------------------------------------------------------------------
% 6. Figure 3 - focal-region zoom
%
% This is the most important figure for understanding why pure spherical
% and pure plane models are both incomplete.
% -------------------------------------------------------------------------
focus_half_span = 4e-3;

z1 = max(min(z),focus_z-focus_half_span);
z2 = min(max(z),focus_z+focus_half_span);

figure('Color','w','Position',[80 80 1600 540]);

for k = 1:3
    subplot(1,3,k);

    imagesc( ...
        x*1e3, ...
        z*1e3, ...
        to_db_self(results{k}.envelope,60));

    set(gca,'YDir','reverse');
    axis image;

    ylim([z1 z2]*1e3);

    xlabel('x (mm)');
    ylabel('z (mm)');
    title(labels{k});

    caxis([-60 0]);
    colorbar;
end

colormap gray;

sgtitle(sprintf( ...
    'Zoom around median transmit focus: z_f = %.2f mm', ...
    focus_z*1e3));

%% ------------------------------------------------------------------------
% 7. Figure 4 - difference from blended
% -------------------------------------------------------------------------
figure('Color','w','Position',[100 100 1200 500]);

subplot(1,2,1);

imagesc( ...
    x*1e3, ...
    z*1e3, ...
    abs(env_norm{1}-env_norm{3}));

set(gca,'YDir','reverse');
axis image;

xlabel('x (mm)');
ylabel('z (mm)');
title('|Spherical - Blended| normalized envelope');
colorbar;

subplot(1,2,2);

imagesc( ...
    x*1e3, ...
    z*1e3, ...
    abs(env_norm{2}-env_norm{3}));

set(gca,'YDir','reverse');
axis image;

xlabel('x (mm)');
ylabel('z (mm)');
title('|Plane - Blended| normalized envelope');
colorbar;

%% ------------------------------------------------------------------------
% 8. Interpretation
% -------------------------------------------------------------------------
fprintf('\nHow to read the figures:\n');
fprintf(['  Spherical everywhere:\n' ...
         '    physically intuitive away from focus, but off-axis focal\n' ...
         '    pixels can suffer from the before/after-focus sign switch.\n']);
fprintf(['  Plane everywhere:\n' ...
         '    removes that focal sign-switch problem, but ignores lateral\n' ...
         '    wavefront curvature away from focus.\n']);
fprintf(['  Blended:\n' ...
         '    uses more local-plane behavior near the focal region and\n' ...
         '    gradually returns to spherical behavior away from it.\n']);

%% =========================================================================
% Local helper
% =========================================================================
function db = to_db_self(env,dynamic_range)

    env = env/(max(env(:))+eps);

    db = 20*log10(env+eps);

    db(db < -dynamic_range) = -dynamic_range;
end
