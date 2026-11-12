# Chapter 5 MATLAB — SLSC

**已完成本章教学用一次 TheGB 真实 UFF 二维对照（2026-11-12）。** 保持精简：一个 core + 一个完整二维一键实验，不增加新的参数扫描。

## 一键运行

~~~matlab
addpath(genpath('D:/你的USTB路径'));
cd matlab/05_SLSC
compare_fi_das_vs_slsc
~~~

默认数据：`../../data/L7_FI_TheGB.uff`，real RF conventional focused imaging，z=5–45 mm，全部 FI scanlines。

### 目录

~~~text
reconstruct_fi_slsc_manual.m  % UFF real RF -> DAS + short-lag coherence maps
compare_fi_das_vs_slsc.m      % 2-D DAS/SLSC / correlation-lag diagnostics
README.md                     % this file
~~~

### 参数

~~~text
n_z                    768
receive_f_number       1.7
axial_kernel_lambda    1.0       % FULL kernel length in wavelengths
lag_fraction           0.15      % Q relative to ACTIVE receive aperture
max_lag                12        % upper limit in physical element pitches
min_valid_samples      3
run_das_reference_check = true
~~~

**Shape / dtype / unit**：

~~~text
UFF RF                    [sample, channel, wave, frame] real
delayed RF gate           [axial_kernel_samples, active_rx_channels] real
DAS output                [z,scanline] complex
lag_correlations          [z,scanline,lag] real, NaN for unavailable lag
SLSC sum / mean           [z,scanline] signed real
SLSC display              [z,scanline] real [0,1]
x/z axes                  [m]
~~~

**关于 normalization：** 原始 SLSC 是对 short lags 的 correlation 求和。由于本项目采用动态 Rx F#，不同深度的有效 lag 数可能不同；core 同时保留 `slsc_sum`（经典累加形式）与 `slsc_mean`（对有效 lag 数取平均的教学显示约定），只将后者裁负值、归一化到 [0,1] 用于 Figure 1。不要把它当 DAS dB amplitude 比较。

### 验证

实验脚本默认执行：

1. normalized correlation 的正/负边界与 amplitude scaling sanity checks；
2. SLSC [-1,1] 范围、lag count consistency；
3. independent Chapter-1 conventional FI-DAS 的复数最大峰归一化误差 `<1e-10`；
4. 完整二维 DAS dB / SLSC linear image、lag curve 和使用 lag 数量 map。

**不执行** USTB SLSC postprocessor，不需要 USTB MEX 来完成本项目算法。USTB 仅负责 UFF 读取。

用户已在本地 MATLAB 完整运行并提供 Figure 1/2 截图；正常显示说明执行到绘图阶段。由于默认 DAS regression 和 sanity asserts 在绘图之前执行，若未关闭 `run_das_reference_check`，说明这些检查已通过。**未提供 Console 数值，因此不记录具体误差、runtime 或性能提升百分比。**

### 本次结果（截图级定性结论）

- **Figure 1：** SLSC 保留体模主要空间结构，但 15–35 mm 区域呈大片高相干亮度，组织散斑外观与 DAS 显著不同；SLSC 为 linear coherence、DAS 为 dB amplitude，**不可按同一灰度直接比较信号强度**。
- **Figure 2：** 中央 ROI（z=15–30 mm）Lag 1 平均相关约 0.90，Lag 4–5 约 0.54，Lag 6–8 略回升；各 lag 的有效像素集合随 Q、深度和动态孔径变化，**回升不等于更远的阵元物理上更相干**；Lag 9–12 在该 ROI 没有有效点，并不是相关性为零。
- requested-lag map 随深度明显增加，符合 dynamic F-number 的孔径定义。

**一个已修正的显示细节：** 原图标题显示 `kernel=1.23 lambda`，原 core 用 `K*dz/lambda` 计算窗口跨度，正确应为 `(K-1)*dz/lambda`。现已修正打印和输出 metadata，**未改变实际窗口采样、RF 数据或 SLSC 图像**。不必为此重跑实验。

本章的结论是：**SLSC 能构建与 DAS 不同的相干性图像，但本次观察不能证明它优于 DAS**。该实验满足教学收尾需求，但不是独立 SLSC 数值金标准/临床有效性验证。

详细原理见 [第 5 章教程](../../chapters/05_SLSC/README.md)。
