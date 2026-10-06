# 第 3 章：MV / MVDR / Capon

本章目标不是把所有 Minimum-Variance 变体都实现一遍，而是把 **标准 receive-domain MVDR 的核心原理、实现条件、真实优缺点和两个重要后续方向**讲清楚。

默认教学数据：

~~~text
data/L7_FI_TheGB.uff
~~~

真实人体补充验证：

~~~text
data/L7_FI_carotid_cross_1.uff
data/L7_FI_carotid_cross_2.uff
~~~

---

# 1. 从 DAS 到 MVDR

完成 Tx/Rx delay alignment 后，一个 pixel 的 active receive aperture 写成：

$$
\mathbf s=[s_1,s_2,\ldots,s_M]^T
$$

DAS 使用固定等权组合：

$$
y_{DAS}=\mathbf 1^H\mathbf s
$$

MVDR 则根据当前 aperture data 的 covariance 自适应计算权重：

$$
y_{MVDR}=\mathbf w^H\mathbf s
$$

因此 MVDR 不是对 DAS 图像再乘一个 scalar，而是直接改变 receive-channel combination。

如果当前 pixel 的 Tx/Rx delay 正确，理想目标经过 delay alignment 后应该近似同相，因此本章 nominal steering vector 为：

$$
\mathbf a=[1,1,\ldots,1]^T
$$

MVDR 要求：

$$
\mathbf w^H\mathbf a=1
$$

同时最小化输出功率：

$$
\min_{\mathbf w}\mathbf w^H\mathbf R\mathbf w
$$

其中：

$$
\mathbf R=E\{\mathbf x\mathbf x^H\}
$$

解为：

$$
\boxed{
\mathbf w=
\frac{\mathbf R^{-1}\mathbf a}
{\mathbf a^H\mathbf R^{-1}\mathbf a}
}
$$

最重要的直觉：

~~~text
R
→ 描述当前 aperture 中的空间功率结构

R^{-1}
→ 对高功率 eigen-directions 给予较小响应

a
→ 指定哪个模式必须保留

归一化分母
→ 保证 w^H a = 1
~~~

所以 MVDR 不是“强信号都压掉”，而是在保护指定 steering mode 的前提下最小化剩余输出功率。

---

# 2. Covariance estimation：真正的工程核心

## 2.1 Spatial smoothing

一个 pixel 只有一个 aperture snapshot。直接使用 xx^H 最多 rank 1，不能稳定估计 covariance。

因此把 M 个 active receive channels 切成多个重叠长度-L子阵：

~~~text
s1 s2 s3 s4 s5 s6

L = 3

x1 = [s1 s2 s3]
x2 = [s2 s3 s4]
x3 = [s3 s4 s5]
x4 = [s4 s5 s6]
~~~

构造：

$$
\mathbf X=[\mathbf x_1,\mathbf x_2,\ldots,\mathbf x_P]
$$

其中 P=M-L+1，再估计：

$$
\hat{\mathbf R}=\frac{1}{P}\mathbf X\mathbf X^H
$$

这些 overlapping subarrays 不是独立采集，而是利用阵列空间平移构造 pseudo-snapshots。

## 2.2 Axial / temporal covariance averaging

本章最初只用 spatial smoothing，完整二维 MVDR 图像出现明显 pixel-to-pixel 权重波动。

当前核心实现默认再使用邻近 axial samples 增加 covariance snapshots：

~~~text
spatial subarrays
        ×
neighboring axial samples
        ↓
covariance estimate
~~~

默认半窗：

~~~text
axial_averaging_lambda = 1.5
~~~

邻近深度只用于估 covariance；当前 pixel 最终幅度仍由当前深度 aperture 计算，不是直接做图像轴向平滑。

## 2.3 Diagonal loading

有限 snapshots、overlap、噪声和模型误差都会让 covariance ill-conditioned。

本章使用：

$$
\mathbf R_{loaded}
=
\mathbf R+
\delta\frac{\mathrm{tr}(\mathbf R)}{L}\mathbf I
$$

默认：

~~~text
diagonal_loading = 0.01
~~~

它可以理解成给很小的 eigenvalues 加一个 floor，防止 covariance inversion 对估计误差过度敏感。

---

# 3. Manual implementation

## 3.1 Conventional FI

核心：

~~~text
matlab/03_MVDR/reconstruct_fi_mvdr_manual.m
~~~

主入口：

~~~matlab
cd matlab/03_MVDR
compare_manual_das_vs_mvdr
~~~

默认：

~~~text
Rx F#                 = 1.7
L/M                   = 0.5
diagonal loading      = 0.01
axial averaging       = +/- 1.5 lambda
forward-backward      = false
~~~

## 3.2 RTB + receive-MVDR

核心：

~~~text
reconstruct_fi_rtb_mvdr_manual.m
~~~

RTB-DAS 和 RTB-MVDR 使用完全相同的 Tx delay、Tx support/apodization、Rx F-number、reconstruction grid 和 cross-Tx coherent combination，只改变 receive combination。

---

# 4. 已验证实验结果

## 4.1 Conventional FI

仅使用 spatial smoothing 时，完整二维 MVDR 图像存在明显 covariance instability。加入 axial covariance averaging 后稳定性明显改善。

1.5 lambda 与更大的 axial averaging window 在 point-target 图像上没有根本差异，因此当前主要限制已经不是 snapshot 数量。

## 4.2 Dense-grid RTB point target

最终 dense-grid 结果：

~~~text
lateral spacing = 0.0250 mm
axial spacing   = 0.0250 mm

                       RTB-DAS      RTB-MVDR
lateral FWHM            0.7063 mm    0.1238 mm
axial FWHM              0.4231 mm    0.4071 mm
lateral -20 dB width    1.1482 mm    0.4617 mm

MVDR lateral FWHM / dx = 4.953 samples
MVDR peak vs DAS       = -2.893 dB
MVDR fallback          = 0%
~~~

因此可以确认：

> **非常强的 lateral adaptive narrowing 不是单纯 conventional-FI scanline undersampling 造成的。**

但不能把 0.706 -> 0.124 mm 直接写成“物理分辨率提高约 5.7 倍”。同时存在约 -2.9 dB target peak loss，说明当前 MVDR 已经存在 target self-suppression / steering mismatch 风险。

更准确的结论是：

> **MVDR 对 point-target profile 产生强烈 lateral adaptive narrowing 和 lateral-skirt suppression，但这种 narrowing 不是无代价的。**

## 4.3 In-vivo carotid

使用 compare_carotid_rtb_das_vs_rtb_mvdr.m 对真实 carotid 做 RTB-DAS vs RTB-MVDR。

在 wave_stride=2 和 wave_stride=1 两种情况下，最终 B-mode morphology 都只表现出有限差异。

观察到：

- lumen / 局部组织幅度存在 adaptive change；
- 部分局部结构有 suppression / sharpening；
- 没有出现 point-target 实验中同等量级的明显结构改善；
- 整体 vessel-wall morphology 与 RTB-DAS 相近；
- “更黑 / 更锐”不能自动解释为更正确。

因此：

> **MVDR 在理想 point target 上的强 adaptive narrowing，不会等比例转化成真实人体 B-mode 图像中的明显结构优势。**

---

# 5. 两个真正值得知道的后续算法

本项目不继续实现大量 MV variants，只保留 EIBMV 和 RCB 两个真正有新概念的方向。

## 5.1 EIBMV / ESMV：Eigenspace-Based Minimum Variance

普通 MVDR 得到 w_MVDR，同时 covariance 可做特征分解：

$$
\mathbf R=\mathbf E\mathbf \Lambda\mathbf E^H
$$

根据 eigenvalue threshold 选择主要 signal subspace E_s。

一个常见 EIBMV 思路是把 MVDR weight 投影到 signal subspace：

$$
\mathbf w_{EIBMV}
=
\mathbf E_s\mathbf E_s^H\mathbf w_{MVDR}
$$

实际实现通常还需要 normalization 和 signal-subspace threshold rule。

直觉：

~~~text
普通 MVDR
→ covariance 中所有方向都可能影响 weights

EIBMV
→ 先判断哪些 eigen-directions 属于主要 signal subspace
→ 再限制 MVDR weights 主要留在这些方向
~~~

它主要回答：

> **covariance 中哪些 eigen-directions 值得相信？**

潜在收益是减少 noise-subspace contribution 和某些不稳定 adaptive weights；代价是 eigendecomposition 和新的 threshold 参数。

本项目到这里认识原理即可，不再增加完整 EIBMV 实验。

## 5.2 RCB：Robust Capon Beamforming

普通 MVDR 假设 nominal steering vector：

$$
\mathbf a_0=[1,1,\ldots,1]^T
$$

是准确的。

真实 delay-aligned target 可能更像：

$$
\mathbf a_{true}
=
[1,e^{j\phi_2},e^{j\phi_3},\ldots]^T
$$

原因可能包括 sound-speed mismatch、phase aberration、RTB Tx model mismatch、probe geometry / calibration error 和 interpolation error。

普通 MVDR 只保证：

$$
\mathbf w^H\mathbf a_0=1
$$

并不保证真实 a_true 也能 unit-gain 通过，所以可能出现 target self-suppression。

RCB 的核心思想是不再把 steering vector 当成绝对准确的点，而是允许：

$$
\mathbf a_{true}\in\mathcal A(\mathbf a_0)
$$

即真实 steering vector 位于 nominal vector 周围的 uncertainty set 内。

它主要回答：

> **如果 steering vector 本身不完全正确，怎样避免 MVDR 把真正目标也当成干扰压掉？**

这与本章 point-target 中观察到的约 -2.9 dB peak loss 直接对应。

RCB 的代价是优化问题和 uncertainty-set 参数选择更复杂。本项目只保留这一核心思想，不继续实现 RCB。

---

# 6. Chapter 3 最终总结

这一章最终应该记住 8 点：

1. **DAS 与 MVDR 的真正区别是 receive-channel weights：DAS 基本固定，MVDR 由 data covariance 自适应决定。**
2. **MVDR 不是 DAS 后处理，而是在 channel-combination 阶段直接替代等权求和。**
3. **理论 covariance 是 R=E{xx^H}；有限超声数据需要 spatial smoothing 和 axial/temporal averaging 去近似这个统计期望。**
4. **Diagonal loading 是 covariance regularization：防止很小、不可靠的 eigenvalues 在 inversion 后被极度放大。**
5. **a=ones 不是天然真理，而是 delay alignment 正确时的 nominal steering model。**
6. **MVDR 在 dense-grid point target 上确实产生很强的 lateral adaptive narrowing，但同时有明显 target peak loss，不能把 FWHM narrowing 直接等同于无代价的物理分辨率提升。**
7. **真实 carotid 上 RTB-MVDR 相比 RTB-DAS 的最终 B-mode morphology 改变有限，说明 point-target 优势不能直接外推到 in-vivo tissue。**
8. **EIBMV 主要解决“哪些 covariance eigen-directions 值得相信”，RCB 主要解决“steering vector 不准确怎么办”。**

---

# 7. 代码入口

~~~text
matlab/03_MVDR/
│
├─ reconstruct_fi_mvdr_manual.m
│    conventional-FI receive-domain MVDR core
│
├─ compare_manual_das_vs_mvdr.m
│    完整二维 DAS vs MVDR
│
├─ experiment_mvdr_tradeoffs.m
│    L/M 与 diagonal loading 的可选参数实验
│
├─ reconstruct_fi_rtb_mvdr_manual.m
│    RTB-DAS + RTB receive-MVDR core
│
├─ compare_rtb_das_vs_rtb_mvdr.m
│    dense-grid point-target validation
│
├─ compare_carotid_rtb_das_vs_rtb_mvdr.m
│    in-vivo carotid robustness check
│
└─ README.md
~~~

核心实现：

~~~text
reconstruct_fi_mvdr_manual.m
reconstruct_fi_rtb_mvdr_manual.m
~~~

最重要验证：

~~~text
compare_rtb_das_vs_rtb_mvdr.m
compare_carotid_rtb_das_vs_rtb_mvdr.m
~~~

Chapter 3 到这里结束，不继续堆 MVDR variants。

---

# 8. 下一章

下一章进入：

> **DMAS / fDMAS**

MVDR 的核心是 covariance-driven adaptive linear weighting。

DMAS 则进入另一条路线：

> **利用 channel-pair multiplication 构造非线性 beamforming response。**