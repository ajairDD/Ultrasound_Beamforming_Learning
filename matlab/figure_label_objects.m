function [objects,labels]=figure_label_objects(fig)
%FIGURE_LABEL_OBJECTS Include layout/ruler titles outside ordinary Children.
objects=num2cell(findall(fig));
properties={'Title','Subtitle','XLabel','YLabel','ZLabel','Label'};
index=1;
while index<=numel(objects)
    obj=objects{index};
    for j=1:numel(properties)
        if ~isprop(obj,properties{j}), continue; end
        value=get(obj,properties{j});
        if ~isobject(value), continue; end
        for k=1:numel(value)
            if ~isprop(value(k),'String'), continue; end
            present=cellfun(@(x) isequal(x,value(k)),objects);
            if ~any(present), objects{end+1}=value(k); end %#ok<AGROW>
        end
    end
    index=index+1;
end
labels={};
if nargout<2, return; end
names={'String','Label','XTickLabel','YTickLabel','ZTickLabel','DisplayName','Name'};
for i=1:numel(objects)
    for j=1:numel(names)
        if ~isprop(objects{i},names{j}), continue; end
        value=get(objects{i},names{j});
        if ischar(value), value=cellstr(value);
        elseif isstring(value), value=cellstr(value);
        elseif ~iscell(value), continue;
        end
        for k=1:numel(value)
            if ischar(value{k}) && ~isempty(strtrim(value{k}))
                labels{end+1}=value{k}; %#ok<AGROW>
            end
        end
    end
end
labels=unique(labels,'stable');
end
