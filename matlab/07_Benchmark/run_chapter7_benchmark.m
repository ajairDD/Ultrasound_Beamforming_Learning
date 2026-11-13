%% run_chapter7_benchmark.m
% CHAPTER 7 - fair, task-stratified ultrasound beamforming benchmark.
%
% Two INDEPENDENT experiment tracks on real L7_FI_TheGB.uff:
%
%   FI : conventional focused scanline DAS / CF / GCF / MVDR /
%        fDMAS / SLSC, same focused Tx and same output [z,scanline].
%
%   RTB: dense receive RTB-DAS / RTB-MVDR / RTB-NSI(c=0.2,0.8),
%        identical Tx model/weights/Rx F-number/Tx coherent compounding.
%
% NEVER pool FI vs RTB point widths into one ranking:
%   conventional FI x spacing (~0.298 mm) undersamples very narrow peaks.
%
% Fi example:
%   cd matlab/07_Benchmark
%   addpath(genpath('D:/YOUR_USTB_PATH'));
%   run_chapter7_benchmark
%
% Optional:
%   benchmark_mode='fi';   % only FI (much less compute)
%   benchmark_mode='rtb';  % only dense RTB
%   benchmark_mode='both'; % both (default)
%
% Contrast metrics are ONLY generated with EXPLICIT lesion/background ROIs:
%   contrast_rois_mm = [xmin xmax zmin zmax; ...
%                       xmin xmax zmin zmax];
% Default [] means "not measured"; no fabricated ground truth.
%
% Figure/csv outputs are saved under ../../output/benchmark/ch07/ on the
% user's local computer. No raw UFF is committed to GitHub.
%
% Scientific caveats:
% - runtime includes UFF loading, analytic conversion & baseline computation
%   inside each core; this is WHOLE PIPELINE runtime, not pure algorithm cost.
% - SLSC is a coherence image; no absolute-amplitude or PSF ranking with DAS.
% - fDMAS changes frequency content and has a different amplitude scale.
% - Even if FI methods share grid, narrow FI FWHM can be undersampled.
% - Speckle correlation relative to DAS is similarity, NOT ground truth.
% - No clinical superiority / lesion detectability without labeled ROIs.

clearvars -except benchmark_mode fi_filename rtb_filename ...
    fi_z_min fi_z_max rtb_n_x rtb_n_z ...
    contrast_rois_mm speckle_roi_mm save_reports;
clc; close all;

if ~exist('benchmark_mode','var') || isempty(benchmark_mode)
    benchmark_mode='both';
end
assert(ischar(benchmark_mode) || ...
       (isstring(benchmark_mode) && isscalar(benchmark_mode)), ...
    'benchmark_mode must be fi, rtb or both.');
benchmark_mode=lower(char(benchmark_mode));
assert(ismember(benchmark_mode,{'fi','rtb','both'}), ...
    'benchmark_mode must be fi, rtb or both.');

if ~exist('fi_filename','var') || isempty(fi_filename)
    fi_filename='../../data/L7_FI_TheGB.uff';
end
if ~exist('rtb_filename','var') || isempty(rtb_filename)
    rtb_filename='../../data/L7_FI_TheGB.uff';
end
if ~exist('fi_z_min','var') || isempty(fi_z_min)
    fi_z_min=16e-3;
end
if ~exist('fi_z_max','var') || isempty(fi_z_max)
    fi_z_max=24e-3;
end
if ~exist('rtb_n_x','var') || isempty(rtb_n_x)
    rtb_n_x=161;
end
if ~exist('rtb_n_z','var') || isempty(rtb_n_z)
    rtb_n_z=161;
end
if ~exist('contrast_rois_mm','var')
    contrast_rois_mm=[];
end
if ~exist('speckle_roi_mm','var') || isempty(speckle_roi_mm)
    % This is a DESCRIPTIVE background window, not a certified
    % homogeneous/ground-truth ROI.
    speckle_roi_mm=[-12,-8,18,22];
end
if ~exist('save_reports','var') || isempty(save_reports)
    save_reports=true;
end

% Make all prior Chapter cores available, without duplicating code.
addpath('../01_DAS_Real_UFF');
addpath('../02_CF_GCF');
addpath('../03_MVDR');
addpath('../04_DMAS');
addpath('../05_SLSC');
addpath('../06_NSI');

assert(~isempty(which('uff.read_object')), ...
    'USTB UFF reader missing. Add USTB to MATLAB path first.');

% Small deterministic numeric contract tests for ROI histogram estimator.
xx=(0:9)*1e-3;
zz=(0:9)*1e-3;
separate=[zeros(5,10);ones(5,10)];
target_roi=[0 9 0 4];
background_roi=[0 9 5 9];
t=benchmark_ch7_contrast(separate,xx,zz, ...
    target_roi,background_roi);
u=benchmark_ch7_contrast(ones(10,10),xx,zz, ...
    target_roi,background_roi);
assert(abs(t.gCNR-1)<1e-12 && abs(u.gCNR)<1e-12, ...
    'gCNR synthetic separated/identical distribution check failed.');
fprintf('gCNR synthetic sanity tests: PASS\n');

report_dir=fullfile('..','..','output','benchmark','ch07');
if save_reports && ~exist(report_dir,'dir')
    mkdir(report_dir);
end

if strcmp(benchmark_mode,'fi') || strcmp(benchmark_mode,'both')
    fi_options=struct();
    fi_options.filename=fi_filename;
    fi_options.z_min=fi_z_min;
    fi_options.z_max=fi_z_max;
    fi_options.speckle_roi_mm=speckle_roi_mm;
    fi_options.contrast_rois_mm=contrast_rois_mm;
    fi_options.report_dir=report_dir;
    fi_options.save_reports=save_reports;
    run_fi_track(fi_options);
end

if strcmp(benchmark_mode,'rtb') || strcmp(benchmark_mode,'both')
    rtb_options=struct();
    rtb_options.filename=rtb_filename;
    rtb_options.n_x=rtb_n_x;
    rtb_options.n_z=rtb_n_z;
    rtb_options.report_dir=report_dir;
    rtb_options.save_reports=save_reports;
    run_rtb_track(rtb_options);
end

fprintf('\n============================================================\n');
fprintf(' Chapter-7 benchmark runner completed.\n');
fprintf(' Images and metrics must be interpreted WITH dataset/ROI caveats.\n');
fprintf(' No method is declared universally best.\n');
fprintf('============================================================\n');

%% ========================================================================
function run_fi_track(o)
    fprintf('\n============ TRACK A: conventional focused FI ============\n');

    assert(exist(o.filename,'file')==2, ...
        'Missing FI UFF: %s',o.filename);
    cd=uff.read_object(o.filename,'/channel_data');
    lambda=cd.lambda;

    % Shared sufficiently dense axial image-time grid for fDMAS 2*f0
    % bandpass and meaningful SLSC axial gates.
    nz=ceil((o.z_max-o.z_min)/(lambda/16))+1;
    fprintf('FI grid: z %.2f–%.2f mm, n_z=%d, dz~lambda/16\n', ...
        o.z_min*1e3,o.z_max*1e3,nz);

    opts=struct('z_min',o.z_min,'z_max',o.z_max,'n_z',nz, ...
        'receive_aperture_mode','f_number', ...
        'receive_f_number',1.7,'verbose',false);

    t=tic;
    das=reconstruct_fi_scanline_manual(o.filename,opts);
    times=zeros(6,1);
    times(1)=toc(t);
    fprintf('DAS      : %.2f s\n',times(1));

    t=tic;
    cf=reconstruct_fi_cf_manual(o.filename,opts);
    times(2)=toc(t);
    verify_fi_reference(das,cf.das_analytic,cf.x_axis,cf.z_axis,'CF');
    fprintf('CF       : %.2f s\n',times(2));

    o_gcf=opts; o_gcf.M0=1;
    t=tic;
    gcf=reconstruct_fi_gcf_manual(o.filename,o_gcf);
    times(3)=toc(t);
    verify_fi_reference(das,gcf.das_analytic,gcf.x_axis,gcf.z_axis,'GCF');
    fprintf('GCF M0=1 : %.2f s\n',times(3));

    o_mv=opts;
    o_mv.subarray_fraction=0.5;
    o_mv.diagonal_loading=0.01;
    o_mv.axial_averaging_lambda=1.5;
    o_mv.forward_backward=false;
    t=tic;
    mv=reconstruct_fi_mvdr_manual(o.filename,o_mv);
    times(4)=toc(t);
    verify_fi_reference(das,mv.das_analytic,mv.x_axis,mv.z_axis,'MVDR');
    fprintf('MVDR     : %.2f s\n',times(4));

    o_fd=struct('z_min',o.z_min,'z_max',o.z_max,'n_z',nz, ...
        'receive_f_number',1.7,'verbose',false);
    t=tic;
    fd=reconstruct_fi_dmas_fdmas_manual(o.filename,o_fd);
    times(5)=toc(t);
    verify_fi_reference(das,fd.das_analytic,fd.x_axis,fd.z_axis,'fDMAS');
    fprintf('fDMAS    : %.2f s\n',times(5));

    o_slsc=struct('z_min',o.z_min,'z_max',o.z_max,'n_z',nz, ...
        'receive_f_number',1.7,'axial_kernel_lambda',1.0, ...
        'lag_fraction',0.15,'max_lag',12,'verbose',false);
    t=tic;
    slsc=reconstruct_fi_slsc_manual(o.filename,o_slsc);
    times(6)=toc(t);
    verify_fi_reference(das,slsc.das_analytic, ...
        slsc.x_axis,slsc.z_axis,'SLSC');
    fprintf('SLSC     : %.2f s\n',times(6));

    labels=["DAS";"CF";"GCF (M0=1)";"MVDR";"fDMAS";"SLSC"];
    imgs={das.envelope,cf.cf_envelope,gcf.gcf_envelope, ...
        mv.mvdr_envelope,fd.fdmas_envelope,slsc.slsc_display};

    is_same_amplitude=[true,true,true,true,false,false];

    % Point target is a known teaching landmark only for TheGB.
    if contains(lower(char(o.filename)),'thegb')
        point_mm=[-0.745,20.1];
    else
        point_mm=[];
        fprintf('FI file is not TheGB: no point-target ground location assumed.\n');
    end

    x=das.x_axis;
    z=das.z_axis;
    N=numel(labels);
    width=nan(N,1); width_samples=nan(N,1);
    axial_width=nan(N,1); w20=nan(N,1);
    cv=nan(N,1); speckle_snr=nan(N,1); corr=nan(N,1);
    peak_change_db=nan(N,1);
    speckle_pixels=zeros(N,1);

    for k=1:N
        mopts=struct('point_mm',point_mm, ...
            'point_radius_mm',1.2, ...
            'measure_psf',k~=N, ...
            'speckle_roi_mm',o.speckle_roi_mm, ...
            'reference',das.envelope);
        mt=benchmark_ch7_metrics(imgs{k},x,z,mopts);
        width(k)=mt.lateral_fwhm_mm;
        width_samples(k)=mt.lateral_width_samples;
        axial_width(k)=mt.axial_fwhm_mm;
        w20(k)=mt.lateral_w20_mm;
        cv(k)=mt.speckle_cv;
        speckle_snr(k)=mt.speckle_snr;
        corr(k)=mt.corr_with_das;
        speckle_pixels(k)=mt.speckle_n_pixels;

        % Quantitative peak amplitude comparable only in the same
        % amplitude convention. CF/GCF/MVDR retain nominal DAS scale;
        % fDMAS and SLSC do not.
        if ~isempty(point_mm) && is_same_amplitude(k)
            ix=find(abs(x*1e3-point_mm(1))<=1.2);
            iz=find(abs(z*1e3-point_mm(2))<=1.2);
            part=imgs{k}(iz,ix);
            base=das.envelope(iz,ix);
            peak_change_db(k)=20*log10( ...
                (max(part(:))+eps)/(max(base(:))+eps));
        end
    end

    fi_table=table(labels,times,width,width_samples,axial_width, ...
        w20,peak_change_db,cv,speckle_snr,corr,speckle_pixels, ...
        'VariableNames',{'method','runtime_s','lat_FWHM_mm', ...
          'lat_FWHM_in_scanlines','axial_FWHM_mm', ...
          'lat_20dB_mm','local_peak_vs_DAS_dB', ...
          'speckle_CV','speckle_SNR','speckle_corr_DAS','speckle_n'});

    disp(fi_table);
    fprintf(['FI NOTE: <3 scanlines across FWHM is sampling-limited; ' ...
        'fDMAS spectral band differs; SLSC is a coherence image.\n']);
    fprintf(['Speckle ROI is not independently certified homogeneous: ' ...
        '[%s] mm.\n'],num2str(o.speckle_roi_mm));
    fprintf(['Speckle correlation is similarity to DAS, not validated ' ...
        'preservation of true tissue reflectivity.\n']);

    fig1=figure('Color','w','Position',[30 30 1450 770]);
    for k=1:N
        subplot(2,3,k);
        if k==N
            imagesc(x*1e3,z*1e3,imgs{k});
            caxis([0 1]);
            title('SLSC: linear coherence (not dB)');
        else
            env=imgs{k};
            peak=max(env(:));
            disp_db=max(-60,20*log10(env/(peak+eps)+eps));
            imagesc(x*1e3,z*1e3,disp_db);
            caxis([-60 0]);
            title(char(labels(k))+" own-peak dB");
        end
        set(gca,'YDir','reverse');
        colormap gray; colorbar; axis image;
        xlabel('x (mm)'); ylabel('z (mm)');
    end
    sgtitle({'Chapter 7 / Track A: same conventional focused FI geometry', ...
        'Envelope methods: own-peak dB; SLSC: linear coherence (not comparable brightness)'});

    % Optional explicitly labeled contrast ROIs, on EXACT same grid.
    if ~isempty(o.contrast_rois_mm)
        boxes=o.contrast_rois_mm;
        assert(isnumeric(boxes) && isequal(size(boxes),[2 4]), ...
            'contrast_rois_mm must have exactly two [xmin xmax zmin zmax] rows.');
        gcnr=nan(N,1); cnr=nan(N,1); cr=nan(N,1);
        hist_bins=zeros(N,1);
        for k=1:N
            if k==N
                contrast_input=slsc.slsc_mean; % signed coherence
            else
                contrast_input=imgs{k};
            end
            stat=benchmark_ch7_contrast(contrast_input,x,z, ...
                boxes(1,:),boxes(2,:));
            gcnr(k)=stat.gCNR;
            hist_bins(k)=stat.n_hist_bins;
            if k~=N
                cnr(k)=stat.CNR;
                cr(k)=stat.CR_dB;
            end
        end
        contrast_table=table(labels,gcnr,cnr,cr,hist_bins, ...
            'VariableNames',{'method','gCNR','CNR','CR_dB','hist_bins'});
        disp(contrast_table);
        fprintf('ROI [target; background], mm:\n');
        disp(boxes);
        if o.save_reports
            writetable(contrast_table,fullfile(o.report_dir,'FI_contrast.csv'));
        end
    else
        fprintf(['No verified lesion/background ROIs provided -> ' ...
            'CR, CNR and gCNR NOT measured (by design).\n']);
    end

    if o.save_reports
        writetable(fi_table,fullfile(o.report_dir,'FI_metrics.csv'));
        saveas(fig1,fullfile(o.report_dir,'FI_images.png'));
        save(fullfile(o.report_dir,'FI_configuration.mat'), ...
            'o','opts','o_gcf','o_mv','o_fd','o_slsc','point_mm');
        fprintf('FI results saved: %s\n',o.report_dir);
    end
end

function verify_fi_reference(das,image,x,z,label)
    assert(isequal(size(image),size(das.das_analytic)), ...
        '%s DAS shape differs from Chapter-1 FI baseline.',label);
    assert(max(abs(x(:)-das.x_axis(:)))<1e-10 && ...
           max(abs(z(:)-das.z_axis(:)))<1e-10, ...
        '%s FI output grid differs.',label);
    err=image-das.das_analytic;
    scaled=max(abs(err(:)))/(max(abs(das.das_analytic(:)))+eps);
    fprintf('  %-6s vs Chapter-1 FI DAS error = %.3e\n',label,scaled);
    assert(scaled<1e-10, ...
        '%s changed DAS baseline; stop before comparing methods.',label);
end

%% ========================================================================
function run_rtb_track(o)
    fprintf('\n============== TRACK B: dense RTB point target =============\n');
    assert(exist(o.filename,'file')==2,'Missing RTB UFF: %s',o.filename);
    assert(contains(lower(char(o.filename)),'thegb'), ...
        ['RTB point-target benchmark uses the known TheGB target ' ...
         'at x=-0.745mm z=20.1mm. Do not label arbitrary in-vivo ' ...
         'structures as a point target.']);

    % Both cores must use exactly the same independent RTB geometry.
    common=struct('x_min',-2.5e-3,'x_max',1.5e-3, ...
        'z_min',18.5e-3,'z_max',22.5e-3, ...
        'n_x',o.n_x,'n_z',o.n_z, ...
        'wave_stride',1,'tx_f_number',2, ...
        'tx_min_aperture',3e-3,'tx_window','tukey25', ...
        'blending_power',0.5,'verbose',false);

    vm=common;
    vm.tx_delay_model='blended';
    vm.rx_aperture_mode='f_number';
    vm.rx_f_number=1.7;
    vm.normalize_tx_weights=true;
    vm.subarray_fraction=0.5;
    vm.diagonal_loading=0.01;
    vm.axial_averaging_lambda=1.5;
    vm.forward_backward=false;

    t=tic;
    a=reconstruct_fi_rtb_mvdr_manual(o.filename,vm);
    time_mvdr=toc(t);
    fprintf('RTB-DAS + RTB-MVDR core: %.2f s\n',time_mvdr);

    ns=common;
    ns.rx_f_number=1.7;
    ns.dc_offset=0.2;
    ns.use_full_tx_span=false;

    t=tic;
    b=reconstruct_fi_rtb_nsi_manual(o.filename,ns);
    time_nsi=toc(t);
    fprintf('RTB-DAS + RTB-NSI core : %.2f s\n',time_nsi);

    assert(isequal(size(a.rtb_das_analytic),size(b.rtb_das_analytic)), ...
        'RTB baseline grid shape differs.');
    assert(max(abs(a.x_axis(:)-b.x_axis(:)))<1e-10 && ...
           max(abs(a.z_axis(:)-b.z_axis(:)))<1e-10, ...
        'RTB baseline x/z grid differs.');
    difference=a.rtb_das_analytic-b.rtb_das_analytic;
    scaled=max(abs(difference(:)))/ ...
        (max(abs(a.rtb_das_analytic(:)))+eps);
    fprintf('Independent RTB DAS branch difference: %.3e\n',scaled);
    assert(scaled<1e-10, ...
        'RTB DAS branches disagree. Do not compare MVDR and NSI.');

    % Since the complex D and Z beams depend only on the waveform and
    % aperture, NSI(c=0.8) can be computed algebraically WITHOUT rerunning
    % the entire UFF beamforming core.
    D=b.rtb_das_analytic;
    Z=b.zero_mean_analytic;
    e08=nsi_with_dc(D,Z,0.8);

    imgs={b.das_envelope,a.rtb_mvdr_envelope, ...
        b.nsi_envelope_das_scale,e08};

    labels=["RTB-DAS";"RTB-MVDR";"RTB-NSI (c=0.2)";"RTB-NSI (c=0.8)"];
    x=b.x_axis; z=b.z_axis;
    n=4;

    width=nan(n,1); axial=nan(n,1);
    w20=nan(n,1); width_samples=nan(n,1);
    peak_x=nan(n,1); peak_z=nan(n,1); peak_delta=nan(n,1);
    point_mm=[-0.745,20.1];

    roi_x=abs(x(:)*1e3-point_mm(1))<=1.2;
    roi_z=abs(z(:)*1e3-point_mm(2))<=1.2;
    base_roi=imgs{1}(roi_z,roi_x);
    base_peak=max(base_roi(:));

    for k=1:n
        m=benchmark_ch7_metrics(imgs{k},x,z, ...
            struct('point_mm',point_mm,'point_radius_mm',1.2));
        width(k)=m.lateral_fwhm_mm;
        width_samples(k)=m.lateral_width_samples;
        axial(k)=m.axial_fwhm_mm;
        w20(k)=m.lateral_w20_mm;
        peak_x(k)=m.peak_x_mm;
        peak_z(k)=m.peak_z_mm;

        part=imgs{k}(roi_z,roi_x);
        peak_delta(k)=20*log10((max(part(:))+eps)/(base_peak+eps));
    end

    % Each core re-calculates DAS internally. These are NOT pure-kernel
    % timing numbers; c=0.8 is generated from the same cached D,Z data.
    runtime_s=[time_nsi;time_mvdr;time_nsi;NaN];

    rtb_table=table(labels,runtime_s,peak_x,peak_z,width, ...
        width_samples,axial,w20,peak_delta, ...
        'VariableNames',{'method','full_core_runtime_s', ...
        'peak_x_mm','peak_z_mm','lat_FWHM_mm', ...
        'lat_FWHM_in_pixels','axial_FWHM_mm', ...
        'lat_20dB_mm','point_peak_vs_DAS_dB'});
    disp(rtb_table);

    fig2=figure('Color','w','Position',[60 60 1300 760]);
    peak=max(imgs{1}(:));
    for k=1:n
        subplot(2,2,k);
        image_db=max(-60,20*log10(imgs{k}/(peak+eps)+eps));
        imagesc(x*1e3,z*1e3,image_db);
        set(gca,'YDir','reverse'); axis image;
        caxis([-60 0]); colormap gray; colorbar;
        xlabel('x (mm)'); ylabel('z (mm)');
        title(char(labels(k))+" (common DAS reference)");
    end
    sgtitle({'Chapter 7 / Track B: identical RTB geometry and Tx compounding', ...
       'Common DAS 0-dB reference; two NSI offsets share the same D/Z RF beamforming'});

    if o.save_reports
        writetable(rtb_table,fullfile(o.report_dir,'RTB_metrics.csv'));
        saveas(fig2,fullfile(o.report_dir,'RTB_images.png'));
        save(fullfile(o.report_dir,'RTB_configuration.mat'), ...
            'o','vm','ns','common','point_mm');
        fprintf('RTB results saved: %s\n',o.report_dir);
    end

    fprintf(['RTB NOTE: point-target FWHM is a descriptive beam response, ' ...
        'NOT proven two-target resolving power.\n']);
    fprintf(['NSI c=0.8 is derived using the same D and Z beams; ' ...
        'its runtime is not a separate full reconstruction.\n']);
end

function e=nsi_with_dc(D,Z,c)
    assert(c>0,'DC offset must be positive.');
    residual=0.5*(abs(Z+c*D)+abs(-Z+c*D))-abs(Z);
    tol=1e-10*max(1,max(abs(c*D(:))));
    assert(all(residual(:)>=-tol) && ...
           all(residual(:)<=c*abs(D(:))+tol), ...
        'NSI envelope violates the theoretical triangle-inequality bound.');
    e=max(residual,0)/c;
end
