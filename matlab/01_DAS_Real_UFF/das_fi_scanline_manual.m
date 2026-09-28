%% das_fi_scanline_manual.m
% Chapter 1 - first REAL-data DAS implementation.
%
% Conventional focused-imaging (FI) scanline DAS on UFF channel data.
%
% IMPORTANT DESIGN CHOICE
% -----------------------
% USTB is used ONLY to read the UFF object and metadata.
% The following steps are implemented here explicitly:
%   1) RF -> analytic signal conversion
%   2) focused-transmit virtual-source delay
%   3) receive propagation delay
%   4) fractional-sample linear interpolation
%   5) receive aperture selection
%   6) coherent receive summation
%   7) envelope magnitude and dB display
%
% This is deliberately NOT RTB:
%   - one transmit wave -> one lateral scanline
%   - the scanline x position is sequence(i_wave).source.x
%   - there is no coherent summation across neighboring transmit waves
%
% Timing convention used here
% ---------------------------
% We use the COMMON channel-data time axis
%
%   t[n] = initial_time + (n-1)/fs
%
% and therefore include -sequence(i_wave).delay explicitly in tau_tx.
% Do NOT also use channel_data.time(i_wave), because that already includes
% wave.delay and would count the offset twice.
%
% First version scope
% -------------------
% This teaching implementation currently requires RF data
% (modulation_frequency == 0). IQ support will be added only after the
% dataset's demodulation convention has been inspected explicitly.
%
% Requirement:
%   USTB must be on the MATLAB path.
%
% Suggested run from repository root:
%   addpath(genpath('D:/USTB'));  % change to your own path
%   cd matlab/01_DAS_Real_UFF
%   filename = '../../data/L7_FI_Verasonics_CIRS_points.uff';
%   das_fi_scanline_manual

clearvars -except filename z_min z_max n_z frame_index ...
    receive_aperture_mode receive_f_number;
clc;
close all;

%% ------------------------------------------------------------------------
% User-facing parameters
% -------------------------------------------------------------------------
if ~exist('filename', 'var')
    filename = '../../data/L7_FI_Verasonics_CIRS_points.uff';
end

if ~exist('z_min', 'var')
    z_min = 5e-3;             % [m]
end

if ~exist('z_max', 'var')
    z_max = 45e-3;            % [m]
end

if ~exist('n_z', 'var')
    n_z = 1024;
end

if ~exist('frame_index', 'var')
    frame_index = 1;
end

% 'full'     : all receive channels, closest to current USTB window.none
% 'f_number' : explicit dynamic boxcar receive aperture D(z)=z/F#
if ~exist('receive_aperture_mode', 'var')
    receive_aperture_mode = 'full';
end

if ~exist('receive_f_number', 'var')
    receive_f_number = 1.7;
end

display_dynamic_range_db = 60;

%% ------------------------------------------------------------------------
% 1. Read UFF metadata with USTB
% -------------------------------------------------------------------------
assert(exist(filename, 'file') == 2, 'File not found: %s', filename);
assert(~isempty(which('uff.read_object')), ...
    ['USTB / UFF reader was not found on the MATLAB path. ' ...
     'Run addpath(genpath(''YOUR_USTB_PATH'')) first.']);

channel_data = uff.read_object(filename, '/channel_data');

assert(frame_index >= 1 && frame_index <= channel_data.N_frames, ...
    'frame_index is outside the available frame range.');

assert(abs(channel_data.modulation_frequency) < eps, ...
    ['This first teaching implementation is intentionally RF-only. ' ...
     'The file reports modulation_frequency = %.12g Hz. ' ...
     'Inspect the IQ convention before extending the beamformer.'], ...
     channel_data.modulation_frequency);

assert(isreal(channel_data.data), ...
    ['The file reports RF (modulation_frequency == 0), but data is complex. ' ...
     'Inspect the file semantics before continuing.']);

probe = channel_data.probe;
sequence = channel_data.sequence;

N_samples = channel_data.N_samples;
N_channels = channel_data.N_channels;
N_waves = channel_data.N_waves;

assert(N_channels == probe.N_elements, ...
    'N_channels does not match probe.N_elements.');

%% ------------------------------------------------------------------------
% 2. Confirm this really is conventional focused imaging
% -------------------------------------------------------------------------
source_x = zeros(N_waves,1);
source_y = zeros(N_waves,1);
source_z = zeros(N_waves,1);

for iw = 1:N_waves
    assert(sequence(iw).wavefront == uff.wavefront.spherical, ...
        'Wave %d is not spherical. This script is for focused FI only.', iw);
    assert(sequence(iw).source.z > 0, ...
        'Wave %d does not have a positive-z focused virtual source.', iw);

    source_x(iw) = sequence(iw).source.x;
    source_y(iw) = sequence(iw).source.y;
    source_z(iw) = sequence(iw).source.z;
end

assert(max(abs(source_y)) < 1e-9, ...
    ['This first implementation assumes a 2-D x-z imaging plane. ' ...
     'Non-zero source.y was detected.']);

% Conventional scanline FI:
% one source.x position -> one output image line.
x_axis = source_x;
z_axis = linspace(z_min, z_max, n_z).';

%% ------------------------------------------------------------------------
% 3. Common acquisition-time axis
% -------------------------------------------------------------------------
fs = channel_data.sampling_frequency;
t0 = channel_data.initial_time;

t_axis = t0 + (0:N_samples-1).' / fs;

fprintf('============================================================\n');
fprintf(' Chapter 1 - Manual conventional FI DAS\n');
fprintf('============================================================\n');
fprintf('File                  : %s\n', filename);
fprintf('Data size [T C W F]   : [%d %d %d %d]\n', ...
    size(channel_data.data,1), size(channel_data.data,2), ...
    size(channel_data.data,3), size(channel_data.data,4));
fprintf('fs                    : %.3f MHz\n', fs/1e6);
fprintf('initial_time          : %.6f us\n', t0*1e6);
fprintf('sound speed           : %.3f m/s\n', channel_data.sound_speed);
fprintf('N scanlines / waves   : %d\n', N_waves);
fprintf('x range               : %.3f to %.3f mm\n', ...
    min(x_axis)*1e3, max(x_axis)*1e3);
fprintf('focus-z range         : %.3f to %.3f mm\n', ...
    min(source_z)*1e3, max(source_z)*1e3);
fprintf('receive aperture mode : %s\n', receive_aperture_mode);
if strcmpi(receive_aperture_mode, 'f_number')
    fprintf('receive F-number      : %.3f\n', receive_f_number);
end
fprintf('\n');

%% ------------------------------------------------------------------------
% 4. Allocate output
% -------------------------------------------------------------------------
% Complex analytic beamformed signal.
das_analytic = complex(zeros(n_z, N_waves));

% Diagnostic counters.
n_out_of_range = 0;
n_requested = 0;
active_channel_count = zeros(n_z, N_waves);

%% ------------------------------------------------------------------------
% 5. Conventional scanline DAS
% -------------------------------------------------------------------------
for iw = 1:N_waves

    if mod(iw-1, max(1, floor(N_waves/10))) == 0
        fprintf('Beamforming wave %d / %d ...\n', iw, N_waves);
    end

    % Read ONE transmit at a time to keep memory usage modest.
    rf_wave = double(channel_data.data(:,:,iw,frame_index));

    % USTB's RF DAS also works with an analytic representation before
    % delay-and-sum. We implement that conversion ourselves using FFT.
    analytic_wave = analytic_signal_fft(rf_wave);

    x_line = x_axis(iw);

    for iz = 1:n_z
        z_pixel = z_axis(iz);

        % ---------------------------------------------------------------
        % Tx delay: focused spherical virtual-source model.
        %
        % This follows the same geometric convention used by USTB's
        % spherical focused-wave delay. On the conventional scanline
        % x_pixel = source.x, spherical and the local hybrid model coincide.
        % ---------------------------------------------------------------
        tau_tx = focused_tx_delay_spherical( ...
            sequence(iw), x_line, 0, z_pixel);

        % ---------------------------------------------------------------
        % Rx delay: distance from candidate pixel to every receive element.
        % ---------------------------------------------------------------
        rx_distance = sqrt( ...
            (probe.x(:).' - x_line).^2 + ...
            (probe.y(:).' - 0).^2 + ...
            (probe.z(:).' - z_pixel).^2);

        tau_rx = rx_distance / channel_data.sound_speed;

        % Total sample time on the common acquisition time axis.
        tau_total = tau_tx + tau_rx;

        % ---------------------------------------------------------------
        % Fractional-sample interpolation across all Rx channels.
        % ---------------------------------------------------------------
        [focused_samples, valid] = sample_channels_linear_uniform( ...
            analytic_wave, t0, fs, tau_total);

        % ---------------------------------------------------------------
        % Receive aperture.
        % ---------------------------------------------------------------
        weights = receive_weights( ...
            probe.x(:).', x_line, z_pixel, ...
            receive_aperture_mode, receive_f_number);

        % Never use samples outside the stored record.
        weights(~valid) = 0;

        active_channel_count(iz,iw) = nnz(weights);
        n_out_of_range = n_out_of_range + nnz(~valid);
        n_requested = n_requested + N_channels;

        % Coherent receive sum.
        %
        % We intentionally do NOT normalize by sum(weights) here because
        % USTB apodization weights are also not automatically normalized.
        % Image display is normalized only after beamforming.
        das_analytic(iz,iw) = sum(weights .* focused_samples);
    end
end

%% ------------------------------------------------------------------------
% 6. Envelope / dB image
% -------------------------------------------------------------------------
envelope = abs(das_analytic);

peak = max(envelope(:));
assert(peak > 0, 'Beamformed image is all zero.');

image_db = 20*log10(envelope / peak + eps);
image_db(image_db < -display_dynamic_range_db) = -display_dynamic_range_db;

%% ------------------------------------------------------------------------
% 7. Display
% -------------------------------------------------------------------------
figure('Color','w');
imagesc(x_axis*1e3, z_axis*1e3, image_db);
set(gca, 'YDir', 'reverse');
axis image;
xlabel('Lateral position x (mm)');
ylabel('Depth z (mm)');
title('Manual conventional FI-DAS');
colorbar;
caxis([-display_dynamic_range_db 0]);
colormap gray;

%% ------------------------------------------------------------------------
% 8. Diagnostics
% -------------------------------------------------------------------------
fprintf('\n=== Diagnostics ===\n');
fprintf('Requested channel samples : %d\n', n_requested);
fprintf('Out-of-record samples     : %d (%.4f%%)\n', ...
    n_out_of_range, 100*n_out_of_range/max(n_requested,1));
fprintf('Active Rx channels range  : %d to %d\n', ...
    min(active_channel_count(:)), max(active_channel_count(:)));

[~, peak_linear_idx] = max(envelope(:));
[peak_iz, peak_ix] = ind2sub(size(envelope), peak_linear_idx);

fprintf('Global image peak         : x = %.3f mm, z = %.3f mm\n', ...
    x_axis(peak_ix)*1e3, z_axis(peak_iz)*1e3);

fprintf('\nScientific status:\n');
fprintf(['  This is our own conventional scanline FI-DAS implementation.\n' ...
         '  USTB was used only for UFF object reading.\n' ...
         '  The next verification step is comparison against a matched\n' ...
         '  USTB conventional scanline DAS reference on the same grid.\n']);

%% =========================================================================
% Local functions
% =========================================================================

function tau_tx = focused_tx_delay_spherical(wave, x, y, z)
%FOCUSED_TX_DELAY_SPHERICAL Focused-wave Tx delay on USTB time convention.
%
% Uses the common channel time axis:
%   t[n] = initial_time + (n-1)/fs
%
% Therefore wave.delay is included explicitly here.
%
% For a focused virtual source in front of the probe (source.z > 0):
%   signed_distance is negative before the focus and positive after it.
%
% IMPORTANT ABOUT wave.source.distance
% ------------------------------------
% USTB defines uff.point.distance as the Euclidean distance from the
% virtual source to the GLOBAL coordinate origin [0,0,0]:
%
%   source.distance = norm(source.xyz)
%
% This is a TIME-REFERENCE convention, not a claim that the acoustic wave
% physically travels from the global origin to the focus.
%
% If we instead choose the probe-plane point directly below the focus,
%
%   local_origin = [source.x, source.y, 0],
%
% the reference source distance would simply be source.z for a flat probe.
% The two conventions differ only by the constant
%
%   source.distance - source.z
%
% and therefore generate the SAME relative transmit-delay law when the
% event-time offset is shifted consistently. USTB exposes exactly this
% correction through wave.t0_origin.
%
% For the present UFF data, we retain the native USTB convention because
% it has already been numerically validated against midprocess.das().

    sx = wave.source.x;
    sy = wave.source.y;
    sz = wave.source.z;

    d = sqrt((sx-x).^2 + (sy-y).^2 + (sz-z).^2);

    if z < sz
        signed_d = -d;
    else
        signed_d = d;
    end

    % Global-origin reference length used by USTB's spherical model.
    source_reference_distance = wave.source.distance;

    tau_tx = ...
        (signed_d + source_reference_distance) / wave.sound_speed ...
        - wave.delay;
end

function [values, valid] = sample_channels_linear_uniform( ...
    channel_data, t0, fs, query_time)
%SAMPLE_CHANNELS_LINEAR_UNIFORM Linear interpolation, one time per channel.
%
% channel_data shape:
%   [sample, receive_channel]
%
% query_time shape:
%   [1, receive_channel]
%
% values shape:
%   [1, receive_channel]

    N_samples = size(channel_data,1);
    N_channels = size(channel_data,2);

    assert(numel(query_time) == N_channels, ...
        'query_time must contain one value per receive channel.');

    % MATLAB 1-based continuous sample coordinate.
    u = (query_time - t0) * fs + 1;

    i0 = floor(u);
    alpha = u - i0;

    valid = (i0 >= 1) & (i0 < N_samples);
    values = complex(zeros(1,N_channels));

    ch = 1:N_channels;

    idx0 = sub2ind(size(channel_data), i0(valid), ch(valid));
    idx1 = sub2ind(size(channel_data), i0(valid)+1, ch(valid));

    values(valid) = ...
        (1-alpha(valid)).*channel_data(idx0) + ...
        alpha(valid).*channel_data(idx1);
end

function w = receive_weights( ...
    element_x, x_pixel, z_pixel, mode, f_number)
%RECEIVE_WEIGHTS Receive-aperture selection for the teaching baseline.
%
% full:
%   all channels active.
%
% f_number:
%   boxcar dynamic aperture with
%       D(z) = z/F#
%   and half-width D/2 around x_pixel.

    switch lower(mode)
        case 'full'
            w = ones(size(element_x));

        case 'f_number'
            assert(isfinite(f_number) && f_number > 0, ...
                'receive_f_number must be positive and finite.');

            aperture_width = z_pixel / f_number;
            half_width = aperture_width / 2;

            w = double(abs(element_x - x_pixel) <= half_width);

            % Avoid an empty aperture at extremely shallow depth.
            if ~any(w)
                [~, idx] = min(abs(element_x - x_pixel));
                w(idx) = 1;
            end

        otherwise
            error('Unknown receive_aperture_mode: %s', mode);
    end
end

function xa = analytic_signal_fft(x)
%ANALYTIC_SIGNAL_FFT Create analytic signal along the first dimension.
%
% Equivalent in intent to hilbert(x) along the time dimension, but uses
% only FFT/IFFT so this teaching code does not require Signal Processing
% Toolbox.
%
% x shape:
%   [time, channel]

    N = size(x,1);
    X = fft(x, [], 1);

    h = zeros(N,1);

    if mod(N,2) == 0
        % Even length: keep DC and Nyquist, double positive frequencies.
        h(1) = 1;
        h(N/2 + 1) = 1;
        h(2:N/2) = 2;
    else
        % Odd length: keep DC, double positive frequencies.
        h(1) = 1;
        h(2:(N+1)/2) = 2;
    end

    xa = ifft(X .* h, [], 1);
end
