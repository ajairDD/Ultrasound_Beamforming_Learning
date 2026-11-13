function figures = rtb_show_methods(out,display_mode)
%RTB_SHOW_METHODS Display all standard RTB outputs on one common x/z grid.
%
%   rtb_show_methods(out)           % own-peak dB; SLSC remains linear
%   rtb_show_methods(out,'common')  % common DAS dB ref except SLSC
%
% For amplitude methods, "own" is for morphology; "common" exposes
% attenuation relative to DAS but fDMAS is not amplitude-calibrated.
% SLSC always uses a linear correlation colorbar, not dB.
%
% All images are stored in out.images [z,x], in SI coordinate arrays.
    if nargin<2 || isempty(display_mode)
        display_mode='own';
    end
    display_mode=lower(char(display_mode));
    assert(ismember(display_mode,{'own','common'}), ...
        'display_mode must be own or common.');
    assert(isstruct(out) && isfield(out,'images') && ...
        isfield(out,'methods') && isfield(out,'x_axis_m') && ...
        isfield(out,'z_axis_m'), ...
        'Input must be the output of rtb_reconstruct_all.');

    methods=out.methods;
    n=numel(methods);
    ncol=min(4,n);
    nrow=ceil(n/ncol);
    x=out.x_axis_m(:)*1e3;
    z=out.z_axis_m(:)*1e3;

    fig=figure('Color','w', ...
        'Position',[50 50 max(1100,360*ncol) max(530,330*nrow)]);
    for k=1:n
        method=methods{k};
        subplot(nrow,ncol,k);
        if strcmp(method,'SLSC')
            img=out.display.SLSC;
            imagesc(x,z,img);
            caxis([0 1]);
            title('SLSC (linear coherence)');
        else
            if strcmp(display_mode,'common')
                img=out.display_common_db.(method);
                title([method ' (common DAS dB)']);
            else
                img=out.display.(method);
                title([method ' (own-peak dB)']);
            end
            imagesc(x,z,img);
            caxis([-out.options.dynamic_range_db,0]);
        end
        set(gca,'YDir','reverse');
        colormap(gca,gray);
        axis image;
        colorbar;
        xlabel('x (mm)');
        ylabel('z (mm)');
    end

    sgtitle({ ...
        'Universal RTB — same focused Tx/Rx geometry, same x/z grid', ...
        ['Amplitude display: ' display_mode ...
         ' reference; SLSC always linear (not RF amplitude)']});

    figures=fig;
end
