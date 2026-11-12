# 第二轮符号与布线核对

## 第二轮：nsi_null_intuition.png

~~~text
Change ONLY the LOWER-LEFT graph's vertical axis label in this image. It still incorrectly contains |Z(δ)|. Replace the complete vertical text with exactly ‘接收方向图幅值 |Z|’, WITHOUT any argument in parentheses and WITHOUT any δ symbol. Preserve the horizontal label ‘观察方向偏移 θ’. The symbol δ must occur NOWHERE in this figure. Preserve all four-channel phasors, Chinese captions, Z=0 arithmetic, central null and overall layout. This is one small text correction; do not introduce any new labels or diagrams.
~~~

## 第二轮：nsi_tx_order.png

~~~text
Rebuild ONLY the upper colored data-flow diagram to eliminate all incorrect crossing buses. Keep the overall Chinese title, white/blue/teal/purple style, bottom grey counterexample, and footer. The upper diagram MUST have EXACTLY THREE HORIZONTAL ROWS with NO VERTICAL INPUT BUSES and NO CROSSING WIRES. Row 1 blue: label ‘ZM 分支’; inside that row show three small contribution cards ‘Tx 1’, ‘Tx 2’, ‘Tx 3’ with plus signs; then a blue box ‘沿 Tx 相干合成’; then ‘取包络’ and output |Z|. Row 2 green: label ‘DC1 分支’; three separate cards ‘Tx 1’, ‘Tx 2’, ‘Tx 3’; then its OWN green ‘沿 Tx 相干合成’ box; then ‘取包络’ and output |DC1|. Row 3 purple: label ‘DC2 分支’; its OWN three Tx contribution cards; its OWN purple coherent sum; then ‘取包络’ and output |DC2|. Do NOT arrange by Tx event with three branches inside each event; arrange by BRANCH so every wire stays horizontal until AFTER magnitude. Only the three final magnitude outputs meet at one orange box ‘两路 DC 包络平均 − ZM 包络’ then one output ‘非负残差 E’. NO further absolute-value box after this subtraction. The common orange caption must read ‘每一分支先相干合成，之后才取包络’. Avoid mathematical summation formulas if they crowd the drawing. Match colors consistently, never connect purple contributions to a blue sum, never combine different branches before envelope detection. The grey bottom example remains ‘每次 Tx 先取包络再相加，通常不是同一个运算’. No extra steps, unexplained arrows, fake clinical image, or English prose.
~~~
