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
