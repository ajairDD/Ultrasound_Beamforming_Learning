%% inspect_uff_metadata_ustb.m
% Inspect USTB channel_data metadata before implementing beamforming.
%
% Requirement: USTB must be on the MATLAB path.

clearvars -except filename;
clc;

if ~exist('filename', 'var')
    filename = '../../data/L7_FI_Verasonics_CIRS_points.uff';
end

assert(exist(filename, 'file') == 2, 'File not found: %s', filename);
assert(~isempty(which('uff.read_object')), ...
    ['USTB / UFF reader was not found on the MATLAB path. ' ...
     'Run addpath(genpath(''YOUR_USTB_PATH'')) first.']);

channel_data = uff.read_object(filename, '/channel_data');

fprintf('=== USTB channel_data inspection ===\n');
fprintf('File: %s\n\n', filename);

raw = channel_data.data;
sz = size(raw);

fprintf('[channel_data.data]\n');
fprintf('class = %s\n', class(raw));
fprintf('isreal = %d\n', isreal(raw));
fprintf('size = [');
fprintf('%d ', sz);
fprintf(']\n\n');

fprintf('[Core metadata]\n');
print_scalar_property(channel_data, 'sampling_frequency');
print_scalar_property(channel_data, 'sound_speed');
print_scalar_property(channel_data, 'initial_time');
print_scalar_property(channel_data, 'modulation_frequency');
print_scalar_property(channel_data, 'N_samples');
print_scalar_property(channel_data, 'N_channels');
print_scalar_property(channel_data, 'N_waves');
print_scalar_property(channel_data, 'N_frames');

fprintf('\n[Probe]\n');
if isprop(channel_data, 'probe') && ~isempty(channel_data.probe)
    probe = channel_data.probe;
    fprintf('class = %s\n', class(probe));
    print_scalar_property(probe, 'N');
    print_scalar_property(probe, 'pitch');

    if isprop(probe, 'x') && ~isempty(probe.x)
        fprintf('numel(probe.x) = %d\n', numel(probe.x));
        fprintf('probe.x range = [%g, %g] m\n', min(probe.x(:)), max(probe.x(:)));
    end
else
    fprintf('probe is missing or empty.\n');
end

fprintf('\n[Sequence]\n');
if isprop(channel_data, 'sequence') && ~isempty(channel_data.sequence)
    seq = channel_data.sequence;
    fprintf('number of transmit waves = %d\n', numel(seq));
    fprintf('class(sequence(1)) = %s\n', class(seq(1)));
else
    fprintf('sequence is missing or empty.\n');
end

fprintf('\n[Dimension sanity check]\n');
check_dimension(channel_data, sz, 1, 'N_samples', 'samples');
check_dimension(channel_data, sz, 2, 'N_channels', 'channels');
check_dimension(channel_data, sz, 3, 'N_waves', 'waves');
check_dimension(channel_data, sz, 4, 'N_frames', 'frames');

fprintf('\nDo not proceed to DAS until shape, axis meaning, units and RF/IQ state are understood.\n');

%% Local functions
function print_scalar_property(obj, name)
    if ~isprop(obj, name)
        fprintf('%s: <not available>\n', name);
        return;
    end

    v = obj.(name);

    if isempty(v)
        fprintf('%s: <empty>\n', name);
    elseif isnumeric(v) && isscalar(v)
        fprintf('%s = %.12g\n', name, v);
    else
        fprintf('%s: class=%s, size=[', name, class(v));
        fprintf('%d ', size(v));
        fprintf(']\n');
    end
end

function check_dimension(obj, sz, dim, property_name, label)
    if ~isprop(obj, property_name)
        fprintf('dim %d (%s): metadata property %s unavailable\n', ...
            dim, label, property_name);
        return;
    end

    expected = obj.(property_name);

    if isempty(expected) || ~isscalar(expected)
        fprintf('dim %d (%s): %s is not a usable scalar\n', ...
            dim, label, property_name);
        return;
    end

    if dim <= numel(sz)
        fprintf('dim %d (%s): data size=%d, metadata=%d, match=%d\n', ...
            dim, label, sz(dim), expected, sz(dim)==expected);
    else
        fprintf('dim %d (%s): data array has fewer dimensions\n', dim, label);
    end
end
