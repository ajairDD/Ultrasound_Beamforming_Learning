# 第三方资源、引用与使用边界

Copyright © 2026 Ultrasound Beamforming Learning contributors. All rights reserved except as expressly granted below.

本文件记录本项目使用的外部软件、数据、论文、生成式工具和商标。它不改变第三方资源自身的许可或使用条款，也不表示本项目有权把第三方资源重新许可为 AGPL-3.0 或 CC BY-NC-SA 4.0。

## 1. 本项目许可范围

| 内容 | 许可 | 说明 |
|---|---|---|
| MATLAB、Python、JavaScript、Shell 等源代码 | [AGPL-3.0-only](LICENSE) | 修改和分发衍生作品时须遵守 AGPL 的源代码提供义务。 |
| 课程正文、PDF、原创示意图、表格、注释和原创配图 | [CC BY-NC-SA 4.0](LICENSE-CONTENT.md) | 须署名、非商业使用、相同方式共享；不得移除来源和许可标识。 |
| 第三方数据、软件、论文、商标和生成式工具 | 各自许可或条款 | 见下文。原始 UFF 数据不随本仓库分发。 |

如果你使用或转载本项目，请同时阅读 [CITATION.cff](CITATION.cff) 和 [RELEASE.md](RELEASE.md)。如第三方条款与本项目许可发生冲突，第三方材料以原条款为准。

## 2. USTB

- 项目：UltraSound ToolBox (USTB)
- 仓库：<https://github.com/unioslo/USTB>
- 文档：<https://unioslo.github.io/USTB/>
- 许可：MIT License，版权归 UltraSound ToolBox contributors。
- 本项目用途：读取 UFF、检查元数据、作为匹配条件下的参考验证。USTB 不随本仓库分发；本项目的教学算法核心以显式 MATLAB 代码实现，不是 USTB 的打包副本。
- 已记录的实验版本：`86126eb7cab8b6009d14f2d448e85eeb8a86f61c`。

使用 USTB 时至少引用以下两项：

1. Rodriguez-Molares, A., Rindal, O. M. H., Bernard, O., Nair, A., Bell, M. A. L., Liebgott, H., Austeng, A., Løvstakken, L. (2017). *The UltraSound ToolBox*. IEEE International Ultrasonics Symposium (IUS), 1-4. DOI: [10.1109/ULTSYM.2017.8092389](https://doi.org/10.1109/ULTSYM.2017.8092389).
2. Rindal, O. M. H., Vrålstad, A. E., Avdal, J., Fiorentini, S., Austeng, A., Rodriguez-Molares, A. (2026). *The Generalized Beamformer in the UltraSound ToolBox*. Ultrasonics, 170, 108289. DOI: [10.1016/j.ultras.2026.108289](https://doi.org/10.1016/j.ultras.2026.108289).

如果使用 USTB 中的特定 process 或 dataset，还应读取对应 UFF/process 对象的 `reference` 字段并引用其中列出的原始文献。

USTB 的 MIT 许可文本：

```text
MIT License

Copyright (c) UltraSound ToolBox contributors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## 3. USTB datasets

- 数据集记录：*USTB datasets*, Zenodo, DOI [10.5281/zenodo.20261898](https://doi.org/10.5281/zenodo.20261898), <https://zenodo.org/records/20261898>
- 创建者：Ole Marius Hoel Rindal
- 许可：CC BY 4.0
- 本项目引用并使用的文件：
  - USTB focused imaging：`L7_FI_Verasonics_CIRS_points.uff`、`Alpinion_L3-8_FI_hypoechoic.uff`、`L7_FI_carotid_cross_1.uff`、`L7_FI_carotid_cross_2.uff`。
  - TheGB：`L7_CPWC_TheGB.uff`、`L7_DW_TheGB.uff`、`L7_STA_TheGB.uff`、`L7_FI_TheGB.uff`。
  - PICMUS：`PICMUS_experiment_resolution_distortion.uff`、`PICMUS_experiment_contrast_speckle.uff`、`PICMUS_carotid_cross.uff`、`PICMUS_carotid_long.uff`。
- 原始 `.uff` 文件不纳入 Git，也不随 PDF 分发。下载地址、大小和 MD5 见 [data/README.md](data/README.md)。
- 本仓库中的 MATLAB 图、统计结果和 PDF 中的相关配图是本项目基于这些数据生成的衍生结果。数据本身的版权和 CC BY 4.0 归属仍属于原数据作者；本项目不声称拥有原始数据。
- 正式发表或再分发衍生结果时，请同时引用数据集记录、USTB 的两篇文献，以及 UFF 内部给出的原始 citation。

## 4. TheGB / Generalized Beamformer

TheGB 四套数据用于比较 focused imaging、plane wave/CPWC、diverging wave 和 STA。除数据集记录外，请引用：

- Rindal, O. M. H., Vrålstad, A. E., Avdal, J., Fiorentini, S., Austeng, A., Rodriguez-Molares, A. (2026). *The Generalized Beamformer in the UltraSound ToolBox*. Ultrasonics, 170, 108289. DOI: [10.1016/j.ultras.2026.108289](https://doi.org/10.1016/j.ultras.2026.108289).
- USTB Generalized Beamformer 文档：<https://unioslo.github.io/USTB/generalized_beamformer.html>

## 5. PICMUS

- 项目：Plane-wave Imaging Challenge in Medical UltraSound (PICMUS), IEEE IUS 2016。
- 官方主页：<https://www.creatis.insa-lyon.fr/Challenge/IEEE_IUS_2016/>
- 官方版权说明：<https://www.creatis.insa-lyon.fr/Challenge/IEEE_IUS_2016/node/48>
- 官方条款摘要：PICMUS 提供的数据和代码可免费使用，但要求正确提及 PICMUS，并引用其 IUS 2016 proceeding。
- 必引文献：Liebgott, H., Rodriguez-Molares, A., Jensen, J. A., Bernard, O. *Plane-Wave Imaging Challenge in Medical Ultrasound*. IEEE International Ultrasonics Symposium, Tours, France, 2016. DOI: [10.1109/ULTSYM.2016.7728908](https://doi.org/10.1109/ULTSYM.2016.7728908).
- 原始 PICMUS 数据不随本仓库分发；本仓库只提供来源、下载说明和基于数据生成的图/结果。

## 6. 生成式工具与概念插图

第 0-8 章的一部分概念图使用 OpenAI 的图像生成能力制作，随后由本项目逐张检查、编辑并加入中文标注。它们只解释机制或处理顺序，不按比例，不是实测声场、临床图像或性能证据。提示词和校正记录保存在各章 `figures/` 目录。

这些原创概念图按本项目的内容许可 CC BY-NC-SA 4.0 提供，前提是相关法域允许对生成内容主张版权。使用时仍须保留来源、许可和引用信息，不得把它们伪装成独立测量或第三方临床资料。

## 7. 构建工具

PDF 构建流程使用以下直接依赖；它们各自保留原许可：

- markdown-it 14.1.0：MIT
- KaTeX 0.16.22：MIT
- Playwright 1.62.1：Apache-2.0
- ReportLab 4.4.9：BSD
- pypdf 6.21.4：BSD-3-Clause
- pdfplumber 0.11.9：MIT
- Pillow 13.0.0：MIT-CMU

依赖版本和锁文件见 [tools/pdf/package.json](tools/pdf/package.json) 与 [tools/pdf/pnpm-lock.yaml](tools/pdf/pnpm-lock.yaml)。本仓库不重新许可这些依赖。

## 8. 商标、隶属关系与临床边界

USTB、University of Oslo、PICMUS、IEEE、CIRS、Verasonics、Alpinion、Philips、MATLAB、MathWorks、OpenAI 等名称和商标归各自权利人所有。本项目仅用它们说明数据来源、工具依赖或实验背景，不表示任何隶属、赞助、认证或背书关系。

本项目是教学与研究材料，不是医疗器械，不用于临床诊断、治疗决策或患者监护。任何真实数据实验的结论都必须按对应章节所述的数据、参数、验证范围和限制解释。

## 9. 发现未署名转载

如果你发现本项目内容被移除 GitHub 地址、版权/许可页脚或引用信息后再次发布，请通过仓库 Issues 提供链接和页面截图：

<https://github.com/ajairDD/Ultrasound_Beamforming_Learning/issues>

PDF 的 SHA-256、页数和链接检查记录见 [output/pdf/manifest.json](output/pdf/manifest.json)。许可证赋予的是有条件的复制、修改和分发权；它不能从技术上阻止复制，但能为来源核验、署名要求和后续维权提供明确依据。
