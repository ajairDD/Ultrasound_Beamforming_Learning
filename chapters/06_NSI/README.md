# 第 6 章：NSI（Null Subtraction Imaging）

**状态：已完成教学实验（TheGB 密集二维点目标 + 全视野体模 + 两组真实人体颈动脉）。** 核心发现是窄点目标响应与严重组织/speckle 抑制之间的取舍；尚无独立临床有效性或 CNR/gCNR 优势证据。

本章结构：一节完整原理、一组分阶段二维实验（点目标到完整体模及人体验证）、一个总结。不再扩展 NSI 变体。

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

第一阶段为点目标的 **dense 2D RTB ROI**，用于隔离横向响应；随后追加全视野 TheGB / carotid 实验，检查是否会普遍损伤 speckle 或真实组织结构。

### 4. TheGB 点目标初步结果：响应很窄，但明显过度抑制

用户在 MATLAB 运行默认点目标密集 RTB-NSI，给出 Figure 1 和 Figure 2 截图：

- **Figure 1**：与 RTB-DAS 相比，NSI 的点目标在 x 方向明显收窄；但附近背景出现大片近黑的断裂/不连续纹理。
- **Figure 2 左**：NSI 横向 profile 的 -6 dB 主瓣明显更窄，-20 dB 以外的横向响应也出现强抑制；这显示了 NSI 借 Null cancellation 产生窄有效响应的特点。
- **Figure 2 右**：ZM 与 mean(DC1,DC2) 两条 envelope 曲线几乎重合，仅在目标中心附近留下一个小残差，符合 \(E_{\rm NSI}\) 是两个近似相等量相减得到的计算结构。**这也表明它容易对小的模型/噪声误差敏感。**

但这些图**不能证明**“NSI 真实分辨率提高数倍”或“背景杂波被正确去除”。尤其是 speckle 大片变黑可能意味着真实组织信号一并被抑制。用户尚未提供本轮 Console 的精确 FWHM/回归误差，因此不编造数值。

### 5. 第二阶段：全视野 TheGB 与真实 carotid

新增：

~~~text
matlab/06_NSI/compare_full_fov_rtb_das_vs_nsi.m
~~~

一键运行：

~~~matlab
compare_full_fov_rtb_das_vs_nsi
~~~

默认直接比较 **TheGB 全视野** 与 **L7_FI_carotid_cross_1 全视野**。为了快速判定结构破坏是否普遍存在，默认设置：

~~~text
x: full focused Tx span (UFF metadata -> automatic)
z: 5–45 mm
n_x=257, n_z=385
wave_stride=2
dc_offset=0.2 (与上一轮保持一致)
~~~

Figure 1 每组显示同一 DAS 0-dB reference 下的 RTB-DAS/NSI；Figure 2 显示经过阈值掩膜的 NSI/DAS amplitude ratio（0–1）。这两个图的意义不同：前者看组织形态，后者看算法抑制强度，而不是以“黑”自动判断是否正确。

可选第二份独立 carotid：

~~~matlab
dataset_indices=[1 2 3];
compare_full_fov_rtb_das_vs_nsi
~~~

如果需要最终检查 all-Tx 而不仅是半数 Tx 快速预览：

~~~matlab
wave_stride=1;
n_x=385;
n_z=513;
compare_full_fov_rtb_das_vs_nsi
~~~

第二阶段先固定 c=0.2，随后用户额外以 c=0.8 进行了单变量对照；比较结果见下一节。更大 c 使输出逐渐接近 DAS，不应将这种亮度恢复直接视作 NSI 效果更好。

**以上全视野实验已经在用户 MATLAB 环境运行并提供 Figure 1 / Figure 2 截图。** 下面记录可由图直接支持的观察；由于没有完整 Console，不记录运行时间、精确 DAS regression error、CNR/gCNR 等未知数值。

### 6. 最终全视野验证：c=0.2 与 c=0.8（2026-11-12）

用户提供了 **3 组完整 Figure 1 + Figure 2**，均覆盖 TheGB、carotid cross 1、carotid cross 2：

| 对照条件 | TheGB median ratio | Carotid 1 | Carotid 2 |
|---|---:|---:|---:|
| c=0.2；wave_stride=2；n_x=257, n_z=385 | **0.07** | **0.06** | **0.06** |
| c=0.2；wave_stride=1；n_x=385, n_z=513 | **0.07** | **0.06** | **0.06** |
| c=0.8；wave_stride=1；n_x=385, n_z=513 | **0.37** | **0.38** | **0.37** |

这些数据直接读取自截图的 Figure 2 标题（保留两位小数），其定义是：

$
r(x,z)=\frac{E_{\rm NSI}(x,z)/c}{|D(x,z)|},\qquad 0\le r\le1,
$

仅对 **DAS ≥ -40 dB、且有 Tx 覆盖** 的像素计算 median。**这是经过显示尺度修正的算法幅度保留比例，不是功率比例、不是信噪比，也不是图像质量指标。** 图 2 的灰色像素被 masking 排除，不等于这些区域的相关算法结果为 0。

**观察 A：c=0.2 很激进，不是“全图杂波干净了”。**

- 在 TheGB 中，点目标仍明显，但大量本来有连续 speckle 的背景接近全黑，正常 speckle 信息也被强烈抑制。
- 在两组 carotid 中，血管腔变暗的同时，血管壁连续性和周围组织纹理也受到明显破坏。
- 三组 foreground median ratio 仅约 0.06–0.07，即在所述有效像素集合下，归一化后的 NSI 幅度通常只有对应 DAS 幅度的很小一部分。**不能把这些受抑制成分都认定为 clutter。**

**观察 B：增加 Tx 数量/提高网格分辨率没有解决强抑制。**

在同一个 c=0.2 下，wave_stride=2（较粗输出网格）与 wave_stride=1（较密输出网格）的 Figure 1 形态和三组 median ratio 基本相同。这是两个条件同时改变的对照，**并非独立隔离 Tx 数量与图像采样间隔的严格实验**；但它支持“不是单纯因为快速预览太粗、Tx 太少才导致大片暗区”的判断。

**观察 C：c=0.8 能显著恢复幅度和组织结构，但未恢复成完整自然的 B-mode 纹理。**

- 三组 median ratio 提高到约 0.37–0.38；
- TheGB 的组织纹理、目标周围回波恢复明显，但与 DAS 相比仍更碎片化、颗粒化；
- carotid 近/远壁和周围实质组织比 c=0.2 更容易辨识，但仍有非自然的组织间断和纹理改变；
- 对照 c=0.2 与 c=0.8 的 wave_stride=1, n_x=385, n_z=513，可以较好隔离 **DC offset** 的影响。

机制上，c 增大后 DC 分量 $cD$ 相对 ZM 分量 $Z$ 更强，$E_{\rm NSI}/c$ 趋向 DAS envelope；亮度恢复是算法本身的数学结果，并不自动代表更高的分辨率或对比度。

#### 对第 6 章的最终科研判断

> **NSI 在 TheGB point-target RTB 上展示了强 lateral narrowing，但完整体模与两组真实 carotid 显示，在当前 receive-NSI / RTB 实现和这些数据下，c=0.2 导致严重组织回波损失，c=0.8 虽明显改善但仍损伤 speckle 和结构连续性。不能把本次 NSI 认定为更好的通用人体 B-mode 方案。**

这一判断适用于**本次实现、发射/接收模型和三份数据**，不否定 NSI 在其他专门序列、孔径设计、参数或任务下的潜在价值。

本轮全视野脚本的 run_rtb_reference_check 默认是 false。已有点目标脚本设置了 DAS regression，但本轮未提供完整 Console；**全视野图像成功显示不等于已经独立数值验证全视野 RTB-DAS 分支**。本章完成的是教学目标和定性鲁棒性判断，不是独立标准 phantom 量化 benchmark。

---

## 三、本章总结

**记住三点就足够：**

1. **NSI 不是更复杂的自适应延时，而是人为设计带中心 Null 的 receive apodization，利用 envelope subtraction 形成很窄的横向响应。**
2. **DC offset 是核心取舍参数**：本次 c=0.2 的 median amplitude retention 仅约 0.06–0.07；增到 c=0.8 后约 0.37–0.38，组织恢复但仍出现明显 speckle/结构破坏。
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
  compare_rtb_das_vs_nsi.m         % 点目标密集二维对照 + DAS 复数回归验证
  compare_full_fov_rtb_das_vs_nsi.m % 全视野体模/人体形态鲁棒性
  README.md
~~~

**当前已完成 TheGB 点目标、TheGB 全视野和两组真实 carotid 全视野的教学实验。** 截图支持形态和 median-ratio 的定性结论，但缺少完整 Console 与独立 ground-truth 指标，不填写或猜测 CNR、gCNR、精确 FWHM 或临床性能提升数字。

下一章为 **第 7 章：统一 Benchmark**。
