# 第 6 章：NSI（Null Subtraction Imaging）

**状态：教学与算法代码已提交；真实 TheGB UFF 成像结果尚未在 MATLAB 验证。**

本章结构：一节完整原理、一次密集二维 RTB-DAS/NSI 对照实验、一个总结。不做大量参数扫描或派生变体。

## 一、原理：制造中心零点，再留下窄主瓣

### 1. 出发点

传统 receive apodization 降低旁瓣时常伴随主瓣变宽。NSI 的思路不同：**设计一个中心为零的接收方向图（null），再从两个带 DC bias 的方向图里减去它**，从而得到窄的有效横向响应。Reeg 和 Oelze 在 2015 年提出 NSI，Agarwal 等人在 2019 年深入研究了宽度、旁瓣、speckle 和对比度的取舍。

### 2. 三套接收孔径

在同一 Tx/Rx delay、fractional interpolation 和 active Rx aperture 下得到复数接收向量：

$$
\mathbf s=[s_1,\ldots,s_M]^T.
$$

DAS：

$$
D=\sum_{i=1}^{M}s_i.
$$

对偶数 active aperture，零均值（ZM）权重：

$$
\mathbf w_{\rm ZM}
=[\underbrace{+1,\ldots,+1}_{M/2},
  \underbrace{-1,\ldots,-1}_{M/2}]^T.
$$

若理想 on-axis 目标在延时后所有通道同相、等幅，ZM 输出恰好为 0，形成中心 Null。

用常数 $c>0$ 构造：

$$
\mathbf w_{\rm DC1}=\mathbf w_{\rm ZM}+c\mathbf 1,\quad
\mathbf w_{\rm DC2}=-\mathbf w_{\rm ZM}+c\mathbf 1.
$$

相应复数 beamformed signals 为：

$$
Z=\mathbf w_{\rm ZM}^T\mathbf s,\quad
DC1=Z+cD,\quad DC2=-Z+cD.
$$

本项目使用 DC offset $c=0.2$，只作为教学默认值，**不是全数据最优值**。

**奇数 active M 的实现约定**：左右各取 floor(M/2) 个元素分别为 +1、-1，中央元素 ZM 权重为 0，仍然保证权重总和为零。这是为了适配 dynamic F-number 的工程约定，区别于文献中常展示的理想偶数孔径。

### 3. 先 envelope，后非相干相减

NSI 图像来自：

$$
\boxed{
E_{\rm NSI}=
\frac{|DC1|+|DC2|}{2}-|Z|.
}
$$

**不是**对原始 RF 直接相减，也不是对 log-compressed B-mode 做 unsharp masking。

核心直觉：ZM 在中心产生 null；DC1/DC2 在中心填入一条小桥。离开中心后，ZM 与 DC 两个 beam patterns 的相似部分通过 envelope subtraction 消去，留下比常规 DAS 更窄的有效主瓣。

对任意复数 $D,Z$，三角不等式保证：

$$
\boxed{0\le E_{\rm NSI}\le c|D|.}
$$

因此本项目用 $E_{\rm NSI}/c$ 与 DAS 在同一个 DAS 0-dB reference 上显示。理想 on-axis 且 $Z=0$ 时 $E_{\rm NSI}/c=|D|$。**除以 $c$ 是显示尺度约定，不是物理幅度校准。**

DC offset 越小通常主瓣越窄，但也容易产生不充分的 speckle、暗孔洞和对比损失。反之大 offset 更接近 DAS；无法只凭点目标越窄就判定更好。

### 4. 为什么选择 RTB，而不是 conventional FI？

我们在第 3 章 MVDR 看到了 conventional FI 横向采样间距约 0.298 mm，可能把很窄的响应显示成单条 scanline。NSI 常产生同样甚至更强的横向收窄，因此本章保留 Chapter 1 的 **RTB blended Tx delay、Tx Tukey25、Tx F#=2、Rx F#=1.7 和 coherent Tx compounding**，采用密集二维 ROI。

这只是对现有 focused-FI/RTB UFF 的 receive-NSI 教学应用，**不是说原始 NSI 论文也采用完全相同的 Tx sequence**。

### 5. 与之前算法的本质区别

| 算法 | 核心机制 |
|---|---|
| CF/GCF | DAS 后乘全孔径相干权重 |
| MVDR | covariance 估计 + adaptive receive linear weights |
| DMAS/fDMAS | 通道对非线性乘积 + 二倍频带通 |
| SLSC | 短阵元间距的轴向 RF normalized correlation |
| **NSI** | **三个接收孔径方向图的 envelope subtraction** |

---

## 二、唯一实验：RTB-DAS vs RTB + receive NSI

### 1. 条件

默认 TheGB 约 20.1 mm 点目标的 **密集二维 ROI**：

~~~text
x: -4 ~ +3 mm      n_x=281   dx=0.025 mm
z: 18 ~ 22.5 mm    n_z=181   dz=0.025 mm

same UFF / RTB blended Tx delay / Tx Tukey25 / Rx F#1.7
same interpolation / active Rx / coherent cross-Tx compounding
all focused Tx, wave_stride=1
NSI offset c=0.2
~~~

RTB-DAS 和 RTB-NSI 在所有几何、延时和采样条件上相同，只改变 receive apodization / envelope combination。

运行：

~~~matlab
addpath(genpath('D:/你的USTB路径'));
cd matlab/06_NSI
compare_rtb_das_vs_nsi
~~~

输出：

- Figure 1：RTB-DAS vs RTB-NSI，**共同 DAS 0 dB reference**，NSI 先除以 $c$；
- Figure 2：点目标 own-peak 横向 profile；同一深度的 DC envelope、ZM envelope 与相减后的 NSI envelope；
- Console：峰值位置、-6 dB 与 -20 dB lateral width、FWHM/grid spacing、执行时间。

### 2. 验证

脚本先检查：

1. 理想 on-axis 均匀孔径的 ZM 为零；
2. NSI envelope 满足 $0\le E\le c|D|$；
3. 新代码算出的 complex RTB-DAS 与 Chapter 1 独立 RTB core 在同一网格的 max-peak scaled error 小于 $10^{-10}$。

核心算法只需计算 **DAS 和 ZM 两路复数 Tx-compounded 图像**；DC1/DC2 通过 $Z+cD$、$-Z+cD$ 得到，与独立计算三套线性 receive apodizations 再作相同 coherent Tx compounding 的数学定义等价。

### 3. 如何解读结果？

- 若 NSI 形成很窄的 lateral profile，先看 FWHM 占多少横向采样点；过窄时不能给出高精度物理宽度结论。
- 同时检查 -20 dB lateral skirts、局部 speckle、异常暗孔洞及峰值损失。
- 不把点目标 FWHM 缩小直接解释为两个紧邻目标的实际 resolvability 提高相同比例。
- 论文已经报告：NSI 可明显压窄主瓣，却可能造成 speckle underdevelopment 与 CNR 损失。我们不重复扩展调参来追求视觉效果。

本次实验是**真正的 2D RTB ROI**，不是完整 5–45 mm 全视野扫描；这样能集中验证最关键的横向特性并降低 MATLAB 运行成本。

---

## 三、本章总结

**记住三点就足够：**

1. **NSI 不是更复杂的自适应延时，而是人为设计带中心 Null 的 receive apodization，利用 envelope subtraction 形成很窄的横向响应。**
2. **DC offset 是核心取舍参数**：更窄可能伴随 speckle 和对比度明显损失。
3. **运算顺序至关重要**：同一 RF/Tx/Rx alignment → 三路复数 receive weighting → coherent Tx compounding（若有）→ 三路 envelope → NSI subtraction → log display。

不继续扩展 dDC-NSI、3D/directional NSI、angle-domain NSI 等路线，除非将来有明确的工程需求。

### 主要来源

- Reeg J., Oelze M. (2015), Improving Lateral Resolution in Ultrasonic Imaging by Utilizing Nulls in the Beam Pattern, IEEE IUS. https://www.brl.uiuc.edu/Publications/2015/IUS_NSI_2015.pdf
- Agarwal A. et al. (2019), Improving Spatial Resolution Using Incoherent Subtraction of Receive Beams Having Different Apodizations, IEEE TUFFC. https://doi.org/10.1109/TUFFC.2018.2876285
- Taylor-Series-Based Derivation of the Resolution of Null Subtraction Imaging for a Uniform Linear Array (2025). https://doi.org/10.1109/OJUFFC.2025.3550096

### 代码入口

~~~text
matlab/06_NSI/
  reconstruct_fi_rtb_nsi_manual.m  % 同一 RTB baseline 上的 receive NSI
  compare_rtb_das_vs_nsi.m         % 一次性二维对照 + 复杂 DAS 回归验证
  README.md
~~~

**当前已提交原理与代码；尚未在用户 MATLAB+UFF 环境中实际执行，不能虚构 NSI FWHM、CNR 或性能提升数字。**

下一章为 **第 7 章：统一 Benchmark**。
