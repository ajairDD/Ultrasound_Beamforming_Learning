function report = inspect_benchmark_outputs(fi,rtb)
%INSPECT_BENCHMARK_OUTPUTS Five figures from saved uncompressed real outputs.
% No reconstruction, new ROI labels, new contrast scores, or timing claims.
assert(all(fi.reference_errors<1e-10) && rtb.scaled<1e-10);
assert(isequal(size(fi.imgs{1}),[numel(fi.z),numel(fi.x)]));
assert(isequal(size(rtb.imgs{1}),[numel(rtb.z),numel(rtb.x)]));
F=fi.fi_table; R=rtb.rtb_table;
assert(all(isnan(R.full_core_runtime_s([1 4]))));
assert(isnan(F.lat_FWHM_mm(6)));
assert(all(cellfun(@(v) all(isfinite(v(:))),[fi.imgs,rtb.imgs])));
report=struct('FI_reference_errors',fi.reference_errors, ...
    'RTB_reference_error',rtb.scaled,'FI_lateral_widths_mm',F.lat_FWHM_mm, ...
    'FI_width_grid_intervals',F.lat_FWHM_in_scanlines, ...
    'RTB_lateral_widths_mm',R.lat_FWHM_mm, ...
    'RTB_width_grid_intervals',R.lat_FWHM_in_pixels, ...
    'FI_runtime_s',F.runtime_s,'RTB_runtime_s',R.full_core_runtime_s);

%% 1. Crop for teaching; keep the original coarse FI x grid.
lecture_figure([1550 820]); layout=tiledlayout(2,3,'TileSpacing','loose','Padding','loose');
for k=1:6
    nexttile; val=fi.imgs{k};
    if k==6
        imagesc(fi.x*1e3,fi.z*1e3,val); caxis([0 1]);
        title('SLSC：线性相干性');
    else
        imagesc(fi.x*1e3,fi.z*1e3,20*log10(val/(max(val(:))+eps)+eps));
        caxis([-60 0]); title(char(fi.labels(k))+"：各自峰值参考");
    end
    axis image; xlim([-4 3]); ylim([18 22.5]); colormap(gca,gray); colorbar;
    xlabel('横向 x（mm）'); ylabel('深度 z（mm）');
end
title(layout,{'轨道 A 局部放大；六种方法仍使用原始 FI 扫描线', ...
    '裁剪视野没有加密横向网格；SLSC 灰度不是包络 dB'});

%% 2. Report widths together with output sampling, separately by track.
lecture_figure([1400 620]); layout=tiledlayout(1,2,'TileSpacing','loose');
nexttile; bar(F.lat_FWHM_in_scanlines(1:5)); grid on;
xticks(1:5); xticklabels(F.method(1:5)); ylabel('半幅宽度 / 扫描线间距');
yline(3,'--','3 个间隔：仅为粗筛提醒');
title('轨道 A：窄响应仅跨约 1–2.4 个间隔');
nexttile; bar(R.lat_FWHM_in_pixels); grid on;
xticks(1:4); xticklabels({'DAS','MVDR','NSI δ=0.2','NSI δ=0.8'});
ylabel('半幅宽度 / Δx'); yline(3,'--','3 个间隔：仅为粗筛提醒');
title('轨道 B：相同 Δx = 0.025 mm');
title(layout,'两条轨道分别读；跨过几个间隔不等于完成采样收敛验证');

%% 3. Actual samples, same width definition as the reported tables.
lecture_figure([1450 650]); layout=tiledlayout(1,2,'TileSpacing','loose');
sets={fi,rtb}; counts=[5 4];
colors=[0 0.45 0.7;0.85 0.3 0.1;0 0.5 0.55;0.5 0.2 0.5;0.2 0.5 0.1];
for j=1:2
    nexttile; data=sets{j}; hold on;
    for k=1:counts(j)
        m=benchmark_ch7_metrics(data.imgs{k},data.x,data.z, ...
            struct('point_mm',[-0.745 20.1],'point_radius_mm',1.2));
        [~,iz]=min(abs(data.z*1e3-m.peak_z_mm));
        [~,ix]=min(abs(data.x*1e3-m.peak_x_mm));
        curve=data.imgs{k}(iz,:)/data.imgs{k}(iz,ix);
        plot(data.x*1e3,max(-60,20*log10(curve+eps)),'-o', ...
            'MarkerSize',3,'LineWidth',1.3,'Color',colors(k,:));
    end
    yline(-6.0206,'k--','半幅'); grid on; ylim([-45 2]); xlim([-2 0.6]);
    xlabel('横向 x（mm）'); ylabel('各自局部峰值归一化幅度（dB）');
    legend(strrep(data.labels(1:counts(j)),'c=','δ='),'Location','best');
end
nexttile(1); title('轨道 A：圆点揭示横向扫描线有多稀疏');
nexttile(2); title('轨道 B：密集样点上的局部响应');
title(layout,'各方法使用自己的局部峰值与峰值深度；曲线连线是显示插值');

%% 4. Descriptive FI ROI statistics, not verified speckle fidelity.
lecture_figure([1500 620]); layout=tiledlayout(1,3,'TileSpacing','loose');
values={F.speckle_CV,F.speckle_SNR,F.speckle_corr_DAS};
titles={'CV：标准差 / 均值','均值 / 标准差','与 DAS 的相关系数'};
for k=1:3
    nexttile; bar(values{k}); grid on; xticks(1:6); xticklabels(F.method);
    title(titles{k}); if k==3,ylim([0 1]);end
end
title(layout,{'同一个描述性 ROI：[-12,−8,18,22] mm；每法 2808 个像素', ...
    '尚无独立同质性标注；SLSC 的均值/标准差不是 RF 信噪比'});

%% 5. Draw only genuinely measured runtimes; NaN is not a zero-time bar.
lecture_figure([1450 620]); layout=tiledlayout(1,2,'TileSpacing','loose');
nexttile; bar(F.runtime_s); grid on; xticks(1:6); xticklabels(F.method);
ylabel('整条核心计时（s）'); title('轨道 A：每个核心独立执行一次');
nexttile; bar(R.full_core_runtime_s([2 3])); grid on;
xticks(1:2); xticklabels({'MVDR + 内部 DAS','NSI + 内部 D、Z'});
ylabel('整条核心计时（s）'); title({'轨道 B：只画实际计时的两条路径', ...
    'DAS 与 NSI δ=0.8 未独立计时'});
title(layout,'本轮单次 MATLAB 实测；含读取与前端，不是纯计算内核或产品帧率');

fprintf('Chapter 7 saved-output checks PASS: finite images, shapes, references, intentional NaNs.\n');
fprintf('FI reference errors: %s.\n',mat2str(fi.reference_errors.',9));
fprintf('RTB reference error: %.9e.\n',rtb.scaled);
fprintf('FI lateral widths mm: %s.\n',mat2str(F.lat_FWHM_mm.',9));
fprintf('RTB lateral widths mm: %s.\n',mat2str(R.lat_FWHM_mm.',9));
fprintf('FI measured core times s: %s.\n',mat2str(F.runtime_s.',9));
fprintf('RTB attributed core times s: %s.\n',mat2str(R.full_core_runtime_s.',9));
fprintf('No annotated lesion/background ROIs: no real-data CR/CNR/gCNR claimed.\n');
end

function lecture_figure(sz)
figure('Color','w','Position',[80 80 sz], ...
    'DefaultAxesFontName','Microsoft YaHei','DefaultTextFontName','Microsoft YaHei');
end
