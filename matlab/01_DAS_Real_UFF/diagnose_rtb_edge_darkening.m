%% diagnose_rtb_edge_darkening.m
% Chapter 1 - Diagnose RTB lateral edge darkening.
%
% Scientific question:
%   Why does the blended RTB image look darker near the left/right edges
%   than near the center?
%
% This script separates three candidate mechanisms:
%
%   A) Tx support / overlap
%      - active Tx count per pixel
%      - sum of Tx apodization weights per pixel
%
%   B) Rx aperture truncation near the physical probe edges
%      - dynamic F-number active Rx count map
%      - compare F# Rx RTB against full-Rx RTB
%
%   C) Is the lateral asymmetry RTB-specific?
%      - reconstruct conventional FI-DAS with the SAME Rx F-number
%      - interpolate only for plotting on the RTB x grid
%      - compare lateral background-level roll-off
%
%   D) Display / normalization effect
%      - compare lateral background-level profiles after the SAME
%        center-referenced normalization rule
%
% IMPORTANT:
%   This script does NOT "correct" the edge darkening.
%   It only diagnoses whether the effect is consistent with finite Tx/Rx
%   support. Any later gain compensation would be a separate display or
%   post-processing step and must not be confused with RTB itself.
%
% Example:
%   addpath(genpath('D:/USTB'));
%   cd matlab/01_DAS_Real_UFF
%
%   filename = '../../data/L7_FI_Verasonics_CIRS_points.uff';
%   diagnose_rtb_edge_darkening

clearvars -except filename z_min z_max n_z x_upsample ...
    rx_f_number tx_f_number blending_power ...
    profile_z_min profile_z_max tx_time_offsets;
clc;
close all;

%% ------------------------------------------------------------------------
% 0. User parameters
% -------------------------------------------------------------------------
if ~exist('filename','var')
    filename = '../../data/L7_FI_Verasonics_CIRS_points.uff';
end
if ~exist('z_min','var')
    z_min = 5e-3;
end
if ~exist('z_max','var')
    z_max = 45e-3;
end
if ~exist('n_z','var')
    n_z = 256;
end
if ~exist('x_upsample','var')
    x_upsample = 4;
end
if ~exist('rx_f_number','var')
    rx_f_number = 1.7;
end
if ~exist('tx_f_number','var')
    tx_f_number = 2.0;
end
if ~exist('blending_power','var')
    blending_power = 0.5;
end

display_dynamic_range_db = 60;

% Depth band used for lateral "background level" summary.
% Default deliberately avoids the ~30 mm point-target group and the large
% bright structure around x~-15 mm, z~35-42 mm in this CIRS dataset.
% Users can override profile_z_min / profile_z_max before running.
if ~exist('profile_z_min','var')
    profile_z_min = 10e-3;
end
if ~exist('profile_z_max','var')
    profile_z_max = 27e-3;
end

% Relative x regions used for left / center / right summaries.
edge_fraction = 0.15;
center_fraction = 0.30;

%% ------------------------------------------------------------------------
% 1. Common RTB options
% -------------------------------------------------------------------------
base = struct();

base.z_min = z_min;
base.z_max = z_max;
base.n_z = n_z;
base.x_upsample = x_upsample;

base.tx_delay_model = 'blended';
base.blending_power = blending_power;

base.tx_f_number = tx_f_number;
base.tx_min_aperture = 3e-3;
base.tx_window = 'tukey25';

base.wave_stride = 1;
base.normalize_tx_weights = true;

base.display_dynamic_range_db = display_dynamic_range_db;
base.verbose = true;
if exist('tx_time_offsets','var')
    base.tx_time_offsets = tx_time_offsets;
end

%% ------------------------------------------------------------------------
% 2. RTB with dynamic Rx F-number
% -------------------------------------------------------------------------
fprintf('============================================================\n');
fprintf(' A / C - BLENDED RTB WITH DYNAMIC RX F-NUMBER\n');
fprintf('============================================================\n');

opts_fnum = base;
opts_fnum.rx_aperture_mode = 'f_number';
opts_fnum.rx_f_number = rx_f_number;

rtb_fnum = reconstruct_fi_rtb_manual(filename,opts_fnum);

%% ------------------------------------------------------------------------
% 3. RTB with full receive aperture
% -------------------------------------------------------------------------
fprintf('\n============================================================\n');
fprintf(' B / C - BLENDED RTB WITH FULL RX APERTURE\n');
fprintf('============================================================\n');

opts_full = base;
opts_full.rx_aperture_mode = 'full';
opts_full.rx_f_number = rx_f_number;  % unused in full mode

rtb_full = reconstruct_fi_rtb_manual(filename,opts_full);

assert(isequal(size(rtb_fnum.envelope),size(rtb_full.envelope)), ...
    'F-number and full-Rx images do not share the same grid.');

assert(max(abs(rtb_fnum.x_axis(:)-rtb_full.x_axis(:))) < 1e-12, ...
    'F-number and full-Rx x axes differ.');

assert(max(abs(rtb_fnum.z_axis(:)-rtb_full.z_axis(:))) < 1e-12, ...
    'F-number and full-Rx z axes differ.');

x_axis = rtb_fnum.x_axis;
z_axis = rtb_fnum.z_axis;

%% ------------------------------------------------------------------------
% 3B. Conventional FI-DAS baseline with the SAME Rx F-number
% -------------------------------------------------------------------------
fprintf('\n============================================================\n');
fprintf(' C / C - CONVENTIONAL FI-DAS WITH SAME RX F-NUMBER\n');
fprintf('============================================================\n');

opts_conv = struct();
opts_conv.z_min = z_min;
opts_conv.z_max = z_max;
opts_conv.n_z = n_z;
opts_conv.receive_aperture_mode = 'f_number';
opts_conv.receive_f_number = rx_f_number;
opts_conv.display_dynamic_range_db = display_dynamic_range_db;
opts_conv.verbose = true;
if exist('tx_time_offsets','var')
    opts_conv.tx_time_offsets = tx_time_offsets;
end

conv = reconstruct_fi_scanline_manual(filename,opts_conv);

assert(max(abs(conv.z_axis(:)-z_axis(:))) < 1e-12, ...
    'Conventional and RTB z axes differ.');

% IMPORTANT:
% This interpolation is ONLY for putting the conventional image on the
% RTB x grid for visual/profile comparison. It is NOT RTB and does not
% create new beamformed information.
conv_interp_env = interp1( ...
    conv.x_axis, ...
    conv.envelope.', ...
    x_axis, ...
    'linear',0).';

%% ------------------------------------------------------------------------
% 4. Read probe geometry and compute active Rx count map
% -------------------------------------------------------------------------
channel_data = uff.read_object(filename,'/channel_data');

probe_x = channel_data.probe.x(:).';
N_channels = channel_data.N_channels;

active_rx_fnum = compute_active_rx_count_map( ...
    probe_x,x_axis,z_axis,'f_number',rx_f_number);

active_rx_full = compute_active_rx_count_map( ...
    probe_x,x_axis,z_axis,'full',rx_f_number);

assert(all(active_rx_full(:) == N_channels), ...
    'Full-Rx active channel count should equal N_channels everywhere.');

%% ------------------------------------------------------------------------
% 5. Display all images with one shared amplitude reference
% -------------------------------------------------------------------------
display_reference = max([rtb_fnum.envelope(:);rtb_full.envelope(:); ...
    conv.envelope(:)]);
fnum_db = to_db(rtb_fnum.envelope,display_dynamic_range_db,display_reference);
full_db = to_db(rtb_full.envelope,display_dynamic_range_db,display_reference);
conv_interp_db = to_db(conv_interp_env,display_dynamic_range_db,display_reference);

%% ------------------------------------------------------------------------
% 6. Lateral background-level profiles: RTB vs conventional
% -------------------------------------------------------------------------
z_mask = z_axis >= profile_z_min & z_axis <= profile_z_max;

assert(any(z_mask), ...
    'Background profile depth band does not intersect the RTB image.');

% Median across depth reduces influence from isolated bright point targets.
fnum_lateral_level = median(rtb_fnum.envelope(z_mask,:),1);
full_lateral_level = median(rtb_full.envelope(z_mask,:),1);
conv_lateral_level = median(conv_interp_env(z_mask,:),1);

% Normalize BOTH curves to the same type of central-region reference:
% the median of each curve in the central x region.
Nx = numel(x_axis);

center_half_width = center_fraction/2 * ...
    (max(x_axis)-min(x_axis));

center_mask = abs(x_axis - median(x_axis)) <= center_half_width;

assert(any(center_mask), ...
    'Center region is empty.');

fnum_center_ref = median(fnum_lateral_level(center_mask));
full_center_ref = median(full_lateral_level(center_mask));
conv_center_ref = median(conv_lateral_level(center_mask));

fnum_profile_db = 20*log10( ...
    fnum_lateral_level/(fnum_center_ref+eps) + eps);

full_profile_db = 20*log10( ...
    full_lateral_level/(full_center_ref+eps) + eps);

conv_profile_db = 20*log10( ...
    conv_lateral_level/(conv_center_ref+eps) + eps);

% A smoothed copy makes the slow lateral trend easier to see without
% replacing the unsmoothed diagnostic curve.
smooth_span = max(5,2*floor(Nx/50)+1);

fnum_profile_smooth = movmean(fnum_profile_db,smooth_span);
full_profile_smooth = movmean(full_profile_db,smooth_span);
conv_profile_smooth = movmean(conv_profile_db,smooth_span);

% RTB-specific lateral trend relative to conventional FI.
% Positive: RTB relatively brighter than conventional at that x.
% Negative: RTB relatively darker than conventional at that x.
rtb_minus_conv_db = fnum_profile_smooth - conv_profile_smooth;
% Unlike the center-aligned residual above, this preserves overall gain.
rtb_absolute_ratio_db = 20*log10(max(fnum_lateral_level,realmin) ...
    ./ max(conv_lateral_level,realmin));

%% ------------------------------------------------------------------------
% 7. Left / center / right regional summaries
% -------------------------------------------------------------------------
x_min = min(x_axis);
x_max = max(x_axis);
x_span = x_max-x_min;

left_mask = x_axis <= x_min + edge_fraction*x_span;
right_mask = x_axis >= x_max - edge_fraction*x_span;

center_half = center_fraction/2*x_span;
center_mask = abs(x_axis-median(x_axis)) <= center_half;

summary = struct();

summary.tx_count = summarize_regions( ...
    median(rtb_fnum.active_tx_count(z_mask,:),1), ...
    left_mask,center_mask,right_mask);

summary.tx_weight = summarize_regions( ...
    median(rtb_fnum.tx_weight_sum(z_mask,:),1), ...
    left_mask,center_mask,right_mask);

summary.rx_count = summarize_regions( ...
    median(active_rx_fnum(z_mask,:),1), ...
    left_mask,center_mask,right_mask);

summary.fnum_level_db = summarize_regions( ...
    fnum_profile_db, ...
    left_mask,center_mask,right_mask);

summary.full_level_db = summarize_regions( ...
    full_profile_db, ...
    left_mask,center_mask,right_mask);

summary.conv_level_db = summarize_regions( ...
    conv_profile_db, ...
    left_mask,center_mask,right_mask);

summary.rtb_minus_conv_db = summarize_regions( ...
    rtb_minus_conv_db, ...
    left_mask,center_mask,right_mask);

%% ------------------------------------------------------------------------
% 8. Console report
% -------------------------------------------------------------------------
fprintf('\n============================================================\n');
fprintf(' RTB EDGE-DARKENING DIAGNOSTICS\n');
fprintf('============================================================\n');

fprintf('Grid [z x]             : [%d %d]\n', ...
    numel(z_axis),numel(x_axis));
fprintf('x spacing              : %.6f mm\n', ...
    median(abs(diff(x_axis)))*1e3);
fprintf('Profile depth band     : %.1f to %.1f mm\n', ...
    profile_z_min*1e3,profile_z_max*1e3);

fprintf('\nMedian active Tx count [left | center | right]:\n');
fprintf('  %.3f | %.3f | %.3f\n', ...
    summary.tx_count.left, ...
    summary.tx_count.center, ...
    summary.tx_count.right);

fprintf('\nMedian Tx weight sum [left | center | right]:\n');
fprintf('  %.3f | %.3f | %.3f\n', ...
    summary.tx_weight.left, ...
    summary.tx_weight.center, ...
    summary.tx_weight.right);

fprintf('\nMedian active Rx count for F# %.2f [left | center | right]:\n', ...
    rx_f_number);
fprintf('  %.3f | %.3f | %.3f\n', ...
    summary.rx_count.left, ...
    summary.rx_count.center, ...
    summary.rx_count.right);

fprintf('\nRelative median background level, F# Rx [dB]:\n');
fprintf('  left %.3f | center %.3f | right %.3f\n', ...
    summary.fnum_level_db.left, ...
    summary.fnum_level_db.center, ...
    summary.fnum_level_db.right);

fprintf('\nRelative median background level, FULL Rx RTB [dB]:\n');
fprintf('  left %.3f | center %.3f | right %.3f\n', ...
    summary.full_level_db.left, ...
    summary.full_level_db.center, ...
    summary.full_level_db.right);

fprintf('\nRelative median background level, CONVENTIONAL FI [dB]:\n');
fprintf('  left %.3f | center %.3f | right %.3f\n', ...
    summary.conv_level_db.left, ...
    summary.conv_level_db.center, ...
    summary.conv_level_db.right);

fprintf('\nRTB(F#) minus conventional lateral trend [dB]:\n');
fprintf('  left %.3f | center %.3f | right %.3f\n', ...
    summary.rtb_minus_conv_db.left, ...
    summary.rtb_minus_conv_db.center, ...
    summary.rtb_minus_conv_db.right);

fprintf('\nInterpretation guide:\n');
fprintf(['  1) If Tx count / Tx weight sum drop toward the edges, finite Tx\n' ...
         '     support contributes to edge darkening.\n' ...
         '  2) If active Rx count also drops at the edges and FULL-Rx RTB\n' ...
         '     reduces the brightness roll-off, Rx aperture truncation is\n' ...
         '     also important.\n' ...
         '  3) A conventional edge roll-off does NOT exclude additional\n' ...
         '     RTB loss. Inspect the absolute ratio and Tx coherence.\n' ...
         '     Inter-Tx timing errors can strongly affect coherent RTB\n' ...
         '     while remaining less visible in one-Tx-per-line FI.\n' ...
         '  4) If conventional FI is laterally uniform but RTB is not,\n' ...
         '     continue investigating off-axis Tx modeling/apodization.\n' ...
         '  5) Tx-weight normalization removes simple overlap gain, but it\n' ...
         '     cannot restore missing synthetic aperture or lost coherent\n' ...
         '     information at the physical FOV boundary.\n']);

%% ------------------------------------------------------------------------
% 9. Figure 1: RTB F-number Rx vs full Rx vs conventional
% -------------------------------------------------------------------------
figure('Color','w');

subplot(1,3,1);
imagesc(x_axis*1e3,z_axis*1e3,fnum_db);
set(gca,'YDir','reverse');
axis image;
xlabel('x (mm)');
ylabel('z (mm)');
title(sprintf('Blended RTB, Rx F# = %.2f',rx_f_number));
caxis([-display_dynamic_range_db 0]);
colorbar;

subplot(1,3,2);
imagesc(x_axis*1e3,z_axis*1e3,full_db);
set(gca,'YDir','reverse');
axis image;
xlabel('x (mm)');
ylabel('z (mm)');
title('Blended RTB, full Rx aperture');
caxis([-display_dynamic_range_db 0]);
colorbar;

subplot(1,3,3);
imagesc(x_axis*1e3,z_axis*1e3,conv_interp_db);
set(gca,'YDir','reverse');
axis image;
xlabel('x (mm)');
ylabel('z (mm)');
title(sprintf('Conventional FI, Rx F# = %.2f',rx_f_number));
caxis([-display_dynamic_range_db 0]);
colorbar;

colormap gray;

%% ------------------------------------------------------------------------
% 10. Figure 2: Tx / Rx support maps
% -------------------------------------------------------------------------
figure('Color','w');

subplot(1,3,1);
imagesc(x_axis*1e3,z_axis*1e3,rtb_fnum.active_tx_count);
set(gca,'YDir','reverse');
axis image;
xlabel('x (mm)');
ylabel('z (mm)');
title('Active Tx count');
colorbar;

subplot(1,3,2);
imagesc(x_axis*1e3,z_axis*1e3,rtb_fnum.tx_weight_sum);
set(gca,'YDir','reverse');
axis image;
xlabel('x (mm)');
ylabel('z (mm)');
title('Tx weight sum');
colorbar;

subplot(1,3,3);
imagesc(x_axis*1e3,z_axis*1e3,active_rx_fnum);
set(gca,'YDir','reverse');
axis image;
xlabel('x (mm)');
ylabel('z (mm)');
title(sprintf('Active Rx count, F# %.2f',rx_f_number));
colorbar;

%% ------------------------------------------------------------------------
% 11. Figure 3: lateral brightness roll-off
% -------------------------------------------------------------------------
figure('Color','w');

plot(x_axis*1e3,fnum_profile_db,'LineWidth',0.7);
hold on;
plot(x_axis*1e3,full_profile_db,'LineWidth',0.7);
plot(x_axis*1e3,conv_profile_db,'LineWidth',0.7);

plot(x_axis*1e3,fnum_profile_smooth,'LineWidth',2.0);
plot(x_axis*1e3,full_profile_smooth,'LineWidth',2.0);
plot(x_axis*1e3,conv_profile_smooth,'LineWidth',2.0);

yline(0,':');

xlabel('x (mm)');
ylabel('Median envelope level relative to center (dB)');

title(sprintf( ...
    'Lateral background-level trend, z = %.0f to %.0f mm', ...
    profile_z_min*1e3,profile_z_max*1e3));

legend( ...
    sprintf('RTB F# %.2f raw',rx_f_number), ...
    'RTB Full Rx raw', ...
    'Conventional raw', ...
    sprintf('RTB F# %.2f smoothed',rx_f_number), ...
    'RTB Full Rx smoothed', ...
    'Conventional smoothed', ...
    'Location','best');

grid on;

%% ------------------------------------------------------------------------
% 11B. Figure 3B: RTB-specific lateral trend relative to conventional
% -------------------------------------------------------------------------
figure('Color','w');

plot(x_axis*1e3,rtb_minus_conv_db,'LineWidth',2.0);
hold on;
plot(x_axis*1e3,rtb_absolute_ratio_db,'LineWidth',1.5);
legend('Center-aligned residual','Absolute RTB / Conventional','Location','best');
yline(0,':');

xlabel('x (mm)');
ylabel('RTB F# - Conventional lateral trend (dB)');
title('RTB-specific lateral brightness trend relative to conventional FI');
grid on;

%% ------------------------------------------------------------------------
% 12. Figure 4: active Tx / Rx centerline summaries
% -------------------------------------------------------------------------
figure('Color','w');

subplot(3,1,1);
plot(x_axis*1e3, ...
    median(rtb_fnum.active_tx_count(z_mask,:),1), ...
    'LineWidth',1.5);
ylabel('Active Tx');
title('Median support across selected depth band');
grid on;

subplot(3,1,2);
plot(x_axis*1e3, ...
    median(rtb_fnum.tx_weight_sum(z_mask,:),1), ...
    'LineWidth',1.5);
ylabel('Tx weight sum');
grid on;

subplot(3,1,3);
plot(x_axis*1e3, ...
    median(active_rx_fnum(z_mask,:),1), ...
    'LineWidth',1.5);
xlabel('x (mm)');
ylabel('Active Rx');
grid on;

%% =========================================================================
% Local helpers
% =========================================================================

function count_map = compute_active_rx_count_map( ...
    element_x,x_axis,z_axis,mode,f_number)
%COMPUTE_ACTIVE_RX_COUNT_MAP Match the receive aperture used by the RTB core.
%
% Output shape:
%   [z, x]

    Nz = numel(z_axis);
    Nx = numel(x_axis);

    count_map = zeros(Nz,Nx);

    switch lower(mode)
        case 'full'
            count_map(:) = numel(element_x);

        case 'f_number'
            for iz = 1:Nz
                aperture_width = z_axis(iz)/f_number;
                half_width = aperture_width/2;

                active = ...
                    abs(x_axis - element_x) <= half_width;

                % active shape: [Nx, N_channel]
                count_map(iz,:) = sum(active,2).';

                empty_x = count_map(iz,:) == 0;

                % Same fallback as the reconstruction core: guarantee at
                % least one nearest receive element.
                count_map(iz,empty_x) = 1;
            end

        otherwise
            error('Unsupported receive aperture mode: %s',mode);
    end
end

function s = summarize_regions(y,left_mask,center_mask,right_mask)
    s.left = median(y(left_mask));
    s.center = median(y(center_mask));
    s.right = median(y(right_mask));
end

function db_img = to_db(env,dynamic_range,reference)
    env = env/reference;
    db_img = 20*log10(env+eps);
    db_img(db_img < -dynamic_range) = -dynamic_range;
end
