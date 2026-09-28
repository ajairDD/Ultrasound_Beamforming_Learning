%% validate_manual_vs_ustb.m
% Chapter 1 validation:
% compare our manual conventional FI-DAS with USTB conventional DAS
% on the SAME UFF file and SAME scan grid.
%
% This script is intentionally a validation wrapper:
%   1) run our manual implementation;
%   2) preserve its output;
%   3) run USTB midprocess.das as the reference;
%   4) compare envelope images and normalized dB images.
%
% Important:
%   - manual DAS remains the learning implementation;
%   - USTB DAS is used only as a cross-check here.
%
% Expected use:
%   addpath(genpath('D:/USTB'));  % change path
%   cd matlab/01_DAS_Real_UFF
%   filename = '../../data/L7_FI_Verasonics_CIRS_points.uff';
%   validate_manual_vs_ustb

clearvars -except filename z_min z_max n_z frame_index;
clc;
close all;

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
    n_z = 1024;
end
if ~exist('frame_index','var')
    frame_index = 1;
end

%% ------------------------------------------------------------------------
% 1. Run our manual DAS
% -------------------------------------------------------------------------
receive_aperture_mode = 'full';

fprintf('\n============================================================\n');
fprintf(' STEP 1 / 3 - MANUAL FI-DAS\n');
fprintf('============================================================\n');

run('das_fi_scanline_manual.m');

manual_envelope = envelope;
manual_image_db = image_db;
manual_x_axis = x_axis;
manual_z_axis = z_axis;
manual_peak = max(manual_envelope(:));

% Preserve parameters because the manual script deliberately clears most
% workspace variables at startup.
manual_nz = numel(manual_z_axis);

%% ------------------------------------------------------------------------
% 2. USTB conventional scanline reference
% -------------------------------------------------------------------------
fprintf('\n============================================================\n');
fprintf(' STEP 2 / 3 - USTB CONVENTIONAL FI-DAS REFERENCE\n');
fprintf('============================================================\n');

channel_data_ref = uff.read_object(filename, '/channel_data');

assert(frame_index <= channel_data_ref.N_frames, ...
    'frame_index exceeds the UFF frame count.');

% Restrict to the same frame if multiple frames are present.
if channel_data_ref.N_frames > 1
    channel_data_ref.data = channel_data_ref.data(:,:,:,frame_index);
end

x_ref = zeros(channel_data_ref.N_waves,1);
for iw = 1:channel_data_ref.N_waves
    x_ref(iw) = channel_data_ref.sequence(iw).source.x;
end

assert(numel(x_ref) == numel(manual_x_axis), ...
    'Manual and USTB x-axis sizes differ.');
assert(max(abs(x_ref(:)-manual_x_axis(:))) < 1e-12, ...
    'Manual and USTB x-axis coordinates differ.');

scan_ref = uff.linear_scan( ...
    'x_axis', x_ref, ...
    'z_axis', manual_z_axis);

mid_ref = midprocess.das();
mid_ref.channel_data = channel_data_ref;
mid_ref.scan = scan_ref;
mid_ref.dimension = dimension.both();

% Match our manual implementation as closely as possible.
mid_ref.spherical_transmit_delay_model = ...
    spherical_transmit_delay_model.spherical;

% Conventional FI: one transmit event per scanline.
mid_ref.transmit_apodization.window = uff.window.scanline;

% Full receive aperture, matching receive_aperture_mode = 'full'.
mid_ref.receive_apodization.window = uff.window.none;

% Use MATLAB implementation so both sides use linear interpolation and
% avoid differences caused by a compiled/MEX implementation.
mid_ref.code = code.matlab;

b_ref = mid_ref.go();

ustb_complex = reshape( ...
    b_ref.data, ...
    scan_ref.N_z_axis, ...
    scan_ref.N_x_axis);

ustb_envelope = abs(ustb_complex);
ustb_peak = max(ustb_envelope(:));

assert(ustb_peak > 0, 'USTB reference image is all zero.');

ustb_image_db = 20*log10(ustb_envelope/ustb_peak + eps);
ustb_image_db(ustb_image_db < -60) = -60;

%% ------------------------------------------------------------------------
% 3. Compare
% -------------------------------------------------------------------------
fprintf('\n============================================================\n');
fprintf(' STEP 3 / 3 - COMPARISON\n');
fprintf('============================================================\n');

assert(isequal(size(manual_envelope), size(ustb_envelope)), ...
    'Manual and USTB image sizes differ.');

% Compare normalized linear envelopes.
manual_norm = manual_envelope / (manual_peak + eps);
ustb_norm = ustb_envelope / (ustb_peak + eps);

linear_diff = manual_norm - ustb_norm;

mae_linear = mean(abs(linear_diff(:)));
rmse_linear = sqrt(mean(linear_diff(:).^2));
max_abs_linear = max(abs(linear_diff(:)));

% Pearson correlation of normalized envelope images.
a = manual_norm(:);
b = ustb_norm(:);
a0 = a - mean(a);
b0 = b - mean(b);
corr_envelope = sum(a0.*b0) / ...
    sqrt(sum(a0.^2)*sum(b0.^2) + eps);

% Peak locations.
[~, idx_manual] = max(manual_envelope(:));
[iz_m, ix_m] = ind2sub(size(manual_envelope), idx_manual);

[~, idx_ustb] = max(ustb_envelope(:));
[iz_u, ix_u] = ind2sub(size(ustb_envelope), idx_ustb);

fprintf('Image size                 : [%d x %d]\n', ...
    size(manual_envelope,1), size(manual_envelope,2));
fprintf('Envelope correlation       : %.9f\n', corr_envelope);
fprintf('Mean abs normalized error  : %.9g\n', mae_linear);
fprintf('RMSE normalized error      : %.9g\n', rmse_linear);
fprintf('Max abs normalized error   : %.9g\n', max_abs_linear);

fprintf('\nManual global peak : x = %.4f mm, z = %.4f mm\n', ...
    manual_x_axis(ix_m)*1e3, manual_z_axis(iz_m)*1e3);
fprintf('USTB   global peak : x = %.4f mm, z = %.4f mm\n', ...
    x_ref(ix_u)*1e3, manual_z_axis(iz_u)*1e3);

fprintf('Peak location delta: dx = %.4f mm, dz = %.4f mm\n', ...
    (manual_x_axis(ix_m)-x_ref(ix_u))*1e3, ...
    (manual_z_axis(iz_m)-manual_z_axis(iz_u))*1e3);

%% Figure A: side-by-side normalized dB images
figure('Color','w');

subplot(1,2,1);
imagesc(manual_x_axis*1e3, manual_z_axis*1e3, manual_image_db);
set(gca,'YDir','reverse');
axis image;
xlabel('x (mm)');
ylabel('z (mm)');
title('Manual FI-DAS');
caxis([-60 0]);
colorbar;
colormap gray;

subplot(1,2,2);
imagesc(x_ref*1e3, manual_z_axis*1e3, ustb_image_db);
set(gca,'YDir','reverse');
axis image;
xlabel('x (mm)');
ylabel('z (mm)');
title('USTB FI-DAS reference');
caxis([-60 0]);
colorbar;
colormap gray;

%% Figure B: normalized envelope difference
figure('Color','w');
imagesc( ...
    manual_x_axis*1e3, ...
    manual_z_axis*1e3, ...
    abs(linear_diff));
set(gca,'YDir','reverse');
axis image;
xlabel('x (mm)');
ylabel('z (mm)');
title('|Manual normalized envelope - USTB normalized envelope|');
colorbar;

%% Figure C: center-depth / representative lateral profile near 30 mm
[~, iz30] = min(abs(manual_z_axis - 30e-3));

figure('Color','w');
plot(manual_x_axis*1e3, ...
    manual_image_db(iz30,:), ...
    'LineWidth',1.5);
hold on;
plot(x_ref*1e3, ...
    ustb_image_db(iz30,:), ...
    '--','LineWidth',1.5);
xlabel('x (mm)');
ylabel('Normalized magnitude (dB)');
title(sprintf('Lateral profile at z = %.3f mm', ...
    manual_z_axis(iz30)*1e3));
legend('Manual','USTB reference','Location','best');
ylim([-60 0]);
grid on;

fprintf('\nInterpretation guide:\n');
fprintf(['  High envelope correlation + matching peak location + small\n' ...
         '  normalized difference indicate that the manual delay/timing\n' ...
         '  implementation is consistent with the USTB reference.\n' ...
         '  If they differ, inspect Tx delay, wave.delay, time axis,\n' ...
         '  interpolation, and analytic-signal conversion before moving on.\n']);
