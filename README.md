# Ultrasound Beamforming Learning

一个以**医学超声经典波束合成**为主线的 MATLAB 学习项目。课程从真实 channel data 出发，逐步建立以下计算链：

> 空间位置 → Tx/Rx delay → fractional-sample interpolation → aperture / weighting → coherent sum → 图像与 PSF

建议学习顺序是**先理解原理，再运行小例子，最后使用真实 UFF 数据验证**。本仓库的第 0–8 章均已完成教学正文与配套实验；算法可运行不代表所有方法均通过论文级独立数值验证。

> **项目主页：** <https://github.com/ajairDD/Ultrasound_Beamforming_Learning>
>
> **许可：** 源代码采用 AGPL-3.0-only；课程正文、PDF 和原创配图采用 CC BY-NC-SA 4.0。第三方数据与工具不纳入本项目再许可。
>
> **引用与发布信息：** [CITATION.cff](CITATION.cff) · [NOTICE.md](NOTICE.md) · [RELEASE.md](RELEASE.md)

## 从这里开始

**第一次接触波束合成：** 从[第 0 章](chapters/00_Fundamentals/README.md)开始，它的 MATLAB 示例不需要 USTB 或外部数据。

~~~matlab
% 在 MATLAB 中将当前文件夹设为仓库根目录
addpath('matlab/00_Fundamentals');
demo_synthetic_point_target
~~~

**已经理解 delay / DAS，准备重建真实图像：** 按[数据准备](data/README.md)下载 `L7_FI_TheGB.uff` 至 `data/`，安装 USTB，然后从[第 1 章](chapters/01_DAS_Real_UFF/README.md)进入真实 FI-DAS 与 RTB。

~~~matlab
% 在仓库根目录启动 MATLAB
addpath(genpath('D:/你的USTB路径'));  % 修改为本机路径
cd matlab/01_DAS_Real_UFF
inspect_uff_metadata_ustb
das_fi_scanline_manual
~~~

完整的环境与各章入口见 **[MATLAB 总指南](matlab/README.md)**。默认真实实验使用 TheGB focused FI channel data；其他数据的来源、用途与下载方式见[数据清单](data/README.md)。

## 课程地图

| 章节 | 这一章解决什么问题 | 教学正文 | MATLAB 实践 | 已发布 PDF |
|---|---|---|---|---|
| 0 · Fundamentals | 延时、孔径、相位、PSF 与 DAS 的基本边界 | [阅读](chapters/00_Fundamentals/README.md) | [运行](matlab/00_Fundamentals/README.md) | [讲义](output/pdf/第00章_波束合成共同基础.pdf) |
| 1 · FI-DAS / RTB | 从真实通道数据重建一条线和二维图像 | [阅读](chapters/01_DAS_Real_UFF/README.md) | [运行](matlab/01_DAS_Real_UFF/README.md) | [讲义](output/pdf/第01章_FI-DAS与RTB.pdf) |
| 2 · CF / GCF | 利用接收孔径相干性给 DAS 结果加权 | [阅读](chapters/02_CF_GCF/README.md) | [运行](matlab/02_CF_GCF/README.md) | [讲义](output/pdf/第02章_CF与GCF.pdf) |
| 3 · MVDR | 根据局部数据估计自适应接收权重 | [阅读](chapters/03_MVDR/README.md) | [运行](matlab/03_MVDR/README.md) | [讲义](output/pdf/第03章_MVDR.pdf) |
| 4 · DMAS / fDMAS | 通道配对、非线性求和与二倍频带 | [阅读](chapters/04_DMAS/README.md) | [运行](matlab/04_DMAS/README.md) | [讲义](output/pdf/第04章_DMAS与fDMAS.pdf) |
| 5 · SLSC | 用短间距阵元的相关性形成图像 | [阅读](chapters/05_SLSC/README.md) | [运行](matlab/05_SLSC/README.md) | [讲义](output/pdf/第05章_SLSC.pdf) |
| 6 · NSI | 利用不同接收孔径的包络相减改变空间响应 | [阅读](chapters/06_NSI/README.md) | [运行](matlab/06_NSI/README.md) | [讲义](output/pdf/第06章_NSI.pdf) |
| 7 · Benchmark | 建立公平比较条件、指标与结论边界 | [阅读](chapters/07_Benchmark/README.md) | [运行](matlab/07_Benchmark/README.md) | [讲义](output/pdf/第07章_统一Benchmark.pdf) |
| 8 · RTB Comparison | 同一 RTB 前端下比较七种组合规则 | [阅读](chapters/08_RTB_Comparison/README.md) | [运行](matlab/08_RTB_Comparison/README.md) | [讲义](output/pdf/第08章_七方法RTB对照.pdf) |

按顺序学习即可；第 0 章负责共同概念，第 1 章建立可靠 DAS 基线，第 2–6 章学习不同组合方式，第 7–8 章负责比较与综合。**每一章的正文开头都提供“学习导航”，MATLAB 目录内则给出“快速开始”。**

## 阅读、代码与配图分别在哪里？

- **学习理论与公式：** `chapters/00_...` 至 `chapters/08_...` 中的 `README.md`。
- **运行与调试：** `matlab/` 下对应编号目录的 `README.md`；公共 RTB 数据接口见 [RTB_Universal](matlab/RTB_Universal/README.md)。
- **查看完整中文配图：** 使用上表的**已发布 PDF**。独立 PNG/FIG 未提交 Git，因而 GitHub 中部分 Markdown 图片无法预览；需要在本地重建图片时查阅[配图与构建说明](tools/pdf/README.md)。
- **查看课件图片来源、参数和日志：** 每章 `figures/README.md`。它们是配套资料，不是初次学习的必读入口。

第 5–8 章 PDF 已同步采用 A4 纵向紧凑排版：宽图随正文流动并按页宽缩放，多列表格可跨页并重复表头，目录列出二级标题；正文、公式、图注和配图内容未改。

## 许可、引用与防冒用

- **代码：** 采用 [AGPL-3.0-only](LICENSE)。修改或分发衍生软件时，须遵守 AGPL 的源代码提供义务并保留版权声明。
- **课程内容：** 课程正文、PDF、原创示意图、表格和原创配图采用 [CC BY-NC-SA 4.0](LICENSE-CONTENT.md)。转载或改编须署名、非商业使用、相同方式共享，并保留项目地址和许可标识。
- **第三方资源：** USTB 使用 MIT 许可；USTB datasets 使用 CC BY 4.0；PICMUS 允许免费使用但要求正确引用。原始 UFF 不随仓库分发，具体来源、引用和边界见 [NOTICE.md](NOTICE.md) 与 [data/README.md](data/README.md)。
- **PDF 来源标识：** 第 0–8 章每份 PDF 的封面和每一页页脚都包含 GitHub 地址、版权与许可摘要；地址可点击，元数据也写入项目来源和发布版本。
- **引用：** 学术使用请使用 [CITATION.cff](CITATION.cff)，并同时引用所使用的 USTB、数据集和算法原始文献。
- **发现未署名转载：** 请通过 [GitHub Issues](https://github.com/ajairDD/Ultrasound_Beamforming_Learning/issues) 提供链接和截图。许可证不能从技术上阻止复制，但能为署名、来源核验和后续维权提供明确依据。

## 科学实现与验证边界

真实超声数据必须核对 RF/IQ、shape/axis、单位、采样时刻、probe / sequence、Tx/Rx delay、插值、孔径、相位和幅度/dB 约定；**程序运行、PSF 变窄或灰度图变好看，均不单独构成科学有效性证明**。

仓库提供 `cd matlab; run_all_checks`，用于复查合成标准接口、TheGB 复数 RTB-DAS 基线与七方法紧凑集成测试；这不是所有算法的论文级真值验证，也不等于跨厂商、临床或计算性能已验证。各章分别保留实际观测、参数和限制，不在首页重复陈列。
