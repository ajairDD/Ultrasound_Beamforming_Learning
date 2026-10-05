%% compare_rtb_das_vs_rtb_mvdr.m
% Chapter 3 - One-click RTB-DAS vs RTB + receive-MVDR.
%
% PURPOSE
% -------
% This is the clean comparison requested after conventional-FI MVDR:
%
%   same RTB Tx model / grid / Tx weights / Rx F#
%        |
%        +--> receive DAS
%        |
%        +--> receive MVDR
%        |
%   same coherent cross-Tx RTB combination
%
% Therefore the difference is attributable to receive-domain MVDR rather
% than to RTB itself.
%
% Default test is a dense ROI around the known TheGB point target near
% x=-0.745 mm, z=20.1 mm. This avoids the coarse lateral sampling of
% conventional one-Tx/one-scanline FI.
%
% Run:
%   addpath(genpath('D:/USTB'));
%   cd matlab/03_MVDR
%   compare_rtb_das_vs_rtb_mvdr
%
% Full-frame RTB+MVDR is intentionally NOT the default because this
% transparent MATLAB implementation is computationally expensive.

clearvars -except filename x_min x_max n_x z_min z_max n_z ...
    subarray_fraction diagonal_loading axial_averaging_lambda ...
    forward_backward run_rtb_reference_check;
clc;
close all;

if ~exist('filename','var')
    filename = '../../data/L7_FI_TheGB.uff';
end
if ~exist('x_min','var')
    x_min = -4e-3;
end
if ~exist('x_max','var')
    x_max = 3e-3;
end
if ~exist('n_x','var')
    n_x = 141;
end
if ~exist('z_min','var')
    z_min = 18e-3;
end
if ~exist('z_max','var')
    z_max = 22.5e-3;
end
if ~exist('n_z','var')
    n_z = 181;
end
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
        ~isfinite(axial_averaging_lambda)
    axial_averaging_lambda = 1.5;
end
if ~exist('forward_backward','var') || ...
        ~isscalar(forward_backward)
    forward_backward = false;
end
if ~exist('run_rtb_reference_check','var') || ...
        ~isscalar(run_rtb_reference_check)
    run_rtb_reference_check = true;
end

% Chapter-1 RTB core is used only as a reference check.
if isempty(which('reconstruct_fi_rtb_manual'))
    addpath('../01_DAS_Real_UFF');
end

opts = struct();

opts.z_min = z_min;
opts.z_max = z_max;
opts.n_z = n_z;

opts.x_min = x_min;
opts.x_max = x_max;
opts.n_x = n_x;

opts.tx_delay_model = 'blended';
opts.pw_margin = 1e-3;
opts.blending_power = 0.5;
opts.tx_f_number = 2;
opts.tx_min_aperture = 3e-3;
opts.tx_window = 'tukey25';

opts.rx_aperture_mode = 'f_number';
opts.rx_f_number = 1.7;

opts.wave_stride = 1;
opts.normalize_tx_weights = true;

opts.subarray_fraction = subarray_fraction;
opts.diagonal_loading = diagonal_loading;
opts.axial_averaging_lambda = axial_averaging_lambda;
opts.forward_backward = forward_backward;

opts.display_dynamic_range_db = 60;
opts.verbose = true;

fprintf('============================================================\n');
fprintf(' RTB-DAS vs RTB + RECEIVE-MVDR\n');
fprintf('============================================================\n');

tic;
out = reconstruct_fi_rtb_mvdr_manual(filename,opts);
runtime_s = toc;

fprintf('\nRuntime: %.2f s\n',runtime_s);

%% ------------------------------------------------------------------------
% 1. Verify RTB-DAS branch against the already validated Chapter-1 core
% -------------------------------------------------------------------------
if run_rtb_reference_check

    assert(~isempty(which('reconstruct_fi_rtb_manual')), ...
        'Chapter-1 reconstruct_fi_rtb_manual was not found.');

    ref_opts = struct();

    ref_opts.z_min = z_min;
    ref_opts.z_max = z_max;
    ref_opts.n_z = n_z;

    ref_opts.x_min = x_min;
    ref_opts.x_max = x_max;
    ref_opts.n_x = n_x;

    ref_opts.tx_delay_model = opts.tx_delay_model;
    ref_opts.pw_margin = opts.pw_margin;
    ref_opts.blending_power = opts.blending_power;
    ref_opts.tx_f_number = opts.tx_f_number;
    ref_opts.tx_min_aperture = opts.tx_min_aperture;
    ref_opts.tx_window = opts.tx_window;

    ref_opts.rx_aperture_mode = opts.rx_aperture_mode;
    ref_opts.rx_f_number = opts.rx_f_number;

    ref_opts.wave_stride = opts.wave_stride;
    ref_opts.normalize_tx_weights = opts.normalize_tx_weights;

    ref_opts.display_dynamic_range_db = 60;
    ref_opts.verbose = false;

    fprintf('\nChecking RTB-DAS branch against Chapter-1 RTB core ...\n');

    ref = reconstruct_fi_rtb_manual(filename,ref_opts);

    delta = out.rtb_das_analytic-ref.rtb_analytic;

    err = max(abs(delta(:)));
    scale = max(abs(ref.rtb_analytic(:)));

    scaled_error = err/(scale+eps);

    fprintf('  max abs complex error : %.6e\n',err);
    fprintf('  max-peak scaled error : %.6e\n',scaled_error);

    assert(scaled_error < 1e-10, ...
        'RTB-DAS branch does not reproduce Chapter-1 RTB.');
end

%% ------------------------------------------------------------------------
% 2. Point-target metrics
% -------------------------------------------------------------------------
target_x = -0.745e-3;
target_z = 20.10e-3;

x = out.x_axis;
z = out.z_axis;

das_env = out.rtb_das_envelope;
mv_env = out.rtb_mvdr_envelope;

ix_roi = find(abs(x-target_x) <= 1.0e-3);
iz_roi = find(abs(z-target_z) <= 1.0e-3);

assert(~isempty(ix_roi) && ~isempty(iz_roi), ...
    'Default point-target ROI is outside the selected RTB grid.');

[iz_das,ix_das] = local_peak(das_env,iz_roi,ix_roi);
[iz_mv,ix_mv] = local_peak(mv_env,iz_roi,ix_roi);

peak_das = das_env(iz_das,ix_das);
peak_mv = mv_env(iz_mv,ix_mv);

das_lat = das_env(iz_das,:)/(peak_das+eps);
das_ax = das_env(:,ix_das)/(peak_das+eps);

mv_lat = mv_env(iz_mv,:)/(peak_mv+eps);
mv_ax = mv_env(:,ix_mv)/(peak_mv+eps);

das_fwhm_x = measure_width_around_peak( ...
    x,das_lat,ix_das,0.5);
das_fwhm_z = measure_width_around_peak( ...
    z,das_ax,iz_das,0.5);
das_w20_x = measure_width_around_peak( ...
    x,das_lat,ix_das,0.1);

mv_fwhm_x = measure_width_around_peak( ...
    x,mv_lat,ix_mv,0.5);
mv_fwhm_z = measure_width_around_peak( ...
    z,mv_ax,iz_mv,0.5);
mv_w20_x = measure_width_around_peak( ...
    x,mv_lat,ix_mv,0.1);

dx = median(abs(diff(x)));
dz = median(abs(diff(z)));

fprintf('\nPoint-target metrics\n');
fprintf('------------------------------------------------------------\n');

fprintf('RTB-DAS peak x,z       : %.4f mm, %.4f mm\n', ...
    x(ix_das)*1e3,z(iz_das)*1e3);
fprintf('RTB-MVDR peak x,z      : %.4f mm, %.4f mm\n', ...
    x(ix_mv)*1e3,z(iz_mv)*1e3);

fprintf('MVDR peak vs DAS       : %.3f dB\n', ...
    20*log10(peak_mv/(peak_das+eps)+eps));

fprintf('\n');
fprintf('                     RTB-DAS      RTB-MVDR\n');
fprintf('lateral FWHM mm     %10.4f    %10.4f\n', ...
    das_fwhm_x*1e3,mv_fwhm_x*1e3);
fprintf('axial FWHM mm       %10.4f    %10.4f\n', ...
    das_fwhm_z*1e3,mv_fwhm_z*1e3);
fprintf('lateral -20dB mm    %10.4f    %10.4f\n', ...
    das_w20_x*1e3,mv_w20_x*1e3);

fprintf('\nSampling context\n');
fprintf('  lateral spacing       : %.6f mm\n',dx*1e3);
fprintf('  axial spacing         : %.6f mm\n',dz*1e3);
fprintf('  DAS FWHM / dx         : %.3f samples\n',das_fwhm_x/dx);
fprintf('  MVDR FWHM / dx        : %.3f samples\n',mv_fwhm_x/dx);

fprintf('\nMVDR fallback count\n');
fprintf('  fallback / attempted  : %d / %d (%.3f%%)\n', ...
    out.mvdr_fallback_count, ...
    out.mvdr_pixel_count, ...
    100*out.mvdr_fallback_count/max(1,out.mvdr_pixel_count));

%% ------------------------------------------------------------------------
% 3. Common-reference images
% -------------------------------------------------------------------------
figure('Color','w','Position',[60 60 1250 620]);

subplot(1,2,1);
imagesc(x*1e3,z*1e3,out.rtb_das_db);
set(gca,'YDir','reverse');
axis image;
xlabel('x (mm)');
ylabel('z (mm)');
title('RTB-DAS');
caxis([-60 0]);
colorbar;

subplot(1,2,2);
imagesc(x*1e3,z*1e3,out.rtb_mvdr_db_common);
set(gca,'YDir','reverse');
axis image;
xlabel('x (mm)');
ylabel('z (mm)');
title('RTB + receive-MVDR (same RTB-DAS reference)');
caxis([-60 0]);
colorbar;

colormap gray;

sgtitle({ ...
    'Same RTB geometry; only receive combination changes', ...
    sprintf('L/M=%.2f, loading=%.3g, axial avg=%.2f lambda', ...
        subarray_fraction,diagonal_loading,axial_averaging_lambda)});

%% ------------------------------------------------------------------------
% 4. Self-normalized morphology + lateral profile
% -------------------------------------------------------------------------
figure('Color','w','Position',[80 80 1250 620]);

subplot(1,2,1);

plot(x*1e3,clip_db(das_lat,60),'LineWidth',1.8);
hold on;
plot(x*1e3,clip_db(mv_lat,60),'LineWidth',1.8);

yline(-6.0206,'--','-6 dB');
yline(-20,':','-20 dB');

xlabel('x (mm)');
ylabel('Amplitude relative to each method peak (dB)');

title('Point-target lateral profile');
legend('RTB-DAS','RTB-MVDR','Location','best');
xlim((target_x+[-2 2]*1e-3)*1e3);
ylim([-60 3]);
grid on;

subplot(1,2,2);

imagesc(x*1e3,z*1e3,out.rtb_mvdr_db_self);
set(gca,'YDir','reverse');
axis image;

xlabel('x (mm)');
ylabel('z (mm)');
title('RTB-MVDR, self-normalized');

caxis([-60 0]);
colorbar;
colormap gray;

sgtitle('Use the profile to judge whether MVDR is now laterally sampled');

fprintf('\nInterpretation boundary\n');
fprintf(['  If RTB-MVDR becomes narrow but still spans several lateral pixels,\n' ...
         '  the earlier one-scanline appearance was mainly conventional-FI\n' ...
         '  lateral undersampling.\n']);
fprintf(['  If RTB-MVDR remains pathological on this dense grid, inspect the\n' ...
         '  covariance / steering assumptions rather than claiming a\n' ...
         '  physical resolution gain.\n']);

%% =========================================================================
% Helpers
% =========================================================================
function [iz_peak,ix_peak] = local_peak(env,iz_roi,ix_roi)

    local = env(iz_roi,ix_roi);

    [~,idx] = max(local(:));
    [lz,lx] = ind2sub(size(local),idx);

    iz_peak = iz_roi(lz);
    ix_peak = ix_roi(lx);
end

function width = measure_width_around_peak(x,y,peak_idx,level)

    left_below = find(y(1:peak_idx) < level,1,'last');
    right_rel = find(y(peak_idx:end) < level,1,'first');

    if isempty(left_below) || isempty(right_rel)
        width = NaN;
        return;
    end

    right_below = peak_idx+right_rel-1;

    if left_below >= peak_idx || right_below <= peak_idx
        width = NaN;
        return;
    end

    x_left = crossing_linear( ...
        x(left_below),y(left_below), ...
        x(left_below+1),y(left_below+1),level);

    x_right = crossing_linear( ...
        x(right_below-1),y(right_below-1), ...
        x(right_below),y(right_below),level);

    width = x_right-x_left;
end

function xc = crossing_linear(x0,y0,x1,y1,level)

    if abs(y1-y0) <= eps
        xc = 0.5*(x0+x1);
        return;
    end

    xc = x0 + ...
        (level-y0)*(x1-x0)/(y1-y0);
end

function db = clip_db(profile,dynamic_range)

    db = 20*log10(abs(profile)+eps);
    db(db < -dynamic_range) = -dynamic_range;
end
