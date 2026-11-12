function report=demo_nsi_building_blocks
%DEMO_NSI_BUILDING_BLOCKS Eight Chinese lecture figures, no UFF required.
% Algebra and narrowband array-factor examples only: no acoustic simulator,
% measured PSF, tissue ground truth, or clinical performance claim.
rng(6,'twister'); close all;
report=struct();

%% 1. Three apodizations, with an explicit odd-aperture convention.
dc=0.2; sizes=[8 7]; labels={'ZM：零均值','DC1：ZM + δ','DC2：−ZM + δ'};
figure('Color','w','Position',[40 40 1500 900]);
tiledlayout(2,3,'TileSpacing','loose','Padding','loose');
for row=1:2
    M=sizes(row); w=zero_mean_weights(M);
    W=[w,w+dc,-w+dc];
    assert(sum(w)==0);
    for k=1:3
        nexttile;
        stem(1:M,W(:,k),'filled','LineWidth',1.8);
        yline(0,':'); ylim([-1.35 1.55]); xticks(1:M); grid on;
        xlabel('当前有效阵元编号'); ylabel('接收权重');
        title(sprintf('M = %d，%s',M,labels{k}));
    end
end
sgtitle({'同一组通道使用三套权重；δ 加在权重上', ...
    '奇数孔径中间的 ZM 权重为零，DC1 / DC2 中该项为 δ'});
max_recombine_error=0;
for M=[1 2 3 7 8 31 32]
    w=zero_mean_weights(M);
    s=randn(M,20)+1i*randn(M,20); D=sum(s,1); Z=w.'*s;
    for dc=[0.2 0.8]
        direct=[(w+dc).'*s;(-w+dc).'*s];
        combined=[Z+dc*D;-Z+dc*D];
        error=max(abs(direct-combined),[],'all');
        max_recombine_error=max(max_recombine_error,error);
    end
end
assert(max_recombine_error<1e-12);
report.direct_apodization_max_error=max_recombine_error;
hand=[1 1 1;1 1 1;1 0.6 -1;1 0.6 -1];
hand_D=sum(hand,1); hand_Z=zero_mean_weights(4).'*hand;
hand_E=envelope_nsi(hand_D,hand_Z,0.2);
assert(max(abs(hand_E-[0.8 0 0]))<1e-12);
report.four_channel_examples=[hand_D;hand_Z;max(hand_E,0);max(hand_E,0)/0.2];

%% 2. An ideal aligned aperture cancels; gain imbalance leaves a residual.
M=8; w=zero_mean_weights(M);
S=[ones(M,1),[ones(M-1,1);1.4]];
D=sum(S,1); Z=w.'*S;
assert(isequal(Z,[0 -0.4]) || max(abs(Z-[0 -0.4]))<1e-12);
figure('Color','w','Position',[60 60 1400 680]);
tiledlayout(1,2,'TileSpacing','loose','Padding','loose');
nexttile;
bar(1:M,w.*S,'grouped'); grid on; yline(0,':');
xticks(1:M); xlabel('阵元编号'); ylabel('ZM 加权后的实数样本');
legend('同相、等幅','最后一条通道幅度增加','Location','best');
title('正负两半需要相互抵消');
nexttile;
bar([D;Z].'); grid on; yline(0,':');
xticks(1:2); xticklabels({'同相、等幅','末阵元增益失配'});
ylabel('加权求和结果'); legend('DAS 输出 D','ZM 输出 Z','Location','best');
title('DAS 都有响应，ZM 只在理想平衡时为零');
sgtitle('Null 是接收加权输出的零点，不是散射体消失');
report.ideal_and_imbalanced_Z=Z;

%% 3. Exact discrete array factor, not a measured broadband PSF.
M=64; u=linspace(-0.045,0.045,6001); dc=0.2;
[D,Z]=array_branches(M,u);
dc_mean=0.5*(abs(Z+dc*D)+abs(-Z+dc*D));
E=dc_mean-abs(Z);
figure('Color','w','Position',[80 80 1450 700]);
tiledlayout(1,2,'TileSpacing','loose','Padding','loose');
nexttile;
plot(u,abs(D)/M,'LineWidth',1.8); hold on;
plot(u,abs(Z)/M,'LineWidth',1.8); grid on;
xlabel('相邻阵元的归一化相位梯度 u'); ylabel('包络 / M');
legend('DAS 包络','ZM 包络','Location','best');
title('均匀权重有中心主瓣，ZM 有中心 Null');
nexttile;
plot(u,dc_mean/M,'LineWidth',1.8); hold on;
plot(u,abs(Z)/M,'LineWidth',1.8);
plot(u,E/M,'LineWidth',2,'Color',[0.15 0.5 0.2]); grid on; xlim([-0.01 0.01]);
xlabel('相邻阵元的归一化相位梯度 u'); ylabel('三条包络使用相同参考 M');
legend('两路 DC 包络平均','ZM 包络','NSI 残差 E','Location','best');
title('相近的包络相减，在中心附近留下残差');
sgtitle('64 阵元窄带阵列因子：s(n,u) = exp(j2πnu)，不是 TheGB 声场或 PSF');

%% 4. Nonnegative residual and the role of relative complex phase.
dc=0.2;
Dtest=randn(10000,1)+1i*randn(10000,1);
Ztest=randn(10000,1)+1i*randn(10000,1);
Etest=envelope_nsi(Dtest,Ztest,dc);
ceiling=dc*abs(Dtest);
assert(all(Etest>=-1e-12) && all(Etest<=ceiling+1e-12));
figure('Color','w','Position',[100 100 1450 700]);
tiledlayout(1,2,'TileSpacing','loose','Padding','loose');
nexttile;
scatter(ceiling(1:500),Etest(1:500),14,'filled'); hold on;
plot([0 max(ceiling)],[0 max(ceiling)],'k--','LineWidth',1.6);
grid on; xlabel('理论上界 δ|D|'); ylabel('NSI 包络 E');
title('一万个随机复数对均通过上下界检查');
legend('其中五百个样本','E = δ|D|','Location','best');
nexttile;
phase=linspace(0,pi,361);
magnitudes=[0 0.1 1]; colors=[0 0.45 0.74;0.85 0.32 0.1;0.15 0.5 0.2];
for kk=1:3
    magnitude=magnitudes(kk);
    value=envelope_nsi(ones(size(phase)),magnitude*exp(1i*phase),dc)/dc;
    plot(phase/pi,value,'LineWidth',1.8,'Color',colors(kk,:)); hold on;
end
grid on; ylim([-0.02 1.05]);
xlabel('Z 相对 D 的相位差 / π'); ylabel('E / (δ|D|)，其中 D = 1');
legend('|Z| = 0','|Z| = 0.1','|Z| = 1','Location','best');
title('一般复数数据：残差也取决于相对相位');
sgtitle('0 ≤ E ≤ δ|D|；不能把所有复数情形简化成实数幅度相减');
report.lower_bound_violation=max(0,-min(Etest));
report.upper_bound_violation=max(0,max(Etest-ceiling));

%% 5. Coherent Tx summation and envelope detection do not commute.
dc=0.2; Dtx=[1 -1]; Ztx=[0 0];
correct=envelope_nsi(mean(Dtx),mean(Ztx),dc);
changed=mean(envelope_nsi(Dtx,Ztx,dc));
assert(correct==0 && abs(changed-dc)<1e-12);
figure('Color','w','Position',[120 120 1350 650]);
tiledlayout(1,2,'TileSpacing','loose','Padding','loose');
nexttile;
stem(1:2,Dtx,'filled','LineWidth',2); yline(0,':');
ylim([-1.3 1.3]); xticks(1:2); xticklabels({'Tx 1','Tx 2'}); grid on;
ylabel('两次 Tx 的复数分量（本例为实数）');
title('D1 = 1，D2 = −1；两路 Z 均为零');
nexttile;
bar([correct changed]); grid on;
xticks(1:2); xticklabels({'先相干合成','先取包络'});
ylabel('NSI 包络 E'); title('相同的输入，两种次序给出不同结果');
sgtitle('两次 Tx 等权平均，δ = 0.2；这个代数例子不代表新的采集序列');
report.compound_then_envelope=correct;
report.envelope_then_average=changed;

%% 6. Offset effects on the same ideal array data, with one common gain.
M=64; u=linspace(-0.04,0.04,8001); [D,Z]=array_branches(M,u);
figure('Color','w','Position',[140 140 1350 700]);
plot(u,abs(D)/M,'k--','LineWidth',1.8); hold on;
widths=zeros(1,2); offsets=[0.2 0.8]; colors=[0.85 0.32 0.1;0 0.5 0.65];
for k=1:2
    response=envelope_nsi(D,Z,offsets(k))/(offsets(k)*M);
    plot(u,response,'LineWidth',1.8,'Color',colors(k,:));
    widths(k)=half_width(u,response);
end
grid on; xlim([-0.025 0.025]); ylim([0 1.05]);
xlabel('相邻阵元的归一化相位梯度 u');
ylabel('DAS 为 |D|/M；NSI 为 E/(δM)');
legend('DAS','δ = 0.2','δ = 0.8','Location','best');
title({'同一理想阵列模型，仅改变 δ，保留同一中心增益参考', ...
    '曲线宽度以 u 为单位，不是实验分辨率或两个目标的可分辨距离'});
assert(widths(1)<widths(2)); report.array_half_amplitude_widths=widths;

%% 7. Grid spacing and grid phase affect the observed narrow response.
M=64; dc=0.2; u=linspace(-0.012,0.012,4801);
[D,Z]=array_branches(M,u); response=envelope_nsi(D,Z,dc)/(dc*M);
coarse=(-3:3)*0.004; shifted=coarse+0.002;
figure('Color','w','Position',[160 160 1400 700]);
tiledlayout(1,2,'TileSpacing','loose','Padding','loose');
grids={coarse,shifted};
names={'稀疏网格恰好命中峰值','同样间距，网格错开半格'};
peaks=zeros(1,2);
for k=1:2
    nexttile;
    plot(u,response,'k-','LineWidth',1.6); hold on;
    [d,z]=array_branches(M,grids{k}); values=envelope_nsi(d,z,dc)/(dc*M);
    stem(grids{k},values,'filled','LineWidth',1.8);
    peaks(k)=max(values); grid on; ylim([0 1.08]); xlim([-0.012 0.012]);
    xlabel('归一化相位梯度 u'); ylabel('共同中心参考下的响应');
    legend('连续模型的密集计算','稀疏采样点','Location','best'); title(names{k});
end
sgtitle('同一响应，不同网格相位；连线插值不能补回未采到的峰值');
assert(peaks(2)<peaks(1)); report.coarse_grid_peak_values=peaks;

%% 8. Nonlinear suppression for a specified random-aperture algebra model.
M=64; S=(randn(M,4096)+1i*randn(M,4096))/sqrt(2);
D=sum(S,1); Z=zero_mean_weights(M).'*S;
offsets=[0.2 0.8]; medians=zeros(1,2);
figure('Color','w','Position',[180 180 1450 700]);
tiledlayout(1,2,'TileSpacing','loose','Padding','loose');
for k=1:2
    value=max(envelope_nsi(D,Z,offsets(k)),0)/offsets(k);
    ratio=value./abs(D); assert(all(ratio>=0 & ratio<=1+1e-12));
    medians(k)=median(ratio);
    nexttile(1);
    scatter(abs(D(1:250)),value(1:250),14,'filled'); hold on;
    nexttile(2);
    plot(sort(ratio),(1:numel(ratio))/numel(ratio),'LineWidth',1.8); hold on;
end
nexttile(1);
peak=max(abs(D)); plot([0 peak],[0 peak],'k--','LineWidth',1.5); grid on;
xlabel('DAS 包络 |D|'); ylabel('除以 δ 后的 NSI 包络');
legend('δ = 0.2','δ = 0.8','与 DAS 相等','Location','best');
title('随机孔径：多数样本并不保留全部 DAS 幅度');
nexttile(2);
grid on; xlim([0 1]); ylim([0 1]);
xlabel('幅度保留比 E/(δ|D|)'); ylabel('累计样本比例');
legend('δ = 0.2','δ = 0.8','Location','best');
title('保留比例描述抑制程度，不是质量评分');
sgtitle({'独立复高斯孔径向量的代数实验，固定随机种子 6', ...
    '没有模拟真实组织的空间相关结构，不用于预测人体图像的具体统计值'});
report.random_aperture_median_retention=medians;

fprintf('NSI concepts: 8 figures; rng(6,twister); no UFF or acoustic simulation.\n');
fprintf('Direct three-apodization / D,Z recombination max error: %.6e.\n',max_recombine_error);
fprintf('Four-channel examples [D;Z;E;E/delta]: %s.\n',mat2str(report.four_channel_examples,9));
fprintf('Ideal / gain-imbalanced Z: %s.\n',mat2str(report.ideal_and_imbalanced_Z));
fprintf('Lower / upper envelope bound violations: %.6e / %.6e.\n', ...
    report.lower_bound_violation,report.upper_bound_violation);
fprintf('Coherent-first / envelope-first example E: %.6f / %.6f.\n',correct,changed);
fprintf('Ideal array half-amplitude widths in u, delta 0.2/0.8: %s.\n',mat2str(widths,9));
fprintf('Coarse-grid peak values, centered/shifted: %s.\n',mat2str(peaks,9));
fprintf('Random-aperture median retention, delta 0.2/0.8: %s.\n',mat2str(medians,9));
fprintf('All algebra, bounds, ordering and sampling checks PASS.\n');
end

function w=zero_mean_weights(M)
h=floor(M/2); w=[ones(h,1);zeros(mod(M,2),1);-ones(h,1)];
end

function [D,Z]=array_branches(M,u)
n=((1:M).'-(M+1)/2);
S=exp(1i*2*pi*n*u); D=sum(S,1); Z=zero_mean_weights(M).'*S;
end

function E=envelope_nsi(D,Z,dc)
E=0.5*(abs(Z+dc*D)+abs(-Z+dc*D))-abs(Z);
end

function width=half_width(x,y)
[~,p]=max(y); left=find(y(1:p)<0.5,1,'last');
right=p-1+find(y(p:end)<0.5,1,'first');
assert(~isempty(left) && ~isempty(right));
xl=x(left)+(0.5-y(left))*diff(x(left:left+1))/diff(y(left:left+1));
xr=x(right-1)+(0.5-y(right-1))*diff(x(right-1:right))/diff(y(right-1:right));
width=xr-xl;
end
