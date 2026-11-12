"""Build internal review sheets and audit final PDF page boundaries."""
import argparse
import json
import subprocess
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont, ImageOps
from pypdf import PdfReader
import pdfplumber

ROOT = Path(__file__).resolve().parents[2]
WORK = ROOT / 'work/pdfs'
FONT = ImageFont.truetype('C:/Windows/Fonts/msyh.ttc', 20)


def sheets(files, directory, cell=(1000, 750)):
    directory.mkdir(parents=True, exist_ok=True)
    records=[]
    for start in range(0, len(files), 4):
        selected=files[start:start+4]
        canvas=Image.new('RGB', (cell[0]*2, (cell[1]+45)*2), '#e9eff4')
        draw=ImageDraw.Draw(canvas)
        for i, path in enumerate(selected):
            x=(i%2)*cell[0]; y=(i//2)*(cell[1]+45)
            with Image.open(path) as opened:
                picture=ImageOps.contain(opened.convert('RGB'), (cell[0]-12, cell[1]-12))
            canvas.paste(picture, (x+(cell[0]-picture.width)//2, y+(cell[1]-picture.height)//2))
            draw.text((x+8, y+cell[1]+4),path.name,font=FONT,fill='#123c61')
        target=directory/f'sheet-{start//4+1:02d}.jpg'
        canvas.save(target,quality=94)
        records.append({'sheet':str(target),'files':[str(p) for p in selected]})
    (directory/'index.json').write_text(json.dumps(records,ensure_ascii=False,indent=2),encoding='utf-8')
    return records


def figures():
    for chapter in sorted((ROOT/'chapters').iterdir()):
        files=sorted((chapter/'figures').glob('*.png'))
        if files:
            result=sheets(files,WORK/'review_figures'/chapter.name)
            print(f'{chapter.name}: {len(files)} figures, {len(result)} review sheets')


def pdfs():
    records=json.loads((WORK/'pdf_build_manifest.json').read_text(encoding='utf-8'))
    audit=[]
    for record in records:
        source=Path(record['output']); directory=WORK/'review_pages'/record['id']
        directory.mkdir(parents=True,exist_ok=True)
        subprocess.run(['pdftoppm','-r','110','-png',str(source),str(directory/'page')],check=True,stdout=subprocess.DEVNULL,stderr=subprocess.PIPE)
        checked=PdfReader(source)
        by_page={int(p.stem.split('-')[-1]):p for p in directory.glob('page-*.png')}
        rendered=[by_page[i+1] for i in range(len(checked.pages))]
        assert len(rendered)==len(checked.pages)
        pages=[]
        with pdfplumber.open(source) as pdf:
            for i,page in enumerate(pdf.pages):
                # KaTeX glyphs overlap intentionally; check page bounds instead.
                outside=[c for c in page.chars if c.get('text','').strip() and
                         (c['x0'] < -0.5 or c['x1'] > page.width+0.5 or
                          c['top'] < -0.5 or c['bottom'] > page.height+0.5)]
                text=page.extract_text() or ''
                assert not outside, f'Text outside page: {source.name}, page {i+1}'
                assert len(text.strip())>25, f'Unexpected blank page: {source.name}, {i+1}'
                pages.append({'page':i+1,'characters':len(page.chars),'images':len(page.images),
                              'text_outside_page':len(outside)})
        result=sheets(rendered,directory/'sheets',cell=(710,1005))
        audit.append({'file':source.name,'pages':len(rendered),'sheets':len(result),'page_audit':pages})
        print(f'{source.name}: rendered {len(rendered)} pages; no text outside pages')
    (WORK/'pdf_page_audit.json').write_text(json.dumps(audit,ensure_ascii=False,indent=2),encoding='utf-8')


def ocr():
    from collect_figure_text import remaining_words
    records=json.loads((WORK/'figure_ocr.json').read_text(encoding='utf-8-sig'))
    for record in records:
        words=sorted(set(remaining_words(record['text'])))
        if words:
            print(record['file']+': '+', '.join(words))


if __name__=='__main__':
    sys.stdout.reconfigure(encoding='utf-8')
    parser=argparse.ArgumentParser()
    parser.add_argument('mode',choices=['figures','pdfs','ocr'])
    args=parser.parse_args()
    {'figures':figures,'pdfs':pdfs,'ocr':ocr}[args.mode]()
