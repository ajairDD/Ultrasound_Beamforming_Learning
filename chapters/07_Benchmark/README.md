# 第 7 章：统一 Benchmark——从“更好看”转向可验证的性能

**状态：第 7 章教学与 TheGB 实际 Benchmark 已完成（2026-11-13）。** 两个 track 的基础 DAS 复数一致性及合成 gCNR 测试通过。**没有可靠的 lesion/background ROI，因此真实数据 CR/CNR/gCNR 尚未测量；不作临床优越性结论。**

本章不增加新的 beamformer，核心问题是：在相同的声学/采样条件下，哪种方法针对哪种成像任务真正有收益，付出什么代价？

## 一、为什么不能给所有算法简单排名？

| 算法 | 输出性质 | 可能收益 | 主要代价 |
|---|---|---|---|
| DAS | 延时相干求和幅度 | 可靠基线 | 旁瓣和杂波 |
| CF / GCF | DAS × coherence weight | 强调高相干结构 | speckle 被改变 |
| MVDR | covariance-driven receive weights | 横向响应收窄 | 目标自抑制 / 失配 |
| fDMAS | real RF 非线性通道对 + 2f0 频带 | 某些旁瓣/背景抑制 | 频谱/幅度/speckle 改变 |
| SLSC | **线性 coherence image** | 反映短-lag 一致性 | **不是 RF amplitude B-mode** |
| NSI | 零均值接收孔径、DC offset 和 envelope subtraction | 极窄有效横向响应 | 可能严重损伤组织信号 |

一个错误的“统一比较”是把 conventional FI scanline 上的 DAS FWHM 与密集 RTB-MVDR / RTB-NSI 直接混排。那同时改变了发射的使用方式和横向输出网格，不是单一算法效果。

另一个错误是把 SLSC 的 coherence brightness 当作 DAS 的 echo amplitude。

因此本章划分两个**组内可比**的实验，组与组之间不排名。

## 二、Track A：Conventional FI 比较

同一份真实聚焦 FI 数据、同样的 Tx/Rx delay、相同动态 Rx F# 和全部聚焦扫描线：

~~~text
DAS
CF
GCF(M0=1)
MVDR
fDMAS
SLSC
~~~

默认采用 TheGB 点目标附近 z=16~24 mm。除各算法固有必要操作外，输出 x/z 网格一致。fDMAS 必须在约 2f0 做带通，因此默认 z grid 由实际 wavelength 取约 lambda/16，确保 Nyquist 安全；不为追求低运行时间而使用会让 fDMAS 混叠的深度采样。

六个核心的**内部 complex DAS**均要求与 Chapter 1 的同网格 FI-DAS 对齐；max-peak scaled error 阈值为 1e-10。失败则停止 Benchmark。

**SLSC 输出类型特殊**：仅对其 linear coherence 图作描述；不拿它的“亮点宽度”与其他算法 RF-envelope FWHM 做物理横向分辨率排名。

## 三、Track B：密集 RTB 比较

TheGB 的已知点目标，所有算法共享：

~~~text
x -2.5 ~ +1.5 mm, 161 pixels, dx 0.025 mm
z 18.5 ~ 22.5 mm, 161 pixels, dz 0.025 mm
blended RTB Tx delay; Tukey25; Tx F#2; Rx F#1.7
same Tx coherent compounding, all focused Tx
~~~

方法：

~~~text
RTB-DAS
RTB-MVDR
RTB-NSI, DC offset = 0.2
RTB-NSI, DC offset = 0.8
~~~

首先核对 MVDR core 与 NSI core 内部产生的**复数 RTB-DAS 是否相同**，max-peak scaled error 需小于 1e-10。

NSI 的两个 DC offset 不需要两次 RF beamforming：已知 complex DAS D 与 zero-mean Z，可精确重组：

$$
E_{\rm NSI}(c)=\frac{|Z+cD|+|-Z+cD|}{2}-|Z|.
$$

代码共用一份 D、Z，再生成两幅 NSI 图；不能把第二个 c 视为独立的 full-core runtime。

## 四、四类指标

| 维度 | 指标 | 使用限制 |
|---|---|---|
| 点目标响应 | axial/lateral -6 dB FWHM、lateral -20 dB width | 同一 Tx/Rx 条件；少于约 3 pixels 的主瓣受采样影响明显；FWHM 不是两点分辨能力 |
| 低回声目标可检测性 | CR、CNR、gCNR | 必须有已确认 lesion / background ROI，不能自动选“最黑的地方” |
| 散斑变化 | ROI CV、ROI 与 DAS 的相关系数 | 只描述统计和相似性；未验证 homogeneous ROI 时不叫真实 speckle fidelity |
| 运行成本 | 全核心 tic/toc 时间 | 包含 UFF 读取、解析 RF、内部 DAS 等；不是纯数学 kernel 或生产 GPU/FPGA latency |

### 为什么特别强调 gCNR？

传统 CNR 在非线性成像和动态范围变化时可能虚高。gCNR 衡量目标与背景概率分布的重叠：

$$
\boxed{\mathrm{gCNR}=1-\int\min(p_{\rm target},p_{\rm background})\,dv.}
$$

gCNR=0 表示两组分布完全重合；gCNR=1 表示没有重叠。它能比较任意定义明确的 scalar image（包括 SLSC），但有限 ROI 与 histogram binning 仍有误差。代码使用从两个 ROI 联合数据构建的等数量 rank/quantile bins，而不是未经说明的固定等宽直方图。

**默认不预设 lesion/background ROI，因此 CR/CNR/gCNR 不会被虚构输出。** 若在有标注的 hypoechoic phantom 上确认两个物理 ROI，可再启用。

参考：Rodriguez-Molares et al., IEEE TUFFC 2020, DOI https://doi.org/10.1109/TUFFC.2019.2956855 ；Hyun et al., 2023, https://pmc.ncbi.nlm.nih.gov/articles/PMC10481948/ 。

## 五、一次性实验与输出

~~~matlab
addpath(genpath('D:/你的USTB路径'));
cd matlab/07_Benchmark
run_chapter7_benchmark
~~~

默认运行两组。如果希望快速先跑 FI：

~~~matlab
benchmark_mode='fi';
run_chapter7_benchmark
~~~

只跑密集 RTB：

~~~matlab
benchmark_mode='rtb';
run_chapter7_benchmark
~~~

结果写入本地：

~~~text
output/benchmark/ch07/
  FI_metrics.csv
  FI_images.png
  FI_configuration.mat
  RTB_metrics.csv
  RTB_images.png
  RTB_configuration.mat
  FI_contrast.csv      (仅提供已确认 ROI 时产生)
~~~

每个表中的 NaN 代表没有合理的物理定义/没有完成测量，不是“算法表现为零”。

要使用已确认的 hypoechoic phantom ROI，可更换 FI UFF 和深度，并显式设置两行 lesion/background ROI，单位 mm。不要凭本章示意或图像观感猜测 ROI。

## 六、前六章已有的结论与本章验收标准

此前实验支持以下**定性观察**，但不是本章新 benchmark 的已跑数据：

- CF/GCF：相干性加权会削弱背景 speckle，M0 变大时恢复更多散射响应；
- MVDR：密集 RTB 点目标显著收窄；真实 carotid 整体改善有限；
- fDMAS：局部点响应抑制，但 speckle 更碎；
- SLSC：短 lag 相关高，图像与 DAS 的含义不同；
- NSI：点目标变窄，但 c=0.2 在体模与两组 carotid 大范围压低组织；c=0.8 恢复部分组织但仍有纹理损伤。

**最重要的研究原则**：

> 真正的成像改进应在同一任务、同一数据和明确 ROI 下表现为相关指标的改善，并且说明分辨率、contrast、speckle 与计算复杂度的取舍。仅仅“更黑”或“主瓣更尖”，不能作为结论。

本章已经收到用户本地 MATLAB 真实运行的 Figure、完整控制台与两组统计表；下述实测结果已写入教程。项目级教学对照完成，但缺少带标注的低回声 phantom ROI，因此不能声称已经完成客观病灶检出性能的全面评测。


---

## 七、TheGB 实测统一 Benchmark（2026-11-13）

本节数据由用户在本地 MATLAB 运行 `run_chapter7_benchmark` 提供的 **Figure 1/2 和完整 Console** 得到。图像保存路径为本地 `output/benchmark/ch07`；仓库只记录日志中的确切数值与分析，不伪造 CSV 或数据文件。

### 1. 共同基线与自检

- gCNR 小型合成用例：**PASS**（完全相同两组分布 0，完全分离两组分布 1）。
- FI 的 CF、GCF、MVDR、fDMAS、SLSC 内部 complex DAS 相对第 1 章的 max-peak scaled error 均为 **6.147×10⁻¹⁸**。
- RTB-MVDR 和 RTB-NSI 两个独立 core 内部的 complex RTB-DAS 误差为 **0**。
- 以上证明**各轨道内部的基础 DAS 实现及输出网格一致**，不证明每个自适应算法的独立论文数值等价性。

### 2. Track A：Conventional FI

统一深度 `z=16–24 mm`，`n_z=434`；真实横向扫描线间距由表格推得约 **0.298 mm**。

| 方法 | 横向 FWHM (mm) | FWHM / 扫描线 | 轴向 FWHM (mm) | 横向 -20 dB (mm) | 点目标局部峰值 vs DAS (dB) | core 耗时 (s) |
|---|---:|---:|---:|---:|---:|---:|
| DAS | 0.71147 | 2.3876 | 0.44182 | 1.14570 | 0 | 23.455 |
| CF | 0.41672 | 1.3985 | 0.43796 | 0.97791 | -0.18643 | 24.287 |
| GCF (M0=1) | 0.62156 | 2.0859 | 0.43953 | 1.13540 | -0.15247 | 23.345 |
| MVDR | 0.30669 | 1.0292 | 0.48558 | 0.55205 | -2.3924 | 41.070 |
| fDMAS | 0.71965 | 2.4151 | 0.62134 | 1.10210 | 不可同幅度比较 | 21.985 |
| SLSC | 不适用 | 不适用 | 不适用 | 不适用 | 不适用 | 24.439 |

**解释**：

- CF / MVDR 在 FI 数据上有很窄的表观横向响应，但这组 FWHM 都不足 3 条 scanline，尤其 MVDR 只有约 1 条：**受采样限制，不能据此宣称物理分辨率提高数倍**。
- GCF (M0=1) 相比 CF 保留更多散斑与横向响应，符合其放宽接受的 aperture spatial-frequency band 的机制。
- fDMAS 在这组数据的横向 FWHM 与 DAS 很接近（0.720 vs 0.711 mm），轴向响应甚至更宽（0.621 vs 0.442 mm）。fDMAS 的二倍频 bandpass 使输出谱定义不同，不宜据此单独推断算法优劣。
- SLSC 输出 **linear coherence**，与 RF envelope 振幅定义不同，不参加幅度 FWHM 排名。

一个事先未验证为 homogeneous 的 speckle ROI `[-12,-8,18,22] mm`，样本数 **2808**，得到：

| 方法 | CV | SNR = mean/std | envelope 与 DAS 相关 |
|---|---:|---:|---:|
| DAS | 0.51056 | 1.9586 | 1 |
| CF | 1.1738 | 0.85196 | 0.89873 |
| GCF | 0.70722 | 1.4140 | 0.92875 |
| MVDR | 0.49909 | 2.0036 | 0.82285 |
| fDMAS | 0.8038 | 1.2441 | 0.79296 |
| SLSC | 0.19771 | 5.0579 | 0.52009 |

**尤其注意**：SLSC 的 `SNR=5.06` 只是其归一化 coherence image 的 mean/std，**不是 RF 回波 SNR 提升到 5.06**，更不能把它判为 speckle 成像质量冠军。该 ROI 没有独立同质性标注，DAS 相关也只说明相似性。

### 3. Track B：dense RTB 同几何点目标

二维网格为 `x=-2.5~1.5 mm` 和 `z=18.5~22.5 mm`，`161×161`，`dx=dz=0.025 mm`。

| 方法 | 横向 FWHM (mm) | FWHM / pixel | 轴向 FWHM (mm) | 横向 -20 dB (mm) | 点峰值 vs DAS (dB) |
|---|---:|---:|---:|---:|---:|
| RTB-DAS | 0.70632 | 28.253 | 0.42305 | 1.14820 | 0 |
| RTB-MVDR | 0.12382 | 4.953 | 0.40714 | 0.46166 | -2.8928 |
| RTB-NSI (c=0.2) | 0.16089 | 6.4358 | 0.38542 | 0.56294 | -2.5358 |
| RTB-NSI (c=0.8) | 0.37254 | 14.902 | 0.42281 | 0.80151 | -0.68566 |

相对 0.70632 mm RTB-DAS 主瓣：MVDR 横向 FWHM 缩小约 **82.5%**，NSI c=0.2 约 **77.2%**，NSI c=0.8 约 **47.3%**。本次 lateral sample spacing 足够密，三种自适应响应的 FWHM 均跨越 4 个以上 pixels，明显减少 conventional FI 欠采样问题。

但是，**这些只是单一 TheGB 点目标的空间响应测量，不是两目标 resolvability、临床对比度或 speckle fidelity 证明**。结合第 3、6 章的 carotid 验证，MVDR 的人体 B-mode 增益有限；NSI c=0.2 导致严重组织抑制，c=0.8 仍引起显著纹理变化。

**实际整条 core 计时（单次运行，非 kernel-only）：**

- RTB-MVDR core（内部含 DAS）：**135.93 s**；
- RTB-NSI core（内部含 DAS/ZM）：**23.40 s**；
- **独立 RTB-DAS 没有在本次 Track B 单独计时**。原版报告将 RTB-NSI 的 23.404 s 同时写在 RTB-DAS 行，会误导为独立 DAS 运行时间；代码现已修正该行耗时为 `NaN`。
- c=0.8 使用已有 `D,Z` 复数结果代数重组，没有第二次 RF beamforming，独立整条 core runtime 记为 `NaN`。

**不要将 135.93/23.40 的比值解读为同硬件上的纯 MVDR/NSI kernel 性能比**：两者的全 core 数据路径、缓存/读取等开销并不完全独立，且只有一次计时。

### 4. 尚未测量的部分

**本次没有已确认的低回声 lesion/background ROI，因此 CR、CNR、gCNR 不参与任何对比，`FI_contrast.csv` 不会生成。**

这不是运行失败，而是遵守了数据有效性边界。如果将来为了评估临床/目标可检测性而继续研究，应优先使用带独立标注的 hypoechoic phantom，固定两个 ROI 后再比较。**但这不是结束当前“经典波束合成学习”项目的阻碍。**

### 5. 最终可支持的结论

1. **方法正确性层面**：两组共同 DAS 复数基线一致，实验具有可比的声学/网格条件。
2. **分辨率层面**：MVDR、NSI 在密集 RTB 点目标上能显著缩窄 lateral response，伴随峰值损失；CF 的 conventional FI 窄主瓣受 scanline sampling 影响更大。
3. **组织层面**：CF/NSI 在已有结果中会明显改变正常组织散斑；MVDR 在人体的整体 B-mode 获益不像点目标结果那样明显。
4. **应用层面**：没有跨方法普适冠军；必须根据真实任务分辨 resolution gain、contrast detectability、speckle distortion 和计算成本。
5. **实验边界**：上述结论是 TheGB 教学 benchmark + 前几章真实 carotid 的综合判断，不包含带 ROI 的客观 lesion detection/临床优越性验证。

**第 7 章的教学和现有数据 Benchmark 已完成。**

后续同一 RTB 几何下 **DAS、CF、GCF、MVDR、fDMAS、SLSC、NSI 七方法一次性成像及定性比较**，另见 [第 8 章](../08_RTB_Comparison/README.md)。两章网格和实验目的不同，不将各自的点目标量化数据直接混用。
