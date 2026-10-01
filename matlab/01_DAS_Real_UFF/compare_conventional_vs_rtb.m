%% compare_conventional_vs_rtb.m
% Chapter 1 - Conventional FI-DAS vs RTB.
%
% This experiment separates three things:
%
%   A) Conventional FI-DAS
%      one focused Tx -> one scanline
%
%   B) Conventional image with lateral interpolation ONLY
%      same conventional beamformed data, displayed on the denser RTB grid
%      -> better visual sampling, but NO new RF information
%
%   C) Manual RTB
%      each focused Tx contributes to multiple pixels and multiple Tx are
%      coherently combined at the same pixel
%
% This distinction is essential:
%   denser display interpolation != retrospective transmit beamforming.
%
% Default comparison uses the SAME receive F-number (1.7) for conventional
% and RTB so the experiment does not confound Rx aperture with RTB.
%
% Example:
%   addpath(genpath('D:/USTB'));
%   cd matlab/01_DAS_Real_UFF
%   filename = '../../data/L7_FI_Verasonics_CIRS_points.uff';
%   target_x_mm = -4.917;
%   target_z_mm = 20.21;
%   compare_conventional_vs_rtb

clearvars -except filename target_x_mm target_z_mm ...
    z_min z_max n_z rtb_x_upsample tx_time_offsets;
clc;
close all;

if ~exist('filename','var')
    filename = '../../data/L7_FI_Verasonics_CIRS_points.uff';
end
if ~exist('target_x_mm','var')
    target_x_mm = -4.917;
end
if ~exist('target_z_mm','var')
    target_z_mm = 20.21;
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
if ~exist('rtb_x_upsample','var')
    rtb_x_upsample = 4;
end

rx_f_number = 1.7;

%% ------------------------------------------------------------------------
% 1. Conventional FI-DAS with the SAME receive F-number
% -------------------------------------------------------------------------
fprintf('============================================================\n');
fprintf(' A / C - CONVENTIONAL FI-DAS\n');
fprintf('============================================================\n');

opts_c = struct();
opts_c.z_min = z_min;
opts_c.z_max = z_max;
opts_c.n_z = n_z;
opts_c.receive_aperture_mode = 'f_number';
opts_c.receive_f_number = rx_f_number;
opts_c.verbose = true;
if exist('tx_time_offsets','var')
    opts_c.tx_time_offsets = tx_time_offsets;
end

conv = reconstruct_fi_scanline_manual(filename,opts_c);

%% ------------------------------------------------------------------------
% 2. Manual RTB
% -------------------------------------------------------------------------
fprintf('\n============================================================\n');
fprintf(' C / C - MANUAL RTB\n');
fprintf('============================================================\n');

opts_r = struct();
opts_r.z_min = z_min;
opts_r.z_max = z_max;
opts_r.n_z = n_z;

opts_r.x_upsample = rtb_x_upsample;

opts_r.tx_delay_model = 'hybrid';
opts_r.pw_margin = 1e-3;

opts_r.tx_f_number = 2;
opts_r.tx_min_aperture = 3e-3;
opts_r.tx_window = 'tukey25';

opts_r.rx_aperture_mode = 'f_number';
opts_r.rx_f_number = rx_f_number;

opts_r.wave_stride = 1;
opts_r.normalize_tx_weights = true;
opts_r.verbose = true;
if exist('tx_time_offsets','var')
    opts_r.tx_time_offsets = tx_time_offsets;
end

rtb = reconstruct_fi_rtb_manual(filename,opts_r);

%% ------------------------------------------------------------------------
% 3. Pure lateral interpolation of conventional envelope
% -------------------------------------------------------------------------
conv_interp_env = interp1( ...
    conv.x_axis, ...
    conv.envelope.', ...
    rtb.x_axis, ...
    'linear',0).';

conv_db = to_db(conv.envelope,60);
conv_interp_db = to_db(conv_interp_env,60);
rtb_db = to_db(rtb.envelope,60);

dx_conv = median(abs(diff(conv.x_axis)));
dx_rtb = median(abs(diff(rtb.x_axis)));

fprintf('\n============================================================\n');
fprintf(' GRID COMPARISON\n');
fprintf('============================================================\n');
fprintf('Conventional x samples : %d\n',numel(conv.x_axis));
fprintf('RTB x samples          : %d\n',numel(rtb.x_axis));
fprintf('Conventional dx        : %.6f mm\n',dx_conv*1e3);
fprintf('RTB dx                 : %.6f mm\n',dx_rtb*1e3);
fprintf('Lateral sampling ratio : %.3f x denser\n',dx_conv/dx_rtb);

%% ------------------------------------------------------------------------
% 4. Compare the same point target
% -------------------------------------------------------------------------
x0 = target_x_mm*1e-3;
z0 = target_z_mm*1e-3;

search_half_x = 1.5e-3;
search_half_z = 1.5e-3;

p_conv = refine_local_peak( ...
    conv.envelope,conv.x_axis,conv.z_axis, ...
    x0,z0,search_half_x,search_half_z);

p_interp = refine_local_peak( ...
    conv_interp_env,rtb.x_axis,conv.z_axis, ...
    x0,z0,search_half_x,search_half_z);

p_rtb = refine_local_peak( ...
    rtb.envelope,rtb.x_axis,rtb.z_axis, ...
    x0,z0,search_half_x,search_half_z);

m_conv = measure_target_psf( ...
    conv.envelope,conv.x_axis,conv.z_axis, ...
    p_conv.ix,p_conv.iz);

m_interp = measure_target_psf( ...
    conv_interp_env,rtb.x_axis,conv.z_axis, ...
    p_interp.ix,p_interp.iz);

m_rtb = measure_target_psf( ...
    rtb.envelope,rtb.x_axis,rtb.z_axis, ...
    p_rtb.ix,p_rtb.iz);

active_tx_at_peak = ...
    rtb.active_tx_count(p_rtb.iz,p_rtb.ix);

tx_weight_sum_at_peak = ...
    rtb.tx_weight_sum(p_rtb.iz,p_rtb.ix);

fprintf('\n============================================================\n');
fprintf(' POINT-TARGET COMPARISON\n');
fprintf('============================================================\n');

fprintf('Target neighborhood     : x %.3f mm, z %.3f mm\n', ...
    target_x_mm,target_z_mm);

fprintf('\nPeak locations:\n');
fprintf('Conventional            : x %.4f mm, z %.4f mm\n', ...
    p_conv.x*1e3,p_conv.z*1e3);
fprintf('Conventional interpolated: x %.4f mm, z %.4f mm\n', ...
    p_interp.x*1e3,p_interp.z*1e3);
fprintf('RTB                     : x %.4f mm, z %.4f mm\n', ...
    p_rtb.x*1e3,p_rtb.z*1e3);

fprintf('\nLateral -6 dB amplitude FWHM:\n');
fprintf('Conventional             : %.6f mm | %.3f original lines\n', ...
    m_conv.fwhm_x*1e3,m_conv.fwhm_x/dx_conv);
fprintf('Conventional interpolated: %.6f mm | %.3f RTB-grid samples\n', ...
    m_interp.fwhm_x*1e3,m_interp.fwhm_x/dx_rtb);
fprintf('RTB                      : %.6f mm | %.3f RTB-grid samples\n', ...
    m_rtb.fwhm_x*1e3,m_rtb.fwhm_x/dx_rtb);

fprintf('\nAxial -6 dB amplitude FWHM:\n');
fprintf('Conventional : %.6f mm\n',m_conv.fwhm_z*1e3);
fprintf('RTB          : %.6f mm\n',m_rtb.fwhm_z*1e3);

fprintf('\nRTB Tx overlap at target:\n');
fprintf('Active Tx count : %d\n',active_tx_at_peak);
fprintf('Tx weight sum   : %.6f\n',tx_weight_sum_at_peak);

fprintf(['\nInterpretation:\n' ...
    '  Conventional interpolation only makes the existing 128-line image\n' ...
    '  smoother. RTB re-queries RF channel data for off-scanline pixels\n' ...
    '  and coherently combines multiple focused transmit events.\n']);

%% ------------------------------------------------------------------------
% 5. Three-way image comparison
% -------------------------------------------------------------------------
figure('Color','w');

subplot(1,3,1);
imagesc(conv.x_axis*1e3,conv.z_axis*1e3,conv_db);
set(gca,'YDir','reverse');
axis image;
xlabel('x (mm)');
ylabel('z (mm)');
title(sprintf('Conventional FI (%d lines)',numel(conv.x_axis)));
caxis([-60 0]);
colorbar;

subplot(1,3,2);
imagesc(rtb.x_axis*1e3,conv.z_axis*1e3,conv_interp_db);
set(gca,'YDir','reverse');
axis image;
xlabel('x (mm)');
ylabel('z (mm)');
title('Conventional + display interpolation');
caxis([-60 0]);
colorbar;

subplot(1,3,3);
imagesc(rtb.x_axis*1e3,rtb.z_axis*1e3,rtb_db);
set(gca,'YDir','reverse');
axis image;
xlabel('x (mm)');
ylabel('z (mm)');
title(sprintf('RTB hybrid (%d pixels)',numel(rtb.x_axis)));
caxis([-60 0]);
colorbar;
colormap gray;

%% ------------------------------------------------------------------------
% 6. Lateral profile comparison
% -------------------------------------------------------------------------
lat_conv_db = profile_db(m_conv.lateral);
lat_interp_db = profile_db(m_interp.lateral);
lat_rtb_db = profile_db(m_rtb.lateral);

figure('Color','w');

plot(conv.x_axis*1e3,lat_conv_db,'o-','LineWidth',1.2);
hold on;
plot(rtb.x_axis*1e3,lat_interp_db,'--','LineWidth',1.5);
plot(rtb.x_axis*1e3,lat_rtb_db,'LineWidth',1.8);

yline(-6.0206,':','-6 dB amplitude');

xlabel('x (mm)');
ylabel('Amplitude relative to target peak (dB)');
title(sprintf('Lateral target profile near z = %.3f mm',p_rtb.z*1e3));

legend( ...
    sprintf('Conventional %.3f mm',m_conv.fwhm_x*1e3), ...
    sprintf('Conv. interpolated %.3f mm',m_interp.fwhm_x*1e3), ...
    sprintf('RTB %.3f mm',m_rtb.fwhm_x*1e3), ...
    'Location','best');

xlim([x0-5e-3,x0+5e-3]*1e3);
ylim([-60 3]);
grid on;

%% ------------------------------------------------------------------------
% 7. Active transmit count map
% -------------------------------------------------------------------------
figure('Color','w');

imagesc( ...
    rtb.x_axis*1e3, ...
    rtb.z_axis*1e3, ...
    rtb.active_tx_count);

set(gca,'YDir','reverse');
axis image;

xlabel('x (mm)');
ylabel('z (mm)');
title('RTB active transmit count per pixel');
colorbar;

%% =========================================================================
% Local helpers
% =========================================================================
function db_img = to_db(env,dynamic_range)
    env = env/(max(env(:))+eps);
    db_img = 20*log10(env+eps);
    db_img(db_img < -dynamic_range) = -dynamic_range;
end

function ydb = profile_db(y)
    ydb = 20*log10(abs(y)+eps);
    ydb(ydb < -60) = -60;
end

function peak = refine_local_peak( ...
    envelope,x_axis,z_axis,x0,z0,half_x,half_z)

    ix = find(abs(x_axis-x0) <= half_x);
    iz = find(abs(z_axis-z0) <= half_z);

    assert(~isempty(ix) && ~isempty(iz), ...
        'Target neighborhood is outside image.');

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

    lateral = lateral/(lateral(ix_peak)+eps);
    axial = axial/(axial(iz_peak)+eps);

    metrics.fwhm_x = measure_fwhm( ...
        x_axis,lateral,ix_peak);

    metrics.fwhm_z = measure_fwhm( ...
        z_axis,axial,iz_peak);

    metrics.lateral = lateral;
    metrics.axial = axial;
end

function width = measure_fwhm(x,y,peak_idx)

    level = 0.5;

    left = find(y(1:peak_idx)<level,1,'last');
    right_rel = find(y(peak_idx:end)<level,1,'first');

    assert(~isempty(left) && ~isempty(right_rel), ...
        'Could not find both -6 dB crossings.');

    right = peak_idx + right_rel - 1;

    xl = crossing_linear( ...
        x(left),y(left), ...
        x(left+1),y(left+1), ...
        level);

    xr = crossing_linear( ...
        x(right-1),y(right-1), ...
        x(right),y(right), ...
        level);

    width = xr-xl;
end

function xc = crossing_linear(x0,y0,x1,y1,level)
    assert(abs(y1-y0)>eps, ...
        'Degenerate threshold crossing.');

    xc = x0 + ...
        (level-y0)*(x1-x0)/(y1-y0);
end
