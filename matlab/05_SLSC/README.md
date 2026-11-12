# 第 5 章 MATLAB：SLSC 的小例子、真实数据与课件图

先读[第 5 章教程](../../chapters/05_SLSC/README.md)，再在代码中沿着这条路径找变量：

> 实数 RF → Tx/Rx 延时与插值 → 固定阵元列的轴向窗口 → 逐对归一化相关 → 同 lag 平均 → 短 lag 求和 / 平均 → 显示。

核心算法仍是 conventional FI、receive-domain、real-RF SLSC。DAS 分支用于核对与第 1 章一致的前端；本章新增课件图不改变核心重建算法，也不增加真实数据参数扫描。

## 1. 先运行八个不需要 UFF 的例子

从仓库根目录运行：

~~~matlab
addpath('matlab/05_SLSC');
report = demo_slsc_building_blocks;
~~~

不需要 USTB、外部数据或声学仿真器。固定随机种子为 `rng(5,'twister')`。八张图依次讲：物理 lag 配对、归一化内积、轴向窗口、共同分量与独立噪声、指定协方差模型、sum / mean、统计集合效应，以及长短窗口的轴向混合。

这些是代数或统计例子，不是仿真声场、真实组织或算法性能基准。模型曲线与实际 TheGB 图像在教程中分别标明来源。

## 2. 运行完整二维 TheGB 对照

~~~matlab
addpath(genpath('D:/你的USTB路径'));
cd matlab/05_SLSC
compare_fi_das_vs_slsc
~~~

默认数据 `../../data/L7_FI_TheGB.uff`，第 1 帧、128 个 focused Tx、5–45 mm、768 个深度点。生成两张基本图：DAS dB / SLSC 线性图，以及 ROI 相关曲线 / 请求 lag 数量。

| 参数 | 默认值 | 含义 |
|---|---:|---|
| `receive_f_number` | 1.7 | 动态 Rx 孔径 |
| `axial_kernel_lambda` | 1.0 | 名义完整窗口长度，以波长为单位 |
| `lag_fraction` | 0.15 | 相对当前有效接收阵元数的比例 |
| `max_lag` | 12 | 物理阵元间隔的上限 |
| `min_valid_samples` | 3 | 每对至少需要的共同有效深度样本 |
| `run_das_reference_check` | true | 与第 1 章复数 DAS 回归 |

原论文的 Q 按发射孔径定义；本项目的 `lag_fraction` 按有效接收孔径定义。不要只凭比例相等就判断两个实现参数相同。

## 3. 导出全部中文课件图

从仓库根目录运行：

~~~matlab
addpath(genpath('D:/你的USTB路径'));
addpath('matlab/05_SLSC');
export_chapter5_figures('all');
~~~

输出到 `chapters/05_SLSC/figures/`：

- `demo_slsc_building_blocks_01.png` 至 `_08.png`：八张教学图。
- `compare_fi_das_vs_slsc_01.png` 至 `_02.png`：两张完整二维实验图。
- `uff_slsc_diagnostics_01.png` 至 `_04.png`：同一结果的孔径计数、ROI 统计支持、有符号输出与显示、真实 RF 窗口。
- `matlab_all_results.txt`：实际运行的检查结果与描述性数值。

六张 AI 概念图由内置 `image_gen` 另行生成，不属于 MATLAB 输出；[配图索引、提示词和校正记录](../../chapters/05_SLSC/figures/README.md)可追溯生成过程。

其他入口：

~~~matlab
export_chapter5_figures('concepts'); % 仅八张无数据教学图
export_chapter5_figures('uff');      % 默认 TheGB 重建和六张真实数据图
export_chapter5_figures('cached');   % 只重画同一缓存结果的四张诊断图
~~~

`cached` 用于标题、字体、留白等呈现修改。若数据、核心算法或重建参数有变化，应重新运行 `all` 或 `uff`。缓存位于 `work/pdfs/chapter5/`，不进入 Git。独立 PNG、MATLAB `.fig` 和中英文图片版本同样不进入 Git；本机已有图片保留。

## 4. 文件分工与主要维度

| 文件 | 阅读重点 |
|---|---|
| `reconstruct_fi_slsc_manual.m` | UFF、延时、窗口、物理阵元索引和逐 lag 核心循环 |
| `compare_fi_das_vs_slsc.m` | 固定参数、基本自检、DAS 回归与两张主结果图 |
| `demo_slsc_building_blocks.m` | 可独立运行、可手算核对的小例子 |
| `inspect_slsc_output.m` | 用同一份 out 核对计数、聚合、显示和一个真实 RF 窗口 |
| `export_chapter5_figures.m` | 固定设置导出中文图、日志与本地缓存 |

~~~text
UFF RF                    [sample,Rx,Tx,frame]，实数
延时后的通道数据          [Nz,N_Rx]，实数
当前像素的 RF 窗口        [K_actual,M]，实数
DAS                       [Nz,Nx]，复数
lag_correlations          [Nz,Nx,max_lag]，实数，无效 lag 为 NaN
slsc_sum / slsc_mean       [Nz,Nx]，有符号实数
slsc_display              [Nz,Nx]，[0,1] 线性显示值
valid_lag_count           [Nz,Nx]，实际可计算的 lag 数
x_axis / z_axis           米，绘图转换成 mm
~~~

窗口内固定当前像素中心选中的 M 个物理阵元，但每一对只保留共同有效的深度行。`min_valid_samples` 是数量门槛，不保证这些行在统计上相互独立。

归一化采用 `sum(a.*b)/sqrt(sum(a.^2)*sum(b.^2))`，不逐窗减均值，不先取包络或绝对值。负相关保留在科学结果中；只有显示支路裁负值。无有效 lag 时的零占位要与 `valid_lag_count` 一起解释。

## 5. 实际验证结果

2026-11-12，MATLAB 9.11.0.1769968（R2021b），默认 TheGB 设置；完整数值见[日志](../../chapters/05_SLSC/figures/matlab_all_results.txt)。

| 项目 | 结果 |
|---|---|
| 四样本内积 | `[1,1,-1,0]`，通过 |
| 六阵元各 lag 对数 | `[5,4,3,2,1]`，通过 |
| 指定协方差玩具模型，样本曲线与总体曲线最大差 | 约 `0.0085962`，在设定容差内 |
| 图像维度 | `[768,128]` |
| 实际轴向窗口 | K=7，跨度 `(K-1)*dz`≈1.058264λ |
| 有效 SLSC 像素 | 98304 / 98304 |
| mean 范围 | 约 `[−0.684833,0.985491]`，负值有效像素 1747 个 |
| 由逐 lag 输出重建 sum / mean | 最大误差均为 0 |
| 第 1 章复数 DAS 最大峰值归一化误差 | `5.225506e-18`，通过 `<1e-10` 要求 |
| 单个真实 RF 窗口独立复算 | 7×39，五个 lag 的相关值最大误差 0 |

复算使用独立逐通道 `interp1`，并固定与核心相同的采样索引 `u=(tau-t0)*fs+1`。本数据的时间 metadata 为 single；另行构造 single 时间轴会引入不同的舍入。统一索引约定是在核对同一离散运算，没有更改核心精度或算法。

未运行 USTB SLSC MEX，不报告独立全图金标准等价性，也不把当前图像外观当作临床或普遍性能优势。本机所有导出完成后，MATLAB 在退出阶段仍提示无法识别 `Settings`；该既有环境问题与数值断言、PNG 导出完成状态分别记录。

## 6. 读结果时先看什么

先看 DAS 与 SLSC 不同的色条，再看每个 lag 的统计数量。中央 ROI 中，Lag 1 约 0.8901，Lag 4 约 0.5419；Lag 6–8 的回升伴随有效像素数量减少。固定前六项共同有效的 18307 个像素后，本次曲线约为 `[0.9124,0.8386,0.7607,0.6958,0.6254,0.5675]`。

这说明统计支持影响 ROI 平均，不意味着真实 R(m) 必须单调，也不能把线性相干性与 dB 幅度直接比较亮度。完整讲解见[教程第 10 节](../../chapters/05_SLSC/README.md)。
