# Universal RTB：跨设备原始数据标准接口

**状态：合成数据标准接口测试、TheGB UFF 的独立复数 DAS 回归（6.533229×10⁻¹⁶），以及 TheGB 的七算法真实 RF 一键重建集成测试均已通过。跨厂商真实采集数据和 fDMAS/SLSC 新 RTB 定义的独立数值验证尚未完成。**

**阅读对比结果请转到 [第 8 章：同一 RTB 几何下的七方法对比](../../chapters/08_RTB_Comparison/README.md)**。本文件重点保留跨设备标准数据接口定义、代码行为与原始验收记录，第 8 章集中整理图像比较和结果解释。

## 1. 目标与适用范围

统一入口：

~~~matlab
out=rtb_reconstruct_all(source,cfg);
rtb_show_methods(out,'own');      % own-peak dB；SLSC 线性
rtb_show_methods(out,'common');   % common DAS dB；SLSC 线性
~~~

source 支持：
- UFF 文件：使用 USTB 只读取 focused FI RF channel data；
- MAT 文件：必须含 canonical struct 变量 acq；
- canonical MATLAB struct：将不同机器的原始数据、坐标、时间定义映射到统一 SI 格式。

**兼容不同机器不等于能自动解码未知私有文件。** 厂商的 bin/HDF5/自有 MAT 应先用其 SDK/导出脚本获取 numeric channel tensor，再经 rtb_from_vendor_array(raw,meta) 明确映射。没有实际厂商协议或发射时序资料，不猜测硬件和 IQ 相位。

**当前只支持**二维 x-z、z=0 的均匀 1D 线性阵列、positive-z focused spherical Tx（RTB）、未 beamformed 的真实 RF 或复数 baseband IQ。当前不支持 CPWC、plane/diverging/STA、convex、二维矩阵阵列、任意 Tx 编码、已经 envelope/log 的数据。兼容的主要是**数据排列和元数据规范**，不是自动支持所有物理发射序列。

## 2. 一键运行现有 TheGB UFF

~~~matlab
addpath(genpath('D:/你的USTB路径'));
cd matlab/RTB_Universal
out=demo_rtb_universal;
~~~

默认 TheGB 测试 ROI：x=-4..3mm，z=18..22.5mm，64 个横向像素、每 4 次 Tx 取一次、全七种方法。z 的采样数自动按波长约 lambda/16 设定以满足 fDMAS 二倍频带通。

也可以自行提供所有重建参数：

~~~matlab
cfg=struct();
cfg.methods={'DAS','CF','GCF','MVDR','FDMAS','SLSC','NSI'};
cfg.x_range_m=[-4,3]*1e-3;
cfg.z_range_m=[18,22.5]*1e-3;
cfg.n_x=64;
cfg.n_z=[];                    % 根据 lambda/16 自动确定
cfg.wave_stride=4;             % 1=全部 Tx
cfg.frame_index=1;

cfg.tx_delay_model='blended';
cfg.tx_f_number=2;
cfg.tx_min_aperture_m=3e-3;
cfg.tx_window='tukey25';
cfg.rx_f_number=1.7;

cfg.gcf_M0=1;
cfg.mvdr_fraction=0.5;
cfg.mvdr_loading=0.01;
cfg.mvdr_axial_lambda=1.5;
cfg.slsc_lag_fraction=0.15;
cfg.slsc_max_lag=12;
cfg.slsc_axial_lambda=1.0;
cfg.nsi_dc=0.8;

out=rtb_reconstruct_all('../../data/L7_FI_TheGB.uff',cfg);
rtb_show_methods(out,'own');
rtb_show_methods(out,'common');
~~~

注意：默认是**快速预览**，不是整张临床全视野。如果将 Tx×pixel 提高太多，程序默认拒绝超大规模 MVDR/SLSC，用户评估资源后才设置 cfg.allow_large=true。另一个设备如 Alpinion、Verasonics focused FI，可改 UFF 路径，并根据该机器真实的有效焦深/视野修改参数。

## 3. 核心标准数据格式（SI 单位）

Canonical acq 的必须字段：

| 字段 | 说明 |
|---|---|
| data | 数值数组 [sample,channel,Tx,frame]；禁止预先 beamform/envelope/log |
| signal_type | RF（实数）或 IQ（复数） |
| tx_wavefront | 必须为 focused_spherical；未知波型或 plane/CPWC 不可以套此模型 |
| data_stage | 必须为 pre_beamform_channel；拒绝已 beamformed/envelope/log 的数据 |
| fs_hz | 采样率 Hz |
| t0_s | ADC/IQ 第一个样点时间，标量或每 Tx 一个值，秒 |
| c_m_s | 重建声速 m/s |
| tx_sound_speed_m_s | 可选，按 Tx 提供虚源模型声速（m/s）；默认使用 c_m_s；UFF 自动读取 wave.sound_speed |
| f0_hz | 标称中心频率 Hz |
| element_xyz_m | [Nelem,3] 物理阵元 xyz，米 |
| channel_to_element | [Nchannel,1] 物理阵元 1-based 编号 |
| focus_xyz_m | [Ntx,3] 聚焦发射源焦点坐标，米 |
| origin_xyz_m | [Ntx,3] 发射波轴的 origin，米 |
| tx_reference_distance_m | [Ntx,1] 虚源 Tx 路径参考距离，米 |
| tx_delay_s | [Ntx,1] Tx 时间偏移，秒 |
| tx_phase_correction_rad | [Ntx,1] Tx analytic 相位补偿，单位 rad；确认相干才填 0 |
| tx_delay_convention | 必须为 subtract，表示 tau_tx=path/c-tx_delay |
| time_reference | 必须为 two_way，样点时间相对 Tx+Rx 全程 |
| IQ 附加 | demod_hz、iq_reference_time_s、iq_phase_convention |

对需要重新排列数组/转单位的非 UFF 数据，使用显式 adapter：

~~~matlab
% raw_vendor 已由机器 SDK 解码成 numeric channel data
% machine.* 是需要你根据该机器实际 SDK/发射配置取得的字段：
meta=struct();
meta.data_order='channel,sample,tx'; % 需核对，不能猜
meta.units=struct('length','mm','time','us','frequency','MHz');
meta.signal_type='RF';
meta.tx_wavefront='focused_spherical';
meta.data_stage='pre_beamform_channel';

meta.sampling_frequency=machine.fs_MHz;
meta.initial_time=machine.initial_time_us;  % scalar 或每 Tx
meta.sound_speed_m_s=machine.c_m_s;
meta.nominal_frequency=machine.f0_MHz;

meta.element_xyz=machine.element_xyz_mm;
meta.channel_to_element=machine.rx_to_element; % 1-based
meta.focus_xyz=machine.focus_xyz_mm;
meta.origin_xyz=machine.origin_xyz_mm;
meta.tx_reference_distance=machine.tx_reference_distance_mm;
meta.tx_delay=machine.tx_delay_us;
meta.tx_phase_correction_rad=machine.tx_phase_correction_rad;
meta.tx_delay_convention='subtract';
meta.time_reference='two_way';

acq=rtb_from_vendor_array(raw_vendor,meta);
out=rtb_reconstruct_all(acq,cfg);
rtb_show_methods(out);
~~~

所有 machine.* 只是**占位字段名**，不是任何厂家都提供的具体 API。转换器会处理 mm/us/MHz→m/s/Hz、任意已明确的数据 axis 顺序、物理 Rx 接线反向和 Tx 独立 t0。关键元数据不全则报错。

若是 IQ，必须明确给出：

~~~matlab
meta.signal_type='IQ';
meta.iq_demodulation_frequency=machine.demod_frequency_MHz;
meta.iq_reference_time=machine.demod_tref_us;
meta.iq_phase_convention= ...
    'iq_equals_analytic_times_exp_minus_j2pift';
~~~

这里定义 IQ(t)=analytic_RF(t)×exp(-j2πf_demod(t-t_ref))，内核在 delay interpolation 后恢复 analytic carrier 相位。其它 IQ 约定必须先做正确的适配；不能仅凭复数 dtype 猜测。IQ 只支持 DAS/CF/GCF/MVDR/NSI；fDMAS/SLSC 必须要真实 RF。默认遇到 IQ+这两方法会**报错**；可明确设置 cfg.unsupported_policy='skip' 并查看 out.skipped。

## 4. 核心算法链与科学边界

~~~text
UFF / vendor tensor / canonical MAT
                |
      validate axes / units
      channel->physical element mapping
      t0 / Tx focus / delay / phase
                |
        shared Tx/Rx RTB delays
        shared Rx F# / Tx weights
        shared fractional interpolation
                |
      aligned receive aperture vector
                |
    DAS: complex receive sum
     CF: per-Tx receive CF × DAS
    GCF: per-Tx Rx-aperture FFT low-bin energy × DAS
   MVDR: receive covariance + spatial/axial smoothing
  fDMAS: real RF sign-sqrt pairs + image-depth 2f0 filter
   SLSC: short-lag axial RF correlation
    NSI: zero-mean Rx + two DC-offset envelopes
                |
      cross-Tx compounding
      B-mode / linear coherence display
~~~

- CF/GCF/MVDR/NSI 都先执行**每 Tx 的 receive 运算**，然后通过相同 Tx apodization 做相干复合。
- **跨机器 GCF 注意事项**：这里的 GCF M0 是 FFT 的固定整数 bin 数，实际对应的归一化 spatial-frequency 截止随有效 Rx 孔径 M 变化；不同阵元数或 F# 的机器不能仅以相同 M0 就认为严格同等滤波条件。
- 各 Tx 在本版本采用同一个采样率 fs；如果机器不同 Tx 使用不等采样率/时间基准，需先正确重采样并更新 t0，不能随意拼接成标准 4D tensor。
- SLSC 的相关性是实数统计量，按 Tx 权重做**非相干平均**。这是新的 RTB 教学扩展，不能冒充论文中已验证的统一 RTB-SLSC。
- fDMAS 对 real RF pair products 先按 RTB 的 Tx 权重求和，再沿轴向图像时间轴滤波二倍频。这是显式规定的 RTB 教学扩展，**不等同于在每次 Tx 内先滤波再复合的所有可能定义**；输出幅度不能当作 DAS 的同一物理校准幅度。
- NSI 默认 c=0.8 是根据本项目此前 c=0.2 的 in-vivo 强抑制结果选择的保守教学值，**不是各类设备最优值**。
- RTB Tx blended model 复用了第 1 章所用的虚源/近焦区混合模型，但不是声场完整正演；其它设备必须先验证 timing/phase，不得仅因图像看起来合理就认定正确。

图像输出：

~~~matlab
out.images.DAS
out.images.CF
out.images.GCF
out.images.MVDR
out.images.FDMAS
out.images.SLSC  % signed coherence, dimensionless
out.images.NSI

out.x_axis_m
out.z_axis_m
out.display                   % 自峰值归一化 dB；SLSC 线性
out.display_common_db         % 与 DAS 共用参考 dB；无 SLSC / fDMAS
out.input_audit
out.diagnostics
out.tx_weight_sum
out.active_tx_count
~~~

## 5. 跨机器最易出错的地方

1. **array shape**：sample/channel/Tx/frame 的顺序，是否混入 ensemble/角度维。
2. **物理通道映射**：ADC channel 到 probe element 的 1-based 映射，是否反向、跳过阵元或者插入虚通道。GCF/SLSC 对物理 lag 特别敏感。
3. **样点时间轴**：time0/pre-trigger、Tx firing offset、pulse-center delay、解调/抽取滤波群延时；t0 错了，即使图像有结构也可能焦点错误。
4. **Tx 参数**：focus 位置、origin、reference distance、Tx delay 的**符号**及不同 Tx 间 coherent phase。
5. **RF/IQ 阶段**：正负载频、IQ 相位原点、decimation、carrier 的时间相位恢复；RF-only 算法不能自动从 IQ 还原真实 RF。
6. **设备前处理**：bandpass、TGC、各通道增益、动态孔径、相关序列的解码/配准等会影响跨机对比；不能默认原始数据已完全等价。
7. **模型适配**：2D linear focused 是当前边界；其他探头/发射序列必须另建物理模型，不是更换元数据字段就能支持。

## 6. 输入预检与两类验证

**先做跨设备输入预检（不是成像验证）：**

~~~matlab
% source 可以是 UFF 文件或 canonical acq
audit=rtb_audit_source(source);
~~~

除了元数据/通道重排校验，预检还会检查各个 Tx 的焦点预测回波时刻是否落在原始采样时间范围内。覆盖比例很低时，优先核对 t0、Tx 参考距离、Tx delay 和采样率；**焦点不在当前采样范围有时是采集设置所致，不一定是错误，因此这里只报警不自动改时序**。

**A. 不依赖 UFF 的合成数据：**

~~~matlab
cd matlab/RTB_Universal
test_rtb_standard_interface
~~~

生成点目标，验证多种数据轴顺序、反向通道、单位换算、RF/IQ、所有七种输出、CF=GCF(M0=0)、NSI 的理论上下界、错误元数据拒绝机制。

**B. 和项目已验证第 1 章 RTB-DAS 独立复数数据对比：**

~~~matlab
addpath('../01_DAS_Real_UFF');
test_rtb_universal_vs_chapter1

% 可额外换不同机器的 focused FI UFF
test_rtb_universal_vs_chapter1('../../data/L7_FI_carotid_cross_1.uff')
test_rtb_universal_vs_chapter1('../../data/Alpinion_L3-8_FI_hypoechoic.uff')
~~~

要求在相同网格和 Tx/Rx 条件下，complex DAS 的 max-peak scaled error 小于 1e-10。若失败，**先核查设备时序和几何，不能进入各方法优劣比较**。成功后也只能证明共同 DAS 基线一致，不自动证明新的 fDMAS/SLSC 扩展完全符合论文定义。

### 2026-11-13：首次真实 UFF 回归发现的归一化差异

用户首次运行：合成输入适配/7 算法检查全部 PASS，但真实 TheGB 的独立 RTB-DAS 复数 regression 出现 **6.848491e-05**，因此**尚未通过 1e-10 验收**。

代码审查发现一处确定的实现不一致：
- Chapter 1：`tx_weight_sum` 对所有 Tx 孔径支持的像素累计 Tx apodization，即使该位置没有有效的 Rx 样点，接收值也按 0 贡献；
- 初版 RTB_Universal：只有至少一个 Rx 通道样点有效的 Tx 才计入分母，导致数据窗边界的零贡献被重新放大。

已修正 RTB_Universal，使分母和 Chapter 1 一致，同时另外输出 `out.valid_rx_tx_weight_sum`、`out.valid_rx_tx_fraction` 和 `out.diagnostics.missing_rx_tx_weight_fraction`，在存在 Rx 数据缺失时给出警告。

**另外发现第二个真实的实现差异**：第 1 章用 `wave.sound_speed` 计算每次发射的 Tx virtual-source delay、用 `channel_data.sound_speed` 计算 Rx delay；统一接口原先将后者同时用于 Tx/Rx。现在 UFF loader 精确保留每个 Tx 的 `tx_sound_speed_m_s`，核心也对应使用。对于厂商标准数组，此字段可以省略，默认等于 `c_m_s`；如果确实有独立 Tx 声速应显式提供。

上述两处差异已在静态代码审查中确认，但**是否足以解释实测 6.848491e-05，需要本地 MATLAB 重跑才能确认**。回归测试输出 Tx 权重最大差异、Tx/Rx 声速元数据差异及复数误差最大位置，不允许仅放宽容差通过。

**复测更新（用户日志）**：误差仍为 **6.848491e-05**，Tx 权重最大绝对差 **2.483118e-07**，Tx/Rx 声速差 **0**，最大复数误差发生在 **x=2.0000 mm、z=30.5225 mm**，该处有效 Rx 覆盖率 **1.0**，全局缺失 Rx 权重比例为 **0**。这排除了前两处差异作为当前主要误差的解释。

最新针对性修复：将通用 RTB 的 Tx Tukey25 窗口计算表达式及 Rx F-number 半孔径边界计算顺序，严格调整为第 1 章的原始 MATLAB 运算顺序；消除在接近孔径阈值时由不同浮点运算顺序可能引入的差异。**此修复尚未得到真实 UFF 复测确认。** 对比测试额外打印 Tx 权重差异的 x/z 坐标，以及最大复数误差位置上的两套 Tx 权重，方便区分“孔径边界差异”与“延时/采样差异”。

**追加的数值精度核对（待 MATLAB 验证）：** MathWorks 文档指出 MATLAB 的 `single` 与 `double` 混合运算可能给出 `single` 结果。第 1 章最初直接读取 UFF geometry 属性，新接口则明确转换为 `double`；如果该 UFF 的 `probe.x`、`wave.source.x` 等是 `single`，之前的双精度 `1e-10` 回归阈值就存在不一致精度的比较问题。

为保证科学一致性，**第 1 章默认行为完全不变**；只为回归测试增加可选 `options.force_double_geometry=true`，将 UFF wave/probe geometry、采样时间和 Tx/Rx 声速在进入同一 RTB 方程之前转成 double。最新独立测试自动开启此选项；新的统一引擎同步保留真实阵元 y/z 几何（而非只用 x），仍要求 complex-DAS relative error `<1e-10`。测试会打印 UFF 原始字段的 `class()`，确认该解释是否适用。

**最终复测（2026-11-14，用户 MATLAB 日志）已通过：**

~~~text
UNIVERSAL RTB vs CHAPTER-1 DAS: 6.533229e-16
Tx normalization weight max abs difference: 0.000000e+00
Max per-Tx vs channel Rx sound-speed diff: 0 m/s
Maximum complex residual: 6.821210e-13
Worst residual at x=-0.1000 mm, z=28.9316 mm
Data-supported Tx-weight fraction: 1.000000
Global missing-Rx Tx-weight fraction: 0
PASS: complex RTB DAS baseline is consistent with Chapter 1.
~~~

说明在 **同一 TheGB 原始 RF、相同 Tx/Rx 几何、网格、参数及当前双精度对照条件**下，统一 RTB-DAS 与独立第 1 章实现达到了约双精度舍入误差量级的一致性。Tx 权重差异为零，且不存在记录样点缺失。结合此前通过的合成数组、通道重排、单位、RF/IQ、异常元数据和 GCF(M0=0)=CF 检查，可将**数据输入适配的合成验证 + TheGB UFF DAS 基线验证**标记为通过。

**归因边界**：这次通过之前同时修正了 Tx/Rx 归一化、运算顺序、几何精度与坐标处理；没有逐一隔离变量的消融实验，因此不能仅凭最终 PASS 断言以前的差异全部由 single/double 引起。第 1 章的 `force_double_geometry` 仍为回归测试专用选项，默认重建行为不变。

**尚未验收**：其它机器的真实 UFF/canonical 数据及 IQ 物理一致性；fDMAS/SLSC 新 RTB 扩展的独立算法数值真值；七算法结果的同物理条件定量 benchmark。TheGB 七算法已经集成运行，但这不意味着每种算法已通过独立科学正确性验证。

### 2026-11-14：TheGB 真实 RF 七算法一键重建

用户运行 `out=demo_rtb_universal;` 并提供 Figure 1（own-peak）、Figure 2（common DAS reference）及控制台日志。**这是端到端集成测试通过，而不是每个算法获得了独立的科学验证。**

~~~text
Finished universal RTB in 41.37 s
MVDR fallback 0/61289, SLSC unavailable pixel-Tx 0
shape_sample_rx_tx_frame: [1920 128 128 1]
element_pitch_m: 2.9800e-04
channel_reorder_changed: 0
t0_range_s: [0 0]
focus_depth_range_m: [0.0296 0.0296]
max_tx_rx_sound_speed_diff_m_s: 0
is_RF: 1
Methods completed: DAS, CF, GCF, MVDR, FDMAS, SLSC, NSI
Total full-pipeline runtime: 41.37 s
~~~

`demo_rtb_universal` 默认从 128 个 Tx 中按 `wave_stride=4` 取子集（32 Tx），视野 x=-4..3 mm，z=18..22.5 mm，`n_x=64`；**不是全部 128 Tx 的全视野性能测试**。41.37 秒是七算法共同处理的一次总时间，不能分配为任何单独方法的耗时。

**截图观察（定性，不是独立 ground truth）：**

- DAS：点目标和背景散斑呈预期 RTB 形态；作为共同空间几何基线。
- CF：更强的背景压低；GCF(M0=1) 相比 CF 恢复部分散斑。
- MVDR：点目标横向响应紧凑；较粗的默认 x 网格不能替代密集 PSF 数值测量。
- fDMAS：点目标附近出现更明显的轴向细长结构；需要在固定几何下进一步核查二倍频 bandpass 和轴向 profile。不能仅因图像可显示就认定新的 RTB-fDMAS 定义已与原方法一致。
- SLSC：宽而平滑的亮区，这是 `short-lag coherence` 的线性图，而非声压幅度图。还需独立验证新的跨 Tx 非相干平均约定。
- NSI：出现明显零点与背景明暗起伏，符合之前 c 相关实验的外观趋势；不能据此认定组织保真性好。

**验收分层：**

1. 解析/物理适配的合成测试：PASS。
2. TheGB 复数 RTB-DAS vs 第 1 章的数值回归：PASS（6.533229×10⁻¹⁶）。
3. TheGB 七算法真实 UFF 端到端运行/展示：PASS（本次日志）。
4. 其它设备原始数据/元数据的真实互操作性：**待验收**。
5. fDMAS、SLSC 的 RTB 扩展与独立算法基准的数值一致性：**待验收**。

**下一项最直接的跨机器检查**：优先拿已有 `Alpinion_L3-8_FI_hypoechoic.uff` 做 `rtb_audit_source`，再运行 `test_rtb_universal_vs_chapter1`。若波型、阵列及时间元数据符合本接口，且复杂 DAS 回归达到 `<1e-10`，再对该数据开启七算法成像。不要把波型/阵元排列不同的文件自动视为兼容。

---

## 7. 文件与依赖

~~~text
matlab/RTB_Universal/
  rtb_from_vendor_array.m
  rtb_load_acquisition.m
  rtb_audit_source.m
  rtb_reconstruct_all.m
  rtb_show_methods.m
  demo_rtb_universal.m
  test_rtb_standard_interface.m
  test_rtb_universal_vs_chapter1.m
  README.md
~~~

MATLAB 基础 FFT/线性代数/绘图，不需额外工具箱。**只读 UFF 时需要 USTB**；canonical struct/MAT 不需要 USTB。原始 UFF 和私有采集数据不提交 GitHub。
