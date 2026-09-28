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
| <code>das_fi_scanline_manual.m</code> | 是（仅用于读取 UFF） | 本项目自己实现的 conventional FI scanline DAS：Tx/Rx delay、analytic RF、插值、aperture、coherent sum、dB 均显式实现 |
| <code>validate_manual_vs_ustb.m</code> | 是 | 在相同 x/z grid、scanline Tx、full Rx aperture 下比较 Manual DAS 与 USTB MATLAB DAS reference，输出相关系数、误差、峰值位置和差分图 |
| <code>analyze_point_target_psf.m</code> | 是（只用于重建前读取 UFF） | 交互选择孤立点靶，局部峰值细化，测量 lateral / axial -6 dB amplitude FWHM，并检查 FWHM 相对于 x/z sampling 的采样充分性 |
| <code>compare_receive_aperture_full_vs_fnumber.m</code> | 是（调用已验证的 Manual DAS） | 在完全相同的 Tx/Rx delay 与成像 grid 下，仅改变 receive aperture，对比 full aperture 与 dynamic F-number boxcar aperture 的 PSF |

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

第三个脚本中，USTB 只负责：

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
