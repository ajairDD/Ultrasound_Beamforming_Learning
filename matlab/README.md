# MATLAB 实践代码

本项目所有算法实践统一使用 MATLAB。

## 设计原则

1. **理论学习不绑定第三方 toolbox。**
2. 每个核心算法尽量先提供一个自包含的 synthetic demo。
3. USTB 用于读取公开 UFF channel data 和复现实验，不作为理解算法的前置条件。
4. 所有真实数据代码在运行前先检查 shape、axis、dtype、单位和采集方式。
5. 比较不同 beamformer 时尽量复用同一套输入数据、成像网格、动态范围与评价指标。

## 目录

- [01_DAS](./01_DAS/)：DAS 基础、原始通道数据、时延和后续 PSF 实验。

后续随着课程推进，会增加：

```text
02_CF/
03_MV_MVDR/
04_DMAS/
05_SLSC/
06_NSI/
shared/
```

不会为了“目录完整”提前放置大量空文件夹。
