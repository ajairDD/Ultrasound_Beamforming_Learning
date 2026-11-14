# 共享前端连线的第二轮校正

初稿及第一轮编辑仍把公共总线连到 RTB 前端的输入。第二轮要求反转这根箭头，表示 RTB 输出进入左侧总线，再分配到四条方法路径；同时补齐三路包络符号和 SLSC 的有效 Tx 权重说明。

~~~text
Change only THREE details in this image; preserve all other boxes, text and layout. (1) The top teal elbow connector currently points RIGHT into the RTB box, causing branches to bypass the shared frontend. REVERSE that arrow: its arrowhead must point LEFT from the RTB box toward the left vertical bus. Explicit direction is RTB box OUTPUT -> left bus -> down -> four rows. The RTB box is the starting stage of this diagram; it must feed the bus, not receive data from it. There must be NO right-pointing arrow on that top horizontal elbow. (2) In the NSI final box, ensure the three labels are exactly |DC1|, |DC2|, |ZM|, with absolute-value bars around ALL THREE. (3) Change the SLSC Tx averaging subtitle from 按有效 Tx 平均 to 按有效 Tx 权重平均. Do not introduce new scientific icons or formulas.
~~~
