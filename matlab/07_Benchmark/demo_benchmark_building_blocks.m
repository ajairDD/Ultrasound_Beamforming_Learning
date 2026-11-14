function report = demo_benchmark_building_blocks()
%DEMO_BENCHMARK_BUILDING_BLOCKS Seven deterministic lessons, no UFF/USTB.
% Synthetic scalar images illustrate measurement definitions, not acoustics.
rng(7,'twister');
report=struct();

%% 1. Measure a known Gaussian envelope, using the real metric function.
x=(-2:0.01:2)*1e-3; z=(18:0.01:22)*1e-3;
sx=0.6/(2*sqrt(2*log(2))); sz=0.4/(2*sqrt(2*log(2)));
A=exp(-0.5*((x*1e3+0.7)/sx).^2-0.5*((z(:)*1e3-20.1)/sz).^2);
m=benchmark_ch7_metrics(A,x,z,struct('point_mm',[-0.7,20.1]));
assert(abs(m.lateral_fwhm_mm-0.6)<5e-4);
assert(abs(m.axial_fwhm_mm-0.4)<5e-4);
lecture_figure([1350 620]); layout=tiledlayout(1,2,'TileSpacing','loose');
[~,ix]=min(abs(x*1e3-m.peak_x_mm)); [~,iz]=min(abs(z*1e3-m.peak_z_mm));
profiles={A(iz,:),A(:,ix).'}; axes_mm={x*1e3,z*1e3};
names={'横向 x（mm）','深度 z（mm）'};
widths=[m.lateral_fwhm_mm,m.axial_fwhm_mm];
for k=1:2
    nexttile; plot(axes_mm{k},profiles{k},'LineWidth',1.8); hold on;
    yline(0.5,'--','半幅：−6.02 dB'); yline(0.1,':','幅度 0.1：−20 dB');
    grid on; ylim([0 1.1]); xlabel(names{k}); ylabel('局部峰值归一化包络');
    title(sprintf('测得半幅宽度 %.4f mm',widths(k)));
end
title(layout,'已知高斯标量图：横向与轴向切片都经过同一局部峰值');
report.gaussian_widths_mm=widths;

%% 2. Same underlying narrow response, different output sampling.
sigma=0.12/(2*sqrt(2*log(2)));
fine=-1:0.001:1; curve=exp(-0.5*(fine/sigma).^2);
grids={(-3:3)*0.298,(-3:3)*0.298+0.149,-0.9:0.025:0.9};
titles={'粗网格：命中峰值','粗网格：错开半格','密集网格：Δx = 0.025 mm'};
lecture_figure([1550 620]); layout=tiledlayout(1,3,'TileSpacing','loose');
peaks=zeros(1,3);
for k=1:3
    nexttile; plot(fine,curve,'k-','LineWidth',1.4); hold on;
    values=exp(-0.5*(grids{k}/sigma).^2); peaks(k)=max(values);
    stem(grids{k},values,'filled','LineWidth',1.5);
    yline(0.5,':'); grid on; xlim([-0.65 0.65]); ylim([0 1.08]);
    xlabel('横向位置（mm）'); ylabel('同一连续响应的幅度'); title(titles{k});
end
title(layout,'同一 0.12 mm 高斯半幅响应；加密网格没有新增 RF 采集');
assert(peaks(2)<0.02 && peaks(1)==1 && peaks(3)>0.999);
report.sampled_peak_values=peaks;

%% 3. Known synthetic labels, explicit physical ROI coordinates.
x=(-3:0.025:3)*1e-3; z=(17:0.025:23)*1e-3;
[X,Z]=meshgrid(x*1e3,z*1e3);
image=sqrt(randn(size(X)).^2+randn(size(X)).^2);
image(X.^2+(Z-20).^2<0.9^2)=0.4*image(X.^2+(Z-20).^2<0.9^2);
target=[-0.6 0.6 19.4 20.6]; background=[1.2 2.4 19.4 20.6];
stat=benchmark_ch7_contrast(image,x,z,target,background);
[a,~,p,q]=roi_values(image,x,z,target,background);
assert(abs(1-sum(min(p,q))-stat.gCNR)<1e-12);
lecture_figure([1350 650]); layout=tiledlayout(1,2,'TileSpacing','loose');
nexttile; show_synthetic(image,x,z,target,background);
title('已知合成分区：固定目标与同深度背景 ROI');
nexttile; bar([p(:),q(:)],1); grid on;
xlabel('两 ROI 联合秩分箱编号'); ylabel('每箱的概率质量');
legend('目标 ROI','背景 ROI','Location','best');
title(sprintf('gCNR = 1 − Σ min(P,Q) = %.3f',stat.gCNR));
title(layout,'指定随机标量图，不是 TheGB、声学仿真或真实病灶标注');
report.synthetic_roi_stat=stat;

%% 4. Invertible scalar maps preserve rank information; saturation does not.
mapped={image,image.^0.2,log(image),ones(size(image))};
names={'原始幅度','幂变换','对数变换','完全饱和'};
cnr=zeros(1,4); gc=zeros(1,4);
for k=1:4
    s=benchmark_ch7_contrast(mapped{k},x,z,target,background);
    cnr(k)=s.CNR; gc(k)=s.gCNR;
end
assert(max(abs(gc(1:3)-gc(1)))<1e-12 && gc(4)==0);
lecture_figure([1400 620]); layout=tiledlayout(1,2,'TileSpacing','loose');
nexttile; bar(cnr); xticks(1:4); xticklabels(names); grid on;
ylabel('指定标量域上的 CNR'); title('同一组信息，CNR 会随非线性尺度变化');
nexttile; bar(gc); xticks(1:4); xticklabels(names); grid on; ylim([0 1]);
ylabel('本项目秩分箱 gCNR 估计'); title('前三种保留顺序；完全饱和丢失信息');
title(layout,'相同 ROI、相同像素；对数后不能再把 CR 当作包络 CR');
report.transform_CNR=cnr; report.transform_gCNR=gc;

%% 5. Rearranging values changes spatial appearance, not ROI marginals.
ordered=image; shuffled=image;
for box={target,background}
    ix=find(x*1e3>=box{1}(1) & x*1e3<=box{1}(2));
    iz=find(z*1e3>=box{1}(3) & z*1e3<=box{1}(4));
    block=image(iz,ix); values=sort(block(:));
    ordered(iz,ix)=reshape(values,size(block));
    shuffled(iz,ix)=reshape(values(randperm(numel(values))),size(block));
end
s1=benchmark_ch7_contrast(ordered,x,z,target,background);
s2=benchmark_ch7_contrast(shuffled,x,z,target,background);
assert(abs(s1.gCNR-s2.gCNR)<1e-12 && abs(s1.CNR-s2.CNR)<1e-12);
lecture_figure([1350 650]); layout=tiledlayout(1,2,'TileSpacing','loose');
nexttile; show_synthetic(ordered,x,z,target,background);
title(sprintf('ROI 内按值排序：gCNR = %.3f',s1.gCNR));
nexttile; show_synthetic(shuffled,x,z,target,background);
title(sprintf('相同值随机换位：gCNR = %.3f',s2.gCNR));
title(layout,'边际分布完全相同，空间排列不同；gCNR 不描述纹理位置与边缘形状');
report.rearranged_gCNR=[s1.gCNR,s2.gCNR];

%% 6. CV and mean/std are reciprocal; correlation is not amplitude fidelity.
reference=reshape(a(1:floor(sqrt(numel(a)))^2), ...
    floor(sqrt(numel(a))),floor(sqrt(numel(a))));
permuted=reshape(reference(randperm(numel(reference))),size(reference));
variants={reference,0.1*reference,permuted}; names={'参考','乘 0.1','换位'};
xx=(0:size(reference,2)-1)*1e-3; zz=(0:size(reference,1)-1)*1e-3;
box=[-0.5,numel(xx)-0.5,-0.5,numel(zz)-0.5]; stats=zeros(3,3);
for k=1:3
    st=benchmark_ch7_metrics(variants{k},xx,zz, ...
        struct('speckle_roi_mm',box,'reference',reference));
    stats(k,:)=[st.speckle_cv,st.speckle_snr,st.corr_with_das];
end
assert(max(abs(stats(:,1).*stats(:,2)-1))<1e-12);
assert(abs(stats(2,3)-1)<1e-12 && max(abs(stats(:,1)-stats(1,1)))<1e-12);
lecture_figure([1500 600]); layout=tiledlayout(1,3,'TileSpacing','loose');
ys={'CV = 标准差 / 均值','均值 / 标准差','与参考数组的相关系数'};
for k=1:3
    nexttile; bar(stats(:,k)); xticks(1:3); xticklabels(names); grid on;
    ylabel(ys{k}); if k==3,ylim([-1 1]);end
end
title(layout,'相同 CV 不保证纹理相同；相关系数为 1 也不保证幅度相同');
report.descriptive_stats=stats;

%% 7. Finite independent samples from ONE population need not estimate zero.
side=[5 10 20 40]; values=zeros(20,numel(side));
for k=1:numel(side)
    n=side(k); xx=(0:n-1)*1e-3; zz=(0:2*n-1)*1e-3;
    for trial=1:size(values,1)
        v=sqrt(randn(2*n,n).^2+randn(2*n,n).^2);
        % Half-pixel edges include every center despite m->mm rounding.
        st=benchmark_ch7_contrast(v,xx,zz, ...
            [-0.5 n-0.5 -0.5 n-0.5],[-0.5 n-0.5 n-0.5 2*n-0.5]);
        values(trial,k)=st.gCNR;
    end
end
lecture_figure([1200 650]);
for k=1:numel(side)
    scatter(repmat(k,size(values,1),1),values(:,k),30,'filled'); hold on;
end
plot(1:numel(side),median(values,1),'k-o','LineWidth',1.8);
yline(0,'--','总体分布相同：理论 gCNR = 0'); grid on;
xticks(1:numel(side)); xticklabels(string(side.^2));
xlabel('每个 ROI 的独立合成样本数'); ylabel('有限样本 gCNR 估计');
title('同一分布，20 次独立抽样：有限样本仍可能给出非零估计');
report.finite_sample_medians=median(values,1);
report.finite_sample_counts=side.^2;

fprintf('Chapter 7 concepts PASS: 7 figures, rng(7,twister), no UFF.\n');
fprintf('Gaussian widths [lateral axial] mm: %s.\n',mat2str(widths,9));
fprintf('Same-curve sampled peaks: %s.\n',mat2str(peaks,9));
fprintf('CNR under scalar transforms: %s.\n',mat2str(cnr,9));
fprintf('gCNR under scalar transforms: %s.\n',mat2str(gc,9));
fprintf('Same-marginal reordered gCNR: %s.\n',mat2str(report.rearranged_gCNR,9));
fprintf('Finite sample counts / median estimates: %s / %s.\n', ...
    mat2str(side.^2),mat2str(report.finite_sample_medians,9));
end

function lecture_figure(sz)
figure('Color','w','Position',[80 80 sz], ...
    'DefaultAxesFontName','Microsoft YaHei','DefaultTextFontName','Microsoft YaHei');
end

function show_synthetic(image,x,z,target,background)
imagesc(x*1e3,z*1e3,20*log10(image/max(image(:))+eps));
axis image; colormap(gca,gray); caxis([-45 0]); colorbar;
xlabel('横向 x（mm）'); ylabel('深度 z（mm）'); hold on;
boxes={target,background}; colors=[0 0.5 0.55;0.85 0.35 0.1];
names={'目标 ROI','背景 ROI'};
for k=1:2
    r=boxes{k}; rectangle('Position',[r(1),r(3),r(2)-r(1),r(4)-r(3)], ...
        'EdgeColor',colors(k,:),'LineWidth',1.8);
    text(r(1),r(3)-0.1,names{k},'Color',colors(k,:), ...
        'BackgroundColor','w','FontSize',10);
end
end

function [a,b,p,q]=roi_values(image,x,z,target,background)
boxes={target,background}; values=cell(1,2);
for k=1:2
    r=boxes{k}; block=image(z*1e3>=r(3)&z*1e3<=r(4),x*1e3>=r(1)&x*1e3<=r(2));
    values{k}=block(:);
end
a=values{1}; b=values{2}; pooled=sort([a;b]); n=numel(pooled);
nb=min(32,max(4,floor(sqrt(min(numel(a),numel(b))))));
idx=max(1,min(n-1,round((1:nb-1)*n/nb)));
edges=[-inf,unique(((pooled(idx)+pooled(idx+1))/2).'),inf];
p=histcounts(a,edges)/numel(a); q=histcounts(b,edges)/numel(b);
end
