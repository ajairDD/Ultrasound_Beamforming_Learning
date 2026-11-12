# Chapter 5 MATLAB — SLSC

本章保持精简：一个 core + 一个完整二维一键实验。

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

尚未用用户本地 TheGB UFF + MATLAB 实际运行。第一次运行以 Console 的 regression/pass checks 和两张 Figure 为验收依据；图像看起来合理不代表算法已完成严谨物理验证。

详细原理见 [第 5 章教程](../../chapters/05_SLSC/README.md)。
