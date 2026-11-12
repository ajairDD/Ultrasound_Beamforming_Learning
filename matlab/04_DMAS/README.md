# Chapter 4 MATLAB — DMAS / fDMAS

**状态：已完成教学与一次 TheGB 真实 UFF 二维实验。** 本目录只有一个核心算法文件和一个一键实验脚本，不继续增加 DMAS 派生版本。

## 一键运行

~~~matlab
addpath(genpath('D:/你的USTB路径'));
cd matlab/04_DMAS
compare_fi_das_vs_fdmas
~~~

默认数据：\`../../data/L7_FI_TheGB.uff\`，conventional FI，5–45 mm，全扫描线，Rx F#=1.7，输出 \(dz\) 约 \(\lambda/16\)。

快速 point-target ROI：

~~~matlab
z_min=16e-3;
z_max=24e-3;
compare_fi_das_vs_fdmas
~~~

## 文件与工作分工

| 文件 | 用途 |
|---|---|
| \`reconstruct_fi_dmas_fdmas_manual.m\` | Chapter-1 同款 FI delays/interpolation/aperture；复数 analytic DAS；实数 RF signed-sqrt DMAS；轴向 \(2f_0\) 带通；fDMAS envelope / B-mode |
| \`compare_fi_das_vs_fdmas.m\` | 运行完整二维比较、点目标 lateral profile、滤波前后频谱、fast-DMAS identity check、Chapter-1 DAS regression check |
| \`README.md\` | 本文运行说明 |

## 主要算法对应代码

对每个 pixel：

~~~matlab
% s = delayed real-RF receive vector of M active channels
u = sign(s).*sqrt(abs(s));
pair_sum = 0.5*(sum(u).^2-sum(u.^2));
dmas_raw = 2*pair_sum/(M-1);  % M>=2, teaching normalization
~~~

其中 \(2/(M-1)\) 是本项目为了动态接收孔径而添加的**幅度归一化约定**，不属于 signed-sqrt DMAS 数学定义，也不保证与 USTB 绝对数值相同。

fDMAS 在轴向 image-time 等效采样率下做 FFT bandpass：

~~~text
F / f0 = [1.5, 1.75, 2.5, 2.75]
fs_z   = c/(2*dz)
require fs_z/2 > 2.75*f0
~~~

最后做 Hilbert/envelope/log compression。

## 已有实验观察（2026-11-12 MATLAB 截图）

用户已完成完整二维 Figure 1 和点目标/频谱 Figure 2：

- Figure 1：fDMAS 保留 TheGB 的主要结构和位置，但 background speckle 比 DAS **更颗粒化**。
- Figure 2 左：部分 lateral skirt/sidelobe 被压低；FI scanline spacing 仍限制 -6 dB FWHM 的精度。
- Figure 2 右：fDMAS 主要保留约 \(2f_0\) 附近频带，低频被抑制。

**当前结论是“现象和预期机制相符”，不是“成像质量更好”。** 未提供 Console 原始数值，因此不记录 FWHM、DAS reference scaled error 或 CNR/gCNR 的虚构结果；assert 是否通过以 Console 为准。

## 验证层次

代码中的检查包括：

1. deterministic real-RF 向量的 pairwise \(O(M^2)\) 与快速 \(O(M)\) 恒等式；
2. fDMAS 的 \(2f_0\) 输出轴向 Nyquist；
3. Chapter-4 DAS 与 Chapter-1 conventional FI-DAS 的 **complex-valued regression**（默认打开）。

本项目使用 real-RF signed-sqrt DMAS，而不是 complex IQ pair multiplication。滤波为 raised-cosine FFT bandpass，USTB 实现为 FIR；两者不能宣称逐点数值等价。由于 fDMAS 非线性，**DAS/fDMAS 图像各自 peak-normalized，只能比较 morphology，不可直接比较幅度增益**。

理论、实验解读、结论见 [第 4 章教程](../../chapters/04_DMAS/README.md)。
