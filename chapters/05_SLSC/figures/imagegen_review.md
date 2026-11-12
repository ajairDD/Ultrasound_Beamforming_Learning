## 首轮核对后的定向校正

### slsc_pipeline_concept.png

~~~text
Edit this SLSC textbook illustration precisely. Preserve the Chinese typography, white background, two method rows and overall composition. SCIENTIFIC CORRECTION 1: BOTH branches MUST originate AFTER the BOTTOM shared box ‘当前有效接收孔径’. Remove the current arrow from the top RF box into DAS. Route a single output from the bottom shared box to a clearly visible fork; from this fork, one arrow travels up to the DAS row and one to the SLSC row. Every path must traverse RF -> Tx/Rx 延时与插值 -> 当前有效接收孔径 BEFORE splitting. CORRECTION 2: replace ‘候选像素（聚焦点）’ with ‘候选像素 P’. CORRECTION 3: inside the ‘近邻阵元对的归一化相关’ panel, remove the incorrect orange Q badge and double-headed horizontal arrow; replace with a small circle labeled Greek ρ (rho), indicating the computed correlation, using a one-way arrow. Replace Rx_{i+1} with Rx_{i+m} if space permits; this comparison is general spatial lag. CORRECTION 4: the RF-window input icon has depth rows and Rx columns; show a SHORT horizontal band of adjacent depth rows spanning several fixed columns, not a full-depth vertical column selection. Preserve all other intended Chinese text and correct processing order. Output drawings remain conceptual, not measured images.
~~~

### slsc_axial_gate.png

~~~text
Edit only the 7-row by 6-column RF matrix in this Chinese SLSC illustration. Keep exactly seven rows at z−3Δz,z−2Δz,z−Δz,z,z+Δz,z+2Δz,z+3Δz, exactly six Rx columns, orange center fourth row, all surrounding Chinese labels, fixed-column rule, probe, window span=(K−1)Δz, and K=7 unchanged. Each matrix cell represents ONE REAL RF SAMPLE, so remove every complete oscillatory wave packet drawn within each individual cell. Replace each cell with a single colored square or a single signed scalar value (e.g. +0.4, −0.3), with a coherent oscillatory progression DOWN each column and modest variation between adjacent columns. The fourth row can use an orange background; avoid drawing multiple-waveform content within one sample. Use short schematic signed numbers or blue-white-orange diverging color blocks; numbers are illustrative, not measurements. The matrix and all formulas must remain clear and correctly counted. Do not change any other part of the image.
~~~

### slsc_dynamic_aperture.png

~~~text
Edit this Chinese SLSC dynamic-aperture teaching image with only two corrections. FIRST: replace BOTH occurrences of the ordinary English word ‘ACTIVE’ by the Chinese word ‘有效’, so the lines read ‘接收（Rx）有效孔径的元素数：M = 20’ and ‘接收（Rx）有效孔径的元素数：M = 40’ (avoid duplicated 有效). SECOND: the lower-left little waveform example incorrectly starts with lag=0 while showing correlation 0.8. Change ONLY its three row labels from lag=0,lag=1,lag=2 to lag=1,lag=2,lag=3 respectively; keep correlation 0.8 for all three. Lag zero must not appear anywhere because self-correlation would be one and is excluded from SLSC. Preserve the exact main arithmetic floor(0.15×20)=3, floor(0.15×40)=6, sums 2.4/4.8, averages 0.8/0.8, max lag=12, all Chinese text, colors, alignment and scientific meaning. Do not add English labels or alter formulas.
~~~
