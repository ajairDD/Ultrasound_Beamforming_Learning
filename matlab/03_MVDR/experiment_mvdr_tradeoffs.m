%% experiment_mvdr_tradeoffs.m
% Chapter 3 - ONE compact MVDR parameter experiment.
%
% Instead of many separate experiments, compare four representative settings
% around the known TheGB point-like target near x=-0.745 mm, z=20.1 mm.
%
% Configurations:
%
%   A) short subarray   L/M=0.25, loading=0.01
%   B) baseline         L/M=0.50, loading=0.01
%   C) long subarray    L/M=0.75, loading=0.01
%   D) robust loading   L/M=0.50, loading=0.10
%
% This single experiment teaches the two most important MVDR controls:
%
%   subarray length:
%       longer -> potentially narrower / more adaptive
%       but covariance estimate becomes harder / more sensitive
%
%   diagonal loading:
%       larger -> more robust / more DAS-like
%       smaller -> more adaptive / potentially less stable
%
% All configurations use the same stabilized covariance baseline:
%   axial covariance averaging = +/- 1.5 lambda
%
% To keep runtime reasonable, only a narrow depth band around the target is
% reconstructed.
%
% Run:
%   addpath(genpath('D:/USTB'));
%   cd matlab/03_MVDR
%   experiment_mvdr_tradeoffs

clearvars -except filename;
clc;
close all;

if ~exist('filename','var')
    filename = '../../data/L7_FI_TheGB.uff';
end

target_x = -0.745e-3;
target_z = 20.1e-3;

z_min = 18e-3;
z_max = 22.5e-3;
n_z = 160;

receive_f_number = 1.7;

labels = { ...
    'L/M=0.25, load=0.01', ...
    'L/M=0.50, load=0.01', ...
    'L/M=0.75, load=0.01', ...
    'L/M=0.50, load=0.10'};

subarray_fraction = [0.25 0.50 0.75 0.50];
diagonal_loading = [0.01 0.01 0.01 0.10];

N = numel(labels);
R = cell(N,1);

fprintf('============================================================\n');
fprintf(' MVDR PARAMETER TRADE-OFF EXPERIMENT\n');
fprintf('============================================================\n');

for k = 1:N

    opts = struct();

    opts.z_min = z_min;
    opts.z_max = z_max;
    opts.n_z = n_z;

    opts.receive_aperture_mode = 'f_number';
    opts.receive_f_number = receive_f_number;

    opts.subarray_fraction = subarray_fraction(k);
    opts.diagonal_loading = diagonal_loading(k);

    % Keep the Chapter-3 stabilized covariance baseline explicit rather
    % than relying on the core function's default.
    opts.axial_averaging_lambda = 1.5;
    opts.forward_backward = false;
    opts.display_dynamic_range_db = 60;
    opts.verbose = false;

    fprintf('%s ... ',labels{k});
    tic;
    R{k} = reconstruct_fi_mvdr_manual(filename,opts);
    fprintf('%.2f s\n',toc);
end

%% Verify identical DAS baselines
for k = 2:N

    delta = R{k}.das_analytic-R{1}.das_analytic;
    scale = max(abs(R{1}.das_analytic(:)));

    assert(max(abs(delta(:)))/(scale+eps) < 1e-10, ...
        'DAS baseline changed between MVDR parameter settings.');
end

x = R{1}.x_axis;
z = R{1}.z_axis;

das_env = R{1}.das_envelope;

dx = median(abs(diff(x)));
dz = median(abs(diff(z)));

%% DAS target peak
ix_roi = find(abs(x-target_x) <= 1.2e-3);
iz_roi = find(abs(z-target_z) <= 1.0e-3);

[iz_das,ix_das] = local_peak(das_env,iz_roi,ix_roi);
peak_das = das_env(iz_das,ix_das);

das_lat = das_env(iz_das,:)/(peak_das+eps);
das_ax = das_env(:,ix_das)/(peak_das+eps);

[das_fwhm_x,~,~] = ...
    measure_width_around_peak(x,das_lat,ix_das,0.5);

[das_fwhm_z,~,~] = ...
    measure_width_around_peak(z,das_ax,iz_das,0.5);

[das_w20_x,~,~] = ...
    measure_width_around_peak(x,das_lat,ix_das,0.1);

fprintf('\nDAS reference target\n');
fprintf('  peak x,z      : %.4f mm, %.4f mm\n', ...
    x(ix_das)*1e3,z(iz_das)*1e3);
fprintf('  lateral FWHM  : %.4f mm\n',das_fwhm_x*1e3);
fprintf('  axial FWHM    : %.4f mm\n',das_fwhm_z*1e3);
fprintf('  lateral -20dB : %.4f mm\n',das_w20_x*1e3);

%% MVDR target metrics
metrics = table( ...
    strings(N,1), ...
    subarray_fraction(:), ...
    diagonal_loading(:), ...
    zeros(N,1), ...
    zeros(N,1), ...
    zeros(N,1), ...
    zeros(N,1), ...
    zeros(N,1), ...
    'VariableNames',{ ...
        'configuration', ...
        'subarray_fraction', ...
        'diagonal_loading', ...
        'peak_change_dB', ...
        'lateral_FWHM_mm', ...
        'axial_FWHM_mm', ...
        'lateral_w20_mm', ...
        'median_L'});

profiles_lat = cell(N,1);

for k = 1:N

    env = R{k}.mvdr_envelope;

    [iz_peak,ix_peak] = local_peak(env,iz_roi,ix_roi);
    peak = env(iz_peak,ix_peak);

    lat = env(iz_peak,:)/(peak+eps);
    ax = env(:,ix_peak)/(peak+eps);

    profiles_lat{k} = lat;

    [fwhm_x,~,~] = ...
        measure_width_around_peak(x,lat,ix_peak,0.5);

    [fwhm_z,~,~] = ...
        measure_width_around_peak(z,ax,iz_peak,0.5);

    [w20_x,~,~] = ...
        measure_width_around_peak(x,lat,ix_peak,0.1);

    metrics.configuration(k) = string(labels{k});

    metrics.peak_change_dB(k) = ...
        20*log10(peak/(peak_das+eps)+eps);

    metrics.lateral_FWHM_mm(k) = fwhm_x*1e3;
    metrics.axial_FWHM_mm(k) = fwhm_z*1e3;
    metrics.lateral_w20_mm(k) = w20_x*1e3;

    Lvals = R{k}.subarray_length_map;
    Lvals = Lvals(Lvals > 0);

    metrics.median_L(k) = median(Lvals);
end

fprintf('\n');
disp(metrics);

fprintf('Sampling context\n');
fprintf('  lateral spacing : %.6f mm\n',dx*1e3);
fprintf('  axial spacing   : %.6f mm\n',dz*1e3);

%% 1. Four MVDR images, same DAS reference
figure('Color','w','Position',[50 50 1250 900]);

for k = 1:N

    subplot(2,2,k);

    imagesc( ...
        R{k}.x_axis*1e3, ...
        R{k}.z_axis*1e3, ...
        R{k}.mvdr_db_common);

    set(gca,'YDir','reverse');
    axis image;

    xlabel('x (mm)');
    ylabel('z (mm)');

    title(labels{k});

    caxis([-60 0]);
    colorbar;
end

colormap gray;

sgtitle({ ...
    'MVDR parameter trade-off near TheGB point target', ...
    'All panels use the SAME DAS amplitude reference'});

%% 2. Lateral profiles
figure('Color','w','Position',[100 100 1000 600]);

plot( ...
    x*1e3, ...
    clip_db(das_lat,60), ...
    'LineWidth',1.8);

hold on;

for k = 1:N
    plot( ...
        x*1e3, ...
        clip_db(profiles_lat{k},60), ...
        'LineWidth',1.3);
end

yline(-6.0206,'--','-6 dB');
yline(-20,':','-20 dB');

xlabel('Lateral position x (mm)');
ylabel('Amplitude relative to each method''s target peak (dB)');

title('DAS vs MVDR lateral target profiles');

legend([{ 'DAS' }, labels], ...
    'Location','best');

xlim((target_x + [-5 5]*1e-3)*1e3);
ylim([-60 3]);

grid on;

fprintf('\nHow to read this experiment:\n');
fprintf(['  1) Compare L/M=0.25, 0.50, 0.75 at fixed loading=0.01 to see\n' ...
         '     the subarray-length trade-off.\n']);
fprintf(['  2) Compare loading=0.01 vs 0.10 at fixed L/M=0.50 to see\n' ...
         '     how diagonal loading pushes MVDR toward a more robust,\n' ...
         '     less aggressive solution.\n']);
fprintf(['  3) Conventional-FI lateral sampling is still coarse. If a measured\n' ...
         '     FWHM spans only a few scanlines, treat the exact mm value as\n' ...
         '     sampling-limited.\n']);

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

    assert(~isempty(left_below) && ~isempty(right_rel), ...
        'Could not find both threshold crossings.');

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
