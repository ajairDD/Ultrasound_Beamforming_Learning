# 第 8 章 MATLAB：七种方法沿同一条 RTB 数据流输出

[教学正文](../../chapters/08_RTB_Comparison/README.md) · [19 张课件图索引](../../chapters/08_RTB_Comparison/figures/README.md)

本目录保留固定 TheGB 参数的一键入口，并提供 **7 个无需 UFF 的机制例子、13 张中文 MATLAB 图**。重建复用 `../RTB_Universal/`；本次没有改写七种方法的重建核心。

## 1. 先运行机制例子

从仓库根目录：

~~~matlab
addpath('matlab/08_RTB_Comparison');
report = demo_rtb_method_building_blocks;
export_chapter8_figures('concepts');
~~~

固定 `rng(8,'twister')`，无需 USTB/UFF 或额外工具箱。七张图对应：

1. CF 的 Tx 内权重与 Tx 合成不可随意交换。
2. Rx 孔径 FFT、CF=GCF(M0=0) 与 M0=1 的区别。
3. 指定解析协方差模型的 MVDR 目标增益约束。
4. fDMAS 带符号开方、配对恒等式与约二倍频滤波。
5. 幅度变化与归一化近邻相关的区别。
6. 同一 D、Z 下 NSI 两种偏置的输出。
7. 声明 IQ 约定以后，在各查询时刻恢复载频相位。

解析阵列/协方差图不是 TheGB PSF；随机通道不是组织真值；IQ 模型的约定也不是任意设备的默认约定。

## 2. 运行真实 TheGB 七方法

~~~matlab
addpath(genpath('D:/你的USTB路径'));
cd matlab/08_RTB_Comparison
out = run_chapter8_rtb_comparison;
~~~

需要本地 `data/L7_FI_TheGB.uff`。固定参数在函数内的 `cfg`，主要条件为：

| 项目 | 值 |
|---|---|
| 方法 | DAS/CF/GCF/MVDR/FDMAS/SLSC/NSI |
| 网格 | x=−4..3 mm，64 点；z=18..22.5 mm，按约 λ/16 得到 245 点 |
| Tx | 128 次中按 stride=4 选择 32 次 |
| 前端 | blended，blending_power=0.5；Tukey25，Tx F#=2，最小孔径 3 mm；Rx F#=1.7 |
| 方法参数 | GCF M0=1；MVDR fraction=0.5/loading=0.01/axial=1.5λ；SLSC lag_fraction=0.15/max_lag=12/axial=1λ；NSI δ=0.8 |
| fDMAS | 实 RF 带符号开方后配对，Tx 合并后在深度轴按 `[1.5,1.75,2.5,2.75]f0` 滤波 |

本轮横向间距约 **0.11111 mm**，轴向约 **0.018443 mm**。它与第 7 章的密集 RTB 网格、全部 Tx 条件不同，不移用第 7 章的宽度数字。

## 3. 输出与显示参考

本地 `output/benchmark/ch08/`：

~~~text
RTB_seven_methods_own.png
RTB_seven_methods_common.png
RTB_seven_methods_results.mat
~~~

MAT 中的 `image_results` 保存图像、配置、坐标和诊断，不嵌入原始 RF。

| 字段 | 解释 |
|---|---|
| `out.images.*` | 未对数压缩的实数 `[z,x]`；SLSC 保留有符号相关 |
| `out.rtb_das_analytic` | 共同 DAS 复数 `[z,x]` |
| `x_axis_m,z_axis_m` | 一维坐标，m |
| `display` | 各自全图峰值 dB；SLSC 例外，为裁到非负的线性值 |
| `display_common_db` | 共同 DAS 参考；FDMAS/SLSC 明确留空 |
| `slsc_valid_mask` | 无有效相关估计的位置，独立于测得的零值 |
| `active_tx_count,tx_weight_sum,valid_rx_tx_fraction` | 孔径支持与记录数据覆盖 |
| `fdmas_filter` | 实际使用的深度等效时间采样率与带通边缘 |
| `diagnostics,options` | 实际诊断和参数，包括所选 Tx |

`rtb_show_methods(out,'own')` 用于形状对照；`'common'` 切换可用分支的参考。**fDMAS 始终自身峰值，SLSC 始终线性相关**。改 `out.options` 仅改变记录，不能重算已存在的图像。

## 4. 导出 13 张中文 MATLAB 课件图

从仓库根目录：

~~~matlab
addpath(genpath('D:/你的USTB路径'));
addpath('matlab/08_RTB_Comparison');
export_chapter8_figures('all');
~~~

完整模式执行七个机制例子、标准输入合成测试、独立第 1 章复数 DAS 回归、真实七方法实验，再生成 own/common 及 4 张诊断图。

已有结果 MAT 后，可无需 USTB、不重复重建：

~~~matlab
export_chapter8_figures('cached');
~~~

缓存模式重新运行小例子并检查保存输出的类型、形状、NSI 上界与显示例外，再重画图像。PNG 在 `chapters/08_RTB_Comparison/figures/`；可编辑 FIG 与文字清单在被忽略的 `work/pdfs/matlab_figures/`。

四张真实诊断图分别解释 Tx 支持与数据覆盖、固定切片的两种参考、fDMAS 轴向形态与记录频带、同像素的幅度与相关性。它们没有新增病灶 ROI 或本轮 FWHM 排名。

## 5. 实际运行与验收范围

2026-11-14、MATLAB R2021b：

- 输入接口合成检查通过。
- 独立复数 RTB-DAS 回归误差 **6.533229e-16**；Tx 权重差 **0**。
- 七方法均输出有限 `[245,64]` 图像；选中 **32/128** 次 Tx。
- MVDR fallback **0/61289**，SLSC 无效 pixel-Tx **0**。
- 本轮联合全流程 **37.16 s**，不是逐算法独立耗时。
- 七个新增机制例子的代数、CF/GCF、配对、NSI 与 IQ 相位检查通过。

[真实运行/回归日志](../../chapters/08_RTB_Comparison/figures/matlab_integration_results.txt) · [教学与保存输出检查日志](../../chapters/08_RTB_Comparison/figures/matlab_lecture_results.txt)。

此前的 41.37/38.66 s 属于不同单次运行。当前结果不代表其它厂商 raw/metadata 已验收，也不是 fDMAS/SLSC RTB 扩展的独立算法真值验证。尚无本轮可靠病灶标注及客观检出指标。导出完成后的既有 `Settings` 退出提示属于本机环境记录。

## 6. 输入适配或修改时先查哪里？

- 学习共享运算流程：`rtb_reconstruct_all.m`。
- 数据轴/单位/物理 Rx 映射：`rtb_from_vendor_array.m` 和 `rtb_load_acquisition.m`。
- 时序覆盖：`rtb_audit_source`。
- 独立基线：`test_rtb_universal_vs_chapter1`，失败时先查几何与时序。
- 图中文字和参考：`rtb_show_methods.m`。
- 本目录的 `inspect_rtb_comparison_outputs.m` 只读结果，不调整重建参数。

本接口面向二维线阵 focused FI。RF 支持七种方法；显式声明相位参考的 IQ 支持 DAS/CF/GCF/MVDR/NSI，本实现的 RF-fDMAS/RF-SLSC 不自动由 IQ 替代。完整元数据合同见 [RTB_Universal README](../RTB_Universal/README.md)。
