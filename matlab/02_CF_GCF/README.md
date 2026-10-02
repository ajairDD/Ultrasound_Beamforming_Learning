# Chapter 2 MATLAB：CF / GCF

默认真实数据：

~~~text
../../data/L7_FI_TheGB.uff
~~~

本章第一阶段只研究 receive-domain coherence。

## 第一课

~~~matlab
demo_cf_aperture_vectors
~~~

不需要 USTB。

目的不是成像，而是先理解一个 pixel 的 aligned aperture vector：

~~~text
s = [s1, s2, ... , sM]
~~~

为什么：

- 同相时 CF 接近 1；
- phase 越乱 CF 越低；
- CF 与 aperture spatial spectrum 有什么关系。

后续再进入真实 UFF 的 Manual CF / GCF。

---

## 第二课：真实 aligned aperture vector

运行：

~~~matlab
addpath('../01_DAS_Real_UFF');
inspect_real_cf_aperture_vectors
~~~

脚本流程：

~~~text
Chapter-1 conventional FI-DAS
        ↓
在图上点击 3 个 pixel
        ↓
snap 到真实 scanline / z-grid
        ↓
重新计算相同 Tx+Rx delay
        ↓
fractional interpolation
        ↓
active receive aperture
        ↓
真实 aligned complex aperture vector
        ↓
CF / phasor / aperture FFT
~~~

每个点还会验证：

~~~text
sum(aligned active samples)
==
Chapter-1 DAS complex pixel
~~~

默认使用 Rx F# = 1.7。

这一课仍然不做完整 CF 图像；目标是先把真实数据中的 aligned aperture vector 物理含义彻底看清楚。