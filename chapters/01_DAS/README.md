# 第一讲：从一个点散射子真正理解 DAS

> **本讲目标**：先建立 Delay-and-Sum (DAS) 的物理直觉，再进入公式和真实数据。  
> **实践语言**：MATLAB。  
> **推荐真实数据**：`data/L7_FI_Verasonics_CIRS_points.uff`。  
> **USTB 不是必需项**：没有安装 USTB 也可以先运行本讲的自包含合成实验。

---

## 1. 为什么从 DAS 开始

后续 CF、MV/MVDR、DMAS、SLSC、NSI 看起来差异很大，但它们都建立在同一件事上：

> **先根据传播模型，把不同阵元对同一个空间点的观测对齐。**

因此，DAS 的核心并不是最后那个 `Sum`，而是前面的 `Delay`。

---

## 2. 一个最小物理场景

先只考虑：

- 一把线阵探头；
- 空间中一个点散射体；
- 发射后，各阵元都收到这个点的回波；
- 因为传播距离不同，各阵元的回波到达时间不同。

```mermaid
flowchart TB
    A[Linear array: e1 ... eM] --> B[Transmit wave]
    B --> C[Point scatterer r = (x,z)]
    C --> D1[Echo to e1]
    C --> D2[Echo to e2]
    C --> D3[Echo to eM]
    D1 --> E[Different arrival times]
    D2 --> E
    D3 --> E
    E --> F[Delay compensation]
    F --> G[Phase / time alignment]
    G --> H[Weighted coherent sum]
```

如果完全不做延时补偿就直接相加，本应来自同一目标的回波会错位，甚至部分抵消。

所以第一条原则是：

> **让同一个假设空间点对应的各通道回波重新对齐。**

---

## 3. 从几何位置到通道取样

设候选成像点为

$$
\mathbf r=(x,z),
$$

第 $m$ 个阵元位置为

$$
\mathbf r_m=(x_m,0).
$$

第 $m$ 个阵元的连续时间接收信号记作 $x_m(t)$。

如果假设散射体真的位于 $\mathbf r$，那么该阵元应该在对应传播时间 $\tau_m(\mathbf r)$ 处取样：

$$
s_m(\mathbf r)
=
x_m\!\left(\tau_m(\mathbf r)\right).
$$

把所有阵元对该像素的取样值收集起来：

$$
\mathbf s(\mathbf r)
=
[s_1(\mathbf r),s_2(\mathbf r),\ldots,s_M(\mathbf r)]^T.
$$

这就是后续所有经典 beamformer 都会反复使用的“已对齐孔径观测”。

---

## 4. DAS 的基本公式

最基本的 DAS 为

$$
y_{\mathrm{DAS}}(\mathbf r)
=
\sum_{m=1}^{M}
w_m(\mathbf r)s_m(\mathbf r),
$$

其中：

- $M$：参与当前像素成像的阵元数；
- $w_m(\mathbf r)$：apodization / aperture 权重；
- $s_m(\mathbf r)$：延时后的第 $m$ 通道值；
- $y_{\mathrm{DAS}}(\mathbf r)$：该像素的波束合成结果。

因此更准确的概括是：

$$
\boxed{
\text{Propagation model}
\rightarrow
\text{Delay}
\rightarrow
\text{Interpolation}
\rightarrow
\text{Weight}
\rightarrow
\text{Coherent Sum}
}
$$

---

## 5. 总传播时间：Tx + Rx

通常：

$$
\tau_m(\mathbf r)
=
\tau_{\mathrm{TX}}(\mathbf r)
+
\tau_{\mathrm{RX},m}(\mathbf r).
$$

### 5.1 接收时间

如果采用常数声速 $c$：

$$
\tau_{\mathrm{RX},m}(\mathbf r)
=
\frac{\|\mathbf r-\mathbf r_m\|}{c}.
$$

同一个散射点到不同阵元的距离不同，因此每个阵元的接收时间不同。

### 5.2 发射时间

$\tau_{\mathrm{TX}}$ 取决于 **acquisition / transmit strategy**：

- Focused Imaging (FI)
- Plane Wave (PW)
- Diverging Wave (DW)
- Synthetic Transmit Aperture (STA)

所以：

> **Acquisition ≠ Beamformer。**

完全可以有：

```text
Plane Wave + DAS
Plane Wave + MV
Focused Imaging + DAS
Focused Imaging + DMAS
```

这些方法都可以使用 DAS，但它们的发射传播模型并不一样。

---

## 6. 为什么说 DAS 的核心是 Delay

如果传播模型错误，或者 $\tau_m$ 算错了：

1. 取到的并不是各阵元对同一个物理散射点的对应样本；
2. 阵元之间不能正确同相；
3. coherent summation 的增益下降；
4. PSF 可能变宽；
5. 旁瓣和杂波可能上升；
6. 更高级的 coherence / adaptive beamformer 也可能受到影响。

因此：

$$
\boxed{
\text{正确的 Sum 不能挽救错误的 Delay}
}
$$

---

## 7. 为什么需要插值

理论上的 $\tau_m(\mathbf r)$ 是连续时间，但 ADC 数据是离散采样：

$$
x_m[n],\qquad n=0,1,2,\ldots
$$

一般情况下：

$$
\tau_m(\mathbf r)f_s
$$

不是整数。

所以实际实现需要亚采样取值，例如：

- nearest-neighbor；
- linear interpolation；
- spline / 高阶插值；
- IQ 或频域方法中的 phase rotation。

最近邻虽然简单，但会引入量化后的时延误差。在高频、低采样倍率或大孔径条件下，这种误差尤其明显。

本项目的基准 DAS 会优先使用**明确可解释的线性插值**，后续再比较更高精度方法。

---

## 8. Aperture、dynamic aperture 和 F-number

### 8.1 Aperture

当前像素参与求和的阵元集合称为接收孔径。

一般而言，更大的有效孔径可以获得更窄的横向主瓣，但也可能增加：

- 对声速误差和相位误差的敏感性；
- 旁瓣设计难度；
- 计算量。

### 8.2 Dynamic aperture

随着深度增加，通常逐渐增大接收孔径，而不是所有深度始终使用同一组阵元。

### 8.3 F-number

常见近似定义：

$$
F\#=\frac{z}{D},
$$

其中 $z$ 为深度，$D$ 为有效孔径宽度。

固定 F-number 就意味着：

> 深度增加时，允许使用的孔径也随之增加。

---

## 9. Apodization：为什么降低旁瓣会牺牲主瓣宽度

Uniform weighting 相当于“硬边界”孔径，通常主瓣较窄，但旁瓣较高。

Hann、Hamming、Tukey 等窗口通过降低孔径边缘阵元的权重来抑制旁瓣，但通常会展宽主瓣。

所以经典 trade-off 是：

$$
\boxed{
\text{Lower sidelobes}
\Longleftrightarrow
\text{Wider main lobe}
}
$$

这也是后面 MV、NSI 等方法要重新挑战的问题之一。

---

## 10. DAS 的问题如何引出后续算法

### 问题 A：DAS 输出很大，就一定是真正聚焦吗？

不一定。

于是出现 coherence weighting：

- CF
- GCF
- phase / sign coherence methods

### 问题 B：为什么权重必须事先固定？

于是出现自适应空间滤波：

- Capon
- MV
- MVDR

### 问题 C：为什么只做线性求和？

于是出现显式 inter-channel nonlinear interaction：

- DMAS
- fDMAS

### 问题 D：为什么最终一定显示“幅度”？

于是出现直接以 spatial coherence 成像的：

- SLSC

### 问题 E：为什么只利用主瓣？

于是出现利用 beam-pattern null 的：

- NSI

---

## 11. 本讲的两条 MATLAB 实践路径

### 路径 A：没有 USTB —— 推荐所有初学者先跑

运行：

```matlab
demo_synthetic_point_target
```

这个脚本：

- 不需要 USTB；
- 不需要任何外部数据；
- 只使用 MATLAB 基本功能；
- 自己生成一个线阵 + 单点散射体的 channel RF；
- 显示未对齐的回波；
- 对目标深度执行 DAS；
- 画出横向 DAS 响应。

它的作用是先建立物理直觉，而不是复现某一台真实超声系统。

### 路径 B：安装 USTB —— 进入真实 UFF channel data

建议顺序：

```matlab
inspect_uff_metadata_ustb
plot_raw_channel_overview_ustb
```

没有 USTB 但已经下载 UFF 文件时，还可以先运行：

```matlab
inspect_uff_hdf5
```

它只使用 MATLAB 自带的 HDF5 接口查看文件内部结构。

---

## 12. 本讲一句话结论

$$
\boxed{
\text{DAS 的本质不是“把通道加起来”，而是先用传播模型把通道对齐，再做加权相干求和。}
}
$$

---

## 13. 下一步

下一小节会真正进入 **DAS MATLAB 实现**：

1. 明确 UFF channel data 的 shape 与轴含义；
2. 构建 imaging grid；
3. 分别计算 Tx / Rx delay；
4. 做亚采样插值；
5. 完成第一版 DAS；
6. 在点靶数据上测 lateral / axial PSF 与 FWHM；
7. 比较 aperture、F-number、apodization。

届时开始使用真实 UFF 数据作为 benchmark。


---

## 14. Aperture → PSF → 横向分辨率

点散射体并不会在重建图像中变成无限小的一个点。

当 beamformer 在真实目标附近扫描候选位置时，附近位置虽然不是完全正确的 focus，但 residual delay 仍可能很小，因此仍能保留一定程度的 coherent summation。

于是理想点目标会形成一个具有有限宽度的空间响应：

$$
\boxed{\text{Point Spread Function (PSF)}}
$$

对于本项目的第一阶段，我们主要观察固定深度处的 **lateral PSF**。

在简化的一维接收孔径模型中，横向主瓣宽度的尺度近似满足：

$$
\Delta x
\propto
\frac{\lambda z}{D}
=
\lambda F\#,
$$

其中：

- $\lambda=c/f_c$：波长；
- $z$：成像深度；
- $D$：有效接收孔径；
- $F\#=z/D$。

这里的比例系数并不是一个对所有系统都通用的常数，它会随 transmit/receive configuration、apodization、带宽、PSF 指标定义等变化。

因此本项目会把 $\lambda z/D$ 当作**尺度关系**，而不会把它当作某个固定的精确公式。

---

## 15. 为什么孔径更大通常带来更窄的 lateral PSF

当有效孔径较小时，候选 focus 在横向稍微移动后，各阵元预测传播时间的变化仍然比较接近，因此 aperture 上还能保持一定 coherence。

当孔径增大后，左右两端阵元之间的传播路径差对横向位置更加敏感。

于是错误候选位置会更快产生：

$$
\epsilon_m
=
\tau_m^{\mathrm{true}}
-
\hat{\tau}_m,
$$

以及对应的 phase error：

$$
\Delta\phi_m
=
2\pi f_c\epsilon_m.
$$

所以更大的 aperture 通常意味着：

$$
\boxed{\text{候选位置稍微偏离目标，就更快失去跨孔径相干性}}
$$

从而形成更窄的 lateral PSF。

---

## 16. F-number 与 dynamic aperture

常见近似定义：

$$
F\#
=
\frac{z}{D}.
$$

如果希望在不同深度维持相近的横向分辨率尺度，可以让有效孔径随深度增加：

$$
D(z)
\approx
\frac{z}{F\#}.
$$

这就是 dynamic receive aperture 的核心思想之一。

在实际系统中，$D(z)$ 最终会受到物理阵元总数、阵元 pitch、探头几何和最小/最大 aperture 的限制。

---

## 17. Apodization 为什么会改变主瓣和旁瓣

把阵元权重写成 aperture function：

$$
w_m.
$$

Uniform weighting 相当于较“硬”的矩形孔径。

它通常可以获得较窄主瓣，但 finite aperture 的截断会带来较明显的 sidelobe。

Hann、Hamming 等窗函数通过降低孔径边缘阵元的权重，使 aperture 过渡更平滑，从而压低 sidelobe，但代价通常是主瓣展宽。

因此：

$$
\boxed{
\text{Lower sidelobes}
\Longleftrightarrow
\text{Wider main lobe}
}
$$

这可以从 aperture function 与 spatial response 的 Fourier-duality 角度理解。

---

## 18. 本项目如何测量 PSF 宽度

配套脚本：

```matlab
demo_aperture_psf_apodization
```

为了避免依赖 Signal Processing Toolbox，该教学脚本使用 complex analytic / IQ-like pulse，并直接对 beamformed complex response 取 magnitude。

脚本中的 “FWHM” 定义为 normalized magnitude 降到 0.5 时的全宽。

因为显示使用：

$$
20\log_{10}|y|,
$$

所以 0.5 amplitude 对应：

$$
20\log_{10}(0.5)
\approx
-6.02\ \mathrm{dB}.
$$

因此这里更准确地说是：

> **-6 dB amplitude width**

不要把它与 **-3 dB half-power beamwidth** 混为一谈。

---

## 19. 当前配套实验

`demo_aperture_psf_apodization.m` 做两组比较。

第一组固定 Uniform weighting，只改变 active aperture：

```text
16 elements
32 elements
64 elements
```

用来观察：

- aperture $D$；
- F-number；
- -6 dB lateral width

之间的关系。

第二组固定 64 个 active elements，比较：

```text
Uniform
Hann
Hamming
```

观察：

- main-lobe width；
- sidelobe suppression

之间的 trade-off。

实验中所有曲线都会按各自 peak 归一化，因此主要用于比较**空间响应形状**，不表示不同窗口的绝对接收灵敏度。

---

## 20. Sidelobe 与 grating lobe 不要混淆

**Sidelobe** 是有限 aperture / weighting 后空间响应中主瓣之外的次级峰。

**Grating lobe** 则主要与阵列空间采样有关，特别受 element pitch 与 wavelength 的关系影响。

二者虽然都会产生离轴响应，但物理来源不同。

本项目会在后续阵列空间采样部分单独讨论 grating lobe，不在本节混在一起。


---

## 21. Axial resolution 与 lateral resolution 来自不同物理机制

这一点必须明确区分。

### Lateral resolution

主要由：

- aperture；
- focusing；
- F-number；
- wavelength；
- apodization

控制。

常用尺度关系：

$$
\Delta x
\sim
\frac{\lambda z}{D}
=
\lambda F\#.
$$

### Axial resolution

主要由 transmitted / received pulse 在时间方向上的长度决定。

更短的脉冲意味着更小的 spatial pulse length，从而更容易分开轴向上相邻的两个散射体。

常见直觉关系：

$$
\Delta z_{\mathrm{axial}}
\sim
\frac{\mathrm{SPL}}{2},
$$

其中 SPL 是 spatial pulse length。

因为 pulse length 与 bandwidth 互为 trade-off，所以通常：

> **shorter pulse → broader bandwidth → better axial resolution**

---

## 22. 为什么 axial resolution 不主要由 aperture 决定

固定 lateral coordinate 时，沿深度方向移动候选焦点，最主要变化是 pulse 到达时间。

如果两个轴向目标的回波在时间上高度重叠，那么即使 aperture 很大，也无法仅靠横向聚焦把两个 temporal echoes 完全分开。

因此：

$$
\boxed{
\text{Axial resolution mainly follows temporal pulse extent}
}
$$

而不是 receive aperture。

---

## 23. Spatial pulse length

如果 pulse 大约包含 $N_c$ 个周期：

$$
\mathrm{SPL}
\approx
N_c\lambda.
$$

对于传统 pulse-echo 情况，常见轴向分辨率尺度：

$$
\Delta z_{\mathrm{axial}}
\approx
\frac{\mathrm{SPL}}{2}.
$$

这里的 $1/2$ 来自双程传播：两个深度之间的空间距离 $\Delta z$ 会对应大约 $2\Delta z/c$ 的往返时间差。

这只是经典近似尺度关系；实际值仍受：

- pulse shape；
- bandwidth；
- filtering；
- demodulation；
- envelope detection；
- width definition

影响。

---

## 24. Bandwidth 与 axial resolution

时间越短的 pulse，其频谱通常越宽。

因此：

$$
\boxed{
\text{Short pulse}
\Longleftrightarrow
\text{Broad bandwidth}
}
$$

进一步：

$$
\boxed{
\text{Broad bandwidth}
\Rightarrow
\text{Better axial resolution}
}
$$

这也是为什么不能只看 center frequency 判断 axial resolution。

两个探头即使都有 5 MHz center frequency，如果 bandwidth 不同，轴向分辨率也可能明显不同。

---

## 25. 二维 PSF

真实成像中的点目标响应是二维的：

$$
PSF(x,z).
$$

它通常表现为：

- axial 方向：由 pulse length / bandwidth 主导；
- lateral 方向：由 aperture / focusing 主导。

因此二维 PSF 往往不是一个圆，而更像一个椭圆或具有复杂旁瓣结构的二维响应。

配套脚本：

```matlab
demo_axial_lateral_2d_psf
```

会依次画出：

1. short vs long pulse 的 axial PSF；
2. 不同 aperture 的 lateral PSF；
3. 一个完整 2-D PSF。

---

## 26. 关于当前脚本里的 bandwidth

当前教学脚本使用 Gaussian-modulated complex analytic pulse：

$$
p(t)
=
\exp\left(-\frac{t^2}{2\sigma_t^2}\right)
\exp(j2\pi f_ct).
$$

较小的 $\sigma_t$：

- pulse 更短；
- frequency-domain Gaussian 更宽；
- axial PSF 更窄。

较大的 $\sigma_t$：

- pulse 更长；
- bandwidth 更窄；
- axial PSF 更宽。

脚本打印的是近似的 -6 dB amplitude fractional bandwidth，只用于帮助建立趋势，不应当替代真实探头的实测 bandwidth 定义。


---

## 27. DAS 的典型 Failure Modes

配套脚本：

```matlab
demo_das_failure_modes
```

这一节不是为了证明 DAS “不好”，而是明确它的适用边界。

### 27.1 两个目标太近：有限 lateral resolution

当两个横向点目标的间距小于当前 PSF 能够有效区分的尺度时，它们的响应会明显重叠。

因此，即使两个真实散射体彼此独立，DAS 图像中也可能只形成一个较宽峰或只有很浅的中间谷值。

本质仍然是：

$$
\boxed{
\text{finite aperture}
\Rightarrow
\text{finite-width PSF}
}
$$

高级 beamformer 若声称“提高分辨率”，首先就应当与相同 acquisition、相同 grid、相同显示条件下的 DAS PSF 比较。

---

### 27.2 强目标掩盖弱目标：动态范围与旁瓣污染

若强散射体幅度为 $A_s$，弱散射体幅度为 $A_w$，并且：

$$
A_w \ll A_s,
$$

那么强目标的 main-lobe tail、sidelobe 或其他空间响应可能高于弱目标本身。

结果是：

> 弱目标物理上存在，但在 DAS 空间响应中不容易从强目标背景中区分出来。

这类问题与：

- sidelobe suppression；
- clutter suppression；
- contrast；
- target detectability

直接相关。

配套 synthetic demo 只用于展示机制，弱目标位置和幅度是为当前模型选择的教学参数，不是通用阈值。

---

### 27.3 独立随机噪声：DAS 实际上有 coherent gain

不要把所有“不想要的信号”都称作同一种 noise。

对于各通道上独立、零均值、等方差的随机噪声，如果 normalized DAS 使用：

$$
w_m=\frac1M,
$$

则正确聚焦的相干信号幅度基本保持，而独立噪声标准差约降低为：

$$
\frac{\sigma}{\sqrt M}.
$$

因此理想功率 SNR 增益约为：

$$
M,
$$

换成 dB：

$$
G_{\mathrm{SNR}}
\approx
10\log_{10}M.
$$

对于 $M=64$：

$$
G_{\mathrm{SNR}}
\approx
18.1\ \mathrm{dB}.
$$

因此：

> **独立随机噪声不是 DAS 最核心的失败点；DAS 本身就擅长 coherent integration。**

真正困难的是：

- reverberation；
- sidelobe clutter；
- coherent interference；
- phase-correlated clutter；
- model mismatch；

这些并不满足“独立白噪声”的简单假设。

---

### 27.4 Sound-speed mismatch：传播模型错误

如果真实声速为：

$$
c_{\mathrm{true}},
$$

但 beamformer 使用：

$$
c_{\mathrm{BF}} \neq c_{\mathrm{true}},
$$

那么：

$$
\hat\tau_m
\neq
\tau_m^{\mathrm{true}}.
$$

其结果不只是“图像略微模糊”，还可能包括：

- axial misregistration；
- lateral defocus；
- peak amplitude reduction；
- coherence loss；
- PSF distortion。

这说明更高级的 channel-combination 方法也无法自动修复一个严重错误的传播模型。

---

### 27.5 Phase aberration：阵元间相对时延被破坏

组织非均匀声速、传播路径差异或系统通道误差都可能导致额外的 channel-dependent delay。

可以写成：

$$
\tau_m^{\mathrm{measured}}
=
\tau_m^{\mathrm{ideal}}
+
\delta\tau_m.
$$

其相位误差近似为：

$$
\Delta\phi_m
=
2\pi f_c\delta\tau_m.
$$

如果 $\delta\tau_m$ 随阵元变化，那么即使 beamformer 使用理想几何 delay，也无法完全对齐各通道。

于是会出现：

- coherent sum 降低；
- PSF 展宽或变形；
- sidelobe / clutter 变化；
- peak position 或强度改变。

配套脚本使用的是**人工构造的空间相关 delay perturbation**，用于演示机制，不等同于真实组织 aberration 的完整统计模型。

---

## 28. DAS 为什么仍然必须作为后续算法的基线

学完 failure modes 后，不应该得到：

> “DAS 很差，所以应该换高级算法。”

正确结论是：

> **DAS 是物理意义最清楚、假设最透明、最适合做统一基线的 beamformer。**

后续算法都需要回答：

1. 它解决了 DAS 的哪个具体 failure mode？
2. 它是否仍使用同一个 propagation delay？
3. 它额外利用了什么信息？
4. 它付出了什么计算、统计或鲁棒性代价？
5. 改善的是 PSF、contrast、noise、clutter 还是 coherence？
6. 改善是否在相同 acquisition / grid / display 条件下成立？

---

# 第一讲总结

## 29. 一张图串起整讲

```text
真实散射体
    ↓
Tx propagation
    ↓
不同 Rx element 上形成不同 arrival time
    ↓
raw channel RF / IQ
    ↓
根据 candidate pixel 计算 Tx + Rx delay
    ↓
sub-sample interpolation
    ↓
focused aperture vector s(r)
    ↓
aperture selection + apodization
    ↓
coherent sum
    ↓
DAS pixel
    ↓
扫描 x,z
    ↓
PSF / B-mode
```

真正需要记住的是中间这一步：

$$
\boxed{
\mathbf s(\mathbf r)
=
[s_1(\mathbf r),\ldots,s_M(\mathbf r)]^T
}
$$

它是后续 CF、MV、DMAS、SLSC 等算法共同面对的输入对象。

---

## 30. 第一讲的核心公式

### 总传播时间

$$
\tau_m(\mathbf r)
=
\tau_{\mathrm{TX}}(\mathbf r)
+
\tau_{\mathrm{RX},m}(\mathbf r).
$$

### 接收传播时间

$$
\tau_{\mathrm{RX},m}
=
\frac{\|\mathbf r-\mathbf r_m\|}{c}.
$$

### Delay 后的通道值

$$
s_m(\mathbf r)
=
x_m\!\left(\tau_m(\mathbf r)\right).
$$

### DAS

$$
y_{\mathrm{DAS}}(\mathbf r)
=
\sum_{m=1}^{M}
w_m(\mathbf r)s_m(\mathbf r).
$$

### Residual delay

$$
\epsilon_m
=
\tau_m^{\mathrm{true}}
-
\hat\tau_m.
$$

### 对应相位误差

$$
\Delta\phi_m
=
2\pi f_c\epsilon_m.
$$

### 横向分辨率尺度

$$
\Delta x
\sim
\frac{\lambda z}{D}
=
\lambda F\#.
$$

### 经典轴向分辨率尺度

$$
\Delta z_{\mathrm{axial}}
\sim
\frac{\mathrm{SPL}}{2}.
$$

---

## 31. 第一讲必须区分开的五组概念

### Acquisition 与 Beamformer

```text
PW / FI / DW / STA
≠
DAS / CF / MV / DMAS / SLSC
```

发射方式改变 $\tau_{\mathrm{TX}}$，而 beamformer 决定 delay 后通道如何组合。

### RF 与 IQ

RF 是实值载波信号；complex IQ 保留幅度与相位信息。

在 coherent beamforming 完成前，不能没有依据地先取：

```matlab
abs(IQ)
```

否则相位信息会丢失。

### Axial 与 Lateral resolution

```text
Axial
→ pulse length / bandwidth

Lateral
→ aperture / F-number / focusing
```

### Sidelobe 与 Grating lobe

```text
Sidelobe
→ finite aperture / weighting

Grating lobe
→ spatial sampling / pitch
```

### Independent noise 与 Clutter

独立随机噪声可以被 coherent averaging 明显抑制。

真实 clutter / reverberation / coherent interference 通常具有结构和相关性，不能简单套用独立噪声结论。

---

## 32. DAS 的优势与边界

### 优势

- 物理意义直接；
- 实现简单；
- 计算路径透明；
- 对独立噪声有 coherent gain；
- 很适合作为所有高级 beamformer 的 baseline；
- 对 acquisition model 的关系最容易检查。

### 主要边界

- finite aperture 带来有限 lateral PSF；
- fixed apodization 存在 mainlobe-sidelobe trade-off；
- 强目标响应可能掩盖弱目标；
- 对 sound-speed mismatch / phase aberration 敏感；
- 不主动判断通道之间“为什么一致或不一致”；
- fixed weights 不利用当前数据的统计结构。

正是这些边界，引出了后面的经典方法。

---

## 33. 从 DAS 自然走向后续算法

```text
DAS：固定权重，相干求和
│
├─ “这些通道真的一致吗？”
│      → CF / GCF / coherence weighting
│
├─ “为什么权重必须预先固定？”
│      → MV / MVDR / Capon
│
├─ “能否直接使用通道两两关系？”
│      → DMAS / fDMAS
│
├─ “能否直接用 spatial coherence 成像？”
│      → SLSC
│
└─ “能否利用 beam-pattern null？”
       → NSI
```

因此第一讲真正完成的不是“学会一个公式”，而是建立后续所有经典 beamformer 的共同坐标系。

---

## 34. 第一讲自测

进入下一章前，建议自己尝试回答：

1. 为什么 raw channel data 中的点目标回波是一条弯曲轨迹？
2. Delay compensation 数学上究竟做了什么？
3. 为什么错误 delay 会转化成 phase error？
4. 为什么 `interp1` / sub-sample interpolation 对 RF beamforming 很重要？
5. 为什么 aperture 增大通常让 lateral PSF 变窄？
6. F-number 与 dynamic aperture 有什么关系？
7. 为什么 Hann 可以降低 sidelobe，却通常让 main lobe 变宽？
8. 为什么 axial resolution 主要与 bandwidth / pulse length 有关？
9. 为什么 sound-speed mismatch 既可能造成位置偏差，也可能造成 defocus？
10. 为什么独立 noise 和 reverberation/clutter 不能当成同一个问题？
11. `focused_samples` 在后续 CF、MV、DMAS、SLSC 中扮演什么角色？
12. 为什么 DAS 应继续作为后续所有算法比较的统一 baseline？

如果这 12 个问题能够不用背定义、而是从传播和通道数据的角度解释出来，第一讲的目标就达到了。

---

**第一讲结束。下一阶段开始进入真实 UFF channel data 上的 DAS 实现，并以此作为后续 CF / MV / DMAS / SLSC / NSI 的统一 baseline。**
