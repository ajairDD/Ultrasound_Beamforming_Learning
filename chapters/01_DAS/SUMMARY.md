# 第一讲速查：Delay-and-Sum (DAS)

> 用于学完第一讲后的复习。完整讲解见 [README.md](./README.md)。

## 一句话

$$
\boxed{
\text{DAS = 用传播模型对齐通道，再做加权相干求和}
}
$$

## 核心链路

```text
target
→ channel RF/IQ
→ Tx + Rx delay
→ interpolation
→ focused aperture vector
→ aperture/apodization
→ coherent sum
→ PSF / image
```

## 六个必须记住的关系

$$
\tau_m
=
\tau_{\mathrm{TX}}
+
\tau_{\mathrm{RX},m}
$$

$$
s_m(\mathbf r)
=
x_m(\tau_m)
$$

$$
y_{\mathrm{DAS}}
=
\sum_m w_ms_m
$$

$$
\Delta\phi_m
=
2\pi f_c\epsilon_m
$$

$$
\Delta x
\sim
\lambda F\#
$$

$$
\Delta z_{\mathrm{axial}}
\sim
\frac{\mathrm{SPL}}{2}
$$

## 横向 vs 轴向

| 方向 | 主要控制因素 |
|---|---|
| Lateral | aperture、F-number、focusing、wavelength、apodization |
| Axial | pulse duration、bandwidth、spatial pulse length |

## DAS 的主要边界

- finite lateral PSF；
- mainlobe-sidelobe trade-off；
- 强目标可掩盖弱目标；
- sound-speed mismatch；
- phase aberration；
- fixed weights 无法利用当前数据统计结构。

## 但不要误解

DAS 对独立随机噪声有 coherent gain：

$$
G_{\mathrm{SNR}}
\approx
10\log_{10}M.
$$

对于 64 个独立噪声通道，理想增益约为 18.1 dB。

## 后续路线

```text
DAS
├── CF / GCF
├── MV / MVDR / Capon
├── DMAS / fDMAS
├── SLSC
└── NSI
```

每一种方法都继续问：

> 它到底改变了 delay、channel weighting、pixel weighting、inter-channel interaction，还是成像量本身？
