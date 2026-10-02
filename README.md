# Ultrasound Beamforming Learning

一个以 **医学超声经典波束合成** 为主线的公开学习项目。算法代码统一使用 MATLAB。

核心目标：从真实 channel data 出发，理解

> **空间位置 → Tx/Rx delay → fractional-sample interpolation → aperture / weighting → coherent sum → PSF / image quality**

---

## 学习路线

| 章节 | 内容 | 状态 |
|---|---|---|
| 第 0 章 | Delay、channel data、PSF、aperture、F-number、apodization、axial/lateral resolution、DAS failure modes | 已完成 |
| 第 1 章 | 真实 UFF 上的 conventional FI-DAS 与 RTB | **已完成** |
| 第 2 章 | CF / GCF | **进行中** |
| 第 3 章 | MV / MVDR / Capon | 计划中 |
| 第 4 章 | DMAS / fDMAS | 计划中 |
| 第 5 章 | SLSC | 计划中 |
| 第 6 章 | NSI | 计划中 |
| 第 7 章 | 统一 benchmark | 计划中 |

---

## 第 0 章

阅读：**[第 0 章：波束合成共同基础](./chapters/00_Fundamentals/README.md)**

~~~matlab
cd matlab/00_Fundamentals
demo_synthetic_point_target
demo_delay_alignment
demo_aperture_psf_apodization
demo_axial_lateral_2d_psf
demo_das_failure_modes
~~~

这些脚本不需要 USTB 和外部数据。

---

## 第 1 章

阅读：**[第 1 章：真实 UFF 上的 conventional FI-DAS 与 RTB](./chapters/01_DAS_Real_UFF/README.md)**

第 1 章统一使用：

~~~text
data/L7_FI_TheGB.uff
~~~

作为默认教学数据。

USTB 负责：UFF 读取、probe / sequence 语义、reference validation。

本项目自己实现：Tx delay、Rx delay、插值、receive aperture、DAS、RTB Tx reconstruction 与跨 Tx coherent combination。

推荐运行顺序：

~~~matlab
cd matlab/01_DAS_Real_UFF
filename = '../../data/L7_FI_TheGB.uff';

inspect_uff_metadata_ustb
plot_raw_channel_overview_ustb

das_fi_scanline_manual
validate_manual_vs_ustb

analyze_point_target_psf
compare_receive_aperture_full_vs_fnumber

compare_conventional_vs_rtb
compare_rtb_spherical_plane_blended

delay_model = 'blended';
validate_manual_rtb_vs_ustb

experiment = 'delay_model';
experiment_rtb_parameter_sweep
~~~

---

## 统一数学框架

候选 pixel：

$$
\mathbf r=(x,z)
$$

总延时：

$$
\tau_m(\mathbf r)=\tau_{Tx}(\mathbf r)+\tau_{Rx,m}(\mathbf r)
$$

延时后的 aperture observation：

$$
s_m(\mathbf r)=x_m\!\left(\tau_m(\mathbf r)\right)
$$

Conventional DAS：

$$
y_{DAS}(\mathbf r)=\sum_m w_m(\mathbf r)s_m(\mathbf r)
$$

后续 CF、MV、DMAS、SLSC、NSI，本质上都在研究：

> **对齐后的 aperture data 应该怎样组合？**

---

## 科学实现原则

代码能运行不等于 beamforming 实现正确。真实数据实验至少检查：shape / axis、RF/IQ、fs / initial_time、probe geometry、transmit sequence、wave delay、Tx/Rx delay、interpolation、aperture、coherent/incoherent combination、amplitude/power/dB，以及 reference validation。

原始 UFF 数据不提交到 GitHub。下载信息、MD5 和用途见 **[data/README.md](./data/README.md)**。

---

## 下一章

第 1 章完成后，下一步进入：

**第 2 章：Coherence Factor（CF）与 Generalized Coherence Factor（GCF）**

第 0–1 章解决“如何把 channel data 按传播模型正确对齐”。

从第 2 章开始，问题变成：

> **已经对齐的 aperture data，怎样衡量通道间相干性，并利用这种相干性改善 DAS？**
