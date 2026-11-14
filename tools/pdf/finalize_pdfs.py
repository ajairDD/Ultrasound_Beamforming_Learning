"""Add an embedded-font ReportLab cover, running header and page numbers."""
import io
import json
import sys
import time
from hashlib import sha256
from pathlib import Path
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.pdfgen.canvas import Canvas
from reportlab.lib.colors import HexColor
from reportlab.lib.pagesizes import A4
from pypdf import PdfReader, PdfWriter
from pypdf.annotations import Link

FONT_DIR = Path("C:/Windows/Fonts")
pdfmetrics.registerFont(TTFont("CourseSans",str(FONT_DIR/"Deng.ttf")))
pdfmetrics.registerFont(TTFont("CourseSansBold",str(FONT_DIR/"Dengb.ttf")))
NAVY = HexColor("#123c61")
TEAL = HexColor("#238a99")
GITHUB_URL = "https://github.com/ajairDD/Ultrasound_Beamforming_Learning"
COPYRIGHT = "© 2026 Ultrasound Beamforming Learning contributors"
CONTENT_LICENSE = "CC BY-NC-SA 4.0"
CODE_LICENSE = "AGPL-3.0"
RELEASE_VERSION = "1.0.0"
FOOTER_FONT_SIZE = 6.4
FOOTER_LINK_RECT = (48,21,48+pdfmetrics.stringWidth(GITHUB_URL,"CourseSans",FOOTER_FONT_SIZE),34)
COVER_LINK_RECT = (54,61,54+pdfmetrics.stringWidth(GITHUB_URL,"CourseSans",9.5),74)

def wrap(text,font,size,width):
    rows=[]; current=""
    for character in text:
        if pdfmetrics.stringWidth(current+character,font,size)>width:
            rows.append(current); current=character
        else:
            current+=character
    if current: rows.append(current)
    return rows

def cover(record):
    buffer=io.BytesIO(); c=Canvas(buffer,pagesize=A4)
    width,height=A4
    c.setFillColor(HexColor("#edf6fa")); c.rect(0,0,width,height,fill=1,stroke=0)
    c.setFillColor(NAVY); c.rect(0,height-14,width,14,fill=1,stroke=0)
    c.setFont("CourseSansBold",15); c.drawString(54,height-80,"超声波束合成学习课程")
    c.setFillColor(TEAL); c.setFont("CourseSansBold",76)
    c.drawString(50,height-225,f"{record['number']:02d}")
    c.setFillColor(NAVY); c.setFont("CourseSansBold",28)
    y=height-292
    for line in wrap(record["title"],"CourseSansBold",28,width-108):
        c.drawString(54,y,line); y-=43
    c.setStrokeColor(TEAL); c.setLineWidth(3); c.line(54,y-12,150,y-12)
    y-=70; c.setFont("CourseSansBold",12); c.drawString(54,y,"本章学习主线")
    y-=31; c.setFont("CourseSans",12)
    for line in wrap(record["route"],"CourseSans",12,width-108):
        c.drawString(54,y,line); y-=25
    c.setFillColor(HexColor("#45657b")); c.setFont("CourseSans",10)
    notes=[
        "完整课堂讲义 · 理论、公式、示例与图像解读",
        "配图说明使用中文；方法缩写、数学符号与单位保留。",
        ("正文保留学习主线，补充课件图附于章末。" if record.get('extra_images',0)
         else "配图紧随对应知识点，保留课堂讲解提示。"),
    ]
    for i,line in enumerate(notes):
        c.drawString(54,146-i*24,line)
    c.setFillColor(HexColor("#45657b")); c.setFont("CourseSansBold",9.5)
    c.drawString(54,80,"项目主页")
    c.setFillColor(TEAL); c.setFont("CourseSans",9.5)
    c.drawString(54,64,GITHUB_URL)
    c.setFillColor(HexColor("#6b7f8c")); c.setFont("CourseSans",7.8)
    c.drawString(54,48,"引用：CITATION.cff · 许可：LICENSE / LICENSE-CONTENT.md · 第三方声明：NOTICE.md")
    c.showPage(); c.save(); buffer.seek(0)
    return PdfReader(buffer)

def overlay(width,height,title,page,total,first):
    buffer=io.BytesIO(); c=Canvas(buffer,pagesize=(width,height))
    c.setFont("CourseSans",8.2); c.setFillColor(HexColor("#567284"))
    if not first:
        c.drawString(48,height-31,title)
        c.setStrokeColor(HexColor("#d3e2e9")); c.setLineWidth(0.5)
        c.line(48,height-39,width-48,height-39)
    c.setFont("CourseSans",FOOTER_FONT_SIZE); c.setFillColor(HexColor("#567284"))
    c.drawString(48,26,GITHUB_URL)
    c.drawRightString(width-48,26,f"第 {page} / {total} 页")
    c.setFont("CourseSans",6.1); c.setFillColor(HexColor("#6b7f8c"))
    c.drawString(48,14,f"{COPYRIGHT} · 内容 {CONTENT_LICENSE} · 代码 {CODE_LICENSE}")
    c.drawRightString(width-48,14,"保留来源、许可与引用")
    c.showPage(); c.save(); buffer.seek(0)
    return PdfReader(buffer).pages[0]

def add_project_link(writer,page,rect):
    writer.add_annotation(page,Link(rect=rect,url=GITHUB_URL,border=[0,0,0]))

def write_pdf_atomic(writer, output):
    output=Path(output)
    temporary=output.with_name(output.stem+".new.pdf")
    backup=output.with_name(output.stem+".old.pdf")
    writer.write(temporary)
    if backup.exists():
        backup.unlink()
    for attempt in range(20):
        try:
            if output.exists():
                output.rename(backup)
            temporary.replace(output)
            break
        except PermissionError:
            if attempt==19:
                raise
            time.sleep(0.5)
    if backup.exists():
        backup.unlink()

def main():
    manifest=Path(sys.argv[1])
    records=json.loads(manifest.read_text(encoding="utf-8"))
    for record in records:
        body=PdfReader(record["body"])
        writer=PdfWriter(); writer.append(cover(record)); writer.add_outline_item("封面",0)
        writer.append(body)
        total=len(writer.pages)
        for i,page in enumerate(writer.pages):
            width=float(page.mediabox.width); height=float(page.mediabox.height)
            page.merge_page(overlay(width,height,f"第 {record['number']} 章  {record['title']}",i+1,total,i==0))
            if i==0:
                add_project_link(writer,page,COVER_LINK_RECT)
            add_project_link(writer,page,FOOTER_LINK_RECT)
        writer.add_metadata({
            "/Title":f"第 {record['number']} 章：{record['title']}",
            "/Subject":f"超声波束合成学习课程 - 第 {record['number']} 章 {record['title']}",
            "/Keywords":"ultrasound beamforming, MATLAB, USTB, medical imaging, education",
            "/Creator":"Markdown + KaTeX + ReportLab",
            "/Producer":"Ultrasound Beamforming Learning PDF pipeline",
            "/Copyright":f"{COPYRIGHT}. Course content {CONTENT_LICENSE}; code {CODE_LICENSE}.",
            "/License":f"{CONTENT_LICENSE} (content); {CODE_LICENSE} (code)",
            "/Source":GITHUB_URL,
            "/ReleaseVersion":RELEASE_VERSION,
            "/ChapterID":record["id"],
        })
        output=Path(record["output"]); output.parent.mkdir(parents=True,exist_ok=True)
        write_pdf_atomic(writer,output)
        checked=PdfReader(output)
        page_texts=[page.extract_text() or "" for page in checked.pages]
        text="\n".join(page_texts)
        if len(checked.pages)<5 or "本章目录" not in text or "超声波束合成" not in text:
            raise ValueError(f"Incomplete PDF: {output}")
        if "\ufffd" in text: raise ValueError(f"Replacement glyph in {output}")
        if any(GITHUB_URL not in page_text for page_text in page_texts):
            raise ValueError(f"Missing project URL on a page: {output}")
        linked_pages=0
        for page in checked.pages:
            found=False
            for item in page.get("/Annots",[]):
                annotation=item.get_object()
                action=annotation.get("/A",{})
                if action.get("/S")=="/URI" and str(action.get("/URI"))==GITHUB_URL:
                    found=True; break
            linked_pages+=int(found)
        if linked_pages!=len(checked.pages):
            raise ValueError(f"Missing clickable project link on {len(checked.pages)-linked_pages} page(s): {output}")
        metadata=checked.metadata or {}
        if str(metadata.get("/Source") or metadata.get("Source"))!=GITHUB_URL:
            raise ValueError(f"Missing /Source metadata: {output}")
        if CONTENT_LICENSE not in str(metadata.get("/License") or metadata.get("License")):
            raise ValueError(f"Missing content license metadata: {output}")
        if CODE_LICENSE not in str(metadata.get("/License") or metadata.get("License")):
            raise ValueError(f"Missing code license metadata: {output}")
        record.update(
            pages=len(checked.pages),bytes=output.stat().st_size,sha256=sha256(output.read_bytes()).hexdigest(),
            github_url=GITHUB_URL,
            source_url=f"{GITHUB_URL}/blob/main/chapters/{record['id']}/README.md",
            content_license=CONTENT_LICENSE,
            code_license=CODE_LICENSE,
            copyright=COPYRIGHT,
            release_version=RELEASE_VERSION,
        )
        print(f"Created {output.name}: {record['pages']} pages; {record['bytes']:,} bytes")
    manifest.write_text(json.dumps(records,ensure_ascii=False,indent=2),encoding="utf-8")

if __name__=="__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    main()
