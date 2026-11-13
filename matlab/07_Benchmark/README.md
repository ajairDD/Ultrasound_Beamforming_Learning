# Chapter 7 MATLAB — Unified Benchmark

一个入口，两个独立比较组，复用 Chapter 1–6 已有代码。**已于 2026-11-13 通过用户本地 TheGB UFF 实验验证并完成第 7 章教学 Benchmark**（不包括未标注 ROI 的 lesion detectability 评价）。

## 一键运行

~~~matlab
addpath(genpath('D:/你的USTB路径'));
cd matlab/07_Benchmark
run_chapter7_benchmark
~~~

默认同时运行 FI 和 RTB 两组。RTB-MVDR 的 full-core 计算量较大，可拆开执行：

~~~matlab
benchmark_mode='fi';
run_chapter7_benchmark

benchmark_mode='rtb';
run_chapter7_benchmark
~~~

### Track A: FI

~~~text
L7_FI_TheGB.uff, z 16–24 mm
same scanlines, Tx/Rx timing, Rx F#1.7
n_z automatically derived from lambda/16
DAS/CF/GCF(M0=1)/MVDR/fDMAS/SLSC
~~~

每个方法内部 complex DAS 与独立 Chapter 1 FI-DAS 做 peak-scaled regression，阈值 1e-10。表里记录 FWHM、speckle ROI CV、与 DAS 的 envelope correlation 和 full-core runtime。

默认 speckle ROI [-12,-8,18,22] mm 没有独立验证为 homogeneous；不能据此证明真实 speckle fidelity。fDMAS 的幅度不能直接与 DAS 比；SLSC 的 linear coherence 不与 DAS amplitude FWHM 比。

### Track B: RTB

~~~text
TheGB point target near x=-0.745,z=20.1 mm
x [-2.5,1.5] mm, n_x=161, dx=0.025mm
z [18.5,22.5] mm, n_z=161, dz=0.025mm
RTB-DAS / MVDR / NSI c=0.2 / NSI c=0.8
~~~

RTB-MVDR 与 NSI 的独立复数 DAS 需要一致；否则拒绝产生比较指标。**本次实测误差为 0**。NSI 的两个 c 只重建一次 D/Z，另一幅从数学上直接重组，不能把第二个 c 当作独立 runtime。**原始输出把 RTB-NSI 的计时复制到 RTB-DAS 行，已修正：没有独立计时的 RTB-DAS 和 NSI c=0.8 均标记 NaN。**

### CR/CNR/gCNR

默认不计算，因为没有已确认 lesion/background ROI。若已有经确认的低回声模体区域：

~~~matlab
fi_filename='../../data/Alpinion_L3-8_FI_hypoechoic.uff';
fi_z_min=35e-3; fi_z_max=45e-3;

% 把以下八个占位变量替换为真实的 ROI 边界坐标（mm）
contrast_rois_mm=[ ...
    lesion_xmin lesion_xmax lesion_zmin lesion_zmax; ...
    bg_xmin bg_xmax bg_zmin bg_zmax];

benchmark_mode='fi';
run_chapter7_benchmark
~~~

真实 gCNR 来自共同分箱下的 1-sum(min(P,Q))，是有限样本估计。SLSC 的 gCNR 可以计算，但 CNR/CR 与 RF-envelope B-mode 的单位定义并不一致。

### 输出

~~~text
output/benchmark/ch07/
  FI_metrics.csv
  FI_images.png
  FI_configuration.mat
  RTB_metrics.csv
  RTB_images.png
  RTB_configuration.mat
  FI_contrast.csv    (可选)
~~~

**本地实验验收标准**：

- 所有同组数据 [z,x] 网格、x/z [m] 与 Rx F# 一致；
- FI 和 RTB 内部 DAS 的 complex max-peak scaled error 小于 1e-10；
- fDMAS 轴向输出采样满足二倍频带通的 Nyquist；
- 点目标宽度同时给出 width/dx；低于 3 pixels 时不强行宣称精确物理宽度；
- 没有已确认 lesion ROI 时不编造 gCNR/CNR；
- 运行时间记录为 full-core 时间，包含 RF 读取等开销。

### 文件

~~~text
run_chapter7_benchmark.m
benchmark_ch7_metrics.m
benchmark_ch7_contrast.m
README.md
~~~

详细教学见 [第 7 章](../../chapters/07_Benchmark/README.md)。


## 本次真实运行记录（2026-11-13）

用户在 MATLAB 中运行 `run_chapter7_benchmark`，提供两组完整 Figure/Console。

- `gCNR synthetic sanity tests: PASS`；
- FI 的 CF、GCF、MVDR、fDMAS、SLSC 相对第 1 章 complex DAS 一致性误差都是 **6.147e-18**；
- RTB 的两条独立 complex DAS 一致性误差 **0**；
- 生成 `FI_metrics.csv` 和 `RTB_metrics.csv` 以及对应 Figure/配置；**没有验证的 lesion/background ROI，未生成 FI_contrast.csv，是预期行为**。

**FI 主瓣 FWHM（mm）**：DAS 0.71147；CF 0.41672；GCF 0.62156；MVDR 0.30669；fDMAS 0.71965。FI 横向扫描线约 0.298 mm，所有主瓣跨越不足 3 scanlines，尤其 MVDR 只有约 1.03 个 scanlines，因此不做精确分辨率倍数宣称。

**密集 RTB FWHM（mm）**：DAS 0.70632；MVDR 0.12382；NSI c=0.2 为 0.16089；NSI c=0.8 为 0.37254。四种条件完全同网格，且 MVDR FWHM 仍跨约 4.95 pixels。点目标峰值相对 DAS 分别为 -2.8928、-2.5358、-0.68566 dB。

**RTB 全核心单次计时**：MVDR + 内部 DAS 135.93 秒，NSI + 内部 DAS/ZM 23.40 秒。请勿将 RTB-DAS 视为单独跑出 23.40 秒：**本次没有单独计时**；c=0.8 重用了同一 D/Z，没有独立 full-core 计时。已更新表格输出，将这两个 runtime 置为 NaN（仅更正计时归属，不影响图像、FWHM 或相干性计算）。如需要验证新的 runtime 列，可只重跑 RTB；**非必须，不影响本章验收**。

本章结论不是“哪个算法全局最好”，而是 **点目标横向响应压窄、真实人体结构保真、contrast detectability 和计算时间之间存在不同的取舍**。完整结果与边界见 [第 7 章正文](../../chapters/07_Benchmark/README.md)。
