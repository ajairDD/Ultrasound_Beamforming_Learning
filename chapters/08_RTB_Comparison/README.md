# 第 8 章：同一 RTB 几何下的七种波束合成方法对比

**状态：TheGB 真实 UFF 的七算法集成实验已完成；标题显示已经在本地 MATLAB 图像中确认。** 本章是方法对比与实验总结，不重新发明算法，也不把图像观感当作临床优越性证明。

> **本章与第 7 章的区别**：第 7 章是统一 benchmark，分为 conventional FI 与 dense RTB 两条独立轨道，侧重 PSF、散斑统计和已有数值指标；**第 8 章固定同一套 RTB Tx/Rx 几何及网格，让 DAS、CF、GCF、MVDR、fDMAS、SLSC、NSI 一次性输出，侧重七种方法可视化对比和跨设备标准接口的实际使用。** 两章并存，不混用第 7 章不同网格的 FWHM 数字。

## 一、问题与共同条件

我们希望只改变**接收通道信息的合并方式**，观察同一 RTB 点目标与背景在七种方法下的变化。

### 1. 实验记录（用户 MATLAB 实测，2026-11-14）

| 参数 | 本次条件 |
|---|---|
| 数据 | `data/L7_FI_TheGB.uff`，真实聚焦发射 RF channel data |
| 原始数组 | `[sample,Rx,Tx,frame]=[1920,128,128,1]` |
| 阵元间距 | 0.298 mm |
| UFF 报告的 Tx 焦深 | 29.6 mm；**不同于**本次显示的约 20 mm 点目标深度 |
| 时间参考 | `initial_time=0`，`Tx/Rx sound-speed difference=0` |
| 图像 ROI | x = -4 至 3 mm；z = 18 至 22.5 mm |
| 横向采样 | 64 pixels，约 0.1111 mm/pixel |
| 轴向采样 | 由实际波长按约 `lambda/16` 自动选取（不要把它与横向采样混用） |
| 发射使用 | `wave_stride=4`：从 128 次聚焦 Tx 中取 32 次；**不是全部 Tx** |
| RTB 模型 | blended virtual-source；`blending_power=0.5` |
| Tx apodization | Tx F#=2，Tukey25，最小 Tx 孔径 3 mm |
| Rx aperture | dynamic Rx F#=1.7 |
| 显示动态范围 | -60 至 0 dB（SLSC 除外） |
| 七算法总耗时 | 41.37 s（一次联合计算，**不是**单独算法耗时） |

**方法特有参数**（与本次 `demo_rtb_universal` 的默认值一致）：

- CF：接收孔径能量相干因子；GCF：`M0=1`，接受 `{-1,0,+1}` 三个低空间频率 bin。
- MVDR：子孔径 `L/M=0.5`，diagonal loading `0.01`，轴向 covariance averaging `1.5 lambda`。
- fDMAS：real-RF signed-sqrt pair product；图像深度时间轴约 `2 f0` 滤波；默认相对频率边缘 `[1.5,1.75,2.5,2.75] f0`。
- SLSC：最大 lag 12，使用有效 Rx 数量的约 15% 短 lag、轴向相关核约 `1 lambda`；各 Tx 的相干性统计量**非相干加权平均**。
- NSI：DC offset `c=0.8`，对零均值接收模式与两次 DC offset 包络做 subtraction。

**共享条件**：七种方法调用 `matlab/RTB_Universal/rtb_reconstruct_all.m` 中相同的 focused-Tx RTB 传播模型、Tx 权重、Rx delay、分数采样插值、接收孔径和输出 x/z 网格。各方法只有数学上必须的附加处理不同（如 MVDR covariance、fDMAS bandpass、SLSC 相关性图）。这保证了**几何比较条件一致**，但不意味着七种结果都有相同的物理幅度单位。

## 二、图像怎样正确比较？

本次用户已确认两张 Figure 中七个子图均显示正确标题。

### Figure 1：own-peak

对应一键脚本导出的 `RTB_seven_methods_own.png`：

- DAS、CF、GCF、MVDR、fDMAS、NSI 的**各自峰值**单独归一化到 0 dB；适合看纹理、点目标形状和背景变化。
- **不能**根据 Figure 1 中相同的白色亮度推断目标回波幅度相同。
- SLSC 一直显示 **0–1 的线性 short-lag coherence**；灰色表示无法获得有效估计，不是零回波。

### Figure 2：common DAS peak reference

对应 `RTB_seven_methods_common.png`：

- DAS、CF、GCF、MVDR、NSI 的显示以**同一 RTB-DAS 峰值**为数值参考，更适合观察某一输出被相对压低多少。
- **重要例外**：fDMAS 的 signed-sqrt pair product 幅度尺度不与 DAS 等价，始终保留 **own-peak dB（non-calibrated）**。不能将 fDMAS 的灰度与 DAS 直接相减当作物理增益。
- **重要例外**：SLSC 是无量纲的线性相干性，不参加 DAS 的 dB 幅度比较。
- 即使统一了显示峰值，MVDR 的量纲/尺度约定与 NSI 的 DC offset 归一化仍需在跨方法绝对信号定量时单独论证；此处主要用于相同实验设置下的数值对照。

**关于图像文件**：用户的 Figure 1/2 截图是本章定性观察的依据。仓库保留可复现的绘图脚本，默认将 PNG/MAT 输出到本地 `output/benchmark/ch08/`；与先前章节一致，不把原始 UFF 或未经复核的图像二进制文件冒充仓库自带数据。

## 三、七种方法——从图片能够观察到什么？

以下是针对本次 **x=-4～3 mm、z=18～22.5 mm 的单个 TheGB ROI** 的定性分析，不是独立 ground truth、跨体模排名或统计显著性检验。

| 方法 | 本次截图中的现象（观察） | 对应的算法作用（解释） | 应注意的代价/局限 |
|---|---|---|---|
| **DAS** | 点目标周围是相对平滑的宽响应，背景 speckle 与局部旁瓣样结构仍可见 | 通道延时对齐后求和，作为共同几何基线 | 不能仅凭这张图判断杂波强度或分辨率 |
| **CF** | 背景整体更黑，点目标周围强相干成分相对突出，周围出现明显的暗区 | 惩罚接收孔径不相干能量，只让高相干回波通过 | 可能同时削弱真实组织 speckle；“更黑”不等于更准确 |
| **GCF (M0=1)** | 背景比 CF 更完整，整体外观向 DAS 靠近；点目标仍明显 | 除 DC 外也保留邻近低空间频率，使对平滑相位结构更加宽容 | 抑制不如 CF 激进，也可能重新接纳低阶杂波 |
| **MVDR** | 点目标形状与 DAS 接近，局部横向响应有所变化，但未见可直接确认的巨大整体优势 | 利用接收 covariance 自适应设权重 | 当前 x 栅格约 0.111 mm，**不能据截图精确量化窄主瓣**；还受模型失配/自抑制影响 |
| **fDMAS** | 点目标更显竖向细长，背景纹理明显改变 | 真实 RF 通道非线性成对组合，再选出二倍频分量 | 轴向条纹/拉长的机理未单独验证；不能仅凭图像断言分辨率提高 |
| **SLSC** | 点目标附近形成比较宽且光滑的亮区，背景表现为平缓的相干性带状变化 | 有限轴向核上的短 lag 接收信号相关性，跨 Tx 统计平均 | **不是回波幅度 B-mode**；其亮区大小不能与 DAS 的回波峰值宽度直接等价 |
| **NSI (c=0.8)** | 点目标突出，背景出现较强的明暗条纹与局部黑区 | 零均值孔径与 DC offset 子模式的包络差分保留窄残差 | 可能抑制真实散射组织；已有全视野 carotid 结果显示这是一项重要风险 |

### 读图时最容易犯的三种错误

**第一，把独立峰值归一化当成真实幅度比较。** 在 Figure 1 中，每张包络图自己的最大值都是 0 dB。只有满足数值尺度可比的分支才能进一步用 Figure 2 辅助判断相对衰减；fDMAS/SLSC 明确不在其内。

**第二，把点目标“变尖”或背景“变黑”直接等同于提高物理分辨率。** 这次只有 64 个横向位置，约 0.111 mm/pixel；没有计算严格同一 PSF 主瓣宽度、旁瓣能量、两点可分辨能力、误差条或重复性。第 7 章的密集 RTB FWHM 来自另一次网格/方法实验，不能直接搬到这张七方法图上形成排名。

**第三，忽略输出图像的信号类型。** DAS/CF/GCF/MVDR/NSI 属于复数波束合成或其包络变换；fDMAS 是非线性、二倍频链路；SLSC 是相关性。即便七个结果坐标完全一致，其灰度对应的物理量也不完全相同。

## 四、已验证的内容、尚未验证的内容

### 当前确实通过

1. **通用输入接口合成测试 PASS**：不同轴排列、单位、物理 Rx channel 映射、RF/IQ 输入、错误元数据拒绝，以及 CF=GCF(M0=0) 等边界检验。
2. **同网格复杂 RTB-DAS 双精度回归 PASS**：统一接口 vs 独立第 1 章 DAS，max-peak scaled error **`6.533229e-16`**，Tx 权重最大差异 **0**；这验证共同几何与聚焦-DAS 基线的一致性。
3. **TheGB 七方法真实 RF 集成运行 PASS**：`Methods completed: DAS, CF, GCF, MVDR, FDMAS, SLSC, NSI`；`MVDR fallback 0/61289`，`SLSC unavailable pixel-Tx 0`；两张图正确显示七个方法标题。

### 目前不能据此声称

- 其它机器的私有 raw/UFF 已经无误适配；尚未完成跨厂商真实 raw + metadata 的数值验收。
- fDMAS 和 SLSC 的这个**RTB 扩展组合顺序**已与原始论文的全部实验序列逐点一致；需要独立 benchmark。
- 目标主瓣宽度、SNR、CNR、gCNR、旁瓣、散斑保真度等定量指标均已测得；**目前并没有该轮实验的数值表**，本章不杜撰指标。
- 本次 **41.37 秒**是总流程运行时间，无法判断各方法独立运行成本，也不等于优化后产品级帧率。
- NSI、CF 或其他方法具有更好的临床检出能力；没有已标注 target/background ROI 和在体重复性证据。

## 五、一键复现：独立的第 8 章脚本

该脚本**复用** `matlab/RTB_Universal`，不复制或改写底层算法：

~~~matlab
% 在仓库根目录外先将 USTB 加入 MATLAB 路径
addpath(genpath('D:/你的USTB路径'));

cd matlab/08_RTB_Comparison
out = run_chapter8_rtb_comparison;
~~~

程序使用本章第 1 节固定的 TheGB 参数，完成七算法计算、像素 shape/finite 检查，输出 own/common 两幅带完整标题的图，并将配置及数值输出保存在本地：

~~~text
output/benchmark/ch08/
  RTB_seven_methods_own.png
  RTB_seven_methods_common.png
  RTB_seven_methods_results.mat
~~~

`out.images` 中每种方法的数值数组统一为 `[z,x]`，`out.x_axis_m`、`out.z_axis_m` 为米；`out.display`、`out.display_common_db` 为绘图数据。SLSC 是无量纲相干性，fDMAS 的 common-display 仍用自身峰值。原始 UFF 不写入 MAT 输出。

如果已经运行 `demo_rtb_universal` 并保留 `out`，则可**无需重复重建**：

~~~matlab
rtb_show_methods(out,'own');
rtb_show_methods(out,'common');
~~~

## 六、本章结论

这项实验成功回答的是：**同一组 focused-Tx RTB 时延和接收孔径数据，在七种不同通道组合方法下，图像会发生怎样的定性变化；统一接口能否一次运行全部方法。**

截图展示了各方法的不同“选择偏好”：CF 强相干筛选、GCF 保留低阶结构、MVDR 自适应组合、fDMAS 非线性频带、SLSC 短 lag 相关统计、NSI 零均值残差。但尚无充分证据宣布某方法全面优于 DAS。

**下一项真正有价值的验证**应先以第二家机器的 focused FI 原始数据通过 `rtb_audit_source` 和独立复数 RTB-DAS 回归，再决定是否进行跨机七算法对比；在未解决输入物理一致性之前，没有必要增加更复杂的算法。

---

### 相关章节和工具

- [第 7 章：统一 Benchmark](../07_Benchmark/README.md)：轨道内定量指标和验证规则。
- [第 1 章：RTB-DAS 基础](../01_DAS_Real_UFF/README.md)：focused Tx virtual-source、aperture 和独立 baseline。
- [RTB_Universal 标准接口与算法实现](../../matlab/RTB_Universal/README.md)：输入元数据、RF/IQ、跨设备边界及测试。
- [第 8 章 MATLAB 一键复现](../../matlab/08_RTB_Comparison/README.md)：运行参数与输出路径。
