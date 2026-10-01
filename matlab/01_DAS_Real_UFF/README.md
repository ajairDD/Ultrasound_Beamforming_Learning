# Chapter 1 MATLAB：Real UFF FI-DAS / RTB

本目录只保留第 1 章教学主线代码。

默认数据：

~~~text
../../data/L7_FI_TheGB.uff
~~~

USTB 用于 UFF 读取和 reference validation；Manual beamformer 的核心计算由本项目显式实现。

---

## 文件说明

| 文件 | 作用 |
|---|---|
| `inspect_uff_hdf5.m` | 不依赖 USTB，只查看 UFF/HDF5 结构 |
| `inspect_uff_metadata_ustb.m` | 检查 shape、RF/IQ、fs、initial_time、probe、sequence、wave.delay |
| `plot_raw_channel_overview_ustb.m` | 查看一个 wave 的原始 channel data |
| `demo_fi_geometry_and_sampling.m` | 从真实 metadata 画几何、Tx 时间、Tx/Rx 权重，再演示非整数取样 |
| `reconstruct_fi_scanline_manual.m` | conventional FI-DAS 核心 |
| `das_fi_scanline_manual.m` | conventional FI-DAS 直接运行入口 |
| `validate_manual_vs_ustb.m` | Manual conventional DAS vs USTB reference |
| `analyze_point_target_psf.m` | 交互选择或给定搜索起点，测 point-like object 的 lateral/axial FWHM |
| `compare_receive_aperture_full_vs_fnumber.m` | Full Rx vs dynamic F-number |
| `reconstruct_fi_rtb_manual.m` | Manual RTB 核心 |
| `compare_conventional_vs_rtb.m` | Conventional / display interpolation / RTB 三方比较 |
| `compare_rtb_spherical_plane_blended.m` | **重点教学实验**：All spherical / All plane / Blended 三种 Tx-delay model 对比 |
| `validate_manual_rtb_vs_ustb.m` | Manual RTB vs USTB reference |
| `experiment_rtb_parameter_sweep.m` | RTB 单因素参数实验 |
| `export_chapter1_figures.m` | 非交互复现课程 PNG 和运行记录，可导出全部或指定实验 |

---

## 最短运行路径

~~~matlab
addpath(genpath('D:/USTB'));  % 改成你的路径
cd matlab/01_DAS_Real_UFF

filename = '../../data/L7_FI_TheGB.uff';

inspect_uff_metadata_ustb
plot_raw_channel_overview_ustb
demo_fi_geometry_and_sampling
das_fi_scanline_manual
validate_manual_vs_ustb

analyze_point_target_psf
compare_receive_aperture_full_vs_fnumber

compare_conventional_vs_rtb

% 重点：理解为什么不能全 spherical / 全 plane
compare_rtb_spherical_plane_blended

delay_model = 'blended';
validate_manual_rtb_vs_ustb
~~~

---

## Conventional core

~~~matlab
opts = struct();
opts.z_min = 5e-3;
opts.z_max = 45e-3;
opts.n_z = 1024;
opts.receive_aperture_mode = 'f_number';
opts.receive_f_number = 1.7;

result = reconstruct_fi_scanline_manual(filename,opts);
~~~

主要输出：`das_analytic`、`envelope`、`image_db`、`x_axis`、`z_axis`、`active_channel_count`。

---

## RTB core

教学主线默认使用 blended Tx-delay model。它以连续权重混合 spherical 与 plane；离轴焦深处仍可能有残余延时跳变，推导和数值图见 [教程第 11 节](../../chapters/01_DAS_Real_UFF/README.md#tx-delay-models)。初次学习请先读教程第一部分的完整算法主线，再查本目录的实现参数。

~~~matlab
opts = struct();
opts.z_min = 5e-3;
opts.z_max = 45e-3;
opts.n_z = 512;
opts.x_upsample = 4;

opts.tx_delay_model = 'blended';
opts.blending_power = 0.5;

% 教学对照还可以设为：
% opts.tx_delay_model = 'spherical';
% opts.tx_delay_model = 'plane';   % 仅用于教学，不推荐作为正式 RTB
opts.tx_f_number = 2;
opts.tx_min_aperture = 3e-3;
opts.tx_window = 'tukey25';

opts.rx_aperture_mode = 'f_number';
opts.rx_f_number = 1.7;

result = reconstruct_fi_rtb_manual(filename,opts);
~~~

主要输出：`rtb_analytic`、`envelope`、`image_db`、`x_axis`、`z_axis`、`tx_weight_sum`、`active_tx_count`。

---

## 参数实验

~~~matlab
experiment = 'delay_model';
experiment_rtb_parameter_sweep
~~~

也可测试 `x_upsample`、`tx_fnumber`、`tx_min_aperture`、`pw_margin`、`rx_fnumber`、`wave_stride`、`blending_power`。

一次只改一个因素。参数探索先用较低 `n_z`，确认趋势后再提高 grid density。

---

## 保持教学主线纯净

本目录不保留针对某一异常数据集的 timing repair、edge-darkening diagnosis、acquisition-specific hypothesis 或临时 audit code。若以后遇到异常 acquisition，应放到独立研究分支处理，而不是污染通用教学实现。

---

## RTB Tx-delay 三模型教学实验

运行：

~~~matlab
compare_rtb_spherical_plane_blended
~~~

它只改变 Tx delay model，其余条件全部固定。

三种模型：

~~~text
spherical
plane      <- teaching-only
blended    <- Chapter 1 baseline
~~~

建议重点看：

1. 完整 B-mode 形态；
2. 使用统一 blended peak 的亮度比较；
3. 焦点深度附近放大；
4. spherical / plane 相对 blended 的 difference map。

这个实验用于建立直觉，并与 `demo_fi_geometry_and_sampling` 中的 Tx 时间曲线一起读：

~~~text
spherical：保留离轴曲率，但在焦深处有正负切换
plane：绕开该切换，但全图使用会忽略离轴曲率
blended：用连续权重混合二者；权重连续不等于最终延时处处连续
~~~

权重使用 `sqrt(x.^2+z.^2)` 与 `wave.source.distance` 的差，不是只用像素到焦点的距离。三模型的差异图以 blended 为比较参考，不是独立真值。

---

## 课程配图复现

在独立 MATLAB 会话中加入 USTB 与本目录后运行：

~~~matlab
export_chapter1_figures                 % 全部实验和 reference
export_chapter1_figures('experiments')  % 实验图
export_chapter1_figures('references')   % 两组 reference
% 也可只重新导出某个实验：
export_chapter1_figures('compare_rtb_spherical_plane_blended')
~~~

输出位于 `chapters/01_DAS_Real_UFF/figures/`，同名 PNG 与对应运行记录会更新。导出入口设定 frame 1、5–45 mm 深度范围，以及从真实图像选取的目标搜索起点 `(-0.75,20.05)` mm；各实验的 `n_z` 不同，详见 [配图索引与运行参数](../../chapters/01_DAS_Real_UFF/figures/README.md)。AI 概念插图不由 MATLAB 导出入口生成。
