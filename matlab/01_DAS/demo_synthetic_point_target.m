%% demo_synthetic_point_target.m
% Self-contained DAS teaching demo.
%
% No USTB and no external data are required.
%
% Model:
%   - 1-D linear receive array
%   - broadside plane-wave transmit
%   - one point scatterer
%   - homogeneous medium with constant sound speed
%   - Gaussian-modulated sinusoidal pulse
%
% Purpose:
%   1) visualize different echo arrival times across elements;
%   2) see why delay compensation is required;
%   3) form a simple lateral DAS response at the target depth.
%
% This is a teaching model, not a complete scanner simulator.

clear;
clc;
close all;

%% Physical and acquisition parameters
c = 1540;               % sound speed [m/s]
fs = 40e6;              % sampling frequency [Hz]
fc = 5e6;               % pulse center frequency [Hz]

n_elements = 64;
pitch = 0.30e-3;        % element pitch [m]

element_x = ((0:n_elements-1) - (n_elements-1)/2) * pitch;

% One point scatterer
target_x = 2.0e-3;      % [m]
target_z = 30e-3;       % [m]
target_amplitude = 1.0;

% Broadside plane-wave transmit:
% the wavefront reaches depth z after z/c.
tau_tx_target = target_z / c;

%% Time axis
max_depth = 45e-3;
t_end = 2 * max_depth / c + 8 / fc;
t = (0:1/fs:t_end).';
n_samples = numel(t);

%% Pulse model
% Gaussian envelope width: chosen only for an intuitive narrow-band pulse.
sigma_t = 0.55 / fc;

channel_rf = zeros(n_samples, n_elements);

for m = 1:n_elements
    rx_distance = sqrt((target_x - element_x(m))^2 + target_z^2);
    tau_rx = rx_distance / c;
    tau_total = tau_tx_target + tau_rx;

    dt = t - tau_total;
    pulse = exp(-(dt.^2) / (2*sigma_t^2)) .* cos(2*pi*fc*dt);

    channel_rf(:, m) = target_amplitude * pulse;
end

%% Figure 1: raw channel RF
figure('Color', 'w');
imagesc(element_x * 1e3, t * 1e6, channel_rf);
axis xy;
xlabel('Element lateral position (mm)');
ylabel('Time (\mus)');
title('Raw channel RF: one point target');
colorbar;

%% Figure 2: several channel waveforms
selected = round(linspace(1, n_elements, 5));

figure('Color', 'w');
hold on;
offset = 0;
for k = 1:numel(selected)
    m = selected(k);
    trace = channel_rf(:, m);
    trace = trace / max(abs(trace) + eps);
    plot(t * 1e6, trace + offset, 'DisplayName', sprintf('Element %d', m));
    offset = offset + 2;
end
xlabel('Time (\mus)');
ylabel('Normalized RF + vertical offset');
title('The same target arrives at different times');
legend('Location', 'best');
grid on;

%% DAS lateral scan at the true target depth
x_scan = linspace(-8e-3, 8e-3, 401);
das = zeros(size(x_scan));

for ix = 1:numel(x_scan)
    x_focus = x_scan(ix);
    z_focus = target_z;

    % Broadside PW transmit delay at the candidate point
    tau_tx = z_focus / c;

    focused_samples = zeros(1, n_elements);

    for m = 1:n_elements
        rx_distance = sqrt((x_focus - element_x(m))^2 + z_focus^2);
        tau_rx = rx_distance / c;
        tau_total = tau_tx + tau_rx;

        % Linear interpolation: explicit sub-sample delay sampling.
        focused_samples(m) = interp1( ...
            t, channel_rf(:, m), tau_total, 'linear', 0);
    end

    % Uniform-aperture DAS
    das(ix) = sum(focused_samples);
end

%% Normalize lateral response
% Use abs() rather than hilbert() so this demo does not require
% Signal Processing Toolbox. This is an RF sample-magnitude response,
% not a full envelope-detected B-mode image.
reference_peak = max(abs(das)) + eps;
das_mag = abs(das) / reference_peak;
das_db = 20 * log10(das_mag + eps);
das_db(das_db < -60) = -60;

figure('Color', 'w');
plot(x_scan * 1e3, das_db, 'LineWidth', 1.5);
xlabel('Lateral focus position (mm)');
ylabel('Normalized amplitude (dB)');
title('Simple DAS lateral response at target depth');
ylim([-60 0]);
xline(target_x * 1e3, '--', 'True target x');
grid on;

%% Compare with a wrong sound speed
c_wrong = 1450;
das_wrong = zeros(size(x_scan));

for ix = 1:numel(x_scan)
    x_focus = x_scan(ix);
    z_focus = target_z;

    tau_tx = z_focus / c_wrong;

    focused_samples = zeros(1, n_elements);
    for m = 1:n_elements
        rx_distance = sqrt((x_focus - element_x(m))^2 + z_focus^2);
        tau_rx = rx_distance / c_wrong;
        tau_total = tau_tx + tau_rx;

        focused_samples(m) = interp1( ...
            t, channel_rf(:, m), tau_total, 'linear', 0);
    end

    das_wrong(ix) = sum(focused_samples);
end

das_wrong_mag = abs(das_wrong) / reference_peak;
das_wrong_db = 20 * log10(das_wrong_mag + eps);
das_wrong_db(das_wrong_db < -60) = -60;

figure('Color', 'w');
plot(x_scan * 1e3, das_db, 'LineWidth', 1.5);
hold on;
plot(x_scan * 1e3, das_wrong_db, '--', 'LineWidth', 1.5);
xlabel('Lateral focus position (mm)');
ylabel('Normalized amplitude (dB)');
title('Correct vs wrong sound-speed model');
legend(sprintf('Beamforming c = %d m/s', c), ...
       sprintf('Beamforming c = %d m/s', c_wrong), ...
       'Location', 'best');
ylim([-60 0]);
grid on;

fprintf('Synthetic DAS demo finished.\n');
fprintf('Array: %d elements, pitch = %.3f mm\n', n_elements, pitch*1e3);
fprintf('Target: x = %.2f mm, z = %.2f mm\n', target_x*1e3, target_z*1e3);
fprintf('fs = %.1f MHz, fc = %.1f MHz\n', fs/1e6, fc/1e6);
