# Chapter 3 MATLAB：MV / MVDR / Capon

本章只保留两个必跑入口。

## 1. 原理 + 完整二维 DAS / MVDR

~~~matlab
compare_manual_das_vs_mvdr
~~~

核心：

~~~text
reconstruct_fi_mvdr_manual.m
~~~

默认：

~~~text
dataset              = L7_FI_TheGB.uff
Rx F#                = 1.7
subarray fraction    = 0.5
diagonal loading     = 0.01
forward-backward     = false
n_z                  = 256
~~~

输出完整二维 DAS / MVDR common-reference 和 self-normalized 对比。

## 2. 一次性参数实验

~~~matlab
experiment_mvdr_tradeoffs
~~~

比较：

~~~text
L/M = 0.25 / 0.50 / 0.75
loading = 0.01

以及

L/M = 0.50
loading = 0.10
~~~

只重建 point-target 附近窄 depth band，以减少运行时间。

## 3. 可选开关

`reconstruct_fi_mvdr_manual.m` 还支持：

~~~matlab
opts.forward_backward = true;
~~~

用于 forward-backward covariance averaging。

本章暂不把 temporal averaging、EIBMV、RCB、LCMV 放入主实现，避免再次把学习路线拉长。

---

## 4. RTB + receive-MVDR

新增：

~~~text
reconstruct_fi_rtb_mvdr_manual.m
compare_rtb_das_vs_rtb_mvdr.m
~~~

直接运行：

~~~matlab
compare_rtb_das_vs_rtb_mvdr
~~~

默认只重建 TheGB 20.1 mm point target 附近的密集 RTB ROI，用于判断 conventional-FI 中 MVDR 的“单 scanline”外观是否来自 lateral undersampling。

新 core 同时计算 RTB-DAS 与 RTB-MVDR；两者使用相同的 Tx delay、Tx weight、Rx F#、RTB grid 和跨 Tx coherent combination，只改变 receive combination。

comparison script 默认还会调用 Chapter-1 reconstruct_fi_rtb_manual.m，对新 core 的 RTB-DAS complex output 做 regression check。

Chapter-1 reconstruct_fi_rtb_manual.m 新增向后兼容的 opts.x_min / opts.x_max，用于 ROI reconstruction；未设置时行为不变。


---

## 5. In-vivo carotid RTB-DAS vs RTB-MVDR

新增一键脚本：

~~~text
compare_carotid_rtb_das_vs_rtb_mvdr.m
~~~

默认运行第一组 carotid acquisition：

~~~matlab
compare_carotid_rtb_das_vs_rtb_mvdr
~~~

默认使用快速 ROI：

~~~text
x = -10 ~ +10 mm
z = 8 ~ 25 mm
n_x = 161
n_z = 171
wave_stride = 2
~~~

保持 RTB-DAS / RTB-MVDR 的 Tx delay、Tx weight、Rx F#、RTB grid 和跨 Tx coherent compounding 完全一致，只改变 receive combination。

第二组数据：

~~~matlab
dataset_index = 2;
compare_carotid_rtb_das_vs_rtb_mvdr
~~~

更密的最终检查：

~~~matlab
n_x = 241;
n_z = 257;
wave_stride = 1;
compare_carotid_rtb_das_vs_rtb_mvdr
~~~

输出 common-reference 图、self-normalized morphology、MVDR-DAS dB change map、runtime、peak change、masked median change、envelope correlation 和 fallback ratio。人体数据没有 ground truth，这些统计只用于描述算法行为，不能直接解释为临床优越性。
