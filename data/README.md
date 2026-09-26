# Ultrasound Beamforming Datasets

> 用途：用于 MATLAB 中经典超声波束合成方法的复现、验证与横向比较，包括 DAS、CF/GCF、MV/MVDR、SLSC、DMAS/fDMAS 等。  
> 数据整理日期：2026-09-26。  
> 当前清单对应本项目已下载的 12 个 UFF 数据文件。

## 1. 使用原则

本目录只维护数据说明、来源、下载地址和使用建议。原始 `.uff` 数据体积较大，不直接提交到 GitHub；建议下载后放在本目录或其子目录中，`data/.gitignore` 会忽略这些大文件。

这些数据均为 **channel-level data**，适合从延时、孔径、加权、通道组合等步骤重新实现 beamforming，而不是只能使用已经形成的 B-mode 图像。

USTB 的 UFF 是基于 HDF5 的超声数据格式，可直接在 MATLAB/USTB 中读取。官方数据目录说明每个 UFF 文件内部还保存了对应的数据引用信息；正式发表结果前应读取并核对原始 citation。

> **重要：不要仅根据文件名假设数据一定是 RF、IQ、基波或谐波。**  
> USTB 数据目录对这些文件统一确认的是“channel data”。后续算法实现时应实际检查 UFF 内部的 sampling frequency、modulation/demodulation frequency、initial time、probe geometry、sequence、sound speed 等字段。对于未被原始资料明确标记为 THI/PIHI 的数据，本清单统一记为“谐波模式未明确”。

---

## 2. 当前数据总览

| 文件 | 数据对象 | 发射方式 | 主要来源 | 官方大小 | 适合的主要用途 |
|---|---|---|---|---:|---|
| `L7_FI_Verasonics_CIRS_points.uff` | CIRS 点靶 | Focused Imaging (FI) | USTB / Zenodo | 135.1 MB | PSF、FWHM、旁瓣；DAS/CF/MV/DMAS |
| `Alpinion_L3-8_FI_hypoechoic.uff` | 低回声目标 | Focused Imaging (FI) | USTB / Zenodo | 472.6 MB | CR/CNR/gCNR、speckle；DAS/CF/MV/SLSC/DMAS |
| `L7_FI_carotid_cross_1.uff` | 人体颈动脉横断面 | Focused Imaging (FI) | USTB / Zenodo | 263.8 MB | 真实人体鲁棒性；DAS/CF/MV/SLSC/DMAS |
| `L7_FI_carotid_cross_2.uff` | 人体颈动脉横断面 | Focused Imaging (FI) | USTB / Zenodo | 263.8 MB | 真实人体鲁棒性；DAS/CF/MV/SLSC/DMAS |
| `L7_CPWC_TheGB.uff` | CIRS 054GS phantom | Plane Wave / CPWC | USTB TheGB | 14.3 MB | Tx 模式对照；DAS/CF/MV/SLSC/DMAS |
| `L7_DW_TheGB.uff` | CIRS 054GS phantom | Diverging Wave (DW) | USTB TheGB | 32.2 MB | Tx 模式对照；DAS/CF/MV/SLSC/DMAS |
| `L7_STA_TheGB.uff` | CIRS 054GS phantom | Single-element STA | USTB TheGB | 165.2 MB | Tx 模式对照；DAS/CF/MV/SLSC/DMAS |
| `L7_FI_TheGB.uff` | CIRS 054GS phantom | Focused Imaging (FI) | USTB TheGB | 165.9 MB | Tx 模式对照；DAS/CF/MV/SLSC/DMAS |
| `PICMUS_experiment_resolution_distortion.uff` | 实验点靶 | Plane Wave / CPWC | IEEE IUS 2016 PICMUS / USTB | 145.5 MB | 分辨率、PSF、几何畸变 |
| `PICMUS_experiment_contrast_speckle.uff` | 实验 contrast / speckle phantom | Plane Wave / CPWC | IEEE IUS 2016 PICMUS / USTB | 145.5 MB | Contrast、CNR/gCNR、speckle |
| `PICMUS_carotid_cross.uff` | 人体颈动脉横断面 | Plane Wave / CPWC | IEEE IUS 2016 PICMUS / USTB | 76.7 MB | 人体 PW benchmark |
| `PICMUS_carotid_long.uff` | 人体颈动脉纵断面 | Plane Wave / CPWC | IEEE IUS 2016 PICMUS / USTB | 76.7 MB | 人体 PW benchmark |

当前 12 个文件合计约 **2.0 GB（Zenodo 十进制标称）**。浏览器显示的数值可能因 MB/MiB 换算而略小。

---

# 3. USTB Focused Imaging 数据

## 3.1 L7_FI_Verasonics_CIRS_points.uff

### 数据介绍

- **对象**：CIRS point-target phantom。
- **探头/系统**：文件名与 USTB 分类表明为 L7 系列线阵、Verasonics、Focused Imaging。
- **数据层级**：channel data。
- **USTB 官方关联**：TUFFC fDMAS publication。
- **谐波模式**：原始公开目录未明确标为 THI/PIHI，不应自行假设。

### 适合复现

这套数据最适合作为 focused beamforming 的第一套验证数据：

- DAS
- CF / GCF / PCF
- MV / MVDR / Capon
- DMAS / fDMAS
- SLSC（可做相干性分析，但点靶不是评价 speckle/contrast 的最佳数据）

推荐指标：

- axial/lateral FWHM
- Point Spread Function (PSF)
- side-lobe level
- peak position / localization error

### 来源与下载

- USTB 数据目录：<https://unioslo.github.io/USTB/datasets.html>
- Zenodo USTB v5：<https://zenodo.org/records/20261898>
- 直接下载：<https://zenodo.org/records/20261898/files/L7_FI_Verasonics_CIRS_points.uff?download=1>
- MD5：`4f8086463b5212ba3fd9456a6c25ff59`

---

## 3.2 Alpinion_L3-8_FI_hypoechoic.uff

### 数据介绍

- **对象**：hypoechoic target / phantom。
- **系统/探头**：Alpinion，L3-8。
- **发射**：Focused Imaging。
- **数据层级**：channel data。
- **USTB 官方关联**：advanced beamforming example。
- **谐波模式**：未明确。

### 适合复现

相比点靶数据，这套数据更适合评价“图像质量”而不是单纯分辨率：

- DAS
- CF / GCF / PCF
- MV / MVDR
- SLSC
- DMAS / fDMAS

推荐指标：

- Contrast Ratio (CR)
- CNR
- gCNR
- lesion detectability
- background speckle statistics

尤其适合检查自适应算法是否只是把目标区域“做黑”，但同时破坏了 speckle 统计或引入伪影。

### 来源与下载

- USTB 数据目录：<https://unioslo.github.io/USTB/datasets.html>
- Zenodo USTB v5：<https://zenodo.org/records/20261898>
- 直接下载：<https://zenodo.org/records/20261898/files/Alpinion_L3-8_FI_hypoechoic.uff?download=1>
- MD5：`b3f4773af0d9852208068beaee955ddb`

---

## 3.3 L7_FI_carotid_cross_1.uff / L7_FI_carotid_cross_2.uff

### 数据介绍

USTB 官方目录明确标记为：

- **L7-4**
- **in-vivo carotid cross-section**
- **channel data**
- **Focused Imaging**

这是当前数据组中非常重要的 **真实人体 focused-acquisition benchmark**。

### 适合复现

- DAS
- CF / GCF / PCF
- MV / MVDR
- SLSC
- DMAS / fDMAS

推荐重点观察：

- vessel lumen 的 clutter suppression
- vessel wall 连续性
- speckle texture 是否被过度破坏
- adaptive beamformer 是否产生局部假结构
- 对相位误差、低 SNR 与真实组织散射的鲁棒性

两份独立 acquisition 都建议保留，避免人体结果只依赖单帧/单 acquisition。

### 来源与下载

**cross 1**

- 直接下载：<https://zenodo.org/records/20261898/files/L7_FI_carotid_cross_1.uff?download=1>
- MD5：`4b6622477c4f9af882dc2496e36dc3bf`

**cross 2**

- 直接下载：<https://zenodo.org/records/20261898/files/L7_FI_carotid_cross_2.uff?download=1>
- MD5：`108477dbd0b6cda6a03f2b840266b58c`

公共入口：

- <https://unioslo.github.io/USTB/datasets.html>
- <https://zenodo.org/records/20261898>

---

# 4. TheGB：同平台/同 phantom 的四种发射方式

这一组对本项目尤其重要，因为它允许把 **Transmit strategy** 与 **Beamformer** 两个因素分开研究。

USTB 2026 Generalized Beamformer 示例明确说明四套 acquisition：

| 文件 | Tx 类型 | Tx 数量（官方示例） |
|---|---|---:|
| `L7_CPWC_TheGB.uff` | Plane Wave / CPWC | 11 |
| `L7_DW_TheGB.uff` | Diverging Wave | 25 |
| `L7_STA_TheGB.uff` | Single-element STA | 128 |
| `L7_FI_TheGB.uff` | Focused Imaging | 128 |

四套数据的共同采集条件：

- **Scanner**：Verasonics Vantage 256
- **Probe**：Philips L7-4 linear array
- **Elements**：128
- **Pitch**：0.298 mm
- **Center frequency**：约 5.2 MHz
- **Receive sampling frequency**：约 20.8 MHz
- **Phantom**：CIRS 054GS

因此它非常适合构建二维比较：

```text
Transmit strategy × Beamformer

PW   × DAS / CF / MV / SLSC / DMAS
DW   × DAS / CF / MV / SLSC / DMAS
STA  × DAS / CF / MV / SLSC / DMAS
FI   × DAS / CF / MV / SLSC / DMAS
```

这样可以区分“算法本身的效果”和“不同发射波前/数据冗余造成的效果”。

### 下载

- CPWC：<https://zenodo.org/records/20261898/files/L7_CPWC_TheGB.uff?download=1>  
  MD5：`7254e6cc505b9abb54ea94c5fc4ac015`
- DW：<https://zenodo.org/records/20261898/files/L7_DW_TheGB.uff?download=1>  
  MD5：`ae479d1122106e8d8d95d211b17ad5ae`
- STA：<https://zenodo.org/records/20261898/files/L7_STA_TheGB.uff?download=1>  
  MD5：`b432201412570c07b552cbaf950776d5`
- FI：<https://zenodo.org/records/20261898/files/L7_FI_TheGB.uff?download=1>  
  MD5：`9d9c728b9d03fa66444956b445fe2d7f`

### 官方资料

- USTB The Generalized Beamformer：<https://unioslo.github.io/USTB/generalized_beamformer.html>
- 四种发射模式 MATLAB 示例：<https://unioslo.github.io/USTB/examples/publications/preprint/generalized_beamformer/TheGB_all_transmit_sequences.html>
- USTB 数据目录：<https://unioslo.github.io/USTB/datasets.html>

---

# 5. PICMUS：IEEE IUS 2016 Plane-Wave Benchmark

PICMUS 全称：

**Plane-wave Imaging Challenge in Medical UltraSound**

是 IEEE International Ultrasonics Symposium (**IUS 2016**) 的公开波束合成 Challenge。

官方 Challenge 将图像质量评价分为 resolution、contrast、speckle quality、geometric distortion 等指标，因此非常适合作为 PW/CPWC beamforming 的标准 benchmark。

## 5.1 已下载的四套 PICMUS 数据

### PICMUS_experiment_resolution_distortion.uff

- **实验数据**
- 主要用于 point-target resolution / distortion
- 适合：DAS、CF/GCF、MV/MVDR、DMAS/fDMAS、SLSC
- 推荐指标：axial/lateral FWHM、PSF、localization/geometric distortion
- 下载：<https://zenodo.org/records/20261898/files/PICMUS_experiment_resolution_distortion.uff?download=1>
- MD5：`e8a4487993222f28458aa88259345440`

### PICMUS_experiment_contrast_speckle.uff

- **实验 contrast/speckle phantom**
- 适合：DAS、CF/GCF、MV/MVDR、SLSC、DMAS/fDMAS
- 推荐指标：contrast、CNR/gCNR、speckle statistics
- 下载：<https://zenodo.org/records/20261898/files/PICMUS_experiment_contrast_speckle.uff?download=1>
- MD5：`26bbfbbb702e90fe4fa9f1ab7d7fc065`

### PICMUS_carotid_cross.uff

- **in-vivo human carotid，cross-section**
- 主要用于真实人体 PW beamforming
- 下载：<https://zenodo.org/records/20261898/files/PICMUS_carotid_cross.uff?download=1>
- MD5：`be81dfc519d3f7c642ff60d85642f311`

### PICMUS_carotid_long.uff

- **in-vivo human carotid，longitudinal**
- 主要用于真实人体 PW beamforming
- 下载：<https://zenodo.org/records/20261898/files/PICMUS_carotid_long.uff?download=1>
- MD5：`09fddc4ca1ce2dc9d1ac870a9d3871b6`

## 5.2 PICMUS 采集参数

PICMUS 官方实验数据采用：

- Probe：L11-4v
- Elements：128
- Pitch：0.30 mm
- Transmit frequency：5.208 MHz
- Sampling frequency：20.832 MHz
- Pulse bandwidth：67%
- Excitation：2.5 cycles
- Transmit voltage：30 V

PICMUS 是 **plane-wave imaging challenge**。官方定义的是 steering plane-wave sequence，而不是正/负极性成对发射的 PI 序列。因此：

```text
Tx mode = Plane Wave / CPWC
PI acquisition = false
THI = not explicitly specified by the public challenge metadata
```

不要将 PICMUS 用作 PI harmonic benchmark。

## 5.3 来源

- PICMUS 官方主页：<https://www.creatis.insa-lyon.fr/Challenge/IEEE_IUS_2016/>
- 官方下载页：<https://www.creatis.insa-lyon.fr/Challenge/IEEE_IUS_2016/download>
- 官方 Data/Rules：<https://www.creatis.insa-lyon.fr/Challenge/IEEE_IUS_2016/Data_info>
- 官方 transmit pulse：<https://www.creatis.insa-lyon.fr/Challenge/IEEE_IUS_2016/transmit_pulse>
- USTB 转换后的 MATLAB/UFF 版本：<https://unioslo.github.io/USTB/datasets.html>
- Zenodo UFF 文件：<https://zenodo.org/records/20261898>

PICMUS 官方说明数据和代码可免费使用，但要求正确引用 PICMUS / IUS 2016 proceeding：

> H. Liebgott, A. Rodriguez-Molares, J. A. Jensen, O. Bernard, “Plane-Wave Imaging Challenge in Medical Ultrasound,” IEEE International Ultrasonics Symposium, 2016.

---

# 6. 建议的算法—数据配对

| 研究问题 | 首选数据 |
|---|---|
| DAS 延时/插值是否正确 | `L7_FI_Verasonics_CIRS_points.uff`、PICMUS resolution |
| PSF / axial & lateral resolution | CIRS points、PICMUS resolution |
| CF / GCF / PCF | CIRS points + hypoechoic + carotid |
| MV / MVDR / Capon | CIRS points + hypoechoic + carotid；再扩展到 TheGB |
| SLSC / spatial coherence | hypoechoic + carotid；TheGB 可做 Tx 模式敏感性 |
| DMAS / fDMAS | **CIRS points（USTB 官方与 fDMAS publication 关联）** + hypoechoic + carotid |
| Contrast / CNR / gCNR | Alpinion hypoechoic、PICMUS contrast/speckle |
| Speckle preservation | Alpinion hypoechoic、PICMUS contrast/speckle、carotid |
| 真实人体鲁棒性 | USTB focused carotid + PICMUS PW carotid |
| Tx strategy 对算法的影响 | **TheGB 四件套：PW / DW / STA / FI** |
| PW/CPWC 标准 benchmark | **PICMUS** |
| Focused Imaging benchmark | USTB FI CIRS / Alpinion / carotid |

---

# 7. MATLAB / USTB 读取

USTB 是 MATLAB toolbox。官方示例的基本读取方式为：

```matlab
filename = 'L7_FI_Verasonics_CIRS_points.uff';

channel_data = uff.read_object(filename, '/channel_data');
```

正式写 beamformer 前，建议至少检查：

```text
data shape / dimensions
sampling frequency
initial time
sound speed
probe geometry / element coordinates
transmit sequence / N_waves
focus or steering angle
transmit / receive aperture
modulation / demodulation frequency
channel data real/complex dtype
```

不同发射方式的 transmit delay 模型不能混用。特别是 PW、DW、STA 和 FI，即使都最终进入 DAS/CF/MV/SLSC/DMAS，发射路径 `tau_tx` 的定义也不同。

---

# 8. 数据完整性

Zenodo 当前记录提供每个文件的 MD5。下载完成后可在 Windows PowerShell 中检查：

```powershell
Get-FileHash .\L7_FI_Verasonics_CIRS_points.uff -Algorithm MD5
```

将输出值与本 README 中对应 MD5 比较。

---

# 9. 当前数据集的边界

当前 12 个文件已经覆盖：

- Focused Imaging
- Plane Wave / CPWC
- Diverging Wave
- Synthetic Transmit Aperture
- point target
- hypoechoic phantom
- speckle / contrast phantom
- in-vivo carotid
- channel-level data

但**尚未覆盖当前项目非常关心的明确 THI / Pulse-Inversion Harmonic Imaging (PIHI) channel data**。

因此后续如果加入谐波数据，应单独标记：

```text
imaging_mode        = fundamental / THI / PIHI / unknown
pi_polarity_pair    = available / unavailable
tx_polarity         = + / -
harmonic_filter     = ...
```

不要把 conventional channel data 与 PI-combined harmonic channel data 混在同一 benchmark 条件下直接比较。

---

## 10. 主要公共来源

1. **UltraSound ToolBox (USTB)**  
   <https://unioslo.github.io/USTB/>

2. **USTB Dataset Catalog**  
   <https://unioslo.github.io/USTB/datasets.html>

3. **USTB datasets — Zenodo, v5**  
   DOI: `10.5281/zenodo.20261898`  
   <https://zenodo.org/records/20261898>

4. **IEEE IUS 2016 PICMUS Challenge**  
   <https://www.creatis.insa-lyon.fr/Challenge/IEEE_IUS_2016/>

5. **USTB Generalized Beamformer / TheGB**  
   <https://unioslo.github.io/USTB/generalized_beamformer.html>
