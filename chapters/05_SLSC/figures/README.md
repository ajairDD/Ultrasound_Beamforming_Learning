# 第 5 章配图与课件索引

本章共 **20 张本地 PNG**：6 张 AI 概念图、8 张 MATLAB 数值教学图、6 张同一 TheGB 重建的实验与诊断图。标题、说明、坐标和图例均使用中文，保留 SLSC、DAS、RF、Tx、Rx、lag、ROI 等专业术语与数学符号。

独立配图文件不纳入 Git，中英文版本均由仓库 `.gitignore` 排除。此索引、MATLAB 源码、生成提示词和数值日志可以提交。全新克隆后，需要在本地生成或取得配图，才能完整预览章节 Markdown。

## 1. 概念图：说明处理关系，不当作测量结果

| 正文图号 | 文件 | 讲解重点 |
|---|---|---|
| 1 | [slsc_pipeline_concept.png](slsc_pipeline_concept.png) | 共享聚焦前端，在 Rx 求和前分成 DAS 与 SLSC |
| 2 | [slsc_axial_gate.png](slsc_axial_gate.png) | 七行深度点、六列固定阵元；每格是一个 RF 样本 |
| 4 | [slsc_spatial_lag.png](slsc_spatial_lag.png) | 空间阵元间隔与时间移位的区别 |
| 6 | [slsc_normalized_similarity.png](slsc_normalized_similarity.png) | 形状、正增益、负相关与包络前处理的区别 |
| 11 | [slsc_dynamic_aperture.png](slsc_dynamic_aperture.png) | 当前有效 Rx 数影响 lag 数；sum 与 mean 的计数因素 |
| 13 | [slsc_interpretation_limits.png](slsc_interpretation_limits.png) | 相干性不是反射强度，也不能独自判定组织来源 |

六张图由 Codex 内置 `image_gen` 实际生成并逐张检查；[初始提示词](imagegen_prompts.md)和[定向校正记录](imagegen_review.md)保留。核对包括：共同前端的分叉位置、空间 lag 的阵元数量、RF 矩阵的 7×6 结构、(K−1)Δz、正负相关、lag=0 的排除与全部中文标签。

图中的探头、路径、波形和输出图标均为概念示意，不按比例，不是临床图像、仿真声场或定量性能证据。矩阵中的示例数值也不来自 UFF。

## 2. MATLAB 图册

| 正文图号 | PNG 文件 | 数据来源与内容 |
|---|---|---|
| 5 | [demo_slsc_building_blocks_01.png](demo_slsc_building_blocks_01.png) | 六阵元的物理 lag 配对矩阵与各 lag 对数 |
| 7 | [demo_slsc_building_blocks_02.png](demo_slsc_building_blocks_02.png) | 四样本精确内积 `[1,1,-1,0]` |
| 3 | [demo_slsc_building_blocks_03.png](demo_slsc_building_blocks_03.png) | 合成 RF 样本窗口；单点与九点的逐对估计 |
| 8 | [demo_slsc_building_blocks_04.png](demo_slsc_building_blocks_04.png) | 共同分量与独立噪声的统计模型 |
| 9 | [demo_slsc_building_blocks_05.png](demo_slsc_building_blocks_05.png) | 人为指数协方差、总体曲线与样本估计 |
| 12 | [demo_slsc_building_blocks_06.png](demo_slsc_building_blocks_06.png) | 固定 R(m)=0.8 时，仅 lag 数改变造成的 sum / mean 差异 |
| 14 | [demo_slsc_building_blocks_07.png](demo_slsc_building_blocks_07.png) | 两组人为统计摘要；参与平均的像素集合改变 |
| 10 | [demo_slsc_building_blocks_08.png](demo_slsc_building_blocks_08.png) | 分段随机模型的九点 / 四十一点窗口，不是 PSF |
| 15 | [compare_fi_das_vs_slsc_01.png](compare_fi_das_vs_slsc_01.png) | 实际 TheGB：DAS 包络 dB 与 SLSC 线性显示 |
| 16 | [compare_fi_das_vs_slsc_02.png](compare_fi_das_vs_slsc_02.png) | 同一结果：各 lag 可用像素的 ROI 曲线、请求 lag 数 |
| 17 | [uff_slsc_diagnostics_01.png](uff_slsc_diagnostics_01.png) | 同一结果：有效 Rx、请求和实际有效 lag 数量 |
| 18 | [uff_slsc_diagnostics_02.png](uff_slsc_diagnostics_02.png) | 同一结果：各 lag 支持与前六项共同有效像素对照 |
| 19 | [uff_slsc_diagnostics_03.png](uff_slsc_diagnostics_03.png) | 同一结果：signed mean、显示映射、有效像素直方图 |
| 20 | [uff_slsc_diagnostics_04.png](uff_slsc_diagnostics_04.png) | 同一结果：7×39 真实 RF 窗口、近邻阵元波形与 R(m) |

## 3. 复现与验证

从仓库根目录运行：

~~~matlab
addpath(genpath('D:/你的USTB路径'));
addpath('matlab/05_SLSC');
export_chapter5_figures('all');
~~~

`concepts` 只生成八张无数据图；`uff` 运行同一套默认 TheGB 设置并导出六张真实数据图；`cached` 只重画此前同一 out 的四张诊断图，适用于呈现修改。完整参数与数据流见[MATLAB 说明](../../../matlab/05_SLSC/README.md)。

实际验证环境为 MATLAB R2021b、Microsoft YaHei 字体；PNG 以 150 dpi 导出。数值例子使用 `rng(5,'twister')`。真实数据使用本地 `data/L7_FI_TheGB.uff`，frame 1、128 条 FI 扫描线、768 个深度点、5–45 mm、Rx F#=1.7、q=0.15、最大 lag=12、名义轴向窗口 1λ。

本机 USTB 提交为 `86126eb7cab8b6009d14f2d448e85eeb8a86f61c`；该 UFF 的 SHA-256 为 `45e6e862fec0d8a5150189f5ed9d0de663486470646dcf1ea56963e3b5e00736`。这是本次复现所用文件的指纹，不代表所有同名数据版本均相同。

[matlab_all_results.txt](matlab_all_results.txt)记录已执行的数值检查、TheGB 描述性统计和单像素独立复算。DAS 复数回归误差为 `5.225506e-18`；逐 lag 聚合误差和该 RF 窗口相关值复算误差均为 0。这些检查没有建立全图 SLSC 独立金标准，也没有测量 CNR、gCNR 或临床有效性。

图形编辑缓存和 UFF 输出缓存保存在被忽略的 `work/pdfs/` 中。所有图导出后，本机 MATLAB 退出阶段仍报告无法识别 `Settings`；该已有环境问题与图像、数值检查完成状态分别记录。
