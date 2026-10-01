function test_rtb_tx_timing(filename)
%TEST_RTB_TX_TIMING Synthetic point target with known per-Tx RF time shifts.
% Requires USTB classes. filename only satisfies the core's file existence
% check; all signal/metadata are supplied in memory, no real UFF is read.
    if nargin < 1
        filename = '../../data/L7_FI_Verasonics_CIRS_points.uff';
    end
    probe = uff.linear_array('N',3,'pitch',0.298e-3, ...
        'element_width',0.25e-3,'element_height',3e-3);
    fs = 20.833333e6; c = 1540; f0 = 5e6; z0 = 20e-3;
    time = (0:1919).'/fs;
    injected = [0;40e-9;80e-9];
    nominal = zeros(1920,3,3,'single'); shifted = nominal;
    w(1,3) = uff.wave();
    for iw = 1:3
        w(iw) = uff.wave();
        w(iw).source = uff.point('x',double(probe.x(iw)),'z',30e-3);
        w(iw).origin = uff.point('x',double(probe.x(iw)),'z',0);
        w(iw).sound_speed = c;
        tx = (double(w(iw).source.distance) ...
            - hypot(double(w(iw).source.x),z0-double(w(iw).source.z)))/c;
        for ch = 1:3
            arrival = tx+hypot(double(probe.x(ch)),z0)/c;
            q = time-arrival;
            nominal(:,ch,iw) = single(exp(-(q/0.3e-6).^2).*cos(2*pi*f0*q));
            q = q-injected(iw);
            shifted(:,ch,iw) = single(exp(-(q/0.3e-6).^2).*cos(2*pi*f0*q));
        end
    end
    cd = uff.channel_data('probe',probe,'sequence',w,'data',nominal, ...
        'sampling_frequency',fs,'initial_time',0,'sound_speed',c, ...
        'modulation_frequency',0);
    r = struct('n_z',3,'n_x',3,'z_min',z0-20e-6,'z_max',z0+20e-6, ...
        'tx_delay_model','spherical','rx_aperture_mode','full');
    expected = reconstruct_fi_rtb_manual(filename,r,cd);
    cd.data = shifted;
    bad = reconstruct_fi_rtb_manual(filename,r,cd);
    r.tx_time_offsets = injected;
    fixed = reconstruct_fi_rtb_manual(filename,r,cd);
    assert(fixed.envelope(2,2) > 1.4*bad.envelope(2,2), ...
        'RF timing correction did not recover coherent point-target amplitude.');
    assert(abs(fixed.envelope(2,2)/expected.envelope(2,2)-1) < 0.06, ...
        'Corrected target differs excessively from the unshifted reference.');
    assert(fixed.tx_coherence(2,2) > bad.tx_coherence(2,2)+0.25, ...
        'Tx coherence did not recover after the known timing correction.');
    c_opts = struct('n_z',3,'z_min',z0-20e-6,'z_max',z0+20e-6, ...
        'tx_time_offsets',injected);
    scan = reconstruct_fi_scanline_manual(filename,c_opts,cd);
    assert(isequal(scan.tx_time_offsets,injected), ...
        'Conventional FI did not preserve the shared timing offsets.');
    r.tx_time_offsets = [0 NaN 0];
    caught = false;
    try
        reconstruct_fi_rtb_manual(filename,r,cd);
    catch e
        caught = contains(e.message,'tx_time_offsets');
    end
    assert(caught,'Nonfinite Tx offsets were not rejected.');
    fprintf('SYNTHETIC_TIMING_TEST_PASS: known RF shifts recovered; invalid offsets rejected.\n');
end
