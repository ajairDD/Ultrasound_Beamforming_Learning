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
