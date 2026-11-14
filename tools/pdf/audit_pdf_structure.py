"""Check local PDF navigation, embedded Chinese fonts and delivery counts."""
import json
import re
import sys
from hashlib import sha256
from pathlib import Path
from pypdf import PdfReader

ROOT=Path(__file__).resolve().parents[2]
GITHUB_URL='https://github.com/ajairDD/Ultrasound_Beamforming_Learning'
CONTENT_LICENSE='CC BY-NC-SA 4.0'
CODE_LICENSE='AGPL-3.0'
COPYRIGHT='© 2026 Ultrasound Beamforming Learning contributors'


def audit():
    records=json.loads((ROOT/'work/pdfs/pdf_build_manifest.json').read_text(encoding='utf-8'))
    result=[]
    for record in records:
        path=Path(record['output']); reader=PdfReader(path)
        page_refs={p.indirect_reference.idnum for p in reader.pages}
        named=reader.named_destinations
        internal=external=github_links=github_pages=0
        chinese_fonts={}
        page_formats={}
        page_texts=[]

        def check_destination(destination):
            if isinstance(destination,str):
                assert destination in named, f'Unknown PDF destination: {destination}'
                destination=named[destination].dest_array
            assert destination[0].idnum in page_refs, f'Invalid PDF page destination: {path.name}'

        for page in reader.pages:
            page_text=page.extract_text() or ''
            page_texts.append(page_text)
            assert GITHUB_URL in page_text, f'Missing project URL on a page: {path.name}'
            width,height=float(page.mediabox.width),float(page.mediabox.height)
            long=max(width,height)
            paper='A3' if long>1000 else 'A4'
            orientation='横向' if width>height else '纵向'
            page_formats[paper+orientation]=page_formats.get(paper+orientation,0)+1
            page_has_github_link=False
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
                    if str(action.get('/URI'))==GITHUB_URL:
                        github_links+=1
                        page_has_github_link=True
            github_pages+=int(page_has_github_link)
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
        text='\n'.join(page_texts)
        assert '**' not in text, f'Unparsed Markdown emphasis in {path.name}'
        assert chinese_fonts and internal>0
        assert github_pages==len(reader.pages), f'Missing clickable project link on {len(reader.pages)-github_pages} page(s): {path.name}'
        assert set(page_formats)=={'A4纵向'}, f'Non-A4-portrait page detected: {path.name} {page_formats}'
        assert len(reader.pages)==record['pages']
        assert sha256(path.read_bytes()).hexdigest()==record['sha256']
        assert len(re.findall(r'[\u4e00-\u9fff]',text))>500
        metadata=reader.metadata or {}
        assert str(metadata.get('/Source') or metadata.get('Source'))==GITHUB_URL, f'Missing /Source metadata: {path.name}'
        license_text=str(metadata.get('/License') or metadata.get('License'))
        assert CONTENT_LICENSE in license_text and CODE_LICENSE in license_text, f'Incomplete /License metadata: {path.name}'
        assert COPYRIGHT in str(metadata.get('/Copyright') or metadata.get('Copyright')), f'Missing /Copyright metadata: {path.name}'
        assert str(metadata.get('/ReleaseVersion') or metadata.get('ReleaseVersion')), f'Missing /ReleaseVersion metadata: {path.name}'
        result.append({key:record[key] for key in ['id','file','pages','images','bytes','sha256']}|
                      {'internal_links':internal,'external_links':external,'github_links':github_links,
                       'embedded_chinese_fonts':list(chinese_fonts),'unparsed_emphasis':0,
                       'page_formats':page_formats,'source_sha256':record.get('source_sha256'),
                       'github_url':GITHUB_URL,'source_url':record.get('source_url'),
                       'content_license':CONTENT_LICENSE,'code_license':CODE_LICENSE,
                       'copyright':COPYRIGHT,'release_version':record.get('release_version')})
        print(f"{path.name}: {internal} internal links; {github_links} project links; A4 portrait; metadata OK")
    assert result and len({r['id'] for r in result})==len(result)
    destination=ROOT/'output/pdf/manifest.json'
    existing=json.loads(destination.read_text(encoding='utf-8')) if destination.exists() else []
    merged={r['id']:r for r in existing}; merged.update({r['id']:r for r in result})
    destination.write_text(json.dumps(sorted(merged.values(),key=lambda r:r['id']),ensure_ascii=False,indent=2)+'\n',encoding='utf-8')


if __name__=='__main__':
    sys.stdout.reconfigure(encoding='utf-8')
    audit()
