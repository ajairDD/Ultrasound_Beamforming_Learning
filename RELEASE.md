# Release v1.0.0

发布日期：2026-11-14

本文件是发布前的检查表、许可矩阵和再分发说明。它不替代 [LICENSE](LICENSE)、[LICENSE-CONTENT.md](LICENSE-CONTENT.md) 或 [NOTICE.md](NOTICE.md) 的正式条款。

## 1. 发布内容

- 第 0-8 章中文 PDF，共 9 份、260 页，全部 A4 纵向。
- 章节 Markdown、MATLAB 教学代码、配图索引、生成提示词和复现记录。
- PDF 构建与结构检查脚本。
- 原始 UFF 数据不随仓库分发；数据来源、MD5 和下载方式见 [data/README.md](data/README.md)。

## 2. 本版本新增的发布标识

- 每份 PDF 的封面显示项目主页、版权和许可摘要。
- 每一页页脚显示 GitHub 地址、版权、内容许可、代码许可和页码。
- 每一页的 GitHub 地址都有可点击链接。
- PDF 元数据写入项目地址、版权、许可、章节 ID 和发布版本。
- `output/pdf/manifest.json` 记录页数、SHA-256、链接数量、A4 页面格式和来源 Markdown 校验值。
- 新增 `LICENSE`、`LICENSE-CONTENT.md`、`NOTICE.md`、`CITATION.cff` 和本文件。

## 3. 许可矩阵

| 对象 | 许可 | 允许 | 不允许或需要额外条件 |
|---|---|---|---|
| 源代码 | AGPL-3.0-only | 学习、修改、分发 | 分发衍生软件时须提供对应源代码并保留许可；不得移除版权声明。 |
| 课程正文、PDF、原创图和表格 | CC BY-NC-SA 4.0 | 署名后非商业分享、改编 | 不得商业使用；改编作品须相同方式共享；不得移除来源和许可标识。 |
| USTB 软件 | MIT | 按 MIT 条款使用 | 保留版权和许可声明。 |
| USTB datasets | CC BY 4.0 | 按 CC BY 4.0 使用 | 必须署名；原始 UFF 不由本仓库分发。 |
| PICMUS 数据 | 官方免费使用条款 | 免费使用 | 必须正确提及 PICMUS 并引用 IUS 2016 proceeding。 |
| 第三方商标和论文 | 各自权利人 | 仅作来源说明 | 不得暗示赞助、认证或背书。 |

如果计划把课程正文或 PDF 用于商业培训、商业产品、付费平台或其他商业用途，请先通过 GitHub Issues 联系维护者取得单独许可。AGPL 对代码的授权不改变课程内容的非商业限制。

## 4. 防冒用与来源核验

许可证不能从技术上阻止复制，但本发布通过以下方式建立可核验来源：

1. 每页可见 GitHub 地址和版权/许可页脚。
2. 每页可点击的项目链接。
3. PDF 元数据中的来源、许可和发布版本。
4. `CITATION.cff` 提供标准引用入口。
5. `manifest.json` 提供 SHA-256、页数和链接审计。
6. `NOTICE.md` 明确第三方资源、商标和无隶属关系。

再分发时不得移除或遮挡页脚、封面来源、版权声明、许可链接和引用信息。若发现未署名转载，请通过 [Issues](https://github.com/ajairDD/Ultrasound_Beamforming_Learning/issues) 提供链接和截图。

## 5. 发布前检查表

- [x] 代码许可文件已加入。
- [x] 课程内容许可文件已加入。
- [x] USTB、USTB datasets、TheGB、PICMUS 和构建依赖已声明。
- [x] 引用文件已加入。
- [x] 9 份 PDF 已重建。
- [x] 每页 GitHub 地址、版权/许可页脚和可点击链接已写入。
- [x] PDF 元数据已写入。
- [x] PDF 结构、字体、链接和 A4 页面检查已执行。
- [x] `manifest.json` 已更新。
- [ ] 在 GitHub 上创建 `v1.0.0` tag 和 Release（由仓库维护者执行）。
- [ ] 在 GitHub Release 页面附上 `manifest.json` 和本文件（由仓库维护者执行）。

## 6. 复验命令

在仓库根目录运行：

```powershell
$courseRuntime = 'C:\Users\Utrasound_2\.cache\codex-runtimes\codex-primary-runtime\dependencies'
& "$courseRuntime\node\bin\node.exe" tools/pdf/build_chapters.cjs
& "$courseRuntime\python\python.exe" tools/pdf/audit_pdf_structure.py
git diff --check
```

构建脚本会重新生成 9 份 PDF；结构检查会验证每页项目地址、可点击链接、中文字体、A4 页面、内部链接和 SHA-256。

## 7. 已知边界

- 本项目不是医疗器械，不用于临床诊断或治疗决策。
- 真实数据实验的结论受数据、参数、网格、孔径、传播模型和验证范围限制；详见各章正文。
- 第三方数据、软件和论文的权利不因本项目许可而改变。
- 本文件是发布说明，不构成法律意见；正式商业使用前应自行核对适用法律和第三方条款。
