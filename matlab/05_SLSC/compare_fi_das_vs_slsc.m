%% compare_fi_das_vs_slsc.m
% Chapter 5: ONE conventional focused-FI 2-D DAS vs SLSC experiment.
%
% Run from matlab/05_SLSC:
%
%   addpath(genpath('D:/YOUR_USTB_PATH'));
%   compare_fi_das_vs_slsc
%
% SLSC measures short-lag receive-channel RF correlations within a local
% axial kernel. Its pixel value is a COHERENCE metric, not a DAS amplitude.
% Accordingly, DAS uses a dB envelope while SLSC is displayed LINEARLY.
%
% The core also computes a numerically identical Chapter-1 analytic DAS
% branch for complex regression testing.

clearvars -except filename z_min z_max n_z receive_f_number ...
    axial_kernel_lambda lag_fraction max_lag run_das_reference_check;
clc;
close all;

if ~exist('filename','var') || isempty(filename)
    filename='../../data/L7_FI_TheGB.uff';
end
if ~exist('z_min','var') || ~isnumeric(z_min) || ...
        ~isscalar(z_min) || ~isfinite(z_min)
    z_min=5e-3;
end
if ~exist('z_max','var') || ~isnumeric(z_max) || ...
        ~isscalar(z_max) || ~isfinite(z_max)
    z_max=45e-3;
end
if ~exist('n_z','var') || ~isnumeric(n_z) || ...
        ~isscalar(n_z) || ~isfinite(n_z)
    n_z=768;
end
if ~exist('receive_f_number','var') || ...
        ~isnumeric(receive_f_number) || ~isscalar(receive_f_number) ...
        || ~isfinite(receive_f_number)
    receive_f_number=1.7;
end
if ~exist('axial_kernel_lambda','var') || ...
        ~isnumeric(axial_kernel_lambda) || ...
        ~isscalar(axial_kernel_lambda) || ...
        ~isfinite(axial_kernel_lambda)
    axial_kernel_lambda=1.0;
end
if ~exist('lag_fraction','var') || ~isnumeric(lag_fraction) || ...
        ~isscalar(lag_fraction) || ~isfinite(lag_fraction)
    lag_fraction=0.15;
end
if ~exist('max_lag','var') || ~isnumeric(max_lag) || ...
        ~isscalar(max_lag) || ~isfinite(max_lag)
    max_lag=12;
end
if ~exist('run_das_reference_check','var') || ...
        ~isscalar(run_das_reference_check)
    run_das_reference_check=true;
end

%% 1. Tiny deterministic check: coherence is independent of scale.
v=[-1;0.5;1.3;-0.7;2];
rho_self=sum(v.*v)/sqrt(sum(v.^2)*sum(v.^2));
rho_scaled=sum(v.*(4*v))/sqrt(sum(v.^2)*sum((4*v).^2));
rho_opposite=sum(v.*(-v))/sqrt(sum(v.^2)*sum((-v).^2));

assert(abs(rho_self-1)<1e-12 && ...
       abs(rho_scaled-1)<1e-12 && ...
       abs(rho_opposite+1)<1e-12, ...
       'Normalized RF correlation sanity check failed.');

fprintf('Normalized correlation sanity check: PASS\n');

%% 2. Run the same-UFF / same-delay / same-grid reconstruction.
opts=struct();
opts.z_min=z_min;
opts.z_max=z_max;
opts.n_z=n_z;
opts.receive_f_number=receive_f_number;
opts.axial_kernel_lambda=axial_kernel_lambda;
opts.lag_fraction=lag_fraction;
opts.max_lag=max_lag;
opts.verbose=true;

tic;
out=reconstruct_fi_slsc_manual(filename,opts);
elapsed=toc;

assert(all(isfinite(out.slsc_mean(:))), ...
    'SLSC contains non-finite values.');
assert(max(abs(out.slsc_mean(:)))<1+1e-10, ...
    'SLSC mean must be within [-1,1].');
assert(all(out.valid_lag_count(:)<=out.requested_lag_count(:)), ...
    'Effective lag count exceeds requested lag count.');

fprintf('\nRuntime: %.2f s\n',elapsed);

%% 3. Validate the DAS branch against Chapter 1.
if run_das_reference_check
    if isempty(which('reconstruct_fi_scanline_manual'))
        addpath('../01_DAS_Real_UFF');
    end
    assert(~isempty(which('reconstruct_fi_scanline_manual')), ...
        'Chapter-1 reference reconstruction is not on MATLAB path.');

    ropts=struct( ...
        'z_min',z_min,'z_max',z_max,'n_z',n_z, ...
        'receive_aperture_mode','f_number', ...
        'receive_f_number',receive_f_number,'verbose',false);

    reference=reconstruct_fi_scanline_manual(filename,ropts);
    assert(isequal(size(out.das_analytic), ...
                   size(reference.das_analytic)), ...
        'Chapter-1 DAS reference shape differs.');

    delta=out.das_analytic-reference.das_analytic;
    abs_err=max(abs(delta(:)));
    peak=max(abs(reference.das_analytic(:)));
    scaled_err=abs_err/(peak+eps);

    fprintf('Chapter-1 DAS max-peak scaled complex error: %.6e\n', ...
        scaled_err);

    assert(scaled_err<1e-10, ...
        'Chapter-5 DAS does not match Chapter-1 DAS. Check delays.');
end

%% 4. One-to-one image layout; note different physical display quantities.
x=out.x_axis*1e3;
z=out.z_axis*1e3;

figure('Color','w','Position',[60 60 1250 660]);

subplot(1,2,1);
imagesc(x,z,out.das_db);
set(gca,'YDir','reverse');
axis image;
colormap gray;
caxis([-60 0]);
colorbar;
xlabel('x (mm)'); ylabel('z (mm)');
title('DAS: RF envelope (dB, own peak)');

subplot(1,2,2);
imagesc(x,z,out.slsc_display);
set(gca,'YDir','reverse');
axis image;
colormap gray;
caxis([0 1]);
colorbar;
xlabel('x (mm)'); ylabel('z (mm)');
title('SLSC: positive short-lag coherence (linear, scaled)');

sgtitle({ ...
    'Chapter 5: same FI Tx/Rx delays and dynamic Rx aperture', ...
    sprintf(['SLSC kernel=%.2f lambda, Q=%.2f active Rx, ' ...
             'maximum lag=%d'], ...
        out.axial_kernel_lambda_actual, ...
        lag_fraction,max_lag)});

%% 5. Why short lags: average lag-correlation vs lag in central ROI.
% For teaching, not a labeled homogeneous-tissue / target ROI.
nx=numel(x);
ix=round(nx*0.1):round(nx*0.9);
iz=find(z>=15 & z<=30);
if isempty(iz)
    iz=1:numel(z);
end

mean_lag=zeros(1,max_lag);
num_lag=zeros(1,max_lag);

for m=1:max_lag
    corr=out.lag_correlations(iz,ix,m);
    corr=corr(isfinite(corr));
    num_lag(m)=numel(corr);
    if ~isempty(corr)
        mean_lag(m)=mean(corr);
    else
        mean_lag(m)=NaN;
    end
end

valid_pixels=out.valid_lag_count>0;
requested=out.requested_lag_count(valid_pixels);

fprintf('\n===========================================================\n');
fprintf(' DESCRIPTIVE STATS (NOT a DAS/SLSC amplitude comparison)\n');
fprintf('===========================================================\n');
fprintf('lambda                   : %.4f mm\n',out.lambda*1e3);
fprintf('axial kernel             : %d depth samples\n', ...
    out.axial_kernel_samples);
fprintf('valid SLSC pixels        : %d / %d\n', ...
    nnz(valid_pixels),numel(valid_pixels));
if ~isempty(requested)
    fprintf('requested lag median     : %.1f elements\n',median(requested));
end
fprintf('signed coherence range   : [%.4f, %.4f]\n', ...
    min(out.slsc_mean(:)),max(out.slsc_mean(:)));
fprintf('positive display peak    : scaled to 1 (linear)\n');

figure('Color','w','Position',[80 90 1180 540]);

subplot(1,2,1);
plot(1:max_lag,mean_lag,'o-','LineWidth',1.8);
hold on;
yline(0,'--');
grid on;
xlabel('Receive-element lag (number of pitches)');
ylabel('Mean normalized correlation');
title('Short-lag behavior: central ROI, z=15–30 mm');
xlim([1 max_lag]);
ylim([-1 1]);

subplot(1,2,2);
imagesc(x,z,out.requested_lag_count);
set(gca,'YDir','reverse');
axis image;
xlabel('x (mm)'); ylabel('z (mm)');
title('Number of requested lags (dynamic aperture)');
colorbar;

sgtitle('Lag dependence and spatial support; not an image-quality metric');

fprintf('\nInterpretation rules:\n');
fprintf('  1) DAS is an amplitude/dB image; SLSC is a coherence/linear image.\n');
fprintf('  2) SLSC may suppress incoherent clutter but alters speckle statistics.\n');
fprintf('  3) Point targets can have limited conspicuity in classic SLSC.\n');
fprintf('  4) In-vivo or phantom superiority requires separate controlled metrics.\n');
