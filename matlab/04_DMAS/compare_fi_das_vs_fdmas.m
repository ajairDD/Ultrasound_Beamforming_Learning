%% compare_fi_das_vs_fdmas.m
% Chapter 4: one complete 2-D real-UFF experiment.
%
% DAS vs filtered DMAS (fDMAS) with identical conventional-FI Tx/Rx delays,
% identical Rx F#, and the same output grid.
%
% DMAS is computed on REAL RF, with signed square roots:
%   u_i = sign(s_i)*sqrt(abs(s_i))
%   y = 0.5*((sum(u))^2-sum(u.^2))
%
% fDMAS filters the output around 2*f0 BEFORE envelope detection.
% The depth grid is automatically refined so the chosen 2*f0 band fits.
% This does not guarantee that every nonlinear harmonic is alias-free.
%
% Run from matlab/04_DMAS:
%   addpath(genpath('D:/YOUR_USTB_PATH'));
%   compare_fi_das_vs_fdmas
%
% Optional, for a faster point-target depth-ROI run:
%   z_min=16e-3; z_max=24e-3;
%   compare_fi_das_vs_fdmas
%
% Notes:
%   - DAS and fDMAS have different nonlinear amplitude conventions.
%     Plot images self-normalized to their OWN peaks for morphology only.
%   - A narrower plotted peak is not equivalent to physically validated
%     spatial resolution. Conventional FI lateral sampling is limited.

clearvars -except filename z_min z_max n_z ...
    receive_f_number run_das_reference_check;
clc; close all;

if ~exist('filename','var') || isempty(filename)
    filename='../../data/L7_FI_TheGB.uff';
end
if ~exist('z_min','var') || ~isscalar(z_min)
    z_min=5e-3;
end
if ~exist('z_max','var') || ~isscalar(z_max)
    z_max=45e-3;
end
if ~exist('n_z','var') || ~isempty(n_z) && ...
        (~isscalar(n_z) || ~isfinite(n_z))
    n_z=[];
end
if ~exist('receive_f_number','var') || ...
        ~isscalar(receive_f_number)
    receive_f_number=1.7;
end
if ~exist('run_das_reference_check','var') || ...
        ~isscalar(run_das_reference_check)
    run_das_reference_check=true;
end

% First verify the O(M) algebraic identity against the original
% pairwise definition using a deterministic REAL RF vector.
test_s=[-2,0.5,1.3,-0.8,0,2.2];
test_u=sign(test_s).*sqrt(abs(test_s));
fast=0.5*(sum(test_u).^2-sum(test_u.^2));
slow=0;
for i=1:numel(test_s)-1
    for j=i+1:numel(test_s)
        pair=test_s(i)*test_s(j);
        slow=slow+sign(pair)*sqrt(abs(pair));
    end
end
assert(abs(fast-slow)<1e-12, ...
    'Fast signed-sqrt DMAS identity check failed.');
fprintf('Signed-sqrt DMAS pair identity: PASS (error %.3e)\n', ...
    abs(fast-slow));

opts=struct();
opts.z_min=z_min;
opts.z_max=z_max;
opts.n_z=n_z;
opts.receive_f_number=receive_f_number;
opts.verbose=true;

tic;
out=reconstruct_fi_dmas_fdmas_manual(filename,opts);
elapsed=toc;
fprintf('Runtime: %.2f s\n',elapsed);

%% Independently compare DAS baseline against Chapter-1 core.
if run_das_reference_check
    if isempty(which('reconstruct_fi_scanline_manual'))
        addpath('../01_DAS_Real_UFF');
    end
    assert(~isempty(which('reconstruct_fi_scanline_manual')), ...
        'Cannot find Chapter-1 DAS reference.');

    ref_opts=struct( ...
        'z_min',z_min,'z_max',z_max,'n_z',numel(out.z_axis), ...
        'receive_aperture_mode','f_number', ...
        'receive_f_number',receive_f_number,'verbose',false);

    ref=reconstruct_fi_scanline_manual(filename,ref_opts);
    delta=out.das_analytic-ref.das_analytic;
    err=max(abs(delta(:)));
    scale=max(abs(ref.das_analytic(:)));
    scaled_error=err/(scale+eps);

    fprintf('DAS regression max-peak scaled error: %.6e\n', ...
        scaled_error);

    assert(scaled_error<1e-10, ...
        'Chapter-4 DAS does not reproduce Chapter-1 DAS baseline.');
end

%% Figure 1: complete 2-D images, EACH method normalized to itself.
x=out.x_axis*1e3;
z=out.z_axis*1e3;

figure('Color','w','Position',[50 50 1250 650]);

subplot(1,2,1);
imagesc(x,z,out.das_db);
set(gca,'YDir','reverse');
axis image;
caxis([-60 0]); colorbar;
colormap gray;
xlabel('x (mm)'); ylabel('z (mm)');
title('DAS (own peak = 0 dB)');

subplot(1,2,2);
imagesc(x,z,out.fdmas_db_self);
set(gca,'YDir','reverse');
axis image;
caxis([-60 0]); colorbar;
colormap gray;
xlabel('x (mm)'); ylabel('z (mm)');
title('fDMAS (own peak = 0 dB)');

sgtitle({ ...
    'Chapter 4: conventional focused FI, identical delay/aperture', ...
    'Own-peak normalized: compare morphology, NOT absolute amplitude'});

%% Figure 2: one point-target lateral profile + spectral sanity check.
target_x=-0.745;
target_z=20.1;

ix_roi=find(abs(x-target_x)<1.2);
iz_roi=find(abs(z-target_z)<1.2);

if ~isempty(ix_roi) && ~isempty(iz_roi)
    [iz_das,ix_das]=peak_in_roi(out.das_envelope,iz_roi,ix_roi);
    [iz_fd,ix_fd]=peak_in_roi(out.fdmas_envelope,iz_roi,ix_roi);

    das_profile=out.das_envelope(iz_das,:);
    fd_profile=out.fdmas_envelope(iz_fd,:);

    % Normalize to the selected LOCAL target peak, not a stronger target
    % elsewhere on the same depth row. Widths refer to this local target.
    das_profile=das_profile/(out.das_envelope(iz_das,ix_das)+eps);
    fd_profile=fd_profile/(out.fdmas_envelope(iz_fd,ix_fd)+eps);

    [das_width,das_samples]=fwhm(x,das_profile,ix_das);
    [fd_width,fd_samples]=fwhm(x,fd_profile,ix_fd);

    fprintf('\nPoint-target lateral profile (conventional FI):\n');
    fprintf('  Selected DAS peak   : x=%.5f mm, z=%.5f mm\n',x(ix_das),z(iz_das));
    fprintf('  Selected fDMAS peak : x=%.5f mm, z=%.5f mm\n',x(ix_fd),z(iz_fd));
    fprintf('  Lateral spacing    : %.6f mm\n',median(diff(x)));
    fprintf('  DAS FWHM       : %.4f mm  (%.2f grid intervals)\n', ...
        das_width,das_samples);
    fprintf('  fDMAS FWHM     : %.4f mm  (%.2f grid intervals)\n', ...
        fd_width,fd_samples);
    fprintf('  Note: these FWHM estimates are sampling-limited.\n');
else
    das_profile=[];
    fd_profile=[];
    fprintf('Known point target not inside the requested z ROI.\n');
end

% Spectral sanity check: raw DMAS contains low-frequency energy and
% 2*f0 neighborhood, which fDMAS intentionally separates.
[~,ix_spec]=min(abs(x-target_x));
Nfft=2^nextpow2(numel(z));
freq=(0:floor(Nfft/2)).'*out.image_fs_z/Nfft;
p_before=abs(fft(out.dmas_unfiltered(:,ix_spec),Nfft));
p_after=abs(fft(out.fdmas_filtered(:,ix_spec),Nfft));
p_before=p_before(1:numel(freq));
p_after=p_after(1:numel(freq));
spec_ref=max(p_before)+eps;
before_db=20*log10(p_before/spec_ref+eps);
after_db=20*log10(p_after/spec_ref+eps);

figure('Color','w','Position',[80 80 1200 530]);

subplot(1,2,1);
if ~isempty(das_profile)
    plot(x,20*log10(das_profile+eps),'-o','LineWidth',1.8,'MarkerSize',4);
    hold on;
    plot(x,20*log10(fd_profile+eps),'-s','LineWidth',1.8,'MarkerSize',4);
    yline(-6.0206,'--','Half amplitude');
    xlim(target_x+[-3 3]);
    ylim([-60 3]);
    legend('DAS','fDMAS','Location','best');
else
    text(0.15,0.5,'Known target is outside z ROI','Units','normalized');
end
xlabel('x (mm)'); ylabel('Relative amplitude (dB)');
title('Local target: each method uses its own peak / slice');
grid on;

subplot(1,2,2);
plot(freq/1e6,before_db,'LineWidth',1.3);
hold on;
plot(freq/1e6,after_db,'LineWidth',1.3);
xline(out.nominal_f0/1e6,'--','f_0', ...
    'LabelVerticalAlignment','bottom','LabelOrientation','horizontal');
xline(2*out.nominal_f0/1e6,'--','2f_0', ...
    'LabelVerticalAlignment','bottom','LabelOrientation','horizontal');
xlim([0 3.2*out.nominal_f0/1e6]);
ylim([-80 5]);
xlabel('Axial image-time frequency (MHz)');
ylabel('Magnitude relative to unfiltered peak (dB)');
title('DMAS output before vs after 2f_0 filtering');
legend('Unfiltered DMAS','Filtered DMAS','Location','best');
grid on;

fprintf('\nScientific interpretation:\n');
fprintf(['  DMAS/fDMAS uses channel-pair nonlinear combination; it does not\n' ...
         '  estimate an MVDR covariance matrix.\n']);
fprintf(['  This real-RF fDMAS uses a 2*f0 band-pass; the chosen band fits\n' ...
         '  below output-grid Nyquist. Higher harmonics need separate care.\n']);
fprintf(['  Images are independently peak-normalized because fDMAS has a\n' ...
         '  DIFFERENT amplitude response. Do not infer gain or loss in dB\n' ...
         '  from the side-by-side self-normalized images.\n']);
fprintf(['  Better-looking speckle/contrast does not prove a clinical gain.\n']);

%% Helpers (MATLAB R2016b+ scripts allow local functions).
function [iz,ix]=peak_in_roi(env,iz_roi,ix_roi)
    cut=env(iz_roi,ix_roi);
    [~,idx]=max(cut(:));
    [j,i]=ind2sub(size(cut),idx);
    iz=iz_roi(j); ix=ix_roi(i);
end

function [width,n_pixels]=fwhm(x,y,peak_idx)
    width=NaN; n_pixels=NaN;
    left=find(y(1:peak_idx)<0.5,1,'last');
    rr=find(y(peak_idx:end)<0.5,1,'first');
    if isempty(left) || isempty(rr)
        return;
    end
    right=peak_idx+rr-1;
    if right<=peak_idx || left>=peak_idx
        return;
    end
    x_left=interp_cross(x(left),y(left),x(left+1),y(left+1),0.5);
    x_right=interp_cross(x(right-1),y(right-1), ...
                        x(right),y(right),0.5);
    width=x_right-x_left;
    n_pixels=width/median(diff(x));
end

function xc=interp_cross(x1,y1,x2,y2,level)
    if abs(y2-y1)<eps
        xc=0.5*(x1+x2);
    else
        xc=x1+(level-y1)*(x2-x1)/(y2-y1);
    end
end
