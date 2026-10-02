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

为了后续能和 USTB 直接验证，正式 GCF core 不再使用上一节纯教学参数 K，而使用 USTB OMHR 风格的 `M0`。

本项目当前定义：

~~~text
M0 <= 1
    -> 只使用 DC
    -> GCF 退化为普通 CF

M0 = 2
    -> 使用 {-2,-1,0,+1,+2}

M0 = 4
    -> 使用 {-4,...,0,...,+4}
~~~

需要特别注意：USTB 当前 legacy implementation 对 `M0=1` 仍然只保留 DC，而不是 `{-1,0,+1}`。所以教程里上一节的 `K=1` 和正式代码里的 `M0=1` **不是同一个约定**。

默认正式实验使用：

~~~text
M0 = 2
~~~

这样既已经是 generalized low-frequency band，又能和 USTB convention 清晰对应。

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
GCF(M0=1)
~~~

因为这时只保留 DC，根据 Parseval 关系它必须和 ordinary CF 完全等价。

所以 `compare_manual_das_cf_gcf.m` 会检查：

~~~text
max |CF - GCF(M0=1)|
~~~

应该接近浮点误差。

这个验证比“图看起来差不多”更重要，因为它直接检查了 CF 与 GCF 数学定义的连接。

### 22.4 运行

~~~matlab
cd matlab/02_CF_GCF

M0 = 2;
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