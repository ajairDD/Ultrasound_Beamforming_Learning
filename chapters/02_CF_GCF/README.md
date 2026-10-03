# 第 2 章：Coherence Factor（CF）与 Generalized Coherence Factor（GCF）

第 0～1 章解决的是：

> **如何根据传播模型，把不同接收阵元的数据正确对齐。**

第 2 章开始问一个新的问题：

> **已经完成 delay alignment 的 aperture data，到底有多“相干”？**

本章第一阶段只研究 receive-domain coherence。对每一个 candidate pixel，我们已经有：

~~~text
s1, s2, s3, ... , sM
~~~

其中 sm 是第 m 个接收阵元在正确 Tx/Rx delay 后取出的 complex sample。

第 1 章的 DAS 直接做：

~~~text
s1 + s2 + ... + sM
~~~

而第 2 章开始问：

> 这些通道真的都支持“这里有一个正确聚焦的 echo”吗？

---

## 1. 为什么 DAS 后面还要看 coherence？

如果一个 pixel 真的是正确聚焦位置，delay alignment 后各通道应该大致：

~~~text
Ch1   ↑
Ch2   ↑
Ch3   ↑
Ch4   ↑
...
~~~

相加时会互相加强。

但如果这个 pixel 主要来自旁瓣、off-axis echo、reverberation、错误聚焦或噪声，delay 后各通道可能更像：

~~~text
Ch1   ↑
Ch2   ↗
Ch3   ↓
Ch4   ←
Ch5   ↘
...
~~~

DAS 仍然会机械地把它们全部加起来。

CF 的核心思想就是：

> **先估计这些已经对齐的通道到底有多一致，再用这个一致程度去给 DAS pixel 加权。**

---

## 2. CF 不修改 Tx/Rx delay

这点要和 RTB 分清。

CF 不重新计算传播路径，也不修改：

~~~text
Tx delay
Rx delay
interpolation
receive aperture
~~~

它拿到第 1 章已经形成的 aligned aperture vector：

~~~text
s = [s1, s2, ... , sM]
~~~

计算一个 0～1 左右的 coherence weight，然后：

~~~text
CF-weighted image
=
CF weight × DAS image
~~~

所以：

> **CF 是对 DAS 结果的自适应 coherence weighting，不是新的传播模型。**

---

## 3. 三种最直观状态

### 3.1 完全相干

~~~text
s = [↑ ↑ ↑ ↑ ↑ ↑ ↑ ↑]
~~~

所有通道方向一致。

CF 接近 1。

含义：

> 大部分通道能量都成功形成了 coherent sum。

### 3.2 部分相干

~~~text
s = [↑ ↑ ↗ ↑ → ↑ ↘ ↑]
~~~

大部分一致，但存在一定 phase error。

CF 在 0 和 1 之间。

### 3.3 不相干

~~~text
s = [↑ ↓ → ↙ ↗ ← ↓ ↑]
~~~

各通道方向比较随机。

虽然每个通道都可能有明显能量，但相干相加时会互相抵消。

CF 接近 0。

---

## 4. CF 的核心计算

对一个 pixel 的 M 个 active receive channels：

$$
S = \sum_{m=1}^{M}s_m
$$

CF：

$$
CF
=
\frac{
|S|^2
}{
M\sum_{m=1}^{M}|s_m|^2
}
$$

先不要背公式。

### 分子

~~~text
所有通道先相干相加
再看最终有多强
~~~

通道越同相，分子越大。

### 分母

~~~text
各通道原本一共有多少能量
~~~

所以 CF 实际在问：

> **你原来有这么多通道能量，最后到底有多少成功形成了 coherent sum？**

完全同相时 CF 接近 1。

相位混乱时，分子因相消而变小，但分母仍然保留每个通道本来的能量，因此 CF 下降。

---

## 5. CF 图像怎么形成？

~~~text
aligned aperture data
        ├──────────────→ CF weight
        │
        ↓
sum over Rx channels
        ↓
DAS complex signal
        │
        × CF
        ↓
CF-weighted complex image
~~~

即：

$$
y_{CF}(P)=CF(P)\,y_{DAS}(P)
$$

CF 本身不重新 beamform。

---

## 6. 为什么 CF 可能压低旁瓣和 clutter？

正确聚焦：

~~~text
↑ ↑ ↑ ↑ ↑ ↑ ↑ ↑
CF 高
~~~

错误聚焦或 off-axis contribution：

~~~text
↑ ↗ ↓ ← ↑ ↘ → ...
CF 低
~~~

所以 CF 倾向于：

~~~text
保留高相干区域
压低低相干区域
~~~

但必须注意：

> **CF 高不等于一定是真目标，CF 低也不等于一定是噪声。**

它衡量的是 aperture coherence，不是目标真假的分类器。

---

## 7. 历史位置

USTB 当前 coherence_factor 实现把 Mallart 和 Fink 1994 年关于 scattering media、sound-speed inhomogeneity 和 focusing criterion 的工作作为主要参考：

~~~text
Raoul Mallart, Mathias Fink
Adaptive focusing in scattering media through sound-speed inhomogeneities:
The van Cittert-Zernike approach and focusing criterion
JASA, 1994
DOI: 10.1121/1.410562
~~~

原论文的背景主要是 phase aberration、adaptive focusing 与 focusing criterion。

因此本教程使用更谨慎的表述：

> **现代 ultrasound coherence-factor weighting 的核心 focusing/coherence criterion 可以追溯到 Mallart–Fink 这条工作。**

---

## 8. GCF 为什么会出现？

把 aperture vector：

~~~text
s1, s2, ... , sM
~~~

看成一个沿阵元方向变化的“空间信号”。

如果所有阵元都很一致：

~~~text
↑ ↑ ↑ ↑ ↑ ↑ ↑ ↑
~~~

沿 aperture 几乎不变化，因此能量主要集中在很低的 spatial frequency，尤其是 DC。

如果阵元之间快速乱跳：

~~~text
↑ ↓ ↑ → ↓ ← ↑ ...
~~~

沿 aperture 变化很快，会出现更多高 spatial-frequency energy。

普通 CF 可以从 aperture spatial spectrum 的 DC coherence 来理解。

Li 和 Li 2003 提出的 GCF 把这个想法推广为：

> **不只看 DC，而是把一小段低空间频率区域都看成 coherent energy。**

GCF：

~~~text
低空间频率能量
----------------
全部空间频率能量
~~~

原论文：

~~~text
Pai-Chi Li, Meng-Lin Li
Adaptive imaging using the generalized coherence factor
IEEE TUFFC, 2003, 50(2):128-141
DOI: 10.1109/TUFFC.2003.1182117
~~~

原论文明确说明：当低频范围只保留 DC 时，GCF 会退化为文献中的 CF。

---

## 9. CF 和 GCF 一句话区别

CF：

> **这些通道是不是非常接近同相？**

GCF：

> **这些通道沿 aperture 的变化，有多少能量集中在低空间频率？**

GCF 因此多一个重要参数：

~~~text
M0
~~~

它控制多宽的 low-spatial-frequency region 被认为属于 coherent portion。

---

## 10. 第 2 章教学路线

~~~text
1. aperture vector 到底什么叫“相干”
        ↓
2. CF numerator / denominator
        ↓
3. synthetic aperture-vector 实验
        ↓
4. 从第 1 章 DAS 中拿真实 aligned aperture data
        ↓
5. Manual CF reconstruction
        ↓
6. DAS vs CF：PSF / sidelobe / contrast
        ↓
7. CF 的失败场景
        ↓
8. aperture FFT 的物理含义
        ↓
9. GCF
        ↓
10. M0 参数实验
        ↓
11. Manual vs USTB reference validation
~~~

真实数据阶段继续使用：

~~~text
data/L7_FI_TheGB.uff
~~~

这样 acquisition 不变，只改变 receive-channel combination / weighting。

---

## 11. 第一小节实验

运行：

~~~matlab
cd matlab/02_CF_GCF
demo_cf_aperture_vectors
~~~

它不需要 USTB。

构造四种 complex aperture vector：

~~~text
完全相干
部分相干
随机相位
单个强异常通道
~~~

同时观察：

- 每个 channel 的 phase；
- complex phasor；
- DAS coherent sum；
- CF；
- aperture spatial spectrum。

---

## 12. 这一小节只记三句话

1. **DAS 解决“怎么对齐并相加”，CF 解决“对齐以后这些通道到底有多一致”。**
2. **CF 高：通道能量大部分形成了 coherent sum；CF 低：很多能量在相互抵消。**
3. **GCF 把 CF 从“主要看 DC coherence”推广到“一段低 spatial-frequency energy”。**

---

## 13. 第二小节：从真实 UFF 中拿出 aligned aperture vector

前一小节里的箭头是人工构造的。

现在进入真实数据：

~~~text
L7_FI_TheGB.uff
~~~

但这一小节仍然故意使用 conventional FI，而不是 RTB。

原因是我们当前只想研究 **receive-domain coherence**：

~~~text
一个 pixel
    ↓
一个 focused Tx / scanline
    ↓
多个 receive channels
    ↓
CF
~~~

这样可以把 Tx 维度先固定住，不把 RTB 的 cross-Tx coherent combination 混进来。

### 13.1 一个真实 pixel 的数据流

第 1 章已经做过：

~~~text
pixel P
    ↓
计算 Tx delay
    ↓
计算每个 Rx element 的 Rx delay
    ↓
Tx delay + Rx delay
    ↓
每个 channel 得到自己的 RF query time
    ↓
fractional interpolation
    ↓
得到 aligned receive samples
~~~

这一小节只是：

> **在 DAS 求和之前停下来，把这组 samples 拿出来看。**

对于一个 pixel：

~~~text
focused_samples
shape = [1, N_channels]
~~~

应用 receive F-number 后只保留 active channels：

~~~text
s = focused_samples(active_channels)
shape = [1, M_active]
~~~

这个 s 就是第 2 章真正研究的对象。

### 13.2 为什么每个 Rx channel 的 query time 不一样？

因为同一个 pixel 到不同阵元的距离不同。

~~~text
E1   E2   E3   E4   E5
======================== probe
 \    \    |    /    /
  \    \   |   /    /
         pixel
~~~

中间阵元离 pixel 较近，边缘阵元传播路径更长。

所以每个 receive channel 都有自己的 tau_rx 和 query time。

真正的 delay alignment 就是：

> **每个通道不要在同一个 sample index 取值，而是在属于自己的 query time 上取值。**

### 13.3 对齐之后，才得到 CF 的输入

假设 active Rx 有 40 个：

~~~text
s1 s2 s3 ... s40
~~~

这些并不是原始 RF 在同一个 sample index 上的 40 个数。

它们是分别在 40 个不同 query times 上经过插值得到的 complex samples。

所以：

> **CF 的输入必须是 delay-aligned aperture vector，而不能直接拿原始 RF 某一个固定 sample index 的所有通道来算。**

### 13.4 本节脚本

运行：

~~~matlab
addpath(genpath('D:/USTB'));
addpath('../01_DAS_Real_UFF');

cd matlab/02_CF_GCF
inspect_real_cf_aperture_vectors
~~~

脚本先调用第 1 章已经验证过的 conventional FI-DAS，形成图像，然后让你点击 3 个位置。

建议：

~~~text
P1：bright / point-like target
P2：ordinary speckle
P3：weak / clutter / suspicious region
~~~

点击以后，x 会吸附到最近的真实 FI scanline，z 也吸附到第 1 章相同的 z-grid。

### 13.5 每个点会显示什么？

第一列是 Tx+Rx query-time curve，用来重新连接第 1 章的 delay 概念。

第二列同时显示 aligned sample 的幅度和 phase。

第三列显示 normalized complex phasors：箭头方向越集中，通常 coherence 越高。

第四列显示 aperture spatial spectrum：越相干的 aperture vector，能量通常越集中在 DC / low spatial frequency，这会直接连接到后面的 GCF。

### 13.6 一个非常重要的数值验证

脚本会重新计算：

~~~matlab
coherent_sum = sum(aligned_active_samples);
~~~

然后和第 1 章同一个 pixel 的 complex DAS 值比较。

也就是说明确验证：

~~~text
这一小节取出来的 aperture vector
        ↓ sum
确实就是
第 1 章 DAS 使用的那组数据
~~~

如果 relative complex error 超过极小容差，脚本会直接报错。

> **数值验证说明**：这一节与 Chapter 1 必须使用完全相同的 metadata 数值类型、delay 算法和 interpolation。主要校验使用 `|sum(s)-DAS| / sum(|s|)`；不要只除以 `|DAS|`，因为强相消 pixel 的 DAS complex sum 可能接近 0，导致所谓“relative error”被人为放大。
### 13.7 Shape 要牢牢记住

~~~text
rf_wave
[N_samples, N_channels]
        ↓

query_time
[1, N_channels]
        ↓

focused_samples
[1, N_channels] complex
        ↓ receive aperture

s
[1, M_active] complex
        ↓

DAS = sum(s)

CF = coherence(s)
~~~

以后 CF、GCF、SLSC、DMAS 等算法，本质上都会围绕这个 aligned aperture vector 展开。

---

## 14. 第二小节总结

这一节只需要记住：

1. **CF 的输入不是原始 RF，而是完成 Tx/Rx delay 和 interpolation 之后的 aperture samples。**
2. **Conventional FI 下，一个 pixel 对应一个 Tx，再沿 receive-channel 维计算 CF；这样最容易先把 receive coherence 学清楚。**
3. **如果把真实 aligned aperture vector 再做一次 sum，它必须回到第 1 章同一个 DAS pixel。**

下一小节开始，我们不再只看三个点，而是：

> **对整张 conventional FI 图的每一个 pixel 都计算 CF，得到第一张完整的 Manual CF 图像。**
---

## 15. 第三小节：整张 Manual CF 图像

前两小节只看单个 aperture vector。

现在对 conventional FI 图像中的每一个 pixel 都做同样的事情：

~~~text
pixel P
    ↓
Tx/Rx delay + interpolation
    ↓
aligned active Rx vector s
    ↓
DAS = sum(s)
    ↓
CF = |sum(s)|^2 / (M · sum(|s|^2))
    ↓
CF-weighted pixel = CF × DAS
~~~

这一节新增两个文件：

~~~text
reconstruct_fi_cf_manual.m
compare_manual_das_vs_cf.m
~~~

### 15.1 `reconstruct_fi_cf_manual.m` 做什么？

它完整重走 Chapter 1 的 conventional FI 路径，但在 DAS 求和之前保留当前 pixel 的 active aperture vector。

对每个 pixel：

~~~matlab
s = focused_samples(active);

coherent_sum = sum(s);
channel_energy = sum(abs(s).^2);

CF = abs(coherent_sum).^2 / ...
    (M*channel_energy);

cf_pixel = CF * coherent_sum;
~~~

因此它同时输出三类核心结果：

~~~text
DAS complex image
CF map
CF-weighted complex image
~~~

### 15.2 Shape

~~~text
das_analytic       [Nz, Nscanline] complex
cf_map             [Nz, Nscanline] real
cf_analytic        [Nz, Nscanline] complex
active_channel_count [Nz, Nscanline]
~~~

每一个 `cf_map(z,x)` 都来自这个 pixel 自己的 active receive aperture。

### 15.3 为什么 CF map 不是 B-mode？

`cf_map` 表示的是 coherence weight，而不是回波 amplitude。

~~~text
0   → 很低的 receive coherence
1   → 很高的 receive coherence
~~~

所以它不能直接当作超声灰阶图解释。

真正的 CF-weighted image 是：

~~~text
DAS complex image × CF map
~~~

### 15.4 为什么必须画两种 CF 图？

脚本会同时提供两种显示方式。

第一种使用 **DAS 的同一个 amplitude reference**：

~~~text
DAS
vs
DAS × CF
~~~

这种图可以真实看到 CF 把哪些区域压低了多少。

第二种是 DAS 和 CF 图各自 self-normalize。

它更适合看 morphology / apparent PSF，但会隐藏整体 attenuation。

所以：

> **判断 suppression 要看 common-reference 图；判断形态可以看 self-normalized 图。**

### 15.5 为什么不能看到 CF 图更“尖”就直接说 resolution 提高？

CF 是 nonlinear / adaptive weighting。

它可能把主瓣边缘、旁瓣和低相干背景压得更厉害，于是显示出来的亮结构会变窄。

这可以叫：

~~~text
apparent PSF narrowing
或
adaptive mainlobe narrowing
~~~

但不能仅凭这一点就直接说：

~~~text
系统物理 diffraction-limited resolution 提高了
~~~

后面需要把 point-target profile、FWHM、sidelobe 和 contrast 分开分析。

### 15.6 与 Chapter 1 的一致性检查

`compare_manual_das_vs_cf.m` 会独立调用 Chapter 1 的 `reconstruct_fi_scanline_manual.m`。

然后检查：

~~~text
Chapter-2 内部 DAS
vs
Chapter-1 DAS baseline
~~~

两条路径必须一致。

这保证：

> **这一节真正只增加了 CF weighting，没有悄悄改变 delay、interpolation 或 aperture。**

### 15.7 运行

~~~matlab
addpath(genpath('D:/USTB'));
addpath('../01_DAS_Real_UFF');

cd matlab/02_CF_GCF
compare_manual_das_vs_cf
~~~

重点看第一张图：

~~~text
Manual DAS
Receive-domain CF map
DAS × CF (same DAS amplitude reference)
~~~

然后再看第二张 self-normalized 对比。

---

## 16. 第三小节总结

这一节只需要记住：

1. **CF 是对每一个 pixel 的 aligned receive aperture vector 独立计算的。**
2. **CF map 是权重图，不是 B-mode；真正成像结果是 `CF × DAS`。**
3. **CF 改善视觉锐度并不自动等于物理 resolution 提升，后面必须把 mainlobe、sidelobe、contrast 分开验证。**

下一小节将专门分析：

> **DAS 与 CF 在 point target 上到底改变了什么：mainlobe、FWHM、sidelobe 还是背景 suppression？**
---

## 17. 已验证结果：整张 Manual CF 图像

在 `L7_FI_TheGB.uff`、Rx F# = 1.7、`n_z = 512` 下，本章 Manual CF 已完成一次真实运行验证。

Chapter 2 内部 DAS 与 Chapter 1 baseline 的 complex consistency：

~~~text
max abs complex error : 1.136868e-13
max-peak scaled error : 5.332858e-18
~~~

这说明本章在加入 CF 时没有改变原来的 Tx/Rx delay、interpolation 或 receive aperture 路径。

本次 CF map：

~~~text
min    = 0.000006
median = 0.178151
mean   = 0.237657
max    = 0.979233
~~~

其中 median CF = 0.178 对应每个 pixel 乘权后约 -15 dB 的 amplitude attenuation；而 max CF = 0.979 对应不到 -0.2 dB 的衰减。

图像上可直接看到：

- 高 coherence 的亮点基本保留；
- 大量低 coherence speckle / background 被明显压低；
- CF map 本身呈现的是 coherence distribution，而不是回波幅度；
- CF-weighted 图像的 speckle texture 被明显改变，因此“更黑、更干净”不能自动等价为“组织信息更真实”。

还要注意：dynamic receive F-number 使不同 pixel 的 active channel count M 不完全相同，因此跨深度直接比较 CF 数值时需要保留这个条件。

---

## 18. 第四小节：point-target profile，CF 到底改变了什么？

这一小节不再只看整张图视觉效果，而是选一个相对孤立的 point-like target，定量比较：

~~~text
DAS
vs
DAS × CF
~~~

新增脚本：

~~~text
analyze_das_vs_cf_point_target.m
~~~

它会独立寻找 DAS 和 CF 在同一局部 ROI 内的 local peak，并报告：

- peak location shift；
- common-reference target peak change；
- lateral -6 dB FWHM；
- axial -6 dB FWHM；
- lateral / axial -20 dB width；
- 每个 FWHM 跨多少实际 image samples。

其中：

> **-6 dB FWHM 用于描述主峰宽度；-20 dB width 主要用于观察 profile skirt suppression，不把它包装成正式 sidelobe 指标。**

另外，conventional FI 的 lateral spacing 仍然是一发一线，所以如果 lateral FWHM 只跨 1～2 个 scanline intervals，必须明确认为它受到 sampling 限制。

运行：

~~~matlab
cd matlab/02_CF_GCF
analyze_das_vs_cf_point_target
~~~

建议点击 z≈20 mm 附近那个相对孤立、明显的 point-like target。

下一步根据实际 profile 再判断：

~~~text
CF 主要做了主瓣 narrowing？
还是主要压了 profile skirt / background？
还是两者都有？
~~~
---

## 19. 已验证结果：point target 上 CF 到底改变了什么？

在同一个 point-like target 上，实测：

~~~text
DAS peak : x = -0.7450 mm, z = 20.1076 mm
CF peak  : x = -0.7450 mm, z = 20.1076 mm
peak shift = 0

CF weight at DAS peak = 0.978733
CF peak attenuation   = -0.187 dB
~~~

说明这个高相干目标的峰值几乎被完整保留。

### 19.1 -6 dB 主峰宽度

~~~text
lateral DAS = 0.708410 mm
lateral CF  = 0.420344 mm

axial DAS   = 0.446485 mm
axial CF    = 0.442143 mm
~~~

按数值比例看，横向 FWHM 约缩小 40.7%，而轴向只变化约 1.0%。

但横向必须谨慎解释：

~~~text
DAS lateral FWHM = 2.377 scanline intervals
CF  lateral FWHM = 1.411 scanline intervals
~~~

两者都少于 3 个 conventional-FI lateral samples，因此：

> **不能把 0.708 mm → 0.420 mm 当成高精度的“物理分辨率提高 40%”结论。**

更准确的表述是：

> **CF weighting 让 conventional-FI 点目标的显示主峰出现明显的 adaptive / apparent lateral narrowing，但该数值受到 scanline sampling 强烈限制。**

### 19.2 轴向结果更有解释力

轴向 FWHM：

~~~text
0.446485 mm → 0.442143 mm
~~~

只变化约 1%。

这与算法结构一致：当前 CF 是 receive-aperture coherence weighting，不改变发射脉冲带宽，也没有改变 axial delay model。

所以当前数据不支持“CF 明显改善 axial resolution”的说法。

### 19.3 -20 dB profile width

~~~text
lateral : 1.158868 mm → 0.982194 mm   (~15.2% reduction)
axial   : 1.020281 mm → 0.957728 mm   (~6.1% reduction)
~~~

这说明 CF 不只是改变 -6 dB 主峰显示宽度，也在压低 target profile 的外围 skirt。

但由于真实 phantom profile 中混有周围 speckle / scatterers，这里的 -20 dB width 只用于描述 profile skirt，不能直接等同于严格的 peak-sidelobe-level。

### 19.4 这一组结果真正支持的结论

当前数据支持：

1. 高相干 point target peak 基本保留（仅约 -0.19 dB）；
2. lateral displayed profile 明显变窄，但 conventional-FI lateral sampling 不足以支持高精度 resolution 数值结论；
3. axial FWHM 几乎不变；
4. lateral / axial profile skirts 都有一定 suppression，其中 lateral 更明显。

因此目前最稳妥的总结是：

> **在这组数据上，receive-domain CF 的主要可见效果是强烈的横向自适应收窄与背景/外侧响应抑制，而不是明显改变轴向主瓣。**

---

## 20. 第五小节：CF 的一个局限，以及 GCF 为什么出现

前面 P3 的真实 aperture vector 已经给了一个很重要的线索：

~~~text
CF 很低
但 aperture spectrum 并不是完全随机铺开
而是有大量能量落在 DC 附近的低 spatial-frequency bin
~~~

这说明普通 CF 有时会过于严格。

CF 基本只奖励：

~~~text
exact DC coherence
~~~

而一个平滑、确定性的 phase ramp：

~~~text
0°, 10°, 20°, 30°, 40°, ...
~~~

虽然不是随机噪声，却会把 aperture spectrum 的峰从 DC 移到旁边一个低频 bin。

这时：

~~~text
CF 可能很低
但 aperture 仍然具有很强的低阶结构
~~~

这正是 GCF 的出发点。

### 20.1 新实验

运行：

~~~matlab
demo_cf_failure_and_gcf_motivation
~~~

它比较三种 aperture vector：

~~~text
A. perfect coherence
B. smooth 1-bin phase ramp
C. random phase
~~~

并定义一个教学版 GCF：

~~~text
GCF(K)
=
FFT bins [-K ... 0 ... +K] 的能量
--------------------------------
全部 aperture FFT 能量
~~~

因此：

~~~text
K = 0
↓
只保留 DC
↓
正好退化为 CF
~~~

而 K = 1 时允许：

~~~text
-1, 0, +1
~~~

这些低空间频率一起作为 coherent energy。

### 20.2 为什么不能把 K 越调越大？

如果 K 不断增大：

~~~text
允许的 spatial-frequency band 越来越宽
~~~

最终连真正的高频不相干成分也会被计入 coherent energy。

所以 GCF 的核心不是“比 CF 更宽松就一定更好”，而是：

> **在保留低阶 coherent structure 与排除高 spatial-frequency incoherence 之间选择一个合理 low-frequency band。**

下一小节才正式把这个概念放回 `L7_FI_TheGB.uff`，实现完整 Manual GCF 图像。
---

## 21. 已验证结果：CF 局限与 GCF 动机

synthetic aperture-vector 实验得到：

~~~text
Perfect coherence
  CF      = 1.000000
  GCF K=1 = 1.000000

Smooth 1-bin phase ramp
  CF      = 0.000000
  GCF K=1 = 1.000000

Random phase
  CF      = 0.026378
  GCF K=1 = 0.039178
  GCF K=2 = 0.102806
  GCF K=4 = 0.206858
~~~

这组结果非常直接地说明：

- CF 对 exact-DC coherence 很敏感；
- 一个确定性的平滑 phase ramp 可以让 CF 变成 0，但它并不是随机不相干；
- 把邻近 low-spatial-frequency bins 纳入后，GCF 可以恢复这种低阶结构；
- low-frequency band 变宽时，随机相位也会被越来越多地计入，因此带宽不能无限增大。

---

## 22. 第六小节：完整 Manual GCF 图像

现在把 GCF 放回真实 `L7_FI_TheGB.uff`。

新增：

~~~text
reconstruct_fi_gcf_manual.m
compare_manual_das_cf_gcf.m
~~~

### 22.1 正式代码中的 M0 convention

正式 Manual GCF 采用清晰的低频半宽定义：

~~~text
M0 = 0
    -> 只使用 DC
    -> GCF 退化为普通 CF

M0 = 1
    -> 使用 {-1,0,+1}

M0 = 2
    -> 使用 {-2,-1,0,+1,+2}

M0 = 4
    -> 使用 {-4,...,0,...,+4}
~~~

也就是说：

> **M0 就是以 DC 为中心的 low-spatial-frequency half-width。**

这一约定和前面的教学参数 K 保持一致，因此不再让同一个整数在两处代表不同含义。

需要单独说明 USTB：当前 `generalized_coherence_factor` 和 `generalized_coherence_factor_OMHR` 代码存在 legacy special case：`M0=1` 仍只取 DC，只有 `M0>1` 才展开成 `{-M0,...,+M0}`。

因此：

> **本项目不把 USTB 的这个 legacy special case 当成 GCF 主定义。以后做 USTB reference validation 时，会显式做参数映射。**

本章当前推荐先从：

~~~text
M0 = 1
~~~

开始，因为它是比 CF 最小幅度的 generalized low-frequency extension。

### 22.2 单个 pixel 的 GCF

对 active aligned aperture vector：

~~~text
s = [s1, s2, ... , sM]
~~~

先做 receive-channel FFT：

~~~matlab
X = fft(s);
~~~

然后：

~~~text
GCF
=
low-spatial-frequency spectral energy
-------------------------------------
total aperture spectral energy
~~~

最后：

~~~text
GCF-weighted pixel = GCF × DAS
~~~

和 CF 一样，GCF 不重新计算 Tx/Rx delay；改变的是 aligned aperture data 的 coherence weighting。

### 22.3 一个必须通过的 identity check

程序会额外计算：

~~~text
GCF(M0=0)
~~~

因为这时只保留 DC，根据 Parseval 关系它必须和 ordinary CF 完全等价。

所以 `compare_manual_das_cf_gcf.m` 会检查：

~~~text
max |CF - GCF(M0=0)|
~~~

应该接近浮点误差。

这个验证比“图看起来差不多”更重要，因为它直接检查了 CF 与 GCF 数学定义的连接。

### 22.4 运行

~~~matlab
cd matlab/02_CF_GCF

M0 = 1;
compare_manual_das_cf_gcf
~~~

输出重点包括：

~~~text
DAS
DAS × CF
DAS × GCF

CF map
GCF map

GCF - CF weight map
~~~

前三张图共用 DAS peak 作为 amplitude reference，所以可以直接观察真实 suppression 强弱。

### 22.5 预期但尚未验证的现象

在真实数据运行之前，只能提出工作预期：

- GCF 通常会比 CF less aggressive，因为它允许邻近 low-frequency energy；
- 某些 CF 很低但存在 smooth phase structure 的区域，GCF weight 可能明显升高；
- M0 增大后背景也可能被更多保留。

这些都必须以实际 TheGB 运行结果为准，不能提前当作已验证结论。
---

## 23. 已验证结果：M0=2 在 TheGB 上过于宽松

真实 `L7_FI_TheGB.uff`、Rx F# = 1.7、`n_z = 512` 下，已经验证：

~~~text
CF statistics
  median = 0.178151
  mean   = 0.237657
  max    = 0.979233

GCF statistics, M0=2
  median = 0.748523
  mean   = 0.706695
  max    = 1.000000
~~~

同时：

~~~text
max |CF - legacy-DC GCF| ≈ 1e-15
~~~

说明上一版代码的 CF/GCF 数学连接本身没有问题；真正的问题是 `M0=2` 的 5-bin low-frequency band 对这份数据过于宽松。

图像上表现为：

- `DAS × CF` 对 background / speckle suppression 很强；
- `DAS × GCF(M0=2)` 与原始 DAS 非常接近；
- `GCF - CF` 在大片区域显著为正；
- GCF map 大量 pixel 权重在 0.6～1 附近。

因此当前数据支持的结论是：

> **对于 TheGB 这组正常 focused-imaging phantom 数据，M0=2 会保留过多 low-spatial-frequency energy；如果评价目标是 point-target突出和强背景抑制，它明显比 CF 更宽松。**

这不代表 GCF 普遍不如 CF。它说明 `M0` 必须和任务一起选择。

---

## 24. 第七小节：M0 参数扫描

现在直接比较：

~~~text
M0 = 0  -> CF
M0 = 1  -> 3-bin GCF
M0 = 2  -> 5-bin GCF
M0 = 4  -> 9-bin GCF
~~~

运行：

~~~matlab
experiment_gcf_m0_sweep
~~~

为了参数实验速度，默认使用：

~~~text
n_z = 256
~~~

确认趋势后，再把选中的 M0 用 `n_z=512` 重跑。

脚本会输出：

- 各 M0 的 common-reference GCF image；
- 各 M0 的 coherence-weight map；
- median / mean / min / max weight；
- median/mean weight 随 M0 的变化。

这一步的目的不是找一个“永远最好的 M0”，而是看清：

> **M0 从 0 增大时，算法是怎样一步步从严格 CF 走向越来越宽松的 low-frequency coherence。**

后续再根据 point target、contrast、speckle preservation 或 aberration robustness 决定评价标准。
---

## 25. 已验证结果：M0 sweep

在 `L7_FI_TheGB.uff`、Rx F# = 1.7、`n_z = 256` 下，得到：

~~~text
M0    min          median      mean        max
0     6.46e-7      0.17847     0.23755     0.97648
1     0.00315      0.56509     0.54686     0.98889
2     0.01209      0.74785     0.70652     1.00000
4     0*           0.89553     0.86755     1.00000
~~~

`M0=4` 的 `min=0` 已确认不是物理结果，而是旧版代码对短 active aperture 直接置零造成的人工边界效应；该逻辑已经修正为自动裁剪 effective M0，不再制造假黑点。

因此本次可以直接信任 `M0=0/1/2` 的统计趋势；`M0=4` 的精确 minimum / mean 建议在修正版上重跑后再作为最终数值。

### 25.1 最重要的定量现象

从 mean weight 看：

~~~text
M0=0 : 0.23755
M0=1 : 0.54686
M0=2 : 0.70652
~~~

因为 GCF 分子只是逐步加入更多非负 spectral energy，所以这些差值可以直观理解为：

~~~text
DC 本身平均贡献                    ≈ 23.8%
加入 ±1 bins 后累计               ≈ 54.7%
再加入 ±2 bins 后累计             ≈ 70.7%
~~~

这说明 TheGB 的 delay-aligned receive-aperture spectrum 中，大量能量并不严格停留在 DC，而是分布在 DC 附近几个低 spatial-frequency bins。

这正是为什么：

- CF 对这份数据非常 aggressive；
- `M0=1` 已经明显比 CF 宽松；
- `M0=2` 更接近原始 DAS。

### 25.2 当前不能得出的结论

不能仅凭“CF 图更黑”就说 CF 比 GCF 更正确。

当前只能说：

> **如果目标是强 point-target / background suppression，CF 更符合当前视觉目标；如果目标包括保留 diffuse speckle 或容忍低阶 phase variation，GCF 可能更合理。**

最终 M0 应该由任务指标决定，而不是由“看起来最干净”决定。

---

## 26. 第八小节：point target 上比较 M0=0 / 1 / 2

下一步只比较：

~~~text
M0=0  -> CF
M0=1  -> 3-bin GCF
M0=2  -> 5-bin GCF
~~~

运行：

~~~matlab
analyze_gcf_m0_point_target
~~~

建议继续点击前面已经使用过的 z≈20 mm 孤立 point-like target。

脚本会输出：

- target coherence weight；
- target peak attenuation；
- lateral / axial -6 dB FWHM；
- lateral / axial -20 dB width；
- 三种 M0 的 lateral / axial profile。

这一节要回答的是：

> **从 CF 放宽到 GCF 后，究竟保留了多少目标峰值，又牺牲了多少 profile / background suppression？**

这比仅比较整张 B-mode 图更能说明 M0 的代价与收益。
---

## 27. 已验证结果：point target 上的 M0 trade-off

在同一个 point-like target 上，得到：

~~~text
M0  target weight  peak change   lateral FWHM  axial FWHM  lateral -20 dB  axial -20 dB
0   0.97648        -0.2067 dB    0.4241 mm     0.4458 mm   0.9871 mm       0.9623 mm
1   0.98076        -0.1687 dB    0.6490 mm     0.4479 mm   1.1504 mm       0.9880 mm
2   0.98323        -0.1469 dB    0.6802 mm     0.4494 mm   1.1530 mm       1.0279 mm
4   0.98695        -0.1141 dB    0.7032 mm     0.4506 mm   1.1552 mm       1.0375 mm
~~~

lateral spacing = 0.297981 mm；axial spacing = 0.156863 mm。

### 27.1 目标中心几乎不受 M0 影响

target weight 从 0.9765 增加到 0.9870，对应 peak attenuation 仅从约 -0.21 dB 变化到 -0.11 dB。

说明这个高相干点目标中心无论 CF 还是 GCF 都基本被保留。

### 27.2 真正被 M0 改变的是横向 profile

lateral FWHM：

~~~text
M0=0 : 0.424 mm
M0=1 : 0.649 mm
M0=2 : 0.680 mm
M0=4 : 0.703 mm
~~~

前面 DAS 的 lateral FWHM 约为 0.708 mm，因此 `M0=4` 已几乎回到 DAS。

这说明：

> **CF 的强 lateral narrowing 主要来自对主峰中心以外 aperture structure 的严格抑制；一旦把邻近 low-spatial-frequency bins 纳入，横向 profile 会迅速恢复。**

尤其是 `M0=1`，只加入 ±1 两个 bins，就已经从 0.424 mm 回到 0.649 mm。

### 27.3 轴向几乎不变

~~~text
0.446 ~ 0.451 mm
~~~

不同 M0 的 axial FWHM 基本一致，再次说明 CF/GCF 主要改变 receive-aperture 横向相干加权，而不是 axial pulse response。

### 27.4 -20 dB width 也说明同样趋势

lateral -20 dB width：

~~~text
0.987 mm → 1.150 → 1.153 → 1.155 mm
~~~

说明 `M0=1` 已经恢复了大部分 CF 原先压掉的 lateral profile skirt。

因此目前对 TheGB 的 point-target 结论是：

> **M0 增大带来的主要收益不是“更保留点目标峰值”——峰值本来就几乎完整；它主要是在恢复 CF 原本强烈压制的横向外围和低阶 aperture structure。**

这也说明为什么必须继续看 homogeneous speckle：GCF 的价值更可能体现在 diffuse scattering / texture preservation，而不是这个高相干点目标中心。

---

## 28. 第九小节：homogeneous speckle preservation

新增：

~~~text
analyze_gcf_speckle_roi.m
~~~

运行：

~~~matlab
analyze_gcf_speckle_roi
~~~

在 DAS 图上选择一个尽量均匀的 speckle ROI，两次点击给出矩形对角点。

避开：

- point target；
- 强边界；
- 明显 lesion / cyst 边缘；
- probe lateral edge。

脚本比较 DAS、CF 与不同 M0 GCF 的：

- ROI mean envelope 相对 DAS 的衰减；
- envelope standard deviation；
- speckle SNR = mean/std；
- coefficient of variation；
- 与原始 DAS envelope texture 的 Pearson correlation；
- mean-normalized envelope histogram。

这一节要回答的核心问题是：

> **CF 把背景压得更黑时，到底是在去除“不相干 clutter”，还是也在强烈重塑正常 diffuse speckle？而 GCF 又保留了多少原始 speckle texture？**

这些统计只描述当前 ROI 的 texture 变化，不自动证明理想 Rayleigh speckle，也不构成临床图像质量结论。
---

## 29. 已验证结果：真实颈动脉上的 CF / GCF

对两个独立 focused-imaging carotid acquisition：

~~~text
L7_FI_carotid_cross_1.uff
L7_FI_carotid_cross_2.uff
~~~

使用同一套 Manual DAS / CF / GCF(M0=1) 代码，得到：

~~~text
cross 1
  CF median  = 0.037282
  CF mean    = 0.092375
  GCF median = 0.13792
  GCF mean   = 0.23105

cross 2
  CF median  = 0.034348
  CF mean    = 0.088520
  GCF median = 0.13131
  GCF mean   = 0.22724
~~~

并且 CF core 与 GCF core 的 DAS baseline 完全一致：

~~~text
DAS_core_scaled_error = 0
~~~

### 29.1 与 TheGB phantom 相比

TheGB 上此前约为：

~~~text
CF median      ≈ 0.178
GCF M0=1 median ≈ 0.565
~~~

而真实 carotid 上只有：

~~~text
CF median      ≈ 0.034 ~ 0.037
GCF M0=1 median ≈ 0.131 ~ 0.138
~~~

因此同一算法在人体数据上明显更 aggressive。

两个独立 acquisition 给出非常接近的统计值，说明这个现象具有一定重复性，不像是单次采集偶然。

### 29.2 图像上的共同现象

两个 carotid acquisition 都表现出：

- CF 把大量组织 speckle / 深部回波强烈压低；
- GCF(M0=1) 比 CF 保留更多组织纹理和结构连续性；
- GCF 仍然比 DAS 明显更暗；
- lumen 内部和周围低 coherence 区域都被显著抑制；
- 深部区域的 CF/GCF 权重整体偏低。

当前不能简单解释为“人体数据更差”或“GCF 更正确”。可能贡献因素包括：

- attenuation / SNR 随深度下降；
- sound-speed mismatch / phase aberration；
- diffuse scattering statistics；
- reverberation / clutter；
- dynamic receive aperture 随深度变化；
- 真实组织几何和 out-of-plane effects。

这些机制当前没有被单独控制，因此只能作为候选解释。

### 29.3 当前最重要的新问题

真实 carotid 上 CF/GCF 的强 suppression 看起来存在明显 depth dependence。

所以在继续做 ROI 评价之前，先需要确认：

> **coherence weight 是否随深度系统性下降，以及这个趋势与 DAS signal level、active Rx count 是否同时变化。**

---

## 30. 第十小节：真实 carotid 的 depth dependence

新增：

~~~text
analyze_carotid_cf_gcf_depth_dependence.m
~~~

运行：

~~~matlab
analyze_carotid_cf_gcf_depth_dependence
~~~

无需手工选 ROI。

脚本自动对两个 carotid acquisition 计算：

- central 80% lateral field 的 CF median / IQR；
- GCF(M0=1) median / IQR；
- median DAS envelope 随深度变化；
- median active Rx count 随深度变化；
- 5–15 / 15–25 / 25–35 / 35–45 mm 四个深度段的统计。

外侧 10% scanlines 被排除，以尽量减少 probe-edge aperture truncation 的影响。

这一步只用于识别 depth trend，不能单独证明趋势来自 attenuation、aberration 或其它某一种机制。
---

## 31. 已验证结果：真实 carotid 的 depth dependence

在两个独立 carotid focused-imaging acquisition 上，central 80% lateral field 的 coherence weight 都随深度明显下降。

### carotid cross 1

~~~text
depth      CF median   GCF median   DAS median level   active Rx median
5–15 mm      0.1056      0.3878        -18.94 dB           19.0
15–25 mm     0.0529      0.2103         -6.16 dB           39.0
25–35 mm     0.0230      0.0927        -14.35 dB           59.0
35–45 mm     0.0162      0.0601        -21.01 dB           77.5
~~~

### carotid cross 2

~~~text
depth      CF median   GCF median   DAS median level   active Rx median
5–15 mm      0.0968      0.3651        -16.53 dB           19.0
15–25 mm     0.0421      0.1853        -16.38 dB           39.0
25–35 mm     0.0191      0.0760        -21.41 dB           59.0
35–45 mm     0.0151      0.0560        -25.02 dB           77.5
~~~

### 31.1 可以确认的事实

两个独立 acquisition 都出现：

~~~text
depth ↑
CF median ↓
GCF median ↓
active receive aperture ↑
~~~

而 DAS median level 与 coherence weight 并不是简单一一对应。

例如 cross 1 中：

~~~text
5–15 mm  DAS = -18.94 dB, CF = 0.1056
15–25 mm DAS =  -6.16 dB, CF = 0.0529
~~~

DAS amplitude 明显更强，但 CF 反而约减半。

cross 2 中 5–15 mm 与 15–25 mm 的 DAS median level 几乎相同，但 CF / GCF 同样明显下降。

因此：

> **人体数据中的 coherence depth trend 不能仅用“深部信号更弱 / SNR 更低”解释。**

### 31.2 当前最重要的混杂因素

dynamic receive F-number 使 active Rx count 随深度系统性增加：

~~~text
约 19 → 39 → 59 → 77.5 channels
~~~

更大的 aperture 会采样更宽的横向范围，因此可能暴露更多：

- phase variation；
- sound-speed mismatch / aberration；
- off-axis / diffuse-scattering differences；
- clutter / reverberation。

所以目前不能把 coherence 下降唯一归因于深度、attenuation 或某一种物理机制。

如果未来专门研究这个问题，应该做 fixed-aperture / fixed-M 对照实验。

---

# 32. 第 2 章总结：CF / GCF

第 2 章到这里结束。

## 32.1 从 DAS 到 CF

Chapter 1 的 DAS：

~~~text
delay-aligned aperture vector
s = [s1, s2, ... , sM]
        ↓
sum(s)
        ↓
DAS
~~~

Chapter 2 增加的问题是：

> **这些已经对齐的 receive channels 到底有多一致？**

普通 CF 可以理解为 coherent energy 相对于总 channel energy 的归一化，也可以从 aperture spatial spectrum 理解为 DC energy fraction。

CF 高意味着 channel energy 大部分成功形成 coherent sum；CF 低意味着大量能量发生相消。

## 32.2 CF 的真实效果

在 TheGB point target 上：

- target peak 基本保留；
- lateral displayed profile 明显变窄；
- axial FWHM 基本不变；
- lateral profile skirt / background suppression 明显增强。

因此更准确的表述是：

> **CF 主要带来 adaptive lateral narrowing 与 low-coherence suppression，而不是改变 axial pulse response。**

同时 conventional-FI lateral sampling 较粗，因此不能把测得的 FWHM 缩小直接解释成高精度物理分辨率提升。

## 32.3 为什么需要 GCF

CF 只严格奖励 exact-DC coherence。

一个平滑 phase ramp 可能不是随机噪声，但能量会从 DC 移到邻近 low-spatial-frequency bins，这时 CF 可以很低。

GCF 因此使用 low-spatial-frequency spectral energy / total aperture spectral energy。

本项目统一 convention：

~~~text
M0=0 -> DC only -> CF
M0=1 -> {-1,0,+1}
M0=2 -> {-2,...,+2}
...
~~~

M0 越大，算法越宽松。

## 32.4 M0 的代价与收益

TheGB 上：

~~~text
M0=0 median ≈ 0.178
M0=1 median ≈ 0.565
M0=2 median ≈ 0.748
~~~

说明大量 aperture energy 分布在 DC 邻近低频 bins。

point target 上，M0 增大几乎不改变目标峰值，却快速恢复 CF 原本压掉的 lateral profile。

所以：

> **GCF 不是“更强的 CF”，而是主动放宽 CF 的 coherence criterion。**

## 32.5 phantom 与 in-vivo 差异

TheGB phantom：

~~~text
CF median ≈ 0.178
GCF(M0=1) median ≈ 0.565
~~~

真实 carotid：

~~~text
CF median ≈ 0.034–0.037
GCF(M0=1) median ≈ 0.131–0.138
~~~

说明相同 coherence weighting 在人体数据上明显更加 aggressive。

这也提醒：

> **算法在 point-target phantom 上表现漂亮，并不代表在真实组织上会同样合理。**

必须关注 speckle preservation、结构连续性、depth dependence 和 acquisition conditions。

## 32.6 本章最终应该记住的五句话

1. **CF / GCF 都建立在正确 delay-aligned aperture data 之上，不重新定义 Tx/Rx propagation。**
2. **CF 本质上衡量 exact coherent sum，也可理解为 aperture spectrum 的 DC energy fraction。**
3. **GCF 把 coherence 从 DC 推广到一段 low spatial-frequency band；M0 控制这个带宽。**
4. **更强 suppression 不自动代表更好的成像；CF 可能同时强烈重塑正常 diffuse speckle。**
5. **phantom、point target 与真实人体的 coherence statistics 可以显著不同，因此参数和结论必须结合数据类型与任务解释。**

---

## 33. 下一章

下一章进入：

> **MV / MVDR / Capon adaptive beamforming**

CF/GCF 仍然是：

~~~text
先做 DAS
再根据 coherence 乘一个 pixel-wise weight
~~~

MVDR 开始真正改变 aperture combination：

~~~text
aligned aperture data
        ↓
estimate covariance
        ↓
solve adaptive channel weights
        ↓
weighted coherent combination
~~~

也就是说，下一章从“判断通道是否一致”进一步进入：

> **根据数据本身，自适应决定每个阵元应该给多大权重。**