# 第 4 章：DMAS / fDMAS——非线性通道组合

> **状态：已完成（教学与一次真实 UFF 图像实验）。**  
> 研究范围：conventional focused imaging (FI)、receive-domain real-RF DMAS/fDMAS。本章不继续堆算法变体，也不把单次实验当成普遍性能结论。

这章只要回答三个问题：

1. 为什么 DAS 已经完成延时相干求和，DMAS 还要让通道两两相乘？
2. DMAS 为什么还需要 **约 \(2f_0\) 的滤波**，才能得到 fDMAS B-mode？
3. 真实数据里究竟改善了什么，又付出了什么代价？

---

## 一、原理：DMAS / fDMAS 到底做了什么

### 1. DAS 是「通道求和」，DMAS 是「通道配对」

以一个成像像素为例。完成**同样的 Tx/Rx delay、插值和接收孔径选择**以后，设有 \(M\) 个有效接收阵元，延时后的实数 RF 样本为：

$$
\mathbf{s}=[s_1,s_2,\ldots,s_M].
$$

DAS（忽略 apodization）：

$$
y_{\rm DAS}=\sum_{i=1}^{M}s_i.
$$

最朴素的 Delay Multiply and Sum（DMAS）是不同接收通道的两两乘积：

$$
y_{\rm pair}=\sum_{1\le i<j\le M}s_i s_j.
$$

例如四个阵元时，参与的是 **6 对**：\((1,2),(1,3),(1,4),(2,3),(2,4),(3,4)\)。不包括自己与自己相乘，也不重复计算 \((j,i)\)。

**直觉**：对一个延时对齐后高度一致的点目标，不同通道往往在同一时刻同号，很多通道对的乘积就会同号；若通道信号不一致，乘积的符号和大小可能互相抵消。因此 DMAS 对接收孔径内的空间一致性有不同于 DAS 的响应。

这**不等于** DMAS 能分清「真实回波」和「杂波」：相干杂波可能保留，弥散散射组织本身也具有空间相关性。

### 2. 实际使用的 signed-sqrt DMAS

简单乘积的幅度与输入幅度的平方有关，因此经典超声 DMAS 通常采用：

$$
\boxed{
y_{\rm DMAS}=
\sum_{i<j}
\operatorname{sign}(s_i s_j)\sqrt{|s_i s_j|}
}
$$

- **sign**：保留乘积正负号；
- **sqrt**：使齐次幅度缩放由平方关系回到一次关系；
- **\(i<j\)**：每对接收通道只计算一次；
- **\(s_i\) 是 real RF**：不是直接拿复数 IQ 两两相乘，也不是拿 IQ envelope 代入。

一个直观例子：

~~~text
同相且正：s = [1, 1, 1, 1]
每一对贡献 +1 → 总 DMAS = +6

正负交错：s = [1, -1, 1, -1]
既有正乘积也有负乘积 → 总 DMAS = -2
~~~

因此仅凭单个 DMAS sample 的符号不能直接判断目标存在与否。最后还要把 RF-like 输出沿轴向做滤波和包络检波。

**注意幅度尺度**：本项目 core 额外把 pair sum 乘以 \(2/(M-1)\)，使全相干、等幅的孔径输出维持与 DAS 相似的 \(O(M)\) 量级，尤其避免动态 Rx F# 下通道对数量随深度变化而引入显著的 \(M(M-1)\) 因子。这是教学比较的 **normalization convention**，不是 signed-sqrt DMAS 的定义本身；不应声称与 USTB 原始输出具有相同的绝对幅度。

### 3. 快速实现：为什么不需要 \(M(M-1)/2\) 次独立乘法？

令：

$$
u_i=\operatorname{sign}(s_i)\sqrt{|s_i|}.
$$

那么 \(u_i u_j=\operatorname{sign}(s_is_j)\sqrt{|s_is_j|}\)，并利用展开：

$$
\left(\sum_i u_i\right)^2
=\sum_i u_i^2+2\sum_{i<j}u_iu_j,
$$

得到：

$$
\boxed{
y_{\rm DMAS}
=\frac12\left[\left(\sum_i u_i\right)^2-\sum_i u_i^2\right].
}
$$

显式枚举所有 pair 是 \(O(M^2)\)；这个**数学上等价的 reduction 形式**只需 \(O(M)\)，因此能直接用于完整二维数据重建。

本章脚本会用确定性的 real-RF 小向量比较这两种写法。

### 4. 为什么还要有「f」DMAS？

fDMAS 的 **f = filtered**。两个中心频率约为 \(f_0\) 的实数窄带信号相乘，会引入低频和约 \(2f_0\) 的分量。对于最简单的余弦：

$$
\cos(2\pi f_0 t)\cos(2\pi f_0 t)
=\tfrac12+\tfrac12\cos(4\pi f_0 t).
$$

signed-sqrt 运算产生的频谱并不严格只有 DC 和 \(2f_0\)，但其约 \(2f_0\) 的分量仍可用带通提取。典型 fDMAS 流程是：

~~~text
real RF channel data
       ↓
同 DAS 的 Tx/Rx delay + fractional interpolation
       ↓
real delayed receive samples
       ↓
signed-sqrt channel-pair DMAS
       ↓
每个 scanline 上的 axial bandpass（约 2f0）
       ↓
Hilbert / analytic signal / envelope
       ↓
各自 peak normalization + log compression
       ↓
fDMAS B-mode
~~~

本项目的窗口为：

~~~text
1.5 f0  – 1.75 f0：平滑进入通带
1.75 f0 – 2.5 f0 ：通带
2.5 f0  – 2.75 f0：平滑退出通带
~~~

实现用 zero-padded FFT raised-cosine mask；官方 USTB 参考代码采用 FIR bandpass。因此两者的滤波目标类似，但**不能声称逐点数值等价**。

### 5. fDMAS 的轴向采样约束

轴向输出网格的深度步长 \(dz\) 对应近似 two-way image-time：

$$
t_{\rm image}\approx 2z/c,\qquad f_{s,z}\approx c/(2dz).
$$

必须让这个**轴向等效采样率**的 Nyquist 高于 \(2f_0\) 滤波上沿。代码会自动选择约 \(dz=\lambda/16\)，并检查：

$$
\frac{f_{s,z}}2>2.75f_0.
$$

需要区分：这一检查保证**输出滤波器频带不会直接越过 Nyquist**，但不等于证明 nonlinear DMAS 的所有更高次谐波都无混叠，也不等于严格验证每个 off-axis pixel 的 two-way time 近似。

---

## 二、唯一实验：真实 UFF 的完整二维 DAS vs fDMAS

### 1. 数据、条件和一键运行

- 数据：`data/L7_FI_TheGB.uff`，focused FI，real RF。
- 图像：所有 focused scanlines，\(z=5\sim45\) mm。
- Tx/Rx delays、fractional interpolation、dynamic Rx F#：与 Chapter 1 的 conventional FI-DAS 一致。
- Rx F#：默认 \(1.7\)。
- 轴向 \(dz\)：按波长自动选择，确保 \(2f_0\) 滤波 Nyquist 条件。
- 显示：DAS 和 fDMAS 各自 peak 归一化，动态范围同为 60 dB。

运行：

~~~matlab
addpath(genpath('D:/你的USTB路径'));
cd matlab/04_DMAS
compare_fi_das_vs_fdmas
~~~

如只需点目标附近的快速测试：

~~~matlab
z_min = 16e-3;
z_max = 24e-3;
compare_fi_das_vs_fdmas
~~~

脚本执行：signed-sqrt 两种求和写法的 algebra identity test；DAS 与 Chapter 1 核心输出的 complex regression test（默认开启）；完整二维两图、point-target lateral profile，以及 DMAS 滤波前后轴向频谱。

### 2. 实际截图解读（2026-11-12）

用户已在本地 MATLAB 运行，并提供 Figure 1、Figure 2 截图。以下是**基于截图的定性观察**，不是未提供的数值统计。

| 对比项 | 实验观察 | 科学解释与限制 |
|---|---|---|
| 完整二维 B-mode | DAS 与 fDMAS 都保留了主要体模目标的大致位置 | 说明本次输出在宏观几何上相容；不能单凭此验证所有 delay 或滤波细节 |
| Point-target lateral profile | fDMAS 在部分旁瓣/邻近横向位置的幅度低于 DAS，中央主瓣仅有少数 scanlines | 有局部响应抑制；当前 conventional-FI 横向采样限制 FWHM 的准确估计 |
| Background speckle | fDMAS 的纹理比 DAS 更细碎、更颗粒化，局部明暗对比变化 | 这是非线性组合及频谱选择带来的**纹理重塑**，不能直接叫“去噪成功” |
| DMAS 频谱 | 滤波前有显著低频分量，另有较高频能量 | 与 channel multiplication 产生频谱重分布一致 |
| fDMAS 频谱 | 滤波后主要保留大约 8–10 MHz 附近能量，低频被大幅削弱 | **与设定的 \(2f_0\) 附近 bandpass 相符**；不代表频域处理已完成严格物理验证 |

Figure 1 的两图都以**各自峰值 0 dB** 显示，故相同灰阶并不表示相同 RF 幅度或绝对 SNR。

Figure 2 的横向 profile 也分别归一化，不应据此比较 point-target 绝对幅度衰减。尤其不能将仅跨少数 scanlines 的窄峰直接写成精确的“分辨率提高”。

本轮未提供 Console 原始输出，因此本文**不填写 FWHM、reference error、CNR/gCNR 等未实际看到的数值**。截图显示程序完成绘图，但严格的 DAS regression PASS 仍以对应 Console 为准。

### 3. 实验回答了什么问题？

它确认了一个定性的现象：

> fDMAS 不只是更换通道求和方式，也会经过频域选择，因而同时改变空间响应与散斑纹理。在本次 TheGB 图像上看到了局部横向响应抑制和明显 speckle 重塑，但没有足够证据宣称它整体优于 DAS。

这正是 DMAS 与 MVDR 的重要差别：

~~~text
MVDR
covariance → 线性自适应 Rx weights → coherent combination

fDMAS
实数 RF → 非线性 channel-pair combination
        → 2f0 bandpass → envelope
~~~

---

## 三、本章总结与边界

**学会这章，只需要记住：**

1. **DMAS 是非线性 receive combination，不是 DAS 之后的标量权重，也不使用 MVDR 的 covariance inversion。**
2. **经典 fDMAS = signed-sqrt real-RF DMAS + 约 \(2f_0\) 带通 + envelope。** 不能把复数 IQ 两两相乘取绝对值直接视作这个定义。
3. **优势有代价**：局部响应可能被压低，但相干 clutter 并不会自动消失；speckle 可能被改写；动态孔径和 bandpass/normalization 都影响图像表现。

本章不继续实现 DS-DMAS、lag-DMAS、coherence-weighted DMAS 等派生方法；留到需要独立研究时再讨论。真正的跨算法胜负应在第 7 章统一 benchmark 中基于同一数据、ROI 和指标检验。

### 代码

~~~text
matlab/04_DMAS/
├─ reconstruct_fi_dmas_fdmas_manual.m  核心算法
├─ compare_fi_das_vs_fdmas.m           唯一一键实验
└─ README.md                           运行说明
~~~

### 参考

- Matrone G. et al. (2015), *IEEE Transactions on Medical Imaging*, “The Delay Multiply and Sum Beamforming Algorithm in Ultrasound B-Mode Medical Imaging”. DOI: https://doi.org/10.1109/TMI.2014.2371235
- USTB official reference: https://github.com/unioslo/USTB/blob/master/+postprocess/delay_multiply_and_sum.m

**下一章：SLSC（Short-Lag Spatial Coherence）**——从 DMAS 的通道对非线性组合，进一步理解如何直接使用相邻阵元的空间相关性形成成像指标。
