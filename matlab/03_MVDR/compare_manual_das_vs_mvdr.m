%% compare_manual_das_vs_mvdr.m
% Chapter 3 - One-click 2-D Manual DAS vs MVDR/Capon comparison.
%
% Default dataset:
%   L7_FI_TheGB.uff
%
% Default MVDR:
%   receive-domain conventional FI
%   Rx F#              = 1.7
%   subarray fraction  = 0.5
%   diagonal loading   = 0.01
%   forward-backward   = false
%
% This is the main Chapter-3 principle demo:
%   aligned aperture -> covariance -> MVDR weights -> full 2-D image.
%
% Run:
%   addpath(genpath('D:/USTB'));
%   cd matlab/03_MVDR
%   compare_manual_das_vs_mvdr

clearvars -except filename n_z z_min z_max ...
    receive_f_number subarray_fraction diagonal_loading ...
    axial_averaging_lambda forward_backward;
clc;
close all;

if ~exist('filename','var')
    filename = '../../data/L7_FI_TheGB.uff';
end
if ~exist('n_z','var')
    n_z = 256;
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
% The script allows scalar overrides from the base workspace.  However,
% experiment_mvdr_tradeoffs leaves vector-valued sweep variables named
% subarray_fraction / diagonal_loading behind.  Those vectors are not valid
% for this one-shot comparison, so reset non-scalar leftovers to defaults.
if ~exist('subarray_fraction','var') || ...
        ~isnumeric(subarray_fraction) || ...
        ~isscalar(subarray_fraction) || ...
        ~isfinite(subarray_fraction)
    subarray_fraction = 0.5;
end
if ~exist('diagonal_loading','var') || ...
        ~isnumeric(diagonal_loading) || ...
        ~isscalar(diagonal_loading) || ...
        ~isfinite(diagonal_loading)
    diagonal_loading = 0.01;
end
if ~exist('axial_averaging_lambda','var') || ...
        ~isnumeric(axial_averaging_lambda) || ...
        ~isscalar(axial_averaging_lambda) || ...
        ~isfinite(axial_averaging_lambda) || ...
        axial_averaging_lambda < 0
    axial_averaging_lambda = 1.5;
end
if ~exist('forward_backward','var') || ...
        ~isscalar(forward_backward) || ...
        ~(islogical(forward_backward) || isnumeric(forward_backward))
    forward_backward = false;
end

opts = struct();
opts.z_min = z_min;
opts.z_max = z_max;
opts.n_z = n_z;
opts.receive_aperture_mode = 'f_number';
opts.receive_f_number = receive_f_number;
opts.subarray_fraction = subarray_fraction;
opts.diagonal_loading = diagonal_loading;
opts.axial_averaging_lambda = axial_averaging_lambda;
opts.forward_backward = forward_backward;
opts.display_dynamic_range_db = 60;
opts.verbose = true;

fprintf('============================================================\n');
fprintf(' MANUAL DAS vs MVDR / CAPON\n');
fprintf('============================================================\n');
fprintf('dataset             : %s\n',filename);
fprintf('n_z                 : %d\n',n_z);
fprintf('Rx F#               : %.3f\n',receive_f_number);
fprintf('subarray fraction   : %.3f\n',subarray_fraction);
fprintf('diagonal loading    : %.4f\n',diagonal_loading);
fprintf('axial averaging     : %.2f lambda half-window\n', ...
    axial_averaging_lambda);
fprintf('forward-backward    : %d\n\n',forward_backward);

tic;
out = reconstruct_fi_mvdr_manual(filename,opts);
elapsed = toc;

fprintf('\nRuntime: %.2f s\n',elapsed);

fprintf('Active Rx count: median %.1f, range [%d,%d]\n', ...
    median(out.active_channel_count(:)), ...
    min(out.active_channel_count(:)), ...
    max(out.active_channel_count(:)));

fprintf('Subarray L: median %.1f, range [%d,%d]\n', ...
    median(out.subarray_length_map(:)), ...
    min(out.subarray_length_map(:)), ...
    max(out.subarray_length_map(:)));

das_peak = max(out.das_envelope(:));
mv_peak = max(out.mvdr_envelope(:));

fprintf('MVDR global peak vs DAS global peak: %.3f dB\n', ...
    20*log10(mv_peak/(das_peak+eps)+eps));

%% Main common-reference figure
figure('Color','w','Position',[80 80 1250 600]);

subplot(1,2,1);
imagesc(out.x_axis*1e3,out.z_axis*1e3,out.das_db);
set(gca,'YDir','reverse');
axis image;
xlabel('x (mm)');
ylabel('z (mm)');
title('Manual DAS');
caxis([-60 0]);
colorbar;

subplot(1,2,2);
imagesc(out.x_axis*1e3,out.z_axis*1e3,out.mvdr_db_common);
set(gca,'YDir','reverse');
axis image;
xlabel('x (mm)');
ylabel('z (mm)');
title('Manual MVDR / Capon (same DAS reference)');
caxis([-60 0]);
colorbar;

colormap gray;

sgtitle({ ...
    'Chapter 3: receive-domain MVDR / Capon', ...
    sprintf('L/M=%.2f, loading=%.3g, axial avg=%.2f lambda', ...
        subarray_fraction,diagonal_loading,axial_averaging_lambda)});

%% Self-normalized morphology comparison
figure('Color','w','Position',[120 120 1250 600]);

subplot(1,2,1);
imagesc(out.x_axis*1e3,out.z_axis*1e3,out.das_db);
set(gca,'YDir','reverse');
axis image;
xlabel('x (mm)');
ylabel('z (mm)');
title('DAS, self-normalized');
caxis([-60 0]);
colorbar;

subplot(1,2,2);
imagesc(out.x_axis*1e3,out.z_axis*1e3,out.mvdr_db_self);
set(gca,'YDir','reverse');
axis image;
xlabel('x (mm)');
ylabel('z (mm)');
title('MVDR, self-normalized');
caxis([-60 0]);
colorbar;

colormap gray;

sgtitle('Use common-reference image for amplitude; self-normalized image for morphology');

fprintf('\nInterpretation:\n');
fprintf(['  DAS uses fixed equal weights after delay alignment.\n' ...
         '  MVDR estimates a covariance matrix from overlapping receive\n' ...
         '  subarrays and computes data-adaptive channel weights.\n']);
fprintf(['  The distortionless constraint preserves a perfectly aligned focal\n' ...
         '  signal, while the minimum-variance objective suppresses energy\n' ...
         '  inconsistent with that steering vector.\n']);
fprintf(['  A sharper / darker MVDR image is not by itself proof of universally\n' ...
         '  better image quality; robustness depends strongly on covariance\n' ...
         '  estimation, subarray size, diagonal loading and model mismatch.\n']);
