function report = demo_slsc_building_blocks
%DEMO_SLSC_BUILDING_BLOCKS Eight deterministic, no-UFF teaching figures.
% These are algebra/statistics examples, not acoustic-field simulations.
% All visible labels are Chinese; RF/SLSC/lag and symbols retain their names.
% Run directly or use export_chapter5_figures('concepts').
rng(5,'twister');
close all;
report=struct();

%% 1. Spatial lag groups unordered physical pairs, excluding lag zero.
M=6; [j,i]=meshgrid(1:M);
lag_map=j-i; lag_map(lag_map<=0)=NaN;
figure('Color','w','Position',[40 40 1350 650]);
tiledlayout(1,2,'TileSpacing','loose','Padding','loose');
nexttile;
h=imagesc(lag_map); h.AlphaData=isfinite(lag_map);
set(gca,'Color',[0.92 0.94 0.96]); axis image;
colormap(gca,parula(5)); caxis([0.5 5.5]); colorbar;
xticks(1:M); yticks(1:M);
xlabel('阵元 j'); ylabel('阵元 i'); title('上三角：每一对只出现一次');
for a=1:M
    for b=a+1:M
        ink='k'; if b-a<=2, ink='w'; end
        text(b,a,sprintf('m=%d',b-a),'HorizontalAlignment','center', ...
            'Color',ink,'FontWeight','bold','FontSize',13);
    end
end
nexttile;
counts=arrayfun(@(m) nnz(lag_map==m),1:M-1);
bar(1:M-1,counts,0.65); grid on; xticks(1:M-1);
xlabel('空间 lag m（阵元间距数）'); ylabel('阵元对数量 M−m');
title('六个连续阵元：lag 越大，通道对越少');
assert(isequal(counts,5:-1:1) && sum(counts)==M*(M-1)/2);
sgtitle('先按阵元间隔分组，再在每个 lag 内平均');
report.pair_counts=counts;

%% 2. Normalized dot product: positive gain, negative sign, orthogonality.
v=[1;-1;1;-1]; w=[1;1;-1;-1];
B=[v,3*v,-v,w];
rho=(v.'*B)./sqrt(sum(v.^2)*sum(B.^2,1));
assert(max(abs(rho-[1 1 -1 0]))<1e-12);
figure('Color','w','Position',[60 60 1400 850]);
tiledlayout(2,2,'TileSpacing','loose','Padding','loose');
names={'正比例放大','整体反相','内积为零'};
for k=1:3
    nexttile;
    plot(1:4,v,'-o','LineWidth',1.8); hold on;
    plot(1:4,B(:,k+1),'-s','LineWidth',1.6);
    yline(0,':'); grid on; xticks(1:4);
    xlabel('窗口样本 n'); ylabel('有正负号的 RF');
    title(sprintf('%s：ρ = %.0f',names{k},rho(k+1)));
    legend('参考通道','另一通道','Location','best');
end
nexttile;
bar(rho); ylim([-1.2 1.2]); grid on; yline(0,':');
xticks(1:4); xticklabels({'自身','三倍幅度','反相','正交'});
ylabel('归一化内积 ρ'); title('幅度尺度消除，但正负相关仍有区别');
sgtitle('四个数就能算完：不减局部均值，不先取包络');
report.exact_correlations=rho;

%% 3. Axial window rows and fixed physical-channel columns.
z=(-32:32).'/16; M=12;
signal=cos(4*pi*z).*exp(-z.^2/1.5^2);
X=signal*ones(1,M)+0.35*randn(numel(z),M);
center=35; rows=center+(-4:4);
a=X(center,1:end-1); b=X(center,2:end);
single_rho=(a.*b)./abs(a.*b);
gate_rho=pair_rho(X(rows,1:end-1),X(rows,2:end));
assert(all(abs(single_rho)==1) && all(abs(gate_rho)<=1+1e-12));
figure('Color','w','Position',[80 80 1450 700]);
tiledlayout(1,2,'TileSpacing','loose','Padding','loose');
nexttile;
imagesc(1:M,z,X); set(gca,'YDir','reverse'); colorbar;
xlabel('同一组物理 Rx 阵元'); ylabel('相对深度 / λ');
title('延时后的 RF：行是重建深度，列是阵元');
hold on;
rectangle('Position',[0.5 z(rows(1)) M z(rows(end))-z(rows(1))], ...
    'EdgeColor',[0.95 0.4 0.05],'LineWidth',2.5);
yline(z(center),'--','当前像素深度','Color',[0.8 0.2 0.05]);
nexttile;
plot(1:M-1,single_rho,'o','LineWidth',1.5); hold on;
plot(1:M-1,gate_rho,'-s','LineWidth',1.7);
ylim([-1.15 1.15]); yline(0,':'); grid on;
xlabel('lag = 1 的阵元对序号'); ylabel('每一对的归一化内积');
legend('单个 RF 样本','九个深度点的窗口','Location','best');
title('两个非零标量只能给出 +1 或 −1');
sgtitle('窗口提供波形样本；窗内阵元索引固定，不随深度换列');
report.singleton_values=unique(single_rho);
report.example_gate_span_lambda=z(rows(end))-z(rows(1));

%% 4. Shared component plus independent noise: a controlled toy model.
K=4096; M=24; max_lag=12;
shared=randn(K,1); shared=shared-mean(shared); shared=shared/std(shared,1);
noise=randn(K,M); noise=noise-mean(noise,1);
noise=noise./std(noise,1,1);
datasets={shared*ones(1,M),shared*ones(1,M)+noise,noise};
expected=[1 0.5 0]; curves=zeros(3,max_lag);
figure('Color','w','Position',[100 100 1300 700]);
for k=1:3
    curves(k,:)=lag_curve(datasets{k},max_lag);
    plot(1:max_lag,curves(k,:),'-o','LineWidth',1.7); hold on;
end
grid on; ylim([-0.1 1.1]); xlim([1 max_lag]);
xlabel('空间 lag m（阵元间距数）'); ylabel('每个 lag 的平均归一化相关');
legend('纯共同分量','共同分量 + 等功率独立噪声','仅独立噪声', ...
    'Location','best');
title({'统计玩具模型：共同分量使通道相似，独立噪声降低相似程度', ...
    '共同分量也可能来自相干杂波；这不是组织来源判别器'});
assert(max(abs(curves(:)))<=1+1e-12);
assert(max(abs(mean(curves,2).'-expected))<0.04);
report.shared_noise_mean_correlations=mean(curves,2).';

%% 5. An explicitly chosen covariance model, not an acoustic prediction.
M=20; ell=6; max_lag=12; L=3;
C=exp(-abs((1:M).'-(1:M))/ell);
X=randn(4096,M)*chol(C);
measured=lag_curve(X,max_lag);
population=exp(-(1:max_lag)/ell);
assert(max(abs(measured-population))<0.05);
figure('Color','w','Position',[120 120 1400 700]);
tiledlayout(1,2,'TileSpacing','loose','Padding','loose');
nexttile;
imagesc(C); axis image; colorbar; caxis([0 1]);
xlabel('阵元 j'); ylabel('阵元 i'); title('人为指定的指数协方差矩阵');
nexttile;
bar(1:L,measured(1:L),0.65,'FaceColor',[0.95 0.55 0.2], ...
    'FaceAlpha',0.4); hold on;
plot(1:max_lag,population,'k--','LineWidth',1.5);
plot(1:max_lag,measured,'-o','LineWidth',1.8);
ylim([0 1]); grid on;
xlabel('空间 lag m（阵元间距数）'); ylabel('归一化相关');
legend('本例选取的前三个 lag','模型期望','有限样本估计','Location','best');
title(sprintf('前三项之和 = %.3f；平均值 = %.3f', ...
    sum(measured(1:L)),mean(measured(1:L))));
sgtitle('先画 R(m)，再决定累加到哪里；指数模型不代表真实组织必然如此');
report.covariance_model_max_error=max(abs(measured-population));

%% 6. Dynamic count alone can change the raw sum.
M=3:96; L=min(12,min(M-1,max(1,floor(0.15*M))));
r=0.8; raw=r*L; averaged=raw./L;
assert(max(abs(averaged-r))<1e-12);
figure('Color','w','Position',[140 140 1400 650]);
tiledlayout(1,2,'TileSpacing','loose','Padding','loose');
nexttile;
stairs(M,L,'LineWidth',2); grid on;
xlabel('当前有效 Rx 数 M'); ylabel('请求的最大 lag');
title('按 0.15M 取整，至少一项，最多十二项');
nexttile;
plot(M,raw,'LineWidth',2); hold on;
plot(M,averaged,'LineWidth',2); grid on;
xlabel('当前有效 Rx 数 M'); ylabel('相干性输出（无量纲）');
legend('短 lag 之和','短 lag 平均值','Location','best');
title('假设每一项始终为 0.8：只改变累加项数');
sgtitle('取平均去掉纯计数因子；若所选 R(m) 改变，平均值仍会改变');
report.dynamic_lags_for_M20_M40=[L(M==20),L(M==40)];

%% 7. Different lag supports can create an upward bend in an ROI mean.
max_lag=8; summary=nan(120,max_lag);
summary(1:60,1:3)=repmat(0.4-0.03*(1:3),60,1);
summary(61:120,:)=repmat(0.8-0.02*(1:max_lag),60,1);
available=mean(summary,1,'omitnan');
common=all(isfinite(summary),2);
fixed=mean(summary(common,:),1);
counts=sum(isfinite(summary),1);
assert(available(4)>available(3) && all(diff(fixed)<0));
figure('Color','w','Position',[160 160 1400 650]);
tiledlayout(1,2,'TileSpacing','loose','Padding','loose');
nexttile;
plot(1:max_lag,available,'-o','LineWidth',1.8); hold on;
plot(1:max_lag,fixed,'-s','LineWidth',1.8); grid on; ylim([0 1]);
xlabel('空间 lag m'); ylabel('ROI 中的平均相关');
legend('各 lag 使用所有可用像素','始终使用同一批像素','Location','best');
title('每组曲线均下降，混合均值却会回升');
nexttile;
bar(1:max_lag,counts,0.65); hold on;
yline(nnz(common),'--','共同有效像素数量'); grid on;
xlabel('空间 lag m'); ylabel('参与平均的像素数量');
title('较大 lag 改变了参与统计的像素集合');
sgtitle('人为构造的两组统计摘要：用于解释集合效应，不是真实 RF 测量');
report.support_bias_available_means=available;
report.support_bias_fixed_means=fixed;

%% 8. A longer axial window mixes a wider neighborhood.
N=513; M=24; edge=257;
shared=randn(N,1); noise=randn(N,M);
X=0.2*noise;
X(1:edge,:)=X(1:edge,:)+shared(1:edge)*ones(1,M);
X(edge+1:end,:)=noise(edge+1:end,:);
windows=[9 41]; rolling=nan(N,2);
for k=1:numel(windows)
    half=(windows(k)-1)/2;
    for n=1+half:N-half
        gate=X(n-half:n+half,:);
        rolling(n,k)=mean(pair_rho(gate(:,1:end-1),gate(:,2:end)));
    end
end
figure('Color','w','Position',[180 180 1300 680]);
plot(1:N,rolling(:,1),'LineWidth',1.1); hold on;
plot(1:N,rolling(:,2),'LineWidth',2);
xline(edge,'k--','模型分界'); grid on; ylim([-0.25 1.1]);
xlim(edge+[-90 90]); xlabel('合成深度样本序号');
ylabel('lag = 1 的平均相关');
legend('九点轴向窗口','四十一点轴向窗口','Location','best');
title({'窗口较长时统计更平稳，也会混入分界两侧的数据', ...
    '这是分段随机模型，不是声学 PSF 或真实分辨率测量'});
report.kernel_lengths=windows;

fprintf('SLSC concepts: 8 figures; rng(5,twister); no UFF or acoustic simulator.\n');
fprintf('Pair counts for M=6: %s.\n',mat2str(report.pair_counts));
fprintf('Exact normalized inner products: %s.\n',mat2str(rho));
fprintf('Shared/noisy/independent mean correlations: %s.\n', ...
    mat2str(report.shared_noise_mean_correlations,6));
fprintf('Covariance toy maximum sample-vs-model error: %.6g.\n', ...
    report.covariance_model_max_error);
fprintf('M=20/40 requested lag counts: %s.\n', ...
    mat2str(report.dynamic_lags_for_M20_M40));
fprintf('All deterministic algebra, bounds and support-bias checks PASS.\n');
end

function rho=pair_rho(A,B)
% Uncentered normalized dot product, matching the tutorial definition.
den=sqrt(sum(A.^2,1).*sum(B.^2,1));
rho=sum(A.*B,1)./den;
rho(den==0)=NaN;
end

function R=lag_curve(X,max_lag)
M=size(X,2); R=nan(1,max_lag);
for m=1:max_lag
    rho=pair_rho(X(:,1:M-m),X(:,1+m:M));
    R(m)=mean(rho,'omitnan');
end
end
