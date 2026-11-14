# 第 8 章实验代码：相同 RTB 几何下的七算法对比

教学正文与实验分析：[第 8 章：七种方法统一 RTB 对照](../../chapters/08_RTB_Comparison/README.md)。

本目录只保留一个固定参数的**复现实验入口**，底层算法复用 `../RTB_Universal/`，不复制重建内核。此前的跨设备接口文档在 [RTB_Universal/README.md](../RTB_Universal/README.md)。

## 一次运行

MATLAB 先打开仓库根目录或使用完整路径，并加入 USTB：

~~~matlab
addpath(genpath('D:/你的USTB路径'));
cd matlab/08_RTB_Comparison
out = run_chapter8_rtb_comparison;
~~~

默认使用 `data/L7_FI_TheGB.uff`，相同波束几何、32 个 Tx（128 中 stride=4）、`x=-4..3 mm`、`z=18..22.5 mm`、`n_x=64`，重建 DAS/CF/GCF/MVDR/fDMAS/SLSC/NSI。所有参数都显式保存在脚本中。

该实验与用户完成标题修复后的 `demo_rtb_universal` 快速预览一致。本地运行将显示两张对比 Figure，并导出：

~~~text
output/benchmark/ch08/RTB_seven_methods_own.png
output/benchmark/ch08/RTB_seven_methods_common.png
output/benchmark/ch08/RTB_seven_methods_results.mat
~~~

- **Figure own**：除 SLSC 外每图自峰值 0 dB。
- **Figure common**：DAS/CF/GCF/MVDR/NSI 参考统一 DAS 峰值；**fDMAS 始终自峰值**（幅度量纲不同），**SLSC 始终线性相干性**。
- **MAT**：保存图像、坐标、算法参数和诊断结果，不保存原始 RF 数据。

## 已验收与限制

根据用户在本地 MATLAB 提供的运行日志：

- TheGB 数据的独立复数 RTB-DAS 基线误差：`6.533229e-16`；Tx 权重差异：`0`。
- 七方法均成功运行，总流程 `41.37 s`；MVDR fallback `0/61289`；SLSC 无效估计 `0`。
- own/common 两幅图中的七个方法标题已由用户截图确认正常显示。

**注意**：以上 41.37 s 为此前 `demo_rtb_universal` 的一次联合完整运行时间，并非本脚本单独测得，也不是各算法的独立耗时。此新封装脚本在当前助手环境没有 MATLAB，尚未亲自执行；它调用的是之前已在用户机器完成集成运行的相同核心。跨设备兼容性及 fDMAS/SLSC RTB 扩展仍需进一步验证。

如仅需显示已有 `out`，不必重复重建：

~~~matlab
addpath('../RTB_Universal')
rtb_show_methods(out,'own');
rtb_show_methods(out,'common');
~~~
