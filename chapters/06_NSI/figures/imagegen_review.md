# 第 6 章概念图核对与校正

逐图检查中文文字、正负权重、分支次序、符号含义和数据来源。以下是首轮校正；最终图以本地 PNG 为准，概念曲线不作定量证据。

## nsi_pipeline_concept.png

~~~text
Precisely correct this Chinese receive-NSI pipeline illustration. Keep the correct shared RF -> Tx/Rx delay/interpolation -> active Rx aperture -> THREE parallel weighting/Rx-sum/Tx-coherent-sum/magnitude paths -> envelope subtraction -> E/delta display layout and the exact E formula. REMOVE every miniature plotted curve from the three WEIGHT cards: the Gaussian shown in the ZM weighting card is wrong. Replace those three mini-plots by simple mathematical vector symbols w_ZM, w_DC1, w_DC2, clearly representing weights, not beam envelopes. Also REMOVE the three miniature hump curves from the envelope cards; show ONLY |Z|, |DC1|, |DC2|, respectively. Replace the two-humped output E icon with an abstract numeric pixel tile, not a beam plot. Replace the final sector-shaped display thumbnail by a generic small rectangular pixel matrix (this course uses a linear array); no fake measured image. Do not add any extra processing operations or new flow arrows. All ordinary labels stay Chinese. ZM weighting must never be depicted as an everywhere-positive window.
~~~

## nsi_three_apodizations.png

~~~text
Correct only the upper-right decorative processing sketch in this eight-element NSI illustration. The lower numeric table is CORRECT and MUST remain EXACTLY unchanged: ZM +1,+1,+1,+1,-1,-1,-1,-1; DC1 1.2 four times then -0.8 four times; DC2 -0.8 four times then 1.2 four times. Preserve element count eight and all Chinese labels. In the upper-right sketch REMOVE ALL THREE lobe/beam drawings: the ZM beam is incorrectly drawn with a central positive peak. Replace each lobe graphic with a simple rectangular output card labeled, respectively, ‘复数输出 Z’, ‘复数输出 DC1’, ‘复数输出 DC2’. Replace each of the three small ‘DAS’ processing boxes by ‘加权求和’. Keep the branch labels ZM, DC1=ZM+δ, DC2=−ZM+δ and all links to the same RF data. Do not introduce any plotted beam pattern, extra receiver or invented processing chain.
~~~

## nsi_null_intuition.png

~~~text
Make two precise text corrections in this four-channel ZM cancellation illustration, preserving all correct phasor arrows, signs, equal lengths, counts and Z=0 formula. The symbol δ is reserved in this course for DC offset, so replace the LOWER graph horizontal label ‘角度偏移 δ’ by ‘观察方向偏移 θ’, and change its vertical expression |Z(δ)| to |Z(θ)|. Do NOT use δ anywhere in this null-direction graph. In the conditions panel replace ‘需要同相、等幅；幅度或相位失配会留下残差’ with ‘此例假设同相、等幅；幅度或相位失配可能留下残差’. Keep Chinese typography sharp. Do not change the arithmetic or add curves.
~~~

## nsi_tx_order.png

~~~text
Correct the upper RTB processing diagram while preserving its three colored branches and Chinese visual style. FIRST remove the extra orange |·| box AFTER ‘NSI 相减’: there is NO further absolute-value operation on the final NSI residual. Connect ‘NSI 相减’ directly to an output tile labeled ‘非负残差 E’. SECOND replace the ambiguous orange divider caption with ‘每路先沿 Tx 相干合成，完成后才取包络’; its leaders should point to the three ‘沿 Tx 相干合成’ boxes immediately BEFORE magnitude detection. THIRD make the input wiring unambiguous: exactly three separate vertical buses (blue for ZM, green for DC1, purple for DC2), with matching color contributions from Tx1,Tx2,Tx3 joining only their same-color bus. No junction dots where different colored buses cross, and no mixing between ZM/DC1/DC2 before their individual coherent sums. Keep the correct bottom muted alternative ‘先取包络再相加，通常不是同一个运算’ and the same-Tx-weight footer. No new diagrams, invented operations, dB subtraction or RF multiplication.
~~~

## nsi_offset_tradeoff.png

~~~text
Scientifically simplify this NSI delta-tradeoff illustration. REMOVE the entire invented processing chain at the top (the row Tx/Rx -> RF -> DC1/DC2 -> ZM -> NSI -> RTB -> DC -> DAS is incorrect). Leave only the main title above the two comparison cards. In BOTH comparison cards REMOVE the left ‘桥接（频域示意）’ plot and all frequency axes: these falsely suggest the ZM pattern changes with delta. Replace each removed plot with a clean two-line mathematical card ‘w_DC1 = w_ZM + δ’ and ‘w_DC2 = −w_ZM + δ’, plus a short label ‘ZM 权重保持不变’. Keep the LEFT delta=0.2 and RIGHT delta=0.8 headings, their qualitative residual icons (explicitly add ‘理想示意’), their Chinese interpretation notes and the three common checks. Retain the footer that D,Z and display reference are the same. No new processing flow, RF DC voltage, time-delay parameter or spatial-frequency claim. All ordinary labels Chinese, no numerical beamwidth claims.
~~~

## nsi_sampling_and_task.png

~~~text
Remove the ENTIRE unnecessary processing-chain row across the BOTTOM of this otherwise good three-card NSI teaching illustration. It incorrectly labels delay as δ and invents a DC processing sequence. Do not replace that row by any new pipeline; use white space and keep only the existing short footer ‘示意图，不用于测量分辨率或判断临床优劣’. Preserve the three upper cards about response width, grid sampling and wall/speckle continuity. In the two small sampling plot legends replace ‘真实响应’ by ‘连续响应（示意）’ to avoid claiming the drawn curves are measured data. Keep sparse/dense sample markers and their captions. Do not change any scientific formula or introduce δ as an angle or time delay.
~~~
