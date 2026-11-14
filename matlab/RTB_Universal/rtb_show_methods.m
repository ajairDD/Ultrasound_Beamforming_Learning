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
        'Position',[50 50 max(1200,420*ncol) max(600,320*nrow)], ...
        'DefaultAxesFontName','Microsoft YaHei','DefaultTextFontName','Microsoft YaHei');
    for k=1:n
        method=methods{k};
        subplot(nrow,ncol,k);
        if strcmp(method,'SLSC')
            img=out.display.SLSC;
            h=imagesc(x,z,img);
            if isfield(out,'slsc_valid_mask') && ...
                    ~isempty(out.slsc_valid_mask)
                % Grey means no valid short-lag estimate, not a measured
                % coherence of zero.
                set(h,'AlphaData',double(out.slsc_valid_mask));
                set(gca,'Color',[0.85 0.85 0.85]);
            end
            caxis([0 1]);
            panel_title={'SLSC：线性相干性','灰色：无有效估计'};
        else
            if strcmp(method,'FDMAS')
                img=out.display.FDMAS;
                panel_title={'fDMAS：各自峰值 dB','未作跨方法幅度标定'};
            elseif strcmp(display_mode,'common')
                img=out.display_common_db.(method);
                panel_title={method,'共同 DAS 峰值参考'};
            else
                img=out.display.(method);
                panel_title={method,'各自峰值参考'};
            end
            imagesc(x,z,img);
            caxis([-out.options.dynamic_range_db,0]);
        end
        set(gca,'YDir','reverse');
        colormap(gca,gray);
        axis image;
        colorbar;
        xlabel('横向 x（mm）');
        ylabel('深度 z（mm）');
        % imagesc resets axes in replace mode. Set title only AFTER
        % plotting so every method keeps its panel label.
        title(panel_title,'Interpreter','none','FontSize',10);
    end

    if strcmp(display_mode,'own')
        mode_label='包络图使用各自峰值参考';
    else
        mode_label='可比包络图使用共同 DAS 参考';
    end
    sgtitle({'相同聚焦 Tx/Rx 几何、相同输出网格的七方法 RTB 对照', ...
        [mode_label '；fDMAS 保留自身参考，SLSC 始终为线性相干性']});

    figures=fig;
end
