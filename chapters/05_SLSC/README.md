# 第 5 章：SLSC（Short-Lag Spatial Coherence）

**状态：代码和原理教程已完成；真实 UFF 输出尚未由本地 MATLAB 验证。**

本章沿用“完整原理一节 → 一次二维 DAS 对照实验 → 总结”的效率优先结构，不增加不必要的变体或参数扫描。

## 一、原理：用相邻阵元的相关性形成图像

### 1. 为什么不继续看 RF 幅度？

DAS 在 Tx/Rx delay alignment 后对各 Rx 求相干和：

$$
y_{\rm DAS}(x,z)=\sum_i s_i(x,z).
$$

但一个像素幅度高，并不意味着它完全来自该位置真实的散射体：off-axis echo、reverberation、phase aberration、noise 都可能污染幅度图像。

SLSC 改问：**当前像素对应的延时后 RF 数据，在物理距离很近的接收阵元之间是否相似？**

这里的 lag 是阵元间隔（number of element pitches），不是回波的时间差：

~~~text
Rx indices: 1  2  3  4  5  6 ...

lag 1:    (1,2), (2,3), (3,4), ...
lag 2:    (1,3), (2,4), (3,5), ...
lag 3:    (1,4), (2,5), (3,6), ...
~~~

对 diffuse speckle，随着物理接收孔径的阵元间距增加，空间相干性一般会降低。SLSC 因此主要使用短 lag，而不是把所有远距离阵元对都同等纳入。

### 2. 一个像素如何计算？

假设候选像素经过同 Chapter 1 相同的 Tx/Rx delay 与插值，在 active aperture 上得到实数 RF 矩阵：

~~~text
X_gate shape: [axial_kernel_samples, active_rx_channels]
~~~

注意**一个 SLSC pixel 需要一个短的轴向 RF 窗口**；不是像 CF 那样只用一个深度的 complex aperture vector 就结束。

两个相隔 \(m\) 个阵元的通道 \(i\) 与 \(i+m\)，在轴向窗口 \(\mathcal{W}(z)\) 内的 normalized RF correlation：

$$
\rho_{i,i+m}(x,z)=
\frac{
 \sum_{n\in\mathcal{W}(z)}s_i[n]s_{i+m}[n]
}{
 \sqrt{
 (\sum_{n\in\mathcal{W}(z)}s_i^2[n])
 (\sum_{n\in\mathcal{W}(z)}s_{i+m}^2[n])
 }
}.
$$

若数据窗口没有有效能量或有效采样不足，该阵元对不参与该像素的 correlation 估计。

固定 lag \(m\)，再平均该 lag 下的有效通道对：

$$
\widehat R(m;x,z)
=\frac{1}{N_m}\sum_{i\in\mathcal V_m}\rho_{i,i+m}(x,z),
$$

其中 \(\mathcal V_m\) 是当前轴向窗口内有效的阵元对集合，\(N_m=|\mathcal V_m|\)。

最后对前几个 lag 积分/求和：

$$
\boxed{
S_{\rm SLSC}(x,z)=\sum_{m=1}^{m_{\max}}\widehat R(m;x,z).
}
$$

以上短 lag 相干求和是 Lediju 等人 2011 年 SLSC 的核心定义。

**物理意义**：

- 对应像素的相干回波在近邻阵元间更相似，\(R(m)\) 更高；
- 不相干杂波、噪声可能降低 \(R(m)\)；
- SLSC 的输出是**无量纲的 coherence metric**，不是 DAS RF amplitude；
- 相干 clutter 仍可能被保留；真实 diffuse scattering 也不保证相干性总是很高。

### 3. 为什么 axial kernel 必不可少？

只取两个阵元在同一个深度的**一个 RF 数字**，不能稳定估计统计相关性（两个标量的“相关系数”没有我们想要的物理意义）。

因此需要一个小的轴向 RF 邻域作为统计样本，在每对阵元之间计算 normalized correlation。经典超声 SLSC 通常选择约一个波长的轴向 kernel，本章默认：

~~~text
axial_kernel_lambda = 1.0
~~~

这与 MVDR 的 axial covariance averaging 有相似之处，但它们服务的最终目标不同：

~~~text
MVDR:
axial snapshots -> covariance R -> adaptive Rx weights -> amplitude

SLSC:
axial RF gate -> per-lag normalized correlation -> coherence image
~~~

### 4. Q、max_lag 与动态 Rx aperture

原始 SLSC 可用 lag 的个数或其占 aperture 元素数的比例 \(Q\) 来表述；文献中短-lag fraction 常选在约 10%–30% 量级，具体不是普适最优值。

本章默认：

~~~text
receive_f_number = 1.7
lag_fraction     = 0.15
max_lag          = 12
~~~

具体实现根据**当前像素有效 Rx aperture** 的元素数 \(M(x,z)\) 选：

$$
m_{\max}(x,z)=\min\bigl(12,\, M-1,\,\max(1,\lfloor0.15 M\rfloor)\bigr).
$$

因此不同深度 \(m_{\max}\) 可能不同：这是动态 F# 的自然结果。

#### 为什么输出同时有 SLSC sum 和 mean？

经典定义是 sum。为了避免随着深度增长、active aperture 变大、累加 lag 数量上升而导致显示亮度出现**纯计数因素**，本项目明确额外输出：

$$
S_{\rm mean}(x,z)
=\frac{1}{N_{\rm good\,lags}}
\sum_{\text{valid short lags}}\widehat R(m;x,z).
$$

- `out.slsc_sum`：未除以 lag 数的原始积分结果；
- `out.slsc_mean`：为当前动态 Rx F# 设置提供的**平均 short-lag coherence**；
- `out.slsc_display`：将 `slsc_mean` 的负值裁为 0，并以最大正值归一化，用于线性灰度显示。

这是**本项目的显示归一化约定**，不能把平均值与原论文的 raw sum 数字混作同一结果。负相关值不应在科学计算阶段直接丢掉。

### 5. 与 CF / DMAS 的区别

| 方法 | 输入窗口 | 关键数学运算 | 输出 |
|---|---|---|---|
| CF | 一个 depth 的复数 Rx aperture | coherent-sum 能量 / aperture 总能量 | DAS × scalar CF |
| fDMAS | 一个 depth 的延时实数 RF 通道，之后沿 z 滤波 | signed-sqrt pair products + 2f0 bandpass | nonlinear amplitude image |
| **SLSC** | **一个 pixel 周围的 axial RF gate × active Rx channels** | **短 lag 归一化相关性** | **coherence image** |

短 lag 相干性成像在低 SNR 或 clutter 污染条件下可能改善目标显示，但不意味着它会增强所有点目标。原始研究明确指出其在某些点目标显示方面的局限。

---

## 二、一次完整实验：二维 FI-DAS vs SLSC

### 1. 数据与运行

沿用 Chapter 1/4 的同一份 UFF：

~~~text
data/L7_FI_TheGB.uff
focused imaging, real RF
x: 全部 Tx 对应的 focused scanlines
z: 5–45 mm
Rx F#: 1.7
n_z: 768
axial kernel: 1 wavelength
Q: 15% of active Rx aperture
lag upper bound: 12 element pitches
~~~

一键运行：

~~~matlab
addpath(genpath('D:/你的USTB路径'));
cd matlab/05_SLSC
compare_fi_das_vs_slsc
~~~

本章两条链路共享：

~~~text
同一份 real RF
同一 Tx spherical timing model
同一 Rx geometric delay
同一 fractional interpolation
同一 dynamic F# receive aperture
同一 [z,scanline] output grid
      |
      +--> analytic DAS -> envelope -> log dB
      |
      +--> real delayed RF axial gates
             -> normalized correlation by lag
             -> short-lag integration
             -> linear coherence display
~~~

### 2. 为什么比较图的灰度标尺不同？

Figure 1 左边是：

~~~text
DAS: envelope, 20log10, [-60, 0] dB
~~~

Figure 1 右边是：

~~~text
SLSC: positive, normalized short-lag coherence [0, 1], LINEAR
~~~

**不能把两张图的同一灰度直接解读为同一 RF 幅度。** SLSC 更黑不代表声能更弱，SLSC 更亮也不代表该像素反射系数更大。

Figure 2 辅助显示 short-lag correlation 随 m 的变化，以及使用 dynamic F# 时各深度的 lag-count map。这个图用于检查算法是否按照短 lag 的思想工作，而不是证明某类结构更好。

### 3. 自检与验收条件

脚本包含：

1. 用确定性 RF 小向量验证 normalized correlation 的幅度缩放不变性与正/负相关边界；
2. 检查 signed mean coherence 在 [-1,1] 之间、有效 lag 数不超过请求 lag 数；
3. 与 Chapter 1 的 `reconstruct_fi_scanline_manual.m` 对**复数 DAS 数据**做 max-peak scaled regression test，要求小于 \(10^{-10}\)；
4. 输出 2-D DAS/SLSC 两幅图和 lag behavior。

**目前状态**：核心文件和脚本已提交 GitHub；尚未在用户本地 MATLAB + TheGB UFF 环境中执行，因此未记录或虚构 PSF/FWHM、CNR、SNR 或提升百分比。

---

## 三、本章总结

三句话足够：

1. **SLSC 是直接用短阵元间距的 normalized RF correlation 构造图像，并非 DAS 后处理，也不是 MVDR adaptive weights。**
2. **它既需要空间 lag，也需要足够短且有统计意义的 axial RF kernel**；kernel、lag fraction 和动态接收孔径都对结果有影响。
3. **相干性不是组织真值**。SLSC 可改善某些 clutter-limited 条件下的结构显示，但会改变 speckle 和点目标外观。尤其不能把线性 coherence 图与 log-compressed DAS 幅度图直接对比亮度来断言优劣。

在一个完整二维实验后本章便可结束，不延伸到 FSAS、G-SLSC、LSC、coherence-flow 等扩展方向。真正比较不同算法性能留到 Chapter 7 的统一 benchmark。

### 文献与官方实现

- Lediju MA, Trahey GE, Byram BC, Dahl JJ. (2011). **Short-lag spatial coherence of backscattered echoes: Imaging characteristics.** *IEEE Transactions on Ultrasonics, Ferroelectrics, and Frequency Control*, 58(7), 1377–1388. DOI: https://doi.org/10.1109/TUFFC.2011.1957
- 原文开放版本：https://pmc.ncbi.nlm.nih.gov/articles/PMC3172134/
- USTB 参考：https://github.com/unioslo/USTB/blob/master/+postprocess/short_lag_spatial_coherence.m

### 代码入口

~~~text
matlab/05_SLSC/
├─ reconstruct_fi_slsc_manual.m   # 手写 receive-domain SLSC core
├─ compare_fi_das_vs_slsc.m       # 唯一一键实验 + Chapter-1 DAS regression
└─ README.md
~~~

**下一章：NSI（Null Subtraction Imaging）。**
