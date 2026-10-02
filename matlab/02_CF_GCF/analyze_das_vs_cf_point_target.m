%% analyze_das_vs_cf_point_target.m
% Chapter 2 - Point-target analysis: DAS vs receive-domain CF.
%
% PURPOSE
% -------
% Quantify what CF changes on one isolated point-like target.
%
% This script compares:
%   - local peak location;
%   - target peak amplitude using a COMMON DAS reference;
%   - lateral -6 dB FWHM;
%   - axial -6 dB FWHM;
%   - lateral / axial -20 dB widths;
%   - how many image samples span each measured width.
%
% IMPORTANT INTERPRETATION
% ------------------------
% A narrower CF-weighted profile is an adaptive/apparent narrowing.
% It does NOT by itself prove that the physical diffraction-limited
% resolution of the acquisition has improved.
%
% Conventional FI has one x sample per Tx scanline, so lateral width
% estimates can be strongly limited by scanline spacing.
%
% Run:
%   addpath(genpath('D:/USTB'));
%   cd matlab/02_CF_GCF
%   analyze_das_vs_cf_point_target
%
% Optional non-interactive use:
%   target_x_mm = ...;
%   target_z_mm = ...;
%   analyze_das_vs_cf_point_target

clearvars -except filename target_x_mm target_z_mm ...
    z_min z_max n_z receive_f_number;
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
    n_z = 1024;
end
if ~exist('receive_f_number','var')
    receive_f_number = 1.7;
end

opts = struct();
opts.z_min = z_min;
opts.z_max = z_max;
opts.n_z = n_z;
opts.receive_aperture_mode = 'f_number';
opts.receive_f_number = receive_f_number;
opts.display_dynamic_range_db = 60;
opts.verbose = true;

fprintf('============================================================\n');
fprintf(' DAS vs CF POINT-TARGET ANALYSIS\n');
fprintf('============================================================\n');

result = reconstruct_fi_cf_manual(filename,opts);

x = result.x_axis;
z = result.z_axis;

das_env = result.das_envelope;
cf_env = result.cf_envelope;

dx = median(abs(diff(x)));
dz = median(abs(diff(z)));

%% ------------------------------------------------------------------------
% 1. Select one isolated point target on DAS
% -------------------------------------------------------------------------
figure('Color','w');
imagesc(x*1e3,z*1e3,result.das_db);
set(gca,'YDir','reverse');
axis image;
xlabel('x (mm)');
ylabel('z (mm)');
title({'Select one isolated point-like target', ...
       'Local DAS and CF peaks will be refined independently'});
caxis([-60 0]);
colorbar;
colormap gray;

if exist('target_x_mm','var') && exist('target_z_mm','var')
    x_click = target_x_mm*1e-3;
    z_click = target_z_mm*1e-3;
    hold on;
    plot(target_x_mm,target_z_mm,'o','MarkerSize',9,'LineWidth',1.5);
else
    [x_click_mm,z_click_mm] = ginput(1);
    x_click = x_click_mm*1e-3;
    z_click = z_click_mm*1e-3;
end

%% ------------------------------------------------------------------------
% 2. Refine local peak independently for DAS and CF
% -------------------------------------------------------------------------
search_half_x = 1.2e-3;
search_half_z = 1.5e-3;

ix_roi = find(abs(x-x_click) <= search_half_x);
iz_roi = find(abs(z-z_click) <= search_half_z);

assert(~isempty(ix_roi) && ~isempty(iz_roi), ...
    'Selected target is outside the image.');

[iz_das,ix_das] = local_peak(das_env,iz_roi,ix_roi);
[iz_cf,ix_cf] = local_peak(cf_env,iz_roi,ix_roi);

x_das = x(ix_das);
z_das = z(iz_das);

x_cf = x(ix_cf);
z_cf = z(iz_cf);

peak_das = das_env(iz_das,ix_das);
peak_cf = cf_env(iz_cf,ix_cf);

peak_change_db = 20*log10(peak_cf/(peak_das+eps)+eps);

fprintf('\nLocal peak positions\n');
fprintf('  DAS : x %.4f mm, z %.4f mm\n',x_das*1e3,z_das*1e3);
fprintf('  CF  : x %.4f mm, z %.4f mm\n',x_cf*1e3,z_cf*1e3);
fprintf('  shift: dx %.4f mm, dz %.4f mm\n', ...
    (x_cf-x_das)*1e3,(z_cf-z_das)*1e3);

fprintf('\nTarget peak amplitude\n');
fprintf('  CF vs DAS local peak, common linear scale: %.3f dB\n', ...
    peak_change_db);

fprintf('  CF weight at DAS peak: %.6f\n', ...
    result.cf_map(iz_das,ix_das));

%% ------------------------------------------------------------------------
% 3. Profiles through each method's own local peak
%
% Each profile is normalized to that method's own local target peak.
% This isolates morphology from absolute attenuation.
% -------------------------------------------------------------------------
das_lat = das_env(iz_das,:) / (peak_das+eps);
das_ax = das_env(:,ix_das) / (peak_das+eps);

cf_lat = cf_env(iz_cf,:) / (peak_cf+eps);
cf_ax = cf_env(:,ix_cf) / (peak_cf+eps);

% -6 dB amplitude => 0.5 amplitude
[das_fwhm_x,das_xL6,das_xR6] = ...
    measure_width_around_peak(x,das_lat,ix_das,0.5);

[cf_fwhm_x,cf_xL6,cf_xR6] = ...
    measure_width_around_peak(x,cf_lat,ix_cf,0.5);

[das_fwhm_z,das_zT6,das_zB6] = ...
    measure_width_around_peak(z,das_ax,iz_das,0.5);

[cf_fwhm_z,cf_zT6,cf_zB6] = ...
    measure_width_around_peak(z,cf_ax,iz_cf,0.5);

% -20 dB amplitude => 0.1 amplitude
[das_w20_x,~,~] = ...
    measure_width_around_peak(x,das_lat,ix_das,0.1);

[cf_w20_x,~,~] = ...
    measure_width_around_peak(x,cf_lat,ix_cf,0.1);

[das_w20_z,~,~] = ...
    measure_width_around_peak(z,das_ax,iz_das,0.1);

[cf_w20_z,~,~] = ...
    measure_width_around_peak(z,cf_ax,iz_cf,0.1);

fprintf('\n-6 dB amplitude FWHM\n');
fprintf('  lateral DAS : %.6f mm  (%.3f scanline intervals)\n', ...
    das_fwhm_x*1e3,das_fwhm_x/dx);
fprintf('  lateral CF  : %.6f mm  (%.3f scanline intervals)\n', ...
    cf_fwhm_x*1e3,cf_fwhm_x/dx);
fprintf('  axial DAS   : %.6f mm  (%.3f z samples)\n', ...
    das_fwhm_z*1e3,das_fwhm_z/dz);
fprintf('  axial CF    : %.6f mm  (%.3f z samples)\n', ...
    cf_fwhm_z*1e3,cf_fwhm_z/dz);

fprintf('\n-20 dB amplitude width\n');
fprintf('  lateral DAS : %.6f mm\n',das_w20_x*1e3);
fprintf('  lateral CF  : %.6f mm\n',cf_w20_x*1e3);
fprintf('  axial DAS   : %.6f mm\n',das_w20_z*1e3);
fprintf('  axial CF    : %.6f mm\n',cf_w20_z*1e3);

if das_fwhm_x/dx < 3 || cf_fwhm_x/dx < 3
    warning(['At least one lateral FWHM spans fewer than 3 conventional ' ...
        'FI scanline intervals. Treat the lateral-width comparison as ' ...
        'sampling-limited, not high-precision resolution metrology.']);
end

%% ------------------------------------------------------------------------
% 4. Plot normalized lateral profiles
% -------------------------------------------------------------------------
das_lat_db = clip_db(das_lat,60);
cf_lat_db = clip_db(cf_lat,60);

figure('Color','w','Position',[100 100 900 550]);

plot(x*1e3,das_lat_db,'LineWidth',1.5);
hold on;
plot(x*1e3,cf_lat_db,'LineWidth',1.5);

yline(-6.0206,'--','-6 dB');
yline(-20,':','-20 dB');

xline(das_xL6*1e3,':');
xline(das_xR6*1e3,':');
xline(cf_xL6*1e3,'--');
xline(cf_xR6*1e3,'--');

xlabel('Lateral position x (mm)');
ylabel('Amplitude relative to each method''s target peak (dB)');
title(sprintf( ...
    'Lateral target profile | DAS FWHM %.3f mm | CF FWHM %.3f mm', ...
    das_fwhm_x*1e3,cf_fwhm_x*1e3));

legend('DAS','DAS × CF','Location','best');
ylim([-60 3]);
xlim([x_click-5e-3,x_click+5e-3]*1e3);
grid on;

%% ------------------------------------------------------------------------
% 5. Plot normalized axial profiles
% -------------------------------------------------------------------------
das_ax_db = clip_db(das_ax,60);
cf_ax_db = clip_db(cf_ax,60);

figure('Color','w','Position',[120 120 900 550]);

plot(z*1e3,das_ax_db,'LineWidth',1.5);
hold on;
plot(z*1e3,cf_ax_db,'LineWidth',1.5);

yline(-6.0206,'--','-6 dB');
yline(-20,':','-20 dB');

xline(das_zT6*1e3,':');
xline(das_zB6*1e3,':');
xline(cf_zT6*1e3,'--');
xline(cf_zB6*1e3,'--');

xlabel('Depth z (mm)');
ylabel('Amplitude relative to each method''s target peak (dB)');
title(sprintf( ...
    'Axial target profile | DAS FWHM %.3f mm | CF FWHM %.3f mm', ...
    das_fwhm_z*1e3,cf_fwhm_z*1e3));

legend('DAS','DAS × CF','Location','best');
ylim([-60 3]);
xlim([z_click-3e-3,z_click+3e-3]*1e3);
grid on;

%% ------------------------------------------------------------------------
% 6. Local 2-D target ROI, same amplitude reference
% -------------------------------------------------------------------------
roi_half_x = 3e-3;
roi_half_z = 2e-3;

ix_plot = find(abs(x-x_click) <= roi_half_x);
iz_plot = find(abs(z-z_click) <= roi_half_z);

das_peak_global = max(das_env(:));

das_roi_db = 20*log10( ...
    das_env(iz_plot,ix_plot)/(das_peak_global+eps)+eps);

cf_roi_db = 20*log10( ...
    cf_env(iz_plot,ix_plot)/(das_peak_global+eps)+eps);

das_roi_db(das_roi_db < -60) = -60;
cf_roi_db(cf_roi_db < -60) = -60;

figure('Color','w','Position',[100 100 1100 520]);

subplot(1,2,1);
imagesc(x(ix_plot)*1e3,z(iz_plot)*1e3,das_roi_db);
set(gca,'YDir','reverse');
axis image;
xlabel('x (mm)');
ylabel('z (mm)');
title('DAS target ROI');
caxis([-60 0]);
colorbar;

subplot(1,2,2);
imagesc(x(ix_plot)*1e3,z(iz_plot)*1e3,cf_roi_db);
set(gca,'YDir','reverse');
axis image;
xlabel('x (mm)');
ylabel('z (mm)');
title('DAS × CF target ROI (same DAS reference)');
caxis([-60 0]);
colorbar;

colormap gray;

sgtitle('Point-target comparison using a common amplitude reference');

fprintf('\nInterpretation boundary\n');
fprintf(['  A reduced FWHM after CF means the adaptive weighting has narrowed\n' ...
         '  the displayed target profile. Do not automatically reinterpret\n' ...
         '  this as a change in the acquisition''s diffraction limit.\n']);
fprintf(['  The -20 dB width is included to show profile-skirt suppression;\n' ...
         '  it is not a standalone formal sidelobe metric.\n']);

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

function [width,x_left,x_right] = ...
    measure_width_around_peak(x,y,peak_idx,level)

    left_below = find(y(1:peak_idx) < level,1,'last');
    right_rel = find(y(peak_idx:end) < level,1,'first');

    assert(~isempty(left_below), ...
        'Could not find the left threshold crossing.');

    assert(~isempty(right_rel), ...
        'Could not find the right threshold crossing.');

    right_below = peak_idx + right_rel - 1;

    assert(left_below < peak_idx && right_below > peak_idx, ...
        'Invalid threshold-crossing geometry.');

    x_left = crossing_linear( ...
        x(left_below),y(left_below), ...
        x(left_below+1),y(left_below+1),level);

    x_right = crossing_linear( ...
        x(right_below-1),y(right_below-1), ...
        x(right_below),y(right_below),level);

    width = x_right-x_left;
end

function xc = crossing_linear(x0,y0,x1,y1,level)

    assert(abs(y1-y0) > eps, ...
        'Threshold crossing is numerically degenerate.');

    xc = ...
        x0 + ...
        (level-y0)*(x1-x0)/(y1-y0);
end

function db = clip_db(profile,dynamic_range)

    db = 20*log10(abs(profile)+eps);

    db(db < -dynamic_range) = -dynamic_range;
end
