function out = rtb_reconstruct_all(source,cfg)
%RTB_RECONSTRUCT_ALL Common RTB geometry, multiple receive beamformers.
%
% PUBLIC API:
%   out=rtb_reconstruct_all('data.uff',cfg);
%   out=rtb_reconstruct_all(acq,cfg);   % canonical SI metadata struct
%
% Supported methods on RF:
%   DAS CF GCF MVDR fDMAS SLSC NSI
% Supported methods on explicitly phase-referenced complex IQ:
%   DAS CF GCF MVDR NSI
%
% This is a NEW common-geometry RTB implementation, not a wrapper around
% Chapter 1-6 UFF-only functions. Models match Chapter-1 RTB conventions.
% All receive operations use the SAME delayed channel data / Tx weights.
%
% The fDMAS route uses receive-domain REAL-RF pair products followed by an
% approximate image-depth 2*f0 bandpass AFTER RTB Tx combination. It is a
% teaching-oriented RTB extension, not a guaranteed reproduction of an
% existing published RTB-fDMAS sequence.
%
% SLSC is computed per Tx from short-lag REAL-RF correlations within a
% short axial gate and then combined across Tx by a NONCOHERENT weighted
% average of correlation metrics. This is an explicit RTB extension, NOT
% coherent compounding of SLSC as if it were complex RF.
%
% All image arrays are [z,x]; x_axis_m / z_axis_m are meters.

    if nargin<2 || isempty(cfg),cfg=struct();end
    assert(isstruct(cfg) && isscalar(cfg),'cfg must be a scalar struct.');
    t_all=tic; % includes file loading and metadata validation

    acq=rtb_load_acquisition(source);
    cfg=defaults(cfg,acq);

    if ischar(cfg.methods)
        requested={upper(strtrim(cfg.methods))};
    else
        requested=cellstr(upper(string(cfg.methods(:))));
    end
    requested=unique(requested,'stable');
    assert(~isempty(requested),'At least one method must be requested.');
    allowed={'DAS','CF','GCF','MVDR','FDMAS','SLSC','NSI'};
    assert(all(ismember(requested,allowed)), ...
        'Methods must be selected from DAS CF GCF MVDR fDMAS SLSC NSI.');
    if ~ismember('DAS',requested)
        requested=[{'DAS'};requested(:)];
    end

    unavailable=intersect(requested,{'FDMAS','SLSC'},'stable');
    skipped={};
    if strcmp(acq.signal_type,'IQ') && ~isempty(unavailable)
        if strcmp(cfg.unsupported_policy,'error')
            error(['IQ input lacks real RF needed for fDMAS and SLSC: ' ...
                '%s. Supply real pre-beamformed RF or set ' ...
                'unsupported_policy=''skip'' to run remaining methods.'], ...
                strjoin(unavailable,', '));
        end
        skipped=unavailable;
        requested=setdiff(requested,unavailable,'stable');
        warning('RTB:IQSkipped', ...
            'Skipping RF-only methods for IQ data: %s',strjoin(skipped,', '));
    end

    Nx=cfg.n_x;
    x=linspace(cfg.x_range_m(1),cfg.x_range_m(2),Nx).';
    z=linspace(cfg.z_range_m(1),cfg.z_range_m(2),cfg.n_z).';
    Nz=numel(z);
    dz=median(diff(z));
    num_waves=numel(cfg.selected_tx);
    count=double(Nx)*double(Nz)*double(num_waves);
    assert(count<=cfg.max_tx_pixel_count || cfg.allow_large, ...
        ['Requested %.0f Tx-pixels; full MVDR/SLSC is expensive. ' ...
         'Reduce n_x/z_range/wave count, or set allow_large=true.'],count);

    run_cf=ismember('CF',requested);
    run_gcf=ismember('GCF',requested);
    run_mvdr=ismember('MVDR',requested);
    run_fdmas=ismember('FDMAS',requested);
    run_slsc=ismember('SLSC',requested);
    run_nsi=ismember('NSI',requested);

    if run_fdmas
        assert(all(abs(acq.tx_phase_correction_rad(cfg.selected_tx))<1e-10), ...
            ['RTB-fDMAS requires Tx phase-consistent REAL RF. ' ...
             'Arbitrary per-Tx complex phase corrections are not ' ...
             'defined for this teaching fDMAS route.']);
        fs_image=acq.c_m_s/(2*dz);
        filter_edges=cfg.fdmas_edges_ratio*acq.f0_hz;
        assert(numel(filter_edges)==4 && all(diff(filter_edges)>0), ...
            'fdmas_edges_ratio must have four increasing edges.');
        assert(fs_image/2>filter_edges(end), ...
            ['fDMAS z grid cannot resolve 2f0. dz=%.2f um; ' ...
             'required <%.2f um. Increase n_z or reduce z_range_m.'], ...
             dz*1e6,acq.c_m_s/(4*filter_edges(end))*1e6);
    end

    active_tx=zeros(Nz,Nx);
    sum_w=zeros(Nz,Nx);
    % Keep the original Chapter-1 RTB normalization: all Tx weights
    % contribute to the denominator even when no Rx sample is valid.
    % Track the data-supported weight SEPARATELY for vendor QA.
    valid_rx_tx_weight=zeros(Nz,Nx);
    D=complex(zeros(Nz,Nx));

    if run_cf,C=complex(zeros(Nz,Nx));end
    if run_gcf,G=complex(zeros(Nz,Nx));end
    if run_mvdr,V=complex(zeros(Nz,Nx));end
    if run_nsi,Z=complex(zeros(Nz,Nx));end
    if run_fdmas,F=zeros(Nz,Nx);end
    if run_slsc
        S=zeros(Nz,Nx);
        sw=zeros(Nz,Nx);
    end

    diagnostics=struct('mvdr_fallback',0,'mvdr_attempts',0, ...
        'slsc_missing',0,'short_rx_apertures',0, ...
        'max_query_out_of_range_fraction',0);
    ele=acq.element_x_m;
    nc=numel(ele);

    if cfg.verbose
        fprintf('RTB UNIVERSAL: %s | %d samples x %d Rx x %d Tx x %d frame\n', ...
            acq.signal_type,acq.audit.n_samples,nc, ...
            acq.audit.n_tx,acq.audit.n_frames);
        fprintf('  source: %s\n',acq.adapter_source);
        fprintf('  x range [mm]: %.3f .. %.3f, nx=%d\n', ...
            x(1)*1e3,x(end)*1e3,Nx);
        fprintf('  z range [mm]: %.3f .. %.3f, nz=%d, dz=%.3f um\n', ...
            z(1)*1e3,z(end)*1e3,Nz,dz*1e6);
        fprintf('  Tx count=%d; methods=%s\n',num_waves,strjoin(requested,','));
        fprintf('  estimated Tx pixels %.0f\n',count);
    end

    mv_half=max(0,round( ...
        0.5*cfg.mvdr_axial_lambda*acq.c_m_s/acq.f0_hz/dz));
    sl_half=max(1,round( ...
        0.5*cfg.slsc_axial_lambda*acq.c_m_s/acq.f0_hz/dz));
     for wi=1:num_waves
        itx=cfg.selected_tx(wi);
        raw=double(acq.data(:,:,itx,cfg.frame_index));
        if strcmp(acq.signal_type,'RF')
            complex_data=analytic_fft(raw);
        else
            complex_data=raw;
        end

        ft=acq.focus_xyz_m(itx,:);
        org=acq.origin_xyz_m(itx,:);
        ref=acq.tx_reference_distance_m(itx);
        txd=acq.tx_delay_s(itx);
        t0=acq.t0_s(itx);

        for ix=1:Nx
            xx=x(ix);
            wt=tx_weight(ft,org,xx,z,cfg);
            if ~any(wt>0)
                continue;
            end

            % Tx virtual-source timing uses per-wave sound speed,
            % while Rx geometric time uses channel-data sound speed.
            % This reproduces the Chapter-1 UFF convention exactly.
            q_tx=tx_delay(ft,ref,txd,xx,z, ...
                          acq.tx_sound_speed_m_s(itx),cfg);
            d_rx=sqrt((xx-ele).^2+z.^2);
            query_time=q_tx+d_rx/acq.c_m_s;

            [samples,valid]=interp_channel_matrix( ...
                complex_data,t0,acq.fs_hz,query_time);

            if strcmp(acq.signal_type,'IQ')
                samples=samples.*exp(1i*2*pi*acq.demod_hz.* ...
                    (query_time-acq.iq_reference_time_s));
            end
            % Per-Tx correction to make analytic carrier phases coherent.
            % Must be independently calibrated by the vendor adapter.
            samples=samples.*exp(1i*acq.tx_phase_correction_rad(itx));

            if run_fdmas || run_slsc
                [real_samples,~]=interp_channel_matrix( ...
                    raw,t0,acq.fs_hz,query_time);
            end

            % Match Chapter-1 Rx F-number arithmetic/order exactly.
            % Avoid a different <= decision at an aperture boundary.
            aperture_width=z/cfg.rx_f_number;
            half_width=aperture_width/2;
            active=abs(xx-ele)<=half_width;
            empty=~any(active,2);
            if any(empty)
                [~,nearest]=min(abs(ele-xx));
                active(empty,nearest)=true;
            end
            active=active & valid;

            % Match independent Chapter-1 RTB DAS exactly:
            % denominator = sum of all transmit-apodization weights.
            % If receive samples are unavailable, their zero contribution
            % is not renormalized into an artificially brighter echo.
            wt=wt(:);
            receive_has_sample=any(active,2);
            sum_w(:,ix)=sum_w(:,ix)+wt;
            active_tx(:,ix)=active_tx(:,ix)+double(wt>0);
            valid_rx_tx_weight(:,ix)=valid_rx_tx_weight(:,ix)+ ...
                wt.*receive_has_sample;
            diagnostics.max_query_out_of_range_fraction=max( ...
                diagnostics.max_query_out_of_range_fraction, ...
                1-nnz(valid)/numel(valid));

            for iz=1:Nz
                txw=wt(iz);
                if txw<=0,continue;end
                idx=find(active(iz,:));
                M=numel(idx);
                if M==0,continue;end

                ss=samples(iz,idx).';
                dd=sum(ss);
                D(iz,ix)=D(iz,ix)+txw*dd;

                if M<2
                    diagnostics.short_rx_apertures= ...
                        diagnostics.short_rx_apertures+1;
                end
                if M>1 && any(diff(idx)~=1) && ...
                     (run_gcf || run_mvdr || run_fdmas || ...
                      run_slsc || run_nsi)
                    error(['Noncontiguous valid Rx channels at Tx %d, ' ...
                        'x=%.2fmm, z=%.2fmm. Check sample timestamps,' ...
                        ' channel mapping and aperture.'], ...
                        itx,xx*1e3,z(iz)*1e3);
                end

                if run_cf
                    cf=abs(dd)^2/(M*sum(abs(ss).^2)+eps);
                    C(iz,ix)=C(iz,ix)+txw*max(0,min(1,cf))*dd;
                end
                if run_gcf
                    spec=fft(ss);
                    m0=min(cfg.gcf_M0,floor(M/2));
                    bins=unique([1:(m0+1),(M-m0+1):M]);
                    gc=sum(abs(spec(bins)).^2)/ ...
                       (sum(abs(spec).^2)+eps);
                    G(iz,ix)=G(iz,ix)+txw*max(0,min(1,gc))*dd;
                end
                if run_nsi
                    h=floor(M/2);
                    zm=sum(ss(1:h))-sum(ss(end-h+1:end));
                    Z(iz,ix)=Z(iz,ix)+txw*zm;
                end
                if run_fdmas && M>=2
                    u=sign(real_samples(iz,idx).').* ...
                        sqrt(abs(real_samples(iz,idx).'));
                    dmas=0.5*(sum(u)^2-sum(u.^2));
                    F(iz,ix)=F(iz,ix)+txw*dmas;
                end
                if run_mvdr
                    diagnostics.mvdr_attempts=diagnostics.mvdr_attempts+1;
                    rows=max(1,iz-mv_half):min(Nz,iz+mv_half);
                    rows=rows(wt(rows)>0);
                    [vm,used_fallback]=mvdr_pixel(ss, ...
                        samples(rows,idx),valid(rows,idx), ...
                        cfg.mvdr_fraction,cfg.mvdr_loading);
                    V(iz,ix)=V(iz,ix)+txw*vm;
                    diagnostics.mvdr_fallback= ...
                        diagnostics.mvdr_fallback+double(used_fallback);
                end
                if run_slsc
                    rows=max(1,iz-sl_half):min(Nz,iz+sl_half);
                    rows=rows(wt(rows)>0);
                    [sl,ok]=slsc_pixel( ...
                        real_samples(rows,idx), ...
                        valid(rows,idx),cfg);
                    if ok
                        S(iz,ix)=S(iz,ix)+txw*sl;
                        sw(iz,ix)=sw(iz,ix)+txw;
                    else
                        diagnostics.slsc_missing= ...
                            diagnostics.slsc_missing+1;
                    end
                end
            end
        end
        if cfg.verbose
            fprintf('  processed Tx %d of %d (wave %d)\n',wi,num_waves,itx);
        end
    end

    support=sum_w>eps;
    D(support)=D(support)./sum_w(support);
    if run_cf,C(support)=C(support)./sum_w(support);end
    if run_gcf,G(support)=G(support)./sum_w(support);end
    if run_mvdr,V(support)=V(support)./sum_w(support);end
    if run_nsi,Z(support)=Z(support)./sum_w(support);end
    if run_fdmas,F(support)=F(support)./sum_w(support);end

    images=struct();
    images.DAS=abs(D);
    if run_cf,images.CF=abs(C);end
    if run_gcf,images.GCF=abs(G);end
    if run_mvdr,images.MVDR=abs(V);end
    if run_nsi
        offset=cfg.nsi_dc;
        residual=0.5*(abs(Z+offset*D)+abs(-Z+offset*D))-abs(Z);
        tol=1e-9*max(1,max(offset*abs(D(:))));
        assert(all(residual(:)>=-tol) && ...
            all(residual(:)<=offset*abs(D(:))+tol), ...
            'NSI violates triangle-inequality bound; check phase/units.');
        images.NSI=max(residual,0)/offset;
    end
    if run_slsc
        good=sw>eps;
        S(good)=S(good)./sw(good);
        images.SLSC=max(-1,min(1,S)); % signed, not RF amplitude
    end
    if run_fdmas
        [filtered,filter_meta]=fdmas_bandpass(F,dz,acq.c_m_s, ...
            acq.f0_hz,cfg.fdmas_edges_ratio);
        images.FDMAS=abs(analytic_fft(filtered));
    else
        filter_meta=[];
    end

    peak=max(images.DAS(:));
    assert(peak>0,'All DAS pixels are zero: inspect Tx timing/geometry.');
    shown=struct();
    common_db=struct();
    for k=1:numel(requested)
        method=requested{k};
        val=images.(method);
        if strcmp(method,'SLSC')
            % Coherence has a different physical scale; display LINEAR.
            shown.(method)=max(val,0);
            common_db.(method)=[];
        else
            maxval=max(val(:));
            shown.(method)=max(-cfg.dynamic_range_db, ...
                20*log10(val/(maxval+eps)+eps));
            if strcmp(method,'FDMAS')
                % fDMAS non-linear pair products do NOT have the same
                % acoustic amplitude unit as DAS. Never offer a
                % misleading common-DAS amplitude comparison.
                common_db.(method)=[];
            else
                common_db.(method)=max(-cfg.dynamic_range_db, ...
                    20*log10(val/(peak+eps)+eps));
            end
        end
    end

    out=struct();
    out.images=images;           % [z,x], non-log, signed SLSC
    out.display=shown;           % own-peak dB or SLSC linear
    out.display_common_db=common_db; % dB same DAS peak, not SLSC
    out.methods=requested;
    out.skipped=skipped;
    out.x_axis_m=x;
    out.z_axis_m=z;
    out.rtb_das_analytic=D;
    if run_slsc
        % SLSC output 0 on unsupported pixels is NOT a measurement of
        % zero coherence. Expose a separate mask for interpretation.
        out.slsc_valid_mask=sw>eps;
    else
        out.slsc_valid_mask=[];
    end
    out.tx_weight_sum=sum_w;
    out.active_tx_count=active_tx;
    out.valid_rx_tx_weight_sum=valid_rx_tx_weight;
    out.valid_rx_tx_fraction=zeros(Nz,Nx);
    out.valid_rx_tx_fraction(support)= ...
        valid_rx_tx_weight(support)./sum_w(support);
    out.input_audit=acq.audit;
    out.source_info=acq.adapter_source;
    out.options=cfg;
    diagnostics.tx_weight_without_rx=sum(max( ...
        sum_w(:)-valid_rx_tx_weight(:),0));
    diagnostics.tx_weight_total=sum(sum_w(:));
    diagnostics.missing_rx_tx_weight_fraction= ...
        diagnostics.tx_weight_without_rx/(diagnostics.tx_weight_total+eps);
    out.diagnostics=diagnostics;
    out.fdmas_filter=filter_meta;
    out.elapsed_s=toc(t_all);
    if diagnostics.missing_rx_tx_weight_fraction>1e-4
        warning('RTB:MissingRxSupport', ...
            ['Some transmit-weighted image pixels have NO valid Rx ' ...
             'samples: global missing Tx-weight fraction %.3g. ' ...
             'Inspect valid_rx_tx_fraction, t0 and sample length.'], ...
             diagnostics.missing_rx_tx_weight_fraction);
    end
    if cfg.verbose
        fprintf('Finished universal RTB in %.2f s\n',out.elapsed_s);
        fprintf('MVDR fallback %d/%d, SLSC unavailable pixel-Tx %d\n', ...
            diagnostics.mvdr_fallback, ...
            diagnostics.mvdr_attempts,diagnostics.slsc_missing);
    end
end

%% ------------------------------------------------------------------------
function cfg=defaults(cfg,a)
    d=struct( ...
        'methods',{{'DAS','CF','GCF','MVDR','FDMAS','SLSC','NSI'}}, ...
        'frame_index',1, ...
        'x_range_m',[], 'n_x',64, ...
        'z_range_m',[], 'n_z',[], ...
        'wave_stride',4,'selected_tx',[], ...
        'tx_delay_model','blended','blending_power',0.5, ...
        'tx_f_number',2,'tx_min_aperture_m',3e-3, ...
        'tx_window','tukey25', ...
        'rx_f_number',1.7, ...
        'gcf_M0',1, ...
        'mvdr_fraction',0.5,'mvdr_loading',0.01, ...
        'mvdr_axial_lambda',1.5, ...
        'slsc_lag_fraction',0.15,'slsc_max_lag',12, ...
        'slsc_axial_lambda',1,'slsc_min_samples',3, ...
        'nsi_dc',0.8, ...
        'fdmas_edges_ratio',[1.5,1.75,2.5,2.75], ...
        'dynamic_range_db',60, ...
        'unsupported_policy','error', ...
        'max_tx_pixel_count',2e6,'allow_large',false, ...
        'verbose',true);
    fs=fieldnames(d);
    for k=1:numel(fs)
        key=fs{k};
        if ~isfield(cfg,key) || isempty(cfg.(key))
            cfg.(key)=d.(key);
        end
    end

    focus=a.focus_xyz_m;
    nw=a.audit.n_tx;
    if isempty(cfg.x_range_m)
        lo=min(focus(:,1));
        hi=max(focus(:,1));
        if hi-lo<1e-8
            % A single focused transmit is still a physical 2D beam.
            % Its output ROI can extend laterally beyond its focus x;
            % actual insonification is determined by Tx support weights.
            reach=min(4e-3,0.5*(max(a.element_x_m)-min(a.element_x_m)));
            lo=lo-reach;
            hi=hi+reach;
        end
        cfg.x_range_m=[lo,hi];
    end
    if isempty(cfg.z_range_m)
        zc=median(focus(:,3));
        cfg.z_range_m=[max(0.5e-3,zc-2e-3),zc+2e-3];
    end
    assert(isnumeric(cfg.x_range_m) && ...
        numel(cfg.x_range_m)==2 && ...
        all(isfinite(cfg.x_range_m)) && ...
        cfg.x_range_m(1)<cfg.x_range_m(2), ...
        'x_range_m must be increasing [min max] in METERS.');
    assert(isnumeric(cfg.z_range_m) && ...
        numel(cfg.z_range_m)==2 && ...
        all(isfinite(cfg.z_range_m)) && ...
        cfg.z_range_m(1)>0 && cfg.z_range_m(2)>cfg.z_range_m(1), ...
        'z_range_m must be increasing positive [min max] in METERS.');
    % Tx source positions are NOT a hard lateral image limit:
    % a single focused beam can insonify off-axis locations, too.
    % The actual per-pixel Tx support/coverage is reported in out.

    if isempty(cfg.n_z)
        lambda=a.c_m_s/a.f0_hz;
        cfg.n_z=ceil(diff(cfg.z_range_m)/(lambda/16))+1;
    end
    assert(isnumeric(cfg.n_x) && isscalar(cfg.n_x) && ...
           isfinite(cfg.n_x) && cfg.n_x>=2 && ...
           cfg.n_x==round(cfg.n_x) && ...
           isnumeric(cfg.n_z) && isscalar(cfg.n_z) && ...
           isfinite(cfg.n_z) && cfg.n_z>=3 && ...
           cfg.n_z==round(cfg.n_z), ...
        'n_x/n_z must be positive integers with n_x>=2, n_z>=3.');
    assert(isscalar(cfg.frame_index) && ...
           cfg.frame_index>=1 && ...
           cfg.frame_index<=a.audit.n_frames && ...
           cfg.frame_index==round(cfg.frame_index), ...
        'frame_index out of range.');
    assert(isscalar(cfg.wave_stride) && ...
           cfg.wave_stride>=1 && ...
           cfg.wave_stride==round(cfg.wave_stride), ...
        'wave_stride must be a positive integer.');
    if isempty(cfg.selected_tx)
        cfg.selected_tx=(1:cfg.wave_stride:nw).';
    end
    assert(isnumeric(cfg.selected_tx) && ...
           all(cfg.selected_tx(:)>=1 & cfg.selected_tx(:)<=nw) && ...
           all(cfg.selected_tx(:)==round(cfg.selected_tx(:))) && ...
           numel(unique(cfg.selected_tx))==numel(cfg.selected_tx), ...
        'selected_tx must contain unique valid 1-based Tx indices.');
    cfg.selected_tx=cfg.selected_tx(:);

    positive={'tx_f_number','rx_f_number','blending_power', ...
        'mvdr_fraction','mvdr_loading','mvdr_axial_lambda', ...
        'slsc_lag_fraction','slsc_axial_lambda','nsi_dc'};
    for k=1:numel(positive)
        val=cfg.(positive{k});
        assert(isnumeric(val) && isscalar(val) && ...
            isfinite(val) && val>0, ...
            '%s must be a positive finite scalar.',positive{k});
    end
    assert(cfg.mvdr_fraction<=1 && cfg.slsc_lag_fraction<=1, ...
        'mvdr_fraction and slsc_lag_fraction must lie in (0,1].');
    assert(isscalar(cfg.gcf_M0) && cfg.gcf_M0>=0 && ...
           cfg.gcf_M0==round(cfg.gcf_M0), ...
        'gcf_M0 must be nonnegative integer.');
    assert(isscalar(cfg.slsc_max_lag) && cfg.slsc_max_lag>=1 && ...
           cfg.slsc_max_lag==round(cfg.slsc_max_lag) && ...
           isscalar(cfg.slsc_min_samples) && ...
           cfg.slsc_min_samples>=2 && ...
           cfg.slsc_min_samples==round(cfg.slsc_min_samples), ...
        'Invalid SLSC lag/sample settings.');
    assert(cfg.tx_min_aperture_m>=0, ...
        'tx_min_aperture_m must be nonnegative.');
    assert(ismember(lower(cfg.tx_delay_model),{'blended','spherical','plane'}), ...
        'tx_delay_model must be blended, spherical or plane.');
    assert(ismember(lower(cfg.tx_window),{'boxcar','tukey25'}), ...
        'tx_window must be boxcar or tukey25.');
    cfg.unsupported_policy=lower(char(cfg.unsupported_policy));
    assert(ismember(cfg.unsupported_policy,{'error','skip'}), ...
        'unsupported_policy must be error or skip.');
    assert(isnumeric(cfg.max_tx_pixel_count) && ...
           isscalar(cfg.max_tx_pixel_count) && ...
           cfg.max_tx_pixel_count>0, ...
        'max_tx_pixel_count must be positive.');
end

function tau=tx_delay(focus,dist,delay,xx,z,c,cfg)
    signed=sqrt((xx-focus(1)).^2+(z-focus(3)).^2);
    signed(z<focus(3))=-signed(z<focus(3));
    spherical=dist+signed;
    plane=dist+z-focus(3);
    switch lower(cfg.tx_delay_model)
        case 'spherical',path=spherical;
        case 'plane',path=plane;
        case 'blended'
            radius=sqrt(xx^2+z.^2);
            alpha=min(abs(dist-radius)/dist,1).^cfg.blending_power;
            path=alpha.*spherical+(1-alpha).*plane;
    end
    tau=path/c-delay;
end

function w=tx_weight(focus,origin,xx,z,cfg)
    % Same order of operations as Chapter-1
    % transmit_weights_focused_wave/tukey_ratio_window.
    ox=origin(1);
    oz=origin(3);
    sx=focus(1);
    sz=focus(3);

    axis_vec=[sx-ox,sz-oz];
    axis_norm=norm(axis_vec);
    assert(axis_norm>eps,'Focused origin and source coincide.');
    zu=axis_vec/axis_norm;
    xu=[zu(2),-zu(1)];

    dx=xx-sx;
    dz=z-sz;
    x_local=dx*xu(1)+dz*xu(2);
    z_local=dx*zu(1)+dz*zu(2);

    z_eff=max(abs(z_local), ...
        cfg.tx_min_aperture_m*cfg.tx_f_number);
    ratio=cfg.tx_f_number.*abs(x_local)./z_eff;

    switch lower(cfg.tx_window)
        case 'boxcar'
            w=double(ratio<=0.5);
        case 'tukey25'
            roll=0.25;
            w=zeros(size(ratio));
            flat=ratio<=0.5*(1-roll);
            taper=ratio>0.5*(1-roll) & ratio<0.5;
            w(flat)=1;
            r=ratio(taper);
            w(taper)=0.5.*(1+cos( ...
                2*pi/roll.*(r-roll/2-1/2)));
        otherwise
            error('Unsupported Tx window: %s',cfg.tx_window);
    end
end

function [v,valid]=interp_channel_matrix(data,t0,fs,tau)
    [ns,nc]=size(data);
    assert(size(tau,2)==nc, ...
        'Query time dimension 2 must equal receive channel count.');
    u=(tau-t0)*fs+1;
    left=floor(u);
    alpha=u-left;
    valid=isfinite(u) & left>=1 & left<ns;
    v=zeros(size(u),'like',data);
    if ~any(valid(:)),return;end
    ch=repmat(1:nc,size(tau,1),1);
    i0=sub2ind([ns,nc],left(valid),ch(valid));
    i1=sub2ind([ns,nc],left(valid)+1,ch(valid));
    v(valid)=(1-alpha(valid)).*data(i0)+alpha(valid).*data(i1);
end

function v=analytic_fft(raw)
    ns=size(raw,1);
    filt=zeros(ns,1);
    filt(1)=1;
    if mod(ns,2)==0
        filt(ns/2+1)=1;
        filt(2:ns/2)=2;
    else
        filt(2:(ns+1)/2)=2;
    end
    v=ifft(fft(raw,[],1).*filt,[],1);
end

function [y,fallback]=mvdr_pixel(s,gate,gate_valid,fraction,loading)
    M=numel(s);
    fallback=false;
    L=max(2,min(M,round(M*fraction)));
    P=M-L+1;
    if M<3 || P<2
        y=sum(s);fallback=true;return;
    end

    % Build P overlapping subarrays from each axial snapshot.
    indices=(0:L-1).'+(1:P);
    R=complex(zeros(L,L));
    count=0;
    for q=1:size(gate,1)
        keep=all(gate_valid(q,indices),1);
        if any(keep)
            slice=gate(q,indices);
            X=slice(:,keep);
            R=R+X*X';
            count=count+nnz(keep);
        end
    end
    if count<1
        y=sum(s);fallback=true;return;
    end

    R=R/count;
    power=real(trace(R))/L;
    if ~(isfinite(power) && power>eps)
        y=sum(s);fallback=true;return;
    end
    R=R+loading*power*eye(L);
    steering=ones(L,1);
    sol=R\steering;
    denom=steering'*sol;
    if ~(isfinite(real(denom)) && isfinite(imag(denom)) && ...
         abs(denom)>eps)
        y=sum(s);fallback=true;return;
    end

    weights=sol/denom;
    center=s(indices);
    y=M*mean(weights'*center); % nominal DAS receive-scale convention
end

function [value,ok]=slsc_pixel(gate,valid,cfg)
    M=size(gate,2);
    value=0;ok=false;
    if M<3 || size(gate,1)<cfg.slsc_min_samples
        return;
    end

    mmax=min([cfg.slsc_max_lag,M-1, ...
        max(1,floor(cfg.slsc_lag_fraction*M))]);
    rsum=0;
    goodlags=0;

    % Vectorize all physical channel pairs within each element lag.
    for lag=1:mmax
        a=gate(:,1:M-lag);
        b=gate(:,1+lag:M);
        both=valid(:,1:M-lag) & valid(:,1+lag:M);
        counts=sum(both,1);
        a(~both)=0;
        b(~both)=0;

        numerator=sum(a.*b,1);
        ea=sum(a.^2,1);
        eb=sum(b.^2,1);
        good=counts>=cfg.slsc_min_samples & ea>0 & eb>0;
        if any(good)
            corr=numerator(good)./sqrt(ea(good).*eb(good));
            corr=max(-1,min(1,corr));
            rsum=rsum+mean(corr);
            goodlags=goodlags+1;
        end
    end
    if goodlags>0
        value=rsum/goodlags;  % documented mean-lag convention
        ok=true;
    end
end

function [filtered,meta]=fdmas_bandpass(raw,dz,c,f0,relative_edges)
    fs_img=c/(2*dz);
    e=relative_edges*f0;
    n=size(raw,1);
    pad=max(32,round(4*c/f0/dz));
    % Mirror axial image before 2f0 filter to reduce FFT boundary seams.
    idx=[flipud((1:min(pad,n)).');(1:n).'; ...
         flipud((max(1,n-min(pad,n)+1):n).')];
    % Column-major indexing: flatten/pad ONLY along z.
    array=raw(idx,:);
    np=size(array,1);
    freq=(0:np-1)'*fs_img/np;
    ff=min(freq,fs_img-freq);
    h=zeros(np,1);
    plateau=ff>=e(2) & ff<=e(3);
    left=ff>e(1) & ff<e(2);
    right=ff>e(3) & ff<e(4);
    h(plateau)=1;
    h(left)=0.5*(1-cos(pi*(ff(left)-e(1))/(e(2)-e(1))));
    h(right)=0.5*(1+cos(pi*(ff(right)-e(3))/(e(4)-e(3))));
    all_f=real(ifft(fft(array,[],1).*h,[],1));
    filtered=all_f(min(pad,n)+(1:n),:);
    meta=struct('fs_image_hz',fs_img,'filter_edges_hz',e, ...
        'filter_stage','after weighted Tx summation on z grid', ...
        'padding','axial mirrored boundary');
end
