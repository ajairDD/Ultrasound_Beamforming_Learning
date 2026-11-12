%% compare_rtb_das_vs_nsi.m
% Chapter 6 - ONE dense-grid 2D receive NSI vs RTB-DAS experiment.
%
% Uses the same TheGB 20-mm point target as Chapter 3.
% Why RTB rather than conventional one-Tx/one-scanline FI?
% Receive NSI can generate an extremely narrow lateral profile: FI's
% ~0.298-mm scanline spacing may substantially undersample it.
%
% Run from matlab/06_NSI:
%   addpath(genpath('D:/YOUR_USTB_PATH'));
%   compare_rtb_das_vs_nsi
%
% This script:
%   (1) checks analytic NSI identities on deterministic complex vectors,
%   (2) reconstructs the same RTB grid with DAS and receive NSI,
%   (3) checks RTB-DAS complex data against the independent Chapter-1 core,
%   (4) displays two 2-D images and lateral/three-apodization profiles.
%
% The default dense 2D ROI is x=-4..3 mm, z=18..22.5 mm.
% A full-field high-resolution NSI reconstruction is intentionally not
% the default in this transparent MATLAB teaching implementation.

clearvars -except filename x_min x_max z_min z_max n_x n_z ...
    dc_offset wave_stride run_rtb_reference_check;
clc; close all;

if ~exist('filename','var') || isempty(filename)
    filename='../../data/L7_FI_TheGB.uff';
end
if ~exist('x_min','var') || ~isnumeric(x_min) || ...
        ~isscalar(x_min) || ~isfinite(x_min)
    x_min=-4e-3;
end
if ~exist('x_max','var') || ~isnumeric(x_max) || ...
        ~isscalar(x_max) || ~isfinite(x_max)
    x_max=3e-3;
end
if ~exist('z_min','var') || ~isnumeric(z_min) || ...
        ~isscalar(z_min) || ~isfinite(z_min)
    z_min=18e-3;
end
if ~exist('z_max','var') || ~isnumeric(z_max) || ...
        ~isscalar(z_max) || ~isfinite(z_max)
    z_max=22.5e-3;
end
if ~exist('n_x','var') || ~isnumeric(n_x) || ...
        ~isscalar(n_x) || ~isfinite(n_x) || ...
        n_x<2 || n_x~=round(n_x)
    n_x=281;
end
if ~exist('n_z','var') || ~isnumeric(n_z) || ...
        ~isscalar(n_z) || ~isfinite(n_z) || ...
        n_z<2 || n_z~=round(n_z)
    n_z=181;
end
if ~exist('dc_offset','var') || ~isnumeric(dc_offset) || ...
        ~isscalar(dc_offset) || ~isfinite(dc_offset) || ...
        dc_offset<=0
    dc_offset=0.2;
end
if ~exist('wave_stride','var') || ~isnumeric(wave_stride) || ...
        ~isscalar(wave_stride) || ~isfinite(wave_stride) || ...
        wave_stride<1 || wave_stride~=round(wave_stride)
    wave_stride=1;
end
if ~exist('run_rtb_reference_check','var') || ...
        ~isscalar(run_rtb_reference_check)
    run_rtb_reference_check=true;
end

% Analytic identity checks for the three receives and the image envelope.
% The NSI construction is NONNEGATIVE and upper-bounded by dc*|DAS|.
D_test=[1+2i;2-1i;0.2-0.3i];
Z_test=[0.5-1i;-2+0.3i;0.1+0.2i];
c=dc_offset;
E_test=0.5*(abs(Z_test+c*D_test)+ ...
            abs(-Z_test+c*D_test))-abs(Z_test);
assert(all(E_test>=-1e-12) && ...
       all(E_test<=c*abs(D_test)+1e-12), ...
    'NSI triangle-inequality sanity check failed.');

% A perfectly aligned aperture cancels under zero-mean receive weights.
s_test=ones(8,1)*(1+2i);
wzm_test=[ones(4,1);-ones(4,1)];
assert(abs(wzm_test.'*s_test)<1e-12, ...
    'The zero-mean aperture does not cancel on-axis steering mode.');
fprintf('NSI algebra / zero-mean aperture tests: PASS\n');

%% 1. Same RTB grid, receive DAS and receive NSI.
opts=struct();

opts.x_min=x_min;
opts.x_max=x_max;
opts.n_x=n_x;
opts.z_min=z_min;
opts.z_max=z_max;
opts.n_z=n_z;

opts.dc_offset=dc_offset;
opts.wave_stride=wave_stride;

opts.tx_f_number=2;
opts.tx_min_aperture=3e-3;
opts.tx_window='tukey25';
opts.blending_power=0.5;
opts.rx_f_number=1.7;

opts.display_dynamic_range_db=60;
opts.verbose=true;

tic;
out=reconstruct_fi_rtb_nsi_manual(filename,opts);
runtime=toc;

fprintf('\nRTB NSI runtime: %.2f s\n',runtime);

%% 2. Regression against the independent Chapter-1 RTB code.
if run_rtb_reference_check
    if isempty(which('reconstruct_fi_rtb_manual'))
        addpath('../01_DAS_Real_UFF');
    end
    assert(~isempty(which('reconstruct_fi_rtb_manual')), ...
        'Chapter-1 RTB reference was not found.');

    refopts=struct();
    refopts.x_min=x_min;
    refopts.x_max=x_max;
    refopts.n_x=n_x;
    refopts.z_min=z_min;
    refopts.z_max=z_max;
    refopts.n_z=n_z;
    refopts.wave_stride=wave_stride;
    refopts.tx_delay_model='blended';
    refopts.blending_power=opts.blending_power;
    refopts.tx_f_number=opts.tx_f_number;
    refopts.tx_min_aperture=opts.tx_min_aperture;
    refopts.tx_window=opts.tx_window;
    refopts.rx_aperture_mode='f_number';
    refopts.rx_f_number=opts.rx_f_number;
    refopts.normalize_tx_weights=true;
    refopts.verbose=false;

    reference=reconstruct_fi_rtb_manual(filename,refopts);

    assert(isequal(size(reference.rtb_analytic), ...
                   size(out.rtb_das_analytic)), ...
        'New RTB-DAS / reference output shapes differ.');

    difference=out.rtb_das_analytic-reference.rtb_analytic;
    abs_err=max(abs(difference(:)));
    ref_peak=max(abs(reference.rtb_analytic(:)));
    relative_err=abs_err/(ref_peak+eps);

    fprintf('Chapter-1 RTB-DAS max-peak complex error: %.6e\n', ...
        relative_err);

    assert(relative_err<1e-10, ...
        'RTB-DAS branch is not identical to Chapter-1 RTB.');
end

%% 3. Dense-grid point-target statistics.
x=out.x_axis*1e3;
z=out.z_axis*1e3;

dx=median(abs(diff(x)));
dz=median(abs(diff(z)));

das_env=out.das_envelope;
nsi_env=out.nsi_envelope_das_scale;

% Both methods use the SAME target neighborhood, but their local peaks
% are located independently to avoid silently forcing a common location.
target_x=-0.745;
target_z=20.10;

ix_roi=find(abs(x-target_x)<=1);
iz_roi=find(abs(z-target_z)<=1);

assert(~isempty(ix_roi) && ~isempty(iz_roi), ...
    'The known TheGB point target is not inside the requested ROI.');

[iz_das,ix_das]=roi_peak(das_env,iz_roi,ix_roi);
[iz_nsi,ix_nsi]=roi_peak(nsi_env,iz_roi,ix_roi);

D_peak=das_env(iz_das,ix_das);
N_peak=nsi_env(iz_nsi,ix_nsi);

profile_das=das_env(iz_das,:)/(D_peak+eps);
profile_nsi=nsi_env(iz_nsi,:)/(N_peak+eps);

width_das=width_around_peak(x,profile_das,ix_das,0.5);
width_nsi=width_around_peak(x,profile_nsi,ix_nsi,0.5);

width20_das=width_around_peak(x,profile_das,ix_das,0.1);
width20_nsi=width_around_peak(x,profile_nsi,ix_nsi,0.1);

fprintf('\n==========================================================\n');
fprintf(' RTB POINT-TARGET SUMMARY (descriptive only)\n');
fprintf('==========================================================\n');
fprintf('DC offset            : %.3f\n',dc_offset);
fprintf('Grid dx/dz           : %.4f / %.4f mm\n',dx,dz);
fprintf('RTB-DAS peak (x,z)   : %.4f, %.4f mm\n', ...
    x(ix_das),z(iz_das));
fprintf('RTB-NSI peak (x,z)   : %.4f, %.4f mm\n', ...
    x(ix_nsi),z(iz_nsi));
fprintf('NSI scaled peak/DAS  : %.3f dB\n', ...
    20*log10(N_peak/(D_peak+eps)+eps));
fprintf('Lateral -6dB widths  : DAS %.4f mm | NSI %.4f mm\n', ...
    width_das,width_nsi);
fprintf('Lateral -20dB widths : DAS %.4f mm | NSI %.4f mm\n', ...
    width20_das,width20_nsi);
fprintf('Width / dx           : DAS %.2f | NSI %.2f pixels\n', ...
    width_das/dx,width_nsi/dx);
fprintf('Odd active apertures : %d (zero-weight center element)\n', ...
    out.odd_aperture_count);

%% 4. Figure 1: the same 2-D RTB data and SAME DAS display reference.
figure('Color','w','Position',[50 60 1400 600], ...
    'DefaultAxesFontName','Microsoft YaHei','DefaultTextFontName','Microsoft YaHei');

subplot(1,2,1);
imagesc(x,z,out.das_db);
set(gca,'YDir','reverse');
axis image;
colormap gray;
caxis([-60 0]);
colorbar;
xlabel('横向 x（mm）'); ylabel('深度 z（mm）');
title('RTB-DAS：共同幅度参考');

subplot(1,2,2);
imagesc(x,z,out.nsi_db_common);
set(gca,'YDir','reverse');
axis image;
colormap gray;
caxis([-60 0]);
colorbar;
xlabel('横向 x（mm）'); ylabel('深度 z（mm）');
title('RTB + 接收 NSI：先除以 δ');

sgtitle({ ...
    '同一 RTB 延时、Tx 相干合成与密集二维网格', ...
    sprintf('DC offset δ = %.2f；两图共用 RTB-DAS 的 0 dB 参考', ...
        dc_offset)});

%% 5. Figure 2: profile and the actual three-envelope construction.
figure('Color','w','Position',[80 80 1450 700], ...
    'DefaultAxesFontName','Microsoft YaHei','DefaultTextFontName','Microsoft YaHei');

subplot(1,2,1);
plot(x,clipped_db(profile_das,60),'LineWidth',1.8);
hold on;
plot(x,clipped_db(profile_nsi,60),'LineWidth',1.8);
yline(-6.0206,'--','半幅（−6.02 dB）');
yline(-20,':','-20 dB');
grid on;
xlim(target_x+[-2 2]);
ylim([-60 3]);
xlabel('横向 x（mm）'); ylabel('各自局部峰值归一化幅度（dB）');
title('横向响应：各自峰值与各自峰值深度');
legend('RTB-DAS','RTB-NSI','Location','best');

subplot(1,2,2);
zline=iz_das;

avgdc=0.5*(abs(out.dc1_analytic(zline,:))+ ...
           abs(out.dc2_analytic(zline,:)));
zm=abs(out.zero_mean_analytic(zline,:));
nsi=out.nsi_envelope(zline,:);

norm_ref=max(avgdc)+eps;

plot(x,avgdc/norm_ref,'LineWidth',1.8);
hold on;
plot(x,zm/norm_ref,'LineWidth',1.8);
plot(x,nsi/norm_ref,'LineWidth',2.0,'Color',[0.15 0.5 0.2]);
xlim(target_x+[-2 2]);
ylim([0 1.05]);
grid on;
xlabel('横向 x（mm）'); ylabel('包络 / 此剖面的 DC 平均包络最大值');
title('DAS 目标深度处的实际包络相减');
legend('两路 DC 包络的平均值','ZM 包络','NSI 残差', ...
    'Location','best');

sgtitle('先对三路分别取包络，再相减，留下窄的非负残差');

fprintf('\nScientific limitations:\n');
fprintf('  - Only 2D point-target ROI, not full-field quantitative validation.\n');
fprintf('  - NSI uses coherent Tx combination BEFORE envelope subtraction.\n');
fprintf('  - Scaled NSI output E/dc is bounded by DAS envelope pointwise.\n');
fprintf('  - Narrower lateral FWHM is not automatically true resolving power.\n');
fprintf('  - Very low DC offsets can severely distort speckle / contrast.\n');

%% local helpers
function [iz,ix]=roi_peak(env,izroi,ixroi)
    roi=env(izroi,ixroi);
    [~,k]=max(roi(:));
    [j,i]=ind2sub(size(roi),k);
    iz=izroi(j);
    ix=ixroi(i);
end

function width=width_around_peak(x,y,peak_idx,level)
    width=NaN;
    left=find(y(1:peak_idx)<level,1,'last');
    ri=find(y(peak_idx:end)<level,1,'first');
    if isempty(left) || isempty(ri)
        return;
    end
    right=peak_idx+ri-1;
    if left>=peak_idx || right<=peak_idx
        return;
    end
    xl=crossing(x(left),y(left),x(left+1),y(left+1),level);
    xr=crossing(x(right-1),y(right-1),x(right),y(right),level);
    width=xr-xl;
end

function xx=crossing(x1,y1,x2,y2,level)
    if abs(y2-y1)<=eps
        xx=0.5*(x1+x2);
    else
        xx=x1+(level-y1)*(x2-x1)/(y2-y1);
    end
end

function db=clipped_db(env,rng)
    db=20*log10(env+eps);
    db=max(-rng,db);
end
