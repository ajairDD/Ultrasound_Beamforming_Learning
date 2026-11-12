# 第三章 MATLAB：把 MVDR 主线变成可运行实验

先读 [第三章完整理论](../../chapters/03_MVDR/README.md)，再按下面顺序运行：**人工向量 → conventional FI → 参数变化 → 密网格 RTB 目标 → 人体数据**。课件图片和实际运行记录见 [配图索引](../../chapters/03_MVDR/figures/README.md)。

## 1. 文件与数据流

| 文件 | 输入 / 作用 | 主要输出 |
|---|---|---|
| [demo_mvdr_building_blocks.m](demo_mvdr_building_blocks.m) | 无外部数据；固定 `rng(3)` 的窄带复数向量 | 权重、子孔径、邻域、加载、失配共 5 张教学图 |
| [reconstruct_fi_mvdr_manual.m](reconstruct_fi_mvdr_manual.m) | UFF RF → conventional FI 的接收 MVDR | `das_analytic,mvdr_analytic[z,scanline]` 与两种 dB 参考 |
| [compare_manual_das_vs_mvdr.m](compare_manual_das_vs_mvdr.m) | 完整二维 DAS / MVDR 对照 | 共同参考和各自峰值参考图像 |
| [experiment_mvdr_tradeoffs.m](experiment_mvdr_tradeoffs.m) | TheGB 目标邻域，四组 `L/M`、loading | 共同参考图像、局部峰归一化剖面和指标 |
| [reconstruct_fi_rtb_mvdr_manual.m](reconstruct_fi_rtb_mvdr_manual.m) | 每个 Tx/pixel 内做接收 MVDR，再跨 Tx 合成 | `rtb_das_analytic,rtb_mvdr_analytic[z,x]`、Tx 支持与 fallback 计数 |
| [compare_rtb_das_vs_rtb_mvdr.m](compare_rtb_das_vs_rtb_mvdr.m) | 同一 RTB 几何的密网格目标对照 | 图像、局部峰、宽度、峰值比与第一章复数回归检查 |
| [compare_carotid_rtb_das_vs_rtb_mvdr.m](compare_carotid_rtb_das_vs_rtb_mvdr.m) | 两组颈动脉 acquisition 中选一组 | 共同参考、灰阶自归一化图、掩膜幅值差图与描述统计 |
| [export_chapter3_figures.m](export_chapter3_figures.m) | 固定课件参数，运行上述教学示例 | PNG 和可复核的数值日志 |

两个核心都经过 `X → R → R_loaded → w → M*mean(w'*X_center)`。空间和轴向平均用于估计权重，最终输出只使用中心深度的子孔径；整个流程保留复数相位。

默认接收 MVDR 使用 Rx F# 1.7、子孔径比例 0.5、相对加载 0.01、约 `±1.5 lambda` 的轴向半窗口，`forward_backward=false`。代码限定二维线阵聚焦成像和实数 RF；EIBMV / RCB 只在正文介绍思路。

## 2. 推荐运行顺序

### 2.1 不依赖 USTB 的五组原理图

~~~matlab
cd D:/Ultrasound_Beamforming_Learning/matlab/03_MVDR
demo_mvdr_building_blocks
~~~

这组例子用 `q` 表示空间相位坡度，单位 cycles/channel，不能把横轴当成 MHz 或角度。函数内部核对单位增益、矩阵共轭、加载后的正定性与理想相干幅度缩放。

### 2.2 完整 conventional FI 图像

~~~matlab
addpath(genpath('D:/USTB'));
cd D:/Ultrasound_Beamforming_Learning/matlab/03_MVDR
filename = '../../data/L7_FI_TheGB.uff';
z_min = 5e-3; z_max = 45e-3; n_z = 256;
receive_f_number = 1.7;
subarray_fraction = 0.5; diagonal_loading = 0.01;
axial_averaging_lambda = 1.5; forward_backward = false;
compare_manual_das_vs_mvdr
~~~

脚本当前默认数据是 `L7_FI_carotid_cross_2.uff`。正文和 phantom 课件显式指定 TheGB，因此可以保留日常使用的 carotid 默认值。

再只改 `axial_averaging_lambda=0` 运行一次，可观察只使用空间子孔径的结果。图片中“common reference”保留与 DAS 的幅度差；“self-normalized”主要展示形态。

### 2.3 一个紧凑的参数实验

~~~matlab
filename = '../../data/L7_FI_TheGB.uff';
experiment_mvdr_tradeoffs
~~~

脚本固定 `z=18–22.5 mm`、`n_z=160`，比较：

| 子孔径比例 | loading |
|---:|---:|
| 0.25 | 0.01 |
| 0.50 | 0.01 |
| 0.75 | 0.01 |
| 0.50 | 0.10 |

四组保留同一 DAS 基线与轴向邻域。这里 conventional 横向间隔约 0.298 mm，MVDR 窄峰可能只有约一个网格间距，应继续看密网格 RTB，不能把插值宽度当作精确分辨率证据。

### 2.4 密网格 RTB 点状目标

~~~matlab
filename = '../../data/L7_FI_TheGB.uff';
x_min = -4e-3; x_max = 3e-3; n_x = 281;
z_min = 18e-3; z_max = 22.5e-3; n_z = 181;
subarray_fraction = 0.5; diagonal_loading = 0.01;
axial_averaging_lambda = 1.5; forward_backward = false;
run_rtb_reference_check = true;
compare_rtb_das_vs_rtb_mvdr
~~~

这组参数对应正文的 `dx=dz=0.025 mm`。脚本自身的默认 `n_x=141` 对应 `dx=0.05 mm`；复现课件需显式使用上面的 281。

RTB 使用 `blended` Tx delay、`blending_power=0.5`、Tx F# 2、最小支持 3 mm、`tukey25`、Rx F# 1.7 和全部 Tx。配置中的 `pw_margin=1 mm` 仅在 `hybrid` 分支生效，本次 `blended` 不使用它。

脚本检查 RTB-DAS 是否重现第一章 RTB 核心。当前密网格图实际得到横向半幅宽 `0.7063 → 0.1238 mm`，局部峰值变化 `−2.893 dB`。应同时展示宽度与峰值代价；完整结果见 [phantom 日志](../../chapters/03_MVDR/figures/matlab_phantom_results.txt)。

### 2.5 人体数据：明确重设 ROI，避免继承目标网格

~~~matlab
dataset_index = 1;        % 第二组改成 2
x_min = -10e-3; x_max = 10e-3; n_x = 161;
z_min = 8e-3; z_max = 25e-3; n_z = 171;
wave_stride = 2;
subarray_fraction = 0.5; diagonal_loading = 0.01;
axial_averaging_lambda = 1.5; forward_backward = false;
compare_carotid_rtb_das_vs_rtb_mvdr
~~~

这里 `dx=0.125 mm,dz=0.1 mm`，选用 64 次 Tx。每组数据内 DAS / MVDR 共用同一 Tx 子集，不把两次独立 acquisition 当作相邻帧。

B-mode 使用灰阶，幅值差使用单独的彩色轴。差图的灰色背景表示不满足 `DAS>=−40 dB` 或没有 Tx 支持，不表示那里实测到 −20 dB 抑制。日志统计用未裁剪包络，不受这次显示修正影响。

## 3. 一键重生成课件图

在新 MATLAB 会话中运行：

~~~matlab
addpath(genpath('D:/USTB'));
cd D:/Ultrasound_Beamforming_Learning/matlab/03_MVDR
export_chapter3_figures
~~~

可选择一类：

~~~matlab
export_chapter3_figures('concepts')   % 无 USTB / UFF 依赖
export_chapter3_figures('phantom')
export_chapter3_figures('carotid')
~~~

也可只运行一个 exporter job，例如：

~~~matlab
export_chapter3_figures('compare_manual_das_vs_mvdr_axial')
export_chapter3_figures('compare_rtb_das_vs_rtb_mvdr')
export_chapter3_figures('compare_carotid_rtb_das_vs_rtb_mvdr_cross2')
~~~

输出位于 `chapters/03_MVDR/figures/`，PNG 分辨率为 150 dpi；日志记录 MATLAB 版本、固定参数、网格、幅值 / 宽度指标与回归结果。原脚本会清理自身变量并关闭图窗，exporter 用独立 helper workspace 承接它们，因此适合集中导图。

Exporter 还为密网格目标增加一张 2×2 剖面课件图：横向 / 轴向分别展示共同 DAS 目标峰参考与各自局部峰参考。图像算法和测宽定义不变。

## 4. 本次真正核对了什么

本次已经运行人工向量、两个 conventional 轴向设置、四组参数、密网格 RTB 与两个 carotid acquisition，共导出 18 张 MATLAB PNG。具体参数、数据 MD5 与日志见 [配图索引](../../chapters/03_MVDR/figures/README.md)。

验证包括：

- 单位增益、共轭二阶矩、理想相干输入的 `M*A` 幅度；
- 输出的 `[z,x]` 形状、复数有限值及 `envelope=abs(analytic)`；
- 两个 conventional DAS 与第一章独立核心的最大峰值归一化复数误差约 `1.071e-17`；
- 密网格 RTB-DAS 与第一章 RTB 的复数误差为 0；
- 四组参数的 DAS 基线一致，图中的宽度从未裁剪线性包络测量。

人体数据本次运行的是上述 `stride=2` 网格；没有重新运行 `stride=1` 的更密人体实验。扩展算法与临床性能也未作为本次验证结果。
