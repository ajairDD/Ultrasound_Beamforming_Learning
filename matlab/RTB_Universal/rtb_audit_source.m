function audit = rtb_audit_source(source)
%RTB_AUDIT_SOURCE Preflight for UFF / canonical multi-vendor channel data.
%
%   audit=rtb_audit_source('my_data.uff');
%   audit=rtb_audit_source(acq);
%
% Performs strict metadata/unit/channel ordering validation (via loader).
% Additionally checks whether expected two-way echo times at EACH Tx
% focus and nearest receive element fall inside the recorded sample span.
%
% A focus outside the recorded time window is a WARNING, NOT proof of bad
% metadata: some acquisitions intentionally record shallower/deeper ROIs.
% A full array/sequence phase calibration is not derivable from metadata.

    acq=rtb_load_acquisition(source);
    nw=acq.audit.n_tx;
    ns=acq.audit.n_samples;
    c=acq.c_m_s;
    times=zeros(nw,1);
    in_recording=false(nw,1);
    rx_index=zeros(nw,1);

    for w=1:nw
        focus=acq.focus_xyz_m(w,:);
        [~,ir]=min(abs(acq.element_x_m-focus(1)));
        rx_index(w)=ir;
        tx_time=acq.tx_reference_distance_m(w)/c-acq.tx_delay_s(w);
        rx_time=sqrt((focus(1)-acq.element_x_m(ir))^2+ ...
            focus(3)^2)/c;
        times(w)=tx_time+rx_time;

        begin=acq.t0_s(w);
        finish=begin+(ns-1)/acq.fs_hz;
        in_recording(w)=times(w)>=begin && times(w)<=finish;
    end

    audit=acq.audit;
    audit.source=acq.adapter_source;
    audit.signal_type=acq.signal_type;
    audit.fs_hz=acq.fs_hz;
    audit.f0_hz=acq.f0_hz;
    audit.sound_speed_m_s=c;
    audit.focus_rx_nearest_channel=rx_index;
    audit.predicted_focus_echo_time_s=times;
    audit.focus_time_in_recording=in_recording;
    audit.focus_time_coverage_fraction=nnz(in_recording)/nw;

    fprintf('\n=== UNIVERSAL RTB ACQUISITION PREFLIGHT ===\n');
    fprintf('Source          : %s\n',audit.source);
    fprintf('Signal          : %s\n',audit.signal_type);
    fprintf('Data shape      : [%d,%d,%d,%d] sample/Rx/Tx/frame\n', ...
        audit.shape_sample_rx_tx_frame);
    fprintf('fs / f0         : %.4f / %.4f MHz\n', ...
        audit.fs_hz/1e6,audit.f0_hz/1e6);
    fprintf('Rx pitch        : %.5f mm\n',audit.element_pitch_m*1e3);
    fprintf('Channel reordered: %d\n',audit.channel_reorder_changed);
    fprintf('t0 range        : %.4f .. %.4f us\n', ...
        audit.t0_range_s*1e6);
    fprintf('Focus depth     : %.3f .. %.3f mm\n', ...
        audit.focus_depth_range_m*1e3);
    fprintf('Predicted focus times in recorded data: %d / %d (%.1f%%)\n', ...
        nnz(in_recording),nw,100*audit.focus_time_coverage_fraction);

    if audit.focus_time_coverage_fraction<0.8
        warning('RTB:FocusTimeCoverage', ...
            ['More than 20%% of focused Tx centers are outside recorded ' ...
             'sample windows. Check t0, fs, Tx reference distance, ' ...
             'Tx delay, and acquisition depth before reconstruction.']);
    end
    fprintf('Preflight is a metadata/time coverage check, NOT image validation.\n');
end
