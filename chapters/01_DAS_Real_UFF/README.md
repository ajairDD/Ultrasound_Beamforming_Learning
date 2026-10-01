# 第 1 章：在真实 UFF Channel Data 上实现 DAS

> 本章才是项目中真正的 **DAS 实现章**。  
> 第 0 章只负责建立共同基础和 synthetic intuition；本章开始使用真实 UFF channel data，自己写 MATLAB DAS baseline，并为后续 CF / MV / DMAS / SLSC / NSI 提供统一代码骨架。

---

## 1. 本章目标

完成本章后，应得到一套可重复使用的真实数据 DAS pipeline：

~~~text
UFF channel data
→ metadata / shape / unit validation
→ probe geometry
→ transmit sequence
→ imaging grid
→ Tx delay
→ Rx delay
→ sub-sample interpolation
→ aperture / apodization
→ coherent sum
→ envelope / log compression
→ PSF / image
→ quantitative validation
~~~

并且能够明确回答：

1. channel data 的 shape 是什么；
2. 每个 axis 的物理含义是什么；
3. 数据是 real RF 还是 complex IQ；
4. sampling frequency、initial time、sound speed 分别如何进入 delay；
5. 当前 acquisition 是 FI / PW / DW / STA 中哪一种；
6. Tx delay 应该怎样从真实 sequence 定义；
7. Rx delay 如何由 probe geometry 和 pixel geometry 计算；
8. interpolation 如何映射 fractional sample；
9. aperture / F-number / apodization 如何进入；
10. 最终图像的 envelope、normalization、dB 和 display dynamic range 如何定义。

---

## 2. 首选数据

本章第一套数据使用：

~~~text
data/L7_FI_Verasonics_CIRS_points.uff
~~~

原因：

- point-target 数据非常适合检查 delay；
- 容易观察 target localization；
- 可以量化 lateral / axial PSF；
- 适合测 FWHM 和 sidelobe；
- 比真实人体数据更容易判断实现是否科学正确。

数据来源、下载地址和 MD5 见：

**[data/README.md](../../data/README.md)**

> 不要只根据文件名假设数据内部维度、RF/IQ 状态或 sequence 细节。正式实现前必须实际读取并核对 UFF metadata。

---

### 2.1 在读取本地文件之前，官方资料已经确认的事实

以下内容来自 USTB 官方数据目录、该数据对应的 fDMAS 示例和当前 USTB DAS 源码；它们可以作为我们检查本地文件时的“先验”，但**不能替代对实际 UFF metadata 的读取**。

1. `L7_FI_Verasonics_CIRS_points.uff` 是 **channel data**，并与 USTB 的 TUFFC fDMAS publication example 关联。
2. USTB 官方对这组 L7 FI 数据按 **conventional scanline Focused Imaging** 处理：一个 transmit wave 对应一条 scanline。
3. 官方示例构造横向成像轴时使用：

~~~matlab
x_axis(n) = channel_data.sequence(n).source.x;
~~~

也就是说，`sequence(n).source.x` 是理解每条 focused transmit line 的关键字段。
4. USTB 官方 fDMAS 示例对这套数据使用：
   - `transmit_apodization.window = uff.window.scanline`
   - `receive_apodization.window = uff.window.none`
   - `receive_apodization.f_number = 1.7`
5. 当前 USTB `uff.channel_data` 明确定义数据轴为：

~~~text
[time × channel × wave × frame]
~~~

6. USTB 的信号语义为：
   - `modulation_frequency == 0`：RF；
   - `modulation_frequency ~= 0`：IQ / complex baseband。
7. `channel_data.time(n_wave)` 的时间轴包含：

~~~text
initial_time + sample_index / fs + sequence(n_wave).delay
~~~

因此后面自己实现 DAS 时，`wave.delay` **只能计入一次**。

官方参考：

- [USTB dataset catalog](https://unioslo.github.io/USTB/datasets.html)
- [该数据对应的 fDMAS example](https://github.com/unioslo/USTB/blob/master/publications/TUFFC/Prieur_et_al_Signal_coherence_and_image_amplitude_with_the_fDMAS/FI_UFF_delay_multiply_and_sum_Fig5_and_Fig6.m)
- [USTB `uff.channel_data`](https://github.com/unioslo/USTB/blob/master/+uff/channel_data.m)
- [USTB `midprocess.das`](https://github.com/unioslo/USTB/blob/master/+midprocess/das.m)

> 这里最重要的不是“照抄 USTB 参数”，而是用官方实现帮助我们解释 UFF 中每个字段的物理意义。真正的 DAS reconstruction 仍由本项目自己实现。

---
## 3. USTB 在本章中的角色

本章会使用 USTB，但要严格区分用途。

### USTB 用于

- 可靠读取 UFF 对象；
- 解析 channel_data；
- 读取 probe geometry；
- 读取 sequence / wave metadata；
- 必要时提供 reference result 做交叉验证。

### 本项目自己实现

- imaging grid；
- Tx delay；
- Rx delay；
- interpolation；
- receive aperture；
- apodization；
- coherent summation；
- envelope / log pipeline；
- PSF / metric extraction。

也就是说：

> **不会直接把 USTB 内置 DAS 当成本项目的 DAS 实现。**

否则我们虽然“得到了图”，却没有真正掌握算法。

---

## 4. 没安装 USTB 时能做什么

UFF 基于 HDF5。

如果还没安装 USTB，可以先运行：

~~~matlab
cd matlab/01_DAS_Real_UFF

filename = '../../data/L7_FI_Verasonics_CIRS_points.uff';
inspect_uff_hdf5
~~~

它只调用 MATLAB 自带的 HDF5 接口查看文件层次。

这个脚本适合回答：

- 文件是否能打开；
- 有哪些 group / dataset；
- 大致结构是什么。

但它**不会**试图自己重新实现完整 UFF object semantics。

真正进入 beamforming 前，仍推荐使用 USTB 读取语义对象。

---

## 5. 安装 USTB 后的第一步

将 USTB 放入 MATLAB path：

~~~matlab
addpath(genpath('D:/USTB'));
~~~

路径换成你自己的安装目录。

然后：

~~~matlab
cd matlab/01_DAS_Real_UFF

filename = '../../data/L7_FI_Verasonics_CIRS_points.uff';

inspect_uff_metadata_ustb
plot_raw_channel_overview_ustb
~~~

`inspect_uff_metadata_ustb` 现在会输出完整的真实数据契约，包括代表性 wave 的 `wavefront / source.xyz / origin.xyz / wave.delay / sound_speed`。

第一步不要急着写 beamformer。

先把数据契约确认清楚。

---

## 6. 本章的数据契约

正式 DAS 代码开始前，至少记录：

### channel data

- shape；
- axis order；
- real / complex；
- numeric class；
- number of samples；
- number of receive channels；
- number of waves；
- number of frames。

### timing

- sampling frequency；
- sampling interval；
- initial time；
- modulation frequency（如果存在）；
- sound speed。

### probe

- number of elements；
- element x / y / z coordinates；
- pitch；
- aperture geometry。

### sequence

- transmit type；
- number of waves；
- focus / source / steering information；
- transmit aperture；
- transmit timing definition。

只要这里还有未确认项，就不要把后面的 DAS 图当成“科学实现已经正确”。

---

## 7. 为什么真实 FI 的 Tx delay 不能直接照搬第 0 章

第 0 章 synthetic demo 使用的是：

> broadside plane-wave transmit

因此可以写：

$$
\tau_{\mathrm{TX}}=\frac{z}{c}.
$$

但本章首选数据是 **Focused Imaging**。

FI 的 Tx path 与实际 transmit focus / source / delay law 有关。

因此第 1 章最重要的第一项真实问题就是：

> **从 UFF sequence 中准确恢复当前 acquisition 的 Tx propagation model。**

这也是为什么第 0 章和第 1 章必须分开。

第 0 章教统一原理，第 1 章处理真实 acquisition 细节。

---

## 8. 本项目到底使用哪一套 DAS 代码？

### 8.1 主实现：我们自己写

第 1 章的 **主算法实现不是 USTB 内置 DAS，也不是 RTB**。

主文件：

~~~text
matlab/01_DAS_Real_UFF/das_fi_scanline_manual.m
~~~

USTB 在这个脚本里只负责：

~~~matlab
channel_data = uff.read_object(filename, '/channel_data');
~~~

从这一步以后，以下内容都由本项目显式实现：

- RF → analytic signal；
- focused-transmit virtual-source delay；
- receive propagation delay；
- fractional-sample linear interpolation；
- receive aperture；
- coherent receive summation；
- envelope / dB display。

这样做的原因是：如果直接调用 `midprocess.das()`，我们能得到图像，但对真正的 delay、sample index、wave.delay 和 aperture 数据流仍然缺少掌握。

### 8.2 USTB DAS：作为 reference，不作为黑盒主实现

等 manual DAS 在真实数据上跑通以后，会再生成一份 **匹配 grid / timing / aperture 的 USTB conventional DAS**，用于数值交叉验证。

因此关系是：

~~~text
Manual DAS     = 我们真正学习和维护的实现
USTB DAS       = reference / oracle-like cross-check
RTB            = conventional DAS 之后的 focused-transmit 扩展
~~~

> 即使 Manual DAS 与 USTB 图像很像，也还要继续检查 delay、shape、unit、peak location 和 PSF，而不是把“看起来一样”当作唯一验证。

---

## 9. Conventional scanline DAS 与 RTB 是什么关系？

### 9.1 Conventional scanline DAS

对于本章这套 Focused Imaging 数据，最基础的 conventional reconstruction 是：

~~~text
Tx wave 1 → scanline 1
Tx wave 2 → scanline 2
Tx wave 3 → scanline 3
...
~~~

横向位置直接由：

~~~matlab
x_line = sequence(i_wave).source.x;
~~~

给出。

每个 transmit wave 只负责它自己的输出 scanline；在该 scanline 上做 dynamic receive focusing 和 Rx coherent sum。

这就是 `das_fi_scanline_manual.m` 第一版实现的边界。

### 9.2 RTB：同一次 focused transmit 生成多条 retrospective lines

RTB（Retrospective Transmit Beamforming）仍然可以使用 DAS 做时间域 beamforming，但它不再限制为：

~~~text
1 transmit → 1 output line
~~~

而是允许：

~~~text
1 focused transmit
      ↓
对发射波场覆盖范围内的多个 candidate pixels / receive lines 重建
      ↓
邻近 focused transmits 的结果在相同 pixel 上进一步 coherent combination
~~~

因此 RTB 更接近一种 **focused-transmit synthetic-aperture / retrospective transmit focusing strategy**。

### 9.3 它们不是两种互斥的“Sum 算法”

二者最核心的区别发生在 **Tx dimension**：

| 项目 | Conventional FI-DAS | RTB-DAS |
|---|---|---|
| 输入 | focused channel data | 同一类 focused channel data |
| Rx delay | 动态计算 | 动态计算 |
| Rx sum | DAS | DAS |
| 一个 Tx 对应输出 | 通常 1 条 scanline | 多个 lateral pixels / lines |
| Tx waves 是否互相合成 | 基本不跨 Tx 合成 | 多个 Tx 可在同一 pixel coherent combine |
| Tx model | 只需本 scanline 的 focused-wave timing | 必须可靠描述 off-axis focused transmit wavefield |
| lateral sampling | 受 transmit line spacing 约束 | 可以比 transmit line spacing 更密 |
| 计算量 | 较低 | 明显更高 |

所以可以把它理解成：

$
\boxed{\text{RTB-DAS = DAS receive focusing + retrospective transmit-domain synthesis}}
$

而不是：

$
\text{RTB} = \text{一种完全不同于 DAS 的通道求和公式}.
$

### 9.4 为什么 RTB 的 Tx delay 更难

Conventional scanline reconstruction 只在每个 focused beam 自己的中心线附近使用该 transmit。

此时 virtual-source spherical model 在 scanline 上比较简单，而且 USTB 的 spherical / hybrid 模型在中心线上给出相同的几何路径。

RTB 则会把某个 focused transmit 用到离开其中心线的 pixels。

这时简单 spherical virtual-source model 可能在 transmit focus 附近产生不连续 / artifact。Nguyen & Prager 的 unified pixel-based model，以及 Rindal 等人的 hybrid virtual-source model，就是为这个问题提出的改进。

因此本项目的顺序是：

~~~text
Step 1  Conventional FI scanline DAS
        ↓
Step 2  与 USTB conventional DAS 交叉验证
        ↓
Step 3  明确 Tx dimension / receive dimension
        ↓
Step 4  RTB：一个 Tx 重建多条线 + 多 Tx coherent combination
        ↓
Step 5  比较 spherical / unified / hybrid Tx delay model
~~~

RTB 不会抢在 Step 1 前面。

---

## 10. 第一版 Manual DAS 的当前定义

`das_fi_scanline_manual.m` 当前采用以下明确约定：

- 只处理 conventional focused scanline FI；
- 一次只读取一个 wave，控制内存；
- 第一个版本只接受 RF 数据；
- 使用公共时间轴 `initial_time + (n-1)/fs`；
- `wave.delay` 在 Tx delay 中显式减去一次；
- Tx 使用 focused spherical virtual-source geometry；
- Rx 使用 pixel 到每个 probe element 的传播距离；
- interpolation 使用 linear fractional sampling；
- 默认 receive aperture 为 `full`，另提供显式 `f_number` boxcar 模式；
- coherent sum 后再取 envelope / dB。

默认 `full` receive aperture 是为了让第一版尽量少混入额外 window 变量。等它和 reference 核对正确后，再单独比较 full aperture 与 dynamic F-number aperture。

---
## 11. 计划中的 DAS 核心接口

本章后续实现会尽量保持数据流清楚，而不是一开始就追求高度抽象。

目标形式类似：

~~~matlab
% 1. Load channel data and metadata
channel_data = ...

% 2. Build imaging grid
x_axis = ...
z_axis = ...

% 3. For each pixel
for iz = 1:numel(z_axis)
    for ix = 1:numel(x_axis)

        % Tx propagation
        tau_tx = ...

        % Rx propagation for every element
        tau_rx = ...

        % Total delay
        tau = tau_tx + tau_rx;

        % Fractional sampling
        s = ...

        % Aperture + apodization
        w = ...

        % Coherent sum
        image_complex(iz, ix) = sum(w .* s);
    end
end
~~~

第一版优先保证：

- 公式和代码一一对应；
- shape 清楚；
- 单位清楚；
- 易调试；
- 易和第 0 章对应。

性能优化放在科学正确性之后。

---

## 12. 输出不是“一个 DAS 图”这么简单

最终至少要明确以下几个阶段：

~~~text
beamformed RF / complex signal
        ↓
envelope / magnitude
        ↓
normalization
        ↓
20log10(amplitude)
        ↓
display dynamic range
~~~

例如：

$$
B_{\mathrm{dB}}
=
20\log_{10}
\left(
\frac{A}{A_{\max}}
\right).
$$

必须区分：

- amplitude dB；
- power dB；
- envelope；
- log compression；
- display clipping。

否则两个算法很容易因为显示方式不同产生“看起来更好”的假象。

---

## 13. 本章验证标准

第 1 章不会以“程序跑通”为完成标准。

至少需要：

### A. 数据级验证

- shape / axis 正确；
- time vector 正确；
- element coordinates 正确；
- sequence 解析合理；
- real / complex 状态明确。

### B. 几何验证

- delay 随 element / pixel 的变化符合几何直觉；
- sample index 在合法范围；
- target depth / lateral position 基本正确。

### C. 图像级验证

点靶应能形成合理 PSF，并测量：

- lateral FWHM；
- axial FWHM；
- sidelobe；
- peak location。

### D. 参考验证

如果 USTB 能生成可对照的 conventional DAS：

- 使用同一数据；
- 尽量统一 grid；
- 尽量统一 aperture / apodization；
- 明确 normalization / envelope / dB 定义；

再比较结果。

> 与 USTB 结果“长得像”仍然不是唯一证据。必须同时检查 delay、shape、unit 和实现定义。

---

## 14. 当前已有代码

路径：

**[matlab/01_DAS_Real_UFF](../../matlab/01_DAS_Real_UFF/)**

当前已经提供：

### <code>inspect_uff_hdf5.m</code>

无需 USTB。

查看 UFF/HDF5 层次结构。

### <code>inspect_uff_metadata_ustb.m</code>

需要 USTB。

检查：

- channel data shape；
- RF/IQ 状态；
- sampling frequency；
- sound speed；
- initial time；
- probe；
- sequence。

### <code>plot_raw_channel_overview_ustb.m</code>

需要 USTB。

显示一组真实 channel data 的：

~~~text
time × receive channel
~~~

结构。

### <code>das_fi_scanline_manual.m</code>

需要 USTB 读取 UFF，但 **DAS 算法本体由本项目自己实现**。

当前实现 conventional FI：

~~~text
1 focused Tx → 1 scanline
~~~

用于建立后续所有高级 beamformer 的真实数据 baseline。

---

## 15. 当前状态

**数据准备完成。**

**真实 DAS reconstruction 尚未在本仓库实现和验证。**

这不是缺陷，而是有意保留清晰的学习边界：

~~~text
第 0 章
→ synthetic model 把物理理解清楚

第 1 章
→ 从真实 UFF 数据开始重新搭建完整 DAS
~~~

下一步就是读取首选点靶数据的真实 metadata，然后根据实际 sequence 决定第一个真实 DAS 版本应该怎样写。

---

## 15.1 Manual DAS vs USTB：真实数据交叉验证已通过

在 `L7_FI_Verasonics_CIRS_points.uff` 上，使用：

- 相同 `x_axis`；
- 相同 `z_axis`；
- conventional scanline Tx；
- full receive aperture；
- USTB MATLAB DAS reference；

比较本项目 `das_fi_scanline_manual.m` 与 USTB `midprocess.das()`，得到：

| 指标 | 结果 |
|---|---:|
| Image size | `1024 × 128` |
| Envelope correlation | `0.999999940` |
| Mean abs normalized error | `1.11320375e-07` |
| RMSE normalized error | `2.08132789e-07` |
| Max abs normalized error | `1.08395861e-05` |
| Manual global peak | `x=-5.5130 mm, z=38.6266 mm` |
| USTB global peak | `x=-5.5130 mm, z=38.6266 mm` |
| Peak location delta | `dx=0 mm, dz=0 mm` |

30 mm 深度的 lateral profile 也几乎完全重合。

因此当前 conventional FI-DAS baseline 可以认为已经通过第一阶段数值交叉验证：

$
\boxed{
\text{Manual FI-DAS} \approx \text{USTB conventional FI-DAS}
}
$

这里的“通过”只针对当前已经匹配的条件：

- spherical focused Tx model；
- scanline transmit apodization；
- full receive aperture；
- linear interpolation；
- RF analytic representation；
- 当前成像 grid。

这并不意味着后续修改 F-number、apodization、RTB 或 IQ 数据时可以跳过重新验证。

下一步进入 **point-target PSF / FWHM / sidelobe** 定量分析。

---
## 15.2 下一小节：Full Receive Aperture vs Dynamic F-number

在 Manual conventional FI-DAS 已通过 USTB 交叉验证后，下一步只改变一个变量：**receive aperture**。

实验脚本：

~~~text
matlab/01_DAS_Real_UFF/compare_receive_aperture_full_vs_fnumber.m
~~~

保持不变：

- 同一 UFF 数据；
- 同一 focused Tx model；
- 同一 `wave.delay` convention；
- 同一 Rx delay；
- 同一 interpolation；
- 同一 x/z grid。

只比较：

~~~text
Full aperture
vs
Dynamic boxcar aperture: D(z) = z / F#
~~~

默认 `F# = 1.7`。

需要特别注意：这里的 F-number aperture 是本项目显式定义的教学模型，不应假设与任意厂商扫描仪或所有 USTB window 配置完全等价。

预期主要观察：

1. finite F-number 减小有效 receive aperture，因此 lateral PSF 通常变宽；
2. axial FWHM 应变化较小，因为 axial resolution 主要受 pulse / bandwidth 限制；
3. full-aperture lateral FWHM 当前只跨约 1–2 个 transmit scanline intervals，因此数值精度受 lateral sampling 明显限制；
4. dynamic aperture 的目标不是在所有深度获得最窄主瓣，而是让有效 aperture 随深度变化，从而控制 F-number 和成像一致性。

在真实 phantom 中，背景散斑和其他散射体会污染所谓“sidelobe profile”，因此本实验优先比较主瓣 FWHM，不把局部背景起伏直接解释成理想 point-target PSL。

---
## 15.3 Full aperture vs F#=1.7：真实数据结果

在同一个约 `x=-4.917 mm, z=20.21 mm` 的点靶附近，仅改变 receive aperture，得到：

| 指标 | Full aperture | Dynamic F# = 1.7 |
|---|---:|---:|
| Active Rx channels | `128 / 128` | `41 / 128` |
| Physical / requested aperture | `37.846 mm` center span | `11.934 mm` from `D=z/F#` |
| Refined peak x | `-4.9170 mm` | `-4.9170 mm` |
| Refined peak z | `20.2102 mm` | `20.2884 mm` |
| Lateral -6 dB amplitude FWHM | `0.481698 mm` | `0.699202 mm` |
| Lateral FWHM / scanline spacing | `1.616` | `2.346` |
| Axial -6 dB amplitude FWHM | `0.427685 mm` | `0.430554 mm` |
| Axial FWHM / z sampling | `10.938` | `11.011` |

主要观察：

1. 将 receive aperture 从全部 128 通道缩到约 41 通道后，lateral PSF 明显变宽；
2. axial FWHM 几乎不变，符合 axial resolution 主要由 pulse / bandwidth 决定的预期；
3. F# aperture 的实际 active-channel 数与 `D=z/F#` 和 probe pitch 的量级一致，说明 aperture selection 逻辑工作正常；
4. Full-aperture lateral FWHM 仅跨 `1.616` 个 scanline intervals，因此 lateral width 的定量精度仍明显受 conventional-FI 横向采样限制；
5. F#=1.7 的 lateral FWHM 也只跨 `2.346` 个 scanline intervals，仍未达到充分横向采样。

这里不能简单使用 `Delta x ~ lambda z / D` 去预测两组 FWHM 的精确比值，因为真实 two-way PSF 同时受到 transmit beam、receive aperture、element directivity、有限 scanline sampling、真实 phantom/background 等因素影响；这个尺度关系主要用于趋势理解，而不是对当前实测 FWHM 做一比一精确预测。

因此这一小节的结论是：

$
\boxed{
D_{\mathrm{Rx}}\downarrow
\Rightarrow
\text{lateral PSF broadens strongly, while axial PSF changes little}
}
$

这也进一步说明：receive F-number 改变的是 **Rx spatial aperture**，而后续 RTB 主要改变的是 **Tx dimension 的 retrospective reconstruction / combination**，两者是不同自由度。

---
## 16. RTB：从“一发一线”到 Pixel-based Transmit Reconstruction

### 16.1 RTB 不是另一种通道求和公式

RTB（Retrospective Transmit Beamforming）仍然可以使用 DAS 完成 receive beamforming。

传统 focused scanline reconstruction：

~~~text
Tx 1 -> scanline 1
Tx 2 -> scanline 2
...
Tx T -> scanline T
~~~

即一个 focused transmit 只用于它自己的 scanline。

RTB 则对每个 focused transmit 构建一张 pixel-based single-transmit image：

$
S_t(x,z)
=
\sum_{m=1}^{M}
w_m^{Rx}(x,z)
s_{m,t}(x,z).
$

然后在同一个 pixel 上跨 transmit coherent combine：

$
S_{RTB}(x,z)
=
\frac{
\sum_{t=1}^{T}
w_t^{Tx}(x,z)S_t(x,z)
}{
\sum_{t=1}^{T}w_t^{Tx}(x,z)
}.
$

因此：

$
\boxed{
\text{RTB-DAS}
=
\text{pixel-based Rx DAS}
+
\text{retrospective Tx-domain coherent combination}
}
$

不是另一种类似 CF / DMAS 的 channel-combination formula。

### 16.2 为什么 conventional scanline 没暴露 spherical-model 的焦点不连续问题？

设 focused virtual source 为：

$
F=(x_f,z_f).
$

simple spherical model 对 candidate pixel $P=(x,z)$ 使用：

$
L_{Tx}^{sph}
=
R_f
+
\operatorname{sgn}(z-z_f)
\sqrt{(x-x_f)^2+(z-z_f)^2},
$

其中 $R_f=\texttt{source.distance}$。

当 conventional scanline 只取：

$
x=x_f,
$

焦点前后极限都连续收敛到 $R_f$。

但是 RTB 会使用 off-axis pixel，即 $x\neq x_f$。在 $z\to z_f^-$ 与 $z\to z_f^+$ 时：

$
L_- = R_f-|x-x_f|,
$

$
L_+ = R_f+|x-x_f|.
$

因此存在跳变：

$
\boxed{
\Delta L
=
2|x-x_f|
}
$

对应时间跳变：

$
\Delta\tau
=
\frac{2|x-x_f|}{c}.
$

这就是 simple spherical virtual-source RTB 在 focal depth 附近产生 artifact 的根本原因。Rindal 等人的 IUS 2018 工作正是针对这个问题。

### 16.3 Hybrid Tx delay

Hybrid model 在远离焦点时仍使用 spherical virtual-source delay；只在：

$
|z-z_f|\le d_{PW}
$

这一小段焦点带内，改用局部 plane-wave delay：

$
L_{Tx}^{PW}
=
R_f+(z-z_f).
$

它不再依赖横向距离 $x-x_f$，因此穿过 focal depth 时连续。

本项目默认：

~~~text
pw_margin = 1 mm
~~~

即与 USTB IUS-2018 示例一致的量级。

### 16.4 Tx apodization：不是所有 Tx 都应该贡献给所有 pixel

一个 focused transmit 的可靠 insonified region 是有限的，因此 RTB 必须有 pixel-dependent Tx weight：

$
w_t^{Tx}(x,z).
$

本项目使用 F-number 定义的局部 transmit support。对于波束局部坐标 $(x',z')$：

$
r
=
F\#_{Tx}
\frac{|x'|}{|z'|}.
$

有效区域约为：

$
r\le\frac12.
$

焦点附近为了避免 aperture 收缩到零，引入：

$
D_{min}^{Tx}.
$

默认参数按照官方 RTB 示例：

~~~text
Tx F#             = 2
Tx minimum aperture = 3 mm
Tx window         = Tukey25
~~~

Tukey25 相比 hard boxcar 会把 beam-support 边缘平滑衰减，减少 abrupt Tx weighting。

### 16.5 为什么最后还要除以 Tx weight sum？

不同 pixel 被多少个 focused transmissions 覆盖并不相同。

如果直接：

$
\sum_t w_t^{Tx}S_t,
$

多 Tx overlap 的区域会天然更亮。

因此官方 RTB 示例以及本项目都采用：

$
\boxed{
S_{RTB}
=
\frac{\sum_t w_t^{Tx}S_t}
{\sum_t w_t^{Tx}}
}
$

这一步是 overlap compensation，不是 envelope normalization。

### 16.6 Manual RTB 实现的数据流

~~~text
UFF channel data
    |
    +-- Tx 1
    |    |
    |    +-- analytic RF
    |    +-- pixel-dependent Tx support
    |    +-- Tx delay
    |    +-- Rx delay for each element
    |    +-- fractional interpolation
    |    +-- Rx DAS -> single-Tx image S1(x,z)
    |
    +-- Tx 2 -> S2(x,z)
    |
    +-- ...
    |
    +-- Tx T -> ST(x,z)
            |
            v
      Tx Tukey/F# weights
            |
            v
      coherent Tx sum
            |
            v
      divide by sum(Tx weights)
            |
            v
        RTB complex image
            |
            v
       envelope / dB
~~~

主代码：

~~~text
matlab/01_DAS_Real_UFF/reconstruct_fi_rtb_manual.m
~~~

代码按 wave 流式处理，不保存完整 `[z x Tx]` low-quality-image cube，从而降低内存需求。

### 16.7 Conventional、纯插值和 RTB 必须区分

`compare_conventional_vs_rtb.m` 同时比较：

1. conventional FI-DAS：原始约 128 条 scanlines；
2. conventional envelope 仅做 lateral interpolation 到 RTB grid；
3. RTB：真正从 RF channel data 对 off-scanline pixels 重新计算 delay 并跨 Tx coherent combine。

其中第 2 项非常重要：

$
\boxed{
\text{display interpolation}
\neq
\text{RTB}
}
$

插值只能让现有图像更平滑，不会重新利用 raw RF，也不会引入新的 transmit-domain coherent information。

### 16.8 与传统 FI-DAS 的核心比较

| 项目 | Conventional FI-DAS | RTB-DAS |
|---|---|---|
| Acquisition | focused Tx | 同一 focused Tx data |
| 一个 Tx 的输出 | 1 条 scanline | 多个 pixels / lines |
| Rx focusing | dynamic DAS | dynamic DAS |
| Tx dimension | 基本不跨 Tx 合成 | 多 Tx 对同一 pixel coherent combine |
| lateral grid | 受 Tx line spacing 约束 | 可比 Tx line spacing 更密 |
| Tx delay model | 中心线较简单 | off-axis model 非常关键 |
| focal-depth artifact | 通常不明显 | spherical model 可产生明显 artifact |
| 计算量 | 低 | 高得多 |
| 主要优势 | 简单、快速、稳定 | 更充分利用 focused-transmit channel data |

### 16.9 当前 Manual RTB 默认参数

~~~text
x_upsample       = 4
Tx delay model   = hybrid
pw_margin        = 1 mm
Tx F#            = 2
Tx min aperture  = 3 mm
Tx window        = Tukey25
Rx F#            = 1.7
wave_stride      = 1
Tx normalization = enabled
~~~

这些参数来自 / 接近 USTB 的 IUS-2018 RTB 示例，但仍需在本数据上重新验证，不能因为来源于官方示例就直接视为当前数据的最优参数。

### 16.10 参数实验应该怎样解释

`experiment_rtb_parameter_sweep.m` 一次只改变一个变量：

| 参数 | 主要改变什么 | 重点观察 |
|---|---|---|
| `tx_delay_model` | spherical vs hybrid | focal-depth artifact / image continuity |
| `x_upsample` | output lateral sampling | dx、FWHM sampling support；不应把更密 grid 自动解释成真实 resolution 提升 |
| `tx_f_number` | 每个 Tx 可贡献的横向角域 | active Tx、compounding 范围、artifact/clutter |
| `tx_min_aperture` | 焦点附近最小 Tx support | focus 附近 coverage 与稳定性 |
| `pw_margin` | 使用 plane-delay 的焦点带宽 | spherical artifact 消除与模型偏差之间的折中 |
| `rx_fnumber` | receive aperture | lateral PSF；这是 Rx 自由度，不是 RTB 本身 |
| `wave_stride` | 实际使用多少个 Tx | acquisition-count / overlap / image quality trade-off |

`wave_stride=2/4` 是用现有数据模拟“只采每 2 / 4 个 focused transmissions”的情形。输出 grid 保持不变，因此可以观察 RTB 在减少 transmit 数量时如何退化。

### 16.11 Manual RTB 也必须做 reference validation

验证脚本：

~~~text
validate_manual_rtb_vs_ustb.m
~~~

它会在匹配的 grid、Tx F#、Tukey25、minimum aperture、hybrid margin 和 Rx F# 下，将 Manual RTB 与 USTB `midprocess.das()` hybrid RTB 做数值比较。

在该脚本真正跑通并得到相关系数 / error / peak-location 结果以前，Manual RTB 只能称为 **实现完成、待真实数据 reference 验证**，不能称为已经科学验证。

### 16.12 Unified model 放在哪里？

Nguyen & Prager 2016 的 unified pixel-based beamforming 从 transmit field shape 出发，比 simple spherical model 更细致地处理 focused transmit 的有效波前；USTB 提供 `spherical_transmit_delay_model.unified`。

本章主实现暂不复制 unified model 的整套区域划分与 delay interpolation，而是：

- Manual baseline 实现 simple spherical + hybrid；
- unified model 作为重要参考方法保留；
- 先验证 hybrid RTB，因为其物理动机和代码更透明。

这符合本项目目标：先掌握可解释的核心，再进入更复杂模型。

---
### 16.13 实测发现：Hybrid 仍可能出现 focal-band seam

在当前 `L7_FI_Verasonics_CIRS_points.uff` 上，Manual Hybrid RTB 与 USTB Hybrid RTB 的图像几乎一致，但二者都在 transmit focus 附近出现明显横向分界。

这不是 Manual RTB 独有实现错误，而与 Hybrid model 本身的 **hard model switch** 有关。

USTB 当前 Hybrid 源码的逻辑为：

~~~text
z < zf - pw_margin      -> spherical
zf-pw_margin < z < zf+pw_margin -> plane
z > zf + pw_margin      -> spherical
~~~

因此 Hybrid 确实移除了 simple spherical model 在 `z=zf` 的符号跳变，但对 off-axis pixel，spherical path 与 plane path 在：

$
z=z_f\pm d_{PW}
$

一般并不严格相等。

所以 hard replacement 可能把原来的焦点不连续转化为两个 focal-band transition seams。

这次实测说明：

> `hybrid` 不应被机械理解为“任何数据上都没有焦点区域 artifact”；它是一种简单、有效但仍然近似的 transmit-delay model。

### 16.14 当前 USTB 的 Blended model

当前 USTB 源码还提供：

~~~matlab
spherical_transmit_delay_model.blended
~~~

它不再在固定深度边界硬切 spherical / plane delay，而定义连续权重：

$
d_n
=
\min\left(
\frac{|R_f-\|P\||}{R_f},
1
\right),
$

$
\alpha=d_n^p,
$

默认：

$
p=\frac12.
$

然后：

$
L_{blend}
=
\alpha L_{spherical}
+
(1-\alpha)L_{plane}.
$

靠近 focal spherical shell 时，plane model 权重更大；远离该区域时逐步回到 spherical model。

这种连续混合没有 `z_f±pw_margin` 的硬切边界，因此特别适合检验当前看到的横向 seam 是否由 Hybrid hard switch 导致。

Manual RTB 现已支持：

~~~text
tx_delay_model = 'spherical'
tx_delay_model = 'hybrid'
tx_delay_model = 'blended'
~~~

并增加：

~~~text
blending_power = 0.5
~~~

参数实验 `delay_model` 现在会三方比较 spherical / hybrid / blended。

---
### 16.15 RTB lateral edge darkening：如何区分 Tx、Rx 与显示因素

Blended model 明显改善 focal-band seam 后，当前真实数据仍可观察到左右边缘比中心略暗。

这个现象不应立即解释为算法错误。对于有限长度线阵和有限 focused-transmit coverage，边缘 pixel 往往同时面临：

1. 可参与的 transmit events 更少；
2. Tx Tukey / F-number 权重总和更低；
3. dynamic receive aperture 在探头物理边缘被截断，active Rx channels 变少；
4. 即使除以 `sum(Tx weights)`，也只能补偿平均 overlap gain，无法恢复边缘缺失的 synthetic aperture / coherent information。

因此增加专用诊断脚本：

~~~text
matlab/01_DAS_Real_UFF/diagnose_rtb_edge_darkening.m
~~~

它在完全相同的 Blended RTB Tx 设置下，对比：

~~~text
Rx F# = 1.7
vs
Full Rx aperture
~~~

并同时输出：

- `active_tx_count(x,z)`；
- `tx_weight_sum(x,z)`；
- dynamic F-number 下的 `active_rx_count(x,z)`；
- Full-Rx 与 F#-Rx 的 RTB B-mode；
- 选定深度范围内，沿 x 的 median envelope level；
- left / center / right 三个区域的 Tx count、Tx weight、Rx count 和相对背景亮度统计。

其中横向背景趋势使用 **depth-wise median envelope**，目的是降低孤立点靶对均值的污染；它仍然只是诊断统计，不是绝对声学灵敏度标定。

推荐解释顺序：

1. 若 edge 的 `active_tx_count` / `tx_weight_sum` 明显下降，说明 Tx support 是主要因素之一；
2. 若 dynamic F# 的 `active_rx_count` 在边缘下降，而且切换到 full Rx 后暗边减轻，说明 Rx aperture truncation 也很重要；
3. 若 full Rx 后仍明显存在暗边，则 Tx coverage / synthetic-aperture loss 更可能是主因；
4. 不应直接按 `tx_weight_sum` 或 `active_tx_count` 对 B-mode 做增益补偿并把它称为 RTB 本身，因为那会引入额外的 post-processing / display correction。

---
### 16.16 实测暗边诊断：简单 Tx/Rx support 不能解释右侧约 4–5 dB 变暗

在 Blended RTB 上运行 `diagnose_rtb_edge_darkening.m`，得到：

~~~text
Median active Tx count [left | center | right]
14 | 15 | 14

Median Tx weight sum [left | center | right]
12.858 | 12.870 | 12.858

Median active Rx count, F#=1.7 [left | center | right]
37 | 54 | 37

Relative median background, RTB F# Rx [dB]
+0.303 | 0 | -4.353

Relative median background, RTB Full Rx [dB]
-0.242 | 0 | -4.900
~~~

这些结果说明：

1. Tx active-count 和 Tx weight-sum 的 left/right 几乎对称，因此不能解释当前明显的 **右侧单边变暗**；
2. Dynamic F-number Rx 的 active-channel count 虽然在左右边缘都下降，但左右同样对称；
3. 改成 Full Rx 后，右侧 roll-off 并没有减轻，反而仍约 `-4.9 dB`，因此 **Rx aperture truncation 不是当前右侧暗边的主因**；
4. 当前 brightness roll-off 明显左右不对称，而几何 Tx/Rx support 基本左右对称，因此下一步必须检查：这种不对称是否已经存在于 conventional FI / acquired data 本身。

为此诊断脚本已扩展为同时重建 matched conventional FI-DAS：

~~~text
RTB, Rx F#=1.7
RTB, full Rx
Conventional FI-DAS, Rx F#=1.7
~~~

Conventional 图像只在最终显示/统计时插值到 RTB x-grid，不会把该插值冒充 RTB。

如果 conventional FI 也出现接近的右侧 `-4~-5 dB` roll-off，则更支持：

- phantom lateral non-uniformity；
- acquisition / probe element sensitivity；
- actual transmit/receive directivity；
- 或其它数据本身已存在的 lateral sensitivity variation。

如果 conventional FI 相对均匀而 RTB 独有右侧 roll-off，则再继续追：

- off-axis focused Tx field model；
- Tx F-number / Tukey support；
- element directivity 未建模；
- synthetic-aperture coherence at the FOV boundary。

---
### 16.17 Conventional 对照结果：右侧 roll-off 不是 RTB 独有

将诊断扩展为 matched conventional FI-DAS 后，观察到：

- RTB F#=1.7；
- RTB full-Rx；
- conventional FI-DAS F#=1.7；

三者在右侧 `x≈14–18 mm` 都出现相似的亮度下降，smoothed lateral profile 的下降位置和量级基本一致。

结合前一轮 support 结果：

~~~text
Tx count      : left / center / right ≈ 14 / 15 / 14
Tx weight sum : 12.858 / 12.870 / 12.858
Rx count      : 37 / 54 / 37
~~~

可以得到当前最重要的结论：

> 当前明显的右侧 lateral roll-off **不是 Blended RTB 特有 artifact**，也不是由 RTB Tx-overlap normalization 或 dynamic Rx aperture truncation 单独造成；它已经存在于同一份 focused-acquisition 数据的 conventional reconstruction 中。

因此后续若要追根因，应优先检查 acquisition / scene 本身，例如：

- phantom lateral non-uniformity；
- 实际 focused-transmit aperture 在边缘 scanlines 的截断或能量变化；
- probe / channel sensitivity variation；
- element / transmit beam directivity；
- 其它 acquisition-side lateral sensitivity variation。

这类因素会同时影响 conventional FI 和 RTB，因此不应再把当前右侧暗边作为 RTB 模型错误继续调参。

#### 一个统计注意事项

当前一次输出的 lateral-profile 标题仍为：

~~~text
z = 10 to 45 mm
~~~

说明 MATLAB 工作区中先前设置的 `profile_z_max=45e-3` 被 `clearvars -except` 保留下来，覆盖了脚本后来新增的默认 `27 mm`。

而 `30 mm` 点靶群以及左下 `35–42 mm` 的大片亮结构会污染 lateral background statistic。

若要做更干净的横向均匀性统计，应显式执行：

~~~matlab
profile_z_min = 10e-3;
profile_z_max = 27e-3;
diagnose_rtb_edge_darkening
~~~

或者先：

~~~matlab
clear profile_z_min profile_z_max
~~~

再运行脚本。

这个重新统计主要用于更可靠地量化左右 roll-off，**不会改变“conventional 与 RTB 都具有相同右侧下降趋势”这一已观察到的定性结论**。

---
## 17. 本章完成后的意义

一旦第 1 章 DAS baseline 完成，后面的算法不再重复写一套完全不同的数据管线。

共同前半部分：

~~~text
UFF
→ geometry
→ Tx/Rx delay
→ interpolation
→ focused aperture vector s(r)
~~~

之后再分支：

~~~text
s(r)
├── DAS
├── CF
├── MV / MVDR
├── DMAS
└── SLSC
~~~

这样后续比较才能真正回答：

> **图像差异来自 beamformer，还是来自不同的前处理、delay、grid 或显示流程？**
