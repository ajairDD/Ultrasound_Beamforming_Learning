# 第二章 AI 概念插图提示词

使用 Codex 内置 `image_gen`，白色背景 PNG；最终图片均已复制到本目录。它们解释算法关系，不作为声场测量、重建真值或数值性能证据。

## 1. aligned_aperture_concept.png

Use case: scientific-educational. Asset: landscape classroom illustration for an introductory medical ultrasound beamforming course. White background, polished restrained scientific textbook style, blue/teal with warm orange for emphasis, crisp large English labels and plenty of space.
Primary concept: the input to coherence weighting is the complex samples taken AFTER per-channel time alignment, for ONE candidate pixel and ONE transmit event.
Composition: left half shows a horizontal linear ultrasound probe of exactly eight rectangular elements at the TOP, tissue below, a single candidate pixel P below the center. Eight return paths join P to the eight receiving elements; outer paths longer, central paths shorter. Label "ONE PIXEL P" and "Rx 1 ... Rx 8". No transmit field, no false sector scan.
Right half shows eight separate RF oscillatory trace rows, with a different orange sample dot on each row at its predicted query time. A rightward arrow labeled "Delay + interpolation" leads to a tidy line of eight small phasor arrows all broadly aligned pointing upward, labeled "Aligned complex samples". Small bottom note exactly "Same pixel. Different query times." Do not depict the samples as all taken at one original time. The phasor arrows represent complex numbers, not acoustic propagation.
Only the quoted short labels. No equations, numerical data, watermark, or claims of measured results. Physical geometry and workflow must be unambiguous.

## 2. cf_phasor_intuition.png

Use case: scientific-educational. Asset: landscape explanatory infographic for a beginner ultrasound course on coherence factor CF. White background, generous whitespace, elegant textbook diagram, clear blue/teal arrows and orange comparison arrows, large readable English short labels.
Three equal panels side by side. Panel A label exactly "Equal amplitude + phase". Show eight equal length complex phasor arrows parallel upward, and a large sum arrow upward below them. Caption "CF = 1".
Panel B label exactly "Phase cancellation". Show eight equal length phasor arrows in four opposite pairs around a circle, and a zero resultant indicated by a dot, caption "CF = 0". No accidental nonzero sum.
Panel C label exactly "One active contribution". Show ONE upward arrow at channel 1 plus seven small gray zero dots at channels 2-8; the aperture still contains eight channels. Show a resultant equal to the one arrow, caption "CF = 1/8". This is a numerical teaching vector, not a measured image.
Bottom note exactly "CF depends on phase AND amplitude distribution".
All three panels have channel labels 1 through 8 and no decorative sine plots, no medical scan, no other equations, no watermark. The message is that matching phases alone is insufficient when channel amplitudes are uneven. Phasor arrows are complex vectors, not rays in tissue.

## 3. cf_processing_pipeline.png

Use case: scientific-educational. Asset: wide landscape classroom infographic explaining CF and GCF image weighting after conventional DAS. White background, clean academic publication style, bold legible short English labels, blue/teal workflow, orange weight branch.
A single left-to-right workflow. Left block "Aligned Rx vector s" contains small phasors. It splits into TWO independent branches from the SAME vector. Upper blue branch block "Sum over Rx" outputs a block "Complex DAS S". Lower orange branch block "CF or GCF" outputs a block "Real weight W: 0 to 1". The two branches join a large multiplication symbol, yielding "Weighted complex pixel W x S". Finally arrow to "Envelope, then dB".
Make the fork and join unambiguous with arrows; the coherence branch must originate from the aligned vector, not from the summed DAS, envelope or B-mode image. Multiplication occurs before envelope. Do not draw noise removed by a filter or a different Tx/Rx delay. Include small bottom note "One Tx. One pixel. Receive-domain weighting." No numerical image content, no watermark, no invented formulas beyond the labels.

## 4. aperture_spatial_spectrum.png

Use case: scientific-educational. Asset: wide landscape concept diagram for understanding aperture FFT in ultrasound CF/GCF. White background, professional textbook illustration, restrained blue/teal, orange highlighted spectrum bins; large English labels.
Three horizontal rows. Each row has left eight COMPLEX PHASOR arrows distributed along receive channel index, center a right arrow "FFT over Rx", right a schematic discrete spatial spectrum with horizontal axis label "Spatial bin k" and clearly separated central ticks -1, 0, +1.
Row 1 "Constant vector": eight equal upward arrows, spectrum has exactly one spike at k=0 with label "DC".
Row 2 "One-bin phase ramp": eight equal arrows rotating by 45 degrees per channel counterclockwise, starting right then northeast then up then northwest then left then southwest then down then southeast; spectrum has exactly one spike at k=+1, ZERO DC, caption "Structured variation".
Row 3 "Irregular phases": eight equal arrows with irregular directions, spectrum has several schematic unequal spikes spread across bins, caption "Energy spread". No exact quantitative values for this random schematic.
Bottom prominent note "This FFT is across channels, not across time." No temporal frequency Hz label, no sine waves, no measured RF or B-mode, no assertion ramp correct target. Concept illustration, not output of MATLAB.

## 5. gcf_bandwidth_tradeoff.png

Use case: scientific-educational. Asset: landscape classroom illustration of the GCF low-spatial-frequency bandwidth choice. White background, polished blue/teal academic style with orange included spectrum regions, large readable English labels.
Three equal panels left-to-right, same schematic discrete aperture-energy spectrum in EACH panel across bins -4 to +4 (zero in center). Nonnegative stem heights unchanged across panels, a tallest DC stem plus visible adjacent stems. Do not put quantitative y-axis values.
Panel1 label "M0 = 0"; highlight ONLY the DC stem orange, all others gray. Caption "CF: DC only".
Panel2 label "M0 = 1"; highlight ONLY stems -1,0,+1 orange. Caption "GCF: allow nearby bins".
Panel3 label "Wider band"; highlight ALL depicted stems orange. Caption "More energy included".
Use small translucent selection spans behind only the included stems. Bottom two short statements exactly "Wider band preserves more contributions" and "Wider band also weakens suppression".
No promise of resolution gains, no before/after clinical image, no equations, no filter waveform, no watermark. Clarify the diagram shows selection for a ratio, not erasing excluded signal and then inverse FFT. Include subtle bottom note "Weighting criterion, not phase correction."

## 定向校正记录

第一张先将取样位置改为与中心像素对称的查询时间，再删除精确相位容易产生歧义的示意波形，改为明确的时间轴与查询点。第五张将能量轴改为 `Spectral energy`，避免与幅值混用。

### 第一张：波形和查询位置校正

Edit this ultrasound teaching illustration. Preserve the left probe and pixel geometry, all eight channel labels, the large rightward workflow arrow, the eight aligned phasor arrows on the right, and white academic style. Correct ONLY the eight RF trace rows in the middle so they are physically consistent with the centered pixel and symmetric array: Rx1 and Rx8 have the LATEST identical echo/query positions; Rx2 and Rx7 the next latest; Rx3 and Rx6 slightly earlier; Rx4 and Rx5 have the EARLIEST identical positions. Use the same full oscillatory pulse on each row shifted horizontally with its query position, so the orange dot samples the SAME POSITIVE CENTRAL PEAK on every RF pulse. Horizontal time increases to the right on every trace. Positions must form a symmetric pattern versus channel index, not a monotonic staircase. Orange dots must sit on matching positive peaks, never at unrelated phases of an unshifted waveform. Add one small readable label "Record time increases to the right". Keep the existing captions "Same pixel. Different query times." and "Delay + interpolation". This is an ideal single-scatterer conceptual drawing, not a measured scan. No other changes or extra content.

### 第一张：最终时间轴示意

Edit this educational illustration ONLY in the center eight time rows. Remove ALL oscillatory blue waveform wiggles. Replace each with a straight thin horizontal blue time axis of identical start and end coordinates, leaving one orange query-time dot ON each straight axis. Keep the query dots' symmetric horizontal locations: Rx1=Rx8 latest on right, Rx2=Rx7 next latest, Rx3=Rx6 earlier, Rx4=Rx5 earliest. Preserve the channel row labels, left probe/pixel geometry, right eight aligned phasors, all workflow arrows and captions, white scientific style. Add a small center label "Query times (schematic)". This deliberately depicts time selection without claiming precise RF phase or waveform. No sine curves, no amplitudes, no new elements. Preserve everything outside the central time axes.

### 第五张：能量轴标签

Edit only the three vertical-axis labels of this GCF diagram. In ALL three panels, the exact label must be "Spectral energy". Delete the current wording "Aperture energy (spectrum magnitude)"; energy is squared magnitude, so the parenthetical wording is scientifically incorrect. Keep every spectrum stem and height, highlight selection, panel title, horizontal bin label, bottom statements, typography style and layout otherwise unchanged. Use two words only for all vertical axes: "Spectral energy". No other modifications.
