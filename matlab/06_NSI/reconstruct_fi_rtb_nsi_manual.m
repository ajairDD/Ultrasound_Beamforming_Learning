function out = reconstruct_fi_rtb_nsi_manual(filename,opts)
%RECONSTRUCT_FI_RTB_NSI_MANUAL RTB-DAS versus receive Null Subtraction Imaging.
%
% The ONE change relative to Chapter-1 RTB-DAS is receive apodization.
% For each Tx/pixel, from the same delayed analytic Rx samples:
%
%     D = sum(s)
%     Z = sum(w_ZM .* s),  sum(w_ZM) = 0
%
% We then coherently compound each branch over Tx with IDENTICAL Tx weights
% and identical normalization. Three complex receive-apodization beams are:
%
%     W_ZM  = Z
%     W_DC1 = Z + dc*D
%     W_DC2 = -Z + dc*D
%
% AFTER coherent Tx compounding, take envelopes and subtract:
%
%     E_NSI = 0.5*(abs(W_DC1)+abs(W_DC2)) - abs(W_ZM)
%
% For dc > 0, the triangle inequality ensures 0 <= E_NSI <= dc*abs(D).
% Hence E_NSI / dc is useful for a COMMON DAS amplitude convention,
% but it is not a separately measured/calibrated acoustic quantity.
%
% Zero-mean aperture convention for odd M:
% +1 on first floor(M/2) channels, 0 on center, -1 on last floor(M/2).
% For even M, +1 and -1 each occupy half the ACTIVE aperture.
%
% This is RECEIVE NSI, NOT angle-domain NSI, and NOT a post-hoc B-mode
% image sharpen/unsharp mask.
%
% Data: focused 2D linear-array real RF UFF, USTB UFF reader only.
% Same Chapter-1 RTB Tx blended model / Rx F# / Tx Tukey25 / compounding.
% Defaults intentionally use a dense lateral 2D ROI around TheGB target.
%
% opts:
%   x_min / x_max       default -4e-3 / 3e-3
%   use_full_tx_span    default false; true -> auto x bounds from UFF Tx
%   z_min / z_max       default 18e-3 / 22.5e-3
%   n_x / n_z           default 281 / 181
%   dc_offset           default 0.2, strictly >0
%   rx_f_number         default 1.7
%   tx_f_number         default 2
%   tx_min_aperture     default 3e-3
%   pw_margin           default 1e-3 (RTB blended doesn't use it)
%   blending_power      default 0.5
%   tx_window           default 'tukey25'
%   frame_index         default 1
%   wave_stride         default 1
%   display_dynamic_range_db   default 60
%   verbose             default true

    if nargin<1 || isempty(filename)
        filename='../../data/L7_FI_TheGB.uff';
    end
    if nargin<2 || isempty(opts)
        opts=struct();
    end
    opts=apply_defaults(opts);

    assert(exist(filename,'file')==2,'Cannot find UFF: %s',filename);
    assert(~isempty(which('uff.read_object')), ...
        'USTB UFF reader not on MATLAB path.');

    cd=uff.read_object(filename,'/channel_data');
    assert(isreal(cd.data) && abs(cd.modulation_frequency)<eps, ...
        'This RTB teaching implementation expects real RF UFF.');
    assert(opts.frame_index>=1 && opts.frame_index<=cd.N_frames, ...
        'frame_index out of range.');
    assert(cd.N_channels==cd.probe.N_elements, ...
        'Probe / receive channel mismatch.');

    probe=cd.probe;
    seq=cd.sequence;
    Nw=cd.N_waves;
    Nc=cd.N_channels;

    assert(max(abs(probe.y(:)-probe.y(1)))<1e-9 && ...
           max(abs(probe.z(:)-probe.z(1)))<1e-9, ...
        'This teaching core expects a 1-D linear array.');

    element_pitch=diff(probe.x(:));
    assert(all(element_pitch>0) || all(element_pitch<0), ...
        'Channel order must follow monotonic physical element positions.');
    assert(max(abs(abs(element_pitch)-median(abs(element_pitch)))) ...
           <max(1e-9,1e-3*median(abs(element_pitch))), ...
        'The receive element pitch must be approximately uniform.');

    src_x=zeros(Nw,1);
    src_y=zeros(Nw,1);
    for iw=1:Nw
        assert(seq(iw).wavefront==uff.wavefront.spherical && ...
               seq(iw).source.z>0, ...
            'Wave %d is not positive-focused spherical FI.',iw);
        src_x(iw)=seq(iw).source.x;
        src_y(iw)=seq(iw).source.y;
    end
    assert(max(abs(src_y))<1e-9, ...
        'This teaching core expects 2D x-z focused imaging.');

    % Full-field mode derives the lateral limits from the actual UFF
    % focused transmit positions; it does not hard-code phantom or
    % carotid coordinates. Default point-target ROI remains unchanged.
    if opts.use_full_tx_span
        x_min=min(src_x);
        x_max=max(src_x);
    else
        x_min=opts.x_min;
        x_max=opts.x_max;
    end

    assert(x_max>x_min, ...
        'Focused Tx positions do not define a valid lateral range.');
    assert(x_min>=min(src_x)-1e-12 && ...
           x_max<=max(src_x)+1e-12, ...
        'The RTB ROI must lie inside focused-Tx lateral coverage.');

    % Record the effective x bounds in metadata, including auto full-FOV
    % mode. Otherwise out.options would misleadingly retain the default
    % cropped point-target limits even for a full-width reconstruction.
    opts.x_min=x_min;
    opts.x_max=x_max;

    x_axis=linspace(x_min,x_max,opts.n_x).';
    z_axis=linspace(opts.z_min,opts.z_max,opts.n_z).';
    selected_waves=1:opts.wave_stride:Nw;

    fs=cd.sampling_frequency;
    t0=cd.initial_time;
    c=cd.sound_speed;

    das_sum=complex(zeros(opts.n_z,opts.n_x));
    zm_sum=complex(zeros(opts.n_z,opts.n_x));
    tx_weight_sum=zeros(opts.n_z,opts.n_x);
    active_tx_count=zeros(opts.n_z,opts.n_x);
    odd_aperture_count=0;

    if opts.verbose
        fprintf('============================================================\n');
        fprintf(' Receive NSI vs Chapter-1 RTB-DAS\n');
        fprintf('============================================================\n');
        fprintf('UFF            : %s\n',filename);
        fprintf('Grid [z,x]     : [%d,%d]\n',opts.n_z,opts.n_x);
        fprintf('dx/dz          : %.5f / %.5f mm\n', ...
            median(diff(x_axis))*1e3,median(diff(z_axis))*1e3);
        fprintf('DC offset      : %.4f\n',opts.dc_offset);
        fprintf('Tx used        : %d of %d\n',numel(selected_waves),Nw);
    end

    for kk=1:numel(selected_waves)
        iw=selected_waves(kk);
        wave=seq(iw);
        rf_wave=double(cd.data(:,:,iw,opts.frame_index));
        analytic_wave=analytic_signal_fft(rf_wave);

        if opts.verbose && ...
                mod(kk-1,max(1,floor(numel(selected_waves)/10)))==0
            fprintf('Tx %d / %d\n',kk,numel(selected_waves));
        end

        for iz=1:opts.n_z
            z=z_axis(iz);
            tx_weights_all=transmit_weights_focused_wave( ...
                wave,x_axis,z,opts);
            active_x=find(tx_weights_all>0);
            if isempty(active_x)
                continue;
            end

            x=x_axis(active_x);
            tau_tx=focused_tx_delay_blended(wave,x,z,opts);

            rx_distance=sqrt( ...
                (x-probe.x(:).').^2 + ...
                (0-probe.y(:).').^2 + ...
                (z-probe.z(:).').^2);
            query_time=tau_tx + rx_distance/c;

            [samples,valid]=sample_matrix_linear_uniform( ...
                analytic_wave,t0,fs,query_time);

            rx_weights=receive_weights_matrix( ...
                probe.x(:).',x,z,opts.rx_f_number);
            rx_weights(~valid)=0;

            S=rx_weights.*samples;   % [active lateral pixels, Rx channels]
            D=sum(S,2);

            % Vectorized zero-mean receive aperture:
            % cumulative sum gives first-half and second-half sums.
            % This is exactly the +1 / -1 / (odd middle=0) apodization.
            active=rx_weights>0;
            M=sum(active,2);
            [~,first]=max(active,[],2);
            [~,rev_first]=max(fliplr(active),[],2);
            last=Nc-rev_first+1;

            good=M>=2;
            assert(all(M(good)==last(good)-first(good)+1), ...
                'Non-contiguous valid Rx aperture; cannot define ZM halves.');

            h=floor(M/2);
            P=[complex(zeros(numel(active_x),1)),cumsum(S,2)];
            row=(1:numel(active_x)).';

            left_half=P(sub2ind(size(P),row,first+h)) ...
                     -P(sub2ind(size(P),row,first));
            right_half=P(sub2ind(size(P),row,last+1)) ...
                      -P(sub2ind(size(P),row,last-h+1));

            Z=left_half-right_half;
            Z(~good)=0;

            odd_aperture_count=odd_aperture_count+ ...
                nnz(good & mod(M,2)==1);

            txw=tx_weights_all(active_x);

            das_sum(iz,active_x)=das_sum(iz,active_x) ...
                +(txw.*D).';

            zm_sum(iz,active_x)=zm_sum(iz,active_x) ...
                +(txw.*Z).';

            tx_weight_sum(iz,active_x)=tx_weight_sum(iz,active_x) ...
                +txw.';
            active_tx_count(iz,active_x)=active_tx_count(iz,active_x) ...
                +double(txw.'>0);
        end
    end

    % Tx weight normalization is the SAME as Chapter-1 RTB-DAS.
    ok=tx_weight_sum>eps;
    D=complex(zeros(size(das_sum)));
    Z=complex(zeros(size(zm_sum)));
    D(ok)=das_sum(ok)./tx_weight_sum(ok);
    Z(ok)=zm_sum(ok)./tx_weight_sum(ok);

    dc=opts.dc_offset;

    % Algebraically equivalent to performing THREE receive beamformings,
    % coherently compounding each over Tx, then envelope/subtraction.
    DC1=Z+dc*D;
    DC2=-Z+dc*D;

    E=0.5*(abs(DC1)+abs(DC2))-abs(Z);

    theoretical_ceiling=dc*abs(D);
    tol=1e-10*max(1,max(theoretical_ceiling(:)));
    assert(all(E(:)>=-tol) && ...
           all(E(:)<=theoretical_ceiling(:)+tol), ...
        'NSI envelope violates its expected [0, dc*DAS] bound.');

    E=max(E,0);  % roundoff only, NOT a user-tuned rectifier
    E_common=E/dc;

    das_env=abs(D);
    das_peak=max(das_env(:));
    nsi_peak=max(E_common(:));
    assert(das_peak>0 && nsi_peak>0, ...
        'The requested ROI has no valid signal.');

    out=struct();
    out.rtb_das_analytic=D;
    out.zero_mean_analytic=Z;
    out.dc1_analytic=DC1;
    out.dc2_analytic=DC2;

    out.das_envelope=das_env;
    out.nsi_envelope=E;
    out.nsi_envelope_das_scale=E_common;

    out.das_db=to_db(das_env,das_peak,opts.display_dynamic_range_db);
    out.nsi_db_common=to_db(E_common,das_peak,opts.display_dynamic_range_db);
    out.nsi_db_self=to_db(E_common,nsi_peak,opts.display_dynamic_range_db);

    out.x_axis=x_axis;
    out.z_axis=z_axis;
    out.full_tx_span=logical(opts.use_full_tx_span);
    out.tx_weight_sum=tx_weight_sum;
    out.active_tx_count=active_tx_count;
    out.selected_waves=selected_waves;
    out.odd_aperture_count=odd_aperture_count;
    out.options=opts;
end

function opts=apply_defaults(opts)
    d=struct('x_min',-4e-3,'x_max',3e-3,'n_x',281, ...
        'use_full_tx_span',false, ...
        'z_min',18e-3,'z_max',22.5e-3,'n_z',181, ...
        'dc_offset',0.2,'frame_index',1, ...
        'tx_f_number',2,'tx_min_aperture',3e-3, ...
        'tx_window','tukey25','blending_power',0.5, ...
        'rx_f_number',1.7,'wave_stride',1, ...
        'display_dynamic_range_db',60,'verbose',true);
    keys=fieldnames(d);
    for k=1:numel(keys)
        key=keys{k};
        if ~isfield(opts,key) || isempty(opts.(key))
            opts.(key)=d.(key);
        end
    end
    assert(isscalar(opts.use_full_tx_span) && ...
           (islogical(opts.use_full_tx_span) || ...
            (isnumeric(opts.use_full_tx_span) && ...
             isfinite(opts.use_full_tx_span) && ...
             ismember(opts.use_full_tx_span,[0 1]))), ...
        'use_full_tx_span must be a scalar logical.');
    assert(opts.x_max>opts.x_min && opts.z_max>opts.z_min, ...
        'Invalid ROI range.');
    assert(isnumeric(opts.n_x) && isscalar(opts.n_x) && ...
           opts.n_x>=2 && opts.n_x==round(opts.n_x), ...
        'n_x must be integer >=2.');
    assert(isnumeric(opts.n_z) && isscalar(opts.n_z) && ...
           opts.n_z>=2 && opts.n_z==round(opts.n_z), ...
        'n_z must be integer >=2.');
    assert(isnumeric(opts.dc_offset) && isscalar(opts.dc_offset) && ...
           isfinite(opts.dc_offset) && opts.dc_offset>0, ...
        'dc_offset must be a finite positive scalar.');
    assert(opts.tx_f_number>0 && opts.rx_f_number>0 && ...
           opts.tx_min_aperture>=0 && opts.blending_power>0, ...
        'Invalid Tx/Rx aperture or blend parameters.');
    assert(strcmpi(opts.tx_window,'tukey25'), ...
        'This Chapter-6 core uses Tx Tukey25 to match the reference.');
    assert(opts.wave_stride>=1 && ...
           opts.wave_stride==round(opts.wave_stride), ...
        'wave_stride must be a positive integer.');
end

function tau=focused_tx_delay_blended(wave,x,z,opts)
    sx=wave.source.x;
    sy=wave.source.y;
    sz=wave.source.z;

    distance=sqrt((x-sx).^2 + (0-sy).^2 + (z-sz).^2);
    if z<sz
        distance=-distance;
    end

    spherical=wave.source.distance+distance;
    plane=wave.source.distance+(z-sz).*ones(size(x));
    pixel_radius=sqrt(x.^2+z.^2);
    normalized_distance=min( ...
        abs(wave.source.distance-pixel_radius)/wave.source.distance,1);
    alpha=normalized_distance.^opts.blending_power;
    path=alpha.*spherical+(1-alpha).*plane;
    tau=path/wave.sound_speed-wave.delay;
end

function w=transmit_weights_focused_wave(wave,x,z,opts)
    ox=wave.origin.x;
    oz=wave.origin.z;
    if all(abs(wave.origin.xyz)<eps) && ...
            any(abs(wave.source.xyz)>eps)
        ox=wave.source.x;
        oz=0;
    end

    axis_vec=[wave.source.x-ox,wave.source.z-oz];
    axis_norm=norm(axis_vec);
    assert(axis_norm>eps,'Invalid focused-wave axis.');
    zu=axis_vec/axis_norm;
    xu=[zu(2),-zu(1)];
    dx=x-wave.source.x;
    dz=z-wave.source.z;

    xlocal=dx*xu(1)+dz*xu(2);
    zlocal=dx*zu(1)+dz*zu(2);
    zeff=max(abs(zlocal),opts.tx_min_aperture*opts.tx_f_number);
    ratio=opts.tx_f_number.*abs(xlocal)./zeff;

    w=zeros(size(ratio));
    flat=ratio<=0.5*(1-0.25);
    taper=ratio>0.5*(1-0.25) & ratio<0.5;
    w(flat)=1;
    rr=ratio(taper);
    w(taper)=0.5.*(1+cos(2*pi/0.25.*(rr-0.25/2-1/2)));
end

function w=receive_weights_matrix(element_x,x,z,rx_f)
    M=numel(element_x);
    w=double(abs(x-element_x)<=z/(2*rx_f));

    empty=~any(w,2);
    if any(empty)
        idx=find(empty);
        for k=1:numel(idx)
            [~,nearest]=min(abs(element_x-x(idx(k))));
            w(idx(k),nearest)=1;
        end
    end

    assert(size(w,2)==M,'Rx weight channel dimension mismatch.');
end

function [values,valid]=sample_matrix_linear_uniform(data,t0,fs,tau)
    [Ns,Nc]=size(data);
    assert(size(tau,2)==Nc,'Query/channel dimension mismatch.');

    u=(tau-t0)*fs+1;
    i0=floor(u);
    alpha=u-i0;
    valid=isfinite(u) & i0>=1 & i0<Ns;

    values=complex(zeros(size(tau)));
    if ~any(valid(:))
        return;
    end

    channel_idx=repmat(1:Nc,size(tau,1),1);
    idx0=sub2ind([Ns,Nc],i0(valid),channel_idx(valid));
    idx1=sub2ind([Ns,Nc],i0(valid)+1,channel_idx(valid));

    values(valid)=...
        (1-alpha(valid)).*data(idx0)+...
        alpha(valid).*data(idx1);
end

function analytic=analytic_signal_fft(rf)
    N=size(rf,1);
    h=zeros(N,1);
    if mod(N,2)==0
        h(1)=1; h(N/2+1)=1;
        h(2:N/2)=2;
    else
        h(1)=1; h(2:(N+1)/2)=2;
    end
    analytic=ifft(fft(rf,[],1).*h,[],1);
end

function db=to_db(env,ref,dynamic_range_db)
    db=20*log10(env/(ref+eps)+eps);
    db=max(-dynamic_range_db,db);
    db=min(0,db);
end
