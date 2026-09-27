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
