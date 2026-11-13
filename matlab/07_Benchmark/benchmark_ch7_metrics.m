function stat = benchmark_ch7_metrics(img,x_axis,z_axis,opts)
%BENCHMARK_CH7_METRICS Explicit, inspectable image measurements.
%
% Input:
%   img        real 2D scalar image [z,x], UNCOMPRESSED;
%   x_axis     [x,1] in meters;
%   z_axis     [z,1] in meters.
%   opts.point_mm       [x,z] or [] (default [])
%   opts.point_radius_mm 1.2 (rectangular search half-width in mm)
%   opts.speckle_roi_mm [xmin xmax zmin zmax] or []
%   opts.reference      real 2D DAS envelope [z,x] or []
%   opts.measure_psf    true/false; false for SLSC coherence
%
% Output fields:
%   lateral_fwhm_mm, axial_fwhm_mm, lateral_w20_mm,
%   lateral_width_samples, peak_x_mm, peak_z_mm,
%   speckle_cv, speckle_snr, corr_with_das, speckle_n_pixels.
%
% Measurements on speckle ROI are DESCRIPTIVE unless ROI is independently
% verified to be homogeneous. corr_with_das measures visual similarity,
% not truth.
%
% FWHM is an amplitude half-maximum (-6.0206 dB) computed around the
% selected local point peak. For SLSC coherence this is not a physical
% amplitude PSF and is deliberately not reported.

    if nargin < 4
        opts=struct();
    end

    defaults=struct('point_mm',[], 'point_radius_mm',1.2, ...
        'speckle_roi_mm',[], 'reference',[], 'measure_psf',true);
    ks=fieldnames(defaults);
    for k=1:numel(ks)
        key=ks{k};
        if ~isfield(opts,key)
            opts.(key)=defaults.(key);
        end
    end

    x=x_axis(:)*1e3;
    z=z_axis(:)*1e3;
    assert(isequal(size(img),[numel(z),numel(x)]), ...
        'Image must have shape [z,x].');
    assert(isreal(img) && all(isfinite(img(:))), ...
        'Metrics require a finite real scalar image.');
    assert(all(diff(x)>0) && all(diff(z)>0), ...
        'Axes must be strictly increasing.');
    assert(all(img(:)>=-1e-12), ...
        'Metrics image must be nonnegative; clip/display SLSC first.');

    stat=struct('peak_x_mm',NaN,'peak_z_mm',NaN, ...
        'lateral_fwhm_mm',NaN,'axial_fwhm_mm',NaN, ...
        'lateral_w20_mm',NaN,'lateral_width_samples',NaN, ...
        'speckle_cv',NaN,'speckle_snr',NaN, ...
        'corr_with_das',NaN,'speckle_n_pixels',0);

    if opts.measure_psf && ~isempty(opts.point_mm)
        point=opts.point_mm;
        assert(isnumeric(point) && numel(point)==2 && ...
            all(isfinite(point)),'point_mm must be [x,z] in mm.');

        ix=find(abs(x-point(1))<=opts.point_radius_mm);
        iz=find(abs(z-point(2))<=opts.point_radius_mm);

        if ~isempty(ix) && ~isempty(iz)
            data=img(iz,ix);
            [maxval,ind]=max(data(:));
            if maxval>0
                [ii,jj]=ind2sub(size(data),ind);
                ip=ix(jj);
                jp=iz(ii);
                stat.peak_x_mm=x(ip);
                stat.peak_z_mm=z(jp);

                lateral=img(jp,:)/maxval;
                axial=img(:,ip)/maxval;

                stat.lateral_fwhm_mm=width_at_level(x,lateral,ip,0.5);
                stat.axial_fwhm_mm=width_at_level(z,axial,jp,0.5);
                stat.lateral_w20_mm=width_at_level(x,lateral,ip,0.1);

                dx=median(diff(x));
                stat.lateral_width_samples=stat.lateral_fwhm_mm/dx;
            end
        end
    end

    if ~isempty(opts.speckle_roi_mm)
        box=opts.speckle_roi_mm;
        assert(isnumeric(box) && numel(box)==4 && ...
               box(1)<box(2) && box(3)<box(4), ...
            'speckle_roi_mm = [xmin xmax zmin zmax] in mm.');
        xx=x>=box(1) & x<=box(2);
        zz=z>=box(3) & z<=box(4);
        if nnz(xx)>=3 && nnz(zz)>=3
            pixel_values=img(zz,xx);
            v=pixel_values(:);
            stat.speckle_n_pixels=numel(v);
            mu=mean(v);
            sigma=std(v,0);
            if mu>0
                stat.speckle_cv=sigma/mu;
                if sigma>eps
                    stat.speckle_snr=mu/sigma;
                end
            end
            if ~isempty(opts.reference)
                ref=opts.reference;
                assert(isequal(size(ref),size(img)), ...
                    'Reference must use the same [z,x] grid.');
                rr=ref(zz,xx);
                rv=rr(:);
                a=v-mean(v);
                b=rv-mean(rv);
                den=sqrt(sum(a.^2)*sum(b.^2));
                if den>0
                    stat.corr_with_das=dot(a,b)/den;
                end
            end
        end
    end
end

function width=width_at_level(axis,profile,peak_idx,level)
    width=NaN;
    if peak_idx<=1 || peak_idx>=numel(axis) || ...
            ~isfinite(profile(peak_idx)) || ...
            profile(peak_idx)<level
        return;
    end
    low_left=find(profile(1:peak_idx)<level,1,'last');
    right_rel=find(profile(peak_idx:end)<level,1,'first');
    if isempty(low_left) || isempty(right_rel)
        return;
    end
    high_right=peak_idx+right_rel-1;

    a=interp_cross(axis(low_left),profile(low_left), ...
        axis(low_left+1),profile(low_left+1),level);
    b=interp_cross(axis(high_right-1),profile(high_right-1), ...
        axis(high_right),profile(high_right),level);
    width=max(0,b-a);
end

function pos=interp_cross(x1,y1,x2,y2,v)
    if abs(y2-y1)<eps
        pos=0.5*(x1+x2);
    else
        pos=x1+(v-y1)*(x2-x1)/(y2-y1);
    end
end
