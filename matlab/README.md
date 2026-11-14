# MATLAB 实践总指南

本项目的算法实验统一使用 MATLAB。**先读章节正文建立直觉，再按该章“快速开始”运行代码**；不必第一次就阅读所有底层函数。

[返回课程首页](../README.md) · [获取数据](../data/README.md) · [中文 PDF 讲义](../output/pdf/README.md)

## 环境与数据准备

| 学习范围 | 最低准备 | 说明 |
|---|---|---|
| 第 0 章 | MATLAB | 合成点目标、延时、孔径和 PSF，无需 USTB/UFF |
| 第 1–8 章的 `demo_*` 原理小实验 | 通常只需 MATLAB | 无数据例子的具体依赖以各章 README 为准 |
| 第 1–8 章的真实 UFF 实验 | MATLAB + USTB + 对应 UFF | 默认使用 `data/L7_FI_TheGB.uff`；部分扩展实验还需其他 UFF |
| `RTB_Universal` / `run_all_checks` | MATLAB + USTB + TheGB UFF（真实数据路径） | 部分合成接口检查可脱离 USTB/UFF |

在 MATLAB 中把当前文件夹设为**仓库根目录**，将 USTB 目录加入搜索路径（只在需要真实数据时）：

~~~matlab
addpath(genpath('D:/你的USTB路径')); % 改成本机 USTB 路径
~~~

原始 UFF 不纳入 Git；请按 [data/README.md](../data/README.md) 的下载说明放入 `data/`。不要仅按文件名假定 RF/IQ 类型或采集参数。

## 各章最短运行入口

下列命令默认在**仓库根目录**启动 MATLAB；依赖和完整运行顺序见每章的运行说明。

| 章 | 无外部数据的入门示例 | 真实数据的建议入口 | 说明 |
|---|---|---|---|
| [0](00_Fundamentals/README.md) | `demo_synthetic_point_target` | 不适用 | 从 synthetic RF 和 DAS 开始 |
| [1](01_DAS_Real_UFF/README.md) | 无单独的零数据入门示例 | `inspect_uff_metadata_ustb` → `das_fi_scanline_manual` | UFF / USTB / 手写 DAS |
| [2](02_CF_GCF/README.md) | `demo_cf_aperture_vectors` | `compare_manual_das_cf_gcf` | 保持 FI-DAS 基线 |
| [3](03_MVDR/README.md) | `demo_mvdr_building_blocks` | `compare_manual_das_vs_mvdr` | 先理解 covariance / loading |
| [4](04_DMAS/README.md) | `demo_dmas_building_blocks` | `compare_fi_das_vs_fdmas` | real-RF 配对与滤波 |
| [5](05_SLSC/README.md) | `demo_slsc_building_blocks` | `compare_fi_das_vs_slsc` | 相关性与幅度图不能混为一谈 |
| [6](06_NSI/README.md) | `demo_nsi_building_blocks` | `compare_rtb_das_vs_nsi` | 先运行点目标，再看全视野 |
| [7](07_Benchmark/README.md) | `demo_benchmark_building_blocks` | `run_chapter7_benchmark` | 先了解指标再做两轨比较 |
| [8](08_RTB_Comparison/README.md) | `demo_rtb_method_building_blocks` | `run_chapter8_rtb_comparison` | 使用 RTB_Universal 共同前端 |

例如，从根目录开始第 5 章零数据示例：

~~~matlab
addpath('matlab/05_SLSC');
demo_slsc_building_blocks
~~~

执行真实数据实验时通常进入该章目录，以保证相对数据路径正确：

~~~matlab
addpath(genpath('D:/你的USTB路径'));
cd matlab/05_SLSC
compare_fi_das_vs_slsc
~~~

进入其他章节时，修改目录与入口脚本即可。每章 `README.md` 会给出额外的依赖路径、可选参数、输出和验证范围；不要把本表当作覆盖所有实验的执行脚本。

## 共享模块与验证

- [RTB_Universal](RTB_Universal/README.md)：第 8 章使用的标准数据接口与统一 RTB 重建；当前支持范围和跨厂商限制见接口文档。
- `run_all_checks.m`：仅用于复验共享前端与部分集成基线，不替代各算法独立数值验证。
- `export_figure_zh_cn.m` 等：中文课件图导出辅助函数；完整流程见 [配图与 PDF 构建说明](../tools/pdf/README.md)。

~~~matlab
% 在仓库根目录：
cd matlab
run_all_checks
% USTB 不在默认位置时，也可：
% run_all_checks('D:/你的USTB路径')
~~~

第 7–8 章的图、CSV、MAT 等本地输出位于 `output/benchmark/`，不纳入 Git。**验证输出、真实算法核心与生成课件图片是不同用途的入口**，第一次学习建议先运行该章最短示例。

## 科学代码约定

1. **单位明确：** 声速 m/s，频率 Hz，空间位置 m；显示时转 mm/µs 应显式换算。
2. **维度明确：** 先识别 sample、Rx channel、Tx / wave、frame 的物理含义，再操作数组。
3. **保留复数相位：** coherent sum 前不能随意 `abs(IQ)`；MATLAB 的 `'` 是共轭转置。
4. **显示参考明确：** amplitude 对应 `20*log10`，power 对应 `10*log10`；own/common 参考不可混淆。
5. **先验证再优化：** Tx/Rx delay、插值、孔径和 reference 对齐以后，再考虑向量化、GPU 或加速。

此前的目录示意只列出了第 0–1 章；现在以本页第 0–8 章总表和各章目录为准。实验所需的 MATLAB 版本、工具箱及独立验证结果以具体章节说明为准。
