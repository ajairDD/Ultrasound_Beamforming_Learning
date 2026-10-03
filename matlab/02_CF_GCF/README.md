# Chapter 2 MATLAB：从 DAS 到 CF / GCF

先读[第二章教程](../../chapters/02_CF_GCF/README.md)的理论主线，再按下面的顺序运行。本目录沿用 Chapter 1 的 conventional FI-DAS：一个像素对应一次 Tx，对已对齐的 **active Rx 复数向量**计算权重，再乘到同一个 DAS 复数像素上。

~~~text
真实 RF → analytic RF → Tx/Rx 延时与插值 → active Rx 向量
                                         ├→ 相干求和 → DAS
                                         └→ CF / GCF 权重 → DAS × 权重
~~~

## 运行准备

在 MATLAB 中进入本目录，并设置：

~~~matlab
addpath(genpath('D:/USTB'));
addpath('../01_DAS_Real_UFF');
~~~

两个 `demo_*` 人工向量示例不需要 USTB 或数据。真实数据默认 `../../data/L7_FI_TheGB.uff`；人体扩展使用 `L7_FI_carotid_cross_1.uff`、`L7_FI_carotid_cross_2.uff`。

本章真实数据代码的范围是二维 x-z、正深度 spherical FI、实 RF、binary boxcar 接收孔径，默认 frame 1、深度 5–45 mm、Rx F-number 1.7。它研究 **receive-domain coherence**；RTB 的 Tx 相干加权不在本章实现范围内。

## 按主线运行

| 顺序 | 入口 | 要回答的问题 |
|---|---|---|
| 1 | `demo_cf_aperture_vectors` | 同相、相位误差、随机相位、强离群通道怎样改变 CF？ |
| 2 | `demo_cf_failure_and_gcf_motivation` | 平滑 phase ramp 为什么 CF 低，却能被邻近 FFT bins 捕捉？ |
| 3 | `inspect_real_cf_aperture_vectors` | 真实像素的 aligned Rx 向量是什么，能否重现 Chapter 1 DAS？ |
| 4 | `compare_manual_das_vs_cf` | CF 权重图怎样改变同一张 DAS？共同参考和各自归一化有何差别？ |
| 5 | `compare_manual_das_cf_gcf` | 允许邻近 spatial-frequency bins 后，GCF 与 CF 有何变化？ |
| 6 | `experiment_gcf_m0_sweep` | `M0=[0 1 2 4]` 如何改变抑制强度？ |

第三步默认在图中点击三个像素，然后 snap 到实际 scanline 与 z-grid。脚本检查 `sum(aligned active samples)` 是否重现 Chapter 1 的复数 DAS 像素；主要误差以 `sum(abs(s))` 归一化，避免接近相消的 DAS 值使相对误差膨胀。

第四步独立调用 Chapter 1 DAS，验证同样的延时、插值和孔径确实得到同样的 baseline。第五步同时验证 CF 与 GCF 内部 DAS 相同、`GCF(M0=0)==CF`。

### 核心函数与参数约定

| 函数 | 输出的权重 | 主要复数输出 |
|---|---|---|
| `reconstruct_fi_cf_manual(filename,opts)` | `cf_map` | `das_analytic`、`cf_analytic` |
| `reconstruct_fi_gcf_manual(filename,opts)` | `gcf_map` | `das_analytic`、`gcf_analytic` |

以上图像数组均为 `[n_z,N_waves]`，第二维是 conventional FI scanline；`x_axis`、`z_axis` 单位为 m。权重为实数，名义范围 `[0,1]`；复数图保留 DAS 的相位。包络只在相干求和和加权完成后取绝对值。

本仓库 `M0` 是孔径 FFT 低频**半宽**：

~~~text
M0=0 → {0}            → CF
M0=1 → {-1,0,+1}      → 3-bin GCF
M0=2 → {-2,...,+2}    → 5-bin GCF
M0=4 → {-4,...,+4}    → 9-bin GCF
~~~

`demo_cf_failure_and_gcf_motivation` 用 `K` 表示同一教学半宽。本仓库的 `M0=1` 不能直接套用到存在 legacy special case 的 USTB GCF 实现；本章没有提供 USTB GCF 数值对照脚本。

短 active aperture 采用 `effective_M0=min(M0,floor(M/2))`，FFT bins 去重后求和，避免重复统计 even-length Nyquist bin。GCF 输出还包括 `effective_M0_map`、`band_clipped_mask` 与 `band_clipped_fraction`。

~~~matlab
opts = struct('n_z',512,'receive_f_number',1.7,'M0',1);
gcf = reconstruct_fi_gcf_manual('../../data/L7_FI_TheGB.uff',opts);
~~~

### 先看共同参考，再看形态

`cf_db_common` / `gcf_db_common` 使用同一数据集的 DAS peak 为 0 dB，便于比较线性包络被抑制多少。`*_db_self` 使用每种方法自己的 peak，便于观察形态，但会隐藏全局衰减。dB 图采用 `20*log10(envelope/reference)`，默认显示动态范围 60 dB。

## 单因素扩展实验

| 入口 | 默认设置 | 观察内容 |
|---|---|---|
| `analyze_das_vs_cf_point_target` | `n_z=1024` | 独立局部峰值、峰值衰减、横向/轴向半幅宽度与 -20 dB profile width |
| `analyze_gcf_m0_point_target` | `n_z=512; M0_values=[0 1 2]` | 放宽低频带对目标峰值和剖面的影响 |
| `analyze_gcf_speckle_roi` | `n_z=512; M0_values=[0 1 2 4]` | 均值衰减、std ratio、mean/std、CV、与 DAS 包络纹理的相关性 |
| `compare_carotid_fi_cf_gcf_oneclick` | `n_z=512; M0=1` | 两次独立人体采集的 DAS / CF / GCF、权重及差值图 |
| `analyze_carotid_cf_gcf_depth_dependence` | `n_z=512; M0=1` | 中央 80% scanline 的权重 median/IQR、信号与 active Rx 数随深度变化 |

`experiment_gcf_m0_sweep` 默认 `n_z=256` 以缩短参数扫描时间；选定感兴趣的 `M0` 后可用 `compare_manual_das_cf_gcf` 的 512 点深度网格查看。

点目标脚本各自归一化剖面来观察形态，并单独打印共同线性参考下的峰值衰减。常规 FI 的横向采样由 scanline 间距决定；半幅宽度若只跨少于三个间隔，只能视为采样受限的粗估。自适应加权后剖面变窄不等于采集的衍射极限改变；-20 dB width 用于观察裙边，不是独立、严格的旁瓣指标。

Speckle ROI 指标描述所选区域被改变了多少，不证明该区域服从理想 Rayleigh 模型，也不证明诊断质量改善。人体两行分别使用各自采集的 DAS peak，不能比较两行绝对亮度；深度趋势还同时受到 signal level 与动态接收孔径等因素影响。

## 非交互复现坐标

除保留原来的点击选择，还可在运行前指定位置，适合课件导出：

~~~matlab
selected_pixels_mm = [-0.75 20.05;8 22;10 10]; % 三行 [x,z]，单位 mm
inspect_real_cf_aperture_vectors

target_x_mm = -0.75;
target_z_mm = 20.05;
analyze_das_vs_cf_point_target

target_x_mm = -0.75;
target_z_mm = 20.05;
analyze_gcf_m0_point_target

roi_corners_mm = [5 18;11 24]; % 两个对角点 [x,z]，单位 mm
analyze_gcf_speckle_roi
~~~

这些固定点与 ROI 是可复现的教学示例；其物理类别不由坐标或相干权重自动确定。实际 pixel/ROI 范围由重建网格决定，脚本会报告 snap 后的位置与大小。

## 一键生成课件 PNG 与日志

~~~matlab
export_chapter2_figures('all');       % 全部 11 个示例
export_chapter2_figures('concepts');  % 仅两个人工向量示例，无需 USTB
export_chapter2_figures('phantom');   % TheGB 的真实向量、全图、参数与 ROI
export_chapter2_figures('carotid');   % 两个人体示例
export_chapter2_figures('compare_manual_das_cf_gcf'); % 只运行一个示例
~~~

输出到 [Chapter 2 figures](../../chapters/02_CF_GCF/figures/)：`<script>_01.png` 等 150 dpi PNG，以及 `matlab_<section>_results.txt` 参数和数值日志。默认导出设置与上表一致，目标 seed `(-0.75,20.05) mm`，三点与 ROI 使用上面的固定坐标。

Exporter 会暂时隐藏 figure 并恢复原设置；脚本会清理自身工作区和关闭图窗，建议用新的 MATLAB session 运行。它检查图像/权重尺寸、权重范围、复数加权关系、M0 sweep 的全像素单调性；各示例仍执行原有的 baseline 与 CF/GCF identity 检查。

下一章计划进入 MV / MVDR / Capon。
