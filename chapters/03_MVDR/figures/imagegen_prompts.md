# 第三章文生图提示词与校正记录

这些图由 Codex 内置 `image_gen` 逐张生成。最终 PNG 已复制到本目录；以下保留实际使用的初始提示词与定向编辑提示词，方便复现构图意图。模型生成不是确定性计算，即使复用提示词，也应再次检查科学含义。

概念图不按比例；矩阵颜色、相量长度与示意柱高不能作为测量值。真实算法与结果以 MATLAB 代码、实际导图和数值日志为准。

## 1. das_cf_mvdr_concept.png

最终文件：[das_cf_mvdr_concept.png](das_cf_mvdr_concept.png)

初始提示词：

~~~text
Create a polished educational illustration for an introductory medical ultrasound beamforming lecture. Landscape 16:9, bright white background, generous whitespace, crisp large English labels, restrained teal/blue/orange palette, approachable flat technical illustration with subtle shading. Scientifically precise schematic, no decorative equations or invented results, no photographs or B-mode simulation. All text legible at classroom projection size. Small footer: 'Concept illustration - not measured data'.
Title 'Where do the weights act?'. Three separate horizontal rows share the same left input: six delayed complex Rx samples, represented by small amplitude/phase arrows. Row 1 labeled 'DAS': equal channel weights -> coherent sum -> envelope. Row 2 labeled 'CF / GCF': equal channel weights -> coherent sum -> multiply by ONE real pixel weight W -> envelope; a thin branch takes the input vector before its sum to calculate W. Row 3 labeled 'MVDR': input -> adaptive complex channel weights w -> coherent sum -> envelope; covariance estimation branches from input to w. Make the contrast visually obvious: CF/GCF weight ONE summed pixel; MVDR weights channels BEFORE the sum. No implication that MVDR is an image filter. Use only those short labels. Output placeholders are simple gray tiles, no promise of improvement.
~~~

定向编辑 1：

~~~text
Edit this existing educational illustration, preserving its style, title, three-row layout and all correct arrow connections. Repair the channel counts: in EACH of the DAS and CF/GCF rows there must be exactly SIX individual boxes labeled 1, one per input phasor x1 through x6, and exactly six corresponding arrows into the coherent sum. Currently too few weight boxes are drawn in those rows. In the MVDR row preserve exactly six boxes, but label them 'w1*', 'w2*', 'w3*', 'w4*', 'w5*', 'w6*' to indicate conjugated weights as used by w^H x. Keep six phasors in EACH input card. Preserve the covariance branch before summation and the CF weight W applied after summation. Do not change other content or invent image results.
~~~

定向编辑 2：

~~~text
Edit this educational illustration, preserve the overall title, colors and three-row structure. Simplify the FIRST TWO rows: remove their individual little channel-weight boxes and their multiple connecting arrows. Replace the entire Equal channel weights stack in each of DAS and CF/GCF with ONE clean blue box labeled 'All weights = 1'. Use ONE arrow representing the complete vector from the input card to this box, then ONE arrow from the box to the coherent sum. This avoids misleading channel counts and improves readability. Preserve all six input phasors per row. Preserve the MVDR row with six weights w1* through w6*, and the orange CF/GCF branch calculating W from input before sum and applying W after sum. All other content remains unchanged.
~~~

检查记录：第一次编辑修正了共轭星号，但固定权重小格数仍不准确；第二次把固定权重改为整体向量的 `All weights = 1`，避免通道数的误导，保留六个输入观测与六个 MVDR 权重。

## 2. mvdr_distortionless_concept.png

最终文件：[mvdr_distortionless_concept.png](mvdr_distortionless_concept.png)

初始提示词：

~~~text
Create a polished educational illustration for an introductory medical ultrasound beamforming lecture. Landscape 16:9, bright white background, generous whitespace, crisp large English labels, restrained teal/blue/orange palette, approachable flat technical illustration with subtle shading. Scientifically precise schematic, no decorative equations or invented results, no photographs or B-mode simulation. All text legible at classroom projection size. Small footer: 'Concept illustration - not measured data'.
Title 'Preserve the expected pattern'. Three large cards from left to right linked by arrows. First 'After delay alignment': six equal-length blue phasors pointing right, label 'Expected target a'; below them six orange phasors with a phase slope, label 'Other spatial pattern'. Second 'Choose complex weights': a small blue/orange knob board representing amplitude and phase choices, label 'Minimize estimated output power'. Third 'One constraint': a blue target arrow exits labeled 'Gain = 1 for a'; a separate subdued orange arrow exits labeled 'Other responses may be reduced'. Important: the blue gain 1 is only for the EXPECTED steering pattern a. Do not show noise entirely eliminated, do not draw stronger brightness or narrower image promises. At bottom small plain text 'Adaptive weights + a preservation constraint'. Friendly visual analogy of keeping a known musical chord while changing mixer knobs, but no irrelevant instruments.
~~~

## 3. mvdr_spatial_smoothing.png

最终文件：[mvdr_spatial_smoothing.png](mvdr_spatial_smoothing.png)

初始提示词：

~~~text
Create a polished educational illustration for an introductory medical ultrasound beamforming lecture. Landscape 16:9, bright white background, generous whitespace, crisp large English labels, restrained teal/blue/orange palette, approachable flat technical illustration with subtle shading. Scientifically precise schematic, no decorative equations or invented results, no photographs or B-mode simulation. All text legible at classroom projection size. Small footer: 'Concept illustration - not measured data'.
Title 'One aperture, several overlapping subarrays'. Exactly six receiver sample blocks in one top horizontal row labeled 1,2,3,4,5,6, with header 'M = 6 channels'. Four rows beneath, each shows exactly three linked blocks: row 1 positions 1,2,3; row 2 positions 2,3,4; row 3 positions 3,4,5; row 4 positions 4,5,6. Label each row 'u1', 'u2', 'u3', 'u4' respectively. Highlight the overlapping selections, without creating extra channels. Right side show one rectangular matrix X with exactly 3 rows and 4 columns, each column tinted to match its selected subarray. Label 'L = 3', 'P = M - L + 1 = 4', and 'X: [L x P]'. Bottom short label 'Average outer products to estimate R'. No actual numeric covariance values, no sum-over-Tx. Every subarray is a Rx selection for the same pixel and same transmit.
~~~

## 4. mvdr_axial_covariance.png

最终文件：[mvdr_axial_covariance.png](mvdr_axial_covariance.png)

初始提示词：

~~~text
Create a polished educational illustration for an introductory medical ultrasound beamforming lecture. Landscape 16:9, white background, generous whitespace, crisp large English labels, restrained teal/blue/orange palette, flat technical illustration with subtle shading. Scientifically precise schematic, no invented numbers or performance promises. Small footer: 'Concept illustration - not measured data'.
Title 'Neighbors estimate weights; the center forms the pixel'. Left: a grid of aligned complex Rx sample arrows. Horizontal axis 'Rx channel', vertical axis 'Depth'. Seven rows of samples; highlight only the center row in orange labeled 'Current depth z0'; three blue rows above and three below are 'Axial neighbors'. Thin bracket on the left 'Half-window h'. Middle top: arrows from ALL selected rows to a blue covariance block labeled 'Estimate R', then to a block 'Solve for w'. Middle bottom: a separate orange path from ONLY THE CENTER ROW to a block 'Current subarrays X0'. Right: w and X0 merge in a summation block labeled 'Current pixel y'. Important: no neighboring row goes directly into the pixel sum; no image smoothing icon or blur. Bottom statement 'Covariance averaging is not output-image averaging'. A tiny ultrasound probe silhouette can establish setting, but no decorative unrelated image.
~~~

定向编辑 1：

~~~text
Edit this existing illustration for scientific precision, preserving its clean white style and main layout. The covariance block must receive ALL SEVEN sample rows, not only the top three and center: add a clearly visible blue collection bus beside the sample grid that joins the three rows BELOW the orange current row as well as the three above, and joins the current row too, then flows to 'Estimate R'. Keep the separate orange center-only output path unchanged. Replace the left depth row labels z0-3,z0-2,z0-1,z0,z0+1,z0+2,z0+3 by '-3','-2','-1','0','+1','+2','+3', and replace vertical axis text with 'Depth offset (grid steps)'. Keep orange row label 'Current depth z0'. Replace both half-window bracket labels by 'h = 3 steps'. Replace the text '(z0 - h ... z0 + h)' above covariance with 'Seven selected depths'. The output node should read 'Current pixel y = M mean(w^H X0)' instead of a bare summation symbol, so it clearly includes conjugation, subarray average and amplitude scaling. Do not send neighboring rows directly to the current pixel output.
~~~

## 5. mvdr_diagonal_loading.png

最终文件：[mvdr_diagonal_loading.png](mvdr_diagonal_loading.png)

初始提示词：

~~~text
Create a polished educational illustration for an introductory medical ultrasound beamforming lecture. Landscape 16:9, white background, generous whitespace, crisp large English labels, restrained teal/blue/orange palette, flat technical illustration with subtle shading. Scientifically precise schematic, no invented numbers or performance promises. Small footer: 'Concept illustration - not measured data'.
Title 'Diagonal loading stabilizes the weight calculation'. Three panels. Left 'Estimated R': a square symmetric covariance heatmap, with some strong and weak modes; short label 'Limited snapshots'. Middle 'Add scaled identity': square identity matrix with orange diagonal entries and blank zero off-diagonal cells; exact short formula 'R_loaded = R + rho I'. Right 'Raise the eigenvalue floor': two small bar charts, BEFORE top and AFTER bottom, each EXACTLY six sorted positive eigenvalue bars, decreasing heights. AFTER adds the SAME small orange cap rho to every bar; do not draw unequal increments. Caption 'Every eigenvalue increases by rho'. Bottom concise text 'More loading: more stable solve, less adaptive freedom'. No claims of new data or better clinical image. The heatmap is conceptual, not numeric experiment.
~~~

定向编辑 1：

~~~text
Edit this existing teaching illustration while preserving its title, three-panel layout, matrix formula, colors and short explanations. Fix the dimensions: replace the left covariance heatmap with EXACTLY a 6 by 6 grid (six rows and six columns), symmetric about the diagonal, with six strong diagonal cells and modest symmetric off-diagonal cells. Its dimensions must match the middle 6 by 6 scaled identity and the six eigenvalue bars. In the AFTER bar plot keep exactly the same blue bar heights as BEFORE on the same scale, then add an equal-height small orange cap rho to EACH of the six bars. Preserve six bars, sorted eigenvalues, and label 'Every eigenvalue increases by rho'. Leave the middle identity matrix correct: rho on six diagonal cells and zero elsewhere. No extra rows, columns, bars or invented measurements.
~~~

## 6. mvdr_rtb_pipeline.png

最终文件：[mvdr_rtb_pipeline.png](mvdr_rtb_pipeline.png)

初始提示词：

~~~text
Create a polished educational illustration for an introductory medical ultrasound beamforming lecture. Landscape 16:9, white background, generous whitespace, crisp large English labels, restrained teal/blue/orange palette, flat technical illustration with subtle shading. Scientifically precise schematic, no invented numbers or performance promises. Small footer: 'Concept illustration - not measured data'.
Title 'Receive MVDR inside the RTB pipeline'. Three transmit events labeled Tx 1, Tx 2, Tx 3 in three separate rows. Each row flows left-to-right: 'Pixel delay + Rx samples' -> 'Receive MVDR' -> 'Shared Tx weight t_k'. A small orange pixel marker P appears as the same candidate position in all three rows. All three row outputs flow to one common block 'Coherent sum across Tx', then 'Normalize by sum of Tx weights', then one output tile 'RTB-MVDR pixel'. Exactly these labels, separate receive direction (inside each Tx) from transmit direction (merging rows). At bottom two statements: 'Weights w are estimated within each Tx' and 'RTB-DAS uses the same geometry and Tx weights'. No covariance estimated across Tx, no magnitude before coherent sum, no claim about speed or resolution.
~~~

定向编辑 1：

~~~text
Edit this existing RTB pipeline illustration, preserving all correct algorithm steps, text, arrows, three transmit rows, and colors. Change ONLY the far-right output icon: remove the simulated gray ultrasound/B-mode image entirely. Replace it with a simple neutral gray pixel square containing a small orange point P, with the existing text 'RTB-MVDR pixel' above it. This is a single output-pixel schematic, not measured or simulated ultrasound image evidence. Keep the footer 'Concept illustration - not measured data'.
~~~

## 7. mvdr_steering_mismatch.png

最终文件：[mvdr_steering_mismatch.png](mvdr_steering_mismatch.png)

初始提示词：

~~~text
Create a polished educational illustration for an introductory medical ultrasound beamforming lecture. Landscape 16:9, white background, generous whitespace, crisp large English labels, restrained teal/blue/orange palette, flat technical illustration with subtle shading. Scientifically precise schematic, no invented numbers or performance promises. Small footer: 'Concept illustration - not measured data'.
Title 'The preservation constraint follows the assumed pattern'. Three panels with minimal English text. Left 'Assumed a': six equal-length blue phasor arrows all pointing right, label 'Perfect delay alignment'. Middle 'Actual a_true': six equal-length orange phasor arrows with a small cumulative angle slope from 0 to 45 degrees, label 'Residual phase error'. Right two clean cards: blue card 'w^H a = 1' and orange card '|w^H a_true| may be < 1'. Connect blue assumed vector to blue card and orange actual vector to orange card. Bottom sentence 'A target can be attenuated when the assumed and actual patterns differ'. Do not show target always lost or prove causes of real-data attenuation. No B-mode, no null plot or quantitative gain. Both vector sets have exactly six phasors; this is a concept of model mismatch.
~~~

定向编辑 1：

~~~text
Edit this educational illustration, preserving the six blue nominal phasors, six orange actual phasors, formulas, short explanation, white background and colors. Remove both numeric angle annotations '45 degrees' and '0 degrees' and remove the dashed curved angle guide; the orange phasors are qualitative and should not carry quantitative angles. Preserve the orange phasor directions as a qualitative residual phase slope. Ensure the blue unit-gain card refers to the blue 'Assumed a' and the orange possible attenuation card refers to the orange 'Actual a_true'; color alone is sufficient, do not introduce crossing connector lines. Do not change the mathematical formulas or add angle measurements.
~~~
