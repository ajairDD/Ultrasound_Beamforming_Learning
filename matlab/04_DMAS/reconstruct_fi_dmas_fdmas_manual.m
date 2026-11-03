function out = reconstruct_fi_dmas_fdmas_manual(filename,opts)
%RECONSTRUCT_FI_DMAS_FDMAS_MANUAL Conventional focused FI: DAS / DMAS / fDMAS.
%
% Reference definition (real RF, sign-sqrt):
%   u_i = sign(s_i)*sqrt(abs(s_i))
%   DMAS = sum_{i<j} u_i*u_j
%        = 0.5*((sum(u))^2-sum(u.^2))
%
% The efficient equality removes the O(M^2) nested loop; both forms are
% exactly the same for real-valued s. Uses active Rx only.
%
% fDMAS is NOT obtained by doing the above on complex IQ or by simply
% taking abs(DMAS). A band-pass around 2*f0 is required, followed by
% analytic envelope detection. It is performed ALONG DEPTH at an
% approximately uniform two-way image-time sampling frequency:
%
%   t_image ~= 2*z/c, fs_image = c/(2*dz)
%
% This image-space approximation follows the conventional ultrasound
% F-DMAS practice; it is not identical to time-domain raw-channel
% filtering for all off-axis paths.
%
% IMPORTANT:
%   - USTB is used only for UFF reading/metadata.
%   - Same Tx/Rx delays, interpolation, receive F# for DAS and DMAS.
%   - Real RF for pairwise DMAS; complex analytic RF for reference DAS.
%   - fDMAS axial grid MUST be fine enough to resolve ~2*f0.
%   - Do not interpret fDMAS amplitudes as directly calibrated to DAS.
%
% opts:
%   z_min / z_max [m]        5e-3 / 45e-3
%   n_z                      [] => approximately lambda/16 axial spacing
%   frame_index              1
%   receive_f_number         1.7
%   filter_relative_edges    [1.5 1.75 2.5 2.75] * f0
%   display_dynamic_range_db 60
%   verbose                  true

    if nargin < 1 || isempty(filename)
        filename = '../../data/L7_FI_TheGB.uff';
    end
    if nargin < 2 || isempty(opts)
        opts = struct();
    end
    opts = defaults(opts);

    assert(exist(filename,'file')==2,'Missing UFF: %s',filename);
    assert(~isempty(which('uff.read_object')),'USTB / UFF reader not on path.');

    cd = uff.read_object(filename,'/channel_data');
    assert(isreal(cd.data) && abs(cd.modulation_frequency)<eps, ...
        'This implementation requires real, non-demodulated RF data.');
    assert(opts.frame_index>=1 && opts.frame_index<=cd.N_frames, ...
        'Invalid frame_index.');

    probe = cd.probe;
    sequence = cd.sequence;
    N_channels = cd.N_channels;
    N_waves = cd.N_waves;
    assert(N_channels==probe.N_elements,'Probe/channel mismatch.');

    c = cd.sound_speed;
    fs = cd.sampling_frequency;
    t0 = cd.initial_time;
    lambda = cd.lambda;
    assert(isfinite(lambda) && lambda>0, ...
        'channel_data.lambda must be positive.');
    f0 = c/lambda;

    if isempty(opts.n_z)
        opts.n_z = ceil((opts.z_max-opts.z_min)/(lambda/16))+1;
    end
    assert(isscalar(opts.n_z) && opts.n_z>=16 && ...
           opts.n_z==round(opts.n_z), ...
        'n_z must be an integer >=16.');

    source_x = zeros(N_waves,1);
    for iw=1:N_waves
        assert(sequence(iw).wavefront==uff.wavefront.spherical && ...
               sequence(iw).source.z>0, ...
            'This chapter supports positive-focus spherical FI only.');
        assert(abs(sequence(iw).source.y)<1e-9, ...
            'This chapter assumes an x-z image plane.');
        source_x(iw)=sequence(iw).source.x;
    end

    x_axis=source_x;
    z_axis=linspace(opts.z_min,opts.z_max,opts.n_z).';
    dz=z_axis(2)-z_axis(1);
    fs_z=c/(2*dz);

    % Filter mask is defined using the NOMINAL f0 metadata. The actual
    % RF pulse spectrum can differ; inspect spectral plots if needed.
    F=opts.filter_relative_edges(:).'*f0;
    assert(all(diff(F)>0) && F(1)>0, ...
        'filter_relative_edges must be four increasing positive values.');
    assert(fs_z/2>F(4), ...
        ['fDMAS 2*f0 band aliases on the image-depth grid. ' ...
         'Reduce dz / increase n_z. fs_z/2=%.3f MHz, F4=%.3f MHz.'], ...
         fs_z/2e6,F(4)/1e6);

    if opts.verbose
        fprintf('FI DAS / DMAS / fDMAS\n');
        fprintf('  [Nz Nx]        : [%d %d]\n',opts.n_z,N_waves);
        fprintf('  z spacing      : %.5f mm\n',dz*1e3);
        fprintf('  image fs_z     : %.3f MHz (two-way depth-time approximation)\n',fs_z/1e6);
        fprintf('  nominal f0     : %.3f MHz\n',f0/1e6);
        fprintf('  filter edges   : [%.2f %.2f %.2f %.2f] MHz\n',F/1e6);
    end

    das=complex(zeros(opts.n_z,N_waves));
    dmas_raw=zeros(opts.n_z,N_waves);
    active_rx=zeros(opts.n_z,N_waves);

    for iw=1:N_waves
        if opts.verbose && mod(iw-1,max(1,floor(N_waves/10)))==0
            fprintf('  Tx %d / %d\n',iw,N_waves);
        end
        rf_wave=double(cd.data(:,:,iw,opts.frame_index));
        analytic_wave=analytic_signal_fft(rf_wave);
        x=x_axis(iw);

        for iz=1:opts.n_z
            z=z_axis(iz);
            tau_tx=focused_tx_delay_spherical(sequence(iw),x,z);

            d_rx=sqrt((probe.x(:).'-x).^2 + ...
                      probe.y(:).'.^2 + ...
                      (probe.z(:).'-z).^2);
            tau=tau_tx+d_rx/c;

            [samples,valid]=interp_channels(analytic_wave,t0,fs,tau);

            % Same dynamic receive F# / boxcar used for both branches.
            half_width=z/(2*opts.receive_f_number);
            in_aperture=abs(probe.x(:).'-x)<=half_width;

            % Match Chapter-1 receive_weights exactly: only select a
            % nearest element when the GEOMETRIC aperture is empty.
            % Do not reactivate a valid out-of-aperture element merely
            % because all in-aperture time queries were out of range.
            if ~any(in_aperture)
                [~,nearest]=min(abs(probe.x(:).'-x));
                in_aperture(nearest)=true;
            end
            active=in_aperture & valid;
            M=nnz(active);
            active_rx(iz,iw)=M;
            if M==0
                continue;
            end

            s=samples(active);
            das(iz,iw)=sum(s);

            if M>=2
                rf=real(s);
                u=sign(rf).*sqrt(abs(rf));
                pair_sum=0.5*(sum(u).^2-sum(u.^2));

                % Scale to be O(M) for a coherent real RF amplitude.
                % This is an algebraic comparison convention only:
                % fDMAS remains nonlinearly transformed and uncalibrated.
                dmas_raw(iz,iw)=2*pair_sum/(M-1);
            end
        end
    end

    % Zero-phase, two-sided, raised-cosine frequency window around 2*f0.
    % Zero-padding reduces periodic-boundary wraparound effects.
    Npad=2^nextpow2(2*opts.n_z);
    f=(0:Npad-1).'*fs_z/Npad;
    f_abs=min(f,fs_z-f);
    H=zeros(Npad,1);

    low=(f_abs>=F(1)) & (f_abs<F(2));
    mid=(f_abs>=F(2)) & (f_abs<=F(3));
    high=(f_abs>F(3)) & (f_abs<=F(4));

    H(low)=0.5-0.5*cos(pi*(f_abs(low)-F(1))/(F(2)-F(1)));
    H(mid)=1;
    H(high)=0.5+0.5*cos(pi*(f_abs(high)-F(3))/(F(4)-F(3)));

    Y=fft(dmas_raw,Npad,1);
    fdmas_filtered=real(ifft(Y.*H,[],1));
    fdmas_filtered=fdmas_filtered(1:opts.n_z,:);

    fdmas_analytic=analytic_signal_fft(fdmas_filtered);

    das_env=abs(das);
    fdmas_env=abs(fdmas_analytic);

    das_peak=max(das_env(:));
    fdmas_peak=max(fdmas_env(:));

    assert(das_peak>0 && fdmas_peak>0, ...
        'At least one beamformed image is all zero.');

    out=struct();
    out.das_analytic=das;
    out.das_envelope=das_env;
    out.dmas_unfiltered=dmas_raw;
    out.fdmas_filtered=fdmas_filtered;
    out.fdmas_analytic=fdmas_analytic;
    out.fdmas_envelope=fdmas_env;
    out.das_db=to_db(das_env,das_peak,opts.display_dynamic_range_db);
    out.fdmas_db_self=to_db(fdmas_env,fdmas_peak,opts.display_dynamic_range_db);

    out.x_axis=x_axis;
    out.z_axis=z_axis;
    out.active_channel_count=active_rx;
    out.fs=fs;
    out.image_fs_z=fs_z;
    out.nominal_f0=f0;
    out.filter_edges=F;
    out.filter_mask=H;
    out.options=opts;
end

function opts=defaults(opts)
    defaults_struct=struct( ...
        'z_min',5e-3,'z_max',45e-3,'n_z',[], ...
        'frame_index',1,'receive_f_number',1.7, ...
        'filter_relative_edges',[1.5 1.75 2.5 2.75], ...
        'display_dynamic_range_db',60,'verbose',true);

    names=fieldnames(defaults_struct);
    for k=1:numel(names)
        key=names{k};
        if ~isfield(opts,key) || isempty(opts.(key))
            opts.(key)=defaults_struct.(key);
        end
    end
    assert(isscalar(opts.z_min) && isscalar(opts.z_max) && ...
           opts.z_max>opts.z_min,'Invalid z range.');
    assert(isscalar(opts.receive_f_number) && ...
           opts.receive_f_number>0,'receive_f_number must be positive.');
end

function tau=focused_tx_delay_spherical(wave,x,z)
    d=sqrt((wave.source.x-x).^2 + wave.source.y.^2 + ...
           (wave.source.z-z).^2);
    if z<wave.source.z
        d=-d;
    end
    tau=(d+wave.source.distance)/wave.sound_speed-wave.delay;
end

function [values,valid]=interp_channels(channel_data,t0,fs,tau)
    [Ns,Nc]=size(channel_data);
    u=(tau-t0)*fs+1;
    i0=floor(u);
    alpha=u-i0;
    valid=isfinite(u) & i0>=1 & i0<Ns;
    values=complex(zeros(1,Nc));
    ch=1:Nc;
    idx0=sub2ind([Ns Nc],i0(valid),ch(valid));
    idx1=sub2ind([Ns Nc],i0(valid)+1,ch(valid));
    values(valid)=...
        (1-alpha(valid)).*channel_data(idx0)+...
        alpha(valid).*channel_data(idx1);
end

function xa=analytic_signal_fft(x)
    N=size(x,1);
    X=fft(x,[],1);
    h=zeros(N,1);
    if mod(N,2)==0
        h(1)=1; h(N/2+1)=1; h(2:N/2)=2;
    else
        h(1)=1; h(2:(N+1)/2)=2;
    end
    xa=ifft(X.*h,[],1);
end

function y=to_db(env,peak,dynamic_range)
    y=20*log10(env/(peak+eps)+eps);
    y=max(-dynamic_range,y);
end
