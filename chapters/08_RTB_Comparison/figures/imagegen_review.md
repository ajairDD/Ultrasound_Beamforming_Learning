# 文生图科学复核与校正

使用内置 `image_gen` 编辑初稿；最终选图进入本章 `figures/`，独立图片保持 Git 忽略。

## rtb_shared_frontend.png

~~~text
Correct the scientific signal-flow diagram. Preserve overall wide style, title and four horizontal rail layout, but rebuild connectors and simplify lower mini-icons. The shared source MUST go first to RTB 延时、插值与有效孔径, then from the OUTPUT RIGHT EDGE of that RTB box descend a shared vertical bus which feeds all FOUR rails. No rail branches from the raw source before RTB. Rail1 keep 复数通道 → DAS / CF / GCF / MVDR → Tx 相干合成 → 包络. Rail2 change D、Z 两个分支 box to a plain text box D、Z 两个分支 with NO arrow between D and Z; final NSI 包络组合 box MUST have NO waveform plus sign, no invented equation, only three small boxes |DC1| |DC2| |ZM| and subtitle 分别取包络，再相减. Rail3 preserve 实 RF 通道 → fDMAS 通道配对 → Tx 加权合并 → 2f₀ 带通与包络, replace multiplication mini-icon by plain subtitle 带符号开方后配对. Rail4 preserve 实 RF 轴向窗 → SLSC 短 lag 相关 → Tx 统计平均 → 线性相干性, REMOVE all formulas x(z+l), 1/K and rho sums. Instead use plain subtitles 相邻接收通道对 under SLSC and 按有效 Tx 权重平均 under Tx 统计平均. No unrequested formulas or scientific icons. Keep exact footer about RTB extension verification.
~~~

## rtb_seven_mechanisms.png

~~~text
Correct ONLY the fDMAS, NSI, and GCF cards' mechanism details; preserve all seven cards and titles, other cards and overall visual layout. GCF card caption must state 接收孔径 FFT 的低频能量占比，作为该 Tx 的 DAS 标量权重. Do not imply that the spectrum is directly filtered to reconstruct. fDMAS card must say 实 RF 先带符号开方，再配对求和，最后选取约二倍频带; remove the incorrect explicit si(t)·sj(t) formula and replace it with two text pills 带符号开方 → 通道配对. NSI card: REMOVE its existing half-aperture-magnitude subtraction flow |y+|-|y-|, remove the claim 增强周围结构. Replace with clear three-output symbolic mechanism: three parallel labels ZM / DC1 / DC2 → three magnitudes |ZM| / |DC1| / |DC2| → final text 两路 DC 包络平均，减去 ZM 包络. You may keep the generic center-null plot labelled 方向图示意, but no invented gain claims. Caption 三路分别取包络后组合，留下中心附近的窄残差. These precise changes are essential.
~~~

## rtb_output_types.png

~~~text
Simplify mechanism details to avoid implying NSI is one complex beam magnitude or fDMAS is just raw multiplication. Keep the three shelves, headings, method badges, separate colorbars and footer. In first shelf REPLACE the complete miniature processing chain (complex beam/I+jQ/absolute/log) by two large text cards 按各方法规则处理 → 包络或包络组合. This includes NSI correctly. In fDMAS shelf REPLACE the pair multiplication and frequency-flow miniatures by two large text cards 带符号开方后配对 → 二倍频带通后取包络. Keep SLSC correlation/linear display shelf. Change amplitude colorbar heading to dB 显示：参考需分别注明. Label any ultrasound thumbnails as 结果示意, not measurements. Do not invent new equations, do not share a physical amplitude calibration across shelves.
~~~

## rtb_display_reference.png

~~~text
Keep the own/common reference comparison and bottom exception cards but correct what is being compared: two METHODS on the SAME target, not two different physical scatterers. Remove the left two-scatterer illustration and its A/B labels. Replace with one small target beneath a probe, caption 同一目标，两种处理. Change RF 数据（未归一化） box heading to 两种处理的输出 and its waveform labels to DAS and 另一方法. In ALL three curve legends replace 散射体 A by DAS 输出 and 散射体 B by 另一方法输出. Original peaks 1 and 0.5 are illustrative output scales; common-reference orange peak must be exactly half teal peak, own-reference both peaks exactly equal. Keep same curve widths and same x peak positions. Remove implication that normalization changes original RF. Preserve the footer and the fDMAS/SLSC exception cards.
~~~

## rtb_metadata_bridge.png

~~~text
Edit ONLY the RF/IQ phase convention checkpoint. Remove the vague assertion 相位约定：以 I 轴为相位零点 and any drawn assumption that IQ is automatically in phase with RF. Keep the complex I/Q icon, but below it use two explicit text chips 解调频率 f_demod and 相位参考时刻 t_ref. Add short caption 明确正负号与参考时刻. Do not add a carrier recovery formula. Preserve all other checkpoints, array axes, physical-channel mapping, standard input, independent complex DAS gate and the scope limitation footer.
~~~
