%% compare_receive_aperture_full_vs_fnumber.m
% Chapter 1 - compare FULL receive aperture with dynamic F-number aperture.
%
% Scientific question:
%   How much of the real-data lateral PSF is controlled by receive aperture?
%
% We keep the SAME:
%   - UFF data
%   - scanline Tx model
%   - Tx delay
%   - Rx delay
%   - interpolation
%   - z grid
%
% and change ONLY the receive aperture:
%
%   A) full aperture:
%        all receive channels active at every depth
%
%   B) dynamic F-number aperture:
%        D(z) = z / F#
%        boxcar receive aperture centered on the current scanline
%
% Default:
%   F# = 1.7
%
% Important:
%   This is OUR explicit teaching definition of a dynamic boxcar receive
%   aperture. Do not assume it is numerically identical to every scanner's
%   proprietary F-number / apodization implementation.
%
% Example:
%   addpath(genpath('D:/USTB'));
%   cd matlab/01_DAS_Real_UFF
%   filename = '../../data/L7_FI_TheGB.uff';
%
%   % Click a point target interactively, or reuse coordinates
%   % selected in analyze_point_target_psf.
%   compare_receive_aperture_full_vs_fnumber

clearvars -except filename z_min z_max n_z frame_index ...
    receive_f_number target_x_mm target_z_mm;
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

if ~exist('frame_index','var')
    frame_index = 1;
end

if ~exist('receive_f_number','var')
    receive_f_number = 1.7;
end

%% ------------------------------------------------------------------------
% 1. Run the SAME manual DAS core twice
% -------------------------------------------------------------------------
fprintf('============================================================\n');
fprintf(' RECEIVE APERTURE COMPARISON\n');
fprintf('============================================================\n');
fprintf('A: full receive aperture\n');
fprintf('B: dynamic boxcar aperture with F# = %.3f\n\n', receive_f_number);

full = run_manual_once( ...
    'full', receive_f_number, ...
    filename, z_min, z_max, n_z, frame_index);

fnum = run_manual_once( ...
    'f_number', receive_f_number, ...
    filename, z_min, z_max, n_z, frame_index);

assert(isequal(size(full.envelope),size(fnum.envelope)), ...
    'The two reconstructions have different image sizes.');

assert(max(abs(full.x_axis(:)-fnum.x_axis(:))) < 1e-12, ...
    'The two reconstructions use different x axes.');

assert(max(abs(full.z_axis(:)-fnum.z_axis(:))) < 1e-12, ...
    'The two reconstructions use different z axes.');

x_axis = full.x_axis;
z_axis = full.z_axis;

dx = median(abs(diff(x_axis)));
dz = median(abs(diff(z_axis)));

%% ------------------------------------------------------------------------
% 2. Select the same physical target for both images
% -------------------------------------------------------------------------
full_norm = full.envelope / (max(full.envelope(:)) + eps);
full_db = 20*log10(full_norm + eps);
full_db(full_db < -60) = -60;

figure('Color','w');
imagesc(x_axis*1e3,z_axis*1e3,full_db);
set(gca,'YDir','reverse');
axis image;
xlabel('x (mm)');
ylabel('z (mm)');
title({'Select one isolated point target', ...
       'The same ROI will be analyzed in both aperture settings'});
caxis([-60 0]);
colorbar;
colormap gray;

if exist('target_x_mm','var') && exist('target_z_mm','var')
    x_click = target_x_mm*1e-3;
    z_click = target_z_mm*1e-3;
    hold on;
    plot(target_x_mm,target_z_mm,'ro','MarkerSize',8,'LineWidth',1.5);
else
    [x_click_mm,z_click_mm] = ginput(1);
    x_click = x_click_mm*1e-3;
    z_click = z_click_mm*1e-3;
end

%% ------------------------------------------------------------------------
% 3. Refine local peaks independently
% -------------------------------------------------------------------------
search_half_x = 1.5e-3;
search_half_z = 1.5e-3;

full_peak = refine_local_peak( ...
    full.envelope,x_axis,z_axis,x_click,z_click, ...
    search_half_x,search_half_z);

fnum_peak = refine_local_peak( ...
    fnum.envelope,x_axis,z_axis,x_click,z_click, ...
    search_half_x,search_half_z);

%% ------------------------------------------------------------------------
% 4. Measure lateral and axial -6 dB amplitude FWHM
% -------------------------------------------------------------------------
full_metrics = measure_target_psf( ...
    full.envelope,x_axis,z_axis,full_peak.ix,full_peak.iz);

fnum_metrics = measure_target_psf( ...
    fnum.envelope,x_axis,z_axis,fnum_peak.ix,fnum_peak.iz);

%% ------------------------------------------------------------------------
% 5. Aperture geometry at the selected target
% -------------------------------------------------------------------------
iz_full = full_peak.iz;
ix_full = full_peak.ix;

iz_fnum = fnum_peak.iz;
ix_fnum = fnum_peak.ix;

n_active_full = full.active_channel_count(iz_full,ix_full);
n_active_fnum = fnum.active_channel_count(iz_fnum,ix_fnum);

physical_span = full.probe_x_max - full.probe_x_min;
dynamic_D = fnum_peak.z / receive_f_number;

fprintf('\n============================================================\n');
fprintf(' RESULT SUMMARY\n');
fprintf('============================================================\n');

fprintf('\nImage sampling:\n');
fprintf('  dx = %.6f mm\n', dx*1e3);
fprintf('  dz = %.6f mm\n', dz*1e3);

fprintf('\nSelected target neighborhood:\n');
fprintf('  click          : x = %.4f mm, z = %.4f mm\n', ...
    x_click*1e3,z_click*1e3);

fprintf('\nFULL aperture peak:\n');
fprintf('  x = %.4f mm, z = %.4f mm\n', ...
    full_peak.x*1e3,full_peak.z*1e3);
fprintf('  active channels = %d / %d\n', ...
    n_active_full,full.N_channels);
fprintf('  physical center span = %.4f mm\n', ...
    physical_span*1e3);

fprintf('\nF# aperture peak:\n');
fprintf('  x = %.4f mm, z = %.4f mm\n', ...
    fnum_peak.x*1e3,fnum_peak.z*1e3);
fprintf('  F# = %.3f\n',receive_f_number);
fprintf('  requested D(z)=z/F# = %.4f mm\n', ...
    dynamic_D*1e3);
fprintf('  active channels = %d / %d\n', ...
    n_active_fnum,fnum.N_channels);

fprintf('\n-6 dB amplitude FWHM:\n');
fprintf('  FULL lateral = %.6f mm | %.3f scanline intervals\n', ...
    full_metrics.fwhm_x*1e3,full_metrics.fwhm_x/dx);
fprintf('  F#   lateral = %.6f mm | %.3f scanline intervals\n', ...
    fnum_metrics.fwhm_x*1e3,fnum_metrics.fwhm_x/dx);
fprintf('  FULL axial   = %.6f mm | %.3f z samples\n', ...
    full_metrics.fwhm_z*1e3,full_metrics.fwhm_z/dz);
fprintf('  F#   axial   = %.6f mm | %.3f z samples\n', ...
    fnum_metrics.fwhm_z*1e3,fnum_metrics.fwhm_z/dz);

fprintf('\nExpected interpretation:\n');
fprintf(['  Reducing the receive aperture with a finite F# should mainly\n' ...
         '  broaden the lateral PSF. The axial PSF should change much less,\n' ...
         '  because axial resolution is mainly pulse/bandwidth limited.\n']);

if full_metrics.fwhm_x/dx < 3
    fprintf(['\nNOTE: the FULL-aperture lateral FWHM is sampled by fewer than\n' ...
             '3 scanline intervals, so its numerical FWHM is strongly\n' ...
             'limited by conventional-FI lateral sampling.\n']);
end

%% ------------------------------------------------------------------------
% 6. Side-by-side images
% -------------------------------------------------------------------------
fnum_norm = fnum.envelope / (max(fnum.envelope(:)) + eps);
fnum_db = 20*log10(fnum_norm + eps);
fnum_db(fnum_db < -60) = -60;

figure('Color','w');

subplot(1,2,1);
imagesc(x_axis*1e3,z_axis*1e3,full_db);
set(gca,'YDir','reverse');
axis image;
xlabel('x (mm)');
ylabel('z (mm)');
title('Full receive aperture');
caxis([-60 0]);
colorbar;

subplot(1,2,2);
imagesc(x_axis*1e3,z_axis*1e3,fnum_db);
set(gca,'YDir','reverse');
axis image;
xlabel('x (mm)');
ylabel('z (mm)');
title(sprintf('Dynamic receive aperture, F# = %.2f',receive_f_number));
caxis([-60 0]);
colorbar;
colormap gray;

%% ------------------------------------------------------------------------
% 7. Lateral PSF comparison
% -------------------------------------------------------------------------
lat_full_db = 20*log10(full_metrics.lateral + eps);
lat_fnum_db = 20*log10(fnum_metrics.lateral + eps);

lat_full_db(lat_full_db < -60) = -60;
lat_fnum_db(lat_fnum_db < -60) = -60;

figure('Color','w');
plot(x_axis*1e3,lat_full_db,'LineWidth',1.5);
hold on;
plot(x_axis*1e3,lat_fnum_db,'--','LineWidth',1.5);
yline(-6.0206,':','-6 dB amplitude');
xlabel('Lateral position x (mm)');
ylabel('Amplitude relative to each target peak (dB)');
title(sprintf('Lateral PSF comparison near z = %.3f mm', ...
    full_peak.z*1e3));
legend( ...
    sprintf('Full: FWHM %.3f mm',full_metrics.fwhm_x*1e3), ...
    sprintf('F# %.2f: FWHM %.3f mm', ...
        receive_f_number,fnum_metrics.fwhm_x*1e3), ...
    'Location','best');
ylim([-60 3]);
xlim([x_click-5e-3,x_click+5e-3]*1e3);
grid on;

%% ------------------------------------------------------------------------
% 8. Axial PSF comparison
% -------------------------------------------------------------------------
ax_full_db = 20*log10(full_metrics.axial + eps);
ax_fnum_db = 20*log10(fnum_metrics.axial + eps);

ax_full_db(ax_full_db < -60) = -60;
ax_fnum_db(ax_fnum_db < -60) = -60;

figure('Color','w');
plot(z_axis*1e3,ax_full_db,'LineWidth',1.5);
hold on;
plot(z_axis*1e3,ax_fnum_db,'--','LineWidth',1.5);
yline(-6.0206,':','-6 dB amplitude');
xlabel('Depth z (mm)');
ylabel('Amplitude relative to each target peak (dB)');
title(sprintf('Axial PSF comparison near x = %.3f mm', ...
    full_peak.x*1e3));
legend( ...
    sprintf('Full: FWHM %.3f mm',full_metrics.fwhm_z*1e3), ...
    sprintf('F# %.2f: FWHM %.3f mm', ...
        receive_f_number,fnum_metrics.fwhm_z*1e3), ...
    'Location','best');
ylim([-60 3]);
xlim([z_click-3e-3,z_click+3e-3]*1e3);
grid on;

%% =========================================================================
% Local functions
% =========================================================================

function out = run_manual_once( ...
    aperture_mode,f_number,filename,z_min,z_max,n_z,frame_index)
%RUN_MANUAL_ONCE Call the reusable DAS core with explicit inputs/outputs.
%
% Do NOT call das_fi_scanline_manual.m with run() from inside a function.
% That script is an interactive wrapper and uses clearvars. Passing data
% through the workspace is fragile and can make names such as "envelope"
% resolve to MATLAB functions instead of variables.

    opts = struct();

    opts.z_min = z_min;
    opts.z_max = z_max;
    opts.n_z = n_z;
    opts.frame_index = frame_index;

    opts.receive_aperture_mode = aperture_mode;
    opts.receive_f_number = f_number;

    opts.display_dynamic_range_db = 60;
    opts.verbose = true;

    out = reconstruct_fi_scanline_manual(filename,opts);
end

function peak = refine_local_peak( ...
    envelope,x_axis,z_axis,x_click,z_click,half_x,half_z)

    ix = find(abs(x_axis-x_click) <= half_x);
    iz = find(abs(z_axis-z_click) <= half_z);

    assert(~isempty(ix) && ~isempty(iz), ...
        'Selected target neighborhood is outside the image.');

    roi = envelope(iz,ix);
    [~,idx] = max(roi(:));
    [ir,ic] = ind2sub(size(roi),idx);

    peak.iz = iz(ir);
    peak.ix = ix(ic);
    peak.x = x_axis(peak.ix);
    peak.z = z_axis(peak.iz);
end

function metrics = measure_target_psf( ...
    envelope,x_axis,z_axis,ix_peak,iz_peak)

    lateral = envelope(iz_peak,:);
    axial = envelope(:,ix_peak);

    lateral = lateral / (lateral(ix_peak) + eps);
    axial = axial / (axial(iz_peak) + eps);

    metrics.fwhm_x = measure_fwhm( ...
        x_axis,lateral,ix_peak);

    metrics.fwhm_z = measure_fwhm( ...
        z_axis,axial,iz_peak);

    metrics.lateral = lateral;
    metrics.axial = axial;
end

function width = measure_fwhm(x,y,peak_idx)

    level = 0.5;

    left = find(y(1:peak_idx) < level,1,'last');
    right_rel = find(y(peak_idx:end) < level,1,'first');

    assert(~isempty(left) && ~isempty(right_rel), ...
        'Could not find both -6 dB crossings.');

    right = peak_idx + right_rel - 1;

    xl = crossing_linear( ...
        x(left),y(left),x(left+1),y(left+1),level);

    xr = crossing_linear( ...
        x(right-1),y(right-1),x(right),y(right),level);

    width = xr-xl;
end

function xc = crossing_linear(x0,y0,x1,y1,level)
    assert(abs(y1-y0) > eps, ...
        'Degenerate threshold crossing.');

    xc = x0 + ...
        (level-y0)*(x1-x0)/(y1-y0);
end
