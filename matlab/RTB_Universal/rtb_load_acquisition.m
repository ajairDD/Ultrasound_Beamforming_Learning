function acq = rtb_load_acquisition(source)
%RTB_LOAD_ACQUISITION Read / validate focused-FI input from UFF or struct.
%
%   acq=rtb_load_acquisition('my_acquisition.uff');
%   acq=rtb_load_acquisition('canonical_acq.mat'); % variable 'acq'
%   acq=rtb_load_acquisition(acq_struct);
%
% For arbitrary raw-array axes/units, first use rtb_from_vendor_array.
% All output values are SI and channels are ordered by physical x position.
%
% Required canonical fields (NO inferred unit conversions):
% data [sample,channel,Tx,frame]
% signal_type 'RF' / 'IQ'
% fs_hz, t0_s [Tx,1] or scalar, c_m_s, f0_hz
% element_xyz_m [N_elem,3], channel_to_element [N_channel,1]
% focus_xyz_m [Ntx,3], origin_xyz_m [Ntx,3]
% tx_reference_distance_m [Ntx,1], tx_delay_s [Ntx,1]
% tx_phase_correction_rad [Ntx,1], multiply analytic by exp(+1i*phase)
% tx_delay_convention 'subtract', time_reference 'two_way'
% IQ only: demod_hz, iq_reference_time_s, and COMPLEX input
%
% UFF IQ is NOT automatically accepted because IQ reference-phase
% conventions can vary by acquisition/export software. Use a documented
% explicit vendor adapter to declare the phase convention.

    if ischar(source) || (isstring(source) && isscalar(source))
        filename=char(source);
        assert(exist(filename,'file')==2, ...
            'Acquisition file does not exist: %s',filename);
        [~,~,ext]=fileparts(filename);
        switch lower(ext)
            case '.mat'
                loaded=load(filename,'acq');
                assert(isfield(loaded,'acq') && isstruct(loaded.acq), ...
                    'MAT file must contain canonical struct variable acq.');
                acq=loaded.acq;
            case '.uff'
                assert(~isempty(which('uff.read_object')), ...
                    'USTB not found; add USTB to MATLAB path for UFF input.');
                cd=uff.read_object(filename,'/channel_data');
                assert(isreal(cd.data) && abs(cd.modulation_frequency)<1, ...
                    ['UFF IQ or demodulated data is not assumed phase-' ...
                     'compatible. Supply an explicit canonical IQ adapter.']);
                acq=struct();
                acq.data=cd.data;
                acq.signal_type='RF';
                acq.fs_hz=double(cd.sampling_frequency);
                acq.t0_s=double(cd.initial_time);
                acq.c_m_s=double(cd.sound_speed);
                acq.f0_hz=double(cd.sound_speed/cd.lambda);

                acq.element_xyz_m=[double(cd.probe.x(:)), ...
                    double(cd.probe.y(:)),double(cd.probe.z(:))];
                acq.channel_to_element=(1:cd.N_channels).';

                nw=cd.N_waves;
                focus=zeros(nw,3);
                origin=zeros(nw,3);
                ref=zeros(nw,1);
                delay=zeros(nw,1);
                for iw=1:nw
                    wave=cd.sequence(iw);
                    assert(wave.wavefront==uff.wavefront.spherical, ...
                        'UFF wave %d is not a focused spherical Tx.',iw);
                    focus(iw,:)=double(wave.source.xyz(:).');
                    origin(iw,:)=double(wave.origin.xyz(:).');
                    ref(iw)=double(wave.source.distance);
                    delay(iw)=double(wave.delay);
                    assert(abs(wave.sound_speed-acq.c_m_s)<1e-4, ...
                        'UFF Tx %d sound speed differs from channel data.',iw);
                    if all(abs(origin(iw,:))<eps) && ...
                            any(abs(focus(iw,:))>eps)
                        % The USTB focused-FI origin fallback used by
                        % Chapter-1 RTB: beam-axis point on z=0 plane.
                        origin(iw,:)=[focus(iw,1) 0 0];
                    end
                end
                acq.focus_xyz_m=focus;
                acq.origin_xyz_m=origin;
                acq.tx_reference_distance_m=ref;
                acq.tx_delay_s=delay;
                % The Chapter-1 UFF focused-FI reference assumes a
                % common coherent transmit phase; see project docs.
                acq.tx_phase_correction_rad=zeros(nw,1);
                acq.tx_delay_convention='subtract';
                acq.time_reference='two_way';
                acq.demod_hz=0;
                acq.iq_reference_time_s=0;
                acq.adapter_source=['UFF: ' filename];
            otherwise
                error(['Unsupported file format %s. Load vendor data ' ...
                    'using vendor-specific tools then map it with ' ...
                    'rtb_from_vendor_array, or save a canonical MAT.'],ext);
        end
    elseif isstruct(source) && isscalar(source)
        acq=source;
        if ~isfield(acq,'adapter_source')
            acq.adapter_source='direct canonical struct';
        end
    else
        error('source must be an UFF path, canonical MAT path, or struct.');
    end

    required={'data','signal_type','fs_hz','t0_s','c_m_s','f0_hz', ...
        'element_xyz_m','channel_to_element','focus_xyz_m', ...
        'origin_xyz_m','tx_reference_distance_m','tx_delay_s', ...
        'tx_phase_correction_rad', ...
        'tx_delay_convention','time_reference'};
    for k=1:numel(required)
        assert(isfield(acq,required{k}), ...
            'Canonical acquisition is missing %s.',required{k});
    end

    assert(isnumeric(acq.data) && ~isempty(acq.data) && ...
           ~issparse(acq.data) && ndims(acq.data)<=4, ...
        'data must be numeric [sample,channel,tx,frame], at most 4-D.');
    shape=size(acq.data);
    shape(end+1:4)=1;
    acq.data=reshape(acq.data,shape);
    ns=shape(1); nc=shape(2); nw=shape(3);
    assert(ns>=3 && nc>=2 && nw>=1, ...
        'Need >=3 samples, >=2 Rx channels, >=1 focused Tx.');

    assert(isnumeric(acq.fs_hz) && isscalar(acq.fs_hz) && ...
           isfinite(acq.fs_hz) && acq.fs_hz>0, ...
        'fs_hz must be positive in Hz.');
    assert(isnumeric(acq.c_m_s) && isscalar(acq.c_m_s) && ...
           isfinite(acq.c_m_s) && ...
           acq.c_m_s>=1000 && acq.c_m_s<=2000, ...
        'c_m_s must be a plausible ultrasound propagation speed in m/s.');
    assert(isnumeric(acq.f0_hz) && isscalar(acq.f0_hz) && ...
           isfinite(acq.f0_hz) && ...
           acq.f0_hz>1e5 && acq.f0_hz<1e8, ...
        'f0_hz must be in Hz (not MHz).');
    assert(all(isfinite(acq.data(:))), ...
        'Channel data contains NaN or Inf.');

    acq.signal_type=upper(char(acq.signal_type));
    assert(ismember(acq.signal_type,{'RF','IQ'}), ...
        'signal_type must be RF or IQ.');
    if strcmp(acq.signal_type,'RF')
        assert(isreal(acq.data),'RF data must be real.');
        acq.demod_hz=0;
        acq.iq_reference_time_s=0;
        assert(acq.fs_hz>2*acq.f0_hz, ...
            'RF sample rate too low for nominal carrier (fs<=2*f0).');
    else
        assert(~isreal(acq.data),'IQ input must be complex.');
        assert(isfield(acq,'demod_hz') && ...
               isfield(acq,'iq_reference_time_s'), ...
            'IQ needs explicit demod_hz and iq_reference_time_s.');
        assert(isscalar(acq.demod_hz) && ...
               isfinite(acq.demod_hz) && ...
               isscalar(acq.iq_reference_time_s) && ...
               isfinite(acq.iq_reference_time_s), ...
            'Invalid IQ demodulation phase reference.');
        % Sign convention is already guaranteed by
        % rtb_from_vendor_array; direct canonical structs MUST affirm it.
        assert(isfield(acq,'iq_phase_convention') && ...
               strcmp(char(acq.iq_phase_convention), ...
                   'iq_equals_analytic_times_exp_minus_j2pift'), ...
            'Direct IQ struct must affirm its IQ phase convention.');
    end

    assert(strcmp(char(acq.tx_delay_convention),'subtract') && ...
           strcmp(char(acq.time_reference),'two_way'), ...
        'Unsupported Tx delay sign or sample-time reference.');

    t0=double(acq.t0_s(:));
    if numel(t0)==1,t0=repmat(t0,nw,1);end
    assert(numel(t0)==nw && all(isfinite(t0)), ...
        't0_s must be scalar or one timestamp per Tx (s).');
    acq.t0_s=t0;

    elem=double(acq.element_xyz_m);
    map=double(acq.channel_to_element(:));
    assert(size(elem,2)==3 && size(elem,1)>=nc && ...
           all(isfinite(elem(:))), ...
        'element_xyz_m must be finite [N_elements,3] in meters.');
    ne=size(elem,1);
    assert(numel(map)==nc && all(isfinite(map)) && ...
           all(map>=1 & map<=ne & map==round(map)) && ...
           numel(unique(map))==nc, ...
        'channel_to_element must map each data channel uniquely to an element.');
    assert(all(abs(elem(:,2))<1e-6) && ...
           all(abs(elem(:,3))<1e-6), ...
        ['Only 2D, linear, z=0 receive arrays are supported. ' ...
         'Transform machine coordinates to array-centered SI frame.']);

    [~,geometry_sort]=sort(elem(:,1));
    [~,element_rank]=sort(geometry_sort);
    physical_ids=element_rank(map);
    [sorted_ids,order]=sort(physical_ids);
    assert(all(diff(sorted_ids)==1), ...
        ['Missing physical receive elements inside acquisition channel ' ...
         'set; contiguous physical lags cannot be inferred.']);
    x=elem(map(order),1);
    pitch=diff(x);
    assert(all(pitch>0) && median(pitch)>5e-6 && ...
           median(pitch)<2e-3 && ...
           max(abs(pitch-median(pitch)))<max(1e-9, ...
                                              1e-3*median(pitch)), ...
        ['Receive pitch is not uniform/physically plausible. ' ...
         'Check coordinates in meters and channel-element mapping.']);

    % Order data by physical x. Do NOT permute channel axis without
    % applying precisely the same permutation to element coordinates.
    acq.data=acq.data(:,order,:,:);
    acq.element_x_m=x(:).';
    acq.channel_to_element=map(order);
    acq.channel_order_permutation=order(:);
    acq.original_element_xyz_m=elem;

    fx=double(acq.focus_xyz_m);
    ox=double(acq.origin_xyz_m);
    rr=double(acq.tx_reference_distance_m(:));
    dd=double(acq.tx_delay_s(:));
    ph=double(acq.tx_phase_correction_rad(:));
    assert(numel(ph)==nw && all(isfinite(ph)), ...
        'tx_phase_correction_rad must be one finite correction per Tx.');
    assert(isequal(size(fx),[nw,3]) && ...
           isequal(size(ox),[nw,3]) && ...
           all(isfinite(fx(:))) && all(isfinite(ox(:))), ...
        'focus_xyz_m and origin_xyz_m must each be [Ntx,3] in meters.');
    assert(all(fx(:,3)>0) && all(abs(fx(:,2))<1e-6) && ...
           all(abs(ox(:,2))<1e-6) && all(abs(ox(:,3))<1e-6), ...
        'Focused Tx must be in x-z plane, positive z, origin on z=0.');
    assert(numel(rr)==nw && all(rr>0) && all(isfinite(rr)) && ...
           numel(dd)==nw && all(isfinite(dd)), ...
        'Invalid Tx reference distance [m] or delay [s].');
    assert(all(vecnorm(fx(:,[1 3])-ox(:,[1 3]),2,2)>eps), ...
        'A Tx focus cannot coincide with its beam origin.');

    acq.focus_xyz_m=fx;
    acq.origin_xyz_m=ox;
    acq.tx_reference_distance_m=rr;
    acq.tx_delay_s=dd;
    acq.tx_phase_correction_rad=ph;

    % Quality summary that can be inspected across machine exports.
    acq.audit=struct( ...
        'shape_sample_rx_tx_frame',size(acq.data), ...
        'n_samples',ns,'n_channels',nc, ...
        'n_tx',nw,'n_frames',shape(4), ...
        'element_pitch_m',median(pitch), ...
        'channel_reorder_changed',any(order(:)~=(1:nc).'), ...
        't0_range_s',[min(t0),max(t0)], ...
        'focus_depth_range_m',[min(fx(:,3)),max(fx(:,3))], ...
        'is_RF',strcmp(acq.signal_type,'RF'));
end
