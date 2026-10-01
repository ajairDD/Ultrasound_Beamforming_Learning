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