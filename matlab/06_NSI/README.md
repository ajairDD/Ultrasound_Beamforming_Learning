# Chapter 6 MATLAB — Null Subtraction Imaging

**状态：已完成教学实验。** 保留一个 NSI core，以及点目标和全视野两种对照入口；不继续扩展 NSI 变体。

## 1. 点目标密集二维实验

~~~matlab
addpath(genpath('D:/你的USTB路径'));
cd matlab/06_NSI
compare_rtb_das_vs_nsi
~~~

默认：

~~~text
UFF = ../../data/L7_FI_TheGB.uff
x = -4..+3 mm;    n_x=281, dx=0.025 mm
z = 18..22.5 mm;  n_z=181, dz=0.025 mm
DC offset c = 0.2
RTB blended Tx delay, Tukey25, Tx F#2
Rx F#1.7, wave_stride=1
~~~

采用密集 RTB grid，而非 conventional FI 的较稀疏 scanlines，是为了避免横向 NSI 主瓣在输出网格上欠采样。

## 文件结构

~~~text
reconstruct_fi_rtb_nsi_manual.m
compare_rtb_das_vs_nsi.m
compare_full_fov_rtb_das_vs_nsi.m
README.md
~~~

核心通过同一套 Tx/Rx delay 和 receive data 计算：

~~~text
D  = sum(s)
Z  = sum(wZM .* s)
DC1 = Z+c*D
DC2 = -Z+c*D
E_NSI = (abs(DC1)+abs(DC2))/2-abs(Z)
~~~

**实际代码只需独立形成 D 和 Z 两路**；DC1/DC2 由线性代数精确重组。先 coherent Tx compounding，再 envelope subtraction。

奇数 active Rx count 时，ZM 左右各半 +1/-1，中央元素 ZM weight=0，确保零均值。

## 验证和显示

- 计算 NSI 理论包络边界 0<=E<=c*abs(D)；
- 比较 RTB-DAS complex beamformed output 与 Chapter-1 independent RTB core（max-peak scaled error <1e-10）；
- 输出同一 DAS 0-dB reference 的两张二维图、lateral profiles 和 DC/ZM/NSI subtraction 的直观拆解。

NSI 显示 E/c 用于与 DAS 比较；不是物理声压标定。参考论文指出窄主瓣可能伴随 speckle underdevelopment 与 CNR 下降。

**用户已运行 TheGB 的点目标 RTB-NSI 实验并提供图像。** 结果显示 NSI 横向响应比 DAS 明显窄，但背景出现严重暗区和 speckle 断裂；这可能是 NSI 在 c=0.2 时过度抑制组织，也可能有数据/模型因素，不能据此认为 NSI 临床成像更好。由于未提供完整 Console 数字，本文件不记录 FWHM 或回归误差的猜测值。

详细见 [第 6 章教程](../../chapters/06_NSI/README.md)。


---

## 2. 全视野 TheGB + 两组人体颈动脉实验（已运行）

直接运行：

~~~matlab
compare_full_fov_rtb_das_vs_nsi
~~~

默认一键处理两个 UFF：

~~~text
1. ../../data/L7_FI_TheGB.uff
2. ../../data/L7_FI_carotid_cross_1.uff
~~~

**不是将 cropped ROI 放大**：x 轴范围自动从各 UFF 的全部 focused Tx source.x 读取；深度 5–45 mm。

为了先查看组织结构是否被破坏，默认用中等网格/半数 Tx：

~~~text
n_x = 257               % full focused Tx lateral span
n_z = 385               % z=5..45 mm
wave_stride = 2          % every second focused Tx
dc_offset = 0.2          % 与点目标实验保持一致
run_rtb_reference_check = false
~~~

当需要第二份独立颈动脉数据：

~~~matlab
dataset_indices = [1 2 3];
compare_full_fov_rtb_das_vs_nsi
~~~

如果需要 all-Tx / 更密网格的最终形态确认：

~~~matlab
dataset_indices = [1 2];
wave_stride = 1;
n_x = 385;
n_z = 513;
compare_full_fov_rtb_das_vs_nsi
~~~

两张主要输出：

- **Figure 1**：每份 UFF 的 RTB-DAS / RTB-NSI 全视野；同一数据集的两图使用相同 DAS 0-dB reference，**不同数据集不共用参考峰值**；
- **Figure 2**：NSI/DAS 幅度保留比 \((E_{\rm NSI}/c)/|D|\)（被限制到 0–1）；只显示 DAS 高于 -40 dB 的 foreground，灰色为低幅度/无 Tx 数据。值小意味着 **NSI 压掉了大量 DAS 响应，不等于这些响应一定是 clutter**。

控制台输出峰值变化、foreground 的 median ratio 和 ratio<0.25 的像素比例。这些仅为**算法抑制强度统计**，不等于 CNR、gCNR 或血管壁保真度。

该全视野脚本默认不重复执行完整 Chapter-1 RTB regression（会显著增加运行时间）；先前点目标脚本仍默认执行该回归。如确需全视野重新检查，可在运行前设置：

~~~matlab
run_rtb_reference_check = true;
compare_full_fov_rtb_das_vs_nsi
~~~

### 重点观察

- **TheGB**：其它体模目标是否出现断裂，正常背景 speckle 是否被大片抑制，点目标之外有没有异常暗孔洞；
- **Carotid**：血管腔是否更干净、近壁和远壁是否连续、周围肌肉/腺体等实质组织是否变得不自然；
- **Cross-acquisition**：第二份颈动脉重复数据是否呈现类似规律；
- **采样限制**：默认约 0.1–0.15 mm 的横向全视野采样用于 morphology 预览，**不能用来精确估计极窄 NSI 点目标 FWHM**。

c=0.2 的全视野实验已证明组织过度抑制；用户随后保持 stride=1 和 385×513 网格，将 c 改为 0.8，完成了单变量比较。该结果用于解释方法取舍，而不是继续调参选最亮图像。

**当前状态：** 用户已运行 TheGB 及两组颈动脉的全视野实验，并提交 c=0.2（stride=2 和 1）以及 c=0.8（stride=1）的 Figure 1/2。形态和 amplitude-ratio 的结论见下节。

## 3. 真实全视野实验结果与局限（2026-11-12）

| 运行条件 | TheGB median ratio | Carotid 1 | Carotid 2 |
|---|---:|---:|---:|
| c=0.2, wave_stride=2, 257×385 | 0.07 | 0.06 | 0.06 |
| c=0.2, wave_stride=1, 385×513 | 0.07 | 0.06 | 0.06 |
| c=0.8, wave_stride=1, 385×513 | 0.37 | 0.38 | 0.37 |

median ratio 使用 **DAS ≥ -40 dB 且有效 Tx 覆盖** 的像素，计算 (NSI envelope/c)/DAS envelope。这是**算法幅度保留比例**，不是 CNR/SNR，也不是功率。

- c=0.2：TheGB 背景 speckle 大片变黑，两组 carotid 的血管壁和周围组织也明显断裂；不能把所有被压低的回波认定为 clutter。
- 固定 c=0.2，stride=2/较粗网格和 stride=1/较密网格的结果相近；这不是独立隔离 stride 的严格消融（同时改变了空间采样），但说明这种严重抑制不能简单归咎于快速预览。
- c=0.8：组织幅度和结构部分恢复，但体模 speckle 仍明显碎片化，颈动脉壁连续性/周围实质纹理依旧不及 DAS 自然。
- 增大 c，归一化 NSI 本来就更接近 DAS；不能将亮度恢复等同于实际分辨率、对比度或组织真实性改善。

**验证边界：** 默认全视野脚本的 run_rtb_reference_check=false；用户提供的是 Figure 截图，而不是完整 Console log。已有点目标脚本默认带 Chapter-1 DAS reference，但本次不能从截图确认具体误差。不要把全视野图像显示成功当成独立 RTB-DAS 数值正确性证明，也不要虚构 CNR/gCNR、FWHM 或临床优越性。

本章按教学目标结束；后续需要基于任务定义统一 benchmark，而不是继续依靠调 c 追求更好看的图。
