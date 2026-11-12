function export_figure_zh_cn(fig,filename,varargin)
%EXPORT_FIGURE_ZH_CN Export lecture figures with Chinese visible labels.
% Capture editable FIGs so label-only revisions never recompute the data.
% The numeric plot data, limits, and color normalization remain unchanged.
repo_dir = fileparts(fileparts(mfilename('fullpath')));
chapter_marker = [filesep 'chapters' filesep];
normalized = strrep(filename,'/',filesep);
% Some legacy exporters use '..' in output paths: resolve them first.
file_object = java.io.File(normalized);
resolved = char(file_object.getCanonicalPath());
start = strfind(resolved,chapter_marker);
assert(~isempty(start),'Expected a chapter figure path.');
relative = resolved(start(end)+numel(chapter_marker):end);
[relative_dir,base] = fileparts(relative);
cache_dir = fullfile(repo_dir,'work','pdfs','matlab_figures',relative_dir);
if ~exist(cache_dir,'dir'), mkdir(cache_dir); end
savefig(fig,fullfile(cache_dir,[base '.fig']));
labels = figure_text(fig);
fid = fopen(fullfile(cache_dir,[base '.texts.json']),'w','n','UTF-8');
assert(fid>=0,'Cannot write figure text inventory.');
fprintf(fid,'%s',jsonencode(labels)); fclose(fid);
map_file = fullfile(repo_dir,'tools','pdf','figure_translations.json');
if exist(map_file,'file')
    localize_figure_zh_cn(fig,map_file);
end
drawnow;
exportgraphics(fig,filename,varargin{:});
end

function labels = figure_text(fig)
labels = {};
objects = figure_label_objects(fig);
properties = {'String','Label','XTickLabel','YTickLabel','ZTickLabel','DisplayName','Name'};
for i = 1:numel(objects)
    for j = 1:numel(properties)
        if ~isprop(objects{i},properties{j}), continue; end
        value = get(objects{i},properties{j});
        if ischar(value), value = cellstr(value);
        elseif isstring(value), value = cellstr(value);
        elseif ~iscell(value), continue;
        end
        for k = 1:numel(value)
            if ischar(value{k}) && ~isempty(strtrim(value{k}))
                labels{end+1} = value{k}; %#ok<AGROW>
            end
        end
    end
end
labels = unique(labels,'stable');
end
