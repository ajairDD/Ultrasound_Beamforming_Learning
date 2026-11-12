function export_chapter5_figures(section)
%EXPORT_CHAPTER5_FIGURES Chinese lecture figures and reproducible evidence.
% 'all' (default), 'concepts' (8 toy figures), 'uff' (one TheGB run), or
% 'cached' (replot the saved SAME UFF output after presentation-only edits).
if nargin<1, section='all'; end
assert(any(strcmp(section,{'all','concepts','uff','cached'})),'Unknown section.');
demo_dir=fileparts(mfilename('fullpath'));
repo_dir=fileparts(fileparts(demo_dir));
out_dir=fullfile(repo_dir,'chapters','05_SLSC','figures');
cache_dir=fullfile(repo_dir,'work','pdfs','chapter5');
if ~exist(out_dir,'dir'), mkdir(out_dir); end
if ~exist(cache_dir,'dir'), mkdir(cache_dir); end
addpath(demo_dir,fileparts(demo_dir),fullfile(repo_dir,'matlab','01_DAS_Real_UFF'));
old_dir=pwd; cleanup_dir=onCleanup(@() cd(old_dir)); %#ok<NASGU>
cd(demo_dir);
old_visible=get(groot,'DefaultFigureVisible');
old_axes=get(groot,'DefaultAxesFontName');
old_text=get(groot,'DefaultTextFontName');
cleanup_style=onCleanup(@() set(groot,'DefaultFigureVisible',old_visible, ...
    'DefaultAxesFontName',old_axes,'DefaultTextFontName',old_text)); %#ok<NASGU>
set(groot,'DefaultFigureVisible','off', ...
    'DefaultAxesFontName','Microsoft YaHei','DefaultTextFontName','Microsoft YaHei');
log_path=fullfile(out_dir,['matlab_' section '_results.txt']);
fid=fopen(log_path,'w','n','UTF-8'); assert(fid>=0);
fprintf(fid,'MATLAB %s\n',version);
fprintf(fid,'Chapter 5: eight seeded algebra/statistics examples; no acoustic simulator.\n');
fprintf(fid,'UFF: TheGB frame 1, same FI delays/grid/aperture for DAS and SLSC.\n');
fprintf(fid,'n_z=768, z=5--45 mm, Rx F#=1.7, q=0.15 active Rx, max lag=12.\n');
fprintf(fid,'Real signed RF correlations, nominal axial kernel=1 lambda; span=(K-1)*dz.\n');
fclose(fid);
if any(strcmp(section,{'all','concepts'}))
    close all;
    text=evalc('concept_report=demo_slsc_building_blocks;');
    append_log(log_path,'demo_slsc_building_blocks',text);
    export_open(out_dir,'demo_slsc_building_blocks',8);
    save(fullfile(cache_dir,'concept_report.mat'),'concept_report');
end
if any(strcmp(section,{'all','uff','cached'}))
    assert(~isempty(which('uff.read_object')),'Add USTB before UFF export.');
    filename=fullfile(repo_dir,'data','L7_FI_TheGB.uff');
    close all;
    if strcmp(section,'cached')
        saved=load(fullfile(cache_dir,'uff_output.mat'),'out'); out=saved.out;
    else
        [text,out]=run_uff(fullfile(demo_dir,'compare_fi_das_vs_slsc.m'),filename);
        append_log(log_path,'compare_fi_das_vs_slsc',text);
        export_open(out_dir,'compare_fi_das_vs_slsc',2);
        save(fullfile(cache_dir,'uff_output.mat'),'out');
        close all;
    end
    text=evalc('diagnostic_report=inspect_slsc_output(out,filename);');
    append_log(log_path,'same_uff_diagnostics',text);
    export_open(out_dir,'uff_slsc_diagnostics',4);
    save(fullfile(cache_dir,'diagnostic_report.mat'),'diagnostic_report');
end
close all;
fprintf('Chapter 5 figures saved to %s\n',out_dir);
end

function [text,out]=run_uff(script_path,filename)
n_z=768; z_min=5e-3; z_max=45e-3; receive_f_number=1.7; %#ok<NASGU>
axial_kernel_lambda=1.0; lag_fraction=0.15; max_lag=12; %#ok<NASGU>
run_das_reference_check=true; %#ok<NASGU>
text=evalc('run(script_path)');
end

function export_open(out_dir,id,expected)
figs=findall(groot,'Type','figure');
assert(numel(figs)==expected,'Unexpected figure count for %s.',id);
[~,order]=sort([figs.Number]); figs=figs(order);
for k=1:numel(figs)
    drawnow;
    export_figure_zh_cn(figs(k),fullfile(out_dir,sprintf('%s_%02d.png',id,k)), ...
        'Resolution',150);
end
fprintf('Exported %d Chinese figures: %s.\n',numel(figs),id);
end

function append_log(path,id,text)
text=erase(text,char(8));
text=regexprep(text,'<(?:"[^"]*"|[^">])*>','');
lines=regexp(text,'\r?\n','split');
keep=cellfun(@(line) ~startsWith(line,'UFF: reading'),lines);
text=strjoin(lines(keep),newline);
fid=fopen(path,'a','n','UTF-8'); assert(fid>=0);
cleanup=onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid,'\n--- %s ---\n%s\n',id,text);
end
