function report = demo_rtb_method_building_blocks()
%DEMO_RTB_METHOD_BUILDING_BLOCKS Seven algebra/array lessons, no UFF.
% These examples explain operators and order; they are not acoustic PSFs.
rng(8,'twister'); report=struct();

%% 1. CF is evaluated inside each Tx, before complex Tx compounding.
S=[ones(4,1),[1;-1;1;-1]]; D=sum(S,1);
cf=abs(D).^2./(4*sum(abs(S).^2,1));
per_tx=mean(cf.*D); averaged=mean(S,2);
late_cf=abs(sum(averaged))^2/(4*sum(abs(averaged).^2));
late_output=late_cf*sum(averaged);
assert(per_tx==2 && late_output==1);
lecture_figure([1300 620]); layout=tiledlayout(1,2,'TileSpacing','loose');
nexttile; bar(S); grid on; xlabel('有效 Rx 通道编号'); ylabel('已对齐复数值（本例为实数）');
legend('Tx 1','Tx 2','Location','best'); title('同一组两次 Tx 的输入');
nexttile; bar([per_tx late_output]); grid on; xticks(1:2);
xticklabels({'逐 Tx 算 CF，再合成','先合通道，再算 CF'}); ylabel('输出幅度');
title('相同输入，改变次序会得到不同结果');
title(layout,'本仓库 CF/GCF 在每次 Tx 的有效接收孔径内计算权重');
report.CF_order_outputs=[per_tx late_output];

%% 2. CF is the zero spatial-bin case of GCF, by Parseval's identity.
M=16; n=(0:M-1).';
signals=[ones(M,1),exp(1i*2*pi*n/M),exp(1i*pi*n), ...
    (randn(M,1)+1i*randn(M,1))/sqrt(2)];
weights=zeros(4,3); names={'同相','一阶相位斜坡','交替反相','指定随机孔径'};
lecture_figure([1450 650]); tiledlayout(1,2,'TileSpacing','loose');
nexttile; hold on;
for k=1:4
    s=signals(:,k); spectrum=fft(s); energy=abs(spectrum).^2;
    weights(k,1)=abs(sum(s))^2/(M*sum(abs(s).^2));
    weights(k,2)=energy(1)/sum(energy);
    weights(k,3)=sum(energy([1 2 M]))/sum(energy);
    plot(-M/2:M/2-1,fftshift(energy/sum(energy)),'-o','LineWidth',1.2);
end
assert(max(abs(weights(:,1)-weights(:,2)))<1e-12);
assert(abs(weights(2,1))<1e-12 && abs(weights(2,3)-1)<1e-12);
grid on; xlabel('接收孔径空间频率 bin'); ylabel('归一化能量'); legend(names,'Location','best');
title('对孔径通道做 FFT，不是沿 RF 时间轴做 FFT');
nexttile; bar(weights); xticks(1:4); xticklabels(names); grid on; ylim([0 1.08]);
ylabel('乘在该 Tx 的 DAS 复数和上的权重');
legend('CF','GCF：M0 = 0','GCF：M0 = 1','Location','best');
title('保留低频能量来求标量权重，不是直接滤掉通道');
report.CF_GCF_weights=weights;

%% 3. Analytic covariance model: distortionless gain plus interference cost.
M=12; n=(0:M-1).'; a=ones(M,1); ui=0.07;
b=exp(1i*2*pi*n*ui); R=eye(M)+50*(b*b');
wd=a/M; v=R\a; wm=v/(a'*v);
assert(abs(wm'*a-1)<1e-12 && abs(wm'*b)<abs(wd'*b));
u=linspace(-0.3,0.3,2401); steering=exp(1i*2*pi*n*u);
lecture_figure([1350 620]); layout=tiledlayout(1,2,'TileSpacing','loose');
nexttile; plot(u,20*log10(abs(wd'*steering)+eps),'--','LineWidth',1.5); hold on;
plot(u,20*log10(abs(wm'*steering)+eps),'LineWidth',1.8);
xline(0,':','目标方向'); xline(ui,':','模型干扰方向');
grid on; ylim([-60 5]); xlabel('归一化空间频率 u'); ylabel('方向响应（dB）');
legend('均匀权重','MVDR 权重','Location','best');
title('两种权重在目标方向的增益都为 1');
nexttile; bar([abs(wd'*a),abs(wm'*a);abs(wd'*b),abs(wm'*b)]);
xticks(1:2); xticklabels({'目标方向','模型干扰方向'}); grid on;
ylabel('响应幅度'); legend('均匀权重','MVDR 权重','Location','best');
title('最小输出方差约束改变其他方向响应');
title(layout,'解析协方差教学模型；不是完整子阵平滑 RTB，也不是实验 PSF');
report.MVDR_desired_gains=[abs(wd'*a),abs(wm'*a)];
report.MVDR_interference_gains=[abs(wd'*b),abs(wm'*b)];

%% 4. Signed square roots matter: identical RF gives |RF| pair products.
f0=5e6; fs=64*f0; N=2048; t=(0:N-1).'/fs;
g=exp(-0.5*((t-mean(t))/(4/f0)).^2);
rf=g.*cos(2*pi*f0*t); raw=[rf rf]; u=sign(raw).*sqrt(abs(raw));
pair=u(:,1).*u(:,2); fast=0.5*(sum(u,2).^2-sum(u.^2,2));
assert(max(abs(pair-fast))<1e-12 && max(abs(pair-abs(rf)))<1e-12);
f=(0:N-1).'*fs/N; folded=min(f,fs-f); edges=[1.5 1.75 2.5 2.75]*f0;
h=band_shape(folded,edges); filtered=real(ifft(fft(pair).*h));
lecture_figure([1400 680]); layout=tiledlayout(1,2,'TileSpacing','loose');
nexttile; plot(t*1e6,rf,'LineWidth',1.2); hold on;
plot(t*1e6,pair,'LineWidth',1.4); grid on; xlim([2.5 3.9]);
xlabel('时间（μs）'); ylabel('教学模型幅度'); legend('同相实 RF','带符号开方后配对','Location','best');
title('相同两路时，配对结果为 |RF|，不是直接 RF²');
nexttile; keep=f<=4*f0; spec=abs(fft(pair)); spec=spec/max(spec);
filtered_spec=abs(fft(filtered))/max(abs(fft(pair)));
plot(f(keep)/f0,spec(keep),'LineWidth',1.5); hold on;
plot(f(keep)/f0,filtered_spec(keep),'LineWidth',1.5);
plot(f(keep)/f0,h(keep),'k:','LineWidth',1.3); grid on;
xlabel('频率 / f0'); ylabel('相同参考的幅度谱 / 滤波器增益');
legend('配对后','带通后','指定带通响应','Location','best');
title('去掉直流，保留约 2f0 的频带');
title(layout,'时间序列上的代数与滤波例子；实际 RTB 在 Tx 合并后的深度网格滤波');
report.fDMAS_pair_identity_error=max(abs(pair-fast));

%% 5. A normalized channel correlation is invariant to positive gain.
gate=cos(2*pi*(0:63).'/16)*ones(1,8);
gates={0.1*gate,10*gate,10*randn(size(gate))};
names={'低幅同相','高幅同相','高幅随机'}; sl=zeros(1,3); rms_sum=zeros(1,3);
for k=1:3
    v=gates{k}; numerator=sum(v(:,1:end-1).*v(:,2:end),1);
    den=sqrt(sum(v(:,1:end-1).^2,1).*sum(v(:,2:end).^2,1));
    sl(k)=mean(numerator./den); rms_sum(k)=sqrt(mean(sum(v,2).^2));
end
assert(abs(sl(1)-1)<1e-12 && abs(sl(2)-1)<1e-12);
lecture_figure([1350 620]); layout=tiledlayout(1,2,'TileSpacing','loose');
nexttile; bar(rms_sum); xticks(1:3); xticklabels(names); grid on;
ylabel('通道和的均方根幅度'); title('幅度随输入增益明显变化');
nexttile; bar(sl); xticks(1:3); xticklabels(names); grid on; ylim([-1 1.1]);
ylabel('lag = 1 的平均归一化相关'); title('同相但很弱的信号，也能有很高的相关值');
title(layout,'SLSC 的一阶近邻相关示例；不是回波幅度或 RF 信噪比');
report.lag1_correlations=sl; report.channel_sum_RMS=rms_sum;

%% 6. NSI reuses the same complex D,Z; DC offset is not a delay parameter.
S=[ones(4,1),[1;1;0.6;0.6],[1;1;-1;-1]];
D=sum(S,1); Z=[1 1 -1 -1]*S; offsets=[0.2 0.8]; values=abs(D).';
for dc=offsets
    E=0.5*(abs(Z+dc*D)+abs(-Z+dc*D))-abs(Z);
    assert(all(E>=-1e-12 & E<=dc*abs(D)+1e-12));
    values(:,end+1)=max(E,0).'/dc; %#ok<AGROW>
end
assert(max(abs(values(:,2)-[4;0;0]))<1e-12);
lecture_figure([1200 620]); bar(values); grid on;
xticks(1:3); xticklabels({'四路同相等幅','两半孔径幅度不同','两半孔径反相'});
ylabel('同一幅度参考下的输出'); legend('|D|','NSI：δ = 0.2','NSI：δ = 0.8','Location','best');
title({'固定 D、Z，仅改变 δ；三种输入不代表三种组织', ...
    '三路分别取包络再相减，结果除以 δ 后与 DAS 对照'});
report.NSI_four_channel_outputs=values;

%% 7. Explicit IQ convention: recover carrier phase at each query time.
f0=5e6; fs=20e6; t0=18e-6; t=t0+(0:80).'/fs;
tau=[20,20.1]*1e-6; tref=0;
q=exp(-0.5*((t-tau)/0.3e-6).^2).*exp(-1i*2*pi*f0*(tau-tref));
samples=complex(zeros(1,2));
for k=1:2, samples(k)=interp1(t,q(:,k),tau(k),'linear'); end
restored=samples.*exp(1i*2*pi*f0*(tau-tref));
assert(max(abs(restored-1))<1e-12);
lecture_figure([1400 620]); layout=tiledlayout(1,3,'TileSpacing','loose');
nexttile; plot(t*1e6,real(q),'LineWidth',1.5); grid on;
xlabel('设备时间（μs）'); ylabel('IQ 的 I 分量'); legend('Rx 1','Rx 2','Location','best');
title('同一目标，两路 IQ 在查询点符号相反');
nexttile; bar([angle(samples);angle(restored)].'/pi); grid on;
xticks(1:2); xticklabels({'Rx 1','Rx 2'}); ylabel('查询点相位 / π');
legend('仅插值 IQ','按约定恢复载频相位','Location','best');
title('相位因子使用各路的查询时刻');
nexttile; bar([abs(sum(samples)),abs(sum(restored))]); grid on;
xticks(1:2); xticklabels({'仅插值','恢复相位'}); ylabel('复数和的模');
title('相位处理改变相干和');
title(layout,'本例声明 IQ = 解析 RF × exp(−j2π f0(t−tref))；不是任意设备默认约定');
report.IQ_sum_magnitudes=[abs(sum(samples)),abs(sum(restored))];
report.IQ_restore_error=max(abs(restored-1));

fprintf('Chapter 8 concepts PASS: 7 figures, rng(8,twister), no UFF.\n');
fprintf('CF per-Tx / after-Tx weighting outputs: %s.\n',mat2str(report.CF_order_outputs));
fprintf('CF vs GCF M0=0 max error: %.6e.\n',max(abs(weights(:,1)-weights(:,2))));
fprintf('MVDR desired / interference gains: %s / %s.\n', ...
    mat2str(report.MVDR_desired_gains,9),mat2str(report.MVDR_interference_gains,9));
fprintf('fDMAS pair identity error: %.6e.\n',report.fDMAS_pair_identity_error);
fprintf('Lag1 correlations low/high/random: %s.\n',mat2str(sl,9));
fprintf('NSI [DAS delta0.2 delta0.8] rows: %s.\n',mat2str(values,9));
fprintf('IQ sums before/after phase restoration: %s; restore error %.6e.\n', ...
    mat2str(report.IQ_sum_magnitudes,9),report.IQ_restore_error);
end

function lecture_figure(sz)
figure('Color','w','Position',[80 80 sz], ...
    'DefaultAxesFontName','Microsoft YaHei','DefaultTextFontName','Microsoft YaHei');
end

function h=band_shape(f,e)
h=zeros(size(f)); h(f>=e(2)&f<=e(3))=1;
idx=f>e(1)&f<e(2); h(idx)=0.5*(1-cos(pi*(f(idx)-e(1))/(e(2)-e(1))));
idx=f>e(3)&f<e(4); h(idx)=0.5*(1+cos(pi*(f(idx)-e(3))/(e(4)-e(3))));
end
