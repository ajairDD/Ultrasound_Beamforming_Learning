function report = inspect_rtb_comparison_outputs(out)
%INSPECT_RTB_COMPARISON_OUTPUTS Four diagnostic figures, no new reconstruction.
% Same saved grid/Tx subset; no imported Chapter-7 widths or lesion metrics.
x=out.x_axis_m*1e3; z=out.z_axis_m*1e3;
assert(numel(out.methods)==7);
for name=out.methods(:).'
    v=out.images.(name{1});
    assert(isequal(size(v),[numel(z),numel(x)]) && all(isfinite(v(:))));
end
D=out.images.DAS; peak=max(D(:));
assert(all(out.images.NSI(:)<=D(:)+1e-9*max(1,peak)));
assert(isempty(out.display_common_db.FDMAS) && isempty(out.display_common_db.SLSC));
assert(all(out.images.SLSC(:)>=-1 & out.images.SLSC(:)<=1));
[~,ind]=max(D(:)); [iz,ix]=ind2sub(size(D),ind);
report=struct('shape_z_x',[numel(z),numel(x)], ...
    'selected_Tx',numel(out.options.selected_tx),'total_Tx',out.input_audit.n_tx, ...
    'dx_dz_mm',[median(diff(x)),median(diff(z))], ...
    'DAS_peak_x_z_mm',[x(ix),z(iz)],'joint_runtime_s',out.elapsed_s, ...
    'MVDR_fallback_attempts',[out.diagnostics.mvdr_fallback,out.diagnostics.mvdr_attempts], ...
    'SLSC_unavailable_pixel_Tx',out.diagnostics.slsc_missing, ...
    'SLSC_valid_pixels',nnz(out.slsc_valid_mask));

%% 1. Shared geometry diagnostics are data, not image-quality scores.
lecture_figure([1500 700]); colormap(gcf,parula);
layout=tiledlayout(1,3,'TileSpacing','loose');
maps={out.active_tx_count,out.tx_weight_sum,out.valid_rx_tx_fraction};
titles={'孔径支持的 Tx 数','Tx 权重之和','有 Rx 数据支持的 Tx 权重比例'};
for k=1:3
    nexttile; imagesc(x,z,maps{k}); axis image; colorbar;
    xlabel('横向 x（mm）'); ylabel('深度 z（mm）'); title(titles{k});
    if k==3,caxis([0 1]);end
end
title(layout,sprintf('实际选择 %d / %d 次 Tx；每个像素使用其中受孔径支持的贡献', ...
    report.selected_Tx,report.total_Tx));

%% 2. One fixed DAS peak depth; change only display reference.
methods={'DAS','CF','GCF','MVDR','NSI'};
colors=[0 0.45 0.7;0.85 0.3 0.1;0 0.5 0.55;0.5 0.2 0.5;0.2 0.5 0.1];
lecture_figure([1450 650]); layout=tiledlayout(1,2,'TileSpacing','loose');
for j=1:2
    nexttile; hold on;
    for k=1:numel(methods)
        val=out.images.(methods{k}); reference=peak;
        if j==1,reference=max(val(:));end
        plot(x,max(-60,20*log10(val(iz,:)/(reference+eps)+eps)),'-o', ...
            'MarkerSize',3,'LineWidth',1.3,'Color',colors(k,:));
    end
    grid on; ylim([-60 3]); xlabel('横向 x（mm）'); ylabel('包络显示值（dB）');
    legend(methods,'Location','best');
end
nexttile(1); title('各自全图峰值参考：看形状');
nexttile(2); title('共同 DAS 全图峰值参考：看数值上的压低');
title(layout,sprintf('相同切片 z = %.4f mm；圆点是实际网格值，不作本轮 FWHM 排名',z(iz)));

%% 3. fDMAS axial morphology plus the RECORDED filter design, not RF spectrum.
meta=out.fdmas_filter; edges=meta.filter_edges_hz;
f0=mean(edges./out.options.fdmas_edges_ratio);
f=linspace(0,meta.fs_image_hz/2,1001); h=zeros(size(f));
h(f>=edges(2)&f<=edges(3))=1;
idx=f>edges(1)&f<edges(2); h(idx)=0.5*(1-cos(pi*(f(idx)-edges(1))/(edges(2)-edges(1))));
idx=f>edges(3)&f<edges(4); h(idx)=0.5*(1+cos(pi*(f(idx)-edges(3))/(edges(4)-edges(3))));
assert(meta.fs_image_hz/2>edges(end));
lecture_figure([1400 650]); layout=tiledlayout(1,2,'TileSpacing','loose');
nexttile; hold on;
for method={'DAS','FDMAS'}
    curve=out.images.(method{1})(:,ix); curve=curve/max(curve);
    plot(z,curve,'LineWidth',1.6);
end
grid on; xlabel('深度 z（mm）'); ylabel('该轴向切片各自峰值归一化包络');
legend('DAS','fDMAS','Location','best'); title(sprintf('固定在 DAS 峰值横向位置 x = %.4f mm',x(ix)));
nexttile; plot(f/f0,h,'LineWidth',1.8); hold on;
xline(meta.fs_image_hz/(2*f0),'--','网格 Nyquist');
grid on; xlabel('频率 / f0'); ylabel('记录的带通设计增益'); ylim([0 1.1]);
title('频带来自 out.fdmas_filter，不是实测 RF 频谱');
title(layout,'深度等效时间采样率 c/(2Δz)；二倍频链路必须检查轴向网格');
report.fdmas_image_fs_hz=meta.fs_image_hz; report.fdmas_edges_hz=edges;

%% 4. Amplitude and coherence are distinct scalars on the same pixel grid.
valid=out.slsc_valid_mask & out.tx_weight_sum>eps;
lecture_figure([1400 650]); layout=tiledlayout(1,2,'TileSpacing','loose');
nexttile; scatter(D(valid)/peak,out.images.SLSC(valid),8,'filled'); grid on;
xlabel('DAS 包络 / DAS 全图峰值'); ylabel('SLSC 原始有符号相关值'); ylim([-1 1]);
title('同一像素可有低幅度和高相关值');
nexttile; plot(x,out.images.SLSC(iz,:),'-o','LineWidth',1.3); hold on;
plot(x,out.display.SLSC(iz,:),'--','LineWidth',1.5);
grid on; xlabel('横向 x（mm）'); ylabel('SLSC 相关值'); ylim([-1 1]);
legend('原始有符号结果','显示：负值裁剪到 0','Location','best');
title(sprintf('相同 z = %.4f mm；无效估计另由遮罩标识',z(iz)));
title(layout,'相关性与幅度不能共用物理解释；这些像素没有病灶真值标注');

fprintf('Chapter 8 saved-output checks PASS: 7 finite [z,x] images; NSI bounds; display exceptions.\n');
fprintf('Grid [z x]=%s; dx/dz mm=%s; selected Tx=%d/%d.\n', ...
    mat2str(report.shape_z_x),mat2str(report.dx_dz_mm,9),report.selected_Tx,report.total_Tx);
fprintf('Fixed DAS peak slice x/z mm: %s.\n',mat2str(report.DAS_peak_x_z_mm,9));
fprintf('MVDR fallback/attempts: %s; SLSC missing pixel-Tx=%d.\n', ...
    mat2str(report.MVDR_fallback_attempts),report.SLSC_unavailable_pixel_Tx);
fprintf('Joint seven-method runtime: %.9f s; not independently timed methods.\n',out.elapsed_s);
fprintf('fDMAS image fs %.9g Hz; edges Hz: %s.\n',meta.fs_image_hz,mat2str(edges,9));
fprintf('No Chapter-7 FWHM numbers or real-data lesion metrics are assigned to this grid.\n');
end

function lecture_figure(sz)
figure('Color','w','Position',[80 80 sz], ...
    'DefaultAxesFontName','Microsoft YaHei','DefaultTextFontName','Microsoft YaHei');
end
