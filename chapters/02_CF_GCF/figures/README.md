# 第二章配图与课件索引

本目录收录 **5 张 AI 概念插图与 27 张实际 MATLAB 配图**。正文按 16 组组织：先用图 1–5 讲完整理论，再用图 6–10 串起人工向量、真实向量与图像，图 11–16 用于讨论参数、目标、组织纹理与深度。

[返回第二章](../README.md) · [MATLAB 入口说明](../../../matlab/02_CF_GCF/README.md) · [AI 提示词与校正记录](imagegen_prompts.md)

## 1. 概念插图：先把算法关系讲清楚

| 正文 | 文件 | 讲解重点 |
|---|---|---|
| 图 1 | [aligned_aperture_concept.png](aligned_aperture_concept.png) | 同一像素在不同 Rx 的查询时刻；复数向量位于求和之前 |
| 图 2 | [cf_phasor_intuition.png](cf_phasor_intuition.png) | 相位相消与幅值分布都影响 CF；有效零样本也计入 M |
| 图 3 | [cf_processing_pipeline.png](cf_processing_pipeline.png) | 同一向量分两路计算 DAS 和权重，乘权后才取包络 |
| 图 4 | [aperture_spatial_spectrum.png](aperture_spatial_spectrum.png) | 常量、相位坡与不规则相位沿 Rx 的空间 FFT |
| 图 5 | [gcf_bandwidth_tradeoff.png](gcf_bandwidth_tradeoff.png) | DC-only 扩展为低频带；扩大 M0 的收益与代价 |

插图由 Codex 内置 `image_gen` 生成，最终 PNG 已放入本目录。白色背景适合课件，英文短标签配正文中文解释。它们不按比例，不能作为声场测量、重建结果或性能证据。

逐张检查了流程箭头、相量关系、DC / +1 bin、低频选择与轴标签。第一张经两次定向编辑改为清晰的查询时间轴，避免示意 RF 相位引起歧义；第五张把能量轴统一为 `Spectral energy`。图 4 画的是频谱幅值示意，GCF 的实际能量使用幅值平方。完整初始提示词与编辑提示词保存在 [imagegen_prompts.md](imagegen_prompts.md)。

## 2. MATLAB 图册：让公式与实际计算对应

所有真实重建用 frame 1、深度 5–45 mm、binary Rx F# 1.7。下表 n_z 指输出深度网格，人工向量不涉及成像网格。PNG 由 `exportgraphics(...,'Resolution',150)` 实际导出。

| 正文 | 文件 | n_z | 课件用途 / 读图提醒 |
|---|---|---:|---|
| 图 6 | [demo_cf_aperture_vectors_01.png](demo_cf_aperture_vectors_01.png) | — | 32 通道；相位、复相量与孔径谱；`rng(1)` |
| 图 7 | [demo_cf_failure_and_gcf_motivation_01.png](demo_cf_failure_and_gcf_motivation_01.png) | — | 64 通道的常量、一 bin 相位坡与随机相位；`rng(2)` |
| 图 7 | [demo_cf_failure_and_gcf_motivation_02.png](demo_cf_failure_and_gcf_motivation_02.png) | — | 教学半宽 K=0/1/2/4 的权重 |
| 图 8 | [inspect_real_cf_aperture_vectors_01.png](inspect_real_cf_aperture_vectors_01.png) | 512 | 三个给定坐标在 DAS 中的位置 |
| 图 8 | [inspect_real_cf_aperture_vectors_02.png](inspect_real_cf_aperture_vectors_02.png) | 512 | 查询时间、幅值 / 相位、phasors 与空间谱 |
| 图 9 | [compare_manual_das_vs_cf_01.png](compare_manual_das_vs_cf_01.png) | 512 | DAS、CF map 与共同 DAS 参考下的加权结果 |
| 图 9 | [compare_manual_das_vs_cf_02.png](compare_manual_das_vs_cf_02.png) | 512 | 两种方法各自峰值归一化，观察形态 |
| 图 10 | [compare_manual_das_cf_gcf_01.png](compare_manual_das_cf_gcf_01.png) | 512 | 同一 DAS peak 下的 DAS / CF / GCF(M0=1) |
| 图 10 | [compare_manual_das_cf_gcf_02.png](compare_manual_das_cf_gcf_02.png) | 512 | 0–1 的 CF / GCF 权重图，不是 B-mode |
| 图 10 | [compare_manual_das_cf_gcf_03.png](compare_manual_das_cf_gcf_03.png) | 512 | GCF−CF 权重差，不是真值误差 |
| 图 11 | [experiment_gcf_m0_sweep_01.png](experiment_gcf_m0_sweep_01.png) | 256 | M0=0/1/2/4，共同 DAS 参考 |
| 图 11 | [experiment_gcf_m0_sweep_02.png](experiment_gcf_m0_sweep_02.png) | 256 | 同一频带变化对应的权重 map |
| 图 11 | [experiment_gcf_m0_sweep_03.png](experiment_gcf_m0_sweep_03.png) | 256 | 权重统计随带宽变化 |
| 图 12 补充 | [analyze_das_vs_cf_point_target_01.png](analyze_das_vs_cf_point_target_01.png) | 1024 | 目标搜索起点和局部峰定位 |
| 图 12 | [analyze_das_vs_cf_point_target_02.png](analyze_das_vs_cf_point_target_02.png) | 1024 | 横向剖面；同时看共同参考与局部峰归一化 |
| 图 12 | [analyze_das_vs_cf_point_target_03.png](analyze_das_vs_cf_point_target_03.png) | 1024 | 轴向剖面；横轴为深度 |
| 图 12 | [analyze_das_vs_cf_point_target_04.png](analyze_das_vs_cf_point_target_04.png) | 1024 | 同一目标附近的局部图像 |
| 图 13 补充 | [analyze_gcf_m0_point_target_01.png](analyze_gcf_m0_point_target_01.png) | 512 | 不同 M0 的目标位置 |
| 图 13 | [analyze_gcf_m0_point_target_02.png](analyze_gcf_m0_point_target_02.png) | 512 | M0=0/1/2 横向剖面，独立网格内比较 |
| 图 13 | [analyze_gcf_m0_point_target_03.png](analyze_gcf_m0_point_target_03.png) | 512 | M0=0/1/2 轴向剖面 |
| 图 14 | [analyze_gcf_speckle_roi_01.png](analyze_gcf_speckle_roi_01.png) | 512 | 可复现 ROI 的位置；不是理想 speckle 真值 |
| 图 14 | [analyze_gcf_speckle_roi_02.png](analyze_gcf_speckle_roi_02.png) | 512 | 同一 ROI，共同 DAS peak，观察纹理和抑制 |
| 图 14 | [analyze_gcf_speckle_roi_03.png](analyze_gcf_speckle_roi_03.png) | 512 | 各自 ROI 均值归一化的包络分布，隐藏了均值差 |
| 图 15 | [compare_carotid_fi_cf_gcf_oneclick_01.png](compare_carotid_fi_cf_gcf_oneclick_01.png) | 512 | 两个独立 acquisition，每行各用本行 DAS peak |
| 图 15 | [compare_carotid_fi_cf_gcf_oneclick_02.png](compare_carotid_fi_cf_gcf_oneclick_02.png) | 512 | 人体 CF / GCF 权重图 |
| 图 15 补充 | [compare_carotid_fi_cf_gcf_oneclick_03.png](compare_carotid_fi_cf_gcf_oneclick_03.png) | 512 | GCF−CF 权重差 |
| 图 16 | [analyze_carotid_cf_gcf_depth_dependence_01.png](analyze_carotid_cf_gcf_depth_dependence_01.png) | 512 | 中央 80% scanlines 的权重、DAS 幅值与有效 M |

B-mode 显示 −60 到 0 dB；权重 map 显示 0–1。目标宽度在未裁剪包络上计算，半幅阈值为 0.5（约 −6.0206 dB），不是功率半高。图 12、13 的 n_z 不同，不要直接混成一次只改算法的对照。

深度图右侧原先把 dB 和 active count 同放在共享 x 轴，导致接收计数被裁掉。本次修正为公共横轴深度、左右纵轴分别显示 dB 与计数，已单独重跑；数值重建与分段统计没有改动。

## 3. 本次实际运行环境与输入

- MATLAB：`9.11.0.1769968 (R2021b)`。
- USTB：本地 `D:/USTB`，固定 Git SHA `86126eb7cab8b6009d14f2d448e85eeb8a86f61c`。
- 数据：实数 RF，TheGB 的 `[sample,Rx,Tx,frame]=[1920,128,128,1]`。
- 所有实验固定 frame 1、Rx F-number 1.7；全图 GCF 半宽 M0=1，sweep 为 [0,1,2,4]，目标 M0 对照为 [0,1,2]。
- 目标 seed：`[-0.75,20.05]` mm；并非独立理想点真值。
- 向量选点 seeds：`[-0.75,20.05;8,22;10,10]` mm；吸附到实际网格后分析。
- ROI corners：`[5,18;11,24]` mm；实际包含 76×20 个像素，没有预先证明理想均匀 speckle。

输入文件 MD5 本次重新读取核对：

| 文件 | bytes | MD5 |
|---|---:|---|
| `L7_FI_TheGB.uff` | 165917807 | `9d9c728b9d03fa66444956b445fe2d7f` |
| `L7_FI_carotid_cross_1.uff` | 263777852 | `4b6622477c4f9af882dc2496e36dc3bf` |
| `L7_FI_carotid_cross_2.uff` | 263777852 | `108477dbd0b6cda6a03f2b840266b58c` |

下载来源见 [数据说明](../../../data/README.md)。本目录只保存配图与日志，UFF 文件不重复加入 Git。

## 4. 本次检查与解释边界

11 个示例均已实际运行并完成 27 张 PNG，MATLAB 批处理退出码为 0。主要数值检查：

| 检查 | 本次结果 |
|---|---|
| 三个真实向量的 `sum(s)` 与第一章复数 DAS | 三点绝对差均为 0 |
| 第二章 CF core DAS 与第一章 DAS | max abs error `1.136868e-13`；peak-scaled `5.332858e-18` |
| CF core 与 GCF core 的 DAS | max complex difference 为 0 |
| CF 与 DC-only GCF | max difference `9.992007e-16` |
| M0 sweep | 全像素权重不下降，DAS 不变 |
| 已返回图像 | shape 一致、有限值、权重 0–1、加权复数图等于 map×DAS |

日志：[matlab_all_results.txt](matlab_all_results.txt)。深度图修正后的重跑记录：[matlab_analyze_carotid_cf_gcf_depth_dependence_results.txt](matlab_analyze_carotid_cf_gcf_depth_dependence_results.txt)。

本机批处理在计算与导出完成后，退出阶段仍出现已有的 `Settings` 未定义提示；本次退出码为 0。计算和 PNG 已完成，未将这个环境退出问题包装成教程算法修改。

内部一致性不等于独立 USTB CF/GCF reference。权重较高不证明正确目标，剖面更窄不自动证明物理分辨率提升；ROI 与人体图也不提供临床有效性结论。具体解释方法见正文第三部分。

## 5. 重新生成 MATLAB 图

在仓库根目录的 MATLAB 会话中：

~~~matlab
addpath(genpath('D:/USTB'));  % 替换为本机 USTB 路径
cd matlab/02_CF_GCF
export_chapter2_figures
~~~

分阶段或单独一个脚本：

~~~matlab
export_chapter2_figures('concepts')  % 2 个纯向量 demo，无需 USTB
export_chapter2_figures('phantom')   % TheGB、目标和 ROI
export_chapter2_figures('carotid')   % 两个人体 acquisition 与 depth
export_chapter2_figures('analyze_das_vs_cf_point_target')
~~~

输出由 [export_chapter2_figures.m](../../../matlab/02_CF_GCF/export_chapter2_figures.m)控制。入口给定坐标避免后台点击；每个脚本的局部 `clearvars` 与 `close all` 不会破坏导出循环，但仍建议使用独立 MATLAB 会话。重新导出会更新同名 MATLAB PNG 与对应阶段日志，AI 插图保留。

## 6. 建议课件提问

| 配图 | 先让学生预测 |
|---|---|
| 图 1、2 | 同相但一个通道特别强，CF 还会是 1 吗？ |
| 图 3 | 只有 B-mode，能不能补算 CF？ |
| 图 4、7 | 一 bin 相位坡的 CF 低，GCF 高；最终 DAS 为什么仍可能为零？ |
| 图 8 | 低 CF 点的频谱是随机铺开，还是有低频结构？ |
| 图 9、10 | 权重升高与图像变亮分别发生在哪一步？ |
| 图 11–13 | M0 增大保留了目标中心，还是更多外围响应？ |
| 图 14、15 | 更暗的组织纹理能直接叫更好吗？ |
| 图 16 | 除深度之外，有效 M 与物理频带还怎样变化？ |

讲解顺序服务于同一条主线：先建立输入和公式的意义，再观察真实数据，最后讨论怎样验证与选择参数。
