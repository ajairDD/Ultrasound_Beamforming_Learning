# 第一章配图与课件索引

本目录提供 **5 张 AI 概念插图和 27 张 MATLAB 图**。正文按 19 组图片组织教学；本索引还收录正文未全部展开的公共幅值图、轴向对照和 reference 剖面，便于按课时选用。

[返回第一章教程](../README.md) · [MATLAB 入口说明](../../../matlab/01_DAS_Real_UFF/README.md)

## 1. 先区分图的来源

| 来源 | 可以说明什么 | 讲解时的边界 |
|---|---|---|
| AI 概念插画 | 采集关系、处理顺序、不同对象的选择 | 不按比例，不是实测声场或数据；英文短标签配合正文中文图解 |
| MATLAB 数据图 | 本次 UFF 的 RF、重建结果、目标剖面、实现差异 | 结论依赖数据、网格、孔径、模型与归一化 |
| MATLAB 几何 / 数值教学图 | metadata 对应的坐标、延时与权重，已知正弦波插值 | 是模型计算，不是测得的声压分布；正弦波不是组织 RF |

## 2. 五张 AI 插图

| 正文 | 原图 | 课件讲解目的 |
|---|---|---|
| 图 1 | [focused_acquisition.png](focused_acquisition.png) | 区分发射焦点 F、散射体 P 与多条 Rx 波形 |
| 图 4 | [virtual_source_geometry.png](virtual_source_geometry.png) | 焦点前后的正负时间参考；声波始终向深处传播 |
| 图 7 | [coherent_processing.png](coherent_processing.png) | 延时后保留相位，相干相加，再取包络与 dB |
| 图 11 | [conventional_vs_rtb.png](conventional_vs_rtb.png) | 一发一线、一发多像素、多发同像素 |
| 图 16 | [tx_rx_apertures.png](tx_rx_apertures.png) | Tx support 选像素，Rx aperture 选阵元 |

插图由 Codex 内置 imagegen 生成，PNG、白色背景。逐张核对了文字、探头位置与传播方向；相干处理图的 B-mode 缩略图经一次编辑，改为适合 linear array 的矩形。它仍是概念缩略图，不能当作 MATLAB 重建结果。

## 3. MATLAB 完整图册

所有重建使用 frame 1、5–45 mm 深度范围；默认文件为 `data/L7_FI_TheGB.uff`。下表的“深度点数”指重建网格，通道图保留原始 1920 个时间样本。图为 150 dpi PNG。

| 原图 | 深度点数 | 讲解用途 / 读图提醒 |
|---|---:|---|
| [plot_raw_channel_overview_ustb_01.png](plot_raw_channel_overview_ustb_01.png) | — | wave 64，全记录 signed RF；归一化到全记录峰值 |
| [raw_channel_echo_zoom.png](raw_channel_echo_zoom.png) | — | wave 64，25–34 µs 放大；缩窄色限，色条仍为 RF / 全记录峰值 |
| [demo_fi_geometry_and_sampling_01.png](demo_fi_geometry_and_sampling_01.png) | — | 实际 Rx / focus 坐标与逐 Tx 的 wave.delay |
| [demo_fi_geometry_and_sampling_02.png](demo_fi_geometry_and_sampling_02.png) | — | 中心 Tx 的中心线与 1 mm 离轴 Tx 时间；纵轴减去共同参考 |
| [demo_fi_geometry_and_sampling_03.png](demo_fi_geometry_and_sampling_03.png) | — | Tx Tukey25 support 与 Rx boxcar 选择；左右横轴对象不同 |
| [demo_fi_geometry_and_sampling_04.png](demo_fi_geometry_and_sampling_04.png) | — | 已知实数正弦波，`u=3.35` 的精确、线性、最近邻取样 |
| [das_fi_scanline_manual_01.png](das_fi_scanline_manual_01.png) | 1024 | 128 条 conventional scanline，full Rx，自身峰值归一化 |
| [analyze_point_target_psf_01.png](analyze_point_target_psf_01.png) | 1024 | 全图上的目标峰标记；full Rx |
| [analyze_point_target_psf_02.png](analyze_point_target_psf_02.png) | 1024 | 横向 PSF，粗 scanline 采样下的半幅宽度 |
| [analyze_point_target_psf_03.png](analyze_point_target_psf_03.png) | 1024 | 轴向 PSF，横轴为深度 |
| [analyze_point_target_psf_04.png](analyze_point_target_psf_04.png) | 1024 | 所选 point-like object 的局部图像 |
| [compare_receive_aperture_full_vs_fnumber_01.png](compare_receive_aperture_full_vs_fnumber_01.png) | 1024 | full Rx 图上的目标选择起点 |
| [compare_receive_aperture_full_vs_fnumber_02.png](compare_receive_aperture_full_vs_fnumber_02.png) | 1024 | full Rx 与 F# 1.7 的全图，各按自身峰值显示 |
| [compare_receive_aperture_full_vs_fnumber_03.png](compare_receive_aperture_full_vs_fnumber_03.png) | 1024 | 两种 Rx aperture 的横向响应 |
| [compare_receive_aperture_full_vs_fnumber_04.png](compare_receive_aperture_full_vs_fnumber_04.png) | 1024 | 两种 Rx aperture 的轴向响应 |
| [compare_conventional_vs_rtb_01.png](compare_conventional_vs_rtb_01.png) | 512 | 128 线 conventional、包络插值、512 横向像素 RTB；均为 Rx F# 1.7 |
| [compare_conventional_vs_rtb_02.png](compare_conventional_vs_rtb_02.png) | 512 | 三者在同一目标附近的横向剖面；更密网格不自动证明更高分辨率 |
| [compare_conventional_vs_rtb_03.png](compare_conventional_vs_rtb_03.png) | 512 | active Tx count；次数不等于连续权重和 |
| [compare_rtb_spherical_plane_blended_01.png](compare_rtb_spherical_plane_blended_01.png) | 384 | 三种 Tx model 全图，各按自身峰值归一化，比较形态 |
| [compare_rtb_spherical_plane_blended_02.png](compare_rtb_spherical_plane_blended_02.png) | 384 | 统一 blended peak，比较相对幅值；超过 0 dB 的部分被裁剪 |
| [compare_rtb_spherical_plane_blended_03.png](compare_rtb_spherical_plane_blended_03.png) | 384 | 焦深 ±4 mm，三种模型纵向排列，便于观察焦区接缝 |
| [compare_rtb_spherical_plane_blended_04.png](compare_rtb_spherical_plane_blended_04.png) | 384 | 自身峰值归一化包络相对 blended 的绝对差，非真值误差 |
| [validate_manual_vs_ustb_01.png](validate_manual_vs_ustb_01.png) | 512 | full Rx conventional 的 Manual / USTB 并排图 |
| [validate_manual_vs_ustb_02.png](validate_manual_vs_ustb_02.png) | 512 | 两者归一化线性包络绝对差，注意色条的 `10^-6` 量级 |
| [validate_manual_vs_ustb_03.png](validate_manual_vs_ustb_03.png) | 512 | 约 30 mm 深度横向 reference 剖面；不是选定目标的 PSF |
| [validate_manual_rtb_vs_ustb_01.png](validate_manual_rtb_vs_ustb_01.png) | 256 | blended RTB 的 Manual / USTB 并排图 |
| [validate_manual_rtb_vs_ustb_02.png](validate_manual_rtb_vs_ustb_02.png) | 256 | 归一化包络差，结合指标与峰位置解释 |

B-mode 均显示 −60 至 0 dB。PSF 曲线在未裁剪线性包络上测量，再转 dB 画图；幅值半高对应 −6.0206 dB。AI 图不使用这些定量尺度。

## 4. 本次运行环境与观测

- MATLAB：`9.11.0.1769968 (R2021b)`。
- USTB：本地 `D:/USTB`，Git HEAD `86126eb7cab8b6009d14f2d448e85eeb8a86f61c`。
- 输入文件：`L7_FI_TheGB.uff`，165,917,807 bytes，MD5 `9d9c728b9d03fa66444956b445fe2d7f`。
- data shape：`[1920,128,128,1]`，实数 `single` RF。
- 图册 RTB：`x_upsample=4`，Tx F# 2、minimum support 全宽 3 mm、Tukey25、Rx boxcar F# 1.7、全部 128 Tx、Tx 权重和归一化。
- 三模型实验固定上述设置，仅改变 spherical / plane / blended。其余 RTB 使用 blended，`blending_power=0.5`。
- 目标搜索起点：`(-0.75,20.05)` mm，根据真实 B-mode 中较孤立亮点选取，并在邻域找局部峰。这里未使用独立理想点真值。

本次匹配条件下的 reference 结果：

| 比较 | 图像 shape [z,x] | 包络相关系数 | 归一化 MAE | 归一化 RMSE | 最大绝对差 | 全局峰位置差 |
|---|---|---:|---:|---:|---:|---|
| conventional / USTB | [512,128] | 0.999999583 | 1.5773e-7 | 2.7348e-7 | 5.5495e-6 | dx=0，dz=0 |
| blended RTB / USTB | [256,512] | 1.000000000 | 1.1366e-7 | 2.0454e-7 | 5.2367e-6 | dx=0，dz=0 |

相关系数显示到 9 位小数。误差基于各自峰值归一化的包络，因此不能单独证明绝对增益或复数相位完全一致。结果支持当前条件下的实现一致性，不是对完整声场或所有 acquisition 的验证。

full Rx、`n_z=1024` 时，所选目标横向半幅宽度约 0.4197 mm、轴向约 0.4461 mm；分别跨约 1.41 个横向间隔与 11.41 个深度间隔。横向值只作为粗估报告。Rx F# 1.7 的实验横向宽度约 0.7322 mm、轴向约 0.4479 mm，不能与不同孔径的 RTB 曲线直接混作同一实验。

近中心 Tx、横向离轴 1 mm 的模型极限：spherical 焦深跳变约 1299 ns，blended 约 26 ns。这些是公式推导的极限，不是测量值。

汇总运行记录：[matlab_all_results.txt](matlab_all_results.txt)，其中通道图、PSF 和三模型段落更新为排版检查后的单项重跑输出，reference 段落保留整套运行的实测结果。单项记录：[通道图](matlab_plot_raw_channel_overview_ustb_results.txt)、[PSF 与采样警告](matlab_analyze_point_target_psf_results.txt)、[三模型实验](matlab_compare_rtb_spherical_plane_blended_results.txt)。

本机 MATLAB 批处理在实验与导出完成后，退出阶段出现 `Settings` 未定义提示；本次进程返回码为 0，全部计算和 PNG 已实际完成。该退出环境问题未在课程代码中处理。

## 5. 复现与选择图片

在仓库根目录打开独立 MATLAB 会话：

~~~matlab
addpath(genpath('D:/USTB'));  % 换成实际路径
addpath('matlab/01_DAS_Real_UFF');
export_chapter1_figures
~~~

可用 `'experiments'`、`'references'` 分组，也可传入上表中的脚本名，单独重出图：

~~~matlab
export_chapter1_figures('plot_raw_channel_overview_ustb')
export_chapter1_figures('analyze_point_target_psf')
export_chapter1_figures('compare_rtb_spherical_plane_blended')
~~~

入口读取仓库内的默认 UFF，后台给定目标起点，以隐藏窗口导出。教学脚本会 `clearvars` / `close all`，请使用独立会话。同名 PNG 与对应日志更新；AI 图不会被覆盖。

建议课件每页先放一张概念图，再放对应 MATLAB 图，并保留坐标、色条和来源。三模型差异图使用不同自动色限，颜色不可直接跨面板比较大小；必须读色条数值。公共峰值图存在 clipping，定量幅值比较使用脚本的线性包络。

## 6. AI 插图的实际提示词

以下保存生成时的完整英文提示词，便于后续维持风格。重新生成是随机过程，未承诺像素级一致。

<details>
<summary>focused_acquisition.png</summary>

~~~text
Use case: scientific-educational. Asset: Chinese ultrasound beamforming course and projected lecture slide. Landscape 1536x1024, polished textbook illustration on white, restrained soft 3D cutaway and precise clean linework, blue ultrasound probe at top, tissue pale translucent blue, orange focus, teal receive paths, plentiful whitespace. All labels exact short English only, large legible. No invented equations, no numerical values, no logos, no watermark. Conceptual illustration, not a quantitative acoustic field. A two-panel illustrated explainer. Left title 'One focused transmit': a linear probe row of elements at TOP of tissue; a selected central group emits downward paths that converge to a single orange point F at mid depth and continue diverging BELOW F. F is explicitly only a focus, not a physical object. A tiny dark point target P sits BELOW and RIGHT of F, inside this diverging beam, scattering echo along three teal paths with arrowheads at three receive elements at the TOP. Color coding blue transmit rays downward, teal receive rays upward, F orange, P dark. Right title 'Record all receive channels': same probe and P, three receive elements highlighted with matching colors; each connects to a separate small waveform strip outside the tissue on the right, staggered arrival pulses qualitatively without axes or scales. Caption labels only 'F: focus', 'P: scatterer', 'RF channels'. Do not confuse F with P. Enough space, physically consistent directions.
~~~

</details>

<details>
<summary>virtual_source_geometry.png</summary>

~~~text
Use case: scientific-educational. Asset: Chinese ultrasound beamforming course and projected lecture slide. Landscape 1536x1024, polished textbook illustration on white, restrained soft 3D cutaway and precise clean linework, blue ultrasound probe at top, tissue pale translucent blue, orange focus, teal receive paths, plentiful whitespace. All labels exact short English only, large legible. No invented equations, no numerical values, no logos, no watermark. Conceptual illustration, not a quantitative acoustic field. A two-panel cutaway illustration explaining focus reference time for focused ultrasound. Both panels same vertical linear probe at TOP and orange focal point F at middle. Left title 'Before focus': a dark point P on vertical central beam axis ABOVE F. Three rays converge downward from probe through P toward F; one central downward arrow from probe to P and another downward arrow from P to F, with no upward propagation. Labels 'P', 'F', 'Earlier than focus'. Right title 'After focus': dark point P BELOW F and slightly right. Rays converge from probe to F, then diverge downward below F; one outgoing ray from F reaches P, arrow points down toward P. Labels 'P', 'F', 'Later than focus'. Focus F remains a geometry reference, not actual scatterer, no backward arrows and no claim that energy physically originates at F. Illustrate signed reference timing without equations.
~~~

</details>

<details>
<summary>conventional_vs_rtb.png</summary>

~~~text
Use case: scientific-educational. Asset: Chinese ultrasound beamforming course and projected lecture slide. Landscape 1536x1024, polished textbook illustration on white, restrained soft 3D cutaway and precise clean linework, blue ultrasound probe at top, tissue pale translucent blue, orange focus, teal receive paths, plentiful whitespace. All labels exact short English only, large legible. No invented equations, no numerical values, no logos, no watermark. Conceptual illustration, not a quantitative acoustic field. A two-panel visual comparison, same top-down tissue x-z cross-section and linear probe at TOP in both. Left title 'Conventional FI': exactly three focused transmits illustrated as blue, teal, orange translucent hourglass beams with focal waists at same depth, each only linked to its own central vertical dashed output scanline. Small bright dots representing candidate pixels lie only along these center lines. Label 'One Tx -> one line'. Right title 'RTB': same three hourglass beams with overlapping regions on a dense rectangular subtle pixel grid below probe. At a region shallower than the focal waist the beams overlap; mark one dark candidate P inside the overlap and highlight three beam contributions toward P using distinct blue, teal, orange short arrows. Highlight pixels within a single beam to show one Tx reconstructed at many pixels. Label 'One Tx -> many pixels' and 'Many Tx -> one pixel'. Focus waists are model geometry, no added anatomy. Do not make the RTB beam a plane wave; preserve focused beams in both panels.
~~~

</details>

<details>
<summary>tx_rx_apertures.png</summary>

~~~text
Use case: scientific-educational. Asset: Chinese ultrasound beamforming course and projected lecture slide. Landscape 1536x1024, polished textbook illustration on white, restrained soft 3D cutaway and precise clean linework, blue ultrasound probe at top, tissue pale translucent blue, orange focus, teal receive paths, plentiful whitespace. All labels exact short English only, large legible. No invented equations, no numerical values, no logos, no watermark. Conceptual illustration, not a quantitative acoustic field. A two-panel teaching illustration distinguishing transmit support in tissue from receive aperture on probe. Left title 'Tx support': one probe at TOP, one focused beam downward, a teal translucent hourglass-shaped eligible region has a narrow finite WAIST at orange F (never zero width), opens above and below F. Boundary softly fades, show three candidate pixels: one inside shaded support marked with a small check, one outside shaded support marked small cross, one at F waist inside marked check. Labels 'F', 'Eligible pixels', 'Finite waist'. Avoid claiming this is measured pressure field. Right title 'Rx aperture': same probe row at top, two side-by-side separate mini tissue views under title, each highlights a selected group of receive elements along top. Left mini view shallow P and small selected centered group, right mini view deep P and wider selected centered group. Thin paths travel upward from each P to ONLY selected receiver elements. Labels 'Shallow: fewer channels', 'Deep: more channels'. This is dynamic receive aperture for the same F-number. Probe top, depth downward throughout.
~~~

</details>

<details>
<summary>coherent_processing.png</summary>

~~~text
Use case: scientific-educational. Asset: Chinese ultrasound beamforming course and projected lecture slide. Landscape 1536x1024, polished textbook illustration on white, restrained soft 3D cutaway and precise clean linework, blue ultrasound probe at top, tissue pale translucent blue, orange focus, teal receive paths, plentiful whitespace. All labels exact short English only, large legible. No invented equations, no numerical values, no logos, no watermark. Conceptual illustration, not a quantitative acoustic field. A wide three-stage teaching illustration, left-to-right flow with generous spacing and crisp labels. Title 'Keep phase until the sum'. Stage 1 label 'Delayed channels': four equally spaced colored sinusoidal wave packets drawn with clear signed oscillations and all pulse centers aligned on a vertical dashed line; identical phase at center. Stage 2 label 'Coherent sum': four arrows converge to one larger sinusoidal wave packet, retaining positive and negative swings. Stage 3 label 'Envelope + dB': small abstract smooth positive envelope around a packet then a grayscale ultrasound thumbnail with point-like bright dots, title only, no numeric scales. Arrows strictly left-to-right; show no abs operation on individual channels. Minimal educational conceptual infographic integrated with soft 3D probe miniature above stage1, no equations, no invented numeric values.
~~~

</details>

<details>
<summary>coherent_processing.png 的编辑提示词</summary>

~~~text
Edit this course illustration. Change ONLY the ultrasound thumbnail in the bottom right: replace the fan-shaped / sector-shaped ultrasound view with a rectangular B-mode grayscale image appropriate for a LINEAR array, filling a rectangle with subtle speckle and three point-like bright dots at different depths. No triangular mask, no circular bottom boundary, no sector geometry. Keep all title text, waveforms, arrows, probe miniature, all colors, white background and layout exactly as they are. The thumbnail is a conceptual generated illustration, not measured data.
~~~

</details>
