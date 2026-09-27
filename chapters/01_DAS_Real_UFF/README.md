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

## 8. 计划中的 DAS 核心接口

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

## 9. 输出不是“一个 DAS 图”这么简单

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

## 10. 本章验证标准

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

## 11. 当前已有代码

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

---

## 12. 当前状态

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

## 13. 本章完成后的意义

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
