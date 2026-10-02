%% compare_manual_das_cf_gcf.m
% Chapter 2 - Full-image comparison: DAS vs CF vs GCF.
%
% This script reconstructs:
%
%   1) ordinary DAS
%   2) receive-domain CF
%   3) receive-domain GCF
%
% on the SAME conventional-FI data and SAME delay / interpolation / aperture
% definitions.
%
% Default:
%   GCF M0 = 1
%
% Scientific/teaching convention:
%
%   M0 = 0 -> DC only -> ordinary CF
%   M0 = 1 -> bins {-1,0,+1}
%   M0 = 2 -> bins {-2,-1,0,+1,+2}
%
% Run:
%   addpath(genpath('D:/USTB'));
%   cd matlab/02_CF_GCF
%   compare_manual_das_cf_gcf

clearvars -except filename z_min z_max n_z receive_f_number M0;
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
if ~exist('M0','var')
    M0 = 1;
end

common = struct();
common.z_min = z_min;
common.z_max = z_max;
common.n_z = n_z;
common.receive_aperture_mode = 'f_number';
common.receive_f_number = receive_f_number;
common.display_dynamic_range_db = 60;
common.verbose = true;

fprintf('============================================================\n');
fprintf(' MANUAL DAS vs CF vs GCF\n');
fprintf('============================================================\n');
fprintf('GCF M0 = %d\n\n',M0);

%% 1. CF
cf = reconstruct_fi_cf_manual(filename,common);

%% 2. GCF
gopts = common;
gopts.M0 = M0;

gcf = reconstruct_fi_gcf_manual(filename,gopts);

%% 3. Verify both cores use the same DAS baseline
delta = cf.das_analytic-gcf.das_analytic;

max_abs_error = max(abs(delta(:)));
reference_scale = max(abs(cf.das_analytic(:)));

scaled_error = ...
    max_abs_error/(reference_scale+eps);

fprintf('DAS consistency check: CF core vs GCF core\n');
fprintf('  max abs complex error : %.6e\n',max_abs_error);
fprintf('  max-peak scaled error : %.6e\n',scaled_error);

assert(scaled_error < 1e-10, ...
    'CF and GCF cores do not reproduce the same DAS baseline.');

%% 4. Important identity: DC-only GCF must equal ordinary CF
check_opts = common;
check_opts.M0 = 0;
check_opts.verbose = false;

gcf_dc = reconstruct_fi_gcf_manual(filename,check_opts);

cf_gcf_dc_error = ...
    max(abs(cf.cf_map(:)-gcf_dc.gcf_map(:)));

fprintf('\nIdentity check\n');
fprintf('  max |CF - GCF(M0=0)| : %.6e\n', ...
    cf_gcf_dc_error);

assert(cf_gcf_dc_error < 1e-10, ...
    'DC-only GCF does not reproduce ordinary CF.');

%% 5. Statistics
fprintf('\nCF statistics\n');
fprintf('  median : %.6f\n',median(cf.cf_map(:)));
fprintf('  mean   : %.6f\n',mean(cf.cf_map(:)));
fprintf('  max    : %.6f\n',max(cf.cf_map(:)));

fprintf('\nGCF statistics, M0=%d\n',M0);
fprintf('  median : %.6f\n',median(gcf.gcf_map(:)));
fprintf('  mean   : %.6f\n',mean(gcf.gcf_map(:)));
fprintf('  max    : %.6f\n',max(gcf.gcf_map(:)));

%% 6. Common-reference image comparison
figure('Color','w','Position',[40 70 1650 620]);

subplot(1,3,1);
imagesc(cf.x_axis*1e3,cf.z_axis*1e3,cf.das_db);
set(gca,'YDir','reverse');
axis image;
xlabel('x (mm)');
ylabel('z (mm)');
title('DAS');
caxis([-60 0]);
colorbar;

subplot(1,3,2);
imagesc(cf.x_axis*1e3,cf.z_axis*1e3,cf.cf_db_common);
set(gca,'YDir','reverse');
axis image;
xlabel('x (mm)');
ylabel('z (mm)');
title('DAS × CF');
caxis([-60 0]);
colorbar;

subplot(1,3,3);
imagesc(gcf.x_axis*1e3,gcf.z_axis*1e3,gcf.gcf_db_common);
set(gca,'YDir','reverse');
axis image;
xlabel('x (mm)');
ylabel('z (mm)');
title(sprintf('DAS × GCF, M0=%d',M0));
caxis([-60 0]);
colorbar;

colormap gray;

sgtitle({ ...
    'Same DAS amplitude reference for all images', ...
    'Use this figure to compare actual suppression'});

%% 7. Weight maps
figure('Color','w','Position',[100 100 1150 560]);

subplot(1,2,1);
imagesc(cf.x_axis*1e3,cf.z_axis*1e3,cf.cf_map);
set(gca,'YDir','reverse');
axis image;
xlabel('x (mm)');
ylabel('z (mm)');
title('CF map');
caxis([0 1]);
colorbar;

subplot(1,2,2);
imagesc(gcf.x_axis*1e3,gcf.z_axis*1e3,gcf.gcf_map);
set(gca,'YDir','reverse');
axis image;
xlabel('x (mm)');
ylabel('z (mm)');
title(sprintf('GCF map, M0=%d',M0));
caxis([0 1]);
colorbar;

colormap gray;

sgtitle('Receive-domain coherence weights');

%% 8. GCF minus CF
figure('Color','w','Position',[150 120 900 600]);

imagesc( ...
    cf.x_axis*1e3, ...
    cf.z_axis*1e3, ...
    gcf.gcf_map-cf.cf_map);

set(gca,'YDir','reverse');
axis image;

xlabel('x (mm)');
ylabel('z (mm)');
title(sprintf('GCF(M0=%d) - CF weight',M0));
colorbar;

fprintf('\nInterpretation:\n');
fprintf(['  CF is the strict DC-only coherence weight.\n' ...
         '  GCF admits a small low-spatial-frequency band.\n' ...
         '  Therefore GCF is usually less aggressive than CF, but the\n' ...
         '  amount depends on M0 and the actual aperture spectra.\n']);
fprintf(['  Larger M0 is not automatically better: it also admits more\n' ...
         '  incoherent / high-spatial-frequency energy.\n']);
