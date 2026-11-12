# 第 6 章配图与课件索引

共 **24 张本地 PNG**：7 张内置 `image_gen` 概念图、8 张 MATLAB 数值教学图，以及 9 张真实 UFF 结果和诊断图。普通说明、标题、图例与坐标使用中文；保留 NSI、DAS、RTB、ZM、DC、Tx、Rx、RF、PSF 等业内名称与数学符号。

中英文独立配图均不纳入 Git；本目录的 Markdown、提示词、校正记录与数值日志可以提交。全新克隆后，需本地生成或取得配图，才能完整预览教程。

## 1. 七张概念图

| 正文图号 | 文件 | 讲解重点 |
|---|---|---|
| 1 | [nsi_pipeline_concept.png](nsi_pipeline_concept.png) | 共享 RF 前端、三路接收、先 Tx 相干合成再包络 |
| 2 | [nsi_null_intuition.png](nsi_null_intuition.png) | 四通道理想相消；Null 是加权输出零点 |
| 4 | [nsi_three_apodizations.png](nsi_three_apodizations.png) | 八阵元 ZM、DC1、DC2 的具体权重 |
| 6 | [nsi_envelope_subtraction.png](nsi_envelope_subtraction.png) | 分别取模再组合，与复数先平均的区别 |
| 8 | [nsi_tx_order.png](nsi_tx_order.png) | 同一分支保留 Tx 相位、各路独立合成 |
| 11 | [nsi_offset_tradeoff.png](nsi_offset_tradeoff.png) | δ 改变 DC 权重，ZM 不变；窄响应与组织保留 |
| 14 | [nsi_sampling_and_task.png](nsi_sampling_and_task.png) | 响应、采样充分性、组织连续性分别判断 |

[初始提示词](imagegen_prompts.md) · [第一轮校正](imagegen_review.md) · [第二轮符号与连线校正](imagegen_review_final.md)。

逐图核对了阵元数量、24 个离散权重、正负号、Null 与方向变量 θ、offset 变量 δ、三路连线、包络次序和输出含义。移除了会混淆权重与方向图的装饰曲线、额外取模和不正确的处理链路。图 8 采用按分支分行的结构，避免跨 Tx 连线交叉造成误解。

这些图解释机制，不按比例。方向图、波形、残差与壁面图标均非测量，不作性能数字或临床证据。

## 2. 十七张 MATLAB 图

| 正文图号 | PNG 文件 | 内容与来源 |
|---|---|---|
| 5 | [demo_nsi_building_blocks_01.png](demo_nsi_building_blocks_01.png) | 奇偶有效孔径的三套精确权重 |
| 3 | [demo_nsi_building_blocks_02.png](demo_nsi_building_blocks_02.png) | 均匀输入与增益失配的代数例子 |
| 7 | [demo_nsi_building_blocks_03.png](demo_nsi_building_blocks_03.png) | 窄带阵列因子、中心 Null 与包络残差 |
| 10 | [demo_nsi_building_blocks_04.png](demo_nsi_building_blocks_04.png) | 随机复数上下界与相对相位 |
| 9 | [demo_nsi_building_blocks_05.png](demo_nsi_building_blocks_05.png) | Tx 相干合成与包络不交换的反例 |
| 12 | [demo_nsi_building_blocks_06.png](demo_nsi_building_blocks_06.png) | 同一阵列因子，仅改变 δ |
| 15 | [demo_nsi_building_blocks_07.png](demo_nsi_building_blocks_07.png) | 连续模型的稀疏采样与峰值错位 |
| 13 | [demo_nsi_building_blocks_08.png](demo_nsi_building_blocks_08.png) | 独立复高斯孔径向量的幅度抑制，不是真实组织模型 |
| 16 | [compare_rtb_das_vs_nsi_01.png](compare_rtb_das_vs_nsi_01.png) | TheGB 密集二维点目标，共同 DAS 参考 |
| 17 | [compare_rtb_das_vs_nsi_02.png](compare_rtb_das_vs_nsi_02.png) | 各自局部峰值剖面与实际三路包络 |
| 19 | [full_fov_delta02_01.png](full_fov_delta02_01.png) | 三份全视野数据，δ=0.2，DAS/NSI 每行共用参考 |
| 20 | [full_fov_delta02_02.png](full_fov_delta02_02.png) | δ=0.2 幅度保留比，明确有效遮罩 |
| 21 | [full_fov_delta08_01.png](full_fov_delta08_01.png) | 同一 D、Z 重算 δ=0.8 的共同参考图 |
| 22 | [full_fov_delta08_02.png](full_fov_delta08_02.png) | δ=0.8 保留比，与 δ=0.2 使用相同遮罩 |
| 18 | [nsi_diagnostics_01.png](nsi_diagnostics_01.png) | 点目标实际网格值、插值交点与半幅宽度 |
| 23 | [nsi_diagnostics_02.png](nsi_diagnostics_02.png) | 同一有效像素集合的保留比累计分布 |
| 24 | [nsi_diagnostics_03.png](nsi_diagnostics_03.png) | 共同参考与自身峰值参考只改变显示 |

## 3. 复现设置与验证范围

从仓库根目录运行：

~~~matlab
addpath(genpath('D:/你的USTB路径'));
addpath('matlab/06_NSI');
export_chapter6_figures('all');
~~~

完整入口说明见[MATLAB README](../../../matlab/06_NSI/README.md)。已验证环境为 MATLAB R2021b、Microsoft YaHei、150 dpi PNG；小例子随机种子为 6。

点目标使用 TheGB 第 1 帧、全部 128 个 focused Tx、281×181 网格、Δx=Δz=0.025 mm。全视野对 TheGB 与两份 carotid 分别使用 385×513 网格、全部 Tx、横向全 Tx 范围、5–45 mm 深度。RTB blended、Tx Tukey25、Tx F#=2、Rx F#=1.7 与第 1 章相同。

δ=0.8 的图直接使用相同的 Tx-compounded D、Z，仅重算线性组合与包络；没有再调采集、孔径、网格或遮罩。

[数值日志](matlab_all_results.txt)包含实际执行的代数检查、点目标与三份全视野复数 DAS 回归、宽度描述和幅度保留统计。四个 DAS 最大峰值归一化误差均为 0；从 D、Z 重算基线 NSI 的归一化差值也均为 0。这不是独立全图 NSI 金标准或临床有效性验证。

本机 MATLAB 在全部导出完成后，退出阶段仍有无法识别 `Settings` 的既有环境提示。该提示与数值检查、图片完成状态分别记录。
