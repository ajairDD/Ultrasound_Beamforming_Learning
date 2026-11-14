# 第 7 章 MATLAB：先理解指标，再运行统一 Benchmark

[教学正文](../../chapters/07_Benchmark/README.md) · [20 张课件图索引](../../chapters/07_Benchmark/figures/README.md)

本目录不新增波束合成算法。它复用第 1–6 章的核心，分为 conventional FI 与密集 RTB 两条轨道，并提供 **7 个无需 UFF 的教学例子、14 张中文 MATLAB 图**。

## 1. 从小例子开始

在仓库根目录：

~~~matlab
addpath('matlab/07_Benchmark');
report = demo_benchmark_building_blocks;
export_chapter7_figures('concepts');
~~~

需要 MATLAB 基础绘图与数值函数，不需要 USTB、UFF 或额外统计工具箱。固定 `rng(7,'twister')`。

七张图依次解释：已知高斯宽度、输出网格采样、合成 ROI 与分箱、CNR/gCNR 的尺度变换、相同分布不同空间排列、CV/相关性的解释、有限样本估计。合成图不冒充声场仿真、TheGB 或真实病灶。

## 2. 运行真实两轨对照

~~~matlab
addpath(genpath('D:/你的USTB路径'));
cd matlab/07_Benchmark
run_chapter7_benchmark
~~~

默认 `benchmark_mode='both'`；可先用 `'fi'` 或 `'rtb'` 单独运行。

| 轨道 | 共同条件 | 输出 |
|---|---|---|
| FI | TheGB，16–24 mm；相同扫描线、Rx F#=1.7；深度约 λ/16 | DAS/CF/GCF/MVDR/fDMAS/SLSC |
| RTB | x=−2.5..1.5 mm、z=18.5..22.5 mm，161×161；全部 Tx；相同 blended/Tukey25/Rx 孔径 | DAS/MVDR/NSI δ=0.2/0.8 |

运行前需准备本地 `data/L7_FI_TheGB.uff`。不混排两轨宽度；fDMAS 的二倍频链路需要足够密的轴向网格；SLSC 不参加 RF 包络宽度排名。

## 3. 输出什么？怎样复用？

默认本地目录 `output/benchmark/ch07/`：

~~~text
FI_metrics.csv         RTB_metrics.csv
FI_images.png          RTB_images.png
FI_configuration.mat   RTB_configuration.mat
FI_results.mat         RTB_results.mat
FI_contrast.csv        （仅显式提供已确认 ROI 时产生）
~~~

新增结果 MAT 用于重绘课件图，不含原始 RF：

| 字段 | 内容 |
|---|---|
| `imgs`、`labels` | 方法图像 cell 与方法名；未取对数的 `[z,x]` 标量图 |
| `x,z` | 坐标，m |
| `fi_table` / `rtb_table` | 本轮实际测量表与计时 |
| `reference_errors` / `scaled` | 内部 DAS 的复数回归误差 |
| RTB 的 `D,Z` | 复数分支，供相同数据上的 NSI 偏置重组 |
| `o` / `common` | 该轨道配置 |

`inspect_benchmark_outputs` 只读这些数值缓存，不重新重建 RF，也不新建病灶标注。所有独立 PNG/FIG 及本地 Benchmark 产物均被 Git 忽略。

## 4. 一次导出 14 张中文 MATLAB 图

从仓库根目录：

~~~matlab
addpath(genpath('D:/你的USTB路径'));
addpath('matlab/07_Benchmark');
export_chapter7_figures('all');
~~~

该入口先运行 7 个小实验，再完整运行两轨 Benchmark、重绘两张比较总图及 5 张真实结果诊断图。

已有当前版本生成的 `FI_results.mat` 和 `RTB_results.mat` 时：

~~~matlab
export_chapter7_figures('cached');
~~~

缓存模式无需 USTB，不依赖旧 PNG/FIG，也不重复 RF 重建；仍会运行小例子与缓存契约检查。图片进入 `chapters/07_Benchmark/figures/`，可编辑 FIG 与文字清单进入被忽略的 `work/pdfs/matlab_figures/`。

## 5. 指标函数的输入合同

- `benchmark_ch7_metrics(img,x,z,opts)`：`img` 为有限、非负、未压缩的 `[z,x]` 标量图，x/z 为 m。
- `opts.point_mm=[x,z]`：在已知点附近搜索局部峰值；两条切片经过该峰值，各自半幅交点做线性插值。
- ROI：`[xmin,xmax,zmin,zmax]`，单位 mm。CV 使用样本标准差，`speckle_SNR` 只是均值/标准差。
- `benchmark_ch7_contrast`：必须显式给定目标与背景两个物理 ROI；每个至少 25 个图像像素，使用共同秩分箱估计 gCNR，并报告实际箱数。
- 不把 dB 图当作原始包络计算 CR/CNR；不把 SLSC 的均值/标准差当作 RF SNR。

## 6. 没有病灶 ROI，就保持未测量

默认 `contrast_rois_mm=[]`。TheGB 本次没有可靠低回声目标/背景标注，**不生成真实 CR/CNR/gCNR**。

只有取得独立确认的区域后，再更换数据并设置：

~~~matlab
fi_filename='../../data/已标注低回声体模.uff';
% 深度范围需按该数据的实际区域设置，以下变量使用 m。
fi_z_min=verified_z_min_m; fi_z_max=verified_z_max_m;

% 两行均为 [xmin xmax zmin zmax]，单位 mm；用真实坐标替换变量。
contrast_rois_mm=[target_xmin target_xmax target_zmin target_zmax; ...
                 background_xmin background_xmax background_zmin background_zmax];
benchmark_mode='fi';
run_chapter7_benchmark
~~~

这里没有给出虚构的目标坐标。换成非 TheGB 文件时，程序也不会继续假定存在该 TheGB 点目标位置。

## 7. 实际验证与计时归属

2026-11-14、MATLAB R2021b：

- 小例子解析宽度、gCNR 边界/变换、换位统计与抽样检查通过。
- FI 五条自适应核心的内部复数 DAS 对第 1 章误差均为 **6.147026e-18**。
- 独立 RTB-MVDR/NSI 核心的基础 DAS 差异为 **0**。
- FI 横向半幅宽度约 0.71147/0.41672/0.62156/0.30669/0.71965 mm；SLSC 不适用。这些宽度仅跨约 1–2.4 个扫描线间隔。
- 密集 RTB 宽度约 0.70632/0.12382/0.16089/0.37254 mm。
- 本轮 RTB 全核心单次时间 **134.90 s**（MVDR + DAS）、**22.86 s**（NSI + D/Z）；独立 DAS 与 NSI δ=0.8 的时间均为 NaN。
- 这些是共同基线、指定数学模型和实际输出契约检查，不是独立全算法论文金标准或临床有效性证明。

[真实运行日志](../../chapters/07_Benchmark/figures/matlab_benchmark_results.txt) · [教学与缓存诊断日志](../../chapters/07_Benchmark/figures/matlab_lecture_results.txt)。MATLAB 输出完成后的既有 `Settings` 退出环境提示另行记录。
