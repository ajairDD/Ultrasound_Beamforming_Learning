%% plot_raw_channel_overview_ustb.m
% Plot one USTB channel-data acquisition as time x channel.
%
% Requirement: USTB must be on the MATLAB path.
%
% This script deliberately validates the first two dimensions before plotting.

clearvars -except filename wave_index frame_index;
clc;

if ~exist('filename', 'var')
    filename = '../../data/L7_FI_TheGB.uff';
end
if ~exist('wave_index', 'var')
    wave_index = 1;
end
if ~exist('frame_index', 'var')
    frame_index = 1;
end

assert(exist(filename, 'file') == 2, 'File not found: %s', filename);
assert(~isempty(which('uff.read_object')), ...
    ['USTB / UFF reader was not found on the MATLAB path. ' ...
     'Run addpath(genpath(''YOUR_USTB_PATH'')) first.']);

channel_data = uff.read_object(filename, '/channel_data');
raw = channel_data.data;

assert(size(raw,1) == channel_data.N_samples, ...
    'Unexpected USTB data layout: dimension 1 is not N_samples.');
assert(size(raw,2) == channel_data.N_channels, ...
    'Unexpected USTB data layout: dimension 2 is not N_channels.');

assert(wave_index >= 1 && wave_index <= max(1, channel_data.N_waves), ...
    'wave_index is out of range.');
assert(frame_index >= 1 && frame_index <= max(1, channel_data.N_frames), ...
    'frame_index is out of range.');

rf2d = squeeze(raw(:, :, wave_index, frame_index));

assert(ismatrix(rf2d), 'Selected channel-data slice is not 2-D.');

fs = channel_data.sampling_frequency;
t0 = channel_data.initial_time;

time_us = (t0 + (0:size(rf2d,1)-1)' / fs) * 1e6;

if isreal(rf2d)
    display_data = rf2d;
    display_label = 'real channel data';
else
    % Keep the complex data intact in rf2d.
    % Only use its real part for this RF-like visualization.
    display_data = real(rf2d);
    display_label = 'real part of complex channel data';
end

display_data = display_data / (max(abs(display_data(:))) + eps);

figure('Color', 'w');
imagesc(1:size(display_data,2), time_us, display_data);
axis xy;
xlabel('Channel index');
ylabel('Time (\mus)');
title(sprintf('%s | wave=%d | frame=%d', ...
    display_label, wave_index, frame_index), 'Interpreter', 'none');
cb = colorbar;
cb.Label.String = 'RF / full-record peak';

fprintf('Displayed [samples x channels] = [%d x %d]\n', ...
    size(display_data,1), size(display_data,2));
fprintf('sampling_frequency = %.6g Hz\n', fs);
fprintf('initial_time = %.6g s\n', t0);
fprintf('isreal(channel_data.data) = %d\n', isreal(raw));
