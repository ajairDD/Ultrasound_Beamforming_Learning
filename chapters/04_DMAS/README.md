# 第 4 章：DMAS / fDMAS

本章保持精简：一节完整原理、一份完整二维对照实验、最后总结，不展开大量派生算法。

## 一、原理

DAS 在 Tx/Rx delay alignment 后对各 Rx 样本直接求和：

$$
y_{\rm DAS}=\sum_{i=1}^M s_i
$$

DMAS（Delay Multiply and Sum）在延时对齐后，让不同接收通道两两相乘再相加。本章选用 2015 年 Matrone 等人采用的修正实数 RF 定义：

$$
y_{\rm DMAS}=\sum_{i<j}\operatorname{sign}(s_is_j)\sqrt{|s_is_j|}
$$

这里的 $s_i$ 是**实数 RF 样本**，不是 complex IQ。sign 保持乘积符号，sqrt 避免简单幅度平方造成的量纲变化。

### 等价快速实现

设

$$
u_i=\operatorname{sign}(s_i)\sqrt{|s_i|}
$$

那么

$$
\boxed{
y_{\rm DMAS}=\frac{(\sum_i u_i)^2-\sum_i u_i^2}{2}
}
$$

这是精确代数恒等式，能把逐像素两层 channel-pair 循环的计算量从 $O(M^2)$ 降至 $O(M)$。脚本内有确定性小向量检验。

### 为什么有 fDMAS？

两个窄带实数 RF 相乘，会产生低频与二倍频成分。以相同频率的余弦为例：

$$
\cos^2(2\pi f_0t)=\frac12+\frac12\cos(4\pi f_0t)
$$

实际 signed-sqrt DMAS 的频谱更复杂，但通常仍需要保留约 $2f_0$ 的成分。fDMAS（Filtered DMAS）在 DMAS 后做 bandpass、再做 Hilbert/envelope 和 log compression。

本项目默认带通窗口沿用经典文献/USTB 一类设计的量级：

~~~text
stop <1.5 f0
transition 1.5–1.75 f0
pass 1.75–2.5 f0
transition 2.5–2.75 f0
stop >2.75 f0
~~~

实现采用 zero-padded FFT raised-cosine window，不与 USTB 的 FIR 滤波器声称数值等价。

### 非常重要：输出轴向采样率

沿深度轴滤波时，使用常见 two-way image-time 近似：

$$
t_{\rm image}\approx 2z/c,\quad f_{s,z}\approx c/(2dz)
$$

如果沿用之前较粗的 n_z=256/512，约 $2f_0$ 的分量可能超过 Nyquist。代码默认自动设 $dz\approx\lambda/16$，并断言 $f_{s,z}/2>2.75f_0$。

这只是轴向等效时间近似；off-axis 延时、实际 pulse spectrum、非线性高次谐波的离散混叠仍是需要理解的限制。

## 二、一次性实验：DAS 与 fDMAS 完整二维成像

运行：

~~~matlab
addpath(genpath('D:/你的USTB路径'));
cd matlab/04_DMAS
compare_fi_das_vs_fdmas
~~~

默认：

~~~text
data/L7_FI_TheGB.uff
conventional focused FI
x: all focused scanlines
z: 5–45 mm
Rx F#: 1.7
dz: approximately lambda/16
~~~

输出完整二维 DAS/fDMAS 图像、point-target lateral profile 和 fDMAS 滤波前后轴向频谱。

该实验固定 Tx/Rx delay、fractional interpolation、Rx F-number，只改变接收通道组合与后续 fDMAS 频带处理。默认还会调用 Chapter 1 DAS core 做 complex regression comparison。

为节省第一次运行时间，可改为：

~~~matlab
z_min=16e-3;
z_max=24e-3;
compare_fi_das_vs_fdmas
~~~

**DAS/fDMAS 图像使用各自 peak 归一化，只能直接比较形态，不能据此比较绝对信号增益。** nonlinear fDMAS 对幅度和 speckle 的影响均不同于 DAS。

## 三、总结

重要结论只有三个。

1. DAS 是线性通道求和；DMAS 利用通道两两乘积，属于非线性组合；fDMAS 则进一步选取 $2f_0$ 附近的频率成分。
2. DMAS 不等于只保留真实目标。相干 clutter 也可能被增强，diffuse speckle 可能被改写；固定发射聚焦数据在离焦区域还可能存在亮度损失。
3. 与 MVDR 不同，DMAS 不求 covariance、不解 adaptive weights；更尖的 profile 也不自动表示真实物理分辨率或临床性能更好。

不继续实现 DS-DMAS、lag-DMAS、coherence-weighted DMAS 等大量变体。后续统一 benchmark 再比较不同算法的真实收益、speckle 保真性和计算成本。

### 来源

- Matrone G. et al., 2015, IEEE TMI, The Delay Multiply and Sum Beamforming Algorithm in Ultrasound B-Mode Medical Imaging, DOI: https://doi.org/10.1109/TMI.2014.2371235
- Matrone G. et al., 2015, Ultrasound Synthetic Aperture Focusing with the Delay Multiply and Sum beamforming algorithm, DOI: https://doi.org/10.1109/EMBC.2015.7318319
- USTB official reference: https://github.com/unioslo/USTB/blob/master/+postprocess/delay_multiply_and_sum.m

目前已提交 MATLAB 实现，但在用户实际运行前不把其真实数据成像性能称为已验证。
