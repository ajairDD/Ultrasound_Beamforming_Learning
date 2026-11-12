# 第四章配图与课件索引

本目录收录 **6 张文生图概念插图与 12 张实际 MATLAB 配图**。正文先用图 1–6 串起完整算法理论，再用图 7–12 展开可控数值实验，最后通过图 13–18 解读同一次 TheGB 重建。

[返回第四章](../README.md) · [MATLAB 运行入口](../../../matlab/04_DMAS/README.md) · [AI 提示词及修订记录](imagegen_prompts.md)

## 图片来源与使用方式

AI 概念图使用内置 image_gen 生成，并保存到本目录。图中曲线、组织切面和像素方格均为示意，不能当作仿真、测量或性能证据。英文标签适合直接放入课件，正文配有中文讲解。

MATLAB PNG 是本次实际执行代码后以 exportgraphics 导出的图片，分辨率设置为 150 dpi。合成小实验与真实 UFF 图像明确分开；所有真实数据诊断图来自同一次 conventional FI 重建，没有添加其他算法变体或新的数据集。

## 课件顺序与文件对应

| 正文图号 | 图片 | 适合讲解的重点 |
|---|---|---|
| 1 | [fdmas_pipeline_concept.png](fdmas_pipeline_concept.png) | 共享 delay / interpolation / aperture；不同接收组合 |
| 2 | [dmas_pairs_concept.png](dmas_pairs_concept.png) | 四通道六个唯一 pair，上三角求和 |
| 3 | [dmas_sign_rectification.png](dmas_sign_rectification.png) | 全局反号不变；全相干特例的整流形状 |
| 4 | [dmas_dynamic_aperture.png](dmas_dynamic_aperture.png) | 孔径变化、pair count 和 2/(M−1) 约定 |
| 5 | [fdmas_digital_frequency.png](fdmas_digital_frequency.png) | 数字非线性产生约 2f₀ 成分 |
| 6 | [fdmas_depth_sampling.png](fdmas_depth_sampling.png) | 输出深度网格与约 2f₀ 滤波的 Nyquist |
| 7 | [demo_dmas_building_blocks_01.png](demo_dmas_building_blocks_01.png) | 手算输入和六个 pair 的逐格对应 |
| 8 | [demo_dmas_building_blocks_02.png](demo_dmas_building_blocks_02.png) | 绝对齐次缩放、原始与归一化 count scaling |
| 9 | [demo_dmas_building_blocks_03.png](demo_dmas_building_blocks_03.png) | 普通乘积与 signed-sqrt 的不同频谱 |
| 10 | [demo_dmas_building_blocks_04.png](demo_dmas_building_blocks_04.png) | 合成脉冲、实际 mask、正确包络顺序 |
| 11 | [demo_dmas_building_blocks_05.png](demo_dmas_building_blocks_05.png) | 粗网格混叠、细网格四点 / 2f₀ 周期 |
| 12 | [demo_dmas_building_blocks_06.png](demo_dmas_building_blocks_06.png) | 相位误差响应，不是通用 PSF 或真假目标分类器 |
| 13 | [compare_fi_das_vs_fdmas_01.png](compare_fi_das_vs_fdmas_01.png) | 完整真实 B-mode；各自全图峰值归一化 |
| 14 | [compare_fi_das_vs_fdmas_02.png](compare_fi_das_vs_fdmas_02.png) | 实际横向采样点与前后频谱 |
| 15 | [uff_dmas_diagnostics_01.png](uff_dmas_diagnostics_01.png) | 同一目标二维放大，仅裁剪显示 |
| 16 | [uff_dmas_diagnostics_02.png](uff_dmas_diagnostics_02.png) | 各自局部峰值的横向 / 轴向包络剖面 |
| 17 | [uff_dmas_diagnostics_03.png](uff_dmas_diagnostics_03.png) | 同一实际 scanline 的三个信号阶段与 Y、YH、H |
| 18 | [uff_dmas_diagnostics_04.png](uff_dmas_diagnostics_04.png) | 实际有效 Rx 数和 pair count 的深度依赖 |

## 复现命令

~~~matlab
addpath(genpath('D:/USTB')); % 按本机位置调整
cd('D:/Ultrasound_Beamforming_Learning/matlab/04_DMAS');
export_chapter4_figures('concepts');
export_chapter4_figures('uff');
% 或 export_chapter4_figures('all');
~~~

'concepts' 无需 USTB 和 UFF，固定 rng(4)。'uff' 固定 TheGB、frame 1、全部 128 条 scanlines、z=5–45 mm、Rx F#=1.7、自动深度网格。仅重新运行导图不会重新生成 AI 图；AI 提示词与修订记录另附。

实际执行日志：

- [matlab_concepts_results.txt](matlab_concepts_results.txt)：六组原理实验的数值断言。
- [matlab_uff_results.txt](matlab_uff_results.txt)：完整二维重建、第一章复数 DAS 回归、目标宽度和数组检查。
- [matlab_sampling_check_results.txt](matlab_sampling_check_results.txt)：另行实际读取输入元数据，并验证 5–45 mm、Nz=128 的粗网格被核心函数拒绝。

## 本次执行环境与固定输入

| 项目 | 记录 |
|---|---|
| 执行日期 | 2026-11-12 |
| MATLAB | 9.11.0.1769968 (R2021b) |
| 本机 USTB | D:/USTB |
| USTB commit | 86126eb7cab8b6009d14f2d448e85eeb8a86f61c |
| UFF 文件 | data/L7_FI_TheGB.uff，第 1 帧 |
| 输入轴语义 | [sample,Rx,Tx,frame]=[1920,128,128,1]；单帧尾维在 MATLAB size 中可省略 |
| UFF MD5 | 9d9c728b9d03fa66444956b445fe2d7f |
| 延时 / 插值 / 接收窗 | 第一章 conventional focused FI 约定；linear interpolation；Rx F#=1.7 boxcar |
| 输入形式 | real RF，未 demodulate；DAS 分支使用 analytic RF |
| 输出形状 | [Nz,Nx]=[2166,128] |
| 实际深度步长 Δz | 0.018475751 mm |
| 横向步长 Δx | 0.297980965 mm；取 sequence.source.x |
| nominal f₀ | 5.208333492 MHz，由元数据的 c / lambda 得到 |
| 原始采集 fs | 20.833333969 MHz |
| 轴向 image-time fs,z | 41.676250458 MHz；近似坐标 2z/c |
| 所选带通 | [1.5,1.75,2.5,2.75] × nominal f₀，双边 raised-cosine FFT mask |
| FFT padding | Npad=2^nextpow2(2*Nz)=8192 |
| DMAS scaling | 2/(M−1)，仅 M≥2；否则输出 0 |
| 有效 Rx 数 M | 5–89 |
| 显示 | 幅度 20log10；B-mode 各自全图峰值归一化；下限 −60 dB |
| 局部剖面 | 各自局部峰值归一化；各自峰值所在的横向 / 轴向切片 |

## 实际数值与科学边界

| 检查或读数 | 结果 |
|---|---|
| 多组向量显式 pairs / O(M) reduction 最大 scaled error | 6.855828×10⁻¹⁷ |
| 全相干归一化输出与 M 乘绝对 RF 的最大误差 | 5.329071×10⁻¹⁵ |
| 对第一章 DAS 基线的复数 max-peak scaled error | 5.113478×10⁻¹⁸ |
| analytic transform 保留实部的 scaled error | 3.063196×10⁻¹⁶ |
| finite [z,x]、real DMAS、abs(analytic)=envelope、整数 M | 全部断言通过；本次实际 M 为 5–89 |
| 粗输出网格拒绝检查 | 5–45 mm、Nz=128：Nyquist≈1.222 MHz，低于带通上沿≈14.323 MHz，按预期报错 |
| 输出 Nyquist / 所选频带上沿 | 20.838125229 / 14.322916985 MHz |
| DAS 局部目标 (x,z) | (−0.744952355,20.076212471) mm |
| fDMAS 局部目标 (x,z) | (−0.744952355,19.965357968) mm |
| 横向半幅宽度 DAS / fDMAS | 0.723634913 / 0.702282398 mm |
| 横向宽度 / Δx | 2.4285 / 2.3568 个网格间距 |
| 轴向半幅宽度 DAS / fDMAS | 0.445320469 / 0.607210753 mm |
| 轴向宽度 / Δz | 24.1030 / 32.8653 个网格间距 |

宽度来自**线性包络的一半**交点，使用相邻样本插值，约等于 −6.0206 dB 的幅度标准，不是 −3 dB 的功率标准。横向读数只有约两个多网格间距，不能据此作精确分辨率提升结论；本次 fDMAS 轴向宽度增加，也说明数字 2f₀ 不保证更短的包络。

DAS 回归只验证共享前端与 DAS 分支。pair identity 验证代数等价，不验证传播模型；本项目 FFT 与官方 USTB FIR 的 fDMAS 没有做逐点等价测试。image-time Nyquist 检查只覆盖选择的频带上沿，不保证全部非线性谐波、离轴路径或有限区间边界都已严格处理。

图 13 / 15 各用自己的全图峰值，图 14 / 16 用各自局部目标峰值；图 17 的时域波形各除以自身全 scanline 的最大绝对值。所有这些缩放均用于读形状，不能从并排灰度或峰值为 0 dB 推导 DAS / fDMAS 的绝对幅度增益。

本次没有计算 CNR / gCNR、SNR 或临床效益。speckle 改变应称为纹理重塑，单幅图像更黑不等于去噪成功；相干杂波也不保证被抑制。

本机部分 MATLAB batch 会在全部计算及导图结束后打印 exit 阶段的 Settings 未定义提示，进程返回 0；原理断言、复数回归和 PNG 导出均在提示之前完成。此处如实记录环境退出信息，不把它算作算法验证项目。
