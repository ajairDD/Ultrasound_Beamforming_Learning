# 第 8 章配图与课件索引

共 **19 张本地 PNG：6 张内置 image_gen 概念图 + 13 张实际 MATLAB 图**。所有普通解释文字、标题与坐标中文化，业内名称和代码符号保留。独立图片全部被 Git 忽略；全新克隆后需本地生成或取得图片。

## 六张概念图

| 正文图号 | 文件 | 讲解重点 |
|---|---|---|
| 1 | [rtb_shared_frontend.png](rtb_shared_frontend.png) | 公共 RTB 输出进入四类处理路径，明确运算次序 |
| 2 | [rtb_pixel_geometry.png](rtb_pixel_geometry.png) | 同一候选 P、多次 Tx、不同于 P 的焦点 |
| 3 | [rtb_seven_mechanisms.png](rtb_seven_mechanisms.png) | 七种通道组合规则 |
| 10 | [rtb_output_types.png](rtb_output_types.png) | 幅度、非线性频带、无量纲相关的区别 |
| 11 | [rtb_display_reference.png](rtb_display_reference.png) | 归一化隐藏或呈现峰值差异 |
| 12 | [rtb_metadata_bridge.png](rtb_metadata_bridge.png) | 轴、单位、通道身份和 RF/IQ 相位约定 |

[完整初稿提示词](imagegen_prompts.md) · [第一轮科学校正](imagegen_review.md) · [共享前端箭头与符号校正](imagegen_review_final.md)。

已逐项修正：公共总线位于 RTB 前端之后；D/Z 为并行分支；NSI 使用三路包络组合；fDMAS 先带符号开方；SLSC lag 为物理通道间隔且按有效 Tx 权重平均；GCF 低频能量是标量权重；归一化比较同一目标的不同处理；IQ 不假定未知相位参考。

图 2 用焦后像素解释几何，本轮真实 TheGB 目标则在 Tx 焦点前；均按相应传播时间模型重建。所有示意画面、方向图、波形与峰高不作实验读数或临床证据。

## 七张无需 UFF 的 MATLAB 图

| 正文图号 | 文件 | 内容 |
|---|---|---|
| 4 | [demo_rtb_method_building_blocks_01.png](demo_rtb_method_building_blocks_01.png) | CF 的 Tx 内权重与合成次序 |
| 5 | [demo_rtb_method_building_blocks_02.png](demo_rtb_method_building_blocks_02.png) | 空间谱、CF 与 GCF(M0=0/1) |
| 6 | [demo_rtb_method_building_blocks_03.png](demo_rtb_method_building_blocks_03.png) | 解析协方差的 MVDR 约束 |
| 7 | [demo_rtb_method_building_blocks_04.png](demo_rtb_method_building_blocks_04.png) | 带符号开方与二倍频配对示例 |
| 8 | [demo_rtb_method_building_blocks_05.png](demo_rtb_method_building_blocks_05.png) | 幅度与近邻相关的区别 |
| 9 | [demo_rtb_method_building_blocks_06.png](demo_rtb_method_building_blocks_06.png) | 固定 D/Z 的 NSI 偏置对照 |
| 13 | [demo_rtb_method_building_blocks_07.png](demo_rtb_method_building_blocks_07.png) | IQ 查询时刻的载频相位恢复 |

源文件：[demo_rtb_method_building_blocks.m](../../../matlab/08_RTB_Comparison/demo_rtb_method_building_blocks.m)。种子 `rng(8,'twister')`，只用 MATLAB 基础功能。模型明确区分于声场/组织/真实采集。

## 六张真实 UFF 结果图

| 正文图号 | 文件 | 内容 |
|---|---|---|
| 14 | [rtb_seven_methods_own.png](rtb_seven_methods_own.png) | 自身峰值 dB；SLSC 线性 |
| 15 | [rtb_seven_methods_common.png](rtb_seven_methods_common.png) | 共同 DAS 参考，fDMAS/SLSC 保留例外 |
| 16 | [rtb_diagnostics_01.png](rtb_diagnostics_01.png) | Tx 孔径支持与数据覆盖 |
| 17 | [rtb_diagnostics_02.png](rtb_diagnostics_02.png) | 固定同一 DAS 峰值深度的两种参考 |
| 18 | [rtb_diagnostics_03.png](rtb_diagnostics_03.png) | 固定横向位置的轴向形状与记录频带 |
| 19 | [rtb_diagnostics_04.png](rtb_diagnostics_04.png) | 同像素的幅度与原始/显示 SLSC |

使用本轮 `RTB_seven_methods_results.mat` 中的实际输出；坐标 `[245,64]`、32/128 Tx、Δx≈0.11111 mm、Δz≈0.018443 mm。fDMAS 右图的频带来自配置，不冒充实测 RF 频谱。没有使用第 7 章的宽度数字，也没有新增真实病灶指标。

## 复现与实际验证

~~~matlab
% 从仓库根目录
addpath(genpath('D:/你的USTB路径'));
addpath('matlab/08_RTB_Comparison');
export_chapter8_figures('all');
% 有 image_results 后可改用 cached，不重复真实重建。
~~~

[MATLAB 说明](../../../matlab/08_RTB_Comparison/README.md) · [集成与回归日志](matlab_integration_results.txt) · [教学与缓存检查](matlab_lecture_results.txt)。

2026-11-14、MATLAB R2021b、Microsoft YaHei、150 dpi。标准输入合成检查通过；独立 TheGB 复数 DAS 回归误差 6.533229e-16，Tx 权重差 0；七方法联合运行 37.16 s，MVDR fallback 0/61289、SLSC 无效 pixel-Tx 0。

这些检查不等于跨厂商真实输入验收，也不等于每个方法已通过独立算法金标准或临床验证。既有 Settings 退出环境提示单独记录。
