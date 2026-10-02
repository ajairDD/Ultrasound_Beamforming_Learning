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
