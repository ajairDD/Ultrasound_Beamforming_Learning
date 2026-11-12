# 第四章 AI 概念图提示词

以下图片使用内置 image_gen 工具生成，成品保存在本目录。图中曲线与几何均为概念示意，不是测量数据；数值曲线与真实 UFF 配图由 MATLAB 生成。每张成品均需经过科学内容和可读性检查。

## 1. fdmas_pipeline_concept.png

```text
Use case: scientific-educational. Asset type: landscape lecture illustration for a beginner ultrasound beamforming course, Chapter 4. Create a polished raster scientific infographic, wide 16:9, white background, navy text, teal for real RF input, orange for nonlinear processing, violet for filtering. Large readable English labels, restrained diagrams with soft depth, no watermark.
Title exactly "From delayed RF to an fDMAS image".
Top left: a linear ultrasound array above one small target P in tissue. Beside it show four RF traces with staggered arrival times, then the SAME traces aligned after a box "Tx + Rx delays / interpolation / Rx aperture". Treat this aligned-data box as the shared starting point.
Then TWO clearly separated branches. Upper blue branch: "Analytic RF samples" -> "DAS: coherent sum" -> "Envelope" -> "B-mode". Lower orange branch: "REAL RF samples" -> "Signed-sqrt pair sum" -> "Pair-count normalization" -> violet "Bandpass near 2f0" -> "Analytic envelope" -> "B-mode". The two B-mode outputs must be neutral abstract square pixel grids, not invented anatomical images or apparent measurements.
At bottom highlight exactly "Same geometry and aperture. Different receive combination." and "The bandpass acts along depth AFTER the nonlinear pair sum."
Constraints: every arrow has a clear source and destination; do not connect DAS output into DMAS. No covariance, matrix inverse, channel IQ multiplication, beamforming across transmit events, performance claims, or detailed equations. RF icons are qualitative, not measured waveforms.
```

## 2. dmas_pairs_concept.png

```text
Use case: scientific-educational. Asset type: wide 16:9 explanatory raster figure for a beginner ultrasound DMAS lecture. Clean white background, very readable navy English labels, teal positive accents, orange pair connections, thoughtful spacing and subtle depth, no watermark.
Title "Four receive channels make six unique pairs".
Left half: four clearly numbered receiver channels 1, 2, 3, 4 arranged on a square. Connect EVERY unordered pair exactly once: (1,2), (1,3), (1,4), (2,3), (2,4), (3,4). Draw exactly the four perimeter edges and two diagonals; no self-loop, no repeated edge. Nodes large; at diagonal crossing no extra node.
Right half: a neat upper-triangular 4 by 4 pairing table. Column labels 1 2 3 4 and row labels 1 2 3 4. Highlight ONLY six cells above the main diagonal, each labeled by pair: "1,2" "1,3" "1,4" "2,3" "2,4" "3,4". Diagonal and lower triangle pale gray. Label diagonal "No self-pairs"; lower triangle "No duplicates". Keep text outside rather than crowding cells.
Bottom: a small sequence "Aligned real RF" -> "Signed square root in each channel" -> "Multiply each unique pair" -> "Sum all pair contributions". The channel input must come BEFORE the nonlinear operation.
Footer exactly "Six pair terms do not mean six independent measurements."
Avoid invented numeric data or any claim that all inconsistent signals cancel. This is a conceptual pairing illustration, not a clinical image.
```

## 3. dmas_sign_rectification.png

```text
Use case: scientific-educational. Asset type: wide 16:9 lecture concept illustration for signed-sqrt DMAS. Crisp white background, navy typography, teal RF traces and orange nonlinear outputs, large simple labels, no watermark. All curves are qualitative schematic illustrations, not data.
Title "Why DMAS loses the global RF sign".
Three vertical panels, with generous margins.
Panel 1 heading "All channels aligned". Draw four identical real sinusoidal RF traces with positive AND negative half cycles. Below show an icon with four +1 inputs, and a second icon with four -1 inputs. Label these examples "Same positive sample" and "Same negative sample".
Panel 2 heading "Products keep pair agreement". Both four +1 inputs and four -1 inputs independently flow to a box "Every pair contributes +1". Then a single label "Unnormalized pair sum = 6". Use the number 6 only for these four-channel equal-amplitude examples.
Panel 3 heading "Full-wave-like output". Draw one signed sinusoid labeled "DAS ~ s" and below an all-nonnegative rectified sinusoidal trace labeled "Normalized DMAS ~ |s|". Both positive and negative RF lobes become upward DMAS lobes. Correct footer "For M identical RF samples: DAS = M s; normalized DMAS = M |s|".
Bottom takeaway exactly "Global sign reversal gives the same DMAS output. Filtering must come before envelope detection."
Do not label raw DMAS as an envelope image, and do not claim that a single negative DMAS value indicates absence of a target. No numerical axes, phantom B-mode images, artificial measurement charts or performance claims.
```

## 4. fdmas_digital_frequency.png

```text
Use case: scientific-educational. Asset type: wide 16:9 scientific lecture raster illustration on the frequency origin in fDMAS. White background, navy large English text, teal physical-path elements, orange digital nonlinear block, violet bandpass, subtle elegant dimensional shading, no watermark.
Title "The 2f0 component is created digitally".
Upper path: "Transmit near f0" beside an ultrasound probe -> "Echo RF near f0" beside receive waveform -> a clearly drawn computer boundary containing "Signed-sqrt DMAS" -> "Low frequency + even harmonics" -> "Bandpass near 2f0" -> "Filtered RF-like output".
The probe and tissue should look like an educational cutaway, not an actual clinical scan. Digital operations entirely inside the computer boundary. The echo before computer is still labeled f0.
Lower portion: three qualitative spectrum sketches with horizontal axis "Frequency". First "Before multiplication" shows a bump near "f0". Second "After nonlinear pairing" shows an obvious low-frequency lobe and distinct lobes near "2f0" and smaller "4f0"; label "Schematic, not to scale". Third "After bandpass" emphasizes only the neighborhood of "2f0" in violet. Make f0, 2f0 and 4f0 ordered with equal proportional spacing along these schematic frequency axes. No invented numerical axis or amplitude values.
Bottom takeaway exactly "Digital 2f0 is not evidence of tissue-generated second harmonic imaging."
Additional small line "Signed square roots can create more than DC and 2f0."
Avoid any image implying sound propagation itself doubles the frequency here. No claims of better resolution, no IQ multiplication, no covariance matrices.
```

## 5. fdmas_depth_sampling.png

```text
Use case: scientific-educational. Asset type: wide 16:9 explanatory raster lecture figure about output-depth sampling in fDMAS. Clean white background, navy large typography, teal good-grid path, orange coarse-grid path, violet bandpass, no watermark.
Title "A fine depth grid is needed AFTER beamforming".
Top: a single raw-RF acquisition panel labeled "Raw data sampling fs" splits into two output depth grids. Explicit subtitle "Output-grid refinement does not acquire new RF data".
Left panel heading "Fine output depth grid". Draw a depth ruler with many evenly spaced points and label "dz = lambda / 16". Beneath display exactly "fs,z = c / (2 dz) = 8 f0" and "Nyquist = 4 f0". A violet band marked "1.5 to 2.75 f0" fits BELOW a clearly placed Nyquist limit at 4 f0. Use a green check "Filter band fits".
Right panel heading "Coarse output depth grid". Draw a depth ruler of the same total span with four times fewer evenly spaced points and label "dz = lambda / 4". Beneath display exactly "fs,z = 2 f0" and "Nyquist = f0". The SAME violet band "1.5 to 2.75 f0" lies ABOVE the limit f0. Use an orange warning label "Filter band does not fit". Do not draw a plausible recovered waveform from the coarse grid.
Footer exactly "Image-time approximation: t = 2z/c. This check covers the chosen band, not every nonlinear harmonic."
Ensure sample-spacing ratio and all algebra correct. No depiction of interpolation creating independent measurements. No acoustic resolution claims.
```

## 6. dmas_dynamic_aperture.png

```text
Use case: scientific-educational. Asset type: landscape 16:9 ultrasound lecture raster illustration of receive-aperture normalization in signed-sqrt DMAS. White background, navy clear English labels, teal probe/aperture, orange channel pairs. Airy, professional classroom layout with subtle depth, no watermark.
Title "More active channels also means more pairs".
Left: physical ultrasound probe cross section with a shallow pixel P1 and deeper pixel P2 on one scanline, depth downward. A narrow teal receive aperture at the array links to shallow P1; a wider teal aperture links to deep P2, illustrating constant receive F-number. Do not suggest changing transmit focus. Label "Shallow: fewer active Rx channels" and "Deep: more active Rx channels". The diagram is schematic.
Right: TWO neatly aligned numeric cards. Top exactly "M = 6", "Unique pairs = 15". Bottom exactly "M = 12", "Unique pairs = 66". Avoid drawing all pair edges. Both cards have the explicit assumption "All active RF samples equal s".
Bottom explanatory strip with three boxes in order: "Pair sum: M(M-1)|s| / 2" -> "Multiply by 2 / (M-1)" -> "Normalized output: M|s|". Below in smaller type "For M >= 2. A project scaling convention, not the definition of DMAS."
Final takeaway exactly "Normalization removes the quadratic pair-count factor; it does not calibrate fDMAS brightness to DAS."
Constraints: formulas and counts must be exact, same s in both cases, no claim of signed amplitude preservation, no B-mode data or universal performance claim.
```

## 成品检查与定向修订

### fdmas_digital_frequency.png

```text
Edit only the lower three schematic frequency plots. Preserve every other visual, title, tissue diagram, digital processing path, and explanatory text. The lower frequency axes currently place f0, 2f0 and 4f0 at equal tick spacings, which is numerically misleading. Remove ALL numeric frequency ticks in the three lower plots. Keep horizontal axes labeled Frequency. Instead place free-floating descriptive labels directly near the appropriate bumps: first plot 'Input band near f0'; second plot 'Low frequency', 'Near 2f0', 'Higher even harmonics'; third plot 'Selected band near 2f0'. Label the row 'Qualitative spectra; no numeric frequency scale'. Keep the three illustrative spectra themselves in place, do not add apparent measured charts. Preserve the footer that the 2f0 component is created digitally. This is one targeted scientific labeling correction.
```

### fdmas_depth_sampling.png

```text
Edit only the two output-depth ruler drawings. Preserve every formula, title, color, arrow, frequency filter and Nyquist graphic, all explanatory text and layout. The fine and coarse rulers need an exact 4:1 interval ratio. Replace the left fine ruler with EXACTLY 17 green dots, equally spaced across a fixed horizontal line, including dots at BOTH endpoints. Replace the right coarse ruler with EXACTLY 5 orange dots equally spaced across a line of the SAME length, including both endpoints. These are 16 versus 4 intervals, matching dz=lambda/16 versus lambda/4 for a total span of one wavelength. Remove endpoint labels z+L and replace with z+lambda on BOTH rulers; retain z at the left endpoint. No other edits. Ensure no extra ticks, dot-like decorations or missing dots. Labels and correct algebra must remain unchanged.
```

### dmas_dynamic_aperture.png

```text
Correct only the left ultrasound geometry. Preserve the title, the two numeric cards on the right (M=6/pairs15 and M=12/pairs66), and ALL formulas and explanatory text at the bottom. The current lower row of Rx elements floats inside tissue, which is physically misleading. Replace the entire left drawing with TWO clearly separated side-by-side small panels labeled 'Shallow pixel' and 'Deep pixel'. Each panel has its own linear probe drawn at the TOP at exactly the SAME vertical level. Each probe has a teal active aperture on the probe surface; the shallow panel aperture is narrower, the deep panel aperture wider. Rays from each active aperture converge downward to its own target, with P1 at shallow depth and P2 at a greater depth. The two panels illustrate the same fixed receive F-number at different depths. All Rx elements must stay on their probe's surface at the top, NEVER at the tissue target or between targets. Use a downward Depth arrow beside the panels. Do not draw any transducer row inside the tissue. Keep the geometry schematic and avoid counts on the small drawn elements. No new text beyond these labels.
```

### fdmas_depth_sampling.png：第二次修订

第一次定向修改后，密网格圆点数仍未准确对应一个波长内的 16 个间隔。最终改用两个相邻采样点与间距箭头，避免 AI 示意图承担精确点数表达；精确采样序列见 MATLAB 图 11。

```text
Make one precise simplification of this lecture diagram. Preserve ALL formulas, titles, raw RF panel, arrows, frequency-band diagrams, Nyquist labels and footer. Replace ONLY the fine and coarse depth-dot rulers with simple spacing icons, so the figure makes no exact dot-count claim. In each panel show exactly TWO depth sample dots on a short horizontal line, with a double-headed spacing arrow BETWEEN those two dots. Fine panel: the two dots close together, arrow labeled 'dz = lambda/16'. Coarse panel: the two dots visibly farther apart, arrow labeled 'dz = lambda/4'. Remove the old endpoint labels z and z+lambda, and remove the old long multi-dot rulers completely. Label each little icon 'Sample spacing (schematic)'. The existing headings already name fine and coarse. Keep the rest of the figure EXACTLY unchanged, especially fs,z=8 f0 vs 2 f0 and Nyquist 4 f0 vs f0. Use large readable labels, no added number axes.
```

## 最终选图核对

六张最终 PNG 均已保存到本目录。检查覆盖：流程分支与滤波顺序、四通道六条边及六个上三角格子、四个正 / 负输入的 pair sum、动态孔径均位于探头表面、数字频带的定性标签、粗细网格的公式与 Nyquist 关系。动态孔径的探头分块不按卡片 M 逐个绘制，正文已说明；定量采样与波形均以实际 MATLAB 配图为准。
