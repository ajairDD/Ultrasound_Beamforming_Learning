# Chapter 4 MATLAB — DMAS / fDMAS

本章只保留一个完整二维实验。

~~~matlab
addpath(genpath('D:/你的USTB路径'));
cd matlab/04_DMAS
compare_fi_das_vs_fdmas
~~~

文件：

~~~text
reconstruct_fi_dmas_fdmas_manual.m
compare_fi_das_vs_fdmas.m
README.md
~~~

核心使用 Chapter 1 conventional-FI Tx/Rx delay、fractional interpolation 和 dynamic Rx F#，在同样的 aperture 上比较 DAS 与 real-RF signed-sqrt DMAS/fDMAS。

默认：TheGB focused FI、full-depth 5–45 mm、Rx F#=1.7、z sampling 约 lambda/16、filter edges [1.5 1.75 2.5 2.75] × nominal f0。

如需快速运行局部 point target：

~~~matlab
z_min=16e-3;
z_max=24e-3;
compare_fi_das_vs_fdmas
~~~

脚本检查：
- O(M) fast-DMAS identity 与真实 pairwise sign-sqrt sum；
- 2f0-band image-time Nyquist 条件；
- 重新计算的 DAS 与 Chapter 1 DAS complex baseline（默认）；
- 完整二维 DAS/fDMAS B-mode、lateral profile、滤波前后频谱。

**注意**：classic real-RF fDMAS 不是 complex IQ pair multiplication；此处 fDMAS 通过 axial image-time bandpass 而非 raw RF 时间滤波，属于常见近似。FFT filter 与 USTB 的 FIR 不完全一样。DAS/fDMAS 各自 peak-normalized，不能据图直接比较绝对 amplitude。

理论参见 ../../chapters/04_DMAS/README.md。
