function report=inspect_nsi_outputs(point,results)
%INSPECT_NSI_OUTPUTS Five lecture views from the SAME saved D,Z branches.
% Figures 1/2: all three full-FOV acquisitions at delta=0.8, reconstructed
% algebraically from D,Z, without another RF interpolation/Tx combination.
% Figures 3/4/5: actual point sampling, common-mask retention distributions,
% and common-vs-self display references. No new NSI variants or quality ROI.
assert(numel(results)==3,'Expected TheGB and two carotid acquisitions.');
names={'TheGB 体模','颈动脉横断面 1','颈动脉横断面 2'};
offsets=[0.2 0.8]; views=cell(3,2); report=struct();
summary=repmat(struct(),3,1);
for k=1:3
    out=results{k}; shape=[numel(out.z_axis),numel(out.x_axis)];
    assert(isequal(size(out.rtb_das_analytic),shape));
    assert(isequal(size(out.zero_mean_analytic),shape));
    assert(all(isfinite(out.rtb_das_analytic(:))) && ...
        all(isfinite(out.zero_mean_analytic(:))));
    for j=1:2
        views{k,j}=offset_view(out,offsets(j));
    end
    baseline_error=max(abs(views{k,1}.scaled(:)-out.nsi_envelope_das_scale(:)))/ ...
        max(out.das_envelope(:));
    assert(baseline_error<1e-12,'Saved core and offset reconstruction differ.');
    assert(isequal(views{k,1}.mask,views{k,2}.mask));
    assert(isequal(views{k,1}.mask,out.ratio_mask));
    assert(isequal(out.options.x_min,out.x_axis(1)) && ...
        isequal(out.options.x_max,out.x_axis(end)));
    summary(k).dataset=names{k};
    summary(k).foreground_count=nnz(views{k,1}.mask);
    summary(k).recombine_delta02_error=baseline_error;
    summary(k).median_delta02=views{k,1}.median;
    summary(k).median_delta08=views{k,2}.median;
    summary(k).fraction_below_quarter_delta02=views{k,1}.quarter;
    summary(k).fraction_below_quarter_delta08=views{k,2}.quarter;
end

%% 1. Same D/Z and common DAS reference; offset=0.8, no RF rerun.
figure('Color','w','Position',[40 30 1500 1700]);
for k=1:3
    out=results{k}; view=views{k,2};
    x=out.x_axis*1e3; z=out.z_axis*1e3;
    subplot(3,2,2*k-1);
    imagesc(x,z,out.das_db); set(gca,'YDir','reverse'); axis image;
    caxis([-60 0]); colormap(gca,gray(256)); colorbar;
    xlabel('横向 x（mm）'); ylabel('深度 z（mm）');
    title(sprintf('%s | RTB-DAS',names{k}));
    subplot(3,2,2*k);
    imagesc(x,z,view.common_db); set(gca,'YDir','reverse'); axis image;
    caxis([-60 0]); colormap(gca,gray(256)); colorbar;
    xlabel('横向 x（mm）'); ylabel('深度 z（mm）');
    title(sprintf('%s | RTB-NSI，δ = 0.8',names{k}));
end
sgtitle({'与 δ = 0.2 使用同一 D、Z：仅重算包络组合', ...
    '每行共用本数据的 DAS 0 dB 参考；不跨数据集比较绝对亮度'});

%% 2. Foreground retention ratio at 0.8, on exactly the SAME mask as 0.2.
figure('Color','w','Position',[60 60 1800 800]);
for k=1:3
    out=results{k}; view=views{k,2};
    subplot(1,3,k);
    im=imagesc(out.x_axis*1e3,out.z_axis*1e3,view.ratio);
    im.AlphaData=double(view.mask);
    set(gca,'Color',[0.94 0.94 0.94],'YDir','reverse'); axis image;
    caxis([0 1]); colormap(gca,parula(256)); colorbar;
    xlabel('横向 x（mm）'); ylabel('深度 z（mm）');
    title({names{k},sprintf('δ = 0.8；保留比中位数 = %.2f',view.median)});
end

%% 3. Physical samples and interpolated half-amplitude crossings.
x=point.x_axis*1e3; z=point.z_axis*1e3;
ix=find(abs(x+0.745)<=1); iz=find(abs(z-20.1)<=1);
assert(~isempty(ix) && ~isempty(iz));
[zd,xd]=local_peak(point.das_envelope,iz,ix);
[zn,xn]=local_peak(point.nsi_envelope_das_scale,iz,ix);
profiles={point.das_envelope(zd,:)/point.das_envelope(zd,xd), ...
    point.nsi_envelope_das_scale(zn,:)/point.nsi_envelope_das_scale(zn,xn)};
peaks=[xd xn]; titles={'RTB-DAS','RTB-NSI，δ = 0.2'};
dx=median(diff(x)); widths=zeros(1,2);
figure('Color','w','Position',[80 80 1450 700]);
tiledlayout(1,2,'TileSpacing','loose','Padding','loose');
for j=1:2
    nexttile;
    plot(x,profiles{j},'-o','LineWidth',1.7,'MarkerSize',4); hold on;
    yline(0.5,'--','半幅位置');
    [widths(j),crossings]=half_width(x,profiles{j},peaks(j));
    plot(crossings,[0.5 0.5],'ks','MarkerFaceColor','k','MarkerSize',7);
    xlim([-1.7 0.3]); ylim([0 1.08]); grid on;
    xlabel('横向 x（mm）'); ylabel('各自局部峰值归一化幅度');
    title({titles{j},sprintf('半幅宽 %.4f mm，跨 %.2f 个网格间隔', ...
        widths(j),widths(j)/dx)});
end
sgtitle('圆点是实际网格值，黑方块是线性插值得到的交点；两条剖面各取自身峰值深度');
report.point_half_amplitude_width_mm=widths;
report.point_width_grid_intervals=widths/dx;

%% 4. Same foreground population: amplitude-retention CDF, not CNR/SNR.
figure('Color','w','Position',[100 100 1600 650]);
tiledlayout(1,3,'TileSpacing','loose','Padding','loose');
for k=1:3
    nexttile;
    for j=1:2
        view=views{k,j}; r=sort(view.ratio(view.mask));
        plot(r,(1:numel(r))/numel(r),'LineWidth',1.8); hold on;
    end
    yline(0.5,'k:'); grid on; xlim([0 1]); ylim([0 1]);
    xlabel('幅度保留比 E/(δ|D|)'); ylabel('累计前景像素比例');
    title({names{k},sprintf('共同有效像素数 = %d',summary(k).foreground_count)});
    legend('δ = 0.2','δ = 0.8','Location','best');
end

%% 5. Self-normalization is a display change, not restoration of signal.
out=results{1}; view=views{1,1};
reference=max(out.das_envelope(:)); self_peak=max(view.scaled(:));
self_db=20*log10(view.scaled/(self_peak+eps)+eps);
self_db=max(-60,min(0,self_db));
figure('Color','w','Position',[120 120 1800 800]);
images={out.das_db,view.common_db,self_db};
labels={'DAS：本数据的峰值为 0 dB', ...
    'NSI：共用 DAS 的 0 dB 参考','NSI：改用自身峰值为 0 dB'};
for k=1:3
    subplot(1,3,k);
    imagesc(out.x_axis*1e3,out.z_axis*1e3,images{k});
    set(gca,'YDir','reverse'); axis image; caxis([-60 0]);
    colormap(gca,gray(256)); colorbar;
    xlabel('横向 x（mm）'); ylabel('深度 z（mm）'); title(labels{k});
end
report.full_summaries=summary;
report.thegb_self_reference_shift_db=20*log10(self_peak/reference);
fprintf('NSI same-output checks PASS: finite [z,x], offset bounds, common masks, effective x bounds.\n');
fprintf('Point half-amplitude widths [DAS NSI] mm: %s.\n',mat2str(widths,9));
fprintf('Point widths / dx: %s; dx=%.9f mm.\n',mat2str(widths/dx,9),dx);
for k=1:3
    fprintf('Full case %d: foreground=%d; recombine error=%.6e.\n', ...
        k,summary(k).foreground_count,summary(k).recombine_delta02_error);
    fprintf('  median retention delta 0.2 / 0.8: %.9f / %.9f.\n', ...
        summary(k).median_delta02,summary(k).median_delta08);
    fprintf('  fraction retention <0.25: %.9f / %.9f.\n', ...
        summary(k).fraction_below_quarter_delta02,summary(k).fraction_below_quarter_delta08);
end
fprintf('TheGB NSI delta0.2 global peak relative to DAS: %.9f dB.\n', ...
    report.thegb_self_reference_shift_db);
fprintf('No ground-truth image-quality or clinical superiority claim is made.\n');
end

function view=offset_view(out,dc)
D=out.rtb_das_analytic; Z=out.zero_mean_analytic;
E=0.5*(abs(Z+dc*D)+abs(-Z+dc*D))-abs(Z);
scale=max(1,max(abs(D(:))));
assert(all(E(:)>=-1e-12*scale) && all(E(:)<=dc*abs(D(:))+1e-12*scale));
value=max(E,0)/dc; ref=max(out.das_envelope(:));
ratio=value./max(out.das_envelope,eps(ref));
assert(all(ratio(:)<=1+1e-10)); ratio=max(0,min(1,ratio));
mask=out.das_db>=-40 & out.tx_weight_sum>eps;
assert(any(mask(:)));
db=20*log10(value/(ref+eps)+eps); db=max(-60,min(0,db));
view=struct('scaled',value,'common_db',db,'ratio',ratio,'mask',mask, ...
    'median',median(ratio(mask)),'quarter',nnz(ratio(mask)<0.25)/nnz(mask));
end

function [iz,ix]=local_peak(image,rows,columns)
cut=image(rows,columns); [~,p]=max(cut(:)); [r,c]=ind2sub(size(cut),p);
iz=rows(r); ix=columns(c);
end

function [width,crossings]=half_width(x,y,p)
left=find(y(1:p)<0.5,1,'last'); right=p-1+find(y(p:end)<0.5,1,'first');
assert(~isempty(left) && ~isempty(right));
xl=x(left)+(0.5-y(left))*diff(x(left:left+1))/diff(y(left:left+1));
xr=x(right-1)+(0.5-y(right-1))*diff(x(right-1:right))/diff(y(right-1:right));
crossings=[xl xr]; width=xr-xl;
end
