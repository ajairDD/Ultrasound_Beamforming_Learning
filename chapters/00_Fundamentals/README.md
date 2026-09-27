# 第 0 章：波束合成共同基础

> 这一章不是“DAS 算法实现章”。  
> 它的任务是先建立后面所有经典 beamformer 共用的物理、信号和阵列语言。  
> 真正的真实 UFF DAS 实现在 **第 1 章**。

---

## 0.1 这一章最终要建立什么能力

学完以后，不要求你背很多公式，但应该能够从 channel data 的角度解释：

1. 为什么一个点散射体会在不同阵元上产生不同 arrival time；
2. Delay 到底补偿什么；
3. 为什么正确 Delay 能产生 coherent summation；
4. Tx delay 与 Rx delay 分别来自哪里；
5. 为什么 sub-sample interpolation 不只是实现细节；
6. aperture、F-number、apodization 如何改变 lateral PSF；
7. bandwidth / pulse length 为什么主要决定 axial resolution；
8. sidelobe 与 grating lobe 为什么不是同一个东西；
9. sound-speed mismatch 与 phase aberration 为什么会破坏聚焦；
10. 为什么独立随机噪声和真实 clutter / reverberation 不能混为一谈；
11. 后续 CF、MV、DMAS、SLSC、NSI 到底是在 DAS 的哪一层继续挖掘信息。

这一章的主线可以压缩成：

~~~text
空间位置
   ↓
传播距离
   ↓
Tx / Rx propagation time
   ↓
channel RF / IQ 中的时间和相位结构
   ↓
Delay + interpolation
   ↓
focused aperture vector
   ↓
aperture / apodization
   ↓
coherent sum
   ↓
PSF / image
~~~

---

# 1. 从一个点散射体开始

先只考虑最简单的场景：

- 一把 1-D linear array；
- 均匀介质；
- 一个点散射体；
- 已知声速 $c$；
- 每个接收阵元都能看到该散射体的回波。

~~~mermaid
flowchart TB
    A[Linear array: element 1 ... M] --> B[Transmit acoustic wave]
    B --> C[Point scatterer r = (x,z)]
    C --> D1[Echo to element 1]
    C --> D2[Echo to element 2]
    C --> D3[Echo to element M]
    D1 --> E[Different arrival times]
    D2 --> E
    D3 --> E
    E --> F[Delay compensation]
    F --> G[Alignment across aperture]
    G --> H[Weighted coherent sum]
~~~

同一个散射体到不同阵元的传播距离不同，所以回波不会在所有 channel 上同时到达。

这就是 beamforming 必须存在的第一个原因。

---

# 2. 探头、波长、时间采样和空间采样

一个典型教学参数可以是：

$$
c=1540\ \mathrm{m/s},
$$

$$
f_c=5\ \mathrm{MHz},
$$

$$
f_s=40\ \mathrm{MHz}.
$$

波长：

$$
\lambda
=
\frac{c}{f_c}
=
0.308\ \mathrm{mm}.
$$

载波周期：

$$
T_c
=
\frac1{f_c}
=
0.2\ \mu s.
$$

采样周期：

$$
T_s
=
\frac1{f_s}
=
25\ ns.
$$

因此一个 5 MHz 周期大约包含 8 个采样点。

这里要分清两种完全不同的“采样”：

~~~text
fs
→ 时间采样

pitch
→ 阵列空间采样
~~~

后者与 grating lobe 有关，前者与 delay 的离散实现、插值和相位误差有关。

---

# 3. Tx delay + Rx delay

设候选成像点：

$$
\mathbf r=(x,z),
$$

第 $m$ 个阵元位置：

$$
\mathbf r_m=(x_m,0).
$$

总传播时间通常写成：

$$
\boxed{
\tau_m(\mathbf r)
=
\tau_{\mathrm{TX}}(\mathbf r)
+
\tau_{\mathrm{RX},m}(\mathbf r)
}
$$

接收传播时间在均匀声速模型下为：

$$
\tau_{\mathrm{RX},m}(\mathbf r)
=
\frac{\|\mathbf r-\mathbf r_m\|}{c}.
$$

Tx 部分取决于 acquisition。

例如 broadside plane wave 的理想化模型中：

$$
\tau_{\mathrm{TX}}(x,z)
=
\frac{z}{c}.
$$

但 Focused Imaging、steered Plane Wave、Diverging Wave、STA 的 Tx 几何并不相同。

因此从一开始就要建立：

$$
\boxed{\text{Acquisition} \neq \text{Beamformer}}
$$

完全可以存在：

~~~text
Plane Wave + DAS
Plane Wave + MV
Focused Imaging + DAS
Focused Imaging + DMAS
~~~

同样的 beamformer 可以作用在不同 acquisition 上，但 Tx delay 模型不能混用。

---

# 4. 为什么原始 channel data 中点目标是一条弯曲轨迹

假设真实点目标位于 $(x_0,z_0)$。

对于 broadside plane-wave 示例，第 $m$ 个通道的真实到达时间为：

$$
\tau_m^{\mathrm{true}}
=
\frac{z_0}{c}
+
\frac{\sqrt{(x_0-x_m)^2+z_0^2}}{c}.
$$

因为存在：

$$
\sqrt{(x_0-x_m)^2+z_0^2},
$$

所以 $\tau_m$ 随阵元位置 $x_m$ 变化是一条曲线。

近轴条件下：

$$
\sqrt{z_0^2+(x_m-x_0)^2}
\approx
z_0+\frac{(x_m-x_0)^2}{2z_0},
$$

因此轨迹看起来近似抛物线。

~~~text
absolute time
    ↓

             ______
          __/      \__
       __/            \__
______/                  \______

──────────────────────────────→ element position
~~~

这条曲线不是显示伪影，它就是点目标的传播几何在 channel domain 中留下的痕迹。

---

# 5. Delay 的真正作用：把传播轨迹“拉直”

Beamformer 对每个候选像素 $(x_f,z_f)$ 预测一套传播时间：

$$
\hat\tau_m(x_f,z_f).
$$

定义 residual delay：

$$
\boxed{
\epsilon_m
=
\tau_m^{\mathrm{true}}
-
\hat\tau_m
}
$$

如果候选点恰好是真实点：

$$
(x_f,z_f)=(x_0,z_0),
$$

则：

$$
\epsilon_m\approx0
$$

对所有阵元成立。

如果定义相对时间 $\Delta t$，并重新取样：

$$
\tilde x_m(\Delta t)
=
x_m\!\left(\Delta t+\hat\tau_m\right),
$$

那么正确 focus 下，各个 channel 的 pulse 都会集中到：

$$
\Delta t\approx0.
$$

~~~text
Before focusing                 After correct focusing

ch 1      /\                    ch 1        /\
ch 2         /\                 ch 2        /\
ch 3   /\                       ch 3        /\
ch 4            /\              ch 4        /\
                                             ↑
                                          Δt = 0
~~~

这就是“Delay 把 channel trajectory 拉直”的准确含义。

---

# 6. Delay error 为什么会变成 phase error

对于窄带信号，时间误差可以转成相位误差：

$$
\boxed{
\Delta\phi_m
=
2\pi f_c\epsilon_m
}
$$

以 5 MHz 为例，25 ns 相当于：

$$
\Delta\phi
=
2\pi
(5\times10^6)
(25\times10^{-9})
=
45^\circ.
$$

而 25 ns 恰好是 40 MHz sampling frequency 的一个采样周期。

这说明：

> RF beamforming 中“只错一个 sample”并不是一个温和的误差。

半周期 100 ns 对应 180°，两个本该同相的通道甚至可能互相抵消。

---

# 7. 为什么需要 sub-sample interpolation

实际 ADC 数据是离散序列：

$$
x_m[n].
$$

理论 delay 对应的 sample location：

$$
u_m
=
\tau_m f_s
$$

通常不是整数。

如果只做：

~~~matlab
n = round(tau * fs);
~~~

最大量化误差大约是半个 sample。

在 5 MHz / 40 MHz 条件下，半 sample 就可能对应约 22.5° carrier phase error。

因此真实 DAS 至少要明确：

- nearest-neighbor；
- linear interpolation；
- spline / higher-order；
- fractional-delay filter；
- 或 complex IQ / frequency-domain phase rotation。

第 0 章 synthetic demo 使用线性插值，是为了让物理意义和实现都清楚。

---

# 8. focused aperture vector：后续所有算法的共同入口

对当前候选像素，在各阵元预测 delay 处取样：

$$
s_m(\mathbf r)
=
x_m\!\left(\tau_m(\mathbf r)\right).
$$

收集为：

$$
\boxed{
\mathbf s(\mathbf r)
=
[s_1(\mathbf r),s_2(\mathbf r),\ldots,s_M(\mathbf r)]^T
}
$$

这是这一章最重要的中间变量。

它不是最终图像，而是：

> **当前 candidate pixel 经过传播模型对齐后，在整个 aperture 上形成的一组 channel observation。**

DAS 只做：

$$
y_{\mathrm{DAS}}
=
\sum_{m=1}^{M}
w_m s_m.
$$

后面的算法几乎全部从 $\mathbf s(\mathbf r)$ 开始分家：

- CF：这些通道到底有多 coherent？
- MV/MVDR：权重能不能根据数据自适应？
- DMAS：通道两两之间能不能直接交互？
- SLSC：能否直接用 spatial coherence 成像？
- NSI：能否换一种 aperture / beam-pattern 利用方式？

---

# 9. 为什么正确 focus 会得到 coherent gain

若正确聚焦后：

$$
s_m\approx A,
$$

则：

$$
\sum_{m=1}^{M}s_m
\approx
MA.
$$

如果用 normalized DAS：

$$
y
=
\frac1M\sum_m s_m,
$$

则目标幅值大致保持为 $A$。

对于 complex IQ，可以写成：

$$
s_m
=
A_m e^{j\phi_m}.
$$

正确 focus：

$$
\phi_1\approx\phi_2\approx\cdots\approx\phi_M.
$$

相位矢量方向接近一致，求和较大。

错误 focus：

$$
\phi_m
$$

分散，向量部分抵消。

因此 DAS 的空间选择性，本质上来自：

$$
\boxed{
\text{position hypothesis}
\rightarrow
\text{predicted delay}
\rightarrow
\text{phase consistency}
}
$$

---

# 10. Point Spread Function：为什么点目标不会成像成无限小的点

即使 focus 没有完全落在真实目标上，只要候选位置足够近，residual delay 仍可能很小。

所以 DAS response 不会在真实位置外立即变成零，而会形成一个有限宽度的峰：

~~~text
             /\
            /  \
           /    \
__________/      \__________
~~~

这个点目标空间响应就是：

$$
\boxed{\text{Point Spread Function, PSF}}
$$

二维情况下：

$$
PSF(x,z).
$$

PSF 是后续比较 beamformer 最重要的基础工具之一。

---

# 11. Aperture 为什么控制 lateral resolution

有效 aperture 宽度记作 $D$。

当 aperture 较小时，候选 focus 横向移动一点，各阵元传播路径变化仍比较相似，因此错误位置还能保持一定 coherence。

当 aperture 增大，左右两端阵元距离更远，同样的横向位置误差会造成更明显的跨阵元 residual delay / phase difference。

所以：

~~~text
D ↑
↓
错误横向位置产生的跨孔径 phase mismatch ↑
↓
coherence 更快下降
↓
lateral PSF 变窄
↓
lateral resolution 提升
~~~

经典尺度关系：

$$
\boxed{
\Delta x
\sim
\frac{\lambda z}{D}
=
\lambda F\#
}
$$

这里是尺度关系，不是一个对所有 acquisition、window 和 PSF 定义都精确成立的固定系数公式。

---

# 12. F-number 与 dynamic receive aperture

定义：

$$
F\#
=
\frac{z}{D}.
$$

如果希望不同深度维持大致相近的 lateral-resolution 尺度，可以让：

$$
D(z)
\approx
\frac{z}{F\#}.
$$

于是：

~~~text
浅层 → 小 aperture
深层 → 大 aperture
~~~

这就是 dynamic receive aperture 的基本思想。

但 aperture 不可能无限增加，最终受：

- 物理阵元总数；
- pitch；
- probe geometry；
- 最小 / 最大 aperture

限制。

---

# 13. Apodization：主瓣与旁瓣的经典 trade-off

Uniform weighting：

$$
w_m=\text{constant}
$$

相当于一个边界比较硬的矩形 aperture。

它通常能获得较窄主瓣，但有限孔径截断会产生比较明显的 sidelobe。

Hann、Hamming 等 window 会降低 aperture 边缘阵元权重，使空间窗函数更平滑：

~~~text
Uniform
|████████████████████████|

Hann
|   ▂▄▆████████▆▄▂   |
~~~

结果通常是：

$$
\boxed{
\text{sidelobe}\downarrow
\quad\text{但}\quad
\text{main lobe width}\uparrow
}
$$

直觉上可以理解为：

> 边缘阵元被压低后，有效 aperture 变小了一部分。

这就是固定 apodization 最经典的 trade-off。

---

# 14. FWHM、-6 dB amplitude width 与 -3 dB half-power

如果归一化的是 amplitude：

$$
A_N(x)
=
\frac{|y(x)|}{\max |y|},
$$

半幅：

$$
A_N=0.5
$$

对应：

$$
20\log_{10}(0.5)
=
-6.02\ \mathrm{dB}.
$$

所以第 0 章脚本里测的 FWHM 更准确地说是：

> **-6 dB amplitude width**

不要与：

> **-3 dB half-power beamwidth**

混为一谈。

看论文时要确认作者的 width 定义。

---

# 15. Axial resolution 与 lateral resolution 来自不同机制

这一点必须彻底分开。

## Lateral

主要受：

- aperture；
- F-number；
- focusing；
- wavelength；
- apodization

影响。

尺度：

$$
\Delta x
\sim
\lambda F\#.
$$

## Axial

主要受 pulse 在时间方向上的长度影响。

如果 pulse 大约有 $N_c$ 个周期：

$$
\mathrm{SPL}
\approx
N_c\lambda,
$$

经典 pulse-echo 尺度关系：

$$
\boxed{
\Delta z_{\mathrm{axial}}
\sim
\frac{\mathrm{SPL}}{2}
}
$$

更短的 pulse：

~~~text
shorter temporal pulse
→ broader bandwidth
→ less echo overlap in depth
→ better axial resolution
~~~

因此：

$$
\boxed{
\text{Axial resolution mainly pulse/bandwidth-limited}
}
$$

而：

$$
\boxed{
\text{Lateral resolution mainly aperture/focusing-limited}
}
$$

---

# 16. Center frequency 与 bandwidth 不是一回事

Center frequency：

$$
f_c
$$

表示频谱中心。

Bandwidth：

$$
BW
$$

表示频谱展开范围。

两个探头即使都有 5 MHz center frequency，只要 bandwidth 不同，pulse duration 和 axial resolution 就可能明显不同。

粗略尺度：

$$
\Delta t
\sim
\frac1{BW},
$$

所以：

$$
\Delta z_{\mathrm{axial}}
\sim
\frac{c}{2BW}.
$$

具体系数取决于 pulse shape、bandwidth 定义和 width 指标，不能机械套固定常数。

---

# 17. 二维 PSF

真实点目标响应是：

$$
PSF(x,z).
$$

它同时包含：

- transmit field；
- receive aperture；
- pulse bandwidth；
- focusing；
- interpolation；
- apodization；
- two-way propagation。

二维 PSF 往往不是圆形，因为 axial 和 lateral 的控制机制不同。

~~~text
             axial
               ↓

             ▓▓▓
          ▓▓████▓▓
        ▓██████████▓
────────────●────────────→ lateral
        ▓██████████▓
          ▓▓████▓▓
             ▓▓▓
~~~

对于 3-D 系统还要再考虑 elevation resolution。

---

# 18. Sidelobe 与 grating lobe 不要混淆

Sidelobe：

> 主要来自 finite aperture / weighting 后的空间响应。

Grating lobe：

> 主要来自阵列空间采样，尤其与 pitch / wavelength 相关。

可以类比：

~~~text
时间采样：
fs 太低 → temporal aliasing

空间采样：
pitch 太大 → grating lobe
~~~

二者都可能产生离轴响应，但物理来源不同。

---

# 19. DAS Failure Mode 1：两个目标太近

有限 aperture 意味着有限宽度 PSF。

两个 lateral point target 如果间距小于当前系统有效分辨尺度，其 PSF 会重叠：

~~~text
far enough:
      /\            /\
_____/  \__________/  \_____

too close:
        /\  /\
_______/  \/  \_______
~~~

这不是 DAS “算错”，而是：

$$
\boxed{
\text{finite aperture}
\Rightarrow
\text{finite PSF}
\Rightarrow
\text{finite resolution}
}
$$

因此任何声称“提高 resolution”的 beamformer，都应该在相同 acquisition / grid / display 条件下与 DAS PSF 公平比较。

---

# 20. DAS Failure Mode 2：强目标掩盖弱目标

强散射体的响应不只存在于目标中心，还包括：

- main-lobe tail；
- sidelobe；
- 其他 off-axis response。

如果：

$$
A_{\mathrm{strong,response}}
>
A_{\mathrm{weak,target}},
$$

弱目标就可能被掩盖。

所以：

> resolution 足够，并不代表 weak-target detectability 一定足够。

这类问题涉及：

- sidelobe；
- dynamic range；
- clutter；
- contrast；
- CNR / gCNR。

---

# 21. 独立随机噪声并不是 DAS 的“纯失败项”

设 normalized DAS：

$$
y
=
\frac1M
\sum_{m=1}^{M}
(A+n_m),
$$

其中 $n_m$ 为彼此独立、零均值、等方差噪声。

正确聚焦信号：

$$
\frac1M\sum_m A
=
A.
$$

噪声标准差：

$$
\sigma_{\mathrm{out}}
=
\frac{\sigma}{\sqrt M}.
$$

理想功率 SNR 增益：

$$
\boxed{
G_{\mathrm{SNR}}
\approx
10\log_{10}M\ \mathrm{dB}
}
$$

$M=64$ 时约为 18.1 dB。

因此 DAS 对独立随机噪声本身其实有很好的 coherent integration gain。

真正难处理的是：

- reverberation；
- sidelobe clutter；
- coherent interference；
- phase-correlated clutter。

所以必须区分：

$$
\boxed{
\text{independent noise}
\neq
\text{clutter}
\neq
\text{reverberation}
}
$$

---

# 22. DAS Failure Mode 3：sound-speed mismatch

如果：

$$
c_{\mathrm{BF}}
\neq
c_{\mathrm{true}},
$$

那么：

$$
\hat\tau_m
\neq
\tau_m^{\mathrm{true}}.
$$

可能同时出现：

- axial misregistration；
- lateral defocus；
- peak amplitude reduction；
- coherence loss；
- PSF distortion。

因此“更高级的 channel combination”不等于自动修复传播模型。

如果 delay 本身严重错误，后面的 CF、MV、DMAS 同样是在错误对齐的数据上工作。

---

# 23. DAS Failure Mode 4：phase aberration

可以把额外的 channel-dependent delay 写成：

$$
\tau_m^{\mathrm{measured}}
=
\tau_m^{\mathrm{ideal}}
+
\delta\tau_m.
$$

对应 phase error：

$$
\Delta\phi_m
=
2\pi f_c\delta\tau_m.
$$

只要 $\delta\tau_m$ 随阵元变化，理想几何 delay 就无法把所有通道完全对齐。

结果可能包括：

- coherent sum 降低；
- PSF 展宽或变形；
- sidelobe 变化；
- peak amplitude 降低；
- 左右不对称。

第 0 章 demo 使用的是人为构造的空间相关 delay perturbation，只用于解释机制，不等价于真实组织 aberration 的完整统计模型。

---

# 24. 一张表总结 DAS 的边界

| 情况 | 现象 | 核心原因 |
|---|---|---|
| 两目标太近 | 无法可靠分开 | finite PSF |
| 强目标 + 弱目标 | 弱目标被掩盖 | sidelobe / dynamic range |
| 独立随机噪声 | DAS 反而能改善 SNR | coherent averaging |
| 声速错误 | 移位 + 失焦 | propagation-model mismatch |
| phase aberration | coherence 下降、PSF 变形 | channel-dependent delay error |

所以不要把所有问题都笼统称为“DAS 抗噪不好”。

---

# 25. 为什么后续算法会自然出现

DAS 当前做的是：

$$
\boxed{
\text{fixed channel weighting + coherent sum}
}
$$

这自然产生几个问题。

~~~text
“这些 delayed channels 真的一致吗？”
          ↓
      CF / GCF

“为什么 weights 必须预先固定？”
          ↓
   MV / MVDR / Capon

“为什么只能逐通道相加？”
          ↓
       DMAS

“为什么 coherence 只能做权重？”
          ↓
       SLSC

“为什么只利用 main lobe？”
          ↓
        NSI
~~~

所以后面的经典方法不是几个互不相干的新公式，而是围绕同一个：

$$
\mathbf s(\mathbf r)
$$

在不同方向上继续利用信息。

---

# 26. 本章 MATLAB 实践顺序

代码位于：

**[matlab/00_Fundamentals](../../matlab/00_Fundamentals/)**

推荐顺序：

### 1. <code>demo_synthetic_point_target.m</code>

建立：

~~~text
point target
→ channel RF
→ Delay
→ interpolation
→ coherent sum
→ lateral response
~~~

### 2. <code>demo_delay_alignment.m</code>

重点观察：

- raw channel trajectory；
- correct delay 后“拉直”；
- wrong focus 的 residual delay；
- delay error 与 phase error。

### 3. <code>demo_aperture_psf_apodization.m</code>

比较：

- 16 / 32 / 64 active elements；
- F-number；
- lateral PSF；
- Uniform / Hann / Hamming；
- main-lobe / sidelobe trade-off。

### 4. <code>demo_axial_lateral_2d_psf.m</code>

区分：

- pulse duration / bandwidth → axial PSF；
- aperture → lateral PSF；
- 查看完整 2-D PSF。

### 5. <code>demo_das_failure_modes.m</code>

故意破坏理想条件：

- close targets；
- strong + weak targets；
- independent noise；
- sound-speed mismatch；
- phase-aberration-like delay perturbation。

---

# 27. 第 0 章的六条核心公式

总 delay：

$$
\boxed{
\tau_m
=
\tau_{\mathrm{TX}}
+
\tau_{\mathrm{RX},m}
}
$$

Delay 后样本：

$$
\boxed{
s_m(\mathbf r)
=
x_m(\tau_m)
}
$$

DAS：

$$
\boxed{
y_{\mathrm{DAS}}
=
\sum_m w_ms_m
}
$$

Residual delay：

$$
\boxed{
\epsilon_m
=
\tau_m^{\mathrm{true}}
-
\hat\tau_m
}
$$

Delay error 到 phase error：

$$
\boxed{
\Delta\phi_m
=
2\pi f_c\epsilon_m
}
$$

横向分辨率尺度：

$$
\boxed{
\Delta x
\sim
\lambda F\#
}
$$

轴向经典尺度：

$$
\boxed{
\Delta z_{\mathrm{axial}}
\sim
\frac{\mathrm{SPL}}{2}
}
$$

---

# 28. 进入第 1 章前的自测

如果以下问题能从传播和 channel data 的角度自己解释，第 0 章就算真正完成：

1. 为什么 raw channel data 中点目标形成弯曲 arrival-time trajectory？
2. Delay compensation 数学上究竟做了什么？
3. 为什么错误 delay 会变成 phase error？
4. 为什么 RF beamforming 需要 sub-sample interpolation？
5. 为什么 aperture 增大通常让 lateral PSF 变窄？
6. F-number 为什么能把 depth 与 aperture 联系起来？
7. Hann 为什么降低 sidelobe 却通常展宽 main lobe？
8. axial resolution 为什么主要由 bandwidth / pulse length 决定？
9. sound-speed mismatch 为什么既会造成位置错误也会造成 defocus？
10. independent noise 与 clutter / reverberation 为什么不能混为一谈？
11. $\mathbf s(\mathbf r)$ 在后续 CF、MV、DMAS、SLSC 中是什么角色？
12. 为什么 DAS 仍然应该作为后续方法统一 baseline？

---

# 29. 第 0 章一句话总结

如果只记住一句话：

$$
\boxed{
\text{Beamforming 是利用传播模型，把空间位置转化为跨阵元相干性，再利用这种相干性形成图像。}
}
$$

DAS 只是最朴素的实现：

$$
\boxed{
\text{Delay}
\rightarrow
\text{Weight}
\rightarrow
\text{Coherent Sum}
}
$$

下一章开始，我们不再停留在 synthetic model，而是进入：

> **真实 UFF channel data → 数据契约 → Tx/Rx delay → interpolation → 自己实现 MATLAB DAS → 点靶 PSF 验证。**
