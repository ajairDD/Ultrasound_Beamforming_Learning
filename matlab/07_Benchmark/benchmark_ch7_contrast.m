function result = benchmark_ch7_contrast(image,x_axis,z_axis,lesion_mm,background_mm)
%BENCHMARK_CH7_CONTRAST ROI-defined CR/CNR/gCNR on an UNCOMPRESSED image.
%
% Required explicit ROIs (never auto-guess a lesion):
% lesion_mm     [xmin xmax zmin zmax], mm
% background_mm [xmin xmax zmin zmax], mm
%
% gCNR uses pooled equal-count (rank/quantile) histogram bins, with
% repeated edges removed. This reduces the brittleness of fixed-width
% histograms, but remains a finite-sample ESTIMATE of PDF overlap.
%
% gCNR can compare arbitrary scalar image values (including SLSC).
% CR/CNR between SLSC coherence and envelope-based methods require
% careful interpretation because their signal definitions differ.
%
% ROI coordinates, sample counts and bin count should be reported.

    assert(isreal(image) && ismatrix(image) && ...
           all(isfinite(image(:))), ...
        'Contrast image must be finite real [z,x].');

    x=x_axis(:)*1e3;
    z=z_axis(:)*1e3;

    assert(isequal(size(image),[numel(z),numel(x)]), ...
        'Expected image shape [z,x].');

    a=extract_roi(image,x,z,lesion_mm);
    b=extract_roi(image,x,z,background_mm);

    assert(numel(a)>=25 && numel(b)>=25, ...
        'Each ROI requires at least 25 image pixels.');

    ma=mean(a);
    mb=mean(b);
    va=var(a,1);
    vb=var(b,1);

    cnr=abs(ma-mb)/(sqrt(va+vb)+eps);
    if ma>0 && mb>0
        cr_db=20*log10(ma/mb);
    else
        cr_db=NaN;
    end

    % Equal-population edges computed from POOLED observations; this
    % enables reasonable comparability under monotonic display mappings.
    pooled=sort([a;b]);
    n=numel(pooled);
    requested_bins=min(32,max(4,floor(sqrt(min(numel(a),numel(b))))));
    idx=round((1:requested_bins-1)*n/requested_bins);
    idx=max(1,min(n-1,idx));
    bounds=(pooled(idx)+pooled(idx+1))/2;
    bounds=unique(bounds(:).');
    edges=[-inf bounds inf];

    p=histcounts(a,edges)/numel(a);
    q=histcounts(b,edges)/numel(b);

    gc=1-sum(min(p,q));
    gc=max(0,min(1,gc));

    result=struct();
    result.CR_dB=cr_db;
    result.CNR=cnr;
    result.gCNR=gc;
    result.target_pixels=numel(a);
    result.background_pixels=numel(b);
    result.n_hist_bins=numel(edges)-1;
    result.lesion_mm=lesion_mm;
    result.background_mm=background_mm;
end

function v=extract_roi(img,x,z,roi)
    assert(isnumeric(roi) && numel(roi)==4 && ...
           all(isfinite(roi)) && ...
           roi(1)<roi(2) && roi(3)<roi(4), ...
        'ROI must be [xmin xmax zmin zmax] mm.');
    ix=x>=roi(1) & x<=roi(2);
    iz=z>=roi(3) & z<=roi(4);
    if ~any(ix) || ~any(iz)
        error('Contrast ROI lies outside the image.');
    end
    block=img(iz,ix);
    v=block(:);
end
