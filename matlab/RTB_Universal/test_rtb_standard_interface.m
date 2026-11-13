function test_rtb_standard_interface()
%TEST_RTB_STANDARD_INTERFACE Deterministic, UFF-free integration tests.
%
% Generates a focused-Tx linear-array RF echo from one synthetic point.
% Checks vendor tensor axis permutation, unit conversion, cable/channel
% reversal, RF and demodulated IQ paths, method outputs, CF=GCF(M0=0),
% NSI envelope inequality, and rejection of unsafe metadata.
%
% Run from matlab/RTB_Universal:
%   test_rtb_standard_interface
%
% NOT a validation of realistic tissue physics or paper equivalence.

    c=1540;
    fs=40e6;
    f0=5e6;
    ns=1600;
    ne=12;
    nw=3;

    ex=(-5.5:5.5)'*0.30e-3;
    ftx=(-1:1)'*0.30e-3;
    focus=[ftx,zeros(nw,1),ones(nw,1)*0.020];
    origin=[ftx,zeros(nw,2)];
    point=[0,0.022];

    t=(0:ns-1)'/fs;
    raw=zeros(ns,ne,nw);
    for iw=1:nw
        tx_path=0.020+sqrt((point(1)-ftx(iw))^2+ ...
            (point(2)-focus(iw,3))^2);
        for ch=1:ne
            rx_path=sqrt((point(1)-ex(ch))^2+point(2)^2);
            arrival=(tx_path+rx_path)/c;
            base=(t-arrival);
            raw(:,ch,iw)=exp(-0.5*(base/(0.30e-6)).^2).* ...
                cos(2*pi*f0*base);
        end
    end

    % Vendor export: [CHANNEL, SAMPLE, TX], with reversed physical cables.
    vendor=permute(raw(:,end:-1:1,:),[2,1,3]);

    meta=struct();
    meta.data_order='channel,sample,tx';
    meta.units=struct('length','mm','time','us','frequency','MHz');
    meta.sampling_frequency=40;
    meta.initial_time=0;
    meta.sound_speed_m_s=c;
    meta.nominal_frequency=5;
    meta.element_xyz=[ex*1e3,zeros(ne,2)];
    meta.channel_to_element=(ne:-1:1).';
    meta.focus_xyz=focus*1e3;
    meta.origin_xyz=origin*1e3;
    meta.tx_reference_distance=20*ones(nw,1);
    meta.tx_delay=zeros(nw,1);
    meta.tx_phase_correction_rad=zeros(nw,1);
    meta.tx_delay_convention='subtract';
    meta.time_reference='two_way';
    meta.tx_wavefront='focused_spherical';
    meta.data_stage='pre_beamform_channel';
    meta.signal_type='RF';

    acq=rtb_from_vendor_array(vendor,meta);
    validated=rtb_load_acquisition(acq);

    assert(isequal(size(validated.data),[ns,ne,nw,1]) || ...
           isequal(size(validated.data),[ns,ne,nw]), ...
        'Canonical data tensor shape mismatch.');
    assert(max(abs(validated.element_x_m(:)-ex))<1e-12, ...
        'Physical element x positions were not correctly ordered.');
    assert(max(abs(double(validated.data(:,:,1))-raw(:,:,1)),[], ...
        'all')<1e-12, ...
        'Reversed cable channels were not correctly remapped.');
    assert(abs(validated.fs_hz-fs)<1e-6 && ...
           abs(validated.focus_xyz_m(2,3)-0.020)<1e-12, ...
        'Vendor unit conversion was incorrect.');

    cfg=struct();
    cfg.methods={'DAS','CF','GCF','MVDR','FDMAS','SLSC','NSI'};
    cfg.x_range_m=[-0.45,0.45]*1e-3;
    cfg.z_range_m=[21.5,22.5]*1e-3;
    cfg.n_x=13;
    cfg.n_z=71;
    cfg.wave_stride=1;
    cfg.mvdr_axial_lambda=0.8;
    cfg.slsc_axial_lambda=1.0;
    cfg.nsi_dc=0.8;
    cfg.verbose=false;

    output=rtb_reconstruct_all(acq,cfg);
    assert(numel(output.methods)==7,'Not all RF methods were produced.');
    methods=output.methods;
    for k=1:numel(methods)
        image=output.images.(methods{k});
        assert(isequal(size(image),[cfg.n_z,cfg.n_x]) && ...
               all(isfinite(image(:))), ...
            'Invalid method image %s.',methods{k});
    end
    assert(output.diagnostics.mvdr_attempts>0, ...
        'MVDR branch was not executed.');

    das=output.images.DAS;
    nsi=output.images.NSI;
    assert(all(nsi(:)>=-1e-10) && ...
           all(nsi(:)<=das(:)+1e-9), ...
        'NSI scaled envelope not bounded by DAS.');
    [~,maxid]=max(das(:));
    [zi,xi]=ind2sub(size(das),maxid);
    assert(abs(output.x_axis_m(xi)-point(1))<0.20e-3 && ...
           abs(output.z_axis_m(zi)-point(2))<0.20e-3, ...
        'Point target is not at its expected physical coordinates.');

    % GCF M0=0 MUST equal CF using the same delayed receive vectors.
    cfg.methods={'DAS','CF','GCF'};
    cfg.gcf_M0=0;
    out0=rtb_reconstruct_all(acq,cfg);
    rel=max(abs(out0.images.CF(:)-out0.images.GCF(:)))/ ...
        (max(out0.images.DAS(:))+eps);
    assert(rel<1e-10, ...
        'GCF M0=0 does not reproduce CF on the same RTB samples.');

    % Construct a baseband IQ representation with EXPLICIT demodulation
    % convention. IQ interpolation is not sample-for-sample identical to
    % interpolated analytic RF at a finite carrier sampling rate.
    H=zeros(ns,1);
    H(1)=1; H(ns/2+1)=1; H(2:ns/2)=2;
    IQ=complex(zeros(size(raw)));
    demod=exp(-1i*2*pi*f0*t);
    for iw=1:nw
        analytic=ifft(fft(raw(:,:,iw),[],1).*H,[],1);
        IQ(:,:,iw)=analytic.*demod;
    end
    vendor_iq=permute(IQ(:,end:-1:1,:),[2,1,3]);
    iq_meta=meta;
    iq_meta.signal_type='IQ';
    iq_meta.iq_demodulation_frequency=5;
    iq_meta.iq_reference_time=0;
    iq_meta.iq_phase_convention= ...
        'iq_equals_analytic_times_exp_minus_j2pift';
    iq_acq=rtb_from_vendor_array(vendor_iq,iq_meta);
    cfg.methods={'DAS','CF','GCF','MVDR','NSI'};
    cfg.gcf_M0=1;
    iq_out=rtb_reconstruct_all(iq_acq,cfg);
    assert(numel(iq_out.methods)==5 && ...
           all(isfinite(iq_out.images.DAS(:))), ...
        'IQ analytic reconstruction returned invalid data.');

    % IQ input with ALL methods is not supported without REAL RF.
    cfg.methods={'DAS','FDMAS','SLSC'};
    cfg.unsupported_policy='error';
    caught=false;
    try
        rtb_reconstruct_all(iq_acq,cfg);
    catch err
        caught=contains(err.message,'IQ input lacks real RF');
    end
    assert(caught,'IQ must reject RF-only methods, not invent them.');

    cfg.unsupported_policy='skip';
    iq_skip=rtb_reconstruct_all(iq_acq,cfg);
    assert(isequal(sort(iq_skip.skipped),sort({'FDMAS';'SLSC'})) && ...
           isequal(iq_skip.methods,{'DAS'}), ...
        'Unsupported IQ method skipping was not correctly reported.');

    % Required timing metadata MUST NOT be guessed.
    bad=rmfield(meta,'tx_delay');
    caught=false;
    try
        rtb_from_vendor_array(vendor,bad);
    catch err
        caught=contains(err.message,'tx_delay');
    end
    assert(caught,'Missing Tx-delay timing must raise an error.');

    % Do NOT let a vendor plane-wave acquisition masquerade as RTB FI.
    bad=meta;
    bad.tx_wavefront='plane';
    caught=false;
    try
        bad_acq=rtb_from_vendor_array(vendor,bad);
        rtb_load_acquisition(bad_acq);
    catch err
        caught=contains(err.message,'Only focused spherical Tx');
    end
    assert(caught,'Non-focused transmit data must be rejected.');

    % Unit typo mm -> m would produce 300-mm array pitch, not 0.3 mm.
    bad=meta;
    bad.units.length='m';
    caught=false;
    try
        bad_acq=rtb_from_vendor_array(vendor,bad);
        rtb_load_acquisition(bad_acq);
    catch err
        caught=contains(err.message,'Receive pitch');
    end
    assert(caught,'Physically implausible unit mapping must be rejected.');

    fprintf('PASS: vendor axis/units/channel order, RF/IQ, all methods.\n');
    fprintf('PASS: CF=GCF(M0=0), NSI envelope bound, point target location.\n');
    fprintf('PASS: reject IQ-only mismatch, missing timing, plane Tx, wrong units.\n');
    fprintf('NOTE: independent UFF/Chapter-1 RTB regression is separate.\n');
end
