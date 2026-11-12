function reexport_chinese_figures(chapter,mode)
%REEXPORT_CHINESE_FIGURES Relabel captured FIGs without rerunning algorithms.
% Original FIGs are captured by each chapter's normal export entry point.
if nargin<1, chapter='all'; end
if nargin<2, mode='render'; end
assert(any(strcmp(mode,{'render','inventory'})),'Unknown mode.');
repo=fileparts(fileparts(mfilename('fullpath')));
cache=fullfile(repo,'work','pdfs','matlab_figures');
files=dir(fullfile(cache,'**','*.fig'));
if ~strcmp(chapter,'all')
    files=files(contains({files.folder},[filesep chapter filesep]));
end
assert(~isempty(files),'No captured figures found. Run chapter exporters first.');
records=cell(1,numel(files));
for k=1:numel(files)
    source=fullfile(files(k).folder,files(k).name);
    relative=source(numel(cache)+2:end);
    output=fullfile(repo,'chapters',relative);
    output=[output(1:end-4) '.png'];
    fig=openfig(source,'invisible');
    [~,original_labels]=figure_label_objects(fig);
    text_path=[source(1:end-4) '.texts.json'];
    fid=fopen(text_path,'w','n','UTF-8'); assert(fid>=0);
    fprintf(fid,'%s',jsonencode(original_labels)); fclose(fid);
    if strcmp(mode,'inventory'), close(fig); continue; end
    values=capture_numeric_plot_data(fig);
    report=localize_figure_zh_cn(fig);
    verify_numeric_plot_data(values);
    exportgraphics(fig,output,'Resolution',150);
    close(fig);
    records{k}=struct('figure',strrep(relative,filesep,'/'), ...
        'numeric_data_and_limits_unchanged',true, ...
        'changed_text_properties',report.changed,'labels',{report.labels});
    fprintf('Chinese figure %d/%d: %s\n',k,numel(files),relative);
end
if strcmp(mode,'inventory')
    fprintf('Inventoried all text, including layout titles, in %d figures.\n',numel(files));
    return;
end
fid=fopen(fullfile(repo,'work','pdfs',['figure_translation_audit_' chapter '.json']), ...
    'w','n','UTF-8');
assert(fid>=0); fprintf(fid,'%s',jsonencode(records)); fclose(fid);
fprintf('PASS: %d figures; numeric plot arrays, axis limits and scales unchanged.\n',numel(files));
end

function records=capture_numeric_plot_data(fig)
records={};
axes_handles=findall(fig,'Type','axes');
for a=1:numel(axes_handles)
    ruler_names={'XAxis','YAxis','ZAxis'};
    for j=1:numel(ruler_names)
        rulers=get(axes_handles(a),ruler_names{j});
        for k=1:numel(rulers)
            if isprop(rulers(k),'Limits')
                records{end+1}=struct('object',rulers(k),'property','Limits', ...
                    'value',get(rulers(k),'Limits')); %#ok<AGROW>
            end
        end
    end
    objects=findall(axes_handles(a));
    for i=1:numel(objects)
        obj=objects(i);
        if strcmp(get(obj,'Type'),'axes')
            names={'XLim','YLim','ZLim','CLim','XScale','YScale','ZScale','XDir','YDir'};
        else
            names={'XData','YData','ZData','CData','SizeData','Data','BinEdges','Values'};
        end
        for j=1:numel(names)
            if ~isprop(obj,names{j}), continue; end
            value=get(obj,names{j});
            if isnumeric(value)||islogical(value)||ischar(value)
                records{end+1}=struct('object',obj,'property',names{j},'value',value); %#ok<AGROW>
            end
        end
    end
end
end

function verify_numeric_plot_data(records)
for i=1:numel(records)
    r=records{i};
    assert(isvalid(r.object) && isequaln(get(r.object,r.property),r.value), ...
        'Translation altered numeric plot data or a scientific axis property: %s',r.property);
end
end
