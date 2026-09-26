# 经典超声波束合成：导论与完整学习计划

**文档版本：v1.0**  
**建立日期：2026-09-26**  
**用途：作为后续“经典超声波束合成算法串讲”的固定总纲与课程锚点，防止长上下文中学习主线、算法边界和讲解标准发生漂移。**

---

# 0. 本文档要解决什么问题

本课程不是为了罗列尽可能多的 beamforming 算法，也不是为了追逐“某某改进型 DAS / DMAS / MV”的论文变体。

目标是重新建立一套能够长期使用的波束合成知识框架，使学习者在看到任何一个新的 beamformer 时，都能回答：

1. 它以什么数据为输入？
2. 它是否改变了传播时延模型？
3. 它改变的是阵元权重、阵元间组合方式、像素权重，还是成像量本身？
4. 它额外利用了什么信息：幅度、相位、空间相干性、协方差、频谱，还是波束零点？
5. 它试图解决 DAS 的哪个缺陷？
6. 它为此付出了什么代价？
7. 它在什么条件下可能真正优于 DAS？
8. 它失败时通常是因为物理模型错了、统计估计不可靠，还是算法本身的 trade-off？
9. 它与其他 beamformer 是真正的继承关系，还是只是面对同一个问题的平行分支？

最终希望形成的不是“记住六七套公式”，而是能够用统一视角理解整个经典 beamforming 家族。

---

# 1. 导论：为什么几乎所有经典 beamformer 都可以从 DAS 讲起

## 1.1 波束合成最核心的问题

设阵列有 \(M\) 个接收阵元。

对于空间中的候选成像点

\[
\mathbf r=(x,z)
\]

第 \(m\) 个阵元记录的 RF 信号为

\[
x_m(t).
\]

根据发射路径和接收路径的几何传播距离，可以计算假设散射体位于 \(\mathbf r\) 时，该阵元应该对应的传播时间

\[
\tau_m(\mathbf r).
\]

于是，从第 \(m\) 个通道取出相应的延时样本：

\[
s_m(\mathbf r)=x_m\left(\tau_m(\mathbf r)\right).
\]

如果使用的是 IQ 数据，则 \(s_m\) 通常是复数；其相位不能在没有明确理由时被丢弃。

把所有通道写成向量：

\[
\mathbf s(\mathbf r)
=
\begin{bmatrix}
s_1(\mathbf r) \\
s_2(\mathbf r) \\
\vdots \\
s_M(\mathbf r)
\end{bmatrix}.
\]

从这一刻开始，绝大多数经典 beamforming 方法都可以抽象成：

\[
\mathbf s(\mathbf r)
\longrightarrow
y(\mathbf r).
\]

换句话说：

> **传播模型负责把不同阵元“对齐到同一个假设像素”，beamformer 决定这些已经对齐的数据应该怎样组合。**

这就是整套课程的统一入口。

---

# 2. DAS：共同基线，而不是“低级算法”

最基本的 Delay-and-Sum（DAS）可以写成

\[
y_{\mathrm{DAS}}(\mathbf r)
=
\sum_{m=1}^{M}
w_m(\mathbf r)s_m(\mathbf r).
\]

其中：

- \(\tau_m(\mathbf r)\)：聚焦延时；
- \(w_m(\mathbf r)\)：apodization / aperture 权重；
- \(s_m(\mathbf r)\)：延时后的通道数据。

最简单情况下：

\[
w_m=\frac{1}{M},
\]

本质就是：

> **Delay → Weight → Sum**

DAS 隐含的核心物理判断是：

> 如果一个散射体真的位于当前假设像素，那么经过正确传播时延补偿以后，各阵元上由它产生的回波应该趋于同相，因此可以进行 coherent summation。

这条原则并没有被后来的很多算法推翻。

恰恰相反，CF、DMAS、SLSC 等方法往往比 DAS 更强烈地利用了“正确聚焦后通道之间应该具有一致性”这个事实。

因此不能把后续算法简单理解为：

> DAS 错了，所以后来出现了更高级的算法。

更准确的理解是：

> **DAS 给出了正确但非常朴素的阵列信息利用方式。后续算法不断追问：除了直接求和，我们还能不能从同一组阵元数据中识别哪些成分是真正聚焦的，哪些是离轴散射、旁瓣、噪声、杂波或相位误差？**

---

# 3. 后续算法到底在“改 DAS 的哪里”

这是整套课程最重要的分类框架。

## 3.1 固定线性组合：DAS / conventional beamforming

\[
y=\mathbf w^H\mathbf s
\]

其中 \(\mathbf w\) 是预先设计好的。

典型内容：

- Uniform weighting
- Rectangular aperture
- Hann / Hanning
- Hamming
- Tukey 等 apodization
- Dynamic aperture
- F-number

这一支首先揭示一个最基本的 trade-off：

> **窄主瓣与低旁瓣通常不能同时免费获得。**

apodization 降低旁瓣，通常以牺牲主瓣宽度、即横向分辨率为代价。

这是后面理解 MV、NSI 等算法的必要基础。

---

## 3.2 相干性加权：CF / GCF 家族

DAS 只看“求和之后有多大”。

Coherence Factor（CF）进一步问：

> **这个大值，到底是很多阵元真正同相叠加得到的，还是由少数大幅值通道、噪声、离轴散射偶然造成的？**

典型 CF 形式：

\[
CF(\mathbf r)
=
\frac{
\left|\sum_{m=1}^{M}s_m(\mathbf r)\right|^2
}{
M\sum_{m=1}^{M}|s_m(\mathbf r)|^2
}.
\]

然后：

\[
y_{\mathrm{CF}}
=
CF\cdot y_{\mathrm{DAS}}.
\]

因此可以把 CF 暂时理解为：

> **DAS 输出 × 当前像素的“通道一致性可信度”。**

这是一条重要路线：

\[
DAS
\rightarrow
coherence estimation
\rightarrow
pixel weighting.
\]

后续 GCF、PCF、SCF 等大量方法都可以放入这一家族，而不是全部作为独立“基座算法”学习。

---

## 3.3 自适应空间滤波：Capon / MV / MVDR

传统 DAS 的权重是预先设定的。

MV 的问题变成：

> **为什么不根据当前接收到的数据，自己决定什么样的阵元权重最合适？**

经典形式为

\[
y_{\mathrm{MV}}
=
\mathbf w_{\mathrm{MV}}^H\mathbf s,
\]

权重通过约束优化得到：

\[
\min_{\mathbf w}
\quad
\mathbf w^H\mathbf R\mathbf w
\]

subject to

\[
\mathbf w^H\mathbf a=1.
\]

解为：

\[
\mathbf w_{\mathrm{MV}}
=
\frac{
\mathbf R^{-1}\mathbf a
}{
\mathbf a^H\mathbf R^{-1}\mathbf a
}.
\]

其中：

- \(\mathbf R\)：阵列数据 covariance matrix；
- \(\mathbf a\)：期望方向的 steering vector。

其核心思想可以概括成：

> **保持目标方向无失真，同时最小化其余输出功率。**

这里第一次引入了一个非常重要的新信息：

\[
\boxed{\text{阵元之间的二阶统计关系}}
\]

因此：

- DAS：fixed weighting；
- MV：data-adaptive weighting。

MV 的理论祖先来自阵列信号处理中的 Capon / minimum variance 思想；后来被系统引入医学超声成像。

---

## 3.4 非线性通道组合：DMAS

DAS 计算的是：

\[
s_1+s_2+\cdots+s_M.
\]

DMAS 则显式构造通道对：

\[
s_is_j.
\]

基本结构为：

\[
y_{\mathrm{DMAS}}
=
\sum_{i=1}^{M-1}
\sum_{j=i+1}^{M}
g(s_i,s_j),
\]

其中实际实现通常需要考虑乘积的符号、动态范围和开方等处理。

核心问题变成：

> **如果两个阵元在正确延时之后确实观察到同一个散射源，那么二者之间是否应该表现出更强的一致性？**

因此 DMAS 虽然表面上看起来是“乘法 beamformer”，但它和 coherence 思想具有深层联系。

与 CF 的区别是：

- CF：先做某种全孔径一致性估计，再对 DAS 像素加权；
- DMAS：直接改变阵元之间的组合运算。

因此 DMAS 属于：

\[
\boxed{\text{nonlinear inter-channel interaction}}
\]

而不是普通 apodization 的一种。

---

# 4. SLSC：从“幅值成像”走向“相干性成像”

Short-Lag Spatial Coherence（SLSC）进一步走了一步。

传统 B-mode 最终关心：

\[
\text{echo amplitude}.
\]

SLSC 则直接计算不同阵元间、不同空间 lag 下的 normalized spatial coherence，并对短 lag 区域积分。

其核心思想可以概括为：

> **既然真正的组织回波和杂波/噪声具有不同的空间相干结构，那么为什么一定要把“幅度”作为最终图像对比量？可以直接把“空间相干性”变成图像。**

这是一种概念上的重要转折：

\[
\text{coherence as a weight}
\]

变成：

\[
\text{coherence as the image quantity itself}.
\]

因此学习 SLSC 的价值不只在于会实现一个算法，而在于真正理解：

- spatial coherence 是什么；
- aperture lag 是什么；
- Van Cittert–Zernike 类思想为什么会进入超声阵列成像；
- speckle、clutter、phase aberration 与空间相干性的关系。

---

# 5. NSI：不再只盯着主瓣，而是利用 beam null

传统 beamforming 通常追求：

- 主瓣越窄越好；
- 旁瓣越低越好。

但常规 apodization 存在经典 trade-off：

\[
\text{lower sidelobe}
\Longleftrightarrow
\text{broader main lobe}.
\]

Null Subtraction Imaging（NSI）换了一个思路：

> **阵列 beam pattern 中的 null 往往比 main lobe 更窄，能否利用 null 的空间结构来形成图像？**

NSI 使用多组特殊 receive apodization：

1. 一组 zero-mean apodization，使 broadside / 当前聚焦方向产生 null；
2. 在其基础上加入小的 DC offset；
3. 构造另一组镜像/互补的 apodization；
4. 分别形成图像；
5. 对若干 envelope / magnitude 结果进行非相干组合或减法。

因此 NSI 不是：

- 简单调整 DAS 权重；
- 普通 coherence weighting；
- covariance adaptive beamforming。

它实际上重新利用了阵列 beam pattern 的结构。

可以归入：

\[
\boxed{\text{multiple spatial responses + nonlinear image combination}}
\]

这一独立路线。

---

# 6. 一张图看懂本课程的算法家族

```text
                         ┌────────────────────────┐
                         │ Array / Channel Data   │
                         └───────────┬────────────┘
                                     │
                        geometric delay / focusing
                                     │
                                     ▼
                          aligned aperture vector
                               s(r) ∈ C^M
                                     │
       ┌─────────────────────────────┼──────────────────────────────┐
       │                             │                              │
       ▼                             ▼                              ▼
 Fixed linear                    Coherence                     Adaptive
 weighting                       reasoning                     weighting
       │                             │                              │
       ▼                             │                              ▼
     DAS                             │                         Capon / MV
       │                             │                           / MVDR
       │                ┌────────────┼────────────┐
       │                │            │            │
       │                ▼            ▼            ▼
       │               CF          DMAS          SLSC
       │          pixel weight   nonlinear    coherence itself
       │                          pairwise      becomes image
       │
       └──────────── aperture / beam-pattern reasoning ──────────────┐
                                                                     │
                                                                     ▼
                                                                    NSI
                                                               beam-null route
```

注意：

> **这不是严格的时间谱系。**

真正的历史结构是：

- DAS / conventional beamforming 是共同基础；
- Capon/MV 来自更早的阵列信号处理与高分辨谱估计；
- coherence-based imaging 是另一条长期发展的理论路线；
- DMAS 最初并不是因为 CF 或 MV “失败”才出现；
- NSI 又从 beam pattern / apodization 的角度开辟了另一种处理方式。

因此不能简单写成：

```text
DAS → CF → MV → DMAS → SLSC → NSI
```

更准确的是：

```text
                           DAS / Conventional Array Imaging
                                      │
                ┌─────────────────────┼─────────────────────┐
                │                     │                     │
       Fixed aperture           Coherence route      Adaptive array route
                │                     │                     │
        Apodization            CF / GCF / SLSC          Capon / MV
                │
                ├──────── nonlinear inter-channel route ───── DMAS
                │
                └──────── beam-pattern/null route ─────────── NSI
```

---

# 7. 本课程如何定义“基座算法”

只有满足以下条件中的大部分，才作为独立主章节：

1. 提出了不同的信息利用机制；
2. 改变了 beamforming 的数学结构，而不只是调参数；
3. 代表一类可以继续派生出很多变体的方法；
4. 在经典超声 beamforming 文献中具有长期影响；
5. 能帮助理解大量后续论文；
6. 与其他基座算法之间存在清楚的概念边界。

因此核心算法暂定为：

1. **DAS**
2. **CF / coherence weighting**
3. **MV / MVDR / Capon**
4. **DMAS**
5. **SLSC**
6. **NSI**

同时必须配套学习：

- aperture；
- apodization；
- dynamic receive focusing；
- dynamic aperture / F-number；
- PSF；
- spatial coherence。

它们虽然不一定每个都应该被称为独立“beamformer”，但构成上述算法的共同语言。

---

# 8. 暂不作为独立主线的算法

以下方法并不是“不重要”，而是当前阶段优先放回其母体方法之后学习：

### CF 家族

- GCF
- PCF
- SCF
- DCF
- 各种 generalized / phase / sign coherence weighting

先掌握：

\[
\boxed{CF}
\]

再理解其余方法究竟修改了哪种 coherence estimator。

### MV 家族

- EIBMV
- ESBMV
- spatial smoothing variants
- forward-backward averaging variants
- diagonal-loading variants
- MV-CF 等组合方法

先掌握：

\[
\boxed{MVDR\ optimization + covariance estimation}
\]

否则容易只会套公式。

### DMAS 家族

- FDMAS
- DS-DMAS
- MV-DMAS
- CF-DMAS
- 各类 filtered / modified DMAS

先理解 pairwise multiplication 本身。

### NSI 家族

- modified NSI
- generalized NSI
- NSI + coherence weighting
- NSI 的各种 DC offset / apodization 变体

先掌握原始 NSI 的 beam-null 思想。

---

# 9. 一个非常重要的边界：不要把“采集方式”和“beamformer 核心”混成一类

后续学习中必须区分：

## Acquisition / transmit strategy

例如：

- focused transmit；
- line-by-line scanning；
- plane-wave imaging；
- multi-angle plane-wave compounding；
- synthetic aperture；
- diverging wave；
- STA / STA imaging。

## Beamforming / reconstruction rule

例如：

- DAS；
- MV；
- CF weighting；
- DMAS；
- SLSC；
- NSI。

例如：

**Plane-Wave Imaging (PWI)** 本身不是与 DAS 平级的一种“通道组合数学规则”。

完全可以：

\[
\text{Plane Wave acquisition}
+
\text{DAS}
\]

也可以：

\[
\text{Plane Wave acquisition}
+
\text{MV}
\]

还可以进一步：

\[
\text{multi-angle acquisition}
+
\text{coherent compounding}.
\]

所以后续必须一直区分：

\[
\boxed{\text{Acquisition}}
\neq
\boxed{\text{Delay model}}
\neq
\boxed{\text{Beamformer}}
\neq
\boxed{\text{Compounding}}
\neq
\boxed{\text{Display/post-processing}}
\]

这是防止概念混乱的重要原则。

---

# 10. 完整学习计划

---

## 第 0 章：建立共同语言——阵列、RF、IQ、相位与 PSF

### 目标

在进入任何高级 beamformer 之前，把所有算法共享的物理基础统一起来。

### 必须讲清楚

- transducer element；
- pitch；
- aperture；
- wavelength；
- center frequency；
- bandwidth；
- RF channel data；
- IQ data；
- analytic signal；
- complex phase；
- transmit path；
- receive path；
- two-way propagation；
- sound speed；
- focal point；
- steering；
- dynamic receive focusing；
- interpolation；
- apodization；
- dynamic aperture；
- F-number；
- PSF；
- axial resolution；
- lateral resolution；
- main lobe；
- side lobe；
- grating lobe。

### 最重要的问题

为什么：

\[
\text{delay}
\]

能够变成：

\[
\text{spatial focusing}?
\]

### 完成标准

能够从一个点散射体开始解释：

```text
point target
→ different arrival times on elements
→ delay compensation
→ phase alignment
→ coherent summation
→ spatial PSF
```

---

## 第 1 章：DAS——把“延时求和”真正学透

### 核心内容

1. transmit delay；
2. receive delay；
3. focused transmit 下的 total delay；
4. plane-wave transmit 下的 total delay；
5. sample index ↔ time ↔ depth；
6. interpolation；
7. receive aperture；
8. dynamic aperture；
9. apodization；
10. coherent summation；
11. RF DAS；
12. complex IQ DAS；
13. envelope detection；
14. log compression。

### 必须理解的公式

\[
\tau_m(\mathbf r)
=
\tau_{\mathrm{TX}}(\mathbf r)
+
\tau_{\mathrm{RX},m}(\mathbf r).
\]

以及

\[
y_{\mathrm{DAS}}(\mathbf r)
=
\sum_m
w_m(\mathbf r)
x_m\left(\tau_m(\mathbf r)\right).
\]

### 必须形成的直觉

DAS 的核心不是“加”。

而是：

\[
\boxed{\text{利用传播模型把空间位置转换成通道相位一致性}}
\]

再进行 coherent integration。

### 完成标准

能够独立回答：

> 为什么完全相同的 Sum，如果 Delay 错了，就不能形成正确图像？

---

# 11. 第 2 章：DAS 为什么会失败

这一章是全课程最重要的过渡章节。

我们不先讲新算法，而是人为破坏 DAS 的理想条件。

## 场景 A：理想单点散射体

观察：

- main lobe；
- side lobe；
- PSF；
- aperture 对 lateral resolution 的影响。

## 场景 B：两个很近的点

观察：

- Rayleigh-like spatial separability；
- main-lobe width；
- 两目标什么时候无法分辨。

## 场景 C：强离轴散射体

观察：

- sidelobe contamination；
- off-axis clutter。

## 场景 D：弱目标旁边有强目标

观察：

- dynamic range；
- contrast masking。

## 场景 E：加入 additive noise

观察：

- coherent integration；
- SNR。

## 场景 F：声速模型错误

例如真实：

\[
c_{\mathrm{true}}
\neq
c_{\mathrm{beamformer}}.
\]

观察：

- phase error；
- focusing error；
- coherence degradation。

## 场景 G：phase aberration

观察：

- 阵元间不再完美同相；
- DAS 为什么开始失焦。

### 这一章结束以后引出四个问题

### 问题 1

> 能不能判断“这些阵元到底是不是真的相干”？

→ **CF**

### 问题 2

> 能不能根据当前数据自动选择最佳权重，而不是提前规定窗函数？

→ **MV**

### 问题 3

> 能不能显式利用通道之间的 pairwise consistency？

→ **DMAS**

### 问题 4

> 能不能直接把 spatial coherence 当作图像？

→ **SLSC**

### 问题 5

> 能不能绕开主瓣宽度的传统思路，直接利用更窄的 beam null？

→ **NSI**

从这里开始，后续算法就不是凭空出现的。

---

# 12. 第 3 章：CF——给 DAS 一个“可信度评分”

## 核心问题

\[
\text{high amplitude}
\]

是否一定意味着：

\[
\text{correctly focused target}?
\]

答案是不一定。

### 学习内容

1. coherent energy；
2. incoherent energy；
3. CF 定义；
4. CF 数值范围；
5. 理想同相信号；
6. 随机相位信号；
7. 强离轴信号；
8. noise；
9. phase aberration；
10. CF-weighted DAS。

### 数学目标

真正理解：

\[
CF
=
\frac{
|\sum_m s_m|^2
}{
M\sum_m |s_m|^2
}
\]

的分子和分母分别意味着什么。

### 延伸

在掌握 CF 后再讲：

- GCF；
- phase coherence；
- sign coherence。

这些作为“CF 如何重新定义相干性”的案例，而不是新的主课程。

---

# 13. 第 4 章：MV / MVDR / Capon——从固定窗到数据自适应空间滤波器

这一章数学强度最高，应慢讲。

## Part A：为什么 fixed apodization 有极限

理解：

\[
\mathbf w_{\mathrm{fixed}}
\]

为什么不知道当前数据中的干扰在哪里。

## Part B：从 constrained optimization 推导 MV

\[
\min_{\mathbf w}
\mathbf w^H\mathbf R\mathbf w
\]

subject to

\[
\mathbf w^H\mathbf a=1.
\]

然后推导：

\[
\mathbf w_{\mathrm{MV}}
=
\frac{
\mathbf R^{-1}\mathbf a
}{
\mathbf a^H\mathbf R^{-1}\mathbf a
}.
\]

## Part C：理解 covariance matrix

重点不是矩阵运算本身，而是理解：

\[
R_{ij}
\]

表示什么。

## Part D：为什么超声 MV 实际实现没这么简单

必须讲：

- finite snapshot；
- subarray；
- spatial smoothing；
- diagonal loading；
- covariance estimation；
- numerical stability；
- matrix inversion；
- computational complexity。

## Part E：MV 在超声中的真正优缺点

不能简单记成：

> MV 比 DAS 分辨率高。

需要讨论：

- robustness；
- speckle statistics；
- sound-speed mismatch；
- covariance estimation；
- computation；
- real-time implementation。

---

# 14. 第 5 章：DMAS——把“相干”写进乘法里

## 核心内容

从 DAS：

\[
\sum_i s_i
\]

走向：

\[
\sum_{i<j}s_is_j.
\]

## 必须理解

为什么：

- same-phase signals 的乘积会被强化；
- incoherent signals 不容易稳定累积。

## 特别重要

DMAS 的乘法会改变频谱。

若窄带 RF 近似：

\[
s_i(t)\sim \cos(\omega_0t+\phi_i),
\]

则：

\[
s_i(t)s_j(t)
\]

会产生：

\[
\cos(\phi_i-\phi_j)
\]

以及接近：

\[
2\omega_0
\]

的分量。

因此 DMAS 不能只当作一个抽象代数技巧。

必须结合：

- RF；
- bandwidth；
- filtering；
- nonlinear frequency generation；
- envelope。

### 完成标准

能够解释：

> DMAS 为什么和 coherence 有关，但又不能简单说“DMAS = CF”。

---

# 15. 第 6 章：SLSC——空间相干性本身成为成像量

## 核心学习内容

1. spatial covariance；
2. spatial coherence；
3. lag；
4. normalized correlation；
5. short-lag；
6. coherence curve；
7. coherence integration；
8. SLSC image。

## 必须理解

为什么短 lag 往往包含最有价值的 coherent tissue information。

## 与 CF 的统一关系

CF：

\[
\text{coherence}
\rightarrow
\text{weight}
\rightarrow
\text{amplitude image}
\]

SLSC：

\[
\text{coherence}
\rightarrow
\text{image directly}.
\]

### 重点讨论

- clutter；
- reverberation；
- phase aberration；
- speckle；
- point target；
- SNR；
- contrast；
- CNR。

---

# 16. 第 7 章：NSI——从主瓣思维转向 null 思维

## Part A：重新复习 aperture → beam pattern

理解：

\[
\text{aperture weighting}
\leftrightarrow
\text{spatial response}.
\]

## Part B：zero-mean apodization

为什么：

\[
\sum_m w_m=0
\]

可以让 broadside / focal direction 出现 null。

## Part C：DC offset

研究：

\[
w_m^{(+)}
=
w_m^{(0)}+\epsilon
\]

等构造如何改变 null 附近的 beam pattern。

## Part D：多图组合

理解 NSI 为什么通常需要：

- 多组 receive apodization；
- 多次 DAS；
- envelope / magnitude；
- nonlinear subtraction / combination。

## Part E：正确理解“super-resolution”

必须明确区分：

- apparent PSF narrowing；
- classical diffraction-limited DAS；
- robustness；
- noise sensitivity；
- element mismatch；
- calibration error；
- speckle appearance。

不能只看到非常窄的 PSF 就简单宣布“突破衍射极限”。

---

# 17. 第 8 章：统一比较——不再按算法，而是按问题思考

这一章重新打乱算法顺序。

## 问题一：我想改善 lateral resolution

比较：

- larger aperture；
- higher frequency；
- MV；
- DMAS；
- NSI。

问：

> 它们得到“窄响应”的机制相同吗？

答案通常不同。

## 问题二：我要降低 sidelobe

比较：

- apodization；
- MV；
- coherence weighting；
- DMAS；
- NSI。

## 问题三：低 SNR

分析：

- DAS coherent gain；
- CF 的可靠性；
- covariance estimation 的稳定性；
- DMAS 的非线性噪声行为；
- SLSC 的适用性。

## 问题四：sound-speed mismatch / phase aberration

比较谁依赖：

\[
\text{precise phase alignment}.
\]

实际上几乎所有高性能 beamforming 方法都不能完全绕开正确传播模型，只是对误差的响应不同。

## 问题五：我要保留自然 speckle

讨论：

- DAS；
- CF；
- MV；
- DMAS；
- SLSC；
- NSI

对 speckle statistics 和 image texture 的改变。

## 问题六：实时系统

比较：

- operation count；
- memory；
- matrix inverse；
- pairwise multiplication；
- multiple beamforming passes；
- GPU / FPGA suitability。

---

# 18. 第 9 章：统一 MATLAB / Python 实验

为了避免“每篇论文用自己的数据证明自己”，所有主要算法最终放到同一套实验中。

用户更熟悉 MATLAB，因此第一轮验证可以优先 MATLAB，随后再建立 Python 对照。

## 统一数据结构

### 单次发射 RF

推荐概念结构：

\[
[\text{channel},\text{sample}]
\]

即：

```text
RF[channel, sample]
```

### 多次发射

例如 plane-wave angles：

\[
[\text{tx},\text{channel},\text{sample}].
\]

### IQ

保持 complex dtype：

```text
IQ : complex
```

不能为了方便提前取：

```text
abs(IQ)
```

否则会直接丢失后续 coherent beamforming 所需要的相位。

## 统一仿真场景

### Test 1

单个 point target。

### Test 2

两个横向接近的 point targets。

### Test 3

弱目标 + 邻近强目标。

### Test 4

anechoic cyst / low-scatter region。

### Test 5

speckle phantom。

### Test 6

additive noise。

### Test 7

sound-speed mismatch。

### Test 8

phase aberration。

---

# 19. 统一评价指标

所有算法尽量使用相同输入和评价标准。

## Resolution

- lateral FWHM；
- axial FWHM。

## Sidelobe

- peak sidelobe level；
- integrated sidelobe energy（需要时）。

## Contrast

- contrast ratio；
- CNR；
- gCNR。

## Robustness

- SNR sweep；
- sound-speed error sweep；
- phase error sweep。

## Computation

- execution time；
- approximate operation complexity；
- memory。

## Image appearance

- speckle texture；
- target conspicuity；
- artifact behavior。

注意：

> PSF、contrast、CNR、gCNR、speckle 评价回答的是不同问题，不能用一个指标代表全部成像质量。

另外，所有 image-domain 指标都必须注明：

- 是否 envelope 后；
- 是否 log compression；
- display dynamic range；
- normalization 方法。

否则不同算法之间的图像比较容易失真。

---

# 20. 每个算法固定使用同一种讲解模板

后续每一章都严格按照下面的顺序讲。

## A. 历史问题

当时的人想解决什么？

## B. 前一方法的瓶颈

为什么已有方法不够？

## C. 一句话核心思想

不用公式能不能解释清楚？

## D. 输入数据

- RF or IQ？
- channel domain？
- beamformed data？
- complex or real？

## E. 最小数学模型

只引入理解算法必须的公式。

## F. 逐步推导

解释每一项的来源和物理意义。

## G. 单点散射体直觉

假设只有一个 point target，算法发生什么？

## H. 离轴散射体 / 噪声直觉

为什么它可能比 DAS 好？

## I. PSF / beam pattern

算法如何改变空间响应？

## J. 真正优势

不只重复论文 abstract。

## K. 失败模式

重点讨论什么时候会失效。

## L. 计算代价

实时性意味着什么？

## M. 与其他基座方法的关系

它改变 DAS 的哪一层？

## N. 最小 MATLAB 实现

用最短但物理正确的程序复现核心思想。

## O. 原始论文

回到原始工作核对作者究竟提出了什么。

## P. 本章一句话结论

必须能够压缩成一句真正有信息量的话。

---

# 21. 历史学习原则

这套课程会同时记录两条时间线：

## 时间线 A：数学 / 阵列信号处理思想首次提出

例如 MV 的祖先来自 Capon 的高分辨率阵列频率-波数估计思想。

## 时间线 B：进入医学超声

同一种思想往往多年以后才被真正用于 medical ultrasound channel data。

不能把二者混在一起说：

> “某算法在某年由超声研究者发明”。

更准确的表述应是：

> “某阵列处理思想在某领域提出，之后在某时期被引入医学超声。”

---

# 22. 已核对的几个历史锚点

这些不是完整历史，只作为后续课程建立时间坐标的“锚点”。

## 1969 — Capon

J. Capon：

**High-resolution frequency-wavenumber spectrum analysis**

Proceedings of the IEEE, 57(8), 1408–1418.

DOI:

`10.1109/PROC.1969.7278`

这项工作是后来 Capon / MVDR 高分辨阵列处理的重要理论源头。

---

## 2003 — GCF

Pai-Chi Li, Meng-Lin Li：

**Adaptive imaging using the generalized coherence factor**

IEEE Transactions on Ultrasonics, Ferroelectrics, and Frequency Control, 50(2), 128–141.

DOI:

`10.1109/TUFFC.2003.1182117`

这里明确把 generalized coherence factor 用于减轻声速不均匀引起的聚焦误差。

注意：

> 这不是说“CF 在 2003 年首次发明”。

CF 的更早来源和术语演进将在 CF 专章中单独核对，避免在总纲里过早给出未经充分考证的单一“发明者”。

---

## 2007 — MV 进入经典医学超声文献

Johan-Fredrik Synnevåg, Andreas Austeng, Sverre Holm：

**Adaptive Beamforming Applied to Medical Ultrasound Imaging**

IEEE Transactions on Ultrasonics, Ferroelectrics, and Frequency Control, 54(8), 1606–1613.

该工作是医学超声领域经典的 MV adaptive beamforming 文献之一。

---

## 2011 — SLSC

Muyinatu A. Lediju, Gregg E. Trahey, Brett C. Byram, Jeremy J. Dahl：

**Short-Lag Spatial Coherence of Backscattered Echoes: Imaging Characteristics**

IEEE Transactions on Ultrasonics, Ferroelectrics, and Frequency Control, 58(7), 1377–1388.

DOI:

`10.1109/TUFFC.2011.1957`

这里系统展示了利用 short-lag spatial coherence 直接形成图像的思路。

---

## 2014/2015 — 医学超声 DMAS

Giulia Matrone, Alessandro Stuart Savoia, Giosuè Caliano, Giovanni Magenes：

**The Delay Multiply and Sum Beamforming Algorithm in Ultrasound B-Mode Medical Imaging**

IEEE Transactions on Medical Imaging, 34(4), 940–949.

在线发表：2014  
期刊卷期：2015

DOI:

`10.1109/TMI.2014.2371235`

作者明确说明 DMAS 原本来自用于乳腺癌检测的 microwave radar 思路，随后经过修改应用于医学超声 B-mode。

---

## 2015 — NSI

Jonathan Reeg, Michael L. Oelze：

**Improving Lateral Resolution in Ultrasonic Imaging by Utilizing Nulls in the Beam Pattern**

2015 IEEE International Ultrasonics Symposium.

DOI:

`10.1109/ULTSYM.2015.0198`

这项工作提出利用 receive beam pattern 中的 null 进行 Null Subtraction Imaging。

---

# 23. 需要贯穿全课程的五个统一问题

以后遇到任何算法，优先问下面五个问题。

## Q1. Delay 有没有改变？

如果没有：

> 它通常仍然继承 DAS 的传播模型。

因此，如果声速模型严重错误，很多所谓“高级 beamformer”仍然可能建立在错误的聚焦基础上。

## Q2. 它到底改了哪一层？

### DAS

\[
\boxed{\text{fixed channel weighting}}
\]

### CF

\[
\boxed{\text{pixel confidence weighting}}
\]

### MV

\[
\boxed{\text{data-adaptive channel weighting}}
\]

### DMAS

\[
\boxed{\text{nonlinear inter-channel interaction}}
\]

### SLSC

\[
\boxed{\text{coherence becomes image contrast}}
\]

### NSI

\[
\boxed{\text{multiple beam patterns + nonlinear combination}}
\]

## Q3. 它额外利用了什么信息？

| 方法 | 主要额外信息 |
|---|---|
| DAS | 对齐后的幅度与相位 |
| CF | 全孔径一致性 |
| MV | covariance / second-order statistics |
| DMAS | pairwise channel interaction |
| SLSC | spatial coherence vs lag |
| NSI | beam-pattern null structure |

## Q4. 它主要想解决什么？

不要只说：

> “提高图像质量”。

必须具体到：

- main-lobe width；
- sidelobe；
- clutter；
- contrast；
- phase aberration；
- noise；
- speckle；
- target detectability；
- computational cost。

## Q5. 它用什么代价换来的？

任何高性能方法都应该继续问：

\[
\text{Gain}
\quad \text{vs} \quad
\text{Cost / Assumption / Failure Mode}.
\]

例如：

- MV：分辨率提升 ↔ covariance estimation + stability + computation；
- CF：杂波抑制 ↔ 可能压制低相干真实回波；
- DMAS：非线性增强 ↔ 频谱变化 + 计算量 + speckle 改变；
- SLSC：clutter robustness ↔ 图像物理含义发生变化；
- NSI：非常窄的空间响应 ↔ calibration / noise / combination sensitivity。

---

# 24. 本课程中始终保持的科学实现原则

后续只要进入代码，就必须明确：

## 数据 shape

例如：

```text
RF[tx, channel, sample]
```

或：

```text
IQ[frame, tx, channel, sample]
```

不能仅凭变量名猜 axis。

## dtype

尤其区分：

```text
real RF
```

和：

```text
complex IQ
```

## 单位

明确：

- Hz / MHz；
- s / us；
- m / mm；
- sample index。

## delay convention

明确：

\[
\tau_{\mathrm{TX}}
\]

和：

\[
\tau_{\mathrm{RX}}
\]

各自的定义。

## interpolation

不能简单用 nearest sample，却把结果描述成理想连续时间聚焦。

## coherent / incoherent

必须明确：

- complex/RF summation；
- magnitude summation；
- envelope summation

之间的区别。

## normalization

不同 beamformer 必须明确 amplitude scaling。

## dB

必须区分：

\[
20\log_{10}|x|
\]

与：

\[
10\log_{10}P.
\]

---

# 25. 后续课程的实验主线

为了让所有算法真正串起来，将始终复用一个最小实验：

```text
线阵
  ↓
一个 point target
  ↓
生成各 channel RF
  ↓
观察天然 time-of-flight curve
  ↓
DAS delay
  ↓
通道对齐
  ↓
DAS summation
  ↓
得到 PSF
```

然后逐步加入：

```text
off-axis target
noise
strong reflector
sound-speed mismatch
phase aberration
speckle
```

在完全相同的数据上依次比较：

```text
DAS
 ↓
CF
 ↓
MV
 ↓
DMAS
 ↓
SLSC
 ↓
NSI
```

这里的箭头表示**学习顺序**，而不是历史上的发明继承关系。

---

# 26. 推荐学习顺序

正式课程固定按以下顺序推进：

```text
0. 阵列与信号基础
      ↓
1. DAS
      ↓
2. DAS Failure Modes
      ↓
3. CF
      ↓
4. MV / MVDR / Capon
      ↓
5. DMAS
      ↓
6. SLSC
      ↓
7. NSI
      ↓
8. Unified Comparison
      ↓
9. Unified MATLAB/Python Lab
```

为什么不是严格按年代？

因为本课程首先服务于：

\[
\boxed{\text{理解}}
\]

而不是：

\[
\boxed{\text{历史编年}}
\]

历史关系会在每章中单独说明。

---

# 27. 第二阶段扩展内容

完成上述主干后，再决定是否进入以下内容：

## Acquisition / compounding

- Synthetic Aperture；
- STA；
- Plane-Wave Imaging；
- coherent plane-wave compounding；
- diverging-wave imaging。

## 其他 adaptive beamforming

- EIBMV；
- ESBMV；
- covariance estimation improvements。

## 其他 coherence beamforming

- GCF；
- PCF；
- SCF；
- coherence-to-variance 类方法。

## Frequency-domain beamforming

- Fourier / frequency-domain beamforming；
- delay interpolation 与 phase rotation 的关系。

## 非线性 DAS 家族

- p-DAS；
- signed p-DAS；
- FDMAS；
- DS-DMAS。

这些在主干完成前不抢占核心学习资源。

---

# 28. 暂时不纳入本主课程的内容

除非后续明确需要，否则先不展开：

- 深度学习 beamforming；
- neural beamformer；
- learned reconstruction；
- diffusion reconstruction；
- ULM；
- SVD clutter filtering；
- CEUS nonlinear pulse sequences；
- Doppler clutter filtering；
- photoacoustic-specific beamforming；
- 超声 CT reconstruction。

原因不是它们不重要，而是它们属于不同问题层级，会干扰当前对经典阵列 beamforming 基础的重新建立。

---

# 29. 防止后续讲解漂移的“课程冻结规则”

从 v1.0 开始，后续讲解遵守以下规则。

## 规则 1

始终以：

\[
\mathbf s(\mathbf r)\rightarrow y(\mathbf r)
\]

作为统一抽象。

## 规则 2

任何新算法必须首先说明：

> 它改变 DAS 的哪一层？

## 规则 3

不把论文小改进提升成与 DAS、MV、DMAS 同级的基座算法。

## 规则 4

不把 acquisition、beamforming、compounding、post-processing 混为一谈。

## 规则 5

每个算法必须同时讲：

- motivation；
- mathematics；
- physics；
- PSF；
- strengths；
- failure modes；
- computation；
- implementation。

## 规则 6

历史上严格区分：

- 数学思想首次提出；
- 首次用于医学超声；
- 后续代表性改进。

## 规则 7

论文作者没有证明的内容，不因为“看起来合理”就当作已验证事实。

## 规则 8

代码运行成功不等于科学实现正确。

## 规则 9

比较算法时尽可能使用同一数据、同一 aperture、同一 normalization、同一 display dynamic range 和同一评价指标。

## 规则 10

除非学习过程中发现当前基座分类本身存在明显错误，否则不随意改变主课程结构。

---

# 30. 最终希望建立的知识图景

完成课程后，看到任何 beamforming 算法，应该首先想到：

```text
                     Ultrasound channel data
                              │
                        propagation model
                              │
                             Delay
                              │
                 aligned aperture observations
                              │
          ┌───────────────────┼───────────────────┐
          │                   │                   │
     fixed weights       adaptive weights     coherence
          │                   │                   │
         DAS                  MV             CF / SLSC
          │
          ├──────── pairwise nonlinear interaction ─── DMAS
          │
          └──────── beam-pattern/null manipulation ─── NSI
```

然后继续追问：

```text
它利用什么？
它抑制什么？
它牺牲什么？
它依赖什么假设？
假设不成立时会怎样？
```

如果能够稳定回答这五个问题，就不再需要依赖死记算法名称。

---

# 31. 下一讲

按照本总纲，下一讲固定为：

# 第一讲：真正理解 DAS

副标题：

**从一个点散射子出发，串起传播时间、动态接收聚焦、孔径、apodization、PSF、主瓣、旁瓣和空间相干性。**

第一讲不会急于介绍高级算法。

首先建立一个统一实验：

```text
point scatterer
→ channel RF
→ time-of-flight
→ delay curve
→ aligned signals
→ coherent sum
→ lateral PSF
```

然后逐步回答：

1. Delay 到底在补偿什么？
2. 为什么 Delay 正确后能够聚焦？
3. 为什么 DAS 能产生主瓣和旁瓣？
4. aperture 为什么决定横向分辨率？
5. apodization 为什么降旁瓣却会展宽主瓣？
6. dynamic aperture / F-number 在做什么？
7. 如果声速错了，哪个环节最先坏？
8. 为什么后续 CF、MV、DMAS、SLSC、NSI 都可以从这个实验自然引出？

这将成为后续所有章节反复复用的物理基准。
