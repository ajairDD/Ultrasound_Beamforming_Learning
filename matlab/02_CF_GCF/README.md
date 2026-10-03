# Chapter 2 MATLAB：CF / GCF

默认真实数据：

~~~text
../../data/L7_FI_TheGB.uff
~~~

本章第一阶段只研究 receive-domain coherence。

## 第一课

~~~matlab
demo_cf_aperture_vectors
~~~

不需要 USTB。

目的不是成像，而是先理解一个 pixel 的 aligned aperture vector：

~~~text
s = [s1, s2, ... , sM]
~~~

为什么：

- 同相时 CF 接近 1；
- phase 越乱 CF 越低；
- CF 与 aperture spatial spectrum 有什么关系。

后续再进入真实 UFF 的 Manual CF / GCF。

---

## 第二课：真实 aligned aperture vector

运行：

~~~matlab
addpath('../01_DAS_Real_UFF');
inspect_real_cf_aperture_vectors
~~~

脚本流程：

~~~text
Chapter-1 conventional FI-DAS
        ↓
在图上点击 3 个 pixel
        ↓
snap 到真实 scanline / z-grid
        ↓
重新计算相同 Tx+Rx delay
        ↓
fractional interpolation
        ↓
active receive aperture
        ↓
真实 aligned complex aperture vector
        ↓
CF / phasor / aperture FFT
~~~

每个点还会验证：

~~~text
sum(aligned active samples)
==
Chapter-1 DAS complex pixel
~~~

默认使用 Rx F# = 1.7。

这一课仍然不做完整 CF 图像；目标是先把真实数据中的 aligned aperture vector 物理含义彻底看清楚。
---

## 第三课：整张 Manual CF 图像

核心函数：

~~~text
reconstruct_fi_cf_manual.m
~~~

对比入口：

~~~matlab
addpath('../01_DAS_Real_UFF');
compare_manual_das_vs_cf
~~~

输出包括：

~~~text
das_analytic
das_envelope
das_db

cf_map

cf_analytic
cf_envelope
cf_db_self
cf_db_common
~~~

`cf_db_common` 使用 DAS peak 作为共同参考，用来看真实 suppression。

`cf_db_self` 使用 CF 图自己的 peak，用来看 morphology。

脚本还会重新调用 Chapter 1 DAS，并验证 Chapter 2 内部的 DAS 没有发生变化。
---

## 第四课：DAS vs CF point-target profile

运行：

~~~matlab
analyze_das_vs_cf_point_target
~~~

点击一个相对孤立的 point-like target。

输出：

~~~text
peak location / shift
target peak attenuation
lateral -6 dB FWHM
axial -6 dB FWHM
lateral -20 dB width
axial -20 dB width
~~~

注意：conventional FI lateral sampling 较粗；若 FWHM 跨少于 3 个 scanline intervals，只能把横向宽度当作 sampling-limited 粗估。

-20 dB width 只用于观察 profile skirt，不作为严格 sidelobe metric。
---

## 第五课：CF 的局限与 GCF 动机

运行：

~~~matlab
demo_cf_failure_and_gcf_motivation
~~~

比较：

~~~text
Perfect coherence
Smooth 1-bin phase ramp
Random phase
~~~

教学版 GCF 使用：

~~~text
K = 0  -> only DC -> CF
K = 1  -> bins -1, 0, +1
K = 2  -> bins -2 ... +2
~~~

重点理解：

~~~text
CF 低
并不一定等于
aperture 完全随机不相干
~~~

一个平滑 phase ramp 也可能让 DC 能量很低，但其能量仍集中在邻近 low spatial-frequency bins。

后续正式 GCF 实现时，会再明确教学参数 K 与 USTB / 文献 M0 convention 的对应关系。
---

## 第六课：完整 Manual GCF

核心：

~~~text
reconstruct_fi_gcf_manual.m
~~~

对比入口：

~~~matlab
M0 = 1;
compare_manual_das_cf_gcf
~~~

正式 Manual GCF 使用统一的 low-frequency half-width `M0`：

~~~text
M0 = 0 -> DC only -> CF
M0 = 1 -> bins -1,0,+1
M0 = 2 -> bins -2...+2
M0 = 4 -> bins -4...+4
~~~

USTB 当前实现对 `M0=1` 有 legacy special case；后续做 reference validation 时单独映射，不改变本项目主定义。

脚本会验证：

~~~text
CF core DAS == GCF core DAS
GCF(M0=0) == CF
~~~

然后显示 DAS / CF / GCF 的 common-reference 图像和权重图。
---

## 第七课：GCF M0 参数扫描

运行：

~~~matlab
experiment_gcf_m0_sweep
~~~

默认比较：

~~~text
M0 = [0 1 2 4]
~~~

其中：

~~~text
M0=0 -> CF
M0=1 -> 3-bin GCF
M0=2 -> 5-bin GCF
M0=4 -> 9-bin GCF
~~~

参数扫描默认 `n_z=256` 以缩短运行时间。

先用它看趋势；确定感兴趣的 M0 后，再用 `compare_manual_das_cf_gcf` 以 `n_z=512` 做正式比较。
---

## 第八课：point target 上比较 M0

运行：

~~~matlab
analyze_gcf_m0_point_target
~~~

默认：

~~~text
M0 = [0 1 2]
n_z = 512
~~~

对应：

~~~text
M0=0 -> CF
M0=1 -> 3-bin GCF
M0=2 -> 5-bin GCF
~~~

输出 point-target peak、FWHM 和 -20 dB profile width，用来量化从严格 CF 到更宽松 GCF 的变化。

另外，`reconstruct_fi_gcf_manual.m` 已修正短 active aperture 的边界处理：requested M0 过大时会裁剪到当前 aperture 能支持的最大 unique symmetric FFT band，而不是把 GCF 权重直接设成 0。
---

## 第九课：homogeneous speckle ROI

运行：

~~~matlab
analyze_gcf_speckle_roi
~~~

在 DAS 图上点击两个对角点选择一块均匀 speckle 区域。

输出：

~~~text
mean_vs_DAS_dB
std_vs_DAS
speckle_SNR
CV
corr_with_DAS
~~~

以及 common-reference ROI 图和 mean-normalized envelope histogram。

目的：定量观察 CF / GCF 在 suppress background 的同时，改变了多少原始 speckle texture。