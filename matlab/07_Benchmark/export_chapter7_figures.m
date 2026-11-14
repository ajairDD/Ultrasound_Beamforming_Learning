function export_chapter7_figures(mode)
%EXPORT_CHAPTER7_FIGURES 7 no-UFF lessons + 7 real-data lecture figures.
% all: fresh benchmark; cached: use FI/RTB_results.mat; concepts: no UFF.
if nargin<1,mode='all';end
assert(ismember(mode,{'all','cached','concepts'}));
here=fileparts(mfilename('fullpath')); root=fileparts(fileparts(here));
dest=fullfile(root,'chapters','07_Benchmark','figures');
cache=fullfile(root,'work','pdfs','chapter7_8');
if ~isfolder(dest),mkdir(dest);end
if ~isfolder(cache),mkdir(cache);end
addpath(here,fullfile(root,'matlab'));
old=pwd; old_visible=get(groot,'DefaultFigureVisible');
cleanup=onCleanup(@() restore(old,old_visible)); %#ok<NASGU>
cd(here); set(groot,'DefaultFigureVisible','off'); close all;
log=fullfile(dest,'matlab_lecture_results.txt');
fid=fopen(log,'w','n','UTF-8'); assert(fid>=0);
fprintf(fid,'MATLAB %s; mode=%s; rng=7.\n',version,mode);
fprintf(fid,'Synthetic lessons are not acoustic simulations or real lesions.\n'); fclose(fid);
text=evalc('concepts=demo_benchmark_building_blocks;');
append_log(log,text); export_open(dest,'demo_benchmark_building_blocks',7);
save(fullfile(cache,'chapter7_concepts.mat'),'concepts'); close all;
if strcmp(mode,'concepts'),return;end
if strcmp(mode,'all')
    assert(~isempty(which('uff.read_object')),'Add USTB before fresh benchmark.');
    text=run_fresh(fullfile(here,'run_chapter7_benchmark.m'));
    append_log(log,text);
    close all;
end
folder=fullfile(root,'output','benchmark','ch07');
fi=load(fullfile(folder,'FI_results.mat')); rtb=load(fullfile(folder,'RTB_results.mat'));
render_saved_boards(fi,rtb);
export_named(figure(1),dest,'benchmark_fi_images.png');
export_named(figure(2),dest,'benchmark_rtb_images.png'); close all;
text=evalc('report=inspect_benchmark_outputs(fi,rtb);'); append_log(log,text);
export_open(dest,'benchmark_diagnostics',5); close all;
fid=fopen(fullfile(cache,'chapter7_verification.json'),'w','n','UTF-8'); assert(fid>=0);
fprintf(fid,'%s\n',jsonencode(report)); fclose(fid);
fprintf('CHAPTER7_FIGURES_COMPLETE: 14 Chinese MATLAB PNGs.\n');
end

function render_saved_boards(fi,rtb)
% Replot numeric caches: cached mode does not depend on old PNG/FIG files.
figure('Color','w','Position',[50 50 1600 850], ...
    'DefaultAxesFontName','Microsoft YaHei','DefaultTextFontName','Microsoft YaHei');
for k=1:6
    subplot(3,2,k); value=fi.imgs{k};
    if k==6
        imagesc(fi.x*1e3,fi.z*1e3,value); caxis([0 1]); title('SLSC：线性相干性');
    else
        imagesc(fi.x*1e3,fi.z*1e3,20*log10(value/(max(value(:))+eps)+eps));
        caxis([-60 0]); title(char(fi.labels(k))+"：各自峰值参考");
    end
    axis image; colormap(gca,gray); colorbar;
    xlabel('横向 x（mm）'); ylabel('深度 z（mm）');
end
sgtitle({'轨道 A：相同 conventional FI 条件与原始扫描线', ...
    '包络图：各自峰值 dB；SLSC：线性相干性'});
figure('Color','w','Position',[50 50 1300 900], ...
    'DefaultAxesFontName','Microsoft YaHei','DefaultTextFontName','Microsoft YaHei');
peak=max(rtb.imgs{1}(:));
for k=1:4
    subplot(2,2,k);
    imagesc(rtb.x*1e3,rtb.z*1e3,20*log10(rtb.imgs{k}/(peak+eps)+eps));
    axis image; caxis([-60 0]); colormap(gca,gray); colorbar;
    xlabel('横向 x（mm）'); ylabel('深度 z（mm）');
    title(strrep(char(rtb.labels(k)),'c=','δ=')+"：共同 DAS 参考");
end
sgtitle({'轨道 B：相同密集 RTB 几何与 Tx 合成', ...
    '两种 NSI 偏置复用同一次 D、Z；同一 DAS 参考'});
end

function text=run_fresh(script_path)
benchmark_mode='both'; %#ok<NASGU>
save_reports=true; %#ok<NASGU>
text=evalc('run(script_path)');
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
