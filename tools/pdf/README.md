# PDF 讲义与中文配图

第 0–4 章各输出一份完整讲义，文件位于 [`output/pdf/`](../../output/pdf/README.md)。PDF 包括封面、可点击目录、正文、公式、示例代码、参考资料，以及正文未展开的补充图片。正文中的代码标识、方法名称与原有中英术语保留。

## 配图汉化

全部 **127 张 PNG** 均纳入汉化：24 张 AI 概念图由内置 `image_gen` 逐张编辑，103 张 MATLAB 图从可编辑图形对象重新导出。标题、说明、坐标名称、图例、参考线标签与多子图总标题使用中文。DAS、RTB、CF、GCF、MVDR、DMAS、fDMAS、RF、IQ、PSF、FFT、B-mode 等业内术语，以及数学符号、代码标识、窗函数名称和单位保留。

- [`figure_translations.json`](figure_translations.json)：人工核对的 MATLAB 文字映射。
- [`image_localization.json`](image_localization.json)：24 张概念图的中文编辑提示词。
- 各章配图索引保留最初的生成提示词；英文提示词是历史来源记录，不代表当前图内文字。
- 原始配图可从汉化前的 Git 提交 `37dc881c68ace2275a74729f1724b1dd3e35bfc7` 追溯。

汉化不修改波束合成算法、数据或重建参数。导出工具比对图形对象的数值数组、坐标上下限（包括双纵轴）、色标、比例和方向；字体变化可能触发 MATLAB 自动调整坐标，因此先保存并恢复原有范围，再验证和导出。中文标签使用独立留白，密集子图重新分配不重叠的外框。AI 图逐张核对通道数量、索引、公式、连接关系与中文文字，不作为定量结果。

## 重新导出 MATLAB 图

在仓库根目录使用独立 MATLAB 会话。实际验证环境为 MATLAB R2021b；中文字体为 Microsoft YaHei。第 1–4 章真实数据实验需要本地 USTB 与仓库 `data/` 中的 UFF。

```matlab
addpath(genpath('D:/USTB')); % 改为本机 USTB 路径
addpath(fullfile(pwd,'matlab','00_Fundamentals'));
export_tutorial_figures;
addpath(fullfile(pwd,'matlab','01_DAS_Real_UFF'));
export_chapter1_figures('all');
addpath(fullfile(pwd,'matlab','02_CF_GCF'));
export_chapter2_figures('all');
addpath(fullfile(pwd,'matlab','03_MVDR'));
export_chapter3_figures('all');
addpath(fullfile(pwd,'matlab','04_DMAS'));
export_chapter4_figures('all');
```

每个入口调用共享的 `matlab/export_figure_zh_cn.m`，保存未汉化的可编辑 `.fig` 到 `work/pdfs/matlab_figures/`，再应用映射导出中文 PNG。若只改文字映射，无需重新计算算法：

```matlab
addpath(fullfile(pwd,'matlab'));
reexport_chinese_figures('all'); % 也可指定 '04_DMAS' 等目录名
```

数值比对结果保存在 `work/pdfs/figure_translation_audit_all.json`。实际已完成 103 张图的数组、坐标与色标一致性检查。MATLAB 导出成功后，当前机器在退出阶段仍报告无法识别 `Settings`；该环境问题与原有配图记录一致，不将其描述为无报错退出。

## 生成 PDF

构建器使用本地 Markdown、KaTeX、Chrome 和 ReportLab，不依赖在线公式或字体服务。显示公式沿用 README 中单行的 `$$ ... $$` 写法。原生 Mermaid 图按原节点和连接关系转换为便于印刷的中文 SVG。

当前验证环境使用 Codex 提供的 Node/Python 运行时；Node 依赖版本锁定在 `package.json` 和 `pnpm-lock.yaml`。需要 `markdown-it`、`katex`、Playwright、ReportLab、pypdf、pdfplumber、Pillow，以及系统 Chrome/Edge、Poppler。字体来自本机 Microsoft YaHei、DengXian 与 KaTeX。

在仓库根目录运行：

```powershell
$courseRuntime = 'C:\Users\Utrasound_2\.cache\codex-runtimes\codex-primary-runtime\dependencies'
& "$courseRuntime\node\bin\node.exe" tools/pdf/build_chapters.cjs
```

`tools/pdf/node_modules/` 需要按锁文件安装依赖。构建器使用上述运行时内的 Playwright；可用 `COURSE_CHROME`、`COURSE_PYTHON` 指定浏览器或 Python 路径。只导出一章可追加 `--chapter 0`（0–4）。构建清单和检查结果写入 `work/pdfs/`，临时文件不进入 Git。

## 版面与文字检查

```powershell
& "$courseRuntime\python\python.exe" tools/pdf/collect_figure_text.py
& "$courseRuntime\python\python.exe" tools/pdf/review_assets.py figures
& "$courseRuntime\python\python.exe" tools/pdf/review_assets.py pdfs
& "$courseRuntime\python\python.exe" tools/pdf/audit_pdf_structure.py
```

构建时检查图片完整加载、配图总数、KaTeX 解析、Markdown 强调标记和元素横向溢出。后处理验证 PDF 可读、正文非空，再把每页渲染为 PNG，检查页面边界并生成逐页核对图。结构检查验证内部跳转目标、中文字体嵌入和文件校验值，输出 `output/pdf/manifest.json`。

Windows 上可补充 OCR 检查（需安装简体中文 OCR）：

```powershell
& 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe' -NoProfile -ExecutionPolicy Bypass -File tools/pdf/ocr_figures.ps1 -Root (Get-Location).Path
& "$courseRuntime\python\python.exe" tools/pdf/review_assets.py ocr
```

OCR 仅帮助发现漏译；数学符号、下标和缩写可能误识别。以可编辑文字清单、逐图检查和最终 PDF 的逐页核对为准。
