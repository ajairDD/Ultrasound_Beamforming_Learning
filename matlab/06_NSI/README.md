# Chapter 6 MATLAB — Null Subtraction Imaging

本章只保留一个 core 和一键密集二维 RTB ROI 对照实验，不继续扩展 NSI 变体。

## 一键运行

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

**真实 UFF+MATLAB 尚未执行。** 结果合理外观不等于独立数值/物理正确性验证。

详细见 [第 6 章教程](../../chapters/06_NSI/README.md)。
