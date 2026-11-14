# 第 7 章配图与课件索引

共 **20 张本地 PNG：6 张内置 image_gen 概念图 + 14 张实际 MATLAB 图**。普通标题、坐标、图例使用中文，保留业内名称、代码标识与数学符号。中英文独立配图均被 Git 忽略，仓库仅记录代码、提示词、复核记录和文本日志。

## 概念图：先建立比较主线

| 正文图号 | 文件 | 讲解重点 |
|---|---|---|
| 1 | [benchmark_task_map.png](benchmark_task_map.png) | 从任务走向条件、指标和取舍 |
| 2 | [benchmark_two_tracks.png](benchmark_two_tracks.png) | FI 与密集 RTB 组内可比、组间不混排 |
| 3 | [benchmark_width_sampling.png](benchmark_width_sampling.png) | 半幅交点、采样点和 Δx |
| 6 | [benchmark_roi_protocol.png](benchmark_roi_protocol.png) | 独立标注、同深度背景与未测量 |
| 8 | [benchmark_gcnr_overlap.png](benchmark_gcnr_overlap.png) | 两组分布的最小公共面积 |
| 13 | [benchmark_runtime_accounting.png](benchmark_runtime_accounting.png) | 实际核心计时与 D/Z 复用 |

[完整提示词](imagegen_prompts.md) · [科学复核与编辑提示词](imagegen_review.md)。

概念图不按比例，组织/B-mode 缩略画面和曲线均为机制示意，不作 TheGB 观测或指标证据。已核对分箱/分布含义、半幅定义、ROI 深度、两轨条件及计时范围。

## 七张无需 UFF 的 MATLAB 图

| 正文图号 | 文件 | 代码与证据类型 |
|---|---|---|
| 4 | [demo_benchmark_building_blocks_01.png](demo_benchmark_building_blocks_01.png) | 已知高斯半幅宽度与实际指标函数 |
| 5 | [demo_benchmark_building_blocks_02.png](demo_benchmark_building_blocks_02.png) | 同一连续模型的不同网格取样 |
| 7 | [demo_benchmark_building_blocks_03.png](demo_benchmark_building_blocks_03.png) | 已知合成区域与共同秩分箱 |
| 9 | [demo_benchmark_building_blocks_04.png](demo_benchmark_building_blocks_04.png) | 可逆变换与完全饱和 |
| 10 | [demo_benchmark_building_blocks_05.png](demo_benchmark_building_blocks_05.png) | 相同边际分布、不同空间排列 |
| 12 | [demo_benchmark_building_blocks_06.png](demo_benchmark_building_blocks_06.png) | CV、均值/标准差和参考相关 |
| 11 | [demo_benchmark_building_blocks_07.png](demo_benchmark_building_blocks_07.png) | 同总体的 20 次有限样本估计 |

来自 [demo_benchmark_building_blocks.m](../../../matlab/07_Benchmark/demo_benchmark_building_blocks.m)，固定 `rng(7,'twister')`。这些是标量/统计模型，不是声场、组织真值或真实病灶。

## 七张真实 TheGB 输出图

| 正文图号 | 文件 | 内容 |
|---|---|---|
| 14 | [benchmark_fi_images.png](benchmark_fi_images.png) | 六方法同一 FI 扫描线与深度网格 |
| 17 | [benchmark_rtb_images.png](benchmark_rtb_images.png) | 密集 RTB 四输出的共同 DAS 参考 |
| 15 | [benchmark_diagnostics_01.png](benchmark_diagnostics_01.png) | FI 裁剪放大，不加密横向采样 |
| 16 | [benchmark_diagnostics_02.png](benchmark_diagnostics_02.png) | 宽度跨越的扫描线/像素间隔数 |
| 18 | [benchmark_diagnostics_03.png](benchmark_diagnostics_03.png) | 经过各自局部峰值深度的实际剖面 |
| 19 | [benchmark_diagnostics_04.png](benchmark_diagnostics_04.png) | 同一个描述性 ROI 的统计 |
| 20 | [benchmark_diagnostics_05.png](benchmark_diagnostics_05.png) | 实际执行路径的单次全核心计时 |

基于本轮重跑产生的 `FI_results.mat` / `RTB_results.mat`，重绘不改变图像数值。FI 深度 16–24 mm、434 点、横向扫描线约 0.298 mm；RTB 为 161×161、Δx=Δz=0.025 mm、全部 Tx。计时及未测量值严格按原执行路径归属，NaN 不画成零耗时。

## 复现与验证

~~~matlab
% 从仓库根目录
addpath(genpath('D:/你的USTB路径'));
addpath('matlab/07_Benchmark');
export_chapter7_figures('all');
% 之后可以使用 cached，只读数值缓存而不重复 RF 重建。
~~~

[MATLAB 说明](../../../matlab/07_Benchmark/README.md) · [真实运行日志](matlab_benchmark_results.txt) · [教学与缓存检查](matlab_lecture_results.txt)。

2026-11-14、MATLAB R2021b，Microsoft YaHei、150 dpi。FI 五条自适应核心内部复数 DAS 误差均 6.147026e-18，RTB 两个独立基础 DAS 差异 0。新增解析宽度、统计与采样例子通过各自断言。

没有真实标注 lesion/background ROI，不生成真实 CR/CNR/gCNR；没有独立全算法金标准或临床优越性结论。退出阶段的既有 Settings 环境提示不作为数值通过依据。
