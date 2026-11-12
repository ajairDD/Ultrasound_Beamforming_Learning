function out = reconstruct_fi_slsc_manual(filename,opts)
%RECONSTRUCT_FI_SLSC_MANUAL Manual FI-DAS and receive-domain SLSC.
%
% Standard short-lag coherence idea, Lediju et al., IEEE TUFFC 2011.
% USTB is used ONLY as a UFF reader; no USTB beamforming is called.
%
% INPUT (UFF):
%   cd.data [sample, receive_channel, focused_Tx, frame], REAL RF.
%
% OUTPUT SHAPE:
%   all images [z, focused_Tx scanline].
%
% SLSC at pixel depth iz:
%   - delay real RF per channel using Chapter-1 Tx/Rx timing;
%   - choose contiguous active receive elements using the same Rx F#;
%   - use an axial kernel centered at the pixel (fixed element indices);
%   - for each short lag m, normalized cross-correlate channel pairs
%     across kernel samples; average across available pairs;
%   - sum the first m_max lag correlations (classic SLSC definition).
%
% This implementation also returns the MEAN across available lags for
% clearer display when dynamic Rx F# makes m_max vary with depth. Mean
% vs sum is an explicit project normalization choice, not a new method.
%
% opts:
%   z_min = 5e-3, z_max = 45e-3, n_z = 768
%   frame_index = 1
%   receive_f_number = 1.7
%   axial_kernel_lambda = 1.0  % full kernel length, in wavelengths
%   lag_fraction = 0.15        % floor(Q*M_active), dynamic
%   max_lag = 12               % maximum physical element separation
%   min_valid_samples = 3      % per pair / kernel
%   verbose = true
%
% Scientific boundary:
%   Q is relative to ACTIVE Rx elements, not the full hardware aperture.
%   No per-channel envelope / log compression before correlation.
%   Raw signed coherence can be negative. Display uses clipped [0,1].
%   No claim that image is a calibrated RF/amplitude B-mode signal.

    if nargin < 1 || isempty(filename)
        filename = '../../data/L7_FI_TheGB.uff';
    end
    if nargin < 2 || isempty(opts)
        opts = struct();
    end
    opts = apply_defaults(opts);

    assert(exist(filename,'file') == 2, ...
        'UFF file does not exist: %s',filename);
    assert(~isempty(which('uff.read_object')), ...
        'USTB UFF reader was not found; add USTB to MATLAB path.');

    cd = uff.read_object(filename,'/channel_data');

    assert(isreal(cd.data) && abs(cd.modulation_frequency)<eps, ...
        'This Chapter-5 implementation expects real, non-demodulated RF.');
    assert(opts.frame_index>=1 && opts.frame_index<=cd.N_frames, ...
        'frame_index out of range.');
    assert(cd.N_channels==cd.probe.N_elements, ...
        'Receive-channel count and probe-element count differ.');

    c = cd.sound_speed;
    lambda = cd.lambda;
    fs = cd.sampling_frequency;
    t0 = cd.initial_time;
    assert(isscalar(lambda) && isfinite(lambda) && lambda>0, ...
        'channel_data.lambda must be a positive scalar.');

    seq = cd.sequence;
    probe = cd.probe;
    Nwaves = cd.N_waves;
    Nch = cd.N_channels;

    source_x=zeros(Nwaves,1);
    for iw=1:Nwaves
        assert(seq(iw).wavefront==uff.wavefront.spherical && ...
               seq(iw).source.z>0, ...
            'Wave %d is not positive-focus conventional FI.',iw);
        assert(abs(seq(iw).source.y)<1e-9, ...
            'This core assumes a 2-D x-z focused scan.',iw);
        source_x(iw)=seq(iw).source.x;
    end

    x_axis=source_x;
    z_axis=linspace(opts.z_min,opts.z_max,opts.n_z).';

    dz=median(diff(z_axis));
    kernel_points=max(3,round(opts.axial_kernel_lambda*lambda/dz));
    if mod(kernel_points,2)==0
        kernel_points=kernel_points+1;
    end
    half_kernel=floor(kernel_points/2);

    das=complex(zeros(opts.n_z,Nwaves));
    slsc_sum=zeros(opts.n_z,Nwaves);
    slsc_mean=zeros(opts.n_z,Nwaves);
    valid_lag_count=zeros(opts.n_z,Nwaves);
    requested_lag_count=zeros(opts.n_z,Nwaves);
    active_channel_count=zeros(opts.n_z,Nwaves);

    % Saved to demonstrate WHY short lags are integrated.
    lag_correlations=nan(opts.n_z,Nwaves,opts.max_lag);

    if opts.verbose
        fprintf('===========================================================\n');
        fprintf(' Manual FI-DAS vs Short-Lag Spatial Coherence\n');
        fprintf('===========================================================\n');
        fprintf('UFF             : %s\n',filename);
        fprintf('shape [z,x]     : [%d,%d]\n',opts.n_z,Nwaves);
        fprintf('dz              : %.5f mm\n',dz*1e3);
        fprintf('lambda          : %.5f mm\n',lambda*1e3);
        fprintf('axial kernel    : %d samples (%.3f lambda)\n', ...
            kernel_points,kernel_points*dz/lambda);
        fprintf('lag fraction Q  : %.3f of active Rx\n',opts.lag_fraction);
        fprintf('max lag         : %d elements\n',opts.max_lag);
        fprintf('Rx F#           : %.3f\n\n',opts.receive_f_number);
    end

    for iw=1:Nwaves

        if opts.verbose && ...
                mod(iw-1,max(1,floor(Nwaves/10)))==0
            fprintf('Tx %d / %d ...\n',iw,Nwaves);
        end

        rf=double(cd.data(:,:,iw,opts.frame_index));
        analytic_rf=analytic_signal_fft(rf);
        x=x_axis(iw);

        % Time delay for ALL z/channel samples of one scanline.
        tau_tx=focused_tx_delay_spherical_depth(seq(iw),x,z_axis);
        d_rx=sqrt( ...
            (probe.x(:).'-x).^2 + ...
            probe.y(:).'.^2 + ...
            (z_axis-probe.z(:).').^2);
        tau=tau_tx+d_rx/c;

        [aligned_rf,aligned_analytic,valid]=interp_rf_and_analytic( ...
            rf,analytic_rf,t0,fs,tau);

        half_aperture=z_axis/(2*opts.receive_f_number);
        geometric_active= ...
            abs(probe.x(:).'-x)<=half_aperture;

        % Match Chapter-1 geometric receive fallback: if the intended
        % F# aperture is empty, select the nearest element.
        no_aperture=~any(geometric_active,2);
        if any(no_aperture)
            [~,nearest]=min(abs(probe.x(:).'-x));
            geometric_active(no_aperture,nearest)=true;
        end

        active=geometric_active & valid;
        active_channel_count(:,iw)=sum(active,2);

        % Exactly the same analytic DAS sum as Chapter 1.
        das(:,iw)=sum(aligned_analytic.*active,2);

        for iz=1:opts.n_z

            idx=find(active(iz,:));
            M=numel(idx);
            if M<3
                continue;
            end

            % Lag m means m physical element pitches. Never treat
            % disconnected channel indices as physically adjacent.
            assert(all(diff(idx)==1), ...
                ['Non-contiguous active receive aperture at ' ...
                 'wave %d, z-index %d.'],iw,iz);

            n_lags=min([opts.max_lag,M-1, ...
                         max(1,floor(opts.lag_fraction*M))]);
            requested_lag_count(iz,iw)=n_lags;

            i0=max(1,iz-half_kernel);
            i1=min(opts.n_z,iz+half_kernel);
            rows=i0:i1;

            % The ELEMENT indices are held fixed across the axial gate.
            % Use acquisition-valid flags at every axial sample.
            gate=aligned_rf(rows,idx);
            gate_valid=valid(rows,idx);

            running_sum=0;
            n_good_lags=0;

            for lag=1:n_lags

                a=gate(:,1:M-lag);
                b=gate(:,1+lag:M);

                common_valid= ...
                    gate_valid(:,1:M-lag) & ...
                    gate_valid(:,1+lag:M);

                a(~common_valid)=0;
                b(~common_valid)=0;

                counts=sum(common_valid,1);
                numerator=sum(a.*b,1);
                energy_a=sum(a.^2,1);
                energy_b=sum(b.^2,1);

                keep=counts>=opts.min_valid_samples & ...
                     energy_a>0 & energy_b>0;

                if ~any(keep)
                    continue;
                end

                rho=numerator(keep)./ ...
                    sqrt(energy_a(keep).*energy_b(keep));
                rho=max(-1,min(1,rho));

                rlag=mean(rho);
                lag_correlations(iz,iw,lag)=rlag;

                running_sum=running_sum+rlag;
                n_good_lags=n_good_lags+1;
            end

            if n_good_lags>0
                slsc_sum(iz,iw)=running_sum;
                slsc_mean(iz,iw)=running_sum/n_good_lags;
                valid_lag_count(iz,iw)=n_good_lags;
            end
        end
    end

    das_env=abs(das);
    peak=max(das_env(:));
    assert(peak>0,'DAS output is empty.');

    das_db=20*log10(das_env/(peak+eps)+eps);
    das_db=max(-opts.display_dynamic_range_db,das_db);

    % Keep signed SLSC values for analysis; clipped display has no
    % brightness interpretation identical to DAS's dB envelope.
    slsc_display=max(slsc_mean,0);
    disp_peak=max(slsc_display(:));
    assert(disp_peak>0,'SLSC output has no positive correlation values.');
    slsc_display=slsc_display/disp_peak;

    out=struct();
    out.das_analytic=das;
    out.das_envelope=das_env;
    out.das_db=das_db;

    out.slsc_sum=slsc_sum;
    out.slsc_mean=slsc_mean;
    out.slsc_display=slsc_display;
    out.lag_correlations=lag_correlations;
    out.valid_lag_count=valid_lag_count;
    out.requested_lag_count=requested_lag_count;
    out.active_channel_count=active_channel_count;

    out.x_axis=x_axis;
    out.z_axis=z_axis;
    out.lambda=lambda;
    out.fs=fs;
    out.initial_time=t0;
    out.sound_speed=c;
    out.axial_kernel_samples=kernel_points;
    out.axial_kernel_lambda_actual=kernel_points*dz/lambda;
    out.options=opts;
end

function opts=apply_defaults(opts)
    d=struct( ...
        'z_min',5e-3,'z_max',45e-3,'n_z',768, ...
        'frame_index',1,'receive_f_number',1.7, ...
        'axial_kernel_lambda',1.0, ...
        'lag_fraction',0.15,'max_lag',12, ...
        'min_valid_samples',3, ...
        'display_dynamic_range_db',60, ...
        'verbose',true);
    keys=fieldnames(d);
    for i=1:numel(keys)
        k=keys{i};
        if ~isfield(opts,k) || isempty(opts.(k))
            opts.(k)=d.(k);
        end
    end

    assert(isscalar(opts.z_min) && isnumeric(opts.z_min) && ...
           isfinite(opts.z_min) && opts.z_min>=0, ...
        'z_min must be a non-negative finite scalar in m.');
    assert(isscalar(opts.z_max) && isfinite(opts.z_max) && ...
           opts.z_max>opts.z_min, ...
        'z_max must exceed z_min.');
    assert(isscalar(opts.n_z) && opts.n_z>=10 && ...
           opts.n_z==round(opts.n_z), ...
        'n_z must be integer >= 10.');
    assert(isscalar(opts.receive_f_number) && ...
           isfinite(opts.receive_f_number) && ...
           opts.receive_f_number>0,'Rx F# must be positive.');
    assert(isscalar(opts.axial_kernel_lambda) && ...
           isfinite(opts.axial_kernel_lambda) && ...
           opts.axial_kernel_lambda>0, ...
        'axial_kernel_lambda must be positive.');
    assert(isscalar(opts.lag_fraction) && ...
           isfinite(opts.lag_fraction) && ...
           opts.lag_fraction>0 && opts.lag_fraction<=1, ...
        'lag_fraction must lie in (0,1].');
    assert(isscalar(opts.max_lag) && ...
           opts.max_lag>=1 && opts.max_lag==round(opts.max_lag), ...
        'max_lag must be a positive integer.');
    assert(isscalar(opts.min_valid_samples) && ...
           opts.min_valid_samples>=2 && ...
           opts.min_valid_samples==round(opts.min_valid_samples), ...
        'min_valid_samples must be an integer >=2.');
    assert(isscalar(opts.frame_index) && opts.frame_index>=1 && ...
           opts.frame_index==round(opts.frame_index), ...
        'frame_index must be positive integer.');
end

function tau=focused_tx_delay_spherical_depth(wave,x,z)
    d=sqrt((wave.source.x-x).^2 + wave.source.y.^2 + ...
           (wave.source.z-z).^2);
    d(z<wave.source.z)=-d(z<wave.source.z);
    tau=(d+wave.source.distance)/wave.sound_speed-wave.delay;
end

function [r,iq,valid]=interp_rf_and_analytic(rf,analytic_rf,t0,fs,tau)
    [Ns,Nch]=size(rf);
    assert(size(tau,2)==Nch, ...
        'Receive time-query channel dimension mismatch.');
    u=(tau-t0)*fs+1;
    n0=floor(u);
    alpha=u-n0;

    valid=isfinite(u) & n0>=1 & n0<Ns;
    r=zeros(size(tau));
    iq=complex(zeros(size(tau)));
    if ~any(valid(:))
        return;
    end

    chans=repmat(1:Nch,size(tau,1),1);
    idx0=sub2ind([Ns,Nch],n0(valid),chans(valid));
    idx1=sub2ind([Ns,Nch],n0(valid)+1,chans(valid));

    r(valid)=(1-alpha(valid)).*rf(idx0)+alpha(valid).*rf(idx1);
    iq(valid)=(1-alpha(valid)).*analytic_rf(idx0) ...
             +alpha(valid).*analytic_rf(idx1);
end

function analytic=analytic_signal_fft(rf)
    N=size(rf,1);
    spectrum=fft(rf,[],1);
    mask=zeros(N,1);
    if mod(N,2)==0
        mask(1)=1;
        mask(N/2+1)=1;
        mask(2:N/2)=2;
    else
        mask(1)=1;
        mask(2:(N+1)/2)=2;
    end
    analytic=ifft(spectrum.*mask,[],1);
end
