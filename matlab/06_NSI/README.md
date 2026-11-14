# 第 6 章 MATLAB：NSI 的原理小例子与真实数据课件

先读[第 6 章教程](../../chapters/06_NSI/README.md)，再沿代码找这条路径：

> 实数 RF → 解析信号与延时插值 → 接收 D / Z → 各路 Tx 相干合成 → DC1 / DC2 重组 → 三路分别取包络 → 相减 → 共同参考显示。

教程统一用 δ 表示代码参数 `dc_offset`，避免与声速 c 混淆。核心 `reconstruct_fi_rtb_nsi_manual.m` 未改动；本次增加教学、中文绘图、日志与同一输出的诊断。

## 快速开始（全课程统一入口）

原理小实验无需数据；密集 RTB 点目标需要 USTB 与 TheGB UFF。**建议先读[本章教学正文](../../chapters/06_NSI/README.md)，再从仓库根目录运行以下命令。**

**第一步：无需外部数据的原理演示**

~~~matlab
addpath('matlab/06_NSI');
demo_nsi_building_blocks
~~~

**第二步：真实 UFF 图像 / 数据检查**（先准备 USTB 与数据）

~~~matlab
addpath(genpath('D:/你的USTB路径'));
cd matlab/06_NSI
compare_rtb_das_vs_nsi
~~~

**提示：** 先做密集点目标，再看全视野与人体；不要把窄响应直接解读为图像整体改善。 完整实验顺序、参数、输出与验证记录见下方说明；课件配图见[本章配图索引](../../chapters/06_NSI/figures/README.md)。

---

## 1. 八个无数据小实验

从仓库根目录运行：

~~~matlab
addpath('matlab/06_NSI');
report = demo_nsi_building_blocks;
~~~

不需要 USTB、UFF 或声学仿真器，随机种子为 `rng(6,'twister')`。依次生成三套孔径、Null 相消、窄带阵列因子、复数边界与相位、Tx 合成次序、δ、采样网格、随机孔径抑制的八张图。

其中阵列因子以归一化相位梯度 u 为横轴，不是毫米；随机孔径例子不包含真实组织相关结构。它们不用于报告 TheGB PSF、真实分辨率或临床优越性。

~~~matlab
export_chapter6_figures('concepts'); % 导出八张中文数值教学图
~~~

## 2. 密集点目标实验

~~~matlab
addpath(genpath('D:/你的USTB路径'));
cd matlab/06_NSI
compare_rtb_das_vs_nsi
~~~

默认 TheGB、第 1 帧、全部 128 个 focused Tx；横向 −4 至 3 mm、281 点，深度 18 至 22.5 mm、181 点，Δx=Δz=0.025 mm，δ=0.2。

共有前端：RTB blended Tx 模型、`blending_power=0.5`、Tx Tukey25、Tx F#=2、最小孔径参数 3 mm、Rx F#=1.7、相同插值及 Tx 权重归一化。脚本默认开启第 1 章 RTB-DAS 复数回归。

两张图分别显示共同 DAS 参考的二维图，以及各自峰值剖面 / 实际三路包络相减。宽度以包络半幅（约 −6.02 dB）和十分之一幅度（−20 dB）定义，交点采用线性插值；不把它当作双目标可分辨能力的独立测量。

## 3. 全视野：快速预览与完整课件设置

直接运行：

~~~matlab
compare_full_fov_rtb_das_vs_nsi
~~~

交互默认是 TheGB 加第一组颈动脉，257×385 网格，`wave_stride=2`，δ=0.2，`run_rtb_reference_check=false`。用于先观察形态，不用于精确量窄主瓣。

本章新课件使用以下固定设置，并检查全部三份数据：

~~~matlab
dataset_indices = [1 2 3];
n_x = 385;
n_z = 513;
wave_stride = 1;
dc_offset = 0.2;
run_rtb_reference_check = true;
compare_full_fov_rtb_das_vs_nsi
~~~

| 数据编号 | 文件 |
|---|---|
| 1 | `data/L7_FI_TheGB.uff` |
| 2 | `data/L7_FI_carotid_cross_1.uff` |
| 3 | `data/L7_FI_carotid_cross_2.uff` |

“全视野”指全部 focused Tx 的横向位置范围与 5–45 mm 深度。边界来自各 UFF metadata，不是把点目标 ROI 放大；有效边界也保存在 `out.options.x_min/x_max` 中。

每一数据集的 DAS 与 NSI 共用该数据的 DAS 全局峰值，数据集之间不共用参考。幅度保留比 `r=(E/δ)/|D|` 仅在 DAS≥−40 dB 且有 Tx 覆盖的位置显示和统计，灰色表示被排除。

## 4. 一键导出全部课件图

从仓库根目录运行：

~~~matlab
addpath(genpath('D:/你的USTB路径'));
addpath('matlab/06_NSI');
export_chapter6_figures('all');
~~~

输出到 `chapters/06_NSI/figures/`，共 **17 张 MATLAB PNG**：

| 文件前缀 | 数量 | 内容 |
|---|---:|---|
| `demo_nsi_building_blocks` | 8 | 无数据的教学例子 |
| `compare_rtb_das_vs_nsi` | 2 | 点目标二维图及剖面 / 三路包络 |
| `full_fov_delta02` | 2 | 三份全视野的 δ=0.2 图与幅度保留比 |
| `full_fov_delta08` | 2 | 同一 D、Z 重算 δ=0.8 的图与保留比 |
| `nsi_diagnostics` | 3 | 网格交点、同一遮罩下的保留比分布、显示参考 |

另有 **7 张内置 `image_gen` 概念图**，并非 MATLAB 输出；[配图索引、提示词及校正记录](../../chapters/06_NSI/figures/README.md)保存来源。

其他模式：

~~~matlab
export_chapter6_figures('point');  % 运行点目标，仅导出两张主结果
export_chapter6_figures('full');   % 三份全视野 + 回归，仅导出两张 δ=0.2 主结果
export_chapter6_figures('cached'); % 从既有点目标 / 全视野缓存导出九张真实数据图
~~~

`cached` 要求此前已运行 `all`，或分别运行 `point` 与 `full`。δ=0.8 的比较重用同一组复数 D、Z，三路包络组合由代数直接重算；它不是另采一组数据，也没有再次改变几何或 Tx 合成。若算法、数据或重建参数改变，应重新运行相应重建模式。

缓存位于 `work/pdfs/chapter6/`；图形编辑缓存位于 `work/pdfs/matlab_figures/06_NSI/`。这些缓存、独立 PNG 和 `.fig` 均被 Git 忽略，中英文配图都只保留本地。代码、Markdown、提示词与数值日志可以提交。

## 5. 核心数值约定与数组

对每个 Tx / 像素，孔径内复数通道样本形成：

~~~matlab
D = sum(s);
Z = sum(wZM .* s);
% 先在 D、Z 各自分支上做相同的 coherent Tx compounding。
DC1 = Z + dc_offset*D;
DC2 = -Z + dc_offset*D;
E = (abs(DC1)+abs(DC2))/2 - abs(Z);
A = max(E,0) / dc_offset;  % 裁剪仅处理浮点舍入
~~~

| 数组 | 维度 / 类型 |
|---|---|
| 采集 RF | `[sample,Rx,Tx,frame]`，实数 |
| 单次 Tx 的解析 RF | `[sample,Rx]`，复数 |
| 固定深度的插值 Rx 样本 | `[有效横向像素,Rx]`，复数 |
| 合成后的 D、Z、DC1、DC2 | `[Nz,Nx]`，复数 |
| E、E/δ、显示 dB 图 | `[Nz,Nx]`，实数 |
| Tx 权重和与覆盖计数 | `[Nz,Nx]` |
| x/z 坐标 | 米，绘图时转为 mm |

偶数 M 左右各半为 +1/−1；奇数 M 的中间 ZM 权重为 0，而 DC 中为 δ，DAS 仍使用该通道。有效阵元应在物理顺序上连续。

理论对任意复数 D、Z 满足 `0≤E≤δ|D|`。三套线性加权只需独立计算 D、Z；但取模与相减不可移入 Tx 相干合成之前。不要对原始 RF 或 dB 图直接做同样相减，也不要对最终 E 再取绝对值。

## 6. 已执行的验证

实际环境为 MATLAB 9.11.0.1769968（R2021b）与 Microsoft YaHei 字体。详细记录见[matlab_all_results.txt](../../chapters/06_NSI/figures/matlab_all_results.txt)。

| 检查 | 结果 |
|---|---|
| 三套接收权重与 D、Z 重组 | 最大绝对差约 `7.32e-15` |
| 四通道手算例子、奇偶权重、相干顺序与采样 | 通过 |
| 一万个随机复数对的包络上下界 | 通过 |
| 点目标与第 1 章复数 RTB-DAS 回归 | 最大峰值归一化误差 0 |
| 三份全视野的独立 RTB-DAS 回归 | 误差 `[0,0,0]` |
| 保存 D、Z 重算 δ=0.2，与核心 E/δ 比较 | 三份数据的归一化最大差均为 0 |
| δ=0.2 / 0.8 的统计遮罩 | 完全相同 |

点目标半幅宽约 0.7063 / 0.1609 mm，对应 28.25 / 6.44 个横向网格间隔。三份全视野的 median 幅度保留比约为：

| 数据 | δ=0.2 | δ=0.8 |
|---|---:|---:|
| TheGB | 0.0699 | 0.3746 |
| 颈动脉 1 | 0.0635 | 0.3769 |
| 颈动脉 2 | 0.0636 | 0.3746 |

这些是指定样本集合中的算法抑制统计，不是功率比或图像质量分数。未运行独立全图 NSI 金标准，未报告 CNR/gCNR 或临床优势。所有图片与断言完成后，本机 MATLAB 退出阶段仍有既有的 `Settings` 提示，日志与教程分别记录这一环境问题。

## 7. 如何阅读结果

先看共同 DAS 参考下的二维图，再看实际采样点和剖面，最后查看体模 speckle、两组血管壁及周围组织。δ=0.2 的窄点目标响应伴随强组织抑制；δ=0.8 恢复部分幅度，但更亮不自动代表更好。

完整原理、每张图的读法、历史快速预览的证据范围及课堂自检见[第 6 章正文](../../chapters/06_NSI/README.md)。
