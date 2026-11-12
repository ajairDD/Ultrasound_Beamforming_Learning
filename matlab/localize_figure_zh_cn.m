function report = localize_figure_zh_cn(fig,map_file)
%LOCALIZE_FIGURE_ZH_CN Change visible labels without changing plot values.
% The JSON contains reviewed whole-label translations and ordered patterns.
if nargin<2
    repo_dir = fileparts(fileparts(mfilename('fullpath')));
    map_file = fullfile(repo_dir,'tools','pdf','figure_translations.json');
end
fid=fopen(map_file,'r'); assert(fid>=0,'Missing figure translation map.');
bytes=fread(fid,Inf,'*uint8').'; fclose(fid);
map=jsondecode(native2unicode(bytes,'UTF-8'));
% Font changes can otherwise change automatic axis limits / nice ticks.
limits={};
axes_handles=findall(fig,'Type','axes');
for a=1:numel(axes_handles)
    names={'XAxis','YAxis','ZAxis'};
    for j=1:numel(names)
        rulers=get(axes_handles(a),names{j});
        for k=1:numel(rulers)
            if isprop(rulers(k),'Limits')
                limits{end+1}={rulers(k),get(rulers(k),'Limits')}; %#ok<AGROW>
            end
        end
    end
end
objects=figure_label_objects(fig);
properties={'String','Label','XTickLabel','YTickLabel','ZTickLabel','DisplayName','Name'};
report=struct('changed',0,'labels',{{}});
for i=1:numel(objects)
    obj=objects{i};
    if isprop(obj,'FontName'), set(obj,'FontName','Microsoft YaHei'); end
    if isprop(obj,'FontSize')
        old_size=get(obj,'FontSize');
        if isnumeric(old_size) && isscalar(old_size)
            set(obj,'FontSize',max(old_size,12.5));
        end
    end
    for j=1:numel(properties)
        property=properties{j};
        if ~isprop(obj,property), continue; end
        % Leave automatically generated numeric tick labels automatic.
        if endsWith(property,'TickLabel') && isprop(obj,[property 'Mode']) ...
                && strcmp(get(obj,[property 'Mode']),'auto')
            continue;
        end
        value=get(obj,property);
        [translated,labels]=translate_value(value,map);
        report.labels=[report.labels labels]; %#ok<AGROW>
        if ~isequal(value,translated)
            set(obj,property,translated);
            report.changed=report.changed+1;
        end
    end
end
report.labels=unique(report.labels,'stable');
% Chinese labels need their own margins; do not retain a cramped inner box.
layouts=findall(fig,'Type','tiledlayout');
for k=1:numel(layouts)
    layouts(k).TileSpacing='loose';
    layouts(k).Padding='loose';
end
for k=1:numel(axes_handles)
    ax=axes_handles(k);
    if ~isa(ax.Parent,'matlab.graphics.layout.TiledChartLayout')
        outside=ax.OuterPosition;
        ax.PositionConstraint='outerposition';
        ax.OuterPosition=outside;
    end
end
% Legacy subplot grids can have overlapping OuterPosition rectangles.
% Give regular dense grids disjoint cells, with space for the total title.
if isempty(layouts) && numel(axes_handles)>=6
    positions=reshape([axes_handles.Position],4,[]).';
    centers=positions(:,1:2)+positions(:,3:4)/2;
    [columns,~,column]=unique(round(centers(:,1)*100)/100);
    [rows,~,row]=unique(round(centers(:,2)*100)/100);
    if numel(columns)*numel(rows)==numel(axes_handles)
        x_edges=linspace(0.005,0.995,numel(columns)+1);
        y_edges=linspace(0.015,0.925,numel(rows)+1);
        for k=1:numel(axes_handles)
            axes_handles(k).OuterPosition=[x_edges(column(k)),y_edges(row(k)), ...
                diff(x_edges(column(k):column(k)+1)), ...
                diff(y_edges(row(k):row(k)+1))];
        end
    end
end
drawnow;
for k=1:numel(limits)
    set(limits{k}{1},'Limits',limits{k}{2});
end
drawnow;
end

function [result,labels]=translate_value(value,map)
result=value; labels={};
if ischar(value)
    if size(value,1)>1
        parts=cellstr(value);
        for k=1:numel(parts), parts{k}=translate_text(parts{k},map); end
        result=char(parts); labels=parts.';
    else
        result=translate_text(value,map); labels={result};
    end
elseif isstring(value)
    parts=cellstr(value);
    for k=1:numel(parts), parts{k}=translate_text(parts{k},map); end
    result=string(parts); labels=parts(:).';
elseif iscell(value) && all(cellfun(@ischar,value(:)))
    for k=1:numel(value), result{k}=translate_text(value{k},map); end
    labels=result(:).';
end
end

function text=translate_text(text,map)
if isempty(text), return; end
for k=1:numel(map.exact)
    if strcmp(text,map.exact(k).source)
        text=map.exact(k).target; return;
    end
end
if isfield(map,'patterns')
    for k=1:numel(map.patterns)
        text=regexprep(text,map.patterns(k).source,map.patterns(k).target);
    end
end
end
