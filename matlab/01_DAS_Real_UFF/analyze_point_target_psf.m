%% analyze_point_target_psf.m
% Chapter 1 - quantitative PSF analysis on the REAL FI-DAS image.
%
% Purpose:
%   - select an isolated point target;
%   - locate its local image peak;
%   - extract lateral and axial amplitude profiles;
%   - measure -6 dB amplitude FWHM in both directions;
%   - report how many image samples span each measured width.
%
% Why interactive selection?
%   This is an experimental CIRS dataset. If UFF phantom ground-truth
%   coordinates are absent, the script should not pretend to know which
%   bright object is a calibration point. The user selects the target,
%   and the code refines the location to the local maximum.
%
% No Image Processing Toolbox is required.
%
% Example:
%   addpath(genpath('D:/USTB'));
%   cd matlab/01_DAS_Real_UFF
%   filename = '../../data/L7_FI_Verasonics_CIRS_points.uff';
%   analyze_point_target_psf
%
% Optional non-interactive use:
%   target_x_mm = -5.5;
%   target_z_mm = 38.6;
%   analyze_point_target_psf

clearvars -except filename target_x_mm target_z_mm z_min z_max n_z frame_index;
clc;
close all;

if ~exist('filename','var')
    filename = '../../data/L7_FI_Verasonics_CIRS_points.uff';
end

%% ------------------------------------------------------------------------
% 1. Reconstruct the manual conventional FI-DAS image
% -------------------------------------------------------------------------
fprintf('============================================================\n');
fprintf(' POINT-TARGET PSF ANALYSIS\n');
fprintf('============================================================\n');

opts = struct();
opts.z_min = z_min;
opts.z_max = z_max;
opts.n_z = n_z;
opts.frame_index = frame_index;
opts.receive_aperture_mode = 'full';
opts.receive_f_number = 1.7;
opts.display_dynamic_range_db = 60;
opts.verbose = true;

result = reconstruct_fi_scanline_manual(filename,opts);

envelope = result.envelope;
image_db = result.image_db;
x_axis = result.x_axis;
z_axis = result.z_axis;

% Work with normalized linear envelope, not the clipped dB image.
env = envelope / (max(envelope(:)) + eps);

dx_median = median(abs(diff(x_axis)));
dz_median = median(abs(diff(z_axis)));

fprintf('\nImage sampling:\n');
fprintf('  median lateral spacing dx = %.6f mm\n', dx_median*1e3);
fprintf('  median axial spacing   dz = %.6f mm\n', dz_median*1e3);

%% ------------------------------------------------------------------------
% 2. Select a point target
% -------------------------------------------------------------------------
figure('Color','w');
imagesc(x_axis*1e3, z_axis*1e3, image_db);
set(gca,'YDir','reverse');
axis image;
xlabel('x (mm)');
ylabel('z (mm)');
title({'Select one isolated point target', ...
       'Click near its center; local peak will be refined automatically'});
colorbar;
caxis([-60 0]);
colormap gray;

if exist('target_x_mm','var') && exist('target_z_mm','var')
    x_click = target_x_mm * 1e-3;
    z_click = target_z_mm * 1e-3;
    hold on;
    plot(target_x_mm, target_z_mm, 'ro', 'MarkerSize',8, 'LineWidth',1.5);
else
    [x_click_mm,z_click_mm] = ginput(1);
    x_click = x_click_mm * 1e-3;
    z_click = z_click_mm * 1e-3;
end

%% ------------------------------------------------------------------------
% 3. Refine to local maximum
% -------------------------------------------------------------------------
% Search only near the selected object. This avoids accidentally jumping
% to another brighter target elsewhere in the image.
search_half_x = 1.2e-3;   % [m]
search_half_z = 1.5e-3;   % [m]

ix_roi = find(abs(x_axis - x_click) <= search_half_x);
iz_roi = find(abs(z_axis - z_click) <= search_half_z);

assert(~isempty(ix_roi) && ~isempty(iz_roi), ...
    'Selected point is outside the reconstructed image.');

local_env = env(iz_roi,ix_roi);
[~,local_idx] = max(local_env(:));
[local_iz,local_ix] = ind2sub(size(local_env),local_idx);

iz_peak = iz_roi(local_iz);
ix_peak = ix_roi(local_ix);

x_peak = x_axis(ix_peak);
z_peak = z_axis(iz_peak);
peak_value = env(iz_peak,ix_peak);

fprintf('\nSelected / refined target:\n');
fprintf('  click        : x = %.4f mm, z = %.4f mm\n', ...
    x_click*1e3, z_click*1e3);
fprintf('  local peak   : x = %.4f mm, z = %.4f mm\n', ...
    x_peak*1e3, z_peak*1e3);
fprintf('  image level  : %.3f dB relative to global image peak\n', ...
    20*log10(peak_value + eps));

%% ------------------------------------------------------------------------
% 4. Optional UFF phantom ground truth
% -------------------------------------------------------------------------
has_gt = false;

if ~isempty(result.phantom_points)

    pts = result.phantom_points;

    % Only compare geometry here; Gamma is not needed for nearest-point
    % matching. Restrict to approximately the x-z imaging plane.
    plane_mask = abs(pts(:,2)) < 1e-6;

    if any(plane_mask)
        pts2 = pts(plane_mask,:);
        distance_xz = sqrt( ...
            (pts2(:,1)-x_peak).^2 + ...
            (pts2(:,3)-z_peak).^2);

        [gt_distance,idx_gt] = min(distance_xz);
        gt = pts2(idx_gt,:);

        fprintf('\nUFF phantom metadata detected:\n');
        fprintf('  nearest GT point : x = %.4f mm, z = %.4f mm\n', ...
            gt(1)*1e3, gt(3)*1e3);
        fprintf('  peak-to-GT offset: %.4f mm\n', gt_distance*1e3);

        has_gt = true;
    end
end

if ~has_gt
    fprintf('\nUFF phantom ground truth: not available / not usable.\n');
    fprintf(['  The selected image peak is therefore treated as the PSF center,\n' ...
             '  not as independently verified physical target coordinates.\n']);
end

%% ------------------------------------------------------------------------
% 5. Extract lateral / axial profiles through the refined peak
% -------------------------------------------------------------------------
lateral = env(iz_peak,:);
axial = env(:,ix_peak);

% Normalize each profile to the selected target peak rather than the
% global image peak.
lateral = lateral / (lateral(ix_peak) + eps);
axial = axial / (axial(iz_peak) + eps);

[fwhm_x, x_left, x_right] = measure_fwhm_around_peak( ...
    x_axis, lateral, ix_peak);

[fwhm_z, z_top, z_bottom] = measure_fwhm_around_peak( ...
    z_axis, axial, iz_peak);

fprintf('\n-6 dB amplitude FWHM:\n');
fprintf('  lateral FWHM : %.6f mm\n', fwhm_x*1e3);
fprintf('  axial FWHM   : %.6f mm\n', fwhm_z*1e3);

fprintf('\nSampling support across measured FWHM:\n');
fprintf('  lateral width / dx : %.3f samples\n', fwhm_x/dx_median);
fprintf('  axial width / dz   : %.3f samples\n', fwhm_z/dz_median);

if fwhm_x/dx_median < 3
    warning(['Lateral FWHM spans fewer than 3 scanline intervals. ' ...
        'The width estimate is therefore strongly limited by conventional ' ...
        'FI lateral sampling. This is one motivation for studying RTB.']);
end

if fwhm_z/dz_median < 3
    warning(['Axial FWHM spans fewer than 3 z samples. ' ...
        'Increase n_z before interpreting the axial width quantitatively.']);
end

%% ------------------------------------------------------------------------
% 6. Plot profiles
% -------------------------------------------------------------------------
lat_db = 20*log10(abs(lateral) + eps);
ax_db = 20*log10(abs(axial) + eps);

lat_db(lat_db < -60) = -60;
ax_db(ax_db < -60) = -60;

figure('Color','w');
plot(x_axis*1e3,lat_db,'LineWidth',1.5);
hold on;
yline(-6.0206,'--','-6 dB amplitude');
xline(x_left*1e3,':');
xline(x_right*1e3,':');
xlabel('Lateral position x (mm)');
ylabel('Amplitude relative to selected target peak (dB)');
title(sprintf('Lateral PSF profile at z = %.4f mm | FWHM = %.4f mm', ...
    z_peak*1e3,fwhm_x*1e3));
ylim([-60 3]);
grid on;

% Zoom around the selected target to avoid distant phantom structures
% dominating visual interpretation.
xlim([x_peak-5e-3,x_peak+5e-3]*1e3);

figure('Color','w');
plot(z_axis*1e3,ax_db,'LineWidth',1.5);
hold on;
yline(-6.0206,'--','-6 dB amplitude');
xline(z_top*1e3,':');
xline(z_bottom*1e3,':');
xlabel('Depth z (mm)');
ylabel('Amplitude relative to selected target peak (dB)');
title(sprintf('Axial PSF profile at x = %.4f mm | FWHM = %.4f mm', ...
    x_peak*1e3,fwhm_z*1e3));
ylim([-60 3]);
grid on;
xlim([z_peak-3e-3,z_peak+3e-3]*1e3);

%% ------------------------------------------------------------------------
% 7. Show local 2-D ROI
% -------------------------------------------------------------------------
roi_half_x = 3e-3;
roi_half_z = 2e-3;

ix_plot = find(abs(x_axis-x_peak) <= roi_half_x);
iz_plot = find(abs(z_axis-z_peak) <= roi_half_z);

figure('Color','w');
imagesc( ...
    x_axis(ix_plot)*1e3, ...
    z_axis(iz_plot)*1e3, ...
    image_db(iz_plot,ix_plot));
set(gca,'YDir','reverse');
axis image;
xlabel('x (mm)');
ylabel('z (mm)');
title('Selected point-target ROI');
caxis([-60 0]);
colorbar;
colormap gray;
hold on;
plot(x_peak*1e3,z_peak*1e3,'r+','MarkerSize',10,'LineWidth',1.5);

fprintf('\nInterpretation note:\n');
fprintf(['  Axial FWHM is typically sampled much more densely here than lateral\n' ...
         '  FWHM because conventional FI has one output x position per\n' ...
         '  transmit scanline. Do not over-interpret sub-scanline lateral\n' ...
         '  precision from this conventional image.\n']);

%% =========================================================================
% Local functions
% =========================================================================
function [width,x_left,x_right] = measure_fwhm_around_peak(x,y,peak_idx)
%MEASURE_FWHM_AROUND_PEAK Width at 0.5 amplitude around a known peak.
%
% Uses linear interpolation between adjacent samples for the threshold
% crossings. It assumes y(peak_idx) has been normalized to approximately 1.

    level = 0.5;

    left_below = find(y(1:peak_idx) < level,1,'last');
    right_rel = find(y(peak_idx:end) < level,1,'first');

    assert(~isempty(left_below), ...
        'Could not find the left -6 dB crossing.');
    assert(~isempty(right_rel), ...
        'Could not find the right -6 dB crossing.');

    right_below = peak_idx + right_rel - 1;

    assert(left_below < peak_idx && right_below > peak_idx, ...
        'Invalid FWHM crossing geometry.');

    x_left = crossing_linear( ...
        x(left_below), y(left_below), ...
        x(left_below+1), y(left_below+1), level);

    x_right = crossing_linear( ...
        x(right_below-1), y(right_below-1), ...
        x(right_below), y(right_below), level);

    width = x_right - x_left;
end

function xc = crossing_linear(x0,y0,x1,y1,level)
    assert(abs(y1-y0) > eps, ...
        'Threshold crossing is numerically degenerate.');

    xc = x0 + (level-y0)*(x1-x0)/(y1-y0);
end
