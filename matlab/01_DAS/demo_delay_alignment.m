%% demo_delay_alignment.m
% Demonstrate how DAS delay compensation "straightens" the curved
% channel-RF arrival-time trajectory.
%
% No USTB, no external data, and no third-party toolbox are required.
%
% Model:
%   - 1-D linear receive array
%   - broadside plane-wave transmit
%   - one point scatterer
%   - homogeneous sound speed
%   - Gaussian-modulated sinusoidal RF pulse
%
% The key quantity is the residual delay:
%
%   epsilon_m = tau_true_m - tau_focus_m
%
% If the focus is correct, epsilon_m ~= 0 for all elements and the
% aligned RF pulses are centered at the same relative time.

clear;
clc;
close all;

%% Parameters
c = 1540;               % [m/s]
fs = 40e6;              % [Hz]
fc = 5e6;               % [Hz]

n_elements = 64;
pitch = 0.30e-3;        % [m]
element_x = ((0:n_elements-1) - (n_elements-1)/2) * pitch;

target_x = 2.0e-3;      % [m]
target_z = 30e-3;       % [m]

max_depth = 45e-3;
t_end = 2 * max_depth / c + 8 / fc;
t = (0:1/fs:t_end).';

sigma_t = 0.55 / fc;

%% Generate raw channel RF from the true target
tau_tx_true = target_z / c;

tau_true = zeros(1, n_elements);
channel_rf = zeros(numel(t), n_elements);

for m = 1:n_elements
    rx_distance = sqrt((target_x - element_x(m))^2 + target_z^2);
    tau_rx_true = rx_distance / c;
    tau_true(m) = tau_tx_true + tau_rx_true;

    dt = t - tau_true(m);
    channel_rf(:, m) = ...
        exp(-(dt.^2) / (2*sigma_t^2)) .* cos(2*pi*fc*dt);
end

%% Choose one correct focus and one wrong focus
focus_correct = [target_x, target_z];
focus_wrong = [0.0e-3, target_z];

tau_focus_correct = compute_pw_total_delay( ...
    focus_correct(1), focus_correct(2), element_x, c);

tau_focus_wrong = compute_pw_total_delay( ...
    focus_wrong(1), focus_wrong(2), element_x, c);

residual_correct = tau_true - tau_focus_correct;
residual_wrong = tau_true - tau_focus_wrong;

%% Build aligned traces on a relative-time axis
relative_time = (-1.2e-6 : 1/fs : 1.2e-6).';

aligned_correct = zeros(numel(relative_time), n_elements);
aligned_wrong = zeros(numel(relative_time), n_elements);

for m = 1:n_elements
    aligned_correct(:, m) = interp1( ...
        t, channel_rf(:, m), ...
        relative_time + tau_focus_correct(m), ...
        'linear', 0);

    aligned_wrong(:, m) = interp1( ...
        t, channel_rf(:, m), ...
        relative_time + tau_focus_wrong(m), ...
        'linear', 0);
end

%% Figure 1: raw channel RF
figure('Color', 'w');
imagesc(element_x * 1e3, t * 1e6, channel_rf);
axis xy;
xlabel('Element lateral position (mm)');
ylabel('Absolute time (\mus)');
title('Raw channel RF: curved arrival-time trajectory');
colorbar;

%% Figure 2: correct delay compensation
figure('Color', 'w');
imagesc(element_x * 1e3, relative_time * 1e6, aligned_correct);
axis xy;
xlabel('Element lateral position (mm)');
ylabel('Relative time after focusing (\mus)');
title('Correct focus: channel RF is aligned at relative time 0');
colorbar;
yline(0, '--');

%% Figure 3: wrong delay compensation
figure('Color', 'w');
imagesc(element_x * 1e3, relative_time * 1e6, aligned_wrong);
axis xy;
xlabel('Element lateral position (mm)');
ylabel('Relative time after focusing (\mus)');
title('Wrong lateral focus: residual delay remains across aperture');
colorbar;
yline(0, '--');

%% Figure 4: residual delay across the aperture
figure('Color', 'w');
plot(element_x * 1e3, residual_correct * 1e9, 'LineWidth', 1.5);
hold on;
plot(element_x * 1e3, residual_wrong * 1e9, '--', 'LineWidth', 1.5);
xlabel('Element lateral position (mm)');
ylabel('Residual delay (ns)');
title('Residual delay after applying the candidate focusing law');
legend('Correct focus', 'Wrong focus', 'Location', 'best');
grid on;

fprintf('=== Delay-alignment demo ===\n');
fprintf('Correct focus residual delay: max |epsilon| = %.3f ns\n', ...
    max(abs(residual_correct))*1e9);
fprintf('Wrong focus residual delay:   max |epsilon| = %.3f ns\n', ...
    max(abs(residual_wrong))*1e9);
fprintf('At fc = %.1f MHz, 25 ns corresponds to %.1f degrees of phase.\n', ...
    fc/1e6, 360*fc*25e-9);

%% Local function
function tau_total = compute_pw_total_delay(x_focus, z_focus, element_x, c)
    % Broadside plane-wave transmit:
    %   tau_tx = z_focus / c
    % Receive:
    %   tau_rx_m = sqrt((x_focus-x_m)^2 + z_focus^2) / c

    tau_tx = z_focus / c;
    tau_rx = sqrt((x_focus - element_x).^2 + z_focus.^2) / c;
    tau_total = tau_tx + tau_rx;
end
