%% inspect_uff_metadata_ustb.m
% Chapter 1 / Step 1:
% inspect the REAL UFF data contract before implementing DAS.
%
% Requirement:
%   USTB must be on the MATLAB path.
%
% This script intentionally does NOT beamform anything.
% It answers:
%   - What is the data shape?
%   - RF or IQ?
%   - What are fs, initial_time and sound speed?
%   - What is the probe geometry?
%   - What kind of transmit waves are stored?
%   - Where are the virtual sources / focuses?
%   - What wave.delay values are present?
%
% USTB channel_data convention:
%   data dimensions = [time, channel, wave, frame]
%
% IMPORTANT timing convention:
%   channel_data.time(n_wave) already includes sequence(n_wave).delay.
%   If a custom beamformer instead uses a time axis based only on
%   channel_data.initial_time, then wave.delay must be handled explicitly
%   in the propagation-delay model. Do not count wave.delay twice.

clearvars -except filename;
clc;

if ~exist('filename', 'var')
    filename = '../../data/L7_FI_TheGB.uff';
end

assert(exist(filename, 'file') == 2, 'File not found: %s', filename);
assert(~isempty(which('uff.read_object')), ...
    ['USTB / UFF reader was not found on the MATLAB path. ' ...
     'Run addpath(genpath(''YOUR_USTB_PATH'')) first.']);

channel_data = uff.read_object(filename, '/channel_data');

fprintf('============================================================\n');
fprintf(' Chapter 1 - UFF DATA CONTRACT INSPECTION\n');
fprintf('============================================================\n');
fprintf('File: %s\n\n', filename);

%% 1. Raw data
raw = channel_data.data;
sz4 = [size(raw,1), size(raw,2), size(raw,3), size(raw,4)];

fprintf('[1] CHANNEL DATA\n');
fprintf('MATLAB class        : %s\n', class(raw));
fprintf('isreal(data)        : %d\n', isreal(raw));
fprintf('size [T C W F]      : [%d %d %d %d]\n', sz4);
fprintf('N_samples           : %d\n', channel_data.N_samples);
fprintf('N_channels          : %d\n', channel_data.N_channels);
fprintf('N_waves             : %d\n', channel_data.N_waves);
fprintf('N_frames            : %d\n', channel_data.N_frames);

assert(sz4(1) == channel_data.N_samples, ...
    'Dimension 1 does not match N_samples.');
assert(sz4(2) == channel_data.N_channels, ...
    'Dimension 2 does not match N_channels.');
assert(sz4(3) == channel_data.N_waves, ...
    'Dimension 3 does not match N_waves.');
assert(sz4(4) == channel_data.N_frames, ...
    'Dimension 4 does not match N_frames.');

%% 2. Timing and RF/IQ state
fprintf('\n[2] TIMING / SIGNAL STATE\n');
fprintf('sampling_frequency  : %.12g Hz\n', channel_data.sampling_frequency);
fprintf('sampling_interval   : %.12g s\n', 1/channel_data.sampling_frequency);
fprintf('initial_time        : %.12g s\n', channel_data.initial_time);
fprintf('sound_speed         : %.12g m/s\n', channel_data.sound_speed);
fprintf('modulation_frequency: %.12g Hz\n', channel_data.modulation_frequency);

if isprop(channel_data, 'PRF') && ~isempty(channel_data.PRF)
    fprintf('PRF                 : %.12g Hz\n', channel_data.PRF);
else
    fprintf('PRF                 : <empty / unavailable>\n');
end

if abs(channel_data.modulation_frequency) < eps
    signal_type = 'RF according to USTB modulation_frequency';
else
    signal_type = 'IQ/baseband according to USTB modulation_frequency';
end
fprintf('USTB signal meaning : %s\n', signal_type);

if abs(channel_data.modulation_frequency) < eps && ~isreal(raw)
    warning(['modulation_frequency is zero, but the stored data is complex. ' ...
        'Inspect the file semantics before assuming ordinary RF.']);
end

if abs(channel_data.modulation_frequency) >= eps && isreal(raw)
    warning(['modulation_frequency is non-zero, but the stored data is real. ' ...
        'Inspect the file semantics before assuming standard complex IQ.']);
end

if isprop(channel_data, 'pulse') && ~isempty(channel_data.pulse)
    fprintf('\n[Pulse]\n');
    fprintf('pulse class          : %s\n', class(channel_data.pulse));
    if isprop(channel_data.pulse, 'center_frequency') && ...
            ~isempty(channel_data.pulse.center_frequency)
        fprintf('center_frequency     : %.12g Hz\n', ...
            channel_data.pulse.center_frequency);
        fprintf('lambda = c/fc        : %.12g m\n', ...
            channel_data.sound_speed/channel_data.pulse.center_frequency);
    end
else
    fprintf('\n[Pulse]\n');
    fprintf('pulse                : <empty / unavailable>\n');
end

%% 3. Probe geometry
fprintf('\n[3] PROBE GEOMETRY\n');

probe = channel_data.probe;
assert(~isempty(probe), 'channel_data.probe is empty.');

fprintf('probe class          : %s\n', class(probe));
fprintf('N_elements           : %d\n', probe.N_elements);

if isprop(probe, 'pitch') && ~isempty(probe.pitch)
    fprintf('pitch                : %.12g m\n', probe.pitch);
end

fprintf('x range              : [%.12g, %.12g] m\n', ...
    min(probe.x(:)), max(probe.x(:)));
fprintf('y range              : [%.12g, %.12g] m\n', ...
    min(probe.y(:)), max(probe.y(:)));
fprintf('z range              : [%.12g, %.12g] m\n', ...
    min(probe.z(:)), max(probe.z(:)));

fprintf('center-span aperture : %.12g m\n', ...
    max(probe.x(:)) - min(probe.x(:)));

assert(channel_data.N_channels == probe.N_elements, ...
    'N_channels does not match probe.N_elements.');

%% 4. Sequence overview
fprintf('\n[4] TRANSMIT SEQUENCE\n');

seq = channel_data.sequence;
assert(~isempty(seq), 'channel_data.sequence is empty.');

Nw = numel(seq);

source_x = zeros(Nw,1);
source_y = zeros(Nw,1);
source_z = zeros(Nw,1);
source_distance = zeros(Nw,1);
origin_x = zeros(Nw,1);
origin_y = zeros(Nw,1);
origin_z = zeros(Nw,1);
wave_delay = zeros(Nw,1);
wave_c = zeros(Nw,1);
wavefront_names = strings(Nw,1);

for k = 1:Nw
    source_x(k) = seq(k).source.x;
    source_y(k) = seq(k).source.y;
    source_z(k) = seq(k).source.z;
    source_distance(k) = seq(k).source.distance;

    origin_x(k) = seq(k).origin.x;
    origin_y(k) = seq(k).origin.y;
    origin_z(k) = seq(k).origin.z;

    wave_delay(k) = seq(k).delay;
    wave_c(k) = seq(k).sound_speed;
    wavefront_names(k) = wavefront_name(seq(k).wavefront);
end

fprintf('number of waves      : %d\n', Nw);
fprintf('wavefront types      : %s\n', strjoin(unique(wavefront_names), ', '));
fprintf('source.x range       : [%.12g, %.12g] m\n', ...
    min(source_x), max(source_x));
fprintf('source.z range       : [%.12g, %.12g] m\n', ...
    min(source_z), max(source_z));
fprintf('source.distance range: [%.12g, %.12g] m\n', ...
    min(source_distance), max(source_distance));
fprintf('wave.delay range     : [%.12g, %.12g] s\n', ...
    min(wave_delay), max(wave_delay));
fprintf('wave sound speed     : [%.12g, %.12g] m/s\n', ...
    min(wave_c), max(wave_c));

if all(wavefront_names == "spherical") && all(source_z > 0)
    fprintf('sequence interpretation: focused / converging spherical waves\n');
elseif all(wavefront_names == "spherical") && all(source_z < 0)
    fprintf('sequence interpretation: diverging spherical waves\n');
elseif all(wavefront_names == "plane")
    fprintf('sequence interpretation: plane-wave sequence\n');
else
    fprintf('sequence interpretation: mixed / requires manual inspection\n');
end

%% 5. Inspect representative waves
fprintf('\n[5] REPRESENTATIVE WAVES\n');

selected = unique([1, ceil(Nw/2), Nw]);

for q = 1:numel(selected)
    k = selected(q);

    fprintf('\nWave %d / %d\n', k, Nw);
    fprintf('  wavefront          : %s\n', wavefront_names(k));
    fprintf('  source.xyz         : [%.12g %.12g %.12g] m\n', ...
        source_x(k), source_y(k), source_z(k));
    fprintf('  source.distance    : %.12g m\n', source_distance(k));
    fprintf('  origin.xyz         : [%.12g %.12g %.12g] m\n', ...
        origin_x(k), origin_y(k), origin_z(k));
    fprintf('  wave.delay         : %.12g s\n', wave_delay(k));
    fprintf('  wave.sound_speed   : %.12g m/s\n', wave_c(k));

    tw = channel_data.time(k);
    fprintf('  first stored time  : %.12g s\n', tw(1));
    fprintf('  last stored time   : %.12g s\n', tw(end));
end

%% 6. Scanline-FI checks
fprintf('\n[6] SCANLINE-FI CHECKS\n');

if all(wavefront_names == "spherical") && all(source_z > 0)
    dx = diff(source_x);
    fprintf('source.x monotonic   : %d\n', all(dx >= 0) || all(dx <= 0));

    if Nw > 1
        fprintf('median source.x step : %.12g m\n', median(abs(dx)));
    end

    fprintf(['For conventional linear-array FI, USTB official examples build\n' ...
             'the image x-axis from sequence(n).source.x and use one\n' ...
             'transmit wave per scanline.\n']);
else
    fprintf('Dataset is not a simple all-focused spherical sequence.\n');
end

%% 7. Timing convention warning
fprintf('\n[7] TIMING CONVENTION - READ THIS BEFORE WRITING DAS\n');

fprintf(['USTB channel_data.time(k) is defined as:\n' ...
         '  initial_time + sample_index/fs + sequence(k).delay\n\n' ...
         'Therefore a custom beamformer must choose ONE consistent convention:\n' ...
         '  A) use channel_data.time(k), and do NOT add wave.delay again; OR\n' ...
         '  B) use a common time axis based on initial_time, and include\n' ...
         '     wave.delay explicitly in the Tx-delay equation.\n\n' ...
         'Never do both, or wave.delay will be double counted.\n']);

%% 8. Final checklist
fprintf('\n[8] BEFORE IMPLEMENTING DAS\n');
fprintf('Confirm and record the following values from this report:\n');
fprintf('  [ ] data size [T C W F]\n');
fprintf('  [ ] RF or IQ state\n');
fprintf('  [ ] fs, initial_time, modulation_frequency\n');
fprintf('  [ ] sound speed\n');
fprintf('  [ ] probe element coordinates / pitch\n');
fprintf('  [ ] number of focused waves / scanlines\n');
fprintf('  [ ] source.x and source.z behavior\n');
fprintf('  [ ] wave.delay convention\n');
fprintf('\nOnly after these are confirmed should the real-data DAS be implemented.\n');

%% Local function
function name = wavefront_name(wf)
    if wf == uff.wavefront.plane
        name = "plane";
    elseif wf == uff.wavefront.spherical
        name = "spherical";
    elseif wf == uff.wavefront.photoacoustic
        name = "photoacoustic";
    else
        name = "unknown";
    end
end
