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

## 14. RTB 最重要的新增难点：Tx delay model

这一节是第 1 章 RTB 部分最重要的内容之一。

先记住一句话：

> **RTB 与 conventional FI 的根本差异，不只是“换了一个发射延时公式”，而是一个 focused Tx 不再只负责自己的中心 scanline，而是要去重建周围许多 off-axis pixels。**

正因为一个 Tx 要被用于很多横向位置，发射侧突然多出三个问题：

~~~text
① 这个 Tx 到这个 pixel 的传播时间是多少？
② 这个 Tx 是否真的有效照射了这个 pixel？权重多少？
③ 多个 Tx 对同一个 pixel 怎样保持 complex coherent sum？
~~~

其中第①个问题，也就是 pixel-based Tx delay model，是 RTB 比 conventional FI 更难理解的核心之一。

### 14.1 为什么 conventional FI 对 Tx model 没那么敏感？

Conventional FI 基本是：

~~~text
                 scanline
                    │
                    │
                    │
                    F
                    │
                    │
====================探头====================
                 当前 Tx
~~~

一个 Tx 主要重建自己的中心线。

candidate pixel 基本和焦点在同一条轴线上，所以 Tx propagation geometry 很简单。

RTB 则是：

~~~text
            P1      P2      P3
             \      |      /
              \     |     /
               \    |    /
                    F
                    │
====================探头====================
                 当前 Tx
~~~

同一个 Tx 要解释 P1 / P2 / P3 这些 off-axis pixels。

这时：

> **Tx delay 必须随 pixel 的横向位置一起变化。**

这就是为什么 RTB 的主要新增难点集中在发射侧。

---

### 14.2 Spherical model：把焦点看成 virtual source

真实 focused transmit 可以直观画成：

~~~text
探头
================================
          \      |      /
           \     |     /
            \    |    /
             \   |   /
              \  |  /
               \ | /
                 F
                / \
               /   \
              /     \
~~~

焦点前是 converging wave，焦点后是 diverging wave。

焦点后的波前特别像：

~~~text
                 F
              /  |  \
            /    |    \
          P1     P2     P3
~~~

所以可以把焦点 F 当成一个 virtual point source。

对于焦点后的 pixel，直觉上可以理解为：

~~~text
参考时间走到 F
      +
F 再传播到 pixel
~~~

因此越远离 F，传播时间越长。

焦点前也仍使用同一个 virtual-source reference，只是时间关系反过来：

~~~text
探头
  ↓
pixel
  ↓
焦点 F
~~~

所以焦点前不是“声波先到 F 再倒着回来”，而是：

> **以“到达焦点的时间”为参考，pixel 比焦点更早被声波经过，因此要从焦点参考时间里减掉 pixel 到 F 的时间。**

代码里就是：

~~~matlab
spherical_path = ...
    wave.source.distance + signed_spherical;
~~~

其中：

~~~text
焦点前  signed_spherical < 0
焦点后  signed_spherical > 0
~~~

可以把 spherical model 记成：

> **以 F 为中心，用球面波的几何来描述 focused transmit。**

---

### 14.3 为什么“全用 spherical”在焦点附近会出问题？

关键不是中心线，而是 off-axis pixel。

想象一个 pixel 和焦点几乎处于同一深度：

~~~text
P1  •────────────── F ──────────────•  P2
              几乎同一 z
~~~

虽然 z_pixel 约等于 z_focus，但横向距离仍然不为 0。

Simple spherical model 的规则是：

~~~text
焦点前：焦点参考时间 - |F→P|/c
焦点后：焦点参考时间 + |F→P|/c
~~~

所以一个 off-axis pixel 只要从焦点上方一点点跨到焦点下方一点点，|F→P| 前面的符号就会从负号突然变成正号。

中心线上的 pixel 问题不明显，因为它靠近焦点时 |F→P| 本身也接近 0。

但 off-axis pixel：

~~~text
F •────────• P
~~~

即使深度差很小，横向距离仍然存在。

所以“全 spherical”容易在焦点深度附近产生不自然的 Tx-delay 跳变和图像 artifact。

一句话：

> **Spherical model 在远离焦点时很有物理直觉，但 simple before/after-focus sign rule 在焦点附近的 off-axis pixels 上不够平滑。**

---

### 14.4 Plane model：焦点附近把波前看成局部平面

为什么焦点附近可以考虑 plane approximation？

想象一个很大的球：

~~~text
        _________
     .-'         '-.
   .'               '.
~~~

整体当然是弯的。

但如果只看球面上一小块：

~~~text
----------------
~~~

局部会显得接近平面。

focused wavefront 也可以用同样的直觉理解：

> **在焦点附近的一小块区域，我们不再强行用“绕着 F 的球面距离”描述，而把局部波前近似成平面。**

对于当前线性扫描 convention，local plane model 主要看 pixel 在焦点上下的轴向位置：

~~~text
        P1      P2      P3
        •       •       •
--------------------------------  local wavefront
                 |
                 |
                 F
~~~

同一深度的 P1 / P2 / P3，plane model 认为 Tx propagation time 近似相同。

代码中：

~~~matlab
signed_axial = z - sz;

plane_path = ...
    wave.source.distance + ...
    signed_axial .* ones(size(x));
~~~

注意这里 plane_path 基本不随横向 x 改变。

可以把 plane model 记成：

> **只看“这个 pixel 在焦点上面还是下面多少”，暂时忽略横向波前曲率。**

---

### 14.5 为什么又不能“全图都用 plane”？

因为 plane 只是焦点附近的 local approximation。

离开焦点很远以后，真实 focused wave 已经明显具有曲率：

~~~text
                 F
              /     \
           /           \
        P1               P2
~~~

此时 P1 和 P2 虽然可能深度相同，但真实传播路径并不应该被认为完全一样。

如果全图都用 plane：

~~~text
P1      P2      P3      P4
•       •       •       •
--------------------------
~~~

就等于假设：

> “同一深度的所有 lateral pixels，Tx time 都差不多。”

这会忽略 off-axis wavefront curvature。

因此：

> **Plane model 能避免 focal-region 的 spherical sign-switch 问题，但不能作为整个成像区域的全局传播模型。**

为了把这一点直接看出来，Manual RTB core 支持一个教学专用选项：

~~~matlab
opts.tx_delay_model = 'plane';
~~~

它故意把 plane_path 用到整张图，只用于教学对照，不是推荐算法。

---

### 14.6 Blended：焦点附近更相信 plane，远处更相信 spherical

所以真正合理的思路不是只用 spherical，也不是只用 plane，而是：

~~~text
远离焦点                     焦点附近                     远离焦点

spherical  <-------------  plane 更重要  ------------->  spherical
~~~

Blended model 可以理解成一个连续的“信任旋钮”。

靠近焦点时：

~~~text
Plane       ██████████
Spherical   ██
~~~

稍微离开：

~~~text
Plane       ██████
Spherical   ██████
~~~

更远：

~~~text
Plane       ██
Spherical   ██████████
~~~

代码里先分别算：

~~~matlab
spherical_path
plane_path
~~~

然后：

~~~matlab
path_length = ...
    alpha .* spherical_path + ...
    (1-alpha) .* plane_path;
~~~

这里可以把 alpha 直观理解为：

> **当前 pixel 有多应该相信 spherical model。**

靠近 focal region，alpha 小，最终 path 更接近 plane_path。

远离 focal region，alpha 大，最终 path 更接近 spherical_path。

最重要的是：

> **这是连续过渡，而不是突然切换。**

这也是本章为什么把：

~~~matlab
tx_delay_model = 'blended';
blending_power = 0.5;
~~~

作为 RTB 教学 baseline。

---

### 14.7 必跑实验：全 spherical vs 全 plane vs blended

运行：

~~~matlab
compare_rtb_spherical_plane_blended
~~~

脚本保持以下条件完全一致：

~~~text
同一份 L7_FI_TheGB.uff
同一 output grid
同一 Tx F#
同一 Tx Tukey window
同一 minimum Tx aperture
同一 Rx F#
同一 interpolation
同一 Tx-overlap normalization
~~~

唯一改变的是 Tx delay model。

三组分别为：

~~~text
1. All spherical
2. All plane
3. Blended
~~~

脚本会输出四组图。

#### Figure 1：各自归一化后的完整图像

用于看形态、聚焦和 artifact 的差异。

因为每张图都归一化到自己的 peak，所以不让整体 gain 掩盖结构差异。

#### Figure 2：统一用 blended peak 作为幅度参考

用于看不同 Tx-delay model 是否改变整体和局部 brightness。

#### Figure 3：焦点深度附近放大

这是最重要的一张。

重点观察：

~~~text
All spherical
    -> focal region 是否出现不自然结构

All plane
    -> focal region 可能比较平滑，但远离焦点的聚焦是否变差

Blended
    -> 是否同时避免上述两个极端
~~~

#### Figure 4：与 blended 的 normalized-envelope difference

直接显示：

~~~text
|Spherical - Blended|
|Plane - Blended|
~~~

差异主要出现在哪里。

这个实验的目的不是证明 blended 在所有场景都绝对最优，而是建立一个非常重要的 RTB 直觉：

> **spherical 是全局几何模型，plane 是 focal-region 局部近似，blended 用连续权重让两者在各自擅长的区域起主要作用。**

---

### 14.8 这一节只需要记住四句话

1. **RTB 的根本变化是“一发多像素 + 多发同像素”，不是简单换一个 delay 公式。**
2. **因此 Tx delay、Tx support 和跨 Tx coherent combination 成为新的核心问题。**
3. **Spherical 远离焦点更合理；local plane 在焦点附近更稳定，但不能全局使用。**
4. **Blended 就是让 plane 在焦点附近更重要，让 spherical 在远处更重要，并且连续过渡。**

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

% 必跑：理解 spherical / plane / blended
compare_rtb_spherical_plane_blended

delay_model = 'blended';
validate_manual_rtb_vs_ustb

% Experiments
experiment = 'delay_model';
experiment_rtb_parameter_sweep
~~~

---

## 21. 第 1 章总结

到这里，第 1 章的教学主线已经完整。

你现在应该能够从真实 UFF channel data 出发，解释并实现：

~~~text
UFF / metadata
    ↓
sample-time axis
    ↓
Tx delay
    ↓
Rx delay
    ↓
fractional-sample interpolation
    ↓
receive aperture / F-number
    ↓
conventional Rx-DAS
    ↓
PSF / FWHM
    ↓
pixel-based RTB
    ↓
Tx support / Tx weighting
    ↓
cross-Tx coherent combination
    ↓
Tx-overlap normalization
    ↓
B-mode envelope / dB
~~~

最重要的几个认识是：

- conventional FI 基本是 **一个 Tx → 一条 scanline**；
- RTB 是 **一个 Tx → 多个 pixels，同时多个 Tx → 一个 pixel**；
- RTB 因此比 conventional FI 更依赖正确的 Tx propagation model；
- spherical / plane / blended 不是三个随意公式，而是对 focused wavefront 在不同空间区域的不同近似；
- DAS 的核心仍然是：**先利用传播模型把信号对齐，再相干求和。**

第 1 章到这里结束。

下一章进入：

> **第 2 章：Coherence Factor（CF）与 Generalized Coherence Factor（GCF）**

从下一章开始，我们不再主要修改传播模型，而开始研究：

> **已经完成 delay alignment 的 aperture data，怎样判断“这些通道到底有多相干”，并利用相干性改善 DAS 图像。**

---

## 22. 本章的科学边界

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