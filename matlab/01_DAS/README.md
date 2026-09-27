# MATLAB 实践：01_DAS

这个目录对应课程第一讲和后续 DAS 实现。

## 两条运行路径

### 路径 A：不安装 USTB

推荐先运行：

```matlab
demo_synthetic_point_target
```

这是**完全自包含**的 MATLAB 演示：

- 不需要 USTB；
- 不需要下载 UFF 数据；
- 不依赖第三方 toolbox；
- 用简化的 broadside plane-wave + point target 模型生成 channel RF；
- 展示不同阵元的到达时间差；
- 执行 DAS；
- 绘制横向响应。

它非常适合第一次理解 DAS。

如果你已经下载了 UFF 文件，但没有 USTB，可以运行：

```matlab
filename = '../../data/L7_FI_Verasonics_CIRS_points.uff';
inspect_uff_hdf5
```

这个脚本使用 MATLAB 自带的 `h5info` 查看 UFF/HDF5 层次结构。  
**注意：它只用于结构检查，不试图完整重建 USTB 对象。**

---

### 路径 B：安装 USTB

USTB 项目：

<https://github.com/ultrasoundtoolbox/ustb>

安装后，把 USTB 根目录加入 MATLAB path，例如：

```matlab
addpath(genpath('D:/USTB'));
```

然后：

```matlab
filename = '../../data/L7_FI_Verasonics_CIRS_points.uff';

inspect_uff_metadata_ustb
plot_raw_channel_overview_ustb
```

---

## 当前文件

| 文件 | 需要 USTB | 用途 |
|---|---:|---|
| `demo_synthetic_point_target.m` | 否 | 自包含 DAS 直觉实验 |
| `demo_delay_alignment.m` | 否 | 可视化原始弯曲到达轨迹如何被正确 Delay 拉直，以及错误焦点留下的 residual delay |
| `demo_aperture_psf_apodization.m` | 否 | 比较 aperture size、F-number 与 Uniform/Hann/Hamming 对 lateral PSF、-6 dB 宽度和 sidelobe 的影响 |
| `inspect_uff_hdf5.m` | 否 | 用 MATLAB HDF5 API 查看 UFF 文件结构 |
| `inspect_uff_metadata_ustb.m` | 是 | 用 USTB 读取并核对 channel data 元数据 |
| `plot_raw_channel_overview_ustb.m` | 是 | 显示真实 UFF 数据的“时间 × 阵元”图 |

---

## 推荐学习顺序

```text
1. demo_synthetic_point_target
        ↓
2. demo_delay_alignment
        ↓
3. demo_aperture_psf_apodization
        ↓
4. 阅读 chapters/01_DAS/README.md
        ↓
5. inspect_uff_hdf5
        ↓
6. 安装 USTB（准备进入真实数据）
        ↓
7. inspect_uff_metadata_ustb
        ↓
8. plot_raw_channel_overview_ustb
        ↓
9. 下一阶段：真正实现 UFF 数据上的 DAS
```

---

## 科学实现约定

后续所有代码都会显式检查：

- array shape；
- 每个 axis 的物理意义；
- real RF / complex IQ；
- Hz / MHz、s / us、m / mm；
- sampling frequency；
- initial time；
- probe element coordinates；
- Tx / Rx delay convention；
- interpolation；
- coherent / incoherent combination；
- amplitude / power / dB。

程序“能跑”不等于 beamforming 物理实现正确。
