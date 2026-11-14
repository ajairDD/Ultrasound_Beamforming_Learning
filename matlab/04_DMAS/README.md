# Chapter 4 MATLAB：从 real RF 配对到 fDMAS 图像

先读[第四章教程](../../chapters/04_DMAS/README.md)的算法主线，再按“原理演示 → 真实数据 → 导图复现”运行。本目录保留一个 conventional FI 的 TheGB 实验；新增演示与诊断图用于看清同一个算法的各个阶段。

## 快速开始（全课程统一入口）

原理小实验不需要 USTB/UFF；真实 RF 实验需要 USTB 和 TheGB UFF。**建议先读[本章教学正文](../../chapters/04_DMAS/README.md)，再从仓库根目录运行以下命令。**

**第一步：无需外部数据的原理演示**

~~~matlab
addpath('matlab/04_DMAS');
demo_dmas_building_blocks
~~~

**第二步：真实 UFF 图像 / 数据检查**（先准备 USTB 与数据）

~~~matlab
addpath(genpath('D:/你的USTB路径'));
cd matlab/04_DMAS
filename = '../../data/L7_FI_TheGB.uff';
compare_fi_das_vs_fdmas
~~~

**提示：** fDMAS 结果涉及二倍频带和输出网格，先看本章采样说明再改变参数。 完整实验顺序、参数、输出与验证记录见下方说明；课件配图见[本章配图索引](../../chapters/04_DMAS/figures/README.md)。

---

## 1. 先运行无需数据的六组演示

~~~matlab
cd('D:/Ultrasound_Beamforming_Learning/matlab/04_DMAS');
demo_dmas_building_blocks
~~~

不需要 USTB、UFF 文件或 Signal Processing Toolbox。固定 rng(4)，使用实数 RF 小向量和合成脉冲；其中 f₀=5 MHz。六张图依次解释：

| 图 | 回答的问题 |
|---|---|
| 01 | 四通道的六个 pair 怎样贡献正负值？为什么整体反号仍得到相同 DMAS？ |
| 02 | 快速式是否等价？绝对齐次缩放和 2/(M−1) 约定是什么？ |
| 03 | 平方与 signed-sqrt 对正弦频谱的影响有何不同？ |
| 04 | 为什么先带通再取包络？未滤波 DMAS 的包络会怎样变化？ |
| 05 | 输出深度网格为什么必须承载约 2f₀ 频带？ |
| 06 | 残余通道相位误差怎样影响 DAS / fDMAS？ |

图 06 的 q 是 cycles/channel，不是 Hz 或声束角度。全部合成图是数值机制演示，不是测量声束图或已知组织的成像性能测试。

## 2. 运行一个真实 TheGB 二维实验

先把本机 USTB 加入路径，再显式设置参数，避免前一次脚本留下的 workspace 配置影响结果：

~~~matlab
addpath(genpath('D:/USTB'));  % 按本机位置调整
cd('D:/Ultrasound_Beamforming_Learning/matlab/04_DMAS');
filename = '../../data/L7_FI_TheGB.uff';
z_min = 5e-3; z_max = 45e-3;
n_z = [];                   % 自动选择约 lambda/16 的深度步长
receive_f_number = 1.7;
run_das_reference_check = true;
compare_fi_das_vs_fdmas
~~~

输出两张交互式 MATLAB 图：

- 完整 DAS / fDMAS B-mode，各自全图峰值为 0 dB，同为 60 dB 动态范围。
- 目标附近的 lateral profile 与同一条 scanline 的 DMAS 滤波前后频谱。剖面按各自局部目标峰值归一化，圆点 / 方点是实际采样位置。

脚本默认执行显式 pairs 与快速式的代数检查，以及对第一章 conventional FI-DAS 的独立**复数结果回归**。

快速目标区间：

~~~matlab
filename = '../../data/L7_FI_TheGB.uff';
z_min = 16e-3; z_max = 24e-3; n_z = [];
receive_f_number = 1.7;
run_das_reference_check = true;
compare_fi_das_vs_fdmas
~~~

缩短区间会改变有限长度 FFT / Hilbert 的边界。正式比较时，应使用足够宽的深度范围再裁剪显示；快速 ROI 结果不保证与完整重建的裁剪逐点相同。

## 3. 一键导出课件图片和原始日志

~~~matlab
export_chapter4_figures('concepts')  % 六张原理图；不需要 USTB
export_chapter4_figures('uff')       % 六张真实 UFF 图；需要 USTB 和 TheGB
% 或一次运行全部：
export_chapter4_figures('all')
~~~

图片保存在 [chapters/04_DMAS/figures](../../chapters/04_DMAS/figures/README.md)，PNG 导出为 150 dpi，英文坐标便于不同 MATLAB 字体环境复现；正文提供中文图解。

UFF 导图固定第 1 帧、5–45 mm、全部 128 条 focused scanlines、Rx F#=1.7、自动深度网格。它隔离教学脚本的 clearvars，恢复运行前工作目录与默认 Figure 可见性，并在结束时关闭导出的图窗。直接运行教学脚本可保留图窗进行操作。

六张 UFF 图包括原脚本的两张图，以及同一次重建的四张诊断图：

| 文件前缀 | 内容 |
|---|---|
| compare_fi_das_vs_fdmas_01 | 完整二维 B-mode |
| compare_fi_das_vs_fdmas_02 | 目标 lateral profile + 滤波前后频谱 |
| uff_dmas_diagnostics_01 | 目标附近二维显示放大，保留全图峰值参考 |
| uff_dmas_diagnostics_02 | 横向 / 轴向局部包络剖面与实际网格点 |
| uff_dmas_diagnostics_03 | DAS、raw DMAS、filtered output、实际 FFT mask |
| uff_dmas_diagnostics_04 | 真实有效接收通道数与 pair count 随位置的变化 |

每次导出会更新对应日志 matlab_concepts_results.txt、matlab_uff_results.txt 或 matlab_all_results.txt。日志记录的是实际计算输出，不是 AI 生成的数值。

## 4. 文件分工与数据路径

| 文件 | 用途 |
|---|---|
| [demo_dmas_building_blocks.m](demo_dmas_building_blocks.m) | 六组确定性原理实验，自带有数学意义的断言 |
| [reconstruct_fi_dmas_fdmas_manual.m](reconstruct_fi_dmas_fdmas_manual.m) | UFF 读取、FI delays、插值、共享接收孔径、analytic DAS、real-RF DMAS、轴向带通与包络 |
| [compare_fi_das_vs_fdmas.m](compare_fi_das_vs_fdmas.m) | 唯一真实数据比较、DAS 回归、局部剖面与频谱 |
| [export_chapter4_figures.m](export_chapter4_figures.m) | 固定条件导图、额外诊断视图、维度 / 实复数 / 包络一致性检查与日志 |
| [README.md](README.md) | 本文运行说明 |

核心函数也可以直接调用：

~~~matlab
opts = struct('z_min',5e-3,'z_max',45e-3,'n_z',[], ...
    'receive_f_number',1.7,'verbose',true);
out = reconstruct_fi_dmas_fdmas_manual(filename,opts);
~~~

重建支持正焦点、球面 focused FI，图像位于 x-z 平面。此实现要求 real、non-demodulated RF；使用 USTB 读取 UFF 与 probe / sequence 元数据，自行实现重建运算。

输出的图像数组都是 [Nz,Nx]：第 1 维为深度，滤波和 analytic transform 均沿这一维；第 2 维为 source.x 对应的 conventional FI 扫描线。das_analytic、fdmas_analytic 是复数，envelope 是各自的绝对值；dmas_unfiltered 与 fdmas_filtered 是实数。

## 5. 公式与核心代码对照

一个像素的 real-RF signed-sqrt 运算：

~~~matlab
u = sign(rf).*sqrt(abs(rf));
pair_sum = 0.5*(sum(u).^2 - sum(u.^2));
dmas_raw = 2*pair_sum/(M-1);  % M>=2
~~~

正文用 s 表示实数 RF；核心局部变量 s 保存插值后的复数通道子集，随后取 rf=real(s)。DAS 使用复数 analytic RF 求和，DMAS 使用实部。不要把变量命名差异理解成对复数 IQ 进行 signed-sqrt 配对。

2/(M−1) 是**本项目的幅度约定**，用于消除全相干输入的二次 pair-count 增长。所有通道相同时，归一化输出为 M|s|，而有符号 RF 的 DAS 为 Ms；这不能用于证明最后的 fDMAS 幅度已经标定成 DAS。

滤波采用：

~~~text
nominal f0 = c / lambda
F          = [1.5, 1.75, 2.5, 2.75] * f0
fs,z       = c / (2*dz)
require    fs,z / 2 > F(4)
Npad       = 2^nextpow2(2*Nz)
~~~

对双边 raised-cosine mask 做 FFT 相乘，裁回原长度后，再构造 analytic signal 和包络。默认 Δz≤约 λ/16。Nyquist 检查只覆盖所选带通上沿，不证明全部非线性谐波无混叠。USTB 官方 DMAS 使用 FIR，且频率估计、归一化等约定不同；本项目未做 fDMAS 的逐点 USTB 等价验证。

想观察网格保护检查，可在同一数据上设置下面的参数。预期是在重建循环前报告输出 Nyquist 不够，不能把这组粗网格当成有效实验图：

~~~matlab
bad_opts = struct('z_min',5e-3,'z_max',45e-3,'n_z',128,'verbose',false);
reconstruct_fi_dmas_fdmas_manual(filename,bad_opts) % 预期报错
~~~

## 6. 本次实际验证与读数

MATLAB R2021b / 本地 USTB 下已运行原理导图和完整 UFF 导图：

| 检查或结果 | 本次记录 |
|---|---|
| 多组向量的 pair / reduction 最大 scaled error | 6.855828×10⁻¹⁷ |
| 全相干归一化输出与 M 乘绝对 RF 的最大误差 | 5.329071×10⁻¹⁵ |
| DAS 对第一章复数基线的 max-peak scaled error | 5.113478×10⁻¹⁸ |
| 图像尺寸、有限值、实数 DMAS、analytic envelope、M 范围 | 断言通过 |
| analytic transform 的实部 scaled error | 3.063196×10⁻¹⁶ |
| [Nz,Nx] / Δz / Δx | [2166,128] / 0.018475751 mm / 0.297980965 mm |
| 轴向等效 Nyquist / 滤波上沿 | 20.838125229 / 14.322916985 MHz |
| 局部目标横向半幅宽度 DAS / fDMAS | 0.723634913 / 0.702282398 mm |
| 局部目标轴向半幅宽度 DAS / fDMAS | 0.445320469 / 0.607210753 mm |

宽度是未截断线性包络左右 0.5 交点之间的全宽（FWHM），交点通过相邻样本插值获得，对应约 −6.0206 dB 的**幅度**标准。横向只跨约 2.43 / 2.36 个网格间距，读数受采样限制；两种方法各用自己的局部峰值和切片。本次 fDMAS 的轴向包络更宽，不能把频率翻倍说成分辨率必然提升。

完整数值、输入 MD5、USTB commit、图片来源和适用边界见[配图索引](../../chapters/04_DMAS/figures/README.md)。本章没有生成 CNR / gCNR、SNR 或临床性能结论。
