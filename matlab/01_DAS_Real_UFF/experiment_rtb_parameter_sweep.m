%% experiment_rtb_parameter_sweep.m
% Chapter 1 - RTB one-factor-at-a-time experiments.
%
% RTB is computationally heavier than conventional FI-DAS. Therefore this
% script intentionally changes ONE parameter family per run rather than
% executing a full Cartesian product.
%
% Choose ONE experiment:
%
%   experiment = 'delay_model'
%   experiment = 'x_upsample'
%   experiment = 'tx_fnumber'
%   experiment = 'tx_min_aperture'
%   experiment = 'pw_margin'
%   experiment = 'rx_fnumber'
%   experiment = 'wave_stride'
%   experiment = 'blending_power'
%
% The default n_z=256 is for parameter exploration. Once a trend is clear,
% rerun the selected cases at n_z=512/1024.
%
% Example:
%   addpath(genpath('D:/USTB'));
%   cd matlab/01_DAS_Real_UFF
%   filename = '../../data/L7_FI_Verasonics_CIRS_points.uff';
%   experiment = 'wave_stride';
%   experiment_rtb_parameter_sweep

clearvars -except filename experiment target_x_mm target_z_mm ...
    z_min z_max n_z;
clc;
close all;

if ~exist('filename','var')
    filename = '../../data/L7_FI_Verasonics_CIRS_points.uff';
end
if ~exist('experiment','var')
    experiment = 'delay_model';
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
    n_z = 256;
end

base = struct();

base.z_min = z_min;
base.z_max = z_max;
base.n_z = n_z;

base.x_upsample = 4;

base.tx_delay_model = 'hybrid';
base.pw_margin = 1e-3;
base.blending_power = 0.5;

base.tx_f_number = 2;
base.tx_min_aperture = 3e-3;
base.tx_window = 'tukey25';

base.rx_aperture_mode = 'f_number';
base.rx_f_number = 1.7;

base.wave_stride = 1;
base.normalize_tx_weights = true;
base.verbose = false;

[cases,labels] = make_cases(experiment,base);

N = numel(cases);
results = cell(N,1);
metrics = repmat(struct(),N,1);

x0 = target_x_mm*1e-3;
z0 = target_z_mm*1e-3;

fprintf('============================================================\n');
fprintf(' RTB PARAMETER SWEEP: %s\n',upper(experiment));
fprintf('============================================================\n');
fprintf('Cases: %d\n',N);
fprintf('Target neighborhood: x %.3f mm, z %.3f mm\n\n', ...
    target_x_mm,target_z_mm);

for k = 1:N
    fprintf('Case %d / %d: %s\n',k,N,labels{k});

    tic;
    results{k} = reconstruct_fi_rtb_manual(filename,cases{k});
    metrics(k).runtime_s = toc;

    peak = refine_local_peak( ...
        results{k}.envelope, ...
        results{k}.x_axis, ...
        results{k}.z_axis, ...
        x0,z0,1.5e-3,1.5e-3);

    psf = measure_target_psf( ...
        results{k}.envelope, ...
        results{k}.x_axis, ...
        results{k}.z_axis, ...
        peak.ix,peak.iz);

    metrics(k).peak = peak;
    metrics(k).psf = psf;

    metrics(k).dx = median(abs(diff(results{k}.x_axis)));
    metrics(k).dz = median(abs(diff(results{k}.z_axis)));

    metrics(k).active_tx = ...
        results{k}.active_tx_count(peak.iz,peak.ix);

    metrics(k).tx_weight_sum = ...
        results{k}.tx_weight_sum(peak.iz,peak.ix);

    fprintf('  runtime       : %.2f s\n',metrics(k).runtime_s);
    fprintf('  dx            : %.4f mm\n',metrics(k).dx*1e3);
    fprintf('  peak          : x %.4f mm, z %.4f mm\n', ...
        peak.x*1e3,peak.z*1e3);
    fprintf('  lateral FWHM  : %.4f mm (%.2f x samples)\n', ...
        psf.fwhm_x*1e3,psf.fwhm_x/metrics(k).dx);
    fprintf('  axial FWHM    : %.4f mm\n',psf.fwhm_z*1e3);
    fprintf('  active Tx     : %d\n',metrics(k).active_tx);
    fprintf('  Tx weight sum : %.4f\n\n',metrics(k).tx_weight_sum);
end

%% ------------------------------------------------------------------------
% Summary table in console
% -------------------------------------------------------------------------
fprintf('============================================================\n');
fprintf(' SUMMARY\n');
fprintf('============================================================\n');

fprintf('%-24s %10s %10s %10s %10s %10s\n', ...
    'Case','dx(mm)','LatFWHM','AxFWHM','ActiveTx','time(s)');

for k = 1:N
    fprintf('%-24s %10.4f %10.4f %10.4f %10d %10.1f\n', ...
        labels{k}, ...
        metrics(k).dx*1e3, ...
        metrics(k).psf.fwhm_x*1e3, ...
        metrics(k).psf.fwhm_z*1e3, ...
        metrics(k).active_tx, ...
        metrics(k).runtime_s);
end

%% ------------------------------------------------------------------------
% Images
% -------------------------------------------------------------------------
figure('Color','w');

for k = 1:N
    subplot(1,N,k);

    db_img = to_db(results{k}.envelope,60);

    imagesc( ...
        results{k}.x_axis*1e3, ...
        results{k}.z_axis*1e3, ...
        db_img);

    set(gca,'YDir','reverse');
    axis image;

    xlabel('x (mm)');
    ylabel('z (mm)');
    title(labels{k},'Interpreter','none');

    caxis([-60 0]);
end

colormap gray;

%% ------------------------------------------------------------------------
% Lateral target profiles
% -------------------------------------------------------------------------
figure('Color','w');
hold on;

for k = 1:N
    p = metrics(k).peak;

    lateral = ...
        results{k}.envelope(p.iz,:) / ...
        (results{k}.envelope(p.iz,p.ix)+eps);

    ydb = 20*log10(lateral+eps);
    ydb(ydb < -60) = -60;

    plot( ...
        results{k}.x_axis*1e3, ...
        ydb, ...
        'LineWidth',1.5, ...
        'DisplayName',labels{k});
end

yline(-6.0206,':','-6 dB');

xlabel('x (mm)');
ylabel('Amplitude relative to target peak (dB)');
title(sprintf('RTB parameter sweep: %s',experiment));

xlim([x0-5e-3,x0+5e-3]*1e3);
ylim([-60 3]);

grid on;
legend('Location','best');

%% ------------------------------------------------------------------------
% Delay-model-specific focal-depth difference
% -------------------------------------------------------------------------
if strcmpi(experiment,'delay_model') && N == 3

    sph = results{1}.envelope / ...
        (max(results{1}.envelope(:))+eps);

    hyb = results{2}.envelope / ...
        (max(results{2}.envelope(:))+eps);

    bld = results{3}.envelope / ...
        (max(results{3}.envelope(:))+eps);

    assert(isequal(size(sph),size(hyb),size(bld)), ...
        'Delay-model cases must use the same grid.');

    focus_z = median(results{1}.source_z);

    figure('Color','w');

    subplot(1,2,1);
    imagesc( ...
        results{1}.x_axis*1e3, ...
        results{1}.z_axis*1e3, ...
        abs(sph-hyb));
    set(gca,'YDir','reverse');
    axis image;
    xlabel('x (mm)');
    ylabel('z (mm)');
    title('|Spherical - Hybrid|');
    ylim(([focus_z-4e-3,focus_z+4e-3])*1e3);
    colorbar;

    subplot(1,2,2);
    imagesc( ...
        results{1}.x_axis*1e3, ...
        results{1}.z_axis*1e3, ...
        abs(hyb-bld));
    set(gca,'YDir','reverse');
    axis image;
    xlabel('x (mm)');
    ylabel('z (mm)');
    title('|Hybrid - Blended|');
    ylim(([focus_z-4e-3,focus_z+4e-3])*1e3);
    colorbar;
end

%% =========================================================================
% Experiment definitions
% =========================================================================
function [cases,labels] = make_cases(experiment,base)

    switch lower(experiment)

        case 'delay_model'
            values = {'spherical','hybrid','blended'};
            labels = {'spherical','hybrid','blended'};
            cases = cell(numel(values),1);

            for k = 1:numel(values)
                cases{k} = base;
                cases{k}.tx_delay_model = values{k};
            end

        case 'x_upsample'
            values = [1 2 4];
            labels = {'x1','x2','x4'};
            cases = cell(numel(values),1);

            for k = 1:numel(values)
                cases{k} = base;
                cases{k}.x_upsample = values(k);
            end

        case 'tx_fnumber'
            values = [1.5 2.0 2.5];
            labels = {'Tx F# 1.5','Tx F# 2.0','Tx F# 2.5'};
            cases = cell(numel(values),1);

            for k = 1:numel(values)
                cases{k} = base;
                cases{k}.tx_f_number = values(k);
            end

        case 'tx_min_aperture'
            values = [1e-3 3e-3 5e-3];
            labels = {'Tx min 1 mm','Tx min 3 mm','Tx min 5 mm'};
            cases = cell(numel(values),1);

            for k = 1:numel(values)
                cases{k} = base;
                cases{k}.tx_min_aperture = values(k);
            end

        case 'pw_margin'
            values = [0.5e-3 1e-3 2e-3];
            labels = {'PW 0.5 mm','PW 1.0 mm','PW 2.0 mm'};
            cases = cell(numel(values),1);

            for k = 1:numel(values)
                cases{k} = base;
                cases{k}.tx_delay_model = 'hybrid';
                cases{k}.pw_margin = values(k);
            end

        case 'rx_fnumber'
            values = [1.0 1.7 2.5];
            labels = {'Rx F# 1.0','Rx F# 1.7','Rx F# 2.5'};
            cases = cell(numel(values),1);

            for k = 1:numel(values)
                cases{k} = base;
                cases{k}.rx_f_number = values(k);
            end


        case 'blending_power'
            values = [0.25 0.5 1.0];
            labels = {'blend p=0.25','blend p=0.5','blend p=1.0'};
            cases = cell(numel(values),1);

            for k = 1:numel(values)
                cases{k} = base;
                cases{k}.tx_delay_model = 'blended';
                cases{k}.blending_power = values(k);
            end

        case 'wave_stride'
            values = [1 2 4];
            labels = {'all Tx','every 2nd Tx','every 4th Tx'};
            cases = cell(numel(values),1);

            for k = 1:numel(values)
                cases{k} = base;
                cases{k}.wave_stride = values(k);
            end

        otherwise
            error('Unknown experiment: %s',experiment);
    end
end

%% =========================================================================
% Metrics
% =========================================================================
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

function db_img = to_db(env,dynamic_range)
    env = env/(max(env(:))+eps);
    db_img = 20*log10(env+eps);
    db_img(db_img < -dynamic_range) = -dynamic_range;
end
