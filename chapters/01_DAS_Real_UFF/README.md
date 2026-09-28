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
## 16. 本章完成后的意义

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
