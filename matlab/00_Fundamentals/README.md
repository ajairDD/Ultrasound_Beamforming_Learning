# MATLAB / 第 0 章：Fundamentals

这些脚本对应：

**[第 0 章：波束合成共同基础](../../chapters/00_Fundamentals/README.md)**

目标是先建立物理和信号直觉，不接触真实 UFF acquisition 的复杂性。

---

## 推荐运行顺序

### 1. <code>demo_synthetic_point_target.m</code>

学习：

~~~text
point target
→ raw channel RF
→ Tx/Rx propagation
→ interpolation
→ DAS
→ lateral response
~~~

重点看：

- channel data shape；
- arrival-time curve；
- candidate focus；
- focused_samples；
- coherent sum。

### 2. <code>demo_delay_alignment.m</code>

学习：

- residual delay；
- channel trajectory “拉直”；
- correct focus vs wrong focus；
- delay error → phase error。

### 3. <code>demo_aperture_psf_apodization.m</code>

学习：

- active aperture；
- F-number；
- lateral PSF；
- -6 dB amplitude width；
- Uniform / Hann / Hamming；
- main-lobe / sidelobe trade-off。

### 4. <code>demo_axial_lateral_2d_psf.m</code>

学习：

- short vs long pulse；
- bandwidth；
- axial PSF；
- lateral PSF；
- 2-D PSF。

### 5. <code>demo_das_failure_modes.m</code>

学习：

- close targets；
- strong / weak targets；
- independent noise；
- sound-speed mismatch；
- phase-aberration-like delay perturbation。

---

## 为什么这些脚本保持自包含

这里没有急着抽出一堆 shared utility。

原因是第 0 章的第一目标是：

> **打开一个脚本，就能顺着数据流把整个实验看明白。**

因此某些 helper 和参数会重复。

等进入真实 DAS baseline 后，再建立真正需要复用的函数。

---

## 运行要求

只需要 MATLAB。

不需要：

- USTB；
- UFF 数据；
- Signal Processing Toolbox。

如果某个 MATLAB 版本对脚本末尾 local function 支持有限，请使用较新的 MATLAB 版本运行。
