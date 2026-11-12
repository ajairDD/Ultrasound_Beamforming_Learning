# 第三章配图与课件索引

本目录收录 **7 张文生图概念插图与 18 张实际 MATLAB 配图**。正文按 18 组讲解：图 1–6 先建立完整算法；图 7–11 把关键公式变成可运行小实验；图 12–17 展示真实重建；图 18 回到导向失配的解释。

[返回第三章](../README.md) · [MATLAB 入口与复现说明](../../../matlab/03_MVDR/README.md) · [AI 提示词与编辑记录](imagegen_prompts.md)

## 1. 文生图：算法关系与直觉

| 正文 | 文件 | 讲解重点 |
|---|---|---|
| 图 1 | [das_cf_mvdr_concept.png](das_cf_mvdr_concept.png) | CF / GCF 在求和后乘像素权重，MVDR 在求和前加接收权重 |
| 图 2 | [mvdr_distortionless_concept.png](mvdr_distortionless_concept.png) | 先约定要保留的导向模式，再最小化输出功率 |
| 图 3 | [mvdr_spatial_smoothing.png](mvdr_spatial_smoothing.png) | 六通道、三通道子孔径、四个重叠观测；`X[L,P]` |
| 图 4 | [mvdr_axial_covariance.png](mvdr_axial_covariance.png) | 邻域估计权重，中心深度形成输出 |
| 图 5 | [mvdr_diagonal_loading.png](mvdr_diagonal_loading.png) | 加载为每个特征值增加同一个正量 |
| 图 6 | [mvdr_rtb_pipeline.png](mvdr_rtb_pipeline.png) | 每个 Tx 内先沿 Rx 做 MVDR，再共用 RTB 的 Tx 合成 |
| 图 18 | [mvdr_steering_mismatch.png](mvdr_steering_mismatch.png) | 单位约束保护名义模式，实际模式不匹配时仍可能衰减 |

这些插图由 Codex 内置 `image_gen` 实际生成，最终选用 PNG 已保存到本目录。白色背景、英文短标签便于放入课件；中文正文解释符号和读图顺序。它们是概念示意，不按比例，不作为声场、协方差测量或算法性能证据。

逐张检查了通道数、子孔径索引、矩阵维度、共轭、数据流和标签。对生成图做了定向校正：简化固定权重的表达，补齐轴向邻域的协方差路径，统一加载图中的矩阵维度，去掉 RTB 输出端的假 B-mode 图标和失配图中的定量角度。完整初始与编辑提示词保存在 [imagegen_prompts.md](imagegen_prompts.md)。

## 2. MATLAB：公式、真实数据与读图

全部 PNG 来自实际 `exportgraphics(...,'Resolution',150)`。下表的 Nx / Nz 是输出网格，人工向量没有真实空间采样坐标。

| 正文 | 文件 | 网格 / 配置 | 课件用途 |
|---|---|---|---|
| 图 7 | [demo_mvdr_building_blocks_01.png](demo_mvdr_building_blocks_01.png) | 16 通道窄带向量，`rng(3)` | 相同单位目标增益下的响应与复数权重 |
| 图 8 | [demo_mvdr_building_blocks_02.png](demo_mvdr_building_blocks_02.png) | `M=6,L=3,P=4` | 索引矩阵、实际 `X` 幅值、二阶矩幅值 |
| 图 9 | [demo_mvdr_building_blocks_03.png](demo_mvdr_building_blocks_03.png) | `M=12,L=8,P=5`，七行 | 轴向邻域、协方差秩与加载后的特征值 |
| 图 10 | [demo_mvdr_building_blocks_04.png](demo_mvdr_building_blocks_04.png) | loading `1e-5/0.01/0.1/10` | 接收响应、条件数与权重能量 |
| 图 11 | [demo_mvdr_building_blocks_05.png](demo_mvdr_building_blocks_05.png) | 残余相位坡，loading `1e-5/0.01/0.1/1` | 名义约束始终满足，但实际目标增益改变 |
| 图 12 | [compare_manual_das_vs_mvdr_spatial_only_01.png](compare_manual_das_vs_mvdr_spatial_only_01.png) | TheGB，Nz=256，轴向半窗 0 | conventional 共同 DAS 参考 |
| 图 12 补充 | [compare_manual_das_vs_mvdr_spatial_only_02.png](compare_manual_das_vs_mvdr_spatial_only_02.png) | 同上 | 各自峰值归一化，幅值差被隐藏 |
| 图 12 | [compare_manual_das_vs_mvdr_axial_01.png](compare_manual_das_vs_mvdr_axial_01.png) | TheGB，Nz=256，轴向半窗 1.5λ | conventional 共同 DAS 参考 |
| 图 12 补充 | [compare_manual_das_vs_mvdr_axial_02.png](compare_manual_das_vs_mvdr_axial_02.png) | 同上 | 各自峰值归一化形态 |
| 图 13 | [experiment_mvdr_tradeoffs_01.png](experiment_mvdr_tradeoffs_01.png) | TheGB，Nz=160；四组 L/M、loading | 同一 DAS 参考的四组 MVDR 图像 |
| 图 13 | [experiment_mvdr_tradeoffs_02.png](experiment_mvdr_tradeoffs_02.png) | 同上；dx≈0.298 mm | 目标横向剖面，窄峰采样不足 |
| 图 14 | [compare_rtb_das_vs_rtb_mvdr_01.png](compare_rtb_das_vs_rtb_mvdr_01.png) | TheGB，Nx=281,Nz=181，stride=1 | 同一 RTB-DAS 参考的密网格图像 |
| 图 15 补充 | [compare_rtb_das_vs_rtb_mvdr_02.png](compare_rtb_das_vs_rtb_mvdr_02.png) | 同上 | 原脚本的横向剖面与自归一化图像 |
| 图 15 | [compare_rtb_das_vs_rtb_mvdr_03.png](compare_rtb_das_vs_rtb_mvdr_03.png) | 同上；dx=dz=0.025 mm | 横向 / 轴向、共同 / 自归一化四个剖面 |
| 图 16 | [compare_carotid_rtb_das_vs_rtb_mvdr_cross1_01.png](compare_carotid_rtb_das_vs_rtb_mvdr_cross1_01.png) | Cross 1，Nx=161,Nz=171，stride=2 | 人体共同参考对照 |
| 图 16 | [compare_carotid_rtb_das_vs_rtb_mvdr_cross1_02.png](compare_carotid_rtb_das_vs_rtb_mvdr_cross1_02.png) | 同上 | 灰阶自归一化形态与有掩膜的幅值差 |
| 图 17 | [compare_carotid_rtb_das_vs_rtb_mvdr_cross2_01.png](compare_carotid_rtb_das_vs_rtb_mvdr_cross2_01.png) | Cross 2，Nx=161,Nz=171，stride=2 | 第二组独立 acquisition 的共同参考 |
| 图 17 | [compare_carotid_rtb_das_vs_rtb_mvdr_cross2_02.png](compare_carotid_rtb_das_vs_rtb_mvdr_cross2_02.png) | 同上 | 第二组的形态与掩膜幅值差 |

人工向量的 `q` 单位是 cycles/channel，不是声学频率或波束角度。真实重建使用复数解析 RF 和 binary receive F# 1.7，frame 1。

完整 conventional 图覆盖 z=5–45 mm；参数实验覆盖 z=18–22.5 mm。密网格 RTB 覆盖 x=−4–3 mm、z=18–22.5 mm；carotid 覆盖 x=−10–10 mm、z=8–25 mm，dx=0.125 mm、dz=0.100 mm。

真实 RTB 统一采用 `blended` Tx delay、`blending_power=0.5`、Tx F# 2、最小 Tx 支持 3 mm、`tukey25`，并归一化 Tx 权重和。`pw_margin=1 mm` 仅供 `hybrid` 分支使用，本次 `blended` 不使用它。默认 MVDR 为子孔径比例 0.5、loading 0.01、轴向半窗 1.5λ、FB=false，参数实验和 spatial-only 图按表中设置例外。

目标 seed `[-0.745,20.10]` mm 对应局部搜索区域，各方法在其中定位自己的峰，不是假定目标真值坐标。半幅宽在未裁剪线性包络的 0.5 阈值（约 −6.0206 dB）处测量；−20 dB 宽使用 0.1 阈值。

参数图原先在 2×2 面板中展示全宽扫描线与很窄的深度带，目标太小。本次将图像显示范围裁到目标横向 ±3.5 mm，并在剖面上标出真实采样点；重建与数值测量仍使用原定义，单独重跑导出。这也让读者直接看见窄峰的扫描线采样限制。

颈动脉第二张图原先沿用默认彩色映射，NaN 掩膜像素也容易被误读为最低差值。本次改为每个 B-mode 轴显式灰阶、差图单独彩色和透明掩膜灰色背景，并实际重跑两个 acquisition。前后打印的网格、全局峰值比、掩膜中位数、包络相关与 fallback 数值一致。

## 3. 本次实际环境、输入与验证

- MATLAB：`9.11.0.1769968 (R2021b)`。
- USTB：`D:/USTB`，Git SHA `86126eb7cab8b6009d14f2d448e85eeb8a86f61c`。
- TheGB：实数 RF，`[sample,Rx,Tx,frame]=[1920,128,128,1]`，fs=20,833,334 Hz。
- 波长由 UFF 元数据读取，约 0.295679986 mm；不能沿用基础章 5 MHz 示例的 0.308 mm。
- 所有真实实验固定 frame 1；conventional 默认脚本文件仍为 carotid cross 2，导出器显式传入 TheGB。
- 人体实验本次只运行 stride=2 的上述网格，未重跑 stride=1 的更密人体实验。

本次重新读取的输入 MD5：

| 文件 | MD5 |
|---|---|
| `L7_FI_TheGB.uff` | `9d9c728b9d03fa66444956b445fe2d7f` |
| `L7_FI_carotid_cross_1.uff` | `4b6622477c4f9af882dc2496e36dc3bf` |
| `L7_FI_carotid_cross_2.uff` | `108477dbd0b6cda6a03f2b840266b58c` |

已经执行并通过的相关检查：

- 人工向量的单位增益误差约 `1.735e-18`；同一加载矩阵下 MVDR 目标函数值不大于归一化 DAS。
- Toy 例子的空间二阶矩秩为 5、轴向平均后为 8；检查 Hermitian 结构、正加载后的正定性和理想相干输入的 `M*A`。
- 真实输出的 `[z,x]` 形状、复数有限值和 `envelope=abs(analytic)`。
- 两个 conventional DAS 与第一章独立实现的最大峰值归一化复数误差约 `1.071e-17`。
- 密网格 RTB-DAS 与第一章 RTB 的复数误差为 0。
- 四组参数使用同一 DAS 基线；两个人体 acquisition 的显示修正没有改变打印的数值结果。

日志： [人工向量](matlab_concepts_results.txt)、[phantom / 目标](matlab_phantom_results.txt)、[参数图重导](matlab_experiment_mvdr_tradeoffs_results.txt)、[carotid](matlab_carotid_results.txt)。

MATLAB 在全部计算与导图完成后，退出时仍出现当前环境的 `Settings` 未定义提示，进程退出码为 0。数值断言、回归检查和 PNG 导出均已完成；这个退出环境问题不属于本次教程修改范围。

## 4. 复现命令

~~~matlab
addpath(genpath('D:/USTB'));
cd D:/Ultrasound_Beamforming_Learning/matlab/03_MVDR
export_chapter3_figures('concepts')
export_chapter3_figures('phantom')
export_chapter3_figures('carotid')
~~~

也可用 `export_chapter3_figures('all')` 一次运行。每组脚本的固定参数和运行指标写入对应日志，现有章节算法核心保持原来的数据流与计算定义。
