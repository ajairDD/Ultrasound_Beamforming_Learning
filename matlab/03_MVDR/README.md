# Chapter 3 MATLAB：MV / MVDR / Capon

Chapter 3 已完成。

本目录只保留两类内容：

~~~text
1. 标准 MVDR 核心实现
2. 用于验证其行为的少量实验
~~~

EIBMV / RCB 只在章节文档中介绍原理，不继续增加实现文件。

---

## 1. 文件结构

~~~text
matlab/03_MVDR/
│
├─ reconstruct_fi_mvdr_manual.m
│    conventional focused-imaging receive-domain MVDR core
│
├─ compare_manual_das_vs_mvdr.m
│    完整二维 conventional DAS vs MVDR
│
├─ experiment_mvdr_tradeoffs.m
│    可选：L/M 与 diagonal-loading 参数实验
│
├─ reconstruct_fi_rtb_mvdr_manual.m
│    RTB-DAS 与 RTB receive-MVDR 共用 core
│
├─ compare_rtb_das_vs_rtb_mvdr.m
│    dense-grid point-target validation
│
├─ compare_carotid_rtb_das_vs_rtb_mvdr.m
│    in-vivo carotid robustness comparison
│
└─ README.md
~~~

没有继续增加 EIBMV、RCB、LCMV、Beamspace 等变体代码，避免把主学习路线拉长。

---

## 2. 当前标准 MVDR 配置

两个 MVDR core 统一采用：

~~~text
receive subarray fraction   L/M = 0.5
diagonal loading                = 0.01
axial covariance averaging      = +/- 1.5 lambda
forward-backward averaging      = false
~~~

covariance estimate 使用：

~~~text
overlapping receive subarrays
+
neighboring axial samples
~~~

axial_averaging_lambda = 0 可以退回最初的 spatial-only 教学版本，但不推荐作为完整二维图像 baseline。

---

## 3. 推荐运行顺序

### 3.1 原理 / conventional FI

~~~matlab
compare_manual_das_vs_mvdr
~~~

用于观察 DAS fixed receive weights 与 MVDR adaptive receive weights 的差别。

### 3.2 Dense RTB point target

~~~matlab
compare_rtb_das_vs_rtb_mvdr
~~~

这是本章最重要的 point-target 验证。

脚本保持 RTB Tx model、Tx weight、Rx F#、grid 和跨 Tx coherent combination 不变，只改变 receive DAS / MVDR combination。

还会用 Chapter-1 reconstruct_fi_rtb_manual.m 对 RTB-DAS branch 做 complex regression check。

已验证 dense-grid 结果：

~~~text
dx = 0.0250 mm
dz = 0.0250 mm

                       RTB-DAS      RTB-MVDR
lateral FWHM            0.7063 mm    0.1238 mm
axial FWHM              0.4231 mm    0.4071 mm
lateral -20 dB width    1.1482 mm    0.4617 mm

MVDR lateral FWHM / dx = 4.953
MVDR peak vs DAS       = -2.893 dB
fallback               = 0%
~~~

结论：强 lateral adaptive narrowing 是真实算法效应，但同时存在 target attenuation，不能直接解释成无代价的物理分辨率提升。

### 3.3 In-vivo carotid

~~~matlab
compare_carotid_rtb_das_vs_rtb_mvdr
~~~

默认第一组 acquisition。

第二组：

~~~matlab
dataset_index = 2;
compare_carotid_rtb_das_vs_rtb_mvdr
~~~

最终观察：真实 carotid 上 RTB-MVDR 与 RTB-DAS 的 B-mode morphology 差异有限，没有复现 point-target 中同等量级的结构优势。

---

## 4. 可选参数实验

如果需要复习 L/M 和 diagonal loading：

~~~matlab
experiment_mvdr_tradeoffs
~~~

它不是 Chapter 3 完成所必须再次运行的实验。

---

## 5. 代码科学边界

当前实现：

- 2-D linear-array focused imaging；
- real RF input，内部转 analytic signal；
- receive-domain MVDR；
- dynamic Rx F-number；
- spatial smoothing；
- axial covariance averaging；
- diagonal loading；
- optional forward-backward averaging；
- RTB-MVDR 在每个 Tx/pixel 上先完成 receive MVDR，再做与 RTB-DAS 相同的 Tx weighting / coherent combination。

当前未实现：

- EIBMV / ESMV；
- Robust Capon Beamforming；
- LCMV；
- Beamspace MV；
- transmit-domain adaptive MV。

Chapter 3 到此结束。