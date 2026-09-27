# MATLAB Code

本项目所有算法实践统一使用 MATLAB。

代码按“学习章节”组织，而不是按函数类型拆得很散。

---

## 目录

~~~text
matlab/
├── 00_Fundamentals/
│   ├── README.md
│   ├── demo_synthetic_point_target.m
│   ├── demo_delay_alignment.m
│   ├── demo_aperture_psf_apodization.m
│   ├── demo_axial_lateral_2d_psf.m
│   └── demo_das_failure_modes.m
└── 01_DAS_Real_UFF/
    ├── README.md
    ├── inspect_uff_hdf5.m
    ├── inspect_uff_metadata_ustb.m
    └── plot_raw_channel_overview_ustb.m
~~~

---

## 第 0 章：零依赖教学实验

进入：

~~~matlab
cd matlab/00_Fundamentals
~~~

按顺序运行：

~~~matlab
demo_synthetic_point_target
demo_delay_alignment
demo_aperture_psf_apodization
demo_axial_lateral_2d_psf
demo_das_failure_modes
~~~

特点：

- 不需要 USTB；
- 不需要下载数据；
- 不依赖第三方 toolbox；
- 每个脚本自包含，方便单独阅读；
- 重复一些基础代码是有意设计，避免初学阶段为了复用而引入过度抽象。

对应讲义：

**[chapters/00_Fundamentals](../chapters/00_Fundamentals/README.md)**

---

## 第 1 章：真实 UFF DAS

进入：

~~~matlab
cd matlab/01_DAS_Real_UFF
~~~

先做：

~~~matlab
inspect_uff_hdf5
inspect_uff_metadata_ustb
plot_raw_channel_overview_ustb
~~~

本章后续会加入真正的：

- UFF loader / validation；
- imaging grid；
- Tx delay；
- Rx delay；
- interpolation；
- aperture / apodization；
- DAS reconstruction；
- envelope / log；
- PSF metrics。

对应讲义：

**[chapters/01_DAS_Real_UFF](../chapters/01_DAS_Real_UFF/README.md)**

---

## 代码风格约定

### 1. 物理量优先写清单位

例如：

~~~matlab
c = 1540;           % [m/s]
fs = 40e6;          % [Hz]
pitch = 0.30e-3;    % [m]
~~~

### 2. shape 必须能解释

真实 UFF 数据不会因为“程序能索引”就自动认为维度正确。

至少要确认：

~~~text
samples
channels
waves
frames
~~~

分别对应哪个 axis。

### 3. complex phase 不随意丢

如果输入是 complex IQ：

> 在 coherent beamforming 完成前，不会为了“方便”先取 abs(IQ)。

### 4. normalization 与 dB 明确

~~~text
amplitude → 20log10
power     → 10log10
~~~

### 5. 先保证科学正确，再优化速度

第一版算法允许写得显式。

只有在 delay、shape、unit 和 reference 都核对以后，才进行：

- vectorization；
- precomputation；
- GPU；
- MEX；
- parallelization。

---

## MATLAB 版本与依赖

第 0 章尽量只使用 base MATLAB。

第 1 章读取 UFF 时推荐安装：

- USTB

但 USTB 不是第 0 章的前置条件，也不会替代本项目自己实现的 beamformer。
