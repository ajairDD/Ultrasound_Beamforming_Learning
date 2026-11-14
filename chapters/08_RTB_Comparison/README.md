# 第 8 章：共享一套 RTB 前端，理解七种不同的组合规则

前几章分别学习了不同方法；第 7 章又讲了怎样组织量化对照。这一章把它们接到同一条数据流上，回答一个更具体的问题：

> **同一份 focused-Tx 通道数据，经过相同的 RTB 延时、插值与孔径选择后，为什么七种组合规则会得到不同的图？**

先理解共同前端，再理解各分支的运算和输出含义，最后看真实 TheGB 对照图。操作顺序、参数清单与接口注意事项放在主线之后。

[MATLAB 运行说明](../../matlab/08_RTB_Comparison/README.md) · [配图与课件索引](figures/README.md) · [上一章：统一 Benchmark](../07_Benchmark/README.md) · [标准接口详细说明](../../matlab/RTB_Universal/README.md)

---

## 本章学习入口

> **推荐顺序：** 先看共享 RTB 前端与七种组合规则，再理解输出类型，最后运行同几何对照。
>
> **最短实践：** `demo_rtb_method_building_blocks` → `run_chapter8_rtb_comparison`（第一步无需数据；第二步需要 USTB/UFF）。跨设备接口的支持边界见 RTB_Universal 说明。详细命令与参数以 [MATLAB 运行说明](../../matlab/08_RTB_Comparison/README.md) 为准。

**章节导航：** [← 上一章](../07_Benchmark/README.md) · [课程目录](../../README.md) · [MATLAB 运行说明](../../matlab/08_RTB_Comparison/README.md) · [配图与实验记录](figures/README.md) · [完整中文 PDF](../../output/pdf/第08章_七方法RTB对照.pdf)

> 先沿正文的**原理与计算主线**阅读，再运行小例子或真实数据；实验观察、实现细节及自测放在主线之后。PDF 包含完整配图，GitHub 上的独立 PNG 未提交。

---

## 1. 先看全貌：相同的是数据来源与几何，不同的是组合规则

![图 1：共享 RTB 前端以后，不同方法沿各自正确的顺序处理](figures/rtb_shared_frontend.png)

**图 1 怎么讲：** 从上方 RTB 框沿向左的箭头进入公共总线，再向下跟踪四条路径。每一行的起点都已经经过共同的延时、插值与有效孔径选择；复数幅度分支、实 RF 配对分支与相关性统计分支分别处理。

一条最简的数据流是：

~~~text
同一份 RF 通道数据
  → 元数据与物理通道顺序
  → 对候选像素计算 Tx/Rx 查询时刻
  → 分数采样插值、选取动态接收孔径
  → 各方法的通道组合与跨 Tx 合成
  → 包络或相干性
  → 明确参考后显示
~~~

这里“共享”不代表把所有方法都写成同一个求和再套函数。**CF/GCF 在每次 Tx 内求权重，NSI 要在相干合成后组合包络，SLSC 则平均相关统计量。** 这些次序是算法定义的一部分。

## 2. 一个候选像素，从哪里取得数据？

### 2.1 P 是重建位置，Fₜ 是发射焦点

![图 2：多个 Tx 为同一个候选像素提供贡献](figures/rtb_pixel_geometry.png)

**图 2 怎么讲：** 始终盯住同一个 P；Tx 改变时，发射路径与权重可以变化，接收路径也要按真实阵元坐标计算。Fₜ 与 P 是两个标记。图中用焦后像素作示意；本章真实约 20 mm 的目标在 29.6 mm 的 Tx 焦点之前，具体时间由 blended 模型计算。

RTB 使用 focused Tx 的传播模型，在其有效支持范围内重建候选像素。输出网格只定义“在哪里算图像”，没有新增采集。Tx/Rx 时间模型沿用[第 1 章](../01_DAS_Real_UFF/README.md)，这里把它记成：

$$ \tau_{i,t}(P)=\tau_{\mathrm{Tx},t}(P)+\frac{\|P-E_i\|}{c_{\mathrm{Rx}}}. $$

Eᵢ 是第 i 个接收阵元的物理坐标。Tx 模型还包含焦点、参考距离、发射延迟及 blended 约定，不能简单把任意像素的 Tx 时间都替换成一个未说明符号的焦点距离。

### 2.2 查询时刻对应哪个样点？

第 t 次 Tx 的首样点时间为 t₀,ₜ，采样率为 fₛ。MATLAB 从 1 开始的分数索引是：

$$ u_{i,t}(P)=1+\bigl(\tau_{i,t}(P)-t_{0,t}\bigr)f_s. $$

`u` 通常不是整数，所以需要插值；查询超出记录时间窗的通道不能当作有效接收样本。接收孔径还按 Rx F# 随深度变化。

接下来区分两种数据：

- `s_i,t(P)`：解析 RF 的**复数**延时样本，保留相位，用于 DAS、CF、GCF、MVDR、NSI。
- `r_i,t(P)`：原始**实 RF**的延时样本及其局部轴向窗，用于本实现的 fDMAS 和 SLSC。

本轮原始 RF 为 `[sample,Rx,Tx,frame]=[1920,128,128,1]`。最终所有图统一为 `[z,x]`，但“坐标相同”还不代表灰度具有同一个物理含义。

## 3. 用同一组变量，逐个看七种组合规则

![图 3：七种方法分别选择通道信息的方式](figures/rtb_seven_mechanisms.png)

**图 3 怎么讲：** 先把七张卡片各说成一句话，再对照下面的公式与 MATLAB 图。GCF 用低频能量占比得到标量权重；它不是把频谱裁掉以后直接重建。NSI 的三路需要分别取包络后再组合。

以下默认当前像素受到 Tx 孔径支持。第 t 次 Tx 有 Mₜ 个有效 Rx；αₜ 是非负 Tx 权重。声速写成 c，NSI 偏置另记为 δ，避免混淆。

### 3.1 DAS：延时对齐以后相加

每次 Tx 先在有效接收孔径内求和，再跨 Tx 做相干加权平均：

$$ d_t(P)=\sum_{i=1}^{M_t}s_{i,t}(P),\qquad D(P)=\frac{\sum_t\alpha_t(P)d_t(P)}{\sum_t\alpha_t(P)}. $$

D 仍是复数，最后显示 `|D|`。这里的分母沿用第 1 章：按 Tx 孔径支持累计权重；没有有效 Rx 样点的贡献为零，并另外报告数据支持比例，避免把缺失数据静默重新放大。

### 3.2 CF：在每次 Tx 的接收孔径内衡量相干程度

$$ \gamma_{\mathrm{CF},t}=\frac{\left|\sum_i s_{i,t}\right|^2}{M_t\sum_i|s_{i,t}|^2+\varepsilon},\qquad C(P)=\frac{\sum_t\alpha_t\gamma_{\mathrm{CF},t}d_t}{\sum_t\alpha_t}. $$

同相通道相加很强，分子就大；不同相位互相抵消时，权重会减小。**权重在各 Tx 内计算，再对加权复数输出做 Tx 合成**，不能随意交换次序。

![图 4：先逐 Tx 求 CF 与先合通道再求 CF 的反例](figures/demo_rtb_method_building_blocks_01.png)

**图 4 怎么讲：** 同一组两次 Tx 输入，正确的本仓库顺序得到 2，换序得到 1。这是代数例子，不代表新采集序列。

每个 Tx 的 CF 在 0–1 内，但跨 Tx 存在复数相消，**最终 CF 包络不必在每个像素都小于 DAS 包络**。不能把“每次 Tx 乘一个小于 1 的数”直接推广成最终像素的逐点幅度上界。

### 3.3 GCF：给低空间频率结构更多容许

对当前 Rx 通道向量做孔径方向 FFT，记为 Sₜ[k]：

$$ \gamma_{\mathrm{GCF},t}=\frac{\sum_{k\in\mathcal K_0}|S_t[k]|^2}{\sum_k|S_t[k]|^2+\varepsilon}. $$

`M0=1` 时选择零频及其两个相邻频率 bin；`M0=0` 只保留零频能量占比。由 Parseval 关系，后者与 CF 相同。FFT 的轴是**接收孔径通道**，不是 RF 采样时间轴。

![图 5：同相、相位斜坡、交替反相与随机孔径的空间谱](figures/demo_rtb_method_building_blocks_02.png)

**图 5 怎么讲：** 一阶相位斜坡在零频没有能量，但在邻近 bin 有能量，因而 GCF(M0=1) 比 CF 更宽容。最后仍是用这个标量权重乘该 Tx 的 DAS 复数和。

### 3.4 MVDR：用协方差求满足目标增益约束的权重

延时对齐后，目标方向的理想 steering vector 记为全 1 向量 a。根据相邻轴向位置与重叠子阵估计协方差，再做 diagonal loading：

$$ R_\eta=R+\eta\frac{\operatorname{tr}(R)}{L}I,\qquad w=\frac{R_\eta^{-1}a}{a^H R_\eta^{-1}a},\qquad w^Ha=1. $$

代码用 `R_eta\a` 求解，而不是显式构造逆矩阵。每次 Tx 的自适应输出再保留相位进行 Tx 合成；本实现还采用名义 DAS 接收尺度的 Mₜ 因子。它是数值尺度约定，不是跨方法声压标定。

![图 6：解析协方差模型中的目标约束与干扰响应](figures/demo_rtb_method_building_blocks_03.png)

**图 6 怎么讲：** 两组权重在目标方向增益都为 1，但对指定模型干扰方向的响应不同。横轴是归一化空间频率；这个小例子没有运行完整 RTB 子阵平滑，也不是 TheGB 实测 PSF。

完整核心使用子阵比例 0.5、loading 0.01、约 1.5λ 的轴向平均；估计失效时会退回 DAS 并计数。退回次数为零只说明这条数值分支没有触发，不证明协方差模型没有失配。

### 3.5 fDMAS：实 RF 带符号开方、成对组合，再选频带

先定义变换后的实 RF 通道：

$$ v_{i,t}=\operatorname{sign}(r_{i,t})\sqrt{|r_{i,t}|},\qquad f_t=\sum_{i<j}v_{i,t}v_{j,t}=\frac{\left(\sum_i v_{i,t}\right)^2-\sum_i v_{i,t}^2}{2}. $$

右边的恒等式避免显式枚举全部通道对。不能漏掉带符号开方，直接把这个定义讲成原始 RF 两两相乘。

![图 7：带符号开方后的配对结果与二倍频滤波](figures/demo_rtb_method_building_blocks_04.png)

**图 7 怎么讲：** 两路相同 RF 时，配对得到 `|RF|`，并非直接 `RF²`；频谱出现直流与约 2f0 分量。图中明确区分配对后频谱、带通后频谱及滤波器设计。

**本仓库的 RTB 扩展顺序**是：每次 Tx 内配对 → 用 Tx 权重合并实数配对结果 → 在输出深度轴上做约 2f0 带通 → 解析包络。这是明确记录的教学组合约定，尚无与独立 RTB-fDMAS 金标准的逐点等价性验收。

深度网格对应的等效双程时间采样率为：

$$ f_{s,\mathrm{image}}=\frac{c}{2\Delta z},\qquad \frac{f_{s,\mathrm{image}}}{2}>f_{\mathrm{high}}. $$

默认最高过渡边缘 `f_high=2.75f0`，因此需要 `Δz<c/(4f_high)`。本章按约 λ/16 选取深度网格，专门给二倍频链路留下采样余量；这与横向网格密度是不同问题。

这里采用代码的双程等效深度时间约定，是该 RTB 扩展的一项滤波近似；它与设备的原始 RF 采样率分开记录。

### 3.6 SLSC：统计近邻通道的一致性，不生成 RF 幅度

在同一 Tx 的实 RF 轴向窗内，计算物理间隔为 ℓ 的通道对：

$$ \rho_{i,\ell,t}=\frac{\sum_{q\in\mathcal G}r_{i,t}[q]\,r_{i+\ell,t}[q]}{\sqrt{\sum_{q\in\mathcal G}r_{i,t}[q]^2\sum_{q\in\mathcal G}r_{i+\ell,t}[q]^2}}. $$

q 遍历**轴向窗**，ℓ 表示**接收通道间隔**；它们不是同一个方向。这里不另减局部均值。先平均有效通道对，再平均有效短 lag；本轮最大 lag 12，并受有效 Rx 数量的约 15% 限制，轴向窗约 1λ。

跨 Tx 时，代码对有效的相关性估计做**非相干加权平均**，分母只包含有有效 SLSC 估计的 Tx 权重，不把相关值当作复数 RF 去相干合成。

![图 8：低幅度也可以高度相关，高幅度也可以不相关](figures/demo_rtb_method_building_blocks_05.png)

**图 8 怎么讲：** 同一组同相波形乘大或乘小，归一化相关仍可为 1；通道和的幅度却明显改变。SLSC 亮，不等于回波幅度强。

原始 SLSC 结果保留 −1 至 1 的有符号相关值；显示时把负值裁剪到 0。`slsc_valid_mask` 另行标记没有有效估计的像素，灰色不等于测得了零相关。

### 3.7 NSI：先保留中心零点，再通过包络相减留下窄响应

每次 Tx 的当前接收孔径分成正负两半，得到零均值分支 zₜ；奇数孔径的中间元素在该分支权重为零，但仍计入普通 dₜ。先分别对 dₜ、zₜ 做相干 Tx 合成，得到 D、Z，再组合：

$$ E_\delta=\frac{|Z+\delta D|+|-Z+\delta D|}{2}-|Z|,\qquad A_{\mathrm{NSI}}=\frac{\max(E_\delta,0)}{\delta}. $$

δ>0 为 DC offset；本章默认 0.8。三路必须**分别取包络后再相减**，除以 δ 则是本项目与 DAS 对照的尺度约定。一般复数输入也满足：

$$ 0\le A_{\mathrm{NSI}}\le|D|. $$

![图 9：固定 D、Z，仅改变 NSI 的偏置](figures/demo_rtb_method_building_blocks_06.png)

**图 9 怎么讲：** 四通道例子的三种输入都能手算。中间那组在 δ=0.2 被完全相减，δ=0.8 则保留部分幅度；算法没有借此识别“哪一种组织应留下”。完整推导见[第 6 章](../06_NSI/README.md)。

## 4. 算完之后，先认清输出类型，再比较灰度

### 4.1 坐标一致，不等于信号定义一致

![图 10：幅度相关输出、非线性频带输出与相干性输出](figures/rtb_output_types.png)

**图 10 怎么讲：** 三层使用相同坐标，但各自解释数值。缩略超声画面仅作示意；真正的 TheGB 结果在后面。

| 分支 | `out.images` 存的是什么？ | 默认怎样显示？ |
|---|---|---|
| DAS、CF、GCF、MVDR | 复数输出的包络 | dB |
| NSI | 三路包络组合，除以 δ 后的非负值 | dB |
| fDMAS | 二倍频带通后的解析包络，未作跨方法幅度标定 | 自身峰值 dB |
| SLSC | 原始有符号相关性标量 | 负值裁到 0，线性 0–1；无效估计用遮罩区分 |

### 4.2 两种参考，回答两个不同问题

对于非负幅度相关图 Aₖ，自己的全图峰值为 Pₖ，DAS 全图峰值为 Pᴅ：

$$ B_{\mathrm{own},k}=20\log_{10}\frac{A_k}{P_k},\qquad B_{\mathrm{common},k}=20\log_{10}\frac{A_k}{P_D}. $$

实际显示还加数值保护并裁剪到动态范围内。

![图 11：各自峰值与共同参考的区别](figures/rtb_display_reference.png)

**图 11 怎么讲：** 两种处理作用于同一目标；换参考不改变未压缩输出。独立归一化便于看形状，却能隐藏峰值降低。示意峰高不作测量读数。

- **各自峰值图：** 看形状、纹理和背景变化；相同白色不代表相同原始幅度。
- **共同 DAS 参考图：** DAS/CF/GCF/MVDR/NSI 使用同一数值参考，辅助观察相对压低；仍未完成物理声压或反射强度标定。
- **两个固定例外：** fDMAS 始终使用自身峰值参考；SLSC 始终使用线性相关性。核心把它们的 `display_common_db` 留空，避免误用。

## 5. 为什么还要讲输入接口？因为“能成像”不保证物理含义正确

### 5.1 标准化的是轴、单位、时序和通道身份

![图 12：从设备数组到标准物理含义，再做独立 DAS 回归](figures/rtb_metadata_bridge.png)

**图 12 怎么讲：** 逐个检查桥上的四项：哪个轴是时间、单位是什么、数组通道对应哪个真实阵元、RF/IQ 使用什么相位约定。最后的复数 DAS 回归是数值检查，不是跨厂商认证。

当前接口面向**二维近线性线阵、focused FI、波束形成前通道数据**。UFF 读取或厂商数组适配只是入口；它不解码任意私有文件，也不自动支持凸阵、矩阵阵列或其他发射波型。

特别需要明确：

| 内容 | 为什么会影响结果？ | 对应字段举例 |
|---|---|---|
| 数组轴顺序 | 时间/Rx/Tx 换错轴会改变插值与相干性 | `data_order` |
| 单位与首样点时间 | μs 误当 s、漏掉 t0 都会移动查询位置 | `units`、`sampling_frequency`、`initial_time` |
| 物理通道身份 | GCF、SLSC 和子阵要求真实的阵元邻接关系 | `channel_to_element`、`element_xyz` |
| Tx 时序与几何 | 焦点、参考距离、delay 符号决定传播模型 | `focus_xyz`、`tx_delay_convention` |
| RF/IQ 与相位参考 | 跨通道/Tx 的相位错误会破坏相干叠加 | `signal_type`、解调频率、相位参考时刻 |

### 5.2 IQ 为什么不能只插值以后直接相加？

假设某设备**已经明确声明**：

$$ q_i(t)=s_i^{\mathrm{analytic}}(t)\exp\!\left[-j2\pi f_{\mathrm{demod}}(t-t_{\mathrm{ref}})\right]. $$

那么在各通道自己的查询时刻，要恢复：

$$ s_i^{\mathrm{analytic}}(\tau_i)=q_i(\tau_i)\exp\!\left[+j2\pi f_{\mathrm{demod}}(\tau_i-t_{\mathrm{ref}})\right]. $$

![图 13：相位约定影响同一目标的相干求和](figures/demo_rtb_method_building_blocks_07.png)

**图 13 怎么讲：** 这个指定的 5 MHz 教学模型中，两路延时 IQ 查询值符号相反；按已声明约定恢复载频相位后，解析信号才会同相相加。不能把这个约定当作任何设备的默认约定。

当前实现对明确相位参考的 IQ 支持 DAS/CF/GCF/MVDR/NSI；本实现定义的 RF-fDMAS 与 RF-SLSC 仍需实 RF。把 `real(IQ)` 当作原始 RF 并不满足这些输入条件。

## 6. 先运行七个无需 UFF 的小实验

从仓库根目录：

~~~matlab
addpath('matlab/08_RTB_Comparison');
report = demo_rtb_method_building_blocks;
~~~

| 生成顺序 | 先预测的问题 | 要对应哪一段代码？ |
|---|---|---|
| 01 | CF 的权重能移到 Tx 合成后再算吗？ | Tx 内权重与复数合成次序 |
| 02 | GCF(M0=0) 为什么等于 CF？ | 接收孔径 FFT 与 Parseval 关系 |
| 03 | 目标增益不变时，其他方向能怎样改变？ | MVDR 约束与协方差 |
| 04 | 相同两路 RF 配对得到 RF² 还是别的量？ | 带符号开方、通道配对、带通 |
| 05 | 输入放大 100 倍，归一化相关会怎样？ | SLSC 的输出类型 |
| 06 | 相同 D、Z 在两种 δ 下保留多少？ | NSI 的三路包络组合 |
| 07 | 未恢复载频相位时，两路 IQ 会怎样相加？ | 插值后的相位恢复 |

固定种子 `rng(8,'twister')`。这些是代数、阵列因子或指定信号模型，均不代替真实数据或独立论文复现。导出：`export_chapter8_figures('concepts')`。

---

## 7. 真实 TheGB 实验：先固定本轮条件

本轮 2026-11-14 在 MATLAB R2021b 重跑 `run_chapter8_rtb_comparison`：

| 项目 | 本轮设置 |
|---|---|
| 输入 | `data/L7_FI_TheGB.uff`，真实 RF，第 1 帧 |
| 原始形状 | `[1920,128,128,1]`，依次为 sample、Rx、Tx、frame |
| 阵元间距 / Tx 焦深 | 0.298 mm / 29.6 mm |
| 时间参考 | `initial_time=0`；本数据 Tx/Rx 声速差为 0 |
| 输出范围 | x=−4 至 3 mm，z=18 至 22.5 mm |
| 横向网格 | 64 个位置，Δx≈0.11111 mm |
| 轴向网格 | 245 个位置，Δz≈0.018443 mm，由真实 λ/16 规则自动选择 |
| 选择的 Tx | `wave_stride=4`，从 128 次中取 32 次 |
| 公共前端 | blended，`blending_power=0.5`；Tx Tukey25，F#=2，最小孔径 3 mm；Rx F#=1.7 |
| 方法参数 | GCF M0=1；MVDR 子阵 0.5、loading 0.01、轴向 1.5λ；SLSC 约 1λ、15% 短 lag、上限 12；NSI δ=0.8 |
| fDMAS 频带 | 过渡/平台边缘 `[1.5,1.75,2.5,2.75]f0`，在 Tx 合并后的深度轴滤波 |
| 包络显示 | −60 至 0 dB；SLSC 例外，显示 0–1 |
| 联合全流程耗时 | **37.16 s**，包含输入读取与共同处理，不是各方法独立计时 |

这套**64 个横向位置、32 个 Tx**的集成实验，与第 7 章的密集 RTB 网格和全部 Tx 条件不同。不把第 7 章的 FWHM 数字移到这里。

## 8. 按三个步骤阅读真实结果

### 8.1 先看各自峰值参考图，认识外观变化

![图 14：七方法自身峰值图，SLSC 保持线性显示](figures/rtb_seven_methods_own.png)

**图 14 怎么讲：** 每次只比较一种现象：点目标形状、目标周围、远离目标的背景。先读标题中的参考方式，再读灰度。所有白色峰值不表示同样强的回波。

| 方法 | 本轮可观察的现象 | 如何结合机制解释？ |
|---|---|---|
| DAS | 宽的局部点响应与连续背景 | 共同几何下的相干求和基线 |
| CF | 背景变暗，强相干区域突出，目标周围出现暗区 | 对每次 Tx 的低相干接收成分加惩罚 |
| GCF | 相比 CF 保留更多背景，整体向 DAS 靠近 | 容许邻近低空间频率能量 |
| MVDR | 局部点响应形状变化；整体优势不能仅由本图判断 | 协方差驱动的权重与名义接收尺度 |
| fDMAS | 目标偏纵向细长，纹理不同 | 配对及二倍频链路改变输出；具体拉长机理未作单变量验证 |
| SLSC | 比较宽、平滑的相干性亮区 | 有限轴向窗与近邻统计的结果，不是包络 PSF |
| NSI，δ=0.8 | 目标突出，背景明暗起伏与局部黑区 | 三路包络相减会同时改变散射组织响应 |

这是对本 ROI 的定性解读，不是独立真值或七算法质量排名。

### 8.2 再换到共同参考，区分形状与幅度变化

![图 15：共同 DAS 参考图中的两个固定例外](figures/rtb_seven_methods_common.png)

**图 15 怎么讲：** DAS/CF/GCF/MVDR/NSI 使用共同参考，fDMAS 标题明确保留自身参考，SLSC 仍是线性值。先指出这两个例外，再讨论相对压低。

![图 16：实际的 Tx 孔径支持与数据支持诊断](figures/rtb_diagnostics_01.png)

**图 16 怎么讲：** 全程选了 32 次 Tx，但每个像素只使用其中受孔径支持的贡献。Tx 数量、权重之和、有效 Rx 数据覆盖比例是不同量；它们不是成像质量分数。

![图 17：同一固定深度，分别切换两种峰值参考](figures/rtb_diagnostics_02.png)

**图 17 怎么讲：** 两边固定在 DAS 全图峰值的深度 **z≈20.0471 mm**。只有参考分母改变，圆点还是同一组实际网格值。这里的切片定义与第 7 章“各自峰值深度”测宽不同。

64 点的横向间距约 0.111 mm，足够用于这轮快速外观对照，但不能由连线外观直接给窄主瓣分配精确 FWHM 或分辨率倍数。

### 8.3 最后分别检查非线性频带与相关性分支

![图 18：fDMAS 轴向形状与配置中记录的带通设计](figures/rtb_diagnostics_03.png)

**图 18 怎么讲：** 左图固定在 DAS 峰值横向位置，两个轴向切片各自归一化；右图只画 `out.fdmas_filter` 中记录的设计频带与网格 Nyquist。它不是从包络反推出的原始 RF 频谱，也没有把细长形态归因为唯一原因。

![图 19：相同像素上的 DAS 幅度与 SLSC 相干性](figures/rtb_diagnostics_04.png)

**图 19 怎么讲：** 左侧散点说明同一像素可以有低幅度与高相关；右侧区分 SLSC 原始有符号结果和显示裁剪。没有有效估计的像素仍必须单独看遮罩，不能与测得的零值混同。

## 9. 本轮到底验证到了哪一层？

| 层次 | 本轮事实 | 能支持什么？ |
|---|---|---|
| 输入接口合成检查 | 轴排列、单位、通道映射、RF/IQ 及错误元数据等测试通过 | 当前声明的输入合同和部分边界行为 |
| 独立 DAS 回归 | `6.533229e-16` 的峰值归一化复数误差，Tx 权重差 0 | TheGB 当前双精度共同几何与 DAS 基线一致 |
| 真实 RF 集成 | 七方法完成；MVDR fallback **0/61289**；SLSC 无效 pixel-Tx **0** | 当前数据/参数的端到端运行与数值输出可用 |
| 新增教学检查 | CF/GCF 边界、配对恒等式、NSI 上界、IQ 相位等通过 | 指定小模型与运算次序正确对应 |
| 跨厂商与算法独立金标准 | 尚未验收 | 不能由以上通过记录推断已经完成 |

每种输出的 `[z,x]` 形状与 finite 检查均通过。**finite 不代表一定对，漂亮也不代表一定对。** 本轮还没有标注病灶 ROI、重复统计、七算法同条件的完整客观指标表；fDMAS/SLSC 的 RTB 扩展仍需独立算法基准。

37.16 s 是这轮七方法共用前端的联合计时；先前的 41.37/38.66 s 来自其他单次运行。不能给每种方法各分配一个 37.16 s，也不能据这些波动声称加速。

[真实运行与回归日志](figures/matlab_integration_results.txt) · [小实验及数值缓存诊断日志](figures/matlab_lecture_results.txt)。本机 MATLAB 的既有 `Settings` 退出提示在完成输出后仍出现，单独作为环境问题记录。

## 10. 对应到文件、变量与实际运行

### 10.1 运行固定条件的七方法实验

~~~matlab
addpath(genpath('D:/你的USTB路径'));
cd matlab/08_RTB_Comparison
out = run_chapter8_rtb_comparison;
~~~

它复用 `matlab/RTB_Universal` 的共享核心，不复制前六章的七套重建代码。默认输出在 `output/benchmark/ch08/`：

~~~text
RTB_seven_methods_own.png
RTB_seven_methods_common.png
RTB_seven_methods_results.mat
~~~

MAT 保存图像、坐标、配置和诊断结果，不把原始 RF 写入结果。完整的 13 张中文 MATLAB 课件图：

~~~matlab
% 从仓库根目录
addpath(genpath('D:/你的USTB路径'));
addpath('matlab/08_RTB_Comparison');
export_chapter8_figures('all');     % 小实验、接口/独立 DAS 检查与真实七方法
export_chapter8_figures('cached');  % 复用已有 image_results，不重复重建
~~~

### 10.2 从总体数据流找到函数

~~~text
设备 raw + 已确认 meta → rtb_from_vendor_array → canonical acq
UFF / canonical acq    → rtb_load_acquisition  → 校验、SI 单位、物理通道排序
                         ↓
                  rtb_reconstruct_all
                    ├─ 共同 Tx/Rx 时延、插值、Rx 孔径
                    ├─ 逐 Tx 的方法运算与跨 Tx 组合
                    └─ images、display、坐标、权重与诊断
                         ↓
                  rtb_show_methods
~~~

| 要查看或修改什么？ | 先看哪个位置？ |
|---|---|
| 数据轴、单位、物理通道映射 | `rtb_from_vendor_array.m`、`rtb_load_acquisition.m` |
| 传播时间、索引与孔径 | `rtb_reconstruct_all.m` 的 Tx/Rx 公共前端 |
| CF/GCF、MVDR、fDMAS、SLSC、NSI | 同核心的逐 Tx/逐像素循环及后处理 |
| 本章固定参数 | `run_chapter8_rtb_comparison.m` 的 `cfg` |
| 显示标题与参考方式 | `rtb_show_methods.m` |
| 无 UFF 的机制图 | `demo_rtb_method_building_blocks.m` |
| 已保存真实结果的诊断图 | `inspect_rtb_comparison_outputs.m` |

重要变量：

- `out.images.*`：未取对数的实数 `[z,x]`，SLSC 保留有符号相关值。
- `out.rtb_das_analytic`：复数 `[z,x]` 的共同 DAS，供数值检查。
- `out.x_axis_m` / `out.z_axis_m`：一维坐标，单位 m。
- `out.display`：各自峰值 dB 或 SLSC 的线性显示值；`display_common_db` 只给可用分支。
- `out.tx_weight_sum`、`active_tx_count`、`valid_rx_tx_fraction`：几何支持和数据覆盖。
- `out.slsc_valid_mask`：相关性估计是否存在；`out.diagnostics`：fallback、缺失样本等计数。
- `out.options`：这次实际使用的参数，含选中的 Tx 索引。改它不会自动重算 `images`；改算法参数后需重新调用重建。

已有 `out` 时，仅换显示参考无需再次重建：

~~~matlab
addpath('matlab/RTB_Universal');  % 从仓库根目录
rtb_show_methods(out,'own');
rtb_show_methods(out,'common');
~~~

### 10.3 修改或适配数据时的排查顺序

先确认数据确为本模型支持的预波束形成 focused-FI 通道数据，再运行 `rtb_audit_source` 查看采样覆盖、t0 与几何。若独立 DAS 回归失败，先定位坐标、时序、插值与权重；不应先解释某自适应方法为何“图不好看”。

调试时尤其注意：物理 Rx 重排后再做 lag/子阵；不提前对解析 RF 取模；不从对数图计算幅度指标；不把所有方法的无效值和显示裁剪混为一谈。

## 11. 课件讲解顺序与自检

1. **共同前端：** 图 1–2，手指跟踪一个 P 和一次 Tx，从查询时刻讲到有效 Rx 向量。
2. **分支机制：** 图 3–9，用小例子预测权重、配对、相关和相减的结果。
3. **输出含义：** 图 10–13，先认清灰度，再讨论参考与输入相位。
4. **真实读图：** 图 14–19，逐项对应条件、现象与尚未完成的验证。

应能回答：

- 为什么 P 的深度不必等于 Tx 焦深？输出网格加密会不会增加 RF 采集？
- CF/GCF 的权重在哪一步算？GCF 的 FFT 沿哪个轴？
- fDMAS 为什么要带符号开方，又为什么要检查 Δz？
- SLSC 的 lag 与轴向窗有什么区别？为什么不能作复数 Tx 相干合成？
- NSI 为何必须先分别取包络？δ 与声速 c 分别指什么？
- 各自峰值图中的白色能否比较幅度？共同参考图的两个例外是什么？
- 接口合成检查、独立 DAS 回归、真实七方法跑通，分别验证了什么？

这章的学习目标是把**输入、几何、运算次序、输出类型和读图依据**连成一条线。各方法的完整理论与原始文献见[第 1–6 章](../../README.md)，量化比较的协议与局限见[第 7 章](../07_Benchmark/README.md)。
