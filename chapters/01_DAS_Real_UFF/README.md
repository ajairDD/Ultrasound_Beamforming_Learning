# 第 1 章：真实 UFF 上的 conventional FI-DAS 与 RTB

第 0 章建立了 Delay、channel data、PSF、aperture、F-number、apodization 和 axial/lateral resolution 的基础。

第 1 章把这些概念放到真实 focused-imaging UFF channel data 上，完成两条主线：

1. conventional scanline FI-DAS；
2. RTB（Retrospective Transmit Beamforming）。

本章只保留可泛化的教学内容，不保留针对单个异常 acquisition 的修补或推测代码。

---

## 1. 默认教学数据

统一使用：

~~~text
data/L7_FI_TheGB.uff
~~~

作为本章默认数据。

它适合同时学习：

- Focused Imaging 的真实 channel data；
- conventional one-Tx-one-line reconstruction；
- Tx/Rx timing convention；
- point-target / PSF 分析；
- receive F-number；
- pixel-based RTB。

下载信息与 MD5 见 **[data/README.md](../../data/README.md)**。

---

## 2. USTB 的角色

USTB 用于：

- 可靠读取 UFF；
- 获取 `channel_data`；
- 获取 probe geometry；
- 获取 transmit sequence、virtual source 和 `wave.delay`；
- 作为 reference beamformer 进行交叉验证。

本项目自己实现：

~~~text
Tx delay
Rx delay
fractional-sample interpolation
receive aperture / F-number
coherent DAS
RTB Tx support
cross-Tx coherent combination
envelope / dB
~~~

所以：

> **USTB 是数据接口和 reference，不是我们的主算法实现。**

---

## 3. 先确认 data contract

运行：

~~~matlab
filename = '../../data/L7_FI_TheGB.uff';

inspect_uff_hdf5
inspect_uff_metadata_ustb
plot_raw_channel_overview_ustb
~~~

至少确认以下内容。

### 3.1 Shape

USTB channel data 常用：

~~~text
[time, receive_channel, transmit_wave, frame]
~~~

即：

~~~matlab
channel_data.data(sample, channel, wave, frame)
~~~

必须确认 `N_samples / N_channels / N_waves / N_frames` 与实际数组一致。

### 3.2 时间轴

本项目 Manual beamformer 使用：

$$
t[n]=t_0+\frac{n-1}{f_s}
$$

其中：

- $t_0=$ `channel_data.initial_time`；
- $f_s=$ `channel_data.sampling_frequency`。

### 3.3 RF / IQ

检查：

- `modulation_frequency`；
- `isreal(channel_data.data)`；
- dtype。

本章核心代码针对 real RF，再通过 FFT 构造 analytic signal。

### 3.4 Probe geometry

确认：

- element 数量；
- `probe.x / y / z`；
- pitch；
- 阵列所在平面。

### 3.5 Transmit sequence

对每个 wave 检查：

- wavefront；
- `wave.source.x/y/z`；
- `wave.source.distance`；
- `wave.delay`。

不要假设所有 wave 的 `delay` 都为 0。

---

## 4. Focused transmit 的时间模型

设 virtual source / focus：

$$
F=(x_f,z_f)
$$

候选 pixel：

$$
P=(x,z)
$$

USTB focused spherical model 使用：

$$
R_f=\texttt{wave.source.distance}
$$

作为时间参考距离的一部分。

候选点到 focus 的几何距离：

$$
d_F(P)=\sqrt{(x-x_f)^2+(z-z_f)^2}
$$

焦点前取负，焦点后取正：

$$
d_s(P)=
\begin{cases}
-d_F(P), & z<z_f \\
+d_F(P), & z\ge z_f
\end{cases}
$$

于是：

$$
\boxed{
\tau_{Tx}(P)=\frac{R_f+d_s(P)}{c}-\texttt{wave.delay}
}
$$

这里要区分：

- `source.distance`：focused-wave reference geometry；
- `wave.delay`：该 Tx wave 的额外时间偏置。

本项目使用统一的 `initial_time + sample/fs` channel-data 时间轴，因此 `wave.delay` 在 Tx model 中显式处理，不能重复计数。

---

## 5. Receive delay

第 $m$ 个阵元：

$$
E_m=(x_m,y_m,z_m)
$$

则：

$$
\tau_{Rx,m}(P)=
\frac{
\sqrt{
(x-x_m)^2+(y-y_m)^2+(z-z_m)^2
}
}{c}
$$

总查询时间：

$$
\boxed{
\tau_m(P)=\tau_{Tx}(P)+\tau_{Rx,m}(P)
}
$$

这一步把空间位置转换成每个 receive channel 上应该读取的时间。

---

## 6. Fractional-sample interpolation

通常：

$$
\tau_m f_s
$$

不是整数。

如果只取最近 sample，会产生额外 delay / phase error。

本章 baseline 使用线性插值：

$$
x(t)\approx(1-\alpha)x[n]+\alpha x[n+1]
$$

其中：

$$
\alpha\in[0,1)
$$

目的是得到可解释、可复现、可与 reference 比较的实现。

---

## 7. Conventional FI-DAS

传统 Focused Imaging 可以理解为：

~~~text
Tx 1 -> scanline 1
Tx 2 -> scanline 2
...
Tx T -> scanline T
~~~

延时后的 receive sample：

$$
s_m(P)=x_m\!\left(\tau_m(P)\right)
$$

DAS：

$$
y(P)=\sum_{m=1}^{M}w_m(P)s_m(P)
$$

核心实现：

~~~text
reconstruct_fi_scanline_manual.m
~~~

直接运行入口：

~~~text
das_fi_scanline_manual.m
~~~

---

## 8. Analytic RF、envelope 与 dB

真实 RF 带载频振荡。

先构造 analytic signal：

$$
x_a(t)=x(t)+j\hat{x}(t)
$$

beamforming 后 envelope：

$$
A(P)=|y_a(P)|
$$

显示：

$$
I_{dB}=20\log_{10}\frac{A(P)}{A_{max}}
$$

这里处理的是 amplitude，所以使用 $20\log_{10}$。

---

## 9. Conventional DAS reference validation

运行：

~~~matlab
validate_manual_vs_ustb
~~~

比较：

~~~text
Manual conventional FI-DAS
vs
USTB conventional DAS
~~~

必须尽量匹配：

- 同一 UFF；
- 同一 frame；
- 同一 x/z grid；
- 同一 Tx model；
- 同一 receive aperture；
- 同类 interpolation；
- 同一种 envelope normalization。

不要只用“图看起来差不多”作为验证。

至少检查：

- envelope correlation；
- normalized MAE / RMSE；
- maximum error；
- peak location。

---

## 10. Point-target PSF

运行：

~~~matlab
analyze_point_target_psf
~~~

脚本让你点击一个相对孤立的 point-like target，然后自动寻找局部 peak。

测量：

- lateral profile；
- axial profile；
- $-6$ dB amplitude FWHM；
- FWHM 跨多少个 samples。

### 横向采样限制

Conventional FI 通常一个 Tx 对应一条 line。

如果 lateral FWHM 只跨 1–2 个 scanline intervals，那么数值只是粗估。

### Axial 与 lateral 的主要控制因素

轴向分辨率主要受 pulse length / bandwidth 影响。

横向分辨率主要受 aperture、wavelength、depth、focusing 和 apodization 影响。

---

## 11. Receive F-number

运行：

~~~matlab
compare_receive_aperture_full_vs_fnumber
~~~

对比 full receive aperture 与 dynamic F-number。

$$
F\#=\frac{z}{D}
$$

所以：

$$
D(z)=\frac{z}{F\#}
$$

默认教学值：

~~~text
Rx F# = 1.7
~~~

只改变 receive aperture，其余保持一致。

预期：aperture 变小主要使 lateral PSF 变宽，axial PSF 改变较小。

---

# 12. RTB：从“一发一线”到 pixel-based reconstruction

Conventional FI：

~~~text
一个 Tx -> 一条 scanline
~~~

RTB：

> 一个 focused Tx 不只用于中心线；在它有效照射的区域内，可以 retrospectively reconstruct 多个 pixels。

对第 $t$ 个 Tx：

$$
S_t(x,z)=\sum_m w_m^{Rx}(x,z)s_{m,t}(x,z)
$$

然后跨 Tx coherent combine：

$$
S_{RTB}(x,z)=
\frac{
\sum_t w_t^{Tx}(x,z)S_t(x,z)
}{
\sum_t w_t^{Tx}(x,z)
}
$$

所以：

$$
\boxed{
\text{RTB}
=
\text{pixel-based Rx DAS}
+
\text{Tx-domain coherent combination}
}
$$

RTB 不是 CF / DMAS 那种新的 receive-channel 求和公式。

---

## 13. RTB 不等于图像插值

运行：

~~~matlab
compare_conventional_vs_rtb
~~~

同时比较：

1. conventional FI；
2. conventional image 的 lateral interpolation；
3. RTB。

普通插值只对已经形成的图像加密显示 grid，不重新访问 RF。

RTB 会回到 raw RF，对新的 candidate pixel 重新计算 Tx/Rx delay，再做 coherent reconstruction。

因此：

$$
\boxed{
\text{display interpolation}\neq\text{RTB}
}
$$

---

## 14. RTB Tx-delay model

RTB 会把一个 focused Tx 用到 off-axis pixels，因此 Tx propagation model 比 conventional scanline 更重要。

### 14.1 Spherical

simple virtual-source spherical model。

优点：简单、直觉清楚。

缺点：对 off-axis pixel，在 focal depth 附近可能出现不连续。

### 14.2 Hybrid

焦点附近使用 local plane-wave delay，远处使用 spherical delay。

它避免了 simple spherical model 在正焦点处的主要问题，但固定 `pw_margin` 属于 hard switch。

### 14.3 Blended

本章教学主线默认：

~~~text
tx_delay_model = 'blended'
blending_power = 0.5
~~~

它连续混合 spherical 与 local-plane path，避免固定深度边界的硬切换。

`spherical / hybrid / blended` 三种模式都保留，用于参数实验理解模型差异。

---

## 15. RTB Tx support / apodization

一个 focused Tx 不应该贡献给整张图。

本章使用 pixel-dependent Tx F-number support。

beam-local coordinates 下：

$$
r=F\#_{Tx}\frac{|x'|}{|z'|}
$$

并使用 Tukey window 平滑 support 边界。

教学 baseline：

~~~text
Tx F#               = 2
Tx minimum aperture = 3 mm
Tx window           = Tukey25
Rx F#               = 1.7
x upsample          = 4
~~~

minimum aperture 用来避免 virtual-source 附近 support 收缩到 0。

---

## 16. Tx overlap normalization

不同 pixel 的 Tx overlap 不同。

若直接：

$$
\sum_t w_tS_t
$$

overlap 多的位置会天然更亮。

因此使用：

$$
\boxed{
S_{RTB}=
\frac{\sum_t w_tS_t}{\sum_t w_t}
}
$$

这是 Tx-overlap normalization，不是额外的 B-mode gain correction。

---

## 17. Manual RTB 核心

核心文件：

~~~text
reconstruct_fi_rtb_manual.m
~~~

数据流：

~~~text
for each Tx
    analytic RF
        -> Tx support
        -> pixel-based Tx delay
        -> Rx delay
        -> fractional interpolation
        -> receive DAS
        -> Tx weight
        -> coherent accumulate
end

divide by Tx weight sum
        -> complex RTB image
        -> envelope / dB
~~~

代码按 Tx streaming accumulation，不保存完整 `[z, x, Tx]` cube。

---

## 18. RTB reference validation

运行：

~~~matlab
delay_model = 'blended';
validate_manual_rtb_vs_ustb
~~~

比较 Manual RTB 与 USTB generalized beamformer。

尽量匹配：

- x/z grid；
- Tx delay model；
- Tx F-number；
- Tx window；
- minimum aperture；
- Rx F-number；
- Tx overlap normalization。

同样不能仅靠视觉相似宣布实现正确。

---

## 19. RTB 参数实验

运行：

~~~matlab
experiment = 'delay_model';
experiment_rtb_parameter_sweep
~~~

| experiment | 主要问题 |
|---|---|
| `delay_model` | spherical / hybrid / blended 有什么差异？ |
| `x_upsample` | output grid 加密后，采样与真实 PSF 如何区分？ |
| `tx_fnumber` | 一个 Tx 应该覆盖多宽？ |
| `tx_min_aperture` | virtual-source 附近最小 support 有何影响？ |
| `pw_margin` | Hybrid 的 plane-wave 区域多宽？ |
| `rx_fnumber` | Rx aperture 如何影响 lateral PSF？ |
| `wave_stride` | 少使用一些 Tx 后 RTB 如何退化？ |
| `blending_power` | blended spherical/plane 过渡速度如何变化？ |

一次只改一个变量，不做无意义的大规模组合搜索。

---

## 20. 推荐运行顺序

~~~matlab
addpath(genpath('D:/USTB'));   % 改成实际路径
cd matlab/01_DAS_Real_UFF

filename = '../../data/L7_FI_TheGB.uff';

% Data contract
inspect_uff_hdf5
inspect_uff_metadata_ustb
plot_raw_channel_overview_ustb

% Conventional FI-DAS
das_fi_scanline_manual
validate_manual_vs_ustb

% PSF / Rx aperture
analyze_point_target_psf
compare_receive_aperture_full_vs_fnumber

% RTB
compare_conventional_vs_rtb
delay_model = 'blended';
validate_manual_rtb_vs_ustb

% Experiments
experiment = 'delay_model';
experiment_rtb_parameter_sweep
~~~

---

## 21. 本章的科学边界

当前代码是教学和可解释 baseline。

不要把以下事情混为一谈：

- 程序运行成功；
- 图像看起来合理；
- 与 reference 接近；
- 数学实现完全正确；
- proprietary scanner beamformer 被完整复现；
- 临床图像质量更优。

本章真正要建立的是：

> **真实 focused channel data 的 geometry、timing、interpolation、aperture 与 coherent reconstruction 之间的关系。**

掌握这一层以后，第 2 章开始才把重点转向：

$$
\mathbf s(\mathbf r)\longrightarrow y(\mathbf r)
$$

也就是“对齐后的 aperture data 应该怎样组合”。