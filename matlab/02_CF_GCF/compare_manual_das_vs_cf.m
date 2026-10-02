%% compare_manual_das_vs_cf.m
% Chapter 2 - Full-image Manual DAS vs receive-domain CF.
%
% This script:
%   1) reconstructs DAS + CF with reconstruct_fi_cf_manual();
%   2) independently reconstructs the Chapter-1 DAS reference;
%   3) verifies both DAS paths agree;
%   4) displays:
%        - ordinary DAS
%        - CF map
%        - CF-weighted DAS with the SAME amplitude reference
%   5) also shows a self-normalized DAS/CF pair to compare morphology.
%
% Run:
%   addpath(genpath('D:/USTB'));
%   addpath('../01_DAS_Real_UFF');
%   cd matlab/02_CF_GCF
%   compare_manual_das_vs_cf

clearvars -except filename z_min z_max n_z receive_f_number;
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

assert(~isempty(which('reconstruct_fi_scanline_manual')), ...
    ['Chapter-1 reconstruct_fi_scanline_manual.m not found. ' ...
     'Add matlab/01_DAS_Real_UFF to the path.']);

opts = struct();
opts.z_min = z_min;
opts.z_max = z_max;
opts.n_z = n_z;
opts.receive_aperture_mode = 'f_number';
opts.receive_f_number = receive_f_number;
opts.verbose = true;

fprintf('============================================================\n');
fprintf(' MANUAL DAS vs RECEIVE-DOMAIN CF\n');
fprintf('============================================================\n');

%% 1. Chapter-2 CF reconstruction
tic;
cf = reconstruct_fi_cf_manual(filename,opts);
t_cf = toc;

%% 2. Independent Chapter-1 DAS baseline
opts_ref = opts;
opts_ref.verbose = false;

tic;
das_ref = reconstruct_fi_scanline_manual(filename,opts_ref);
t_ref = toc;

%% 3. Verify the DAS path is unchanged
delta = cf.das_analytic - das_ref.das_analytic;

max_abs_error = max(abs(delta(:)));
reference_scale = max(abs(das_ref.das_analytic(:)));

scaled_error = ...
    max_abs_error/(reference_scale+eps);

fprintf('\nDAS consistency check\n');
fprintf('  max abs complex error : %.6e\n',max_abs_error);
fprintf('  max-peak scaled error : %.6e\n',scaled_error);

assert(scaled_error < 1e-10, ...
    ['Chapter-2 DAS path does not reproduce Chapter-1 baseline. ' ...
     'Scaled error = %.3e'], ...
    scaled_error);

fprintf('\nRuntime\n');
fprintf('  Chapter-2 DAS+CF : %.2f s\n',t_cf);
fprintf('  Chapter-1 DAS    : %.2f s\n',t_ref);

fprintf('\nCF map statistics\n');
fprintf('  min    : %.6f\n',min(cf.cf_map(:)));
fprintf('  median : %.6f\n',median(cf.cf_map(:)));
fprintf('  mean   : %.6f\n',mean(cf.cf_map(:)));
fprintf('  max    : %.6f\n',max(cf.cf_map(:)));

%% 4. Main teaching figure: same amplitude reference
figure('Color','w','Position',[70 70 1550 620]);

subplot(1,3,1);
imagesc(cf.x_axis*1e3,cf.z_axis*1e3,cf.das_db);
set(gca,'YDir','reverse');
axis image;
xlabel('x (mm)');
ylabel('z (mm)');
title('Manual DAS');
caxis([-60 0]);
colorbar;

subplot(1,3,2);
imagesc(cf.x_axis*1e3,cf.z_axis*1e3,cf.cf_map);
set(gca,'YDir','reverse');
axis image;
xlabel('x (mm)');
ylabel('z (mm)');
title('Receive-domain CF map');
caxis([0 1]);
colorbar;

subplot(1,3,3);
imagesc(cf.x_axis*1e3,cf.z_axis*1e3,cf.cf_db_common);
set(gca,'YDir','reverse');
axis image;
xlabel('x (mm)');
ylabel('z (mm)');
title('DAS × CF (same DAS amplitude reference)');
caxis([-60 0]);
colorbar;

colormap gray;

sgtitle({ ...
    'Manual receive-domain Coherence Factor', ...
    'Right image uses the SAME amplitude reference as DAS'});

%% 5. Morphology-only comparison: each image self-normalized
figure('Color','w','Position',[120 100 1100 560]);

subplot(1,2,1);
imagesc(cf.x_axis*1e3,cf.z_axis*1e3,cf.das_db);
set(gca,'YDir','reverse');
axis image;
xlabel('x (mm)');
ylabel('z (mm)');
title('DAS, self-normalized');
caxis([-60 0]);
colorbar;

subplot(1,2,2);
imagesc(cf.x_axis*1e3,cf.z_axis*1e3,cf.cf_db_self);
set(gca,'YDir','reverse');
axis image;
xlabel('x (mm)');
ylabel('z (mm)');
title('DAS × CF, self-normalized');
caxis([-60 0]);
colorbar;

colormap gray;

sgtitle({ ...
    'Self-normalized comparison', ...
    'Use this figure for morphology; do NOT use it to judge absolute suppression'});

%% 6. Interpretation reminder
fprintf('\nInterpretation:\n');
fprintf(['  - The CF map is NOT a B-mode image; it is a per-pixel coherence weight.\n' ...
         '  - The common-reference figure shows how much CF suppresses each pixel.\n' ...
         '  - The self-normalized figure emphasizes morphology but hides global attenuation.\n' ...
         '  - A visually narrower bright structure after CF is an apparent/adaptive\n' ...
         '    narrowing; it is not automatically proof of improved physical resolution.\n']);
