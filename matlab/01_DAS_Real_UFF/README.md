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
| `reconstruct_fi_scanline_manual.m` | conventional FI-DAS 核心 |
| `das_fi_scanline_manual.m` | conventional FI-DAS 直接运行入口 |
| `validate_manual_vs_ustb.m` | Manual conventional DAS vs USTB reference |
| `analyze_point_target_psf.m` | 交互选择 point target，测 lateral/axial FWHM |
| `compare_receive_aperture_full_vs_fnumber.m` | Full Rx vs dynamic F-number |
| `reconstruct_fi_rtb_manual.m` | Manual RTB 核心 |
| `compare_conventional_vs_rtb.m` | Conventional / display interpolation / RTB 三方比较 |
| `compare_rtb_spherical_plane_blended.m` | **重点教学实验**：All spherical / All plane / Blended 三种 Tx-delay model 对比 |
| `validate_manual_rtb_vs_ustb.m` | Manual RTB vs USTB reference |
| `experiment_rtb_parameter_sweep.m` | RTB 单因素参数实验 |

---

## 最短运行路径

~~~matlab
addpath(genpath('D:/USTB'));  % 改成你的路径
cd matlab/01_DAS_Real_UFF

filename = '../../data/L7_FI_TheGB.uff';

inspect_uff_metadata_ustb
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

教学主线默认使用 continuous blended Tx-delay model：

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

这个实验用于建立直觉：

~~~text
远离焦点：spherical 更符合波前曲率
焦点附近：local plane approximation 更稳定
blended：连续交接二者
~~~
