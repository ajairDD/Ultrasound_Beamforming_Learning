# Ultrasound Beamforming Learning

一个以 **医学超声经典波束合成** 为主线的公开学习项目。

目标不是收集尽可能多的算法名字，而是从真实 channel data 出发，逐步理解：

> **空间位置 → 传播距离 → Tx/Rx delay → 通道相位一致性 → aperture / weighting → beamformed pixel**

并在同一套 MATLAB 框架中实现和比较 DAS、CF、MV/MVDR、DMAS、SLSC、NSI 等经典方法。

---

## 项目当前状态

| 章节 | 内容 | 状态 |
|---|---|---|
| 第 0 章 | 波束合成共同基础：Delay、channel data、PSF、aperture、F-number、apodization、axial/lateral resolution、DAS failure modes | **已完成** |
| 第 1 章 | 在真实 UFF channel data 上从零实现 DAS | **进行中** |
| 第 2 章 | CF / GCF：coherence weighting | 计划中 |
| 第 3 章 | MV / MVDR / Capon：adaptive channel weighting | 计划中 |
| 第 4 章 | DMAS / fDMAS：nonlinear inter-channel interaction | 计划中 |
| 第 5 章 | SLSC：直接以 spatial coherence 成像 | 计划中 |
| 第 6 章 | NSI：利用 beam-pattern null | 计划中 |
| 第 7 章 | 统一 benchmark 与方法比较 | 计划中 |

---

## 从哪里开始

### 1. 第一次学习 beamforming

先读：

**[第 0 章：波束合成共同基础](./chapters/00_Fundamentals/README.md)**

然后按顺序运行：

~~~matlab
cd matlab/00_Fundamentals

demo_synthetic_point_target
demo_delay_alignment
demo_aperture_psf_apodization
demo_axial_lateral_2d_psf
demo_das_failure_modes
~~~

这些脚本：

- 不需要 USTB；
- 不需要外部数据；
- 不依赖第三方 MATLAB toolbox；
- 用最小 synthetic model 建立 Delay、PSF、aperture、相干叠加和失效机制的直觉。

### 2. 准备进入真实数据 DAS

阅读：

**[第 1 章：真实 UFF Channel Data 上的 DAS](./chapters/01_DAS_Real_UFF/README.md)**

推荐第一套数据：

<code>data/L7_FI_Verasonics_CIRS_points.uff</code>

当前第 1 章已经提供数据检查脚本：

~~~matlab
cd matlab/01_DAS_Real_UFF

inspect_uff_hdf5
inspect_uff_metadata_ustb
plot_raw_channel_overview_ustb
~~~

其中：

- <code>inspect_uff_hdf5.m</code>：**不需要 USTB**，只查看 UFF/HDF5 结构；
- 后两个脚本需要 USTB，用于可靠读取 UFF 的 channel/probe/sequence 语义。

> 第 1 章的正式 DAS reconstruction 将由我们自己用 MATLAB 实现。USTB 主要用于 UFF 读取和参考核对，不把 USTB 内置 beamformer 当作我们的算法实现。

---

## 仓库结构

~~~text
Ultrasound_Beamforming_Learning/
├── README.md
├── chapters/
│   ├── 00_Fundamentals/
│   │   └── README.md
│   └── 01_DAS_Real_UFF/
│       └── README.md
├── matlab/
│   ├── README.md
│   ├── 00_Fundamentals/
│   │   ├── README.md
│   │   ├── demo_synthetic_point_target.m
│   │   ├── demo_delay_alignment.m
│   │   ├── demo_aperture_psf_apodization.m
│   │   ├── demo_axial_lateral_2d_psf.m
│   │   └── demo_das_failure_modes.m
│   └── 01_DAS_Real_UFF/
│       ├── README.md
│       ├── inspect_uff_hdf5.m
│       ├── inspect_uff_metadata_ustb.m
│       └── plot_raw_channel_overview_ustb.m
└── data/
    ├── README.md
    └── .gitignore
~~~

原始 UFF 数据体积较大，不直接提交到 GitHub。下载来源、MD5 和各数据用途见：

**[data/README.md](./data/README.md)**

---

## 贯穿整个项目的统一框架

设候选像素为

$$
\mathbf r=(x,z),
$$

第 $m$ 个阵元记录信号为 $x_m(t)$。

传播模型给出：

$$
\tau_m(\mathbf r)
=
\tau_{\mathrm{TX}}(\mathbf r)
+
\tau_{\mathrm{RX},m}(\mathbf r).
$$

在相应时间取样：

$$
s_m(\mathbf r)
=
x_m\!\left(\tau_m(\mathbf r)\right).
$$

形成 delay 后的 aperture vector：

$$
\mathbf s(\mathbf r)
=
[s_1(\mathbf r),\ldots,s_M(\mathbf r)]^T.
$$

之后各种 beamformer 的核心问题就是：

$$
\boxed{
\mathbf s(\mathbf r)
\longrightarrow
y(\mathbf r)
}
$$

DAS：

$$
y_{\mathrm{DAS}}
=
\sum_m w_m s_m.
$$

CF 会进一步估计通道相干性；MV/MVDR 根据数据统计自适应求权重；DMAS 显式利用通道两两关系；SLSC 直接把 spatial coherence 作为成像量；NSI 利用特殊 aperture / beam-pattern null。

---

## 本项目的实现原则

### 科学正确性优先于“代码能跑”

每个真实数据算法至少检查：

- array shape 与每个 axis 的物理意义；
- real RF / complex IQ；
- Hz / MHz、s / µs、m / mm；
- sampling frequency 与 initial time；
- probe / element coordinates；
- transmit sequence；
- Tx / Rx delay convention；
- interpolation；
- aperture / apodization；
- coherent / incoherent combination；
- amplitude / power / dB；
- envelope / log compression。

### Acquisition 与 Beamformer 分开

~~~text
PW / FI / DW / STA
≠
DAS / CF / MV / DMAS / SLSC / NSI
~~~

发射方式决定传播模型的一部分，beamformer 决定 delay 后通道如何组合。

### 比较必须公平

比较不同算法时尽量固定：

- 同一份 channel data；
- 同一 imaging grid；
- 同一 Tx/Rx geometry；
- 同一 normalization；
- 同一 envelope / log compression；
- 同一 display dynamic range；
- 同一评价指标。

---

## 数据

当前仓库的数据清单覆盖：

- Focused Imaging；
- Plane Wave / CPWC；
- Diverging Wave；
- Synthetic Transmit Aperture；
- point target；
- hypoechoic / contrast / speckle phantom；
- in-vivo carotid。

第一阶段优先使用：

~~~text
L7_FI_Verasonics_CIRS_points.uff
~~~

因为点靶最适合检查：

- delay 是否正确；
- target localization；
- lateral / axial PSF；
- FWHM；
- sidelobe；
- interpolation；
- aperture / apodization。

---

## 学习主线

这个项目不会把经典方法强行排成：

~~~text
DAS → CF → MV → DMAS → SLSC → NSI
~~~

更准确的理解是：它们是围绕 DAS 暴露出来的不同问题形成的平行路线。

~~~text
                         delayed aperture vector s(r)
                                   │
              ┌────────────────────┼─────────────────────┐
              │                    │                     │
        coherence route      adaptive route      nonlinear route
          CF / SLSC          MV / MVDR            DMAS
              │                    │                     │
              └────────────────────┼─────────────────────┘
                                   │
                         beam-pattern / null route
                                  NSI
~~~

每学习一个新算法，我们都会重复回答五个问题：

1. Delay 模型是否改变？
2. 它改变的是 channel weighting、pixel weighting、inter-channel combination，还是成像量本身？
3. 它额外利用了什么信息？
4. 它试图解决 DAS 的哪个具体问题？
5. 它的代价、假设和 failure mode 是什么？

---

## MATLAB

本项目算法实践统一使用 MATLAB。

代码入口：

**[matlab/README.md](./matlab/README.md)**

第 0 章代码全部自包含。第 1 章开始接触 UFF 时，USTB 是推荐依赖，但我们会明确区分：

- **USTB 用来读取/解释 UFF 数据；**
- **本项目自己实现的 beamformer；**
- **USTB 结果作为可能的 reference，而不是黑盒替代实现。**

---

## 当前下一步

第 0 章已经完成。

下一步进入：

> **第 1 章：在真实 UFF channel data 上，从数据检查开始，自己写出可验证的 MATLAB DAS baseline。**
