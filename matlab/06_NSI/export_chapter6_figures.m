function export_chapter6_figures(section)
%EXPORT_CHAPTER6_FIGURES Seventeen reproducible Chinese MATLAB figures.
% all: fresh concepts, point-target and 3 full-FOV reference-checked runs.
% concepts: 8 no-UFF figures. point/full: run only that existing experiment.
% cached: export saved point/full FIGs and recombine the same D,Z at 0.8.
if nargin<1, section='all'; end
assert(any(strcmp(section,{'all','concepts','point','full','cached'})));
demo_dir=fileparts(mfilename('fullpath')); repo_dir=fileparts(fileparts(demo_dir));
out_dir=fullfile(repo_dir,'chapters','06_NSI','figures');
cache_dir=fullfile(repo_dir,'work','pdfs','chapter6');
if ~exist(out_dir,'dir'), mkdir(out_dir); end
if ~exist(cache_dir,'dir'), mkdir(cache_dir); end
addpath(demo_dir,fileparts(demo_dir),fullfile(repo_dir,'matlab','01_DAS_Real_UFF'));
old_dir=pwd; cleanup_dir=onCleanup(@() cd(old_dir)); %#ok<NASGU>
cd(demo_dir);
old_visible=get(groot,'DefaultFigureVisible');
old_axes=get(groot,'DefaultAxesFontName'); old_text=get(groot,'DefaultTextFontName');
cleanup_style=onCleanup(@() set(groot,'DefaultFigureVisible',old_visible, ...
    'DefaultAxesFontName',old_axes,'DefaultTextFontName',old_text)); %#ok<NASGU>
set(groot,'DefaultFigureVisible','off','DefaultAxesFontName','Microsoft YaHei', ...
    'DefaultTextFontName','Microsoft YaHei');
log_path=fullfile(out_dir,['matlab_' section '_results.txt']);
fid=fopen(log_path,'w','n','UTF-8'); assert(fid>=0);
fprintf(fid,'MATLAB %s\n',version);
fprintf(fid,'Chapter 6: NSI lecture figures; independent images remain local/ignored.\n');
fprintf(fid,'Point: [Nz Nx]=[181 281], dx=dz=0.025 mm, all focused Tx, delta=0.2.\n');
fprintf(fid,'Full: 3 acquisitions, [Nz Nx]=[513 385], 5--45 mm, full Tx span, all Tx.\n');
fprintf(fid,'Both existing experiments enable Chapter-1 complex RTB-DAS regression.\n');
fprintf(fid,'Delta=0.8 views reuse exactly the same compounded complex D,Z branches.\n');
fclose(fid);
if any(strcmp(section,{'all','concepts'}))
    close all;
    text=evalc('concept_report=demo_nsi_building_blocks;');
    append_log(log_path,'no_UFF_concepts',text);
    export_open(out_dir,'demo_nsi_building_blocks',8);
    save(fullfile(cache_dir,'concept_report.mat'),'concept_report');
end
if any(strcmp(section,{'all','point'}))
    assert(~isempty(which('uff.read_object')),'Add USTB before UFF export.');
    close all;
    [text,point]=run_point(fullfile(demo_dir,'compare_rtb_das_vs_nsi.m'));
    append_log(log_path,'point_target',text);
    save(fullfile(cache_dir,'point_output.mat'),'-struct','point');
    savefig(figure(1),fullfile(cache_dir,'point_01.fig'));
    savefig(figure(2),fullfile(cache_dir,'point_02.fig'));
    export_open(out_dir,'compare_rtb_das_vs_nsi',2);
end
if any(strcmp(section,{'all','full'}))
    assert(~isempty(which('uff.read_object')),'Add USTB before UFF export.');
    close all;
    [text,full]=run_full(fullfile(demo_dir,'compare_full_fov_rtb_das_vs_nsi.m'));
    append_log(log_path,'full_FOV',text);
    save(fullfile(cache_dir,'full_outputs.mat'),'-struct','full');
    savefig(figure(1),fullfile(cache_dir,'full_02_01.fig'));
    savefig(figure(2),fullfile(cache_dir,'full_02_02.fig'));
    export_open(out_dir,'full_fov_delta02',2);
end
if any(strcmp(section,{'all','cached'}))
    point=load(fullfile(cache_dir,'point_output.mat'));
    full=load(fullfile(cache_dir,'full_outputs.mat'));
    assert(point.relative_err<1e-10);
    errors=cellfun(@(entry) entry.reference_complex_error,full.reports);
    assert(all(isfinite(errors) & errors<1e-10),'Full-FOV references not checked.');
    if strcmp(section,'cached')
        for k=1:2
            close all; fig=openfig(fullfile(cache_dir,sprintf('point_%02d.fig',k)),'invisible');
            export_one(fig,out_dir,sprintf('compare_rtb_das_vs_nsi_%02d.png',k));
            close all; fig=openfig(fullfile(cache_dir,sprintf('full_02_%02d.fig',k)),'invisible');
            export_one(fig,out_dir,sprintf('full_fov_delta02_%02d.png',k));
        end
    end
    close all;
    text=evalc('diagnostic_report=inspect_nsi_outputs(point.out,full.results);');
    append_log(log_path,'same_D_Z_diagnostics',text);
    figs=ordered_figures(5);
    for k=1:2
        export_one(figs(k),out_dir,sprintf('full_fov_delta08_%02d.png',k));
    end
    for k=3:5
        export_one(figs(k),out_dir,sprintf('nsi_diagnostics_%02d.png',k-2));
    end
    diagnostic_report.point_reference_complex_error=point.relative_err;
    diagnostic_report.full_reference_complex_errors=errors;
    save(fullfile(cache_dir,'diagnostic_report.mat'),'diagnostic_report');
    fid=fopen(fullfile(cache_dir,'verification.json'),'w','n','UTF-8'); assert(fid>=0);
    fprintf(fid,'%s',jsonencode(diagnostic_report)); fclose(fid);
end
close all;
fprintf('Chapter 6 figures completed: %s\n',out_dir);
end

function [text,saved]=run_point(script_path)
run_rtb_reference_check=true; %#ok<NASGU>
text=evalc('run(script_path)');
saved=struct('out',out,'relative_err',relative_err, ...
    'width_das',width_das,'width_nsi',width_nsi,'width20_das',width20_das, ...
    'width20_nsi',width20_nsi,'runtime',runtime);
end

function [text,saved]=run_full(script_path)
dataset_indices=[1 2 3]; n_x=385; n_z=513; wave_stride=1; %#ok<NASGU>
dc_offset=0.2; run_rtb_reference_check=true; %#ok<NASGU>
text=evalc('run(script_path)');
saved=struct('results',{results},'reports',{reports});
end

function figs=ordered_figures(expected)
figs=findall(groot,'Type','figure'); assert(numel(figs)==expected);
[~,order]=sort([figs.Number]); figs=figs(order);
end

function export_open(out_dir,id,expected)
figs=ordered_figures(expected);
for k=1:numel(figs)
    export_one(figs(k),out_dir,sprintf('%s_%02d.png',id,k));
end
end

function export_one(fig,out_dir,name)
drawnow; export_figure_zh_cn(fig,fullfile(out_dir,name),'Resolution',150);
fprintf('Exported %s\n',name);
end

function append_log(path,id,text)
text=erase(text,char(8));
% Strip actual console hyperlink/emphasis tags, never ordinary < / >= text.
text=regexprep(text,'</?(?:a|strong|em|b|i|span)(?:[ \t]+[^<>\r\n]*)?>','');
lines=regexp(text,'\r?\n','split');
keep=cellfun(@(line) ~startsWith(line,'UFF: reading'),lines);
fid=fopen(path,'a','n','UTF-8'); assert(fid>=0);
fprintf(fid,'\n--- %s ---\n%s\n',id,strjoin(lines(keep),newline)); fclose(fid);
end
