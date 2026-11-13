# 第 7 章：统一 Benchmark——从“更好看”转向可验证的性能

**状态：方法学与 MATLAB 测试脚本已提交；尚待本地运行真实 UFF 以验收。**

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

当前只完成算法接入、合规性检查和数值小样例。缺少本地 MATLAB 真实运行结果，必须保持“进行中”；不得把代码提交视为科学 Benchmark 通过。
