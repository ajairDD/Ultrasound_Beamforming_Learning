%% inspect_uff_hdf5.m
% Inspect a UFF file without USTB.
%
% UFF is based on HDF5. MATLAB can inspect the HDF5 hierarchy with h5info.
% This script intentionally does NOT attempt to reconstruct USTB objects.
% It is a dependency-free way to learn what is physically stored in the file.

clearvars -except filename;
clc;

if ~exist('filename', 'var')
    filename = '../../data/L7_FI_Verasonics_CIRS_points.uff';
end

assert(exist(filename, 'file') == 2, 'File not found: %s', filename);

fprintf('=== UFF / HDF5 structure inspection ===\n');
fprintf('File: %s\n\n', filename);

info = h5info(filename);

print_group(info, 0);

fprintf('\nTip:\n');
fprintf(['UFF can contain object metadata, groups and references. h5info is excellent\n' ...
         'for structure inspection, but USTB is recommended when you want to reconstruct\n' ...
         'the semantic channel_data / probe / sequence objects reliably.\n']);

%% Local function
function print_group(group, level)
    indent = repmat('  ', 1, level);

    fprintf('%sGROUP: %s\n', indent, group.Name);

    for k = 1:numel(group.Datasets)
        d = group.Datasets(k);
        fprintf('%s  DATASET: %s', indent, d.Name);

        if isfield(d, 'Dataspace') && isfield(d.Dataspace, 'Size')
            fprintf(' | size = [');
            fprintf('%d ', d.Dataspace.Size);
            fprintf(']');
        end

        if isfield(d, 'Datatype') && isfield(d.Datatype, 'Class')
            fprintf(' | type = %s', d.Datatype.Class);
        end

        fprintf('\n');
    end

    for k = 1:numel(group.Groups)
        print_group(group.Groups(k), level + 1);
    end
end
