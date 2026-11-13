function acq = rtb_from_vendor_array(raw,meta)
%RTB_FROM_VENDOR_ARRAY Explicit vendor -> canonical RTB acquisition adapter.
%
% This does NOT decode a proprietary file. It maps a vendor's ALREADY
% EXTRACTED raw numeric tensor and verified metadata into SI conventions.
%
% REQUIRED metadata (all metadata units explicitly declared):
%   data_order = 'sample,channel,tx[,frame]' (any permutation)
%   units.length = 'm'/'mm'/'um'; units.time = 's'/'ms'/'us'/'ns'
%   units.frequency = 'Hz'/'kHz'/'MHz'
%   sampling_frequency                  raw sample clock in units.frequency
%   initial_time                        first-sample timestamp (scalar or W)
%   sound_speed_m_s
%   nominal_frequency                   nominal transmit frequency
%   element_xyz                         [Ne,3], units.length
%   channel_to_element                   [Nc,1], 1-based geometry indices
%   focus_xyz                           [W,3], units.length
%   origin_xyz                          [W,3], units.length, Tx beam axis
%   tx_reference_distance               [W,1], units.length
%   tx_delay                            [W,1], units.time
%   tx_phase_correction_rad             [W,1]; explicit 0 if confirmed
%   tx_delay_convention = 'subtract'     tau_tx=path/c - tx_delay
%   time_reference = 'two_way'           sample timestamp for Tx+Rx path
%   signal_type = 'RF' or 'IQ'
%
% REQUIRED FOR IQ:
%   iq_demodulation_frequency           units.frequency, can be signed
%   iq_reference_time                    units.time
%   iq_phase_convention='iq_equals_analytic_times_exp_minus_j2pift'
%     -> analytic_RF(t) = IQ(t)*exp(+1i*2*pi*f_demod*(t-t_reference))
%
% This is intentional: A wrong sample-t0, pulse delay, channel order, or
% IQ phase convention can produce plausible-looking but WRONG images.
% In particular IQ already log-compressed / beamformed input is invalid.
%
% OUTPUT acq.data [sample, physical_receive_channel, focused_Tx, frame].
%
% Example (replace ALL values using verified machine documentation):
%   meta.data_order='channel,sample,tx'; ...
%   acq=rtb_from_vendor_array(vendor_tensor,meta);
%   out=rtb_reconstruct_all(acq,cfg);

    assert(isnumeric(raw) && ~issparse(raw) && ~isempty(raw), ...
        'raw must be a nonempty numeric channel-data tensor.');
    assert(isstruct(meta) && isscalar(meta), ...
        'meta must be a scalar metadata struct.');

    required={'data_order','units','sampling_frequency', ...
        'initial_time','sound_speed_m_s','nominal_frequency', ...
        'element_xyz','channel_to_element','focus_xyz', ...
        'origin_xyz','tx_reference_distance','tx_delay', ...
        'tx_phase_correction_rad', ...
        'tx_delay_convention','time_reference','signal_type'};
    for k=1:numel(required)
        assert(isfield(meta,required{k}), ...
            'Missing REQUIRED vendor metadata: %s',required{k});
    end

    assert(strcmpi(char(meta.tx_delay_convention),'subtract'), ...
        ['Only confirmed tau_tx = path/c - tx_delay is supported. ' ...
         'Convert machine-specific timing in the adapter FIRST.']);
    assert(strcmpi(char(meta.time_reference),'two_way'), ...
        'Input timestamps must refer to the complete Tx+Rx travel time.');

    u=meta.units;
    assert(isstruct(u) && all(isfield(u,{'length','time','frequency'})), ...
        'meta.units must define length, time and frequency.');
    ls=unit_scale(u.length,'length');
    ts=unit_scale(u.time,'time');
    fsu=unit_scale(u.frequency,'frequency');

    names=strsplit(lower(strrep(char(meta.data_order),' ','')),',');
    target={'sample','channel','tx','frame'};
    assert(numel(names)==3 || numel(names)==4, ...
        'data_order must explicitly name 3 or 4 array axes.');
    for k=1:numel(names)
        names{k}=canonical_axis(names{k});
    end
    assert(numel(unique(names))==numel(names), ...
        'Duplicate data_order axis.');
    assert(all(ismember({'sample','channel','tx'},names)), ...
        'data_order must name sample, channel and tx.');
    if numel(names)==3
        names{4}='frame';
    end
    dims=size(raw);
    dims(end+1:4)=1;
    assert(ndims(raw)<=4,'Only 3-D or 4-D channel arrays supported.');
    assert(numel(names)==4,'Invalid data axes.');
    p=zeros(1,4);
    for k=1:4
        idx=find(strcmp(names,target{k}));
        assert(isscalar(idx),'data_order must contain %s once.',target{k});
        p(k)=idx;
    end
    reshaped=reshape(raw,dims);
    canonical=permute(reshaped,p);

    w=size(canonical,3);
    nc=size(canonical,2);
    assert(w>=1 && nc>=2 && size(canonical,1)>=3, ...
        'Need at least 3 samples, 2 receive channels and 1 focused Tx.');

    % All coordinates are [x,y,z]. Convert ALL explicit vendor units to SI.
    elements=double(meta.element_xyz)*ls;
    focus=double(meta.focus_xyz)*ls;
    origin=double(meta.origin_xyz)*ls;
    reference=double(meta.tx_reference_distance(:))*ls;
    delay=double(meta.tx_delay(:))*ts;
    t0=double(meta.initial_time(:))*ts;

    if numel(t0)==1
        t0=repmat(t0,w,1);
    end
    assert(numel(t0)==w,'initial_time must be scalar or one per Tx.');
    assert(isequal(size(focus),[w,3]),'focus_xyz must be [Ntx,3].');
    assert(isequal(size(origin),[w,3]),'origin_xyz must be [Ntx,3].');
    assert(numel(reference)==w && numel(delay)==w, ...
        'tx_reference_distance and tx_delay must have one value per Tx.');

    acq=struct();
    acq.data=canonical;
    acq.signal_type=upper(char(meta.signal_type));
    acq.fs_hz=double(meta.sampling_frequency)*fsu;
    acq.t0_s=t0;
    acq.c_m_s=double(meta.sound_speed_m_s);
    acq.f0_hz=double(meta.nominal_frequency)*fsu;

    acq.element_xyz_m=elements;
    acq.channel_to_element=double(meta.channel_to_element(:));
    acq.focus_xyz_m=focus;
    acq.origin_xyz_m=origin;
    acq.tx_reference_distance_m=reference;
    acq.tx_delay_s=delay;
    acq.tx_phase_correction_rad=double(meta.tx_phase_correction_rad(:));
    assert(numel(acq.tx_phase_correction_rad)==w && ...
           all(isfinite(acq.tx_phase_correction_rad)), ...
        'tx_phase_correction_rad requires one finite value per Tx.');
    acq.tx_delay_convention='subtract';
    acq.time_reference='two_way';

    if strcmp(acq.signal_type,'IQ')
        need={'iq_demodulation_frequency','iq_reference_time', ...
            'iq_phase_convention'};
        for k=1:numel(need)
            assert(isfield(meta,need{k}), ...
                'IQ input requires %s',need{k});
        end
        assert(strcmpi(char(meta.iq_phase_convention), ...
          'iq_equals_analytic_times_exp_minus_j2pift'), ...
            'Unsupported IQ phase convention: map it explicitly first.');
        acq.demod_hz=double(meta.iq_demodulation_frequency)*fsu;
        acq.iq_reference_time_s=double(meta.iq_reference_time)*ts;
        acq.iq_phase_convention='iq_equals_analytic_times_exp_minus_j2pift';
    else
        acq.demod_hz=0;
        acq.iq_reference_time_s=0;
    end

    % Return a canonical, SI-unit struct. The central reconstruction
    % entrypoint validates and reorders it exactly ONCE. Do not reorder
    % the channel dimension in multiple adapters independently.
    acq.adapter_source='vendor-array-with-explicit-metadata';
end

function s=canonical_axis(s)
    switch s
        case {'sample','samples','time'},s='sample';
        case {'channel','channels','rx'},s='channel';
        case {'tx','transmit','transmits','wave','waves'},s='tx';
        case {'frame','frames'},s='frame';
        otherwise,error('Unknown data axis: %s',s);
    end
end

function v=unit_scale(u,kind)
    token=lower(strtrim(char(u)));
    switch kind
        case 'length'
            switch token
                case 'm',v=1;
                case 'mm',v=1e-3;
                case {'um','µm'},v=1e-6;
                otherwise,error('Unsupported length unit: %s',token);
            end
        case 'time'
            switch token
                case 's',v=1;
                case 'ms',v=1e-3;
                case {'us','µs'},v=1e-6;
                case 'ns',v=1e-9;
                otherwise,error('Unsupported time unit: %s',token);
            end
        case 'frequency'
            switch token
                case 'hz',v=1;
                case 'khz',v=1e3;
                case 'mhz',v=1e6;
                otherwise,error('Unsupported frequency unit: %s',token);
            end
    end
end
