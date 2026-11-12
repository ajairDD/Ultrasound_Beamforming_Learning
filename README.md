# Ultrasound Beamforming Learning

一个以 **医学超声经典波束合成** 为主线的公开学习项目。算法代码统一使用 MATLAB。

核心目标：从真实 channel data 出发，理解

> **空间位置 → Tx/Rx delay → fractional-sample interpolation → aperture / weighting → coherent sum → PSF / image quality**

---

## PDF 课堂讲义

已完成的第 0–4 章各有一份 PDF，包含目录、公式、完整正文与补充课件图。全部配图说明已汉化，保留方法缩写、数学符号、代码标识与单位。

独立配图文件仅保存在本地，中英文版本均不纳入 Git。GitHub 上请阅读下方 PDF 获取完整图文；章节 Markdown 的图片预览和 PDF 重建需要本地配图，生成方法与提示词见构建说明。

| 章节 | PDF |
|---|---|
| 第 0 章 | [波束合成共同基础](output/pdf/第00章_波束合成共同基础.pdf) |
| 第 1 章 | [FI-DAS 与 RTB](output/pdf/第01章_FI-DAS与RTB.pdf) |
| 第 2 章 | [CF 与 GCF](output/pdf/第02章_CF与GCF.pdf) |
| 第 3 章 | [MVDR](output/pdf/第03章_MVDR.pdf) |
| 第 4 章 | [DMAS 与 fDMAS](output/pdf/第04章_DMAS与fDMAS.pdf) |

[构建与配图汉化说明](tools/pdf/README.md)

---

## 学习路线

| 章节 | 内容 | 状态 |
|---|---|---|
| 第 0 章 | Delay、channel data、PSF、aperture、F-number、apodization、axial/lateral resolution、DAS failure modes | 已完成 |
| 第 1 章 | 真实 UFF 上的 conventional FI-DAS 与 RTB | **已完成** |
| 第 2 章 | CF / GCF | **已完成** |
| 第 3 章 | MV / MVDR / Capon | **已完成** |
| 第 4 章 | DMAS / fDMAS | **已完成** |
| 第 5 章 | SLSC | **已完成** |
| 第 6 章 | NSI | **进行中** |
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
## 第 4 章

阅读：**[第 4 章：DMAS / fDMAS](./chapters/04_DMAS/README.md)**

本章已完成“原理 → 一次完整二维实验 → 总结”：

~~~matlab
cd matlab/04_DMAS
compare_fi_das_vs_fdmas
~~~

核心是 real-RF signed-sqrt DMAS、约 `2*f0` 的带通后形成 fDMAS，以及正确的输出轴向采样检查。

TheGB 实验观察到：部分点目标横向响应被压低，但 fDMAS speckle 更颗粒化；**不能把局部 profile 变化直接等同于整体成像质量提升**。代码会检查快速 DMAS 恒等式和 Chapter-1 DAS reference，一次性实验足够完成本章教学。

---

## 第 5 章

阅读：**[第 5 章：SLSC（Short-Lag Spatial Coherence）](./chapters/05_SLSC/README.md)**

本章按“原理主线 → 数值小例子 → TheGB 完整二维实验 → 实现注意事项”组织，包含 6 张中文 AI 概念图与 14 张可复现 MATLAB 图。独立配图只在本地保存，生成步骤见[运行说明](./matlab/05_SLSC/README.md)。

~~~matlab
cd matlab/05_SLSC
demo_slsc_building_blocks       % 无需 USTB / UFF 的八个小例子
compare_fi_das_vs_slsc
~~~

实验观察到：中央 ROI Lag 1 约 0.8901、Lag 4 约 0.5419；较大 lag 的统计像素集合发生变化，固定共同有效像素后曲线也会改变。SLSC 散斑与 DAS 幅度图明显不同。**线性相干性不等同于 dB 幅度，本次没有证据证明 SLSC 整体优于 DAS。** DAS 分支回归、逐 lag 聚合及一个真实 RF 窗口的独立复算均已实际验证。

当前实现同时保留经典 short-lag sum 和适应动态 Rx F# 的 mean-across-lags 显示约定；已修正轴向 kernel 真实跨度的文字计算，未改动实际 RF 计算过程。

---

## 第 6 章

阅读：**[第 6 章：NSI（Null Subtraction Imaging）](./chapters/06_NSI/README.md)**

本章继续按“原理 → 一次二维实验 → 总结”推进。NSI 利用 zero-mean receive apodization 构造 Null，再通过两幅 DC-offset envelope 平均后减去 ZM envelope 形成窄横向响应。

~~~matlab
cd matlab/06_NSI
compare_rtb_das_vs_nsi
~~~

默认对 TheGB 的 20.1 mm 点目标附近进行密集 RTB 二维 ROI 重建。新 NSI 核心与第 1 章 RTB-DAS 使用相同 Tx/Rx timing、Tx weights、Rx F# 与 coherent Tx compounding，脚本包含 Chapter-1 RTB 复数数据回归验证。

**代码、教学说明已提交；真实 UFF 输出尚待本地运行验证，故暂标记“进行中”。**

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

当前第 6 章 **NSI** 正在进行，完成 TheGB 二维 DAS/NSI 验证后进入 **第 7 章：统一 Benchmark**。
