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
| 第 2 章 | CF / GCF | **已完成** |
| 第 3 章 | MV / MVDR / Capon | **已完成** |
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

## 第 3 章

阅读：**[第 3 章：MV / MVDR / Capon](./chapters/03_MVDR/README.md)**

本章已经完成：

~~~text
1. conventional receive-domain MVDR
2. covariance / spatial smoothing / axial averaging / diagonal loading
3. dense-grid RTB point-target validation
4. in-vivo carotid RTB-DAS vs RTB-MVDR
5. EIBMV 与 RCB 两个重要后续方向
~~~

推荐入口：

~~~matlab
cd matlab/03_MVDR

compare_manual_das_vs_mvdr
compare_rtb_das_vs_rtb_mvdr
compare_carotid_rtb_das_vs_rtb_mvdr
~~~

最终结论：MVDR 在 point target 上可以产生很强的 lateral adaptive narrowing，但在真实 carotid B-mode 上优势明显减弱；steering mismatch 和 covariance robustness 是理解 MVDR 的关键边界。

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

第 3 章完成后，下一步进入：

**第 4 章：DMAS / fDMAS**

前面章节从：

~~~text
DAS：固定线性求和
CF/GCF：DAS 后的 coherence scalar weighting
MVDR：covariance-driven adaptive linear weighting
~~~

逐步走到 adaptive linear beamforming。

下一章开始研究：

> **利用 channel-pair multiplication 构造非线性 beamforming response。**
