function export_chapter8_figures(mode)
%EXPORT_CHAPTER8_FIGURES 7 no-UFF lessons + 6 real-data lecture figures.
% all: fresh integration/regression. cached: saved results. concepts: no UFF.
if nargin<1,mode='all';end
assert(ismember(mode,{'all','cached','concepts'}));
here=fileparts(mfilename('fullpath')); root=fileparts(fileparts(here));
dest=fullfile(root,'chapters','08_RTB_Comparison','figures');
cache=fullfile(root,'work','pdfs','chapter7_8');
if ~isfolder(dest),mkdir(dest);end
if ~isfolder(cache),mkdir(cache);end
addpath(here,fullfile(root,'matlab'),fullfile(root,'matlab','RTB_Universal'), ...
    fullfile(root,'matlab','01_DAS_Real_UFF'));
old=pwd; visible=get(groot,'DefaultFigureVisible');
cleanup=onCleanup(@() restore(old,visible)); %#ok<NASGU>
set(groot,'DefaultFigureVisible','off'); close all;
log=fullfile(dest,'matlab_lecture_results.txt');
fid=fopen(log,'w','n','UTF-8'); assert(fid>=0);
fprintf(fid,'MATLAB %s; mode=%s; rng=8.\n',version,mode); fclose(fid);
text=evalc('concepts=demo_rtb_method_building_blocks;');
append_log(log,text); export_open(dest,'demo_rtb_method_building_blocks',7);
save(fullfile(cache,'chapter8_concepts.mat'),'concepts'); close all;
if strcmp(mode,'concepts'),return;end
if strcmp(mode,'all')
    assert(~isempty(which('uff.read_object')),'Add USTB before a fresh UFF run.');
    cd(fullfile(root,'matlab','RTB_Universal'));
    text=evalc('test_rtb_standard_interface; relative_error=test_rtb_universal_vs_chapter1;');
    append_log(log,text); assert(relative_error<1e-10);
    text=evalc('out=run_chapter8_rtb_comparison;'); append_log(log,text); close all;
else
    file=fullfile(root,'output','benchmark','ch08','RTB_seven_methods_results.mat');
    saved=load(file,'image_results'); out=saved.image_results;
end
f=rtb_show_methods(out,'own'); export_named(f,dest,'rtb_seven_methods_own.png'); close(f);
f=rtb_show_methods(out,'common'); export_named(f,dest,'rtb_seven_methods_common.png'); close(f);
text=evalc('report=inspect_rtb_comparison_outputs(out);'); append_log(log,text);
export_open(dest,'rtb_diagnostics',4); close all;
fid=fopen(fullfile(cache,'chapter8_verification.json'),'w','n','UTF-8'); assert(fid>=0);
fprintf(fid,'%s\n',jsonencode(report)); fclose(fid);
fprintf('CHAPTER8_FIGURES_COMPLETE: 13 Chinese MATLAB PNGs.\n');
end

function export_open(dest,id,expected)
figs=findall(groot,'Type','figure'); assert(numel(figs)==expected);
[~,order]=sort([figs.Number]); figs=figs(order);
for k=1:numel(figs),export_named(figs(k),dest,sprintf('%s_%02d.png',id,k));end
end

function export_named(fig,dest,name)
% R2021b image-aspect layouts can overlap their total and panel titles.
% Reserve a separate figure heading band before font localization/export.
layouts=findall(fig,'-isa','matlab.graphics.layout.TiledChartLayout');
for k=1:numel(layouts)
    heading=layouts(k).Title.String;
    if ~isempty(heading)
        layouts(k).Title.String='';
        layouts(k).Units='normalized';
        layouts(k).OuterPosition=[0 0.025 1 0.85];
        annotation(fig,'textbox',[0.02 0.92 0.96 0.075], ...
            'String',heading,'HorizontalAlignment','center', ...
            'VerticalAlignment','middle','LineStyle','none', ...
            'Interpreter','none','FontName','Microsoft YaHei','FontSize',12.5);
    end
end
drawnow; export_figure_zh_cn(fig,fullfile(dest,name),'Resolution',150);
fprintf('Exported %s\n',name);
end

function append_log(path,text)
text=erase(text,char(8));
text=regexprep(text,'</?(?:a|strong|em|b|i|span)(?:[ \t]+[^<>\r\n]*)?>','');
lines=regexp(text,'\r?\n','split'); lines=lines(~startsWith(lines,'UFF:'));
fid=fopen(path,'a','n','UTF-8'); assert(fid>=0);
fprintf(fid,'%s\n',strjoin(lines,newline)); fclose(fid);
end

function restore(folder,visible)
cd(folder); set(groot,'DefaultFigureVisible',visible);
end
