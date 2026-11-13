function relative_error = test_rtb_universal_vs_chapter1(filename)
%TEST_RTB_UNIVERSAL_VS_CHAPTER1 Independent UFF focused-RTB DAS regression.
%
% Requires USTB plus original Chapter-1 RTB reference on MATLAB path.
% Compares COMPLEX values on EXACT same geometry/Tx/Rx support, not dB.
%
% Run:
%   addpath('../01_DAS_Real_UFF');
%   test_rtb_universal_vs_chapter1
%
% Optional: test another verified focused-FI UFF acquisition:
%   test_rtb_universal_vs_chapter1('../../data/L7_FI_carotid_cross_1.uff')
%
% Numerical regression tests the common RTB geometry and indexing; it
% does NOT independently validate CF/GCF/MVDR/fDMAS/SLSC scientific claims.

    if nargin<1 || isempty(filename)
        filename='../../data/L7_FI_TheGB.uff';
    end
    assert(~isempty(which('reconstruct_fi_rtb_manual')), ...
        'Add the Chapter-1 RTB core folder to MATLAB path.');
    assert(exist(filename,'file')==2,'Missing UFF %s',filename);

    acq=rtb_load_acquisition(filename);
    % UFF HDF5 may store scan geometry as single precision. Chapter-1
    % directly accesses UFF properties; the universal adapter converts
    % them to double by design. Such dtype differences can affect an
    % aperture boundary or sub-sample interpolation.
    probe_raw=uff.read_object(filename,'/channel_data');
    fprintf('Original UFF classes: channel=%s, probe.x=%s, source.x=%s, source.distance=%s, wave.delay=%s, sample_fs=%s\n', ...
        class(probe_raw.data),class(probe_raw.probe.x), ...
        class(probe_raw.sequence(1).source.x), ...
        class(probe_raw.sequence(1).source.distance), ...
        class(probe_raw.sequence(1).delay), ...
        class(probe_raw.sampling_frequency));
    x0=median(acq.focus_xyz_m(:,1));
    focus_depth=median(acq.focus_xyz_m(:,3));
    x_min=max(min(acq.focus_xyz_m(:,1)),x0-2e-3);
    x_max=min(max(acq.focus_xyz_m(:,1)),x0+2e-3);
    z_min=max(2e-3,focus_depth-1e-3);
    z_max=focus_depth+1e-3;

    cfg=struct();
    cfg.methods={'DAS'};
    cfg.x_range_m=[x_min,x_max];
    cfg.z_range_m=[z_min,z_max];
    cfg.n_x=41;
    cfg.n_z=45;
    cfg.wave_stride=8;
    cfg.tx_delay_model='blended';
    cfg.blending_power=0.5;
    cfg.tx_f_number=2;
    cfg.tx_min_aperture_m=3e-3;
    cfg.tx_window='tukey25';
    cfg.rx_f_number=1.7;
    cfg.verbose=false;

    a=rtb_reconstruct_all(filename,cfg);

    options=struct();
    options.x_min=x_min;
    options.x_max=x_max;
    options.z_min=z_min;
    options.z_max=z_max;
    options.n_x=cfg.n_x;
    options.n_z=cfg.n_z;
    options.wave_stride=cfg.wave_stride;
    options.tx_delay_model=cfg.tx_delay_model;
    options.blending_power=cfg.blending_power;
    options.tx_f_number=cfg.tx_f_number;
    options.tx_min_aperture=cfg.tx_min_aperture_m;
    options.tx_window=cfg.tx_window;
    options.rx_aperture_mode='f_number';
    options.rx_f_number=cfg.rx_f_number;
    options.normalize_tx_weights=true;
    options.verbose=false;
    b=reconstruct_fi_rtb_manual(filename,options);

    assert(isequal(size(a.rtb_das_analytic),size(b.rtb_analytic)), ...
        'RTB complex output shapes differ.');
    assert(max(abs(a.x_axis_m-b.x_axis))<1e-12 && ...
           max(abs(a.z_axis_m-b.z_axis))<1e-12, ...
        'RTB output axes differ.');
    residual=a.rtb_das_analytic-b.rtb_analytic;
    [max_diff,linear_index]=max(abs(residual(:)));
    relative_error=max_diff/(max(abs(b.rtb_analytic(:)))+eps);
    [iz,ix]=ind2sub(size(residual),linear_index);
    txw_delta=abs(a.tx_weight_sum-b.tx_weight_sum);
    [txw_diff,ixw]=max(txw_delta(:));
    [izw,jxw]=ind2sub(size(txw_delta),ixw);
    fprintf('UNIVERSAL RTB vs CHAPTER-1 DAS: %.6e\n',relative_error);
    fprintf('  Tx normalization weight max abs difference: %.6e\n',txw_diff);
    fprintf('  Max Tx-weight difference at x=%.4f mm,z=%.4f mm; universal %.9g vs baseline %.9g\n', ...
        a.x_axis_m(jxw)*1e3,a.z_axis_m(izw)*1e3, ...
        a.tx_weight_sum(izw,jxw),b.tx_weight_sum(izw,jxw));
    fprintf('  Tx weights at worst complex residual: universal %.9g vs baseline %.9g\n', ...
        a.tx_weight_sum(iz,ix),b.tx_weight_sum(iz,ix));
    fprintf('  Max per-Tx vs channel Rx sound-speed diff: %.9g m/s\n', ...
        acq.audit.max_tx_rx_sound_speed_diff_m_s);
    fprintf('  Maximum complex residual: |delta|=%.6e at x=%.4f mm, z=%.4f mm\n', ...
        max_diff,a.x_axis_m(ix)*1e3,a.z_axis_m(iz)*1e3);
    fprintf('  Data-supported Tx-weight fraction at that pixel: %.6f\n', ...
        a.valid_rx_tx_fraction(iz,ix));
    fprintf('  Global missing-Rx Tx-weight fraction: %.6e\n', ...
        a.diagnostics.missing_rx_tx_weight_fraction);
    assert(txw_diff<=1e-10*max(1,max(b.tx_weight_sum(:))), ...
        'Tx apodization/weight accumulation differs from Chapter 1.');
    assert(relative_error<1e-10, ...
        ['Unified RTB DAS does not match independently verified ' ...
         'Chapter-1 geometry. Do not compare method images yet.']);
    fprintf('PASS: complex RTB DAS baseline is consistent with Chapter 1.\n');
end
