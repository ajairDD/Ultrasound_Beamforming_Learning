"""Check local PDF navigation, embedded Chinese fonts and delivery counts."""
import json
import re
import sys
from hashlib import sha256
from pathlib import Path
from pypdf import PdfReader

ROOT=Path(__file__).resolve().parents[2]


def audit():
    records=json.loads((ROOT/'work/pdfs/pdf_build_manifest.json').read_text(encoding='utf-8'))
    result=[]
    for record in records:
        path=Path(record['output']); reader=PdfReader(path)
        page_refs={p.indirect_reference.idnum for p in reader.pages}
        named=reader.named_destinations
        internal=external=0
        chinese_fonts={}
        page_formats={}

        def check_destination(destination):
            if isinstance(destination,str):
                assert destination in named, f'Unknown PDF destination: {destination}'
                destination=named[destination].dest_array
            assert destination[0].idnum in page_refs, f'Invalid PDF page destination: {path.name}'

        for page in reader.pages:
            width,height=float(page.mediabox.width),float(page.mediabox.height)
            long=max(width,height)
            paper='A3' if long>1000 else 'A4'
            orientation='横向' if width>height else '纵向'
            page_formats[paper+orientation]=page_formats.get(paper+orientation,0)+1
            for item in page.get('/Annots',[]):
                annotation=item.get_object()
                if annotation.get('/Subtype')!='/Link': continue
                action=annotation.get('/A',{})
                if '/Dest' in annotation:
                    check_destination(annotation['/Dest']); internal+=1
                elif action.get('/S')=='/GoTo':
                    check_destination(action['/D']); internal+=1
                elif action.get('/S')=='/URI':
                    external+=1
            fonts=page.get('/Resources',{}).get('/Font',{})
            for reference in fonts.values():
                font=reference.get_object(); name=str(font.get('/BaseFont',''))
                if not any(word in name.lower() for word in ['yahei','dengxian']): continue
                if font.get('/Subtype')=='/Type0': font=font['/DescendantFonts'][0].get_object()
                descriptor=font.get('/FontDescriptor',{}).get_object()
                embedded=any(key in descriptor for key in ['/FontFile','/FontFile2','/FontFile3'])
                assert embedded, f'Chinese font is not embedded: {name}'
                assert reference.get_object().get('/ToUnicode'), f'Missing Chinese text mapping: {name}'
                chinese_fonts[name]=embedded
        text='\n'.join(page.extract_text() or '' for page in reader.pages)
        assert '**' not in text, f'Unparsed Markdown emphasis in {path.name}'
        assert chinese_fonts and internal>0
        assert len(reader.pages)==record['pages']
        assert sha256(path.read_bytes()).hexdigest()==record['sha256']
        assert len(re.findall(r'[\u4e00-\u9fff]',text))>500
        result.append({key:record[key] for key in ['id','file','pages','images','bytes','sha256']}|
                      {'internal_links':internal,'external_links':external,
                       'embedded_chinese_fonts':list(chinese_fonts),'unparsed_emphasis':0,
                       'page_formats':page_formats,'source_sha256':record.get('source_sha256')})
        print(f"{path.name}: {internal} internal links; Chinese fonts embedded; no raw emphasis markers")
    assert result and len({r['id'] for r in result})==len(result)
    destination=ROOT/'output/pdf/manifest.json'
    existing=json.loads(destination.read_text(encoding='utf-8')) if destination.exists() else []
    merged={r['id']:r for r in existing}; merged.update({r['id']:r for r in result})
    destination.write_text(json.dumps(sorted(merged.values(),key=lambda r:r['id']),ensure_ascii=False,indent=2)+'\n',encoding='utf-8')


if __name__=='__main__':
    sys.stdout.reconfigure(encoding='utf-8')
    audit()
