%% analyze_gcf_m0_point_target.m
% Chapter 2 - Point-target comparison across GCF bandwidths.
%
% Compare:
%   M0 = 0 -> CF
%   M0 = 1 -> 3-bin GCF
%   M0 = 2 -> 5-bin GCF
%
% This quantifies the tradeoff seen in the full-image sweep:
% widening the low-spatial-frequency band preserves more aperture energy,
% but also reduces suppression.
%
% Run:
%   addpath(genpath('D:/USTB'));
%   cd matlab/02_CF_GCF
%   analyze_gcf_m0_point_target
%
% Optional:
%   target_x_mm = -0.745;
%   target_z_mm = 20.108;
%   analyze_gcf_m0_point_target

clearvars -except filename target_x_mm target_z_mm ...
    z_min z_max n_z receive_f_number M0_values;
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
    n_z = 512;
end
if ~exist('receive_f_number','var')
    receive_f_number = 1.7;
end
if ~exist('M0_values','var')
    M0_values = [0 1 2];
end

base = struct();
base.z_min = z_min;
base.z_max = z_max;
base.n_z = n_z;
base.receive_aperture_mode = 'f_number';
base.receive_f_number = receive_f_number;
base.display_dynamic_range_db = 60;
base.verbose = false;

N = numel(M0_values);
R = cell(N,1);

fprintf('============================================================\n');
fprintf(' GCF M0 POINT-TARGET COMPARISON\n');
fprintf('============================================================\n');

for k = 1:N
    opts = base;
    opts.M0 = M0_values(k);

    fprintf('Reconstructing M0=%d ... ',opts.M0);
    tic;
    R{k} = reconstruct_fi_gcf_manual(filename,opts);
    fprintf('%.2f s\n',toc);
end

% All reconstructions must share the same DAS baseline.
for k = 2:N
    err = max(abs(R{k}.das_analytic(:)-R{1}.das_analytic(:)));
    scale = max(abs(R{1}.das_analytic(:)));
    assert(err/(scale+eps) < 1e-10, ...
        'DAS baseline changed between M0 reconstructions.');
end

x = R{1}.x_axis;
z = R{1}.z_axis;

dx = median(abs(diff(x)));
dz = median(abs(diff(z)));

das_env = R{1}.das_envelope;

%% 1. Select target
figure('Color','w');
imagesc(x*1e3,z*1e3,R{1}.das_db);
set(gca,'YDir','reverse');
axis image;
xlabel('x (mm)');
ylabel('z (mm)');
title('Select one isolated point-like target');
caxis([-60 0]);
colorbar;
colormap gray;

if exist('target_x_mm','var') && exist('target_z_mm','var')
    x_click = target_x_mm*1e-3;
    z_click = target_z_mm*1e-3;
else
    [x_click_mm,z_click_mm] = ginput(1);
    x_click = x_click_mm*1e-3;
    z_click = z_click_mm*1e-3;
end

search_half_x = 1.2e-3;
search_half_z = 1.5e-3;

ix_roi = find(abs(x-x_click) <= search_half_x);
iz_roi = find(abs(z-z_click) <= search_half_z);

[iz_das,ix_das] = local_peak(das_env,iz_roi,ix_roi);

peak_das = das_env(iz_das,ix_das);

fprintf('\nDAS local peak\n');
fprintf('  x = %.4f mm\n',x(ix_das)*1e3);
fprintf('  z = %.4f mm\n',z(iz_das)*1e3);

%% 2. Measure each M0
metrics = table( ...
    M0_values(:), ...
    zeros(N,1), ...
    zeros(N,1), ...
    zeros(N,1), ...
    zeros(N,1), ...
    zeros(N,1), ...
    zeros(N,1), ...
    'VariableNames', ...
    {'M0','target_weight','peak_change_db', ...
     'lateral_fwhm_mm','axial_fwhm_mm', ...
     'lateral_w20_mm','axial_w20_mm'});

profiles_lat = cell(N,1);
profiles_ax = cell(N,1);

for k = 1:N

    env = R{k}.gcf_envelope;

    [iz_peak,ix_peak] = local_peak(env,iz_roi,ix_roi);

    peak = env(iz_peak,ix_peak);

    lat = env(iz_peak,:) / (peak+eps);
    ax = env(:,ix_peak) / (peak+eps);

    profiles_lat{k} = lat;
    profiles_ax{k} = ax;

    [fwhm_x,~,~] = ...
        measure_width_around_peak(x,lat,ix_peak,0.5);

    [fwhm_z,~,~] = ...
        measure_width_around_peak(z,ax,iz_peak,0.5);

    [w20_x,~,~] = ...
        measure_width_around_peak(x,lat,ix_peak,0.1);

    [w20_z,~,~] = ...
        measure_width_around_peak(z,ax,iz_peak,0.1);

    metrics.target_weight(k) = R{k}.gcf_map(iz_das,ix_das);
    metrics.peak_change_db(k) = ...
        20*log10(peak/(peak_das+eps)+eps);

    metrics.lateral_fwhm_mm(k) = fwhm_x*1e3;
    metrics.axial_fwhm_mm(k) = fwhm_z*1e3;

    metrics.lateral_w20_mm(k) = w20_x*1e3;
    metrics.axial_w20_mm(k) = w20_z*1e3;
end

disp(metrics);

fprintf('\nSampling context\n');
fprintf('  lateral spacing : %.6f mm\n',dx*1e3);
fprintf('  axial spacing   : %.6f mm\n',dz*1e3);

%% 3. Lateral profiles
figure('Color','w','Position',[100 100 950 560]);
hold on;

for k = 1:N
    plot( ...
        x*1e3, ...
        clip_db(profiles_lat{k},60), ...
        'LineWidth',1.5);
end

yline(-6.0206,'--','-6 dB');
yline(-20,':','-20 dB');

xlabel('Lateral position x (mm)');
ylabel('Amplitude relative to each method''s target peak (dB)');
title('Point-target lateral profile versus GCF bandwidth');

labels = arrayfun( ...
    @(m) sprintf('M0=%d',m), ...
    M0_values, ...
    'UniformOutput',false);

legend(labels,'Location','best');
xlim([x_click-5e-3,x_click+5e-3]*1e3);
ylim([-60 3]);
grid on;

%% 4. Axial profiles
figure('Color','w','Position',[120 120 950 560]);
hold on;

for k = 1:N
    plot( ...
        z*1e3, ...
        clip_db(profiles_ax{k},60), ...
        'LineWidth',1.5);
end

yline(-6.0206,'--','-6 dB');
yline(-20,':','-20 dB');

xlabel('Depth z (mm)');
ylabel('Amplitude relative to each method''s target peak (dB)');
title('Point-target axial profile versus GCF bandwidth');
legend(labels,'Location','best');
xlim([z_click-3e-3,z_click+3e-3]*1e3);
ylim([-60 3]);
grid on;

fprintf('\nInterpretation:\n');
fprintf(['  M0=0 is ordinary CF.\n' ...
         '  If M0 increases, target peak attenuation should generally weaken\n' ...
         '  because more low-frequency aperture energy is accepted.\n']);
fprintf(['  Compare this benefit against the loss of background / skirt\n' ...
         '  suppression seen in the full-image sweep.\n']);
fprintf(['  Lateral FWHM remains sampling-limited in conventional FI whenever\n' ...
         '  it spans only a few scanline intervals.\n']);

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
