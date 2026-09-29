# MATLAB / 第 1 章：Real UFF DAS

对应：

**[第 1 章：在真实 UFF Channel Data 上实现 DAS](../../chapters/01_DAS_Real_UFF/README.md)**

---

## 当前代码

| 文件 | USTB | 作用 |
|---|---:|---|
| <code>inspect_uff_hdf5.m</code> | 否 | 使用 MATLAB HDF5 API 查看 UFF 文件结构 |
| <code>inspect_uff_metadata_ustb.m</code> | 是 | 第 1 步：输出完整数据契约，检查 shape、RF/IQ、timing、probe、wavefront、source、origin 和 wave.delay |
| <code>plot_raw_channel_overview_ustb.m</code> | 是 | 显示真实 channel data 的 time × channel 结构 |
| <code>reconstruct_fi_scanline_manual.m</code> | 是（仅用于读取 UFF） | **可复用的 Manual FI-DAS 核心函数**；所有真实数据实验统一调用它，显式实现 Tx/Rx delay、analytic RF、插值、aperture、coherent sum、envelope/dB |
| <code>das_fi_scanline_manual.m</code> | 是 | 面向学习者的直接运行入口；负责设置参数、调用核心函数、显示图像和 diagnostics，不再承载另一份算法实现 |
| <code>validate_manual_vs_ustb.m</code> | 是 | 在相同 x/z grid、scanline Tx、full Rx aperture 下比较 Manual DAS 与 USTB MATLAB DAS reference，输出相关系数、误差、峰值位置和差分图 |
| <code>analyze_point_target_psf.m</code> | 是（只用于重建前读取 UFF） | 交互选择孤立点靶，局部峰值细化，测量 lateral / axial -6 dB amplitude FWHM，并检查 FWHM 相对于 x/z sampling 的采样充分性 |
| <code>compare_receive_aperture_full_vs_fnumber.m</code> | 是（调用已验证的 Manual DAS） | 在完全相同的 Tx/Rx delay 与成像 grid 下，仅改变 receive aperture，对比 full aperture 与 dynamic F-number boxcar aperture 的 PSF |
| <code>reconstruct_fi_rtb_manual.m</code> | 是（仅用于读取 UFF） | **Manual RTB 核心**：pixel-based Tx/Rx delay、Tx F-number/Tukey weighting、single-Tx Rx-DAS、跨 Tx coherent sum 与 overlap normalization |
| <code>compare_conventional_vs_rtb.m</code> | 是 | Conventional FI、纯 lateral interpolation、Hybrid RTB 三方对比，区分“采样变密”和“真正重新利用 RF/Tx dimension” |
| <code>validate_manual_rtb_vs_ustb.m</code> | 是 | Manual Hybrid RTB vs USTB Hybrid RTB 数值交叉验证 |
| <code>experiment_rtb_parameter_sweep.m</code> | 是 | 一次只改变一个 RTB 参数：delay model、x upsample、Tx/Rx F#、minimum aperture、PW margin、wave stride |

---

## 推荐数据

~~~text
../../data/L7_FI_Verasonics_CIRS_points.uff
~~~

如果文件放在其他位置，修改 <code>filename</code> 即可。

---

## 没安装 USTB

先运行：

~~~matlab
filename = '../../data/L7_FI_Verasonics_CIRS_points.uff';
inspect_uff_hdf5
~~~

这只能做结构检查。

---

## 已安装 USTB

~~~matlab
addpath(genpath('D:/USTB'));

filename = '../../data/L7_FI_Verasonics_CIRS_points.uff';

inspect_uff_metadata_ustb
plot_raw_channel_overview_ustb
~~~

---

## 在开始写 DAS 前必须确认

- <code>size(channel_data.data)</code>；
- samples / channels / waves / frames；
- real RF or complex IQ；
- sampling frequency；
- initial time；
- sound speed；
- probe element coordinates；
- sequence；
- Focused Imaging 的 transmit geometry。

---

## 本章原则

USTB 用来读 UFF 和做 reference。

真正的 DAS：

~~~text
delay
interpolation
aperture
apodization
coherent sum
~~~

由本项目自己实现并逐步验证。

当前仓库还没有把“真实 UFF DAS”标成完成，因为这部分尚未正式实现和运行验证。


---

## 当前真正的 DAS 主线

本项目不会把 `midprocess.das()` 当成教学主实现。

运行顺序：

```matlab
inspect_uff_metadata_ustb
plot_raw_channel_overview_ustb
das_fi_scanline_manual
validate_manual_vs_ustb
analyze_point_target_psf
```

`reconstruct_fi_scanline_manual.m` 是唯一的 Manual DAS 算法核心。`das_fi_scanline_manual.m`、验证、PSF 和 aperture 对比脚本都调用这一核心。

核心函数中，USTB 只负责：

```matlab
channel_data = uff.read_object(filename, '/channel_data');
```

之后的 beamforming 数学全部由仓库代码自己完成。

默认先做：

```text
1 focused transmit -> 1 scanline
```

即 conventional FI-DAS。

RTB 会在这套 baseline 完成并与 USTB reference 对齐之后再加入。


---

## 关于 MATLAB workspace 的实现约定

早期版本的 aperture-comparison 脚本曾在局部函数中通过：

```matlab
run('das_fi_scanline_manual.m')
```

调用脚本，再依赖 `envelope`、`x_axis` 等变量留在调用工作区。

这种写法不稳定：脚本中的 `clearvars` 与函数 workspace 会导致变量丢失，MATLAB 还可能把丢失的变量名解析为同名函数，例如 `envelope()`。

现在统一改为：

```matlab
result = reconstruct_fi_scanline_manual(filename, opts);
```

所有结果通过 `result.envelope`、`result.x_axis` 等显式返回。后续算法代码不再依赖脚本间共享 workspace。


---

## RTB 推荐运行顺序

先跑最重要的主对照：

```matlab
filename = '../../data/L7_FI_Verasonics_CIRS_points.uff';

target_x_mm = -4.917;
target_z_mm = 20.21;

compare_conventional_vs_rtb
```

然后做 reference validation：

```matlab
validate_manual_rtb_vs_ustb
```

验证通过后再做参数实验，例如：

```matlab
experiment = 'delay_model';
experiment_rtb_parameter_sweep
```

或：

```matlab
experiment = 'wave_stride';
experiment_rtb_parameter_sweep
```

RTB 比 conventional FI-DAS 计算量大很多，因此参数探索默认使用较小的 `n_z`。确认趋势以后再提高到 512 / 1024。
