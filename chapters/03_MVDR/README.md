# 第 3 章：MV / MVDR / Capon

本章加快节奏，只保留三部分：

1. **原理 + 完整二维 Manual MVDR + DAS 对比**
2. **一次性参数实验**
3. **衍生算法与后续路线**

默认数据仍使用：

~~~text
data/L7_FI_TheGB.uff
~~~

本章先只做 conventional FI 的 **receive-domain MVDR**，不把 RTB / transmit-adaptive processing 混进来。

---

# 1. 原理：从 DAS 到 MVDR，并直接形成二维图像

## 1.1 MV、MVDR、Capon 是什么关系？

在本章语境下可以先把它们理解成同一家族，而不是三个完全不同的算法：

- **MV**：Minimum Variance，最小方差；
- **MVDR**：Minimum Variance Distortionless Response，更完整地写出了“最小方差 + 目标方向无失真”的约束；
- **Capon beamformer**：这一类方法的经典名称，超声文献和 USTB 中经常与 MV/MVDR 连用。

所以后面看到“MV image”“MVDR image”“Capon image”，先不要把它们当成三套完全不同的核心公式。

## 1.2 和 DAS 的本质差别

第 1 章 DAS 在 delay alignment 后得到：

~~~text
s = [s1, s2, ..., sM]
~~~

然后直接：

~~~text
DAS = s1 + s2 + ... + sM
~~~

也就是 active receive channels 基本等权相加。

MVDR 则问：

> **在保证真正来自当前 focal point 的信号不被削弱的前提下，怎样自动给各通道权重，使输出的总功率尽可能小？**

直觉上：

~~~text
已经 delay-aligned 的目标信号
    → 各通道应该大体同相
    → steering vector a = [1,1,...,1]^T

off-axis / sidelobe / clutter / mismatch
    → 在 aperture 上呈现不同空间结构
    → covariance 中可以被识别
~~~

MVDR 的约束是：

$$
\min_{\mathbf w}\ \mathbf w^H\mathbf R\mathbf w
\qquad
\text{s.t.}\ \mathbf w^H\mathbf a=1
$$

解为：

$$
\mathbf w=\frac{\mathbf R^{-1}\mathbf a}
{\mathbf a^H\mathbf R^{-1}\mathbf a}
$$

这里最重要的不是背公式，而是：

~~~text
DAS：权重基本预先定好

MVDR：权重由当前 aperture data 的 covariance 自适应算出来
~~~

## 1.3 为什么突然多了 covariance matrix？

CF/GCF 只需要回答“通道整体有多相干”。

MVDR 需要进一步知道：

> **哪些通道变化是一起出现的？哪些 aperture pattern 更像目标？哪些更像干扰？**

所以需要估计 channel covariance：

$$
\mathbf R=E\{\mathbf x\mathbf x^H\}
$$

但一个 pixel 只有一组 aperture vector，直接估计 covariance 很不稳定。

因此医学超声 MV 通常要做 **spatial smoothing**：把 M 个 active channels 切成很多重叠的长度 L 子阵。

例如：

~~~text
s1 s2 s3 s4 s5 s6

L = 3

x1 = [s1 s2 s3]
x2 = [s2 s3 s4]
x3 = [s3 s4 s5]
x4 = [s4 s5 s6]
~~~

把这些子阵当作多个 covariance snapshots。

代码中：

~~~matlab
X = [x1 x2 ... xP];       % [L, P]
R = (X * X') / P;         % [L, L]
~~~

## 1.4 为什么还需要 diagonal loading？

真实 ultrasound covariance 很容易病态或受模型误差影响，所以通常加：

$$
\mathbf R_{loaded}
=
\mathbf R
+
\delta\frac{\mathrm{tr}(\mathbf R)}{L}\mathbf I
$$

`delta` 越大通常越稳健，但也会让 MVDR 更接近非自适应方法；太小则更激进、更容易受 covariance estimation 和 steering mismatch 影响。

本章默认：

~~~text
subarray fraction L/M = 0.5
diagonal loading      = 0.01
~~~

这也和 USTB 常见示例中的 `L ≈ N/2`、`regCoef = 1/100` 保持同一数量级。

## 1.5 为什么代码最后还乘 M？

MVDR 约束是 unit gain。

如果所有 active channels 都是完全一致的：

~~~text
s = [A, A, A, ..., A]
~~~

标准 MVDR 输出约为 `A`，而 DAS 输出是 `M*A`。

为了让 DAS / MVDR 使用同一个 amplitude reference 做直观比较，本项目把平均子阵 MVDR 输出乘回 active-channel count `M`。

这样理想完全相干目标满足：

~~~text
Manual MVDR amplitude ≈ Manual DAS amplitude
~~~

这个缩放只统一显示/幅度 convention，不改变 MVDR 权重本身。

## 1.6 整张二维图怎么出来？

每一个 conventional-FI pixel 都完整执行：

~~~text
RF
 ↓
Tx/Rx delay
 ↓
fractional interpolation
 ↓
aligned active aperture s   [1,M]
 ├──────────────→ DAS = sum(s)
 ↓
overlapping subarrays X     [L,P]
 ↓
covariance R                [L,L]
 ↓
diagonal loading
 ↓
MVDR weights w              [L,1]
 ↓
average subarray outputs
 ↓
MVDR pixel
~~~

整幅扫描后得到：

~~~text
das_analytic   [Nz, Nscanline] complex
mvdr_analytic  [Nz, Nscanline] complex
~~~

核心代码：

~~~text
matlab/03_MVDR/reconstruct_fi_mvdr_manual.m
~~~

一键二维比较：

~~~matlab
cd matlab/03_MVDR
compare_manual_das_vs_mvdr
~~~

默认 `n_z=256`，目的是先快速看完整二维结果；如果最终需要更密的轴向显示，再设置 `n_z=512`。

脚本同时画：

~~~text
DAS
MVDR（使用 DAS peak 作为共同 0 dB reference）
~~~

以及 self-normalized morphology 对比。

> **先看 common-reference 图判断真实 amplitude suppression；再看 self-normalized 图判断形态变化。**

## 1.7 当前 Manual core 刻意没有加什么？

为了把主原理一次讲清，本节只包含：

~~~text
spatial smoothing
+
diagonal loading
+
receive-domain MVDR
~~~

暂时不加 temporal averaging、EIBMV、robust steering-vector optimization、transmit-domain MV。

这些留到第三部分统一讲。

---

# 2. 一次性实验：只看两个最关键参数

不再拆很多实验，只跑一个：

~~~matlab
experiment_mvdr_tradeoffs
~~~

只围绕 TheGB 中已经反复使用的约 20.1 mm point-like target，并缩小 depth range 以节省时间。

一次比较四个配置：

~~~text
A  L/M=0.25, loading=0.01
B  L/M=0.50, loading=0.01   ← baseline
C  L/M=0.75, loading=0.01
D  L/M=0.50, loading=0.10
~~~

这样一次就回答两个问题。

## 2.1 Subarray length L

比较 A / B / C。

通常：

~~~text
L 更长
→ 自适应空间自由度更高
→ 可能得到更窄主瓣 / 更强干扰抑制
→ 但可用于 covariance averaging 的重叠子阵数量减少
→ 对估计误差和模型失配更敏感
~~~

`L` 太短则逐渐失去 MVDR 的分辨能力，结果更接近常规加权。

## 2.2 Diagonal loading

比较 B / D。

~~~text
loading 小
→ 更依赖估计出来的 covariance
→ 更 adaptive

loading 大
→ covariance inversion 更稳定
→ steering mismatch 更不容易把目标压掉
→ 但结果通常更保守、更接近 DAS
~~~

脚本自动输出：

- common-reference MVDR target-region images；
- target peak change；
- lateral / axial FWHM；
- lateral -20 dB width；
- lateral profile。

注意 conventional FI lateral spacing 仍约为一个 Tx scanline spacing，所以非常窄的 FWHM 仍然是 sampling-limited。

---

# 3. 衍生算法：知道它们在 MVDR 上改了什么就够了

## 3.1 Spatial smoothing / diagonal loading / temporal averaging

这些首先是 **MVDR 的 covariance estimation / robustness 技术**，不必当作全新的 beamformer。

- spatial smoothing：本章已经实现；
- diagonal loading：本章已经实现；
- temporal / axial averaging：用当前 pixel 邻近深度样本继续增加 covariance snapshots，USTB 的 Capon 实现支持这一做法；
- forward-backward averaging：利用阵列对称性进一步稳定 covariance，本项目 core 已预留 `forward_backward` 开关。

## 3.2 EIBMV / ESMV：Eigenspace-Based MV

先算普通 MVDR weights，再对 covariance 做特征分解：

~~~text
R
↓ eig
signal subspace + noise subspace
↓
把 MVDR weight 投影到 signal subspace
~~~

目的通常是进一步抑制 noise / interference，同时保留主要 signal subspace。

代价是多一个 eigenvalue threshold，例如 USTB 的 EIBMV 实现使用 `gamma` 来决定 signal subspace。

这是最值得在 MVDR 之后继续学习的直接衍生算法。

## 3.3 Robust Capon Beamforming（RCB）

普通 MVDR 默认 steering vector 是准确的。

真实人体里 speed-of-sound mismatch、aberration、probe/model error 会让 `a=[1,...,1]` 不再完全正确。

RCB 不再假定 steering vector 精确已知，而是允许它在一个 uncertainty set 内变化，再求更稳健的 Capon solution。

优点：对 steering mismatch 更稳。

代价：优化问题更复杂、计算量更高。

## 3.4 LCMV

MVDR 只有一个 distortionless constraint。

LCMV（Linearly Constrained Minimum Variance）允许多个线性约束，例如：

~~~text
当前 focal direction 保持增益
+
某些方向明确形成 null
+
某些信号分量保持指定响应
~~~

它是 MVDR 从单约束到多约束的自然推广。

## 3.5 Beamspace MV

先把 element-space aperture data 投影到较低维 beamspace，再做 MV。

主要目的：

~~~text
减少 covariance 维度
降低 inversion 成本
改善有限 snapshots 下的稳定性
~~~

适合大阵元数或实时化场景。

## 3.6 本项目后续怎么走？

Chapter 3 不把所有衍生算法都实现一遍。

本章验收标准只有：

1. 能解释 DAS 与 MVDR 权重的本质区别；
2. 能从 aligned aperture data 得到 covariance；
3. 理解 subarray smoothing 与 diagonal loading 为什么必须存在；
4. 能生成完整 Manual MVDR 二维图并和 DAS 比较；
5. 能通过一次实验理解 `L` 与 loading 的 trade-off；
6. 知道 EIBMV、RCB、LCMV、Beamspace MV 分别在核心 MVDR 上改了什么。

完成这些后即可进入下一章，不继续堆 MV 变体。
---

## 2.3 RTB + receive-MVDR：解决 conventional-FI lateral undersampling

Conventional FI 中一个 Tx 只对应一个输出 scanline。前面的 MVDR point-target 结果可能已经窄到接近一个 scanline，因此仅靠 conventional-FI grid 很难判断：

~~~text
是真的 lateral mainlobe 很窄
还是
lateral sampling 太粗造成“细线”显示
~~~

因此新增 RTB 对照：

~~~text
reconstruct_fi_rtb_mvdr_manual.m
compare_rtb_das_vs_rtb_mvdr.m
~~~

核心设计是只改变 receive combination：

~~~text
same RTB Tx delay
same Tx support / Tukey weight
same Rx F#
same RTB grid
same cross-Tx coherent compounding

branch A:
aligned Rx aperture -> DAS

branch B:
aligned Rx aperture -> MVDR
~~~

所以最终比较的是：

~~~text
RTB-DAS
vs
RTB + receive-MVDR
~~~

而不是把 RTB 与 MVDR 两个因素混在一起。

### 默认快速实验

运行：

~~~matlab
compare_rtb_das_vs_rtb_mvdr
~~~

默认只重建 TheGB 中约 20.1 mm point target 的密集 ROI：

~~~text
x = -4 ~ +3 mm
z = 18 ~ 22.5 mm
n_x = 141
n_z = 181
~~~

lateral spacing 约 0.05 mm，明显细于 conventional-FI 的约 0.298 mm scanline spacing。

默认 MVDR：

~~~text
L/M = 0.5
diagonal loading = 0.01
axial averaging = +/- 1.5 lambda
~~~

### 验证设计

新 RTB+MVDR core 同时计算 RTB-DAS branch。

comparison script 默认还会调用第 1 章已经验证过的：

~~~text
reconstruct_fi_rtb_manual.m
~~~

并比较两套 RTB-DAS complex result。

只有：

~~~text
max-peak scaled complex error < 1e-10
~~~

才继续接受结果。

这一步用于确认新增 RTB+MVDR 代码没有悄悄改变：

- Tx delay；
- Rx delay；
- interpolation；
- Tx support / apodization；
- cross-Tx coherent combination。

### 当前科学问题

这个实验主要回答：

> **MVDR point target 在 dense RTB grid 上是否仍然退化成单条线。**

如果 RTB-MVDR 的 lateral FWHM 能跨多个 dense-grid samples，则之前 conventional-FI 的“细线”主要属于 lateral undersampling。

如果在 dense RTB grid 上仍然出现异常断裂或单线结构，则应继续检查 covariance / steering-vector assumptions，而不是直接解释成物理分辨率提升。