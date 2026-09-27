# 第 0 章配图与复现

## MATLAB 图

在仓库根目录启动 MATLAB，然后运行：

```matlab
addpath(fullfile(pwd, 'matlab', '00_Fundamentals'));
export_tutorial_figures
```

建议使用独立 MATLAB 会话：原始教学脚本包含 `clear`、`clc` 和 `close all`。导出入口依次运行五个原始实验，以 150 dpi 保存 PNG，并将命令行结果保存到 [matlab_results.txt](matlab_results.txt)。再次运行会更新同名图和日志。算法与数值参数未作改动；前两个实验的原始 RF 图仅将显示时间放大至 38–41 µs。

本次使用 MATLAB R2021b，2026-09-27 运行。五个实验和 19 张图的导出完成，进程返回码为 0；MATLAB 退出阶段另报告无法识别 `Settings`，不将其描述为完全无报错运行。图片已独立检查。

| 脚本 / 文件前缀 | 图编号与内容 |
|---|---|
| `demo_synthetic_point_target` | 01 原始 RF；02 单通道波形；03 横向响应；04 错误声速 |
| `demo_delay_alignment` | 01 原始 RF；02 正确聚焦；03 错误聚焦；04 残余延时 |
| `demo_aperture_psf_apodization` | 01 孔径比较；02 窗函数比较；03 权重 |
| `demo_axial_lateral_2d_psf` | 01 轴向剖面；02 横向剖面；03 二维 PSF |
| `demo_das_failure_modes` | 01 两点分辨；02 强弱目标；03 独立噪声；04 声速错误；05 相位畸变 |

文件名格式为 `脚本名_编号.png`。正文选用关键图，其余图保留供实验对照。图内英文与 MATLAB 变量一致，中文解读见正文。

## AI 概念插图

文件：[plane_wave_concept.png](plane_wave_concept.png)。使用内置 image_gen 生成；只说明发射与接收的路径关系，不是仿真结果，不按比例绘制。插图中阵元数量不代表实验中的 64 阵元。

生成提示词：

```text
Use case: scientific-educational. Create a wide polished textbook conceptual illustration on white background, landscape 1536x1024. Two panels with minimal exact English labels only: left 'Transmit', right 'Receive'. Both show the same linear ultrasound probe at the top as a row of small rectangular elements and a single orange point scatterer below slightly right of center in translucent pale blue homogeneous tissue. Left: several straight horizontal parallel cyan wavefronts traveling vertically down from array toward scatterer, one downward arrow. Right: three thin orange straight paths from that same scatterer to left, center, right receiving elements, arrowheads pointing upward toward elements, clearly unequal lengths. Soft understated 3D cutaway educational rendering, ample whitespace, high contrast. No curved transmit wavefronts, no focused transmit, no numerical measurements, no equations, no decorative wave traces, no additional scatterers, no logos. This is conceptual broadside plane-wave transmit then point-scatterer echo reception, not quantitative simulation.
```
