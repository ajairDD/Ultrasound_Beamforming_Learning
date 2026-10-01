# 第 1 章：从 conventional FI-DAS 到 RTB

本章围绕一个问题展开：**一组聚焦发射记录下来的通道波形，怎样一步步变成超声图像？**

我们先完整走通 conventional FI-DAS：一次发射，重建一条扫描线；再沿着同一条计算链理解 RTB：一次发射重建一片像素，多次发射共同重建同一个像素。这样，后面的时间偏置、插值、孔径和发射模型都有明确的位置。

第一次阅读先读完第一部分，再打开 MATLAB。第一部分讲算法为什么这样做；第二部分把算法对应到本仓库；第三部分集中说明实现和读图细节。配套代码见 [MATLAB 第一章说明](../../matlab/01_DAS_Real_UFF/README.md)，全部配图与参数见 [课件配图索引](figures/README.md)。

| 阅读阶段 | 要建立的理解 | 读完后能做什么 |
|---|---|---|
| [第一部分：算法原理，第 1–5 节](#theory) | 采集波形 → 接收 DAS → 一发一线 → RTB 跨发射组合 | 自己讲出两种算法的完整流程 |
| [第二部分：对应到仓库，第 6–8 节](#practice) | 数据、核心函数、实验结果和参考实现 | 跑通重建，并知道每一步在检查什么 |
| [第三部分：实现与读图细节，第 9–13 节](#implementation-notes) | 时间参考、采样、孔径、Tx 模型与结果解读 | 出现差异时，沿计算链定位原因 |

<a id="theory"></a>

## 第一部分：先理解完整的成像过程

### 1. 聚焦发射之后，我们实际得到了什么？

超声探头包含多个阵元。一次发射时，参与发射的阵元以适当的时间先后发出脉冲，让声波在预定位置附近聚焦；这就是 **Focused Imaging（FI，聚焦发射成像）**。一次发射记作一个 **Tx 事件**。

声波经过组织中的散射体后产生回波。不同接收阵元与散射体之间的距离不同，同一个回波到达它们的时间也不同。每个接收通道 **Rx** 记录一条随时间变化的波形，通常称为 RF 信号。

![一次聚焦发射与多通道接收](figures/focused_acquisition.png)

**图 1｜一次 Tx 记录多条 Rx 波形。** $F$ 是预设发射焦点，$P$ 是示意散射体。发射聚焦决定声波怎样照射，接收通道记录回波怎样返回。图为 AI 概念插画，不按比例。

因此，采集后的原始数据还不是图像。它更像一组有组织的波形记录：

~~~text
Tx 1：Rx 1 的波形、Rx 2 的波形、……、Rx M 的波形
Tx 2：Rx 1 的波形、Rx 2 的波形、……、Rx M 的波形
……
Tx T：Rx 1 的波形、Rx 2 的波形、……、Rx M 的波形
~~~

为了覆盖不同横向位置，采集序列会依次进行多次聚焦发射。本章默认数据采用垂直的线性扫描，各次发射的横向焦点位置不同，焦深约相同。

**发射已经聚焦，为什么还要接收波束合成？** 因为发射聚焦只完成了照射，接收端仍有很多条波形。我们还要把来自某个位置的回波，在不同 Rx 上找到并组合起来。这正是接收 DAS 要做的事。

### 2. DAS 的起点：先想清楚“怎样重建一个像素”

图像中的一个像素对应一个候选空间位置 $P=(x,z)$。算法并不提前知道这里有没有散射体，而是逐个位置检验：

> 如果回波来自 $P$，它应该在每条通道波形的哪个时刻出现？

下面用 $t$ 表示 Tx 序号，$m$ 表示 Rx 序号；传播时间写成 $\tau$。先假设发射与记录采用一致的时间参考，用几何传播时间解释算法。真实 UFF 的时钟偏置在第 9 节处理。

声波先由第 $t$ 次发射到达 $P$，再由 $P$ 返回第 $m$ 个接收阵元。因此总时间包含两段：

$$ \tau^{\mathrm{geom}}_{m,t}(P)=\tau^{\mathrm{geom}}_{\mathrm{Tx},t}(P)+\tau_{\mathrm{Rx},m}(P). $$

#### 2.1 发射段：以焦点的到达时间作参考

聚焦声波在焦点之前收敛，在焦点之后发散。虚拟声源模型用焦点作为传播的参考位置：先知道到达焦点的参考时间，再估计经过其他像素的时间。

![焦点前后如何计算参考时间](figures/virtual_source_geometry.png)

**图 2｜焦点前更早经过，焦点后更晚经过。** 中心线上的 $P$ 位于焦点前时，从焦点时间减去剩余传播时间；位于焦点后时，加上继续传播的时间。减号表示更早，声波仍向深处传播。AI 插画中的 $F$ 是几何参考，不是实际散射体。

对本章的垂直中心线，记焦深为 $z_{f,t}$、焦点参考到达时间为 $T_{f,t}$，则：

$$ \tau^{\mathrm{geom}}_{\mathrm{Tx},t}(x_{f,t},z)=T_{f,t}+\frac{z-z_{f,t}}{c_t}. $$

这里 $c_t$ 是发射模型采用的声速。焦点前 $z-z_{f,t}<0$，焦点后 $z-z_{f,t}>0$。离开中心线后，还要考虑横向位置对传播路径的影响；RTB 会用到这一步，第 11 节再展开具体模型。

#### 2.2 接收段：从像素返回不同阵元

在本章的二维线性阵列示意中，阵元位于 $z=0$，第 $m$ 个阵元横坐标为 $x_m$：

$$ \tau_{\mathrm{Rx},m}(P)=\frac{\sqrt{(x-x_m)^2+z^2}}{c}. $$

对同一像素和同一次发射，Tx 时间只有一个，Rx 时间则随阵元而变。把它们相加，就得到每个通道各自的查询时刻。

#### 2.3 延时并求和：把同一个位置的观测对齐

沿每条波形到预测时刻取样，相当于把不同到达时间的回波对齐。再将这些样本加起来，就是 **Delay-And-Sum（DAS，延时并求和）**。

为了后续保留相位，以下用 $v^a_{m,t}$ 表示通道的复数解析 RF；它仍含载频振荡，可以同时表示幅值与相位。它的代码构造方法放在第 9 节。

$$ S_t(P)=\sum_{m=1}^{M}w_m^{\mathrm{Rx}}(P)\,v^a_{m,t}\!\left(\tau^{\mathrm{geom}}_{m,t}(P)\right). $$

读这个式子时，从内向外走：**传播时间 → 在通道里取样 → 接收加权 → 沿 Rx 相加**。$w_m^{\mathrm{Rx}}$ 表示该阵元参与多少；最简单时，参与的阵元权重为 1，其余为 0。

如果候选位置与真实回波来源吻合，对齐后的观测通常能相干叠加；位置不吻合时，回波较难保持同样的对齐关系。这种空间选择性让图像能够区分位置。真实组织包含许多散射体，错误位置的输出并不保证为零。

### 3. Conventional FI-DAS：把“一个像素”扩展成“一条线、一张图”

现在已经知道如何计算 $S_t(P)$。Conventional FI-DAS 的组织方式是：**第 $t$ 次发射只重建它对应的中心扫描线。**

对这条线，我们固定横坐标 $x=x_{f,t}$，沿深度依次放置候选像素：

$$ P_t(z)=(x_{f,t},z),\qquad Y_{\mathrm{FI}}(z,t)=S_t\!\left(P_t(z)\right). $$

在每个深度，重复刚才的 Tx/Rx 时间计算、通道取样和接收 DAS。完成全部深度后得到一列；换下一次 Tx，再得到下一列；把所有列按横向位置排列起来，就得到二维图像。

**一个 Tx 对应一条线，不是一个 Tx 只对应一个像素。** 每条线上有很多深度点。随着候选深度改变，接收延时也改变，形成动态接收聚焦；预设的发射焦点仍由采集时的发射设置决定。

本章 conventional 基线的完整算法是：

1. 取出第 $t$ 次 Tx 的全部 Rx 波形。
2. 选它的中心线，在这条线上逐个遍历深度。
3. 对每个像素计算 Tx 时间与各 Rx 时间。
4. 查询对应通道样本，接收加权后相干求和，得到一个复数像素。
5. 完成该条线后，处理下一次 Tx。
6. 所有线拼好后，取包络并转换为 B-mode 显示。

~~~mermaid
flowchart LR
    A[一次 Tx 的多条 Rx 波形] --> B[中心线上的一个深度点]
    B --> C[计算 Tx 和 Rx 时间]
    C --> D[按各自时间取样]
    D --> E[沿 Rx 相干求和]
    E --> F[遍历深度得到一条线]
    F --> G[遍历 Tx 拼成二维图像]
    G --> H[包络与 dB 显示]
~~~

#### 相干求和为什么要在取包络之前？

RF 有正负振荡，解析 RF 还保留复数相位。波束合成要利用这些信息进行相长和相消。如果先把每个通道变成幅值，原来应该相消的观测也会被加成正值。

例如两个已取出的观测是 $1$ 和 $-1$：相干和为 0，先取幅值再相加却得到 2。

![相干求和之后再取包络](figures/coherent_processing.png)

**图 3｜先相干相加，再取包络。** 通道对齐后仍保留振荡，中间完成求和，最后才取幅值与 dB。AI 图中的矩形 B-mode 缩略图只是示意。

最后，复数图像转换成包络和相对幅值 dB：

$$ A_{\mathrm{FI}}(P)=|Y_{\mathrm{FI}}(P)|,\qquad I_{\mathrm{dB}}(P)=20\log_{10}\frac{A_{\mathrm{FI}}(P)}{A_{\mathrm{ref}}}. $$

包络表示回波幅值；对数压缩让较弱回波也能在有限的显示灰度中看见。到这里，conventional FI-DAS 已形成完整闭环：**波形 → 逐点接收聚焦 → 扫描线 → 二维复数图像 → B-mode**。

### 4. RTB：继续使用同一个 DAS 构件，扩大重建范围并组合多次发射

Conventional 已经得到图像，为什么还要 RTB？

一次聚焦发射实际照射的是有一定宽度的区域，中心线周围的散射体也可能留下回波。同一位置还可能被相邻的几次 Tx 照射。原始通道数据中，因此可能存在多个 Tx 对同一位置的观测。

**Retrospective Transmit Beamforming（RTB，回顾性发射波束合成）** 利用这些记录：采集完成以后，为更多像素重新计算每次 Tx 的接收 DAS，再组合对同一像素有效的 Tx 贡献。它不会改变已经发出的声波。

之所以称为“发射波束合成”，是因为最终像素的相干组合也发生在不同发射事件之间：先在每次 Tx 内完成接收聚焦，再把各次 Tx 对同一位置的响应对齐并组合。组合的是不同发射事件记录下来的回波观测。

![Conventional 与 RTB 的重建关系](figures/conventional_vs_rtb.png)

**图 4｜左边按线输出，右边按像素组合。** Conventional 为每次 Tx 输出中心线；RTB 在统一网格中重建像素。同一个 $P$ 可以同时使用多个 Tx。彩色箭头表示计算贡献，图为 AI 概念插画。

#### 4.1 第一步：让一次 Tx 重建一片像素

仍然计算 $S_t(P)$，但不再把 $P$ 限定在当前 Tx 的中心线上。对于周围允许参与的像素，也计算它们各自的 Tx/Rx 时间，再沿 Rx 相干求和。

哪些像素可以参与，由当前 Tx 的 **support（参与范围）** 与权重 $w_t^{\mathrm{Tx}}(P)$ 描述。范围外的权重为零，范围内可采用平坦或渐变权重。这个范围是传播与照射的重建近似，其具体参数在第 10 节说明。

#### 4.2 第二步：让多个 Tx 重建同一个像素

固定同一个 $P$，收集不同 Tx 得到的 $S_1(P),S_2(P),\ldots$。这些结果仍是复数，需要在共同的空间位置和时间参考下跨 Tx 相干组合。

本项目先计算加权和，再按 Tx 权重和归一化：

$$ C(P)=\sum_t w_t^{\mathrm{Tx}}(P)S_t(P),\qquad W(P)=\sum_t w_t^{\mathrm{Tx}}(P). $$

$$ Y_{\mathrm{RTB}}(P)=\frac{C(P)}{W(P)},\qquad W(P)>0. $$

没有有效 Tx 贡献时，输出置零。除以 $W$ 是本章基线采用的幅值归一化方式；RTB 的核心则是前面的**跨 Tx 相干加权**。

为什么要除以权重和？假设两次 Tx 对同一像素都得到相同复数响应 $a$，权重都为 1：分子为 $2a$，分母为 2，结果仍为 $a$。这样可减少“参与次数不同”带来的幅值比例变化。如果两个响应为 $a$ 和 $-a$，结果依然是零，归一化无法修复相位不一致。

#### 4.3 一次看懂 Tx 与 Rx 各选什么

![Tx support 与 Rx aperture](figures/tx_rx_apertures.png)

**图 5｜Tx 选像素，Rx 选阵元。** 左图描述一次发射允许参与的空间范围；右图描述为了重建某个像素而选取的接收阵元。AI 图示意有限 Tx 腰部和随深度变化的 Rx aperture，不是实测声场。

因此，RTB 有两层相干组合：

| 层次 | 固定什么 | 组合什么 | 得到什么 |
|---|---|---|---|
| 接收 DAS | 当前 $P$ 和当前 Tx | 不同 Rx 的观测 | 当前 Tx 的复数响应 $S_t(P)$ |
| RTB 跨发射组合 | 当前 $P$ | 不同 Tx 的 $S_t(P)$ | 最终复数像素 $Y_{\mathrm{RTB}}(P)$ |

实际实现可以按像素收集 Tx，也可以按 Tx 依次更新整幅图。本仓库选择后者：每次 Tx 处理其 support 内的像素，将结果累计到统一网格。组合完成以后，才取包络和 dB，顺序与 conventional 相同。

把 RTB 的完整流程连起来看：

~~~mermaid
flowchart LR
    A[一次 Tx 的多条 Rx 波形] --> B[该 Tx support 内的像素]
    B --> C[逐像素计算 Tx 和 Rx 时间并取样]
    C --> D[沿 Rx 相干求和]
    D --> E[乘 Tx 权重并累计到统一网格]
    E --> F[遍历 Tx 后除以各像素的 Tx 权重和]
    F --> G[包络与 dB 显示]
~~~

### 5. 把两种算法放回同一条主线上

两种方法共享“预测传播时间、通道取样、接收相干求和”。差别在于，在哪里执行这个构件，以及是否继续跨 Tx 组合：

| 问题 | 本章 conventional FI-DAS | 本章 RTB |
|---|---|---|
| 输入 | 多次聚焦发射的原始通道波形 | 同一份原始通道波形 |
| 一次 Tx 在哪里重建？ | 对应的中心扫描线 | 当前 Tx support 内的像素 |
| 一个像素使用几次 Tx？ | 对应的一次 Tx | 对该位置有效的多个 Tx |
| 是否沿 Rx 相干求和？ | 是 | 是 |
| 是否跨 Tx 相干组合？ | 本章基线不做 | 做 |
| 最后怎样显示？ | 复数结果 → 包络 → dB | 复数结果 → 包络 → dB |
| 新增计算要求 | 中心线的传播时间 | 离轴 Tx 时间、Tx support、跨 Tx 权重 |

**RTB 与图像插值的关系也因此清楚了。** 对 conventional 包络做插值，只使用已经形成的图像数值；RTB 重新访问 RF，为新像素计算传播时间，并组合多个 Tx 的相干响应。

RTB 提供更充分使用通道记录的重建方式，但输出网格更密，不自动等于物理分辨率更高。它的表现取决于传播模型、有效照射、孔径、采样和相位一致性；这些因素将在真实数据实验中逐个检查。

读到这里，先合上公式，尝试回答：**如何从一组 RF 得到一条 conventional 线？RTB 在哪两处扩展了这个过程？** 如果能顺着流程解释，就可以进入仓库实践了。


<a id="practice"></a>

## 第二部分：把原理落到本仓库

### 6. 先找到算法的输入：真实 UFF 通道记录

统一使用 `data/L7_FI_TheGB.uff`。文件的下载链接和 MD5 见 [数据说明](../../data/README.md)。现在读取它，是为了找到第一部分中的 Rx 波形、Tx 序号和传播几何。

在仓库根目录打开 MATLAB，设置 USTB 路径，然后进入本章代码目录：

~~~matlab
addpath(genpath('D:/USTB'));  % 换成自己的 USTB 路径
cd matlab/01_DAS_Real_UFF
filename = '../../data/L7_FI_TheGB.uff';
inspect_uff_hdf5
inspect_uff_metadata_ustb
wave_index = 64;  % 与本章通道配图保持一致
plot_raw_channel_overview_ustb
~~~

UFF 是数据容器；USTB 在这里负责读出波形、探头坐标与发射信息。接收 DAS 与 RTB 的核心计算由本项目显式实现。入口会清理部分工作区变量，建议使用独立 MATLAB 会话。

#### 6.1 把采集记录对应到四个数据维度

~~~matlab
channel_data.data(sample, channel, wave, frame)
%                  时间      Rx       Tx     帧
~~~

本次对默认文件的实际读取结果为：

| 项目 | 本次读取值 | 为什么要看 |
|---|---:|---|
| shape | `[1920,128,128,1]` | 1920 个样本、128 Rx、128 Tx、1 帧 |
| dtype / real | `single` / 实数 | 本章输入为 RF |
| sampling frequency | 20.833334 MHz | 延时如何映射到样本 |
| initial time | 0 s | 第一个样本对应的记录时间 |
| sound speed | 1540 m/s | 距离如何转换成时间 |
| modulation frequency | 0 Hz | 与实数状态一起确认 RF 语义 |
| pulse center frequency | 5.2083335 MHz | 采样误差对应的载波相位 |
| pitch | 约 0.298 mm | 阵列空间采样 |
| Rx 阵元中心范围 | 约 −18.923 到 +18.923 mm | 接收几何与最大孔径 |
| Tx focus depth | 约 29.568 mm | 焦点前后的发射模型 |
| `wave.delay` 范围 | 约 −1.895 到 +1.699 µs | 各次发射的时间参考并不相同 |

数值来自本次本地 UFF 读取，完整记录见 [MATLAB 运行输出](figures/matlab_all_results.txt)。

~~~matlab
rf_wave = channel_data.data(:,:,64,1);  % [1920,128]
trace = channel_data.data(:,32,64,1);   % [1920,1]
~~~

第一句取出一次发射的所有 Rx 通道；第二句只取其中一个通道。128 Rx 与 128 Tx 在这里恰好相等，物理意义仍完全不同。

#### 6.2 这里看到的还是通道波形

![第 64 次发射的原始 channel RF](figures/plot_raw_channel_overview_ustb_01.png)

![同一次发射在 25–34 微秒内的回波细节](figures/raw_channel_echo_zoom.png)

**图 6｜横轴是 channel，纵轴是记录时间。** 上图看完整记录，下图放大时间范围并缩窄对称色限，让较弱回波可见；色条都以完整记录峰值为单位，保留 RF 正负号。很早时刻的强信号压低了上图中较晚回波的颜色对比。它们还不是 B-mode 图。真实数据包含许多散射体与背景回波，因此整张图不会只有第 0 章那样的一条干净轨迹。

原始通道图使用 `axis xy`，时间向上增加；后面的 B-mode 图使用深度向下的显示方式。读图时先确认坐标轴。

### 7. 沿着同一条主线，先运行 conventional，再运行 RTB

#### 7.1 重建扫描线：对应第 3 节

输入是一次 Tx 的多条 Rx 波形，输出是沿深度排列的复数像素。先运行：

~~~matlab
das_fi_scanline_manual
~~~

核心是 [reconstruct_fi_scanline_manual.m](../../matlab/01_DAS_Real_UFF/reconstruct_fi_scanline_manual.m)，数据流为：

~~~matlab
rf_wave          % [sample,Rx]，实数 RF
analytic_wave    % [sample,Rx]，复数解析 RF
tau_total        % [1,Rx]，查询时间
focused_samples  % [1,Rx]，插值后的复数观测
weights          % [1,Rx]，接收权重
% sum(weights .* focused_samples) -> 一个复数像素
~~~

![本项目实现的真实 conventional FI-DAS 图像](figures/das_fi_scanline_manual_01.png)

**图 7｜第一次把真实 RF 变成 B-mode。** 深度向下，横轴为成像位置，色条为相对全图峰值的幅值 dB，显示范围 −60 到 0 dB。先找点状亮目标，再看背景和其他结构。传播模型、孔径与显示共同影响结果。

默认入口使用 full Rx aperture，横向有 128 条 scanline。输出 `das_analytic`、`envelope`、`image_db` 的 shape 都是 `[z,scanline]`，但对应不同处理阶段。

#### 7.2 扩展到 RTB：对应第 4–5 节

下一步使用同一份数据，对照 conventional、包络插值与 RTB。这个实验统一使用 Rx F# 1.7；上一步直接入口的默认设置为 full Rx，因此不同实验的图不能直接混作同一孔径条件。

运行 `compare_conventional_vs_rtb`：

![Conventional、包络插值与 RTB 的真实图像](figures/compare_conventional_vs_rtb_01.png)

![三种方式下同一目标的横向剖面](figures/compare_conventional_vs_rtb_02.png)

**图 8｜看数据入口，再看显示是否平滑。** 第一张是 scanline 输出；第二张对已形成的 conventional **包络**做横向插值；第三张重新查询 RF 并计算新像素的 Tx/Rx delay。三者保持相同 Rx F-number，图像各按自身峰值归一化。

| 操作 | 重新访问 RF | 新像素传播时间 | 新增跨 Tx 相干组合 |
|---|---|---|---|
| conventional 包络插值 | 否 | 否 | 否 |
| RTB | 是 | 是 | 是 |

对应第一部分的算法，第二张只插值已形成的包络，第三张重新执行传播时间查询和跨 Tx 组合。实验采用 128 条 conventional 线与 512 个 RTB 横向像素；分辨率与采样怎样区分，集中见第 12 节。

#### 7.3 在代码里找到两层组合

| 核心入口 | 主要输出 | shape 与含义 |
|---|---|---|
| `reconstruct_fi_scanline_manual` | `das_analytic` | `[N_z,N_Tx]`，一列对应一次 Tx 的扫描线 |
| `reconstruct_fi_rtb_manual` | `rtb_analytic` | `[N_z,N_x]`，统一网格上的复数像素 |
| 两个核心入口 | `envelope`、`image_db` | 与各自复数图像同 shape，分别对应包络和显示 |

Conventional 核心逐 Tx、逐深度求接收 DAS；RTB 在此基础上扩大像素范围，并更新跨 Tx 的累计量。对照第 4 节的公式，阅读下面的流程伪代码：

RTB 核心是 [reconstruct_fi_rtb_manual.m](../../matlab/01_DAS_Real_UFF/reconstruct_fi_rtb_manual.m)，按 Tx streaming accumulation，不保存完整 `[z,x,Tx]` 立方体：

~~~matlab
for each Tx
    % [sample,Rx] -> 沿 sample 维构造解析 RF
    % 计算当前深度行的 Tx support
    % support 内计算 Tx + Rx 查询时间
    % 插值得到 samples：[active_pixel,Rx]
    single_tx_values = sum(rx_weights .* samples,2); % 沿 Rx 相加
    weighted_values = tx_weights .* single_tx_values;
    % 加入 coherent_sum
    % 累计 tx_weight_sum 与 active_tx_count
end
% 有效 pixel 除以 tx_weight_sum
% abs -> envelope -> 20log10 -> display clipping
~~~

两次相干组合：`sum(...,2)` 沿 Rx，逐次更新 `coherent_sum` 沿 Tx。两次都保留复数相位。输出 `rtb_analytic`、`envelope`、`image_db` 的 shape 为 `[z,x]`。

设置 `opts.inspect_wave_index` 可返回 `single_tx_unweighted`、`single_tx_weighted`、`single_tx_delay`。延时、权重与响应适合分开画图检查。

### 8. 检查重建是否按预期完成：与 USTB 对照

前两步得到图像，这一步检查显式实现是否与匹配条件下的 USTB 参考接近。两种算法分别有对照入口：

~~~matlab
validate_manual_vs_ustb
delay_model = 'blended';
validate_manual_rtb_vs_ustb
~~~

Conventional 对照使用相同数据、frame、网格、spherical Tx、full Rx 与 MATLAB 插值路径。RTB 对照使用相同网格、blended Tx、Tx support、Tukey25、Rx F-number 和 Tx 权重和归一化。

![Conventional Manual 与 USTB 并排图](figures/validate_manual_vs_ustb_01.png)

![Conventional 归一化包络差异](figures/validate_manual_vs_ustb_02.png)

**图 9｜检查 conventional 这条计算链。** 并排图看结构，差异图看线性包络偏差，色条显示实际误差量级。

![RTB Manual 与 USTB 并排图](figures/validate_manual_rtb_vs_ustb_01.png)

![RTB 归一化包络差异](figures/validate_manual_rtb_vs_ustb_02.png)

**图 10｜检查新增的跨 Tx 重建。** Conventional 接近参考，不能直接替代 RTB 的对照；后者还包含离轴时间和 Tx 权重。

随配图保存的这次运行得到：

| 对照 | 网格 [z,x] | 包络相关系数 | 归一化 RMSE | 最大绝对差 | 全局峰位置差 |
|---|---|---:|---:|---:|---|
| conventional / USTB | [512,128] | 0.999999583 | 2.73e-7 | 5.55e-6 | dx=0，dz=0 |
| blended RTB / USTB | [256,512] | 1.000000000（打印精度内） | 2.05e-7 | 5.24e-6 | dx=0，dz=0 |

完整参数和输出见 [配图索引](figures/README.md) 与 [运行记录](figures/matlab_all_results.txt)。这些结果支持当前条件下的实现一致性；怎样理解归一化、采样与物理准确性的边界，见第 12 节。

完成第二部分以后，你应该能把第一部分的每一步，指向一个数据维度、一个核心函数或一种输出。后面再逐项解释这些步骤中需要保持一致的约定。

<a id="implementation-notes"></a>

## 第三部分：主线掌握后，再检查这些细节

下面按计算链的顺序展开：先检查“去哪里取样”，再检查“哪些观测参与”，最后检查“怎样解释输出”。第一次读理论时不必同时记住所有参数；需要运行和定位差异时，回到对应环节即可。

### 9. 从传播时间到 RF 样本：时间参考、插值与相位

第一部分用几何时间讲原理；真正查询 UFF 波形时，需要把它转换到采集记录的时间轴。这里的约定对应算法中的“按预测时刻取样”。

#### 9.1 几何时间与记录时间，只转换一次

本项目使用不含逐 Tx 偏置的公共记录时间轴：

$$ \tau_{\mathrm{axis}}[n]=t_0+\frac{n-1}{f_s},\qquad n=1,\ldots,N_{\mathrm{samples}}. $$

USTB 的 `channel_data.time(t)` 已经包含该次发射的 `sequence(t).delay`。两种约定都可以一致使用：

| 记录时间轴 | 几何查询时间 | 用法 |
|---|---|---|
| $t_0+(n-1)/f_s$ | $\tau_{\mathrm{geom}}-\mathrm{wave.delay}$ | 本章 Manual core |
| $t_0+(n-1)/f_s+\mathrm{wave.delay}$ | $\tau_{\mathrm{geom}}$ | 使用逐 wave 的 USTB 时间轴 |

选择第一行时，在查询时间里减 `wave.delay`；选择第二行时不再重复减。两行最终查到同一个样本位置。

![阵元与发射焦点坐标，以及逐发射时间偏置](figures/demo_fi_geometry_and_sampling_01.png)

**图 11｜几何和时间偏置都要实际读取。** 左图显示探头与焦点位置，右图显示 `wave.delay` 随 Tx 的变化。偏置达到微秒量级，远大于一个 RF 周期；忽略它会明显改变取样位置。

#### 9.2 把焦点参考时间写成 UFF 变量

第一部分的 $T_{f,t}$，在本章采用的 USTB 模型中对应 $R_f/c_t$；其中 $R_f$ 直接取 `wave.source.distance`。记 $d_F(P)=\sqrt{(x-x_f)^2+(z-z_f)^2}$，下面给出 spherical 几何与记录时间转换的完整表达。

在本章的 spherical 约定下：

$$ d_s(P)=\begin{cases}-d_F(P),&z<z_f,\\+d_F(P),&z\ge z_f.\end{cases} $$

$$ \boxed{\tau_{\mathrm{Tx}}(P)=\frac{R_f+d_s(P)}{c_t}-\mathrm{wave.delay}},\qquad R_f=\mathrm{wave.source.distance}. $$

$c_t$ 对应 `wave.sound_speed`；本次文件中它与 `channel_data.sound_speed` 都为 1540 m/s。

**source.distance 要读取，不要自行替换为 $z_f$ 或 origin-to-focus 距离。** 它是 USTB source 的参考距离；不同 Tx 的值并不完全相同。用实际元数据才能与库中的时间约定一致。

在当前垂直中心线上，焦点前后都有 $d_s=z-z_f$，所以两侧都化为：

$$ \tau_{\mathrm{Tx}}=\frac{R_f+z-z_f}{c_t}-\mathrm{wave.delay}. $$

因此中心线经过焦点时，没有这个符号规则造成的跳变。离轴像素更复杂，留到第 11 节。

实际核心还读取阵元的三维坐标，在 $y=0$ 的成像平面计算接收时间：

$$ \tau_{\mathrm{Rx},m}(P)=\frac{\sqrt{(x-x_m)^2+y_m^2+(z-z_m)^2}}{c}. $$

~~~matlab
tau_tx = ...;                       % 标量，s，已换到公共记录参考
tau_rx = rx_distance / sound_speed; % [1,Rx]，s
tau_total = tau_tx + tau_rx;        % [1,Rx]，用于通道查询
~~~

内部使用 m、s、Hz。对 20 mm 附近的中心像素，总查询时间在数十微秒量级；数量级检查能帮助发现单位错误。

#### 9.3 从非整数样本位置取样

将查询时间转换为 MATLAB 的连续样本位置：

$$ u_{m,t}=(\tau_{m,t}-t_0)f_s+1,\qquad i=\lfloor u_{m,t}\rfloor,\qquad \beta=u_{m,t}-i. $$

线性插值为：

$$ v_{m,t}(\tau_{m,t})\approx(1-\beta)v_{m,t}[i]+\beta v_{m,t}[i+1],\qquad 0\le\beta<1. $$

例如 $u=3.35$，使用第 3、4 个样本，权重为 0.65、0.35。最近邻只取第 3 个样本。

![非整数位置的最近邻、线性插值与原始正弦波](figures/demo_fi_geometry_and_sampling_04.png)

**图 12｜插值是明确的数值近似。** 灰线是已知的教学正弦波，圆点按默认数据的 $f_s,f_c$ 采样，红方块为线性查询，黑十字为精确值。线性插值避免取整，但仍可能有幅值误差。此图不是组织回波。

本数据每个载波周期约 4 个样本。一采样周期对应约 90° 相位，最近邻的半样本误差可达到约 45°，因此插值直接影响相干求和。

核心函数只对 $1\le i<N_{\mathrm{samples}}$ 的查询取样，其余返回零并取消对应接收权重。`n_out_of_range / n_requested` 用来判断是否大量查询落在记录之外。零值不能代替正确的时间模型。

#### 9.4 用真实数值走一遍时间、索引与取样

取本次文件的 wave 64，在它的中心线上查询一个深度 20 mm 的候选像素，并使用附近的 Rx 64。以下数值按实际 metadata 四舍五入：

| 步骤 | 代入 / 结果 | 对应代码 |
|---|---|---|
| 焦点与时间参考 | $x_f\approx-0.14899$ mm，$z_f\approx29.568$ mm；$R_f\approx29.568376$ mm；`wave.delay` 约 −1.895459 µs | `wave.source`、`wave.delay` |
| Tx 查询时间 | $\tau_{\mathrm{Tx}}\approx14.883$ µs；焦点前用负距离，最后减去负的 `wave.delay` | `tau_tx` |
| Rx 返回时间 | Rx 64 与像素几乎同一横坐标，$\tau_{\mathrm{Rx}}\approx\frac{20\times10^{-3}\ \mathrm{m}}{1540\ \mathrm{m/s}}\approx12.987$ µs | `tau_rx` |
| 总查询时间 | $\tau\approx27.870$ µs | `tau_total` |
| 连续样本位置 | $u\approx581.62$，不是整数 | `(tau_total-t0)*fs+1` |
| 插值 | 第 581、582 个样本的权重约为 0.38、0.62 | `i`、`beta` |

这个例子只算了一个像素、一个通道。对其余 Rx 重复并相干求和，才得到该像素；对更多深度重复，才得到整条 scanline。查询时间落在图 6 的放大范围内，你可以先在那里找对应的 RF 振荡。

#### 9.5 解析 RF 的构造属于取样前的信号准备

本章沿原始数据的时间维做 FFT：保留 DC，正频率加倍，负频率置零；偶数长度保留 Nyquist 项，再逆变换得到解析 RF：

$$ v_a(\tau)=v(\tau)+j\mathcal H\{v(\tau)\}. $$

这是保留载频的复数解析信号，仍与原始 RF 处于同一采样时间轴；它不是已经解调的基带 IQ。通道插值与两层相干组合都保留复数，最后才 `abs`。如果将来换成基带 IQ 输入，需要重新确认调制与相位补偿约定。

### 10. 哪些观测参与：接收孔径、Tx support 与权重和

这一节对应第一部分的两个权重：$w_m^{\mathrm{Rx}}$ 决定选哪些阵元，$w_t^{\mathrm{Tx}}$ 决定选哪些发射贡献。先看接收端，再看跨 Tx 的参与范围。

#### 10.1 接收 F-number

运行 `compare_receive_aperture_full_vs_fnumber`，只改变 Rx aperture：

$$ F\#_{\mathrm{Rx}}=\frac{z}{D_{\mathrm{Rx}}},\qquad D_{\mathrm{Rx}}(z)=\frac{z}{F\#_{\mathrm{Rx}}}. $$

选择满足 $|x_m-x|\le D_{\mathrm{Rx}}/2$ 的阵元。固定 F-number 时，浅层阵元较少，深层更多，最后受阵列边界限制。

![Full Rx 与 F-number 下的目标横向响应](figures/compare_receive_aperture_full_vs_fnumber_03.png)

**图 13｜比较同一目标的主瓣与两侧响应。** 剖面各按自己的目标峰值归一化。一般而言，减小有效孔径会展宽横向主瓣；真实背景、Tx 声场与粗采样也会影响本次曲线。

代码使用 boxcar Rx 权重，Rx sum **没有除以有效阵元数**。孔径改变也会改变幅值，不能把各自归一化的图解读为绝对增益相同。`active_channel_count` 用于核对每个像素用了多少 Rx。

#### 10.2 Tx support 的数值定义

第 4 节用有限宽度的照射范围解释 Tx support。代码用下面的 beam-local 几何和窗函数近似它：

在以焦点为参考的 beam-local 坐标 $(x',z')$ 中：

本章垂直发射时，$x'=x-x_f$、$z'=z-z_f$，即像素相对于当前 Tx 焦点的横向、轴向位置。下面的宽度因此围绕焦点变化，而不是直接用探头到像素的深度 $z$。

$$ z_{\mathrm{eff}}=\max(|z'|,D_{\min}F\#_{\mathrm{Tx}}),\qquad r=\frac{F\#_{\mathrm{Tx}}|x'|}{z_{\mathrm{eff}}}. $$

boxcar 选 $r\le0.5$；`tukey25` 在中心平台之外渐变到零。完整 support 宽度：

$$ D_{\mathrm{support}}=\max\!\left(\frac{|z'|}{F\#_{\mathrm{Tx}}},D_{\min}\right). $$

`tx_min_aperture=3e-3` 表示模型中 support 的最小全宽，不能直接解释成硬件发射孔径。没有下限，几何模型会在焦点收缩到零宽度。

![代码定义的 Tx 权重与 Rx 选择范围](figures/demo_fi_geometry_and_sampling_03.png)

**图 14｜概念图之后，用数值图核对。** 左侧是近中心 Tx 的 Tukey 权重，右侧是中心像素线的 Rx 选择。左图横轴是 pixel 位置，右图横轴是阵元位置。相同单位，却选择不同对象。

| 参数 | 默认值 | 控制什么 |
|---|---:|---|
| `tx_f_number` | 2 | Tx support 的张开程度 |
| `tx_min_aperture` | 3 mm | 焦区 support 的最小宽度 |
| `tx_window` | `tukey25` | Tx support 边缘权重 |
| `rx_f_number` | 1.7 | 各像素接收孔径宽度 |
| `x_upsample` | 4 | 输出横向采样点数 |

support 是重建近似，并非扫描器完整声场测量。扩大 support 不会凭空产生有效照射的信息。

#### 10.3 Tx 权重和归一化与 coverage 诊断

代码累计复数贡献与权重：

$$ C(P)=\sum_t w_t^{\mathrm{Tx}}(P)S_t(P),\qquad W(P)=\sum_t w_t^{\mathrm{Tx}}(P). $$

然后用 $C/W$ 形成 RTB。若各 Tx 的相干响应近似相同，除以 $W$ 能消除重复次数引起的增益变化；若相位不一致，分母无法修复相消。

![每个 RTB 像素参与重建的 Tx 次数](figures/compare_conventional_vs_rtb_03.png)

**图 15｜这是 coverage 诊断，不是 B-mode。** `active_tx_count` 数权重大于零的 Tx，`tx_weight_sum` 累计权重，两者不同。覆盖较少或权重和很小的区域值得单独检查。

归一化只处理 Tx-overlap。Rx 权重和、真实发射声压、衰减和系统增益仍影响亮度，它不是完整深度增益校正。

<a id="tx-delay-models"></a>

### 11. 离轴 Tx 时间：先识别模型差别，再看焦区现象

第 4 节让一次 Tx 重建中心线周围的像素。接收距离容易按阵元坐标计算，新增的难点是：怎样估计聚焦发射经过离轴像素的时间？下面只讨论这一项，其余 DAS 与跨 Tx 组合步骤保持不变。

#### 11.1 Spherical：焦点参考与离轴符号跳变

spherical path 为第 9 节的 $L_{\mathrm{sph}}=R_f+d_s(P)$。中心线上等价于 $R_f+z-z_f$。离轴时，在焦深两侧的极限不同：

$$ L_{\mathrm{sph}}(z_f^-)=R_f-|x-x_f|,\qquad L_{\mathrm{sph}}(z_f^+)=R_f+|x-x_f|. $$

$$ \Delta\tau_{\mathrm{jump}}=\frac{2|x-x_f|}{c_t}. $$

横向偏离 1 mm、声速 1540 m/s 时，跳变量约 1.30 µs。这是简化模型的符号切换；真实声场不会因像素越过一个深度平面就突然跳变。

#### 11.2 Plane：用轴向参考绕开这个跳变

当前 linear scan 的局部 plane path：

$$ L_{\mathrm{plane}}(P)=R_f+z-z_f. $$

同一深度得到相同 Tx 时间。它在焦区提供另一种近似，绕开上述正负切换；全图采用则忽略离轴曲率。

不能用“焦点附近球面很大，因此很平”解释它。几何球面靠近球心时曲率反而很大；这里是**焦区传播的近似模型**，需要数据与参考评估。

#### 11.3 Blended：先看权重究竟怎么计算

本仓库与本次 USTB 版本使用：

$$ \rho(P)=\sqrt{x^2+z^2},\qquad q(P)=\min\!\left(\frac{|R_f-\rho(P)|}{R_f},1\right),\qquad \alpha(P)=q(P)^p. $$

$$ L_{\mathrm{blend}}(P)=\alpha(P)L_{\mathrm{sph}}(P)+[1-\alpha(P)]L_{\mathrm{plane}}(P). $$

$$ \tau_{\mathrm{Tx}}(P)=L_{\mathrm{blend}}(P)/c_t-\mathrm{wave.delay}. $$

~~~matlab
pixel_radius = sqrt(x.^2 + z.^2);
q = min(abs(wave.source.distance - pixel_radius) ...
    / wave.source.distance, 1);
alpha = q .^ opts.blending_power;
path_length = alpha .* spherical_path + (1-alpha) .* plane_path;
~~~

默认 $p=0.5$。$\alpha$ 小时 plane 更重要，$\alpha$ 大时 spherical 更重要。**权重依赖全局原点距离 $\rho$，并非只依赖 $|z-z_f|$ 或 pixel-to-focus 距离。** 公式依据 [对应版本的 USTB DAS 源码](https://github.com/unioslo/USTB/blob/86126eb7cab8b6009d14f2d448e85eeb8a86f61c/%2Bmidprocess/das.m)。

![中心线与离轴位置的三种 Tx 时间模型](figures/demo_fi_geometry_and_sampling_02.png)

**图 16｜先看左侧重合，再看右侧差异。** 纵轴减去共同的焦点参考时间。中心线上三条曲线重合；横向偏离 1 mm 时，spherical 有明显跳变，plane 没有，blended 减小了其影响。曲线来自元数据与公式，不是声场测量。

本次近中心 Tx 的 1 mm 离轴位置，spherical 极限跳变量约 **1299 ns**，blended 约 **26 ns**。后者画在微秒坐标里很小，仍不能据此把延时误差当成零。

$\alpha$ 连续变化，不代表最终延时处处连续。若焦深处 $\alpha_f\ne0$，blended 仍有 $2\alpha_f|x-x_f|/c_t$ 的极限跳变。准确说法是“用连续权重混合两种近似”，不能保证所有焦区伪影消失。

`hybrid` 则在 $|z-z_f|\le\mathrm{pw\_margin}$ 的区域直接用 plane，外部用 spherical。硬切换可能把接缝移到替换带的边界，适合与 blended 对照。

#### 11.4 必跑：只换 Tx delay model

~~~matlab
compare_rtb_spherical_plane_blended
~~~

![三种 Tx delay model 的完整 RTB 图像](figures/compare_rtb_spherical_plane_blended_01.png)

![三种模型在焦点深度附近的放大对比](figures/compare_rtb_spherical_plane_blended_03.png)

**图 17｜先看全图，再看约 29.568 mm 的焦区。** 同一数据、网格、Tx/Rx support、插值和 normalization，只改变 Tx delay model。各图按自己的峰值归一化，看形态；公共峰值图另存于配图目录，用于观察幅值差。

![Spherical 与 Plane 相对 Blended 的包络差异](figures/compare_rtb_spherical_plane_blended_04.png)

**图 18｜difference 表示模型差异，不是相对真值的误差。** Blended 这里只是比较参考。更接近 blended，不等于更接近真实声场。

> 课件提问：中心线上三种模型重合，为何整张图仍不同？答：RTB 使用离轴像素；同一像素对不同 Tx，可能各处于不同的离轴位置。

### 12. 怎样解释图像变化：显示、PSF 与验证边界

算法已明确以后，图像还会随显示基准、采样网格与模型改变。这里把相关注意事项集中放在一起，避免把这些变化都归因于“算法更好”。

#### 12.1 先说明显示使用哪个幅值参考

同一个包络可以用不同 $A_{\mathrm{ref}}$ 转换为 dB：

- 各自峰值归一化用于比较形状，会隐藏整体增益差。
- 公共峰值归一化用于比较相对幅值，仍要注意色限和 clipping。
- 局部 PSF 剖面以该目标峰值归一化，宽度在未裁剪线性包络上计算。

本章 B-mode 显示 −60 至 0 dB。三模型的公共参考图以 blended peak 为基准，大于 0 dB 的部分也被裁剪。其差异图显示模型之间的归一化包络差异，并不是对独立真值的误差。

#### 12.2 再用一个目标理解横向、轴向与采样

理想点散射体经过成像系统后不会只占一个像素，其扩展响应称为点扩散函数（Point Spread Function，PSF）。观察点状目标的横向、轴向剖面，可以帮助理解图像如何区分相邻位置；真实目标是否足够接近理想点，则要另外确认。

运行 `analyze_point_target_psf`，先选择相对孤立的点状目标，脚本在附近找局部峰。本次检查图 7 后，选择约 $(-0.75,20.05)$ mm 作为搜索起点。可以非交互复现：

~~~matlab
target_x_mm = -0.75;
target_z_mm = 20.05;
analyze_point_target_psf
~~~

![所选目标的局部图像](figures/analyze_point_target_psf_04.png)

![所选目标的横向剖面](figures/analyze_point_target_psf_02.png)

![所选目标的轴向剖面](figures/analyze_point_target_psf_03.png)

**图 19｜先看目标，再看穿过峰的两个剖面。** 横向剖面改变 $x$，轴向剖面改变 $z$；轴向图的横轴画的是深度。−6.0206 dB 虚线对应幅值 0.5，竖线标出半幅交点。

本次 full-aperture、1024 深度点结果：

| 量 | 本次值 | 解读 |
|---|---:|---|
| 局部峰 | $x\approx-0.745$ mm，$z\approx20.054$ mm | 图像峰，不是独立物理真值 |
| 横向步长 | 0.297981 mm | conventional scanline 间距 |
| 轴向步长 | 0.039101 mm | 重建深度网格 |
| 横向半幅宽度 | 约 0.4197 mm | 仅跨约 **1.41** 个横向间隔，受采样强烈限制 |
| 轴向半幅宽度 | 约 0.4461 mm | 跨约 **11.41** 个深度间隔，采样相对充足 |

本次分析没有使用独立的 phantom point ground truth，所选亮点也未被校准为理想点散射体。这里测的是所选 point-like object 的图像响应，真实目标尺寸、背景和系统响应都会影响宽度。

**很多小数位不代表高精度。** 用交点插值能给出宽度，却不能补回粗采样丢失的形状。幅值 FWHM 是 −6.02 dB；功率减半是 −3.01 dB，定义要写清。

#### 12.3 最后限定对照结论

第 8 节的相关系数、MAE / RMSE、最大误差与峰位置应一起读。包络相关性高，不说明每个像素或复数相位完全相同；各自峰值归一化也会消除整体比例差。

与 USTB 接近，支持匹配条件下的实现一致性。两者共享的传播近似，还需要独立物理证据。运行成功、图像合理、实现一致、物理准确和任务效果，并不能相互替代。

输出网格更密也不自动证明分辨率提升。第 7 节的包络插值、RTB 和第 12 节的 PSF，要结合重建条件、采样支撑、主瓣、两侧响应与背景一起判断。相邻 Tx 的运动或不一致时间参考还可能破坏相干性；本章静态重建未做运动补偿。

### 13. 按计算链修改参数，一次验证一个解释

~~~matlab
experiment = 'delay_model';
experiment_rtb_parameter_sweep
~~~

| `experiment` | 运行前写下预测 |
|---|---|
| `delay_model` | spherical / hybrid / blended 的差异集中在哪？ |
| `x_upsample` | 哪些变化只是网格采样变化？ |
| `tx_fnumber` | F-number 更大，Tx support 更窄还是更宽？ |
| `tx_min_aperture` | 最小宽度增大，焦区参与的 Tx 怎么变？ |
| `pw_margin` | hybrid 替换带扩大后，接缝可能移到哪里？ |
| `rx_fnumber` | Rx F-number 更大，孔径和主瓣怎么变？ |
| `wave_stride` | 减少 Tx 后，coverage 与相干增益怎么变？ |
| `blending_power` | $0<q<1$ 时，增大 $p$ 让 $\alpha=q^p$ 怎么变？ |

最后一项中，$p$ 越大，$\alpha$ 越小，plane 占比越高。`pw_margin` 只影响 hybrid，`blending_power` 只影响 blended。改当前模型不用的参数，结果可能不变。

先用较低 `n_z` 看全图趋势；量化轴向 PSF 时再提高深度采样。每次只改一个变量，记录数据、frame、grid、model 和显示范围。

重新生成课程配图可运行：

~~~matlab
export_chapter1_figures                 % 全部实验和 reference
export_chapter1_figures('experiments')  % 实验图
export_chapter1_figures('references')   % reference 图
~~~

导出入口给定目标搜索起点，不需后台点击；同名 MATLAB 图与运行记录会更新。AI 插画不由该入口生成。分项导出、运行环境和完整参数见 [配图索引](figures/README.md)。

## 自测：先会讲完整流程，再会解释实现细节

**只读完第一部分，先回答这六题：**

1. 聚焦发射已经完成，为什么接收端仍要做波束合成？
2. 重建一个像素时，为什么要同时算 Tx 和 Rx 时间？
3. Conventional 的“一发一线”，怎样扩展成整张图？
4. 固定发射焦点与动态接收聚焦有什么区别？
5. RTB 的两层相干组合，分别沿哪个维度进行？
6. RTB 与对 conventional 包络做插值，数据入口有什么区别？

**完成实践与第三部分后，再回答这六题：**

7. UFF 中两个 128 分别表示什么？公共时间轴为何要在查询时间中减 `wave.delay`？
8. `u=(tau-t0)*fs+1` 中，`t0` 和 `+1` 分别来自哪里？
9. Tx support、Rx aperture、Tx 权重和归一化分别控制哪一步？
10. Blended 权重连续，为什么仍可能有离轴延时跳变？
11. FWHM 仅跨 1.4 个 scanline 间隔，应怎样报告？
12. 与 USTB 接近，能说明什么，还不能说明什么？

<details>
<summary>展开参考思路</summary>

1. 发射聚焦完成照射；接收仍需对齐并组合来自候选位置的多通道回波。
2. 声波先到达像素，再从像素返回阵元，两段共同决定查询时刻。
3. 一次 Tx 遍历中心线深度得到一列，再按 Tx 横向位置排列所有列。
4. 发射焦点由采集设置决定；接收延时随候选像素的深度改变。
5. 先沿 Rx 得到单次 Tx 的响应，再跨 Tx 组合该像素的多个响应。
6. 包络插值使用已有图像；RTB 回到 RF，重新计算传播时间和相干组合。
7. 分别是 Rx channels 与 Tx waves；时间参考转换只能计一次。
8. 记录起始时间，以及 MATLAB 从 1 开始的索引。
9. 分别选空间像素、接收阵元，以及调整跨 Tx 累计的幅值比例。
10. Spherical 有离轴符号跳变，切换处 spherical 权重不为零时仍有残余跳变。
11. 报宽度与采样支撑，说明是粗估，不能把小数位当成精度。
12. 支持当前匹配条件下的实现一致性，不能独立证明声场模型精确或任务效果更优。

</details>

## 术语回查

第一次遇到的术语已在主线中解释，复习时可以查这张表：

| 术语 | 对应主线中的对象 |
|---|---|
| Tx / wave | 一次发射事件，不是一个接收阵元 |
| Rx / channel | 一个接收通道的时间序列 |
| pixel | 正在重建的候选空间位置 $P$ |
| scanline | Conventional 图像中沿深度排列的一列 |
| focus / virtual source | 聚焦发射的参考位置，不等于真实散射体 |
| aperture | 孔径；本章 Rx aperture 指参与接收的阵元范围 |
| support | 当前 Tx 模型允许参与的像素范围 |
| analytic RF | 保留载频、幅值与相位的复数解析信号 |
| envelope | 相干组合完成后的幅值 |
| UFF / USTB | 数据容器 / 读取与参考计算工具 |

## 课件讲解顺序与延伸阅读

先用概念图讲完整算法，再用 MATLAB 图落地，最后选择实现细节进行精讲。无需在第一轮讲解中穿插全部参数。

| 讲解轮次 | 图片与内容 | 学生应建立的理解 |
|---|---|---|
| 第一轮：完整理论 | 图 1 → 2 → 3 → 4 → 5，第 5 节对比表 | 输入是什么；单像素怎样重建；conventional 与 RTB 怎样组织计算 |
| 第二轮：真实重建 | 图 6 → 7 → 8 | 找到通道记录；得到第一张图；比较插值与 RTB |
| 第二轮：实现对照 | 图 9、10 | 用匹配条件下的 reference 检查计算 |
| 第三轮：取样细节 | 图 11、12 | 时钟参考和非整数查询如何对应到代码 |
| 第三轮：参与范围 | 图 13、14、15 | Rx 孔径、Tx support 与 coverage 各说明什么 |
| 第三轮：发射模型 | 图 16、17、18 | 离轴 Tx 时间为何重要，焦区模型怎样不同 |
| 第三轮：结果解释 | 图 19 | 区分目标响应、采样精度与物理分辨率 |

全部原图、提示词、参数和导出命令见 [配图与课件索引](figures/README.md)。

本章核心面向二维线性阵列、正深度 focused virtual source 与实数 RF。基带 IQ、扇扫、运动目标和完整声场模拟需要对应模型与处理。

- [USTB 对应版本的 DAS 源码](https://github.com/unioslo/USTB/blob/86126eb7cab8b6009d14f2d448e85eeb8a86f61c/%2Bmidprocess/das.m)：本章 Tx 模型与时间约定依据。
- [USTB 对应版本的 RTB example](https://github.com/unioslo/USTB/blob/86126eb7cab8b6009d14f2d448e85eeb8a86f61c/publications/IUS2018/Rindal_et_al_ASimpleArtifactFreeVirtualSourceModel/Proceedings_FI_UFF_Verasonics_RTB_delay_models.m)：RTB 参数与流程。
- Rindal、Rodriguez-Molares 与 Austeng，2018：[A Simple, Artifact-Free, Virtual Source Model](https://doi.org/10.1109/ULTSYM.2018.8579944)。论文讨论焦深 virtual-source artifact 与 hybrid 近似；本章 blended 公式以链接代码版本为准。

下一章沿着本章的接收 DAS 继续：通道经过几何对齐以后，是否都足够相干？**Coherence Factor（CF）与 Generalized Coherence Factor（GCF）** 将用对齐后的通道观测度量和利用相干性。
