%% compare_carotid_rtb_das_vs_rtb_mvdr.m
% Chapter 3 - In-vivo carotid RTB-DAS vs RTB + receive-MVDR.
%
% PURPOSE
% -------
% Apply the already validated RTB-DAS / RTB-MVDR core to real carotid FI
% data.  The comparison keeps RTB geometry, Tx weighting, Rx F-number and
% cross-Tx coherent compounding identical; only the receive combination
% changes:
%
%   RTB-DAS  : equal-weight Rx sum
%   RTB-MVDR : adaptive Rx weights from covariance
%
% DEFAULT DATA
% ------------
%   dataset_index = 1
%       ../../data/L7_FI_carotid_cross_1.uff
%
% Set:
%   dataset_index = 2;
% to run the second independent acquisition.
%
% FAST DEFAULT ROI
% ----------------
%   x = -10 ... +10 mm
%   z =   8 ...  25 mm
%   n_x = 161
%   n_z = 171
%   wave_stride = 2
%
% This gives about 0.125 mm lateral and 0.10 mm axial grid spacing and uses
% every second focused Tx to keep the transparent MATLAB MVDR runtime
% practical.
%
% For a denser / stronger final comparison, run for example:
%
%   dataset_index = 1;
%   n_x = 241;
%   n_z = 257;
%   wave_stride = 1;
%   compare_carotid_rtb_das_vs_rtb_mvdr
%
% OUTPUT
% ------
% Figure 1:
%   RTB-DAS vs RTB-MVDR with COMMON RTB-DAS 0-dB reference.
%
% Figure 2:
%   self-normalized DAS / MVDR morphology and a masked MVDR-DAS dB map.
%
% Console:
%   runtime, grid spacing, peak change, median masked suppression,
%   envelope correlation and MVDR fallback ratio.
%
% IMPORTANT
% ---------
% This is an in-vivo robustness / morphology comparison. There is no
% ground-truth image, so darker lumen, sharper wall, or lower speckle is
% not by itself proof of better image quality or clinical performance.

clearvars -except dataset_index x_min x_max n_x z_min z_max n_z ...
    wave_stride subarray_fraction diagonal_loading ...
    axial_averaging_lambda forward_backward;
clc;
close all;

%% ------------------------------------------------------------------------
% 1. Defaults
% -------------------------------------------------------------------------
if ~exist('dataset_index','var') || ...
        ~isnumeric(dataset_index) || ...
        ~isscalar(dataset_index) || ...
        ~ismember(dataset_index,[1 2])
    dataset_index = 1;
end

datasets = { ...
    '../../data/L7_FI_carotid_cross_1.uff', ...
    '../../data/L7_FI_carotid_cross_2.uff'};

dataset_names = { ...
    'L7 FI carotid cross 1', ...
    'L7 FI carotid cross 2'};

filename = datasets{dataset_index};
dataset_name = dataset_names{dataset_index};

if ~exist('x_min','var') || ~isscalar(x_min) || ~isfinite(x_min)
    x_min = -10e-3;
end
if ~exist('x_max','var') || ~isscalar(x_max) || ~isfinite(x_max)
    x_max = 10e-3;
end
if ~exist('n_x','var') || ~isscalar(n_x) || ...
        ~isfinite(n_x) || n_x < 2
    n_x = 161;
end

if ~exist('z_min','var') || ~isscalar(z_min) || ~isfinite(z_min)
    z_min = 8e-3;
end
if ~exist('z_max','var') || ~isscalar(z_max) || ~isfinite(z_max)
    z_max = 25e-3;
end
if ~exist('n_z','var') || ~isscalar(n_z) || ...
        ~isfinite(n_z) || n_z < 2
    n_z = 171;
end

if ~exist('wave_stride','var') || ...
        ~isscalar(wave_stride) || ...
        ~isfinite(wave_stride) || ...
        wave_stride < 1 || ...
        wave_stride ~= round(wave_stride)
    wave_stride = 2;
end

if ~exist('subarray_fraction','var') || ...
        ~isscalar(subarray_fraction) || ...
        ~isfinite(subarray_fraction)
    subarray_fraction = 0.5;
end

if ~exist('diagonal_loading','var') || ...
        ~isscalar(diagonal_loading) || ...
        ~isfinite(diagonal_loading)
    diagonal_loading = 0.01;
end

if ~exist('axial_averaging_lambda','var') || ...
        ~isscalar(axial_averaging_lambda) || ...
        ~isfinite(axial_averaging_lambda)
    axial_averaging_lambda = 1.5;
end

if ~exist('forward_backward','var') || ...
        ~isscalar(forward_backward)
    forward_backward = false;
end

assert(x_max > x_min,'x_max must be greater than x_min.');
assert(z_max > z_min,'z_max must be greater than z_min.');

%% ------------------------------------------------------------------------
% 2. RTB / MVDR options
% -------------------------------------------------------------------------
opts = struct();

opts.x_min = x_min;
opts.x_max = x_max;
opts.n_x = round(n_x);

opts.z_min = z_min;
opts.z_max = z_max;
opts.n_z = round(n_z);

% Keep the same Chapter-1 RTB model.
opts.tx_delay_model = 'blended';
opts.pw_margin = 1e-3;
opts.blending_power = 0.5;
opts.tx_f_number = 2;
opts.tx_min_aperture = 3e-3;
opts.tx_window = 'tukey25';

opts.rx_aperture_mode = 'f_number';
opts.rx_f_number = 1.7;

opts.wave_stride = wave_stride;
opts.normalize_tx_weights = true;

% MVDR.
opts.subarray_fraction = subarray_fraction;
opts.diagonal_loading = diagonal_loading;
opts.axial_averaging_lambda = axial_averaging_lambda;
opts.forward_backward = logical(forward_backward);

opts.display_dynamic_range_db = 60;
opts.verbose = true;

fprintf('============================================================\n');
fprintf(' IN-VIVO CAROTID RTB-DAS vs RTB-MVDR\n');
fprintf('============================================================\n');
fprintf('dataset                 : %s\n',dataset_name);
fprintf('x ROI                   : %.2f ... %.2f mm\n', ...
    x_min*1e3,x_max*1e3);
fprintf('z ROI                   : %.2f ... %.2f mm\n', ...
    z_min*1e3,z_max*1e3);
fprintf('grid                    : %d x %d [z x]\n', ...
    opts.n_z,opts.n_x);
fprintf('wave stride             : %d\n',wave_stride);
fprintf('MVDR L/M                : %.3f\n',subarray_fraction);
fprintf('diagonal loading        : %.4g\n',diagonal_loading);
fprintf('axial covariance avg    : +/- %.2f lambda\n\n', ...
    axial_averaging_lambda);

tic;
out = reconstruct_fi_rtb_mvdr_manual(filename,opts);
runtime_s = toc;

%% ------------------------------------------------------------------------
% 3. Descriptive diagnostics
% -------------------------------------------------------------------------
x = out.x_axis;
z = out.z_axis;

dx = median(abs(diff(x)));
dz = median(abs(diff(z)));

das_env = out.rtb_das_envelope;
mv_env = out.rtb_mvdr_envelope;

das_peak = max(das_env(:));
mv_peak = max(mv_env(:));

peak_change_db = 20*log10(mv_peak/(das_peak+eps)+eps);

% Only summarize pixels with meaningful RTB-DAS amplitude. This avoids
% meaningless ratios in the noise-floor / display-clipped background.
mask = out.rtb_das_db >= -40 & out.tx_weight_sum > eps;

delta_db = 20*log10((mv_env+eps)./(das_env+eps));

if any(mask(:))
    masked_delta = delta_db(mask);
    median_delta_db = median(masked_delta);

    a = das_env(mask);
    b = mv_env(mask);

    a = a-mean(a);
    b = b-mean(b);

    denom = sqrt(sum(a.^2)*sum(b.^2));
    if denom > 0
        envelope_corr = sum(a.*b)/denom;
    else
        envelope_corr = NaN;
    end
else
    median_delta_db = NaN;
    envelope_corr = NaN;
end

fprintf('\n============================================================\n');
fprintf(' DESCRIPTIVE SUMMARY\n');
fprintf('============================================================\n');
fprintf('runtime                 : %.2f s\n',runtime_s);
fprintf('lateral spacing         : %.4f mm\n',dx*1e3);
fprintf('axial spacing           : %.4f mm\n',dz*1e3);
fprintf('MVDR global peak vs DAS : %.3f dB\n',peak_change_db);
fprintf('median MVDR-DAS dB      : %.3f dB (DAS >= -40 dB mask)\n', ...
    median_delta_db);
fprintf('envelope correlation    : %.4f (same mask)\n', ...
    envelope_corr);
fprintf('MVDR fallback           : %d / %d (%.4f%%)\n', ...
    out.mvdr_fallback_count, ...
    out.mvdr_pixel_count, ...
    100*out.mvdr_fallback_count/max(1,out.mvdr_pixel_count));

fprintf('\nInterpret these only as descriptive image statistics.\n');
fprintf('They are NOT measures of clinical superiority.\n');

%% ------------------------------------------------------------------------
% 4. Figure 1: common-reference image comparison
% -------------------------------------------------------------------------
figure('Color','w','Position',[50 60 1280 650]);

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
    dataset_name, ...
    sprintf(['Common DAS reference | stride=%d | L/M=%.2f | ' ...
             'loading=%.3g | axial avg=%.2f lambda'], ...
        wave_stride,subarray_fraction, ...
        diagonal_loading,axial_averaging_lambda)});

%% ------------------------------------------------------------------------
% 5. Figure 2: morphology + masked change map
% -------------------------------------------------------------------------
das_db_self = 20*log10(das_env/(das_peak+eps)+eps);
das_db_self(das_db_self < -60) = -60;

delta_display = delta_db;
delta_display(~mask) = NaN;
delta_display(delta_display < -20) = -20;
delta_display(delta_display > 10) = 10;

figure('Color','w','Position',[40 80 1550 620]);

subplot(1,3,1);
imagesc(x*1e3,z*1e3,das_db_self);
set(gca,'YDir','reverse');
axis image;
xlabel('x (mm)');
ylabel('z (mm)');
title('RTB-DAS, self-normalized');
caxis([-60 0]);
colorbar;

subplot(1,3,2);
imagesc(x*1e3,z*1e3,out.rtb_mvdr_db_self);
set(gca,'YDir','reverse');
axis image;
xlabel('x (mm)');
ylabel('z (mm)');
title('RTB-MVDR, self-normalized');
caxis([-60 0]);
colorbar;

subplot(1,3,3);
imagesc(x*1e3,z*1e3,delta_display);
set(gca,'YDir','reverse');
axis image;
xlabel('x (mm)');
ylabel('z (mm)');
title('MVDR - DAS amplitude change (dB)');
caxis([-20 10]);
colorbar;

sgtitle({ ...
    'Morphology and adaptive amplitude change', ...
    'Difference map shown only where RTB-DAS >= -40 dB'});

%% ------------------------------------------------------------------------
% 6. What to inspect
% -------------------------------------------------------------------------
fprintf('\n============================================================\n');
fprintf(' VISUAL CHECKLIST\n');
fprintf('============================================================\n');
fprintf('1) lumen residual clutter: lower or just unnaturally black?\n');
fprintf('2) near/far vessel wall: sharper AND continuous, or broken/thinned?\n');
fprintf('3) tissue speckle: preserved texture, or strongly re-shaped?\n');
fprintf('4) small structures: clearer, or converted into needle-like features?\n');
fprintf('5) deep region: stable, or increasingly aggressive / fragmented?\n');
fprintf('\n');

fprintf('For the second acquisition run:\n');
fprintf('  dataset_index = 2;\n');
fprintf('  compare_carotid_rtb_das_vs_rtb_mvdr\n');
fprintf('\n');

fprintf('For a denser final run:\n');
fprintf('  n_x = 241; n_z = 257; wave_stride = 1;\n');
fprintf('  compare_carotid_rtb_das_vs_rtb_mvdr\n');
