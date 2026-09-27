%% demo_aperture_psf_apodization.m
% Demonstrate how aperture size and apodization change the lateral PSF.
%
% No USTB, no external data, and no third-party toolbox are required.
%
% Teaching model:
%   - 1-D linear receive array
%   - broadside plane-wave transmit
%   - one point target at x = 0
%   - homogeneous sound speed
%   - complex analytic (IQ-like) Gaussian-modulated pulse
%
% Why use complex data here?
%   We want to measure a smooth spatial magnitude response without calling
%   hilbert(), so the demo remains base-MATLAB only.
%
% Reported width:
%   "FWHM" here means the width of the normalized magnitude response at
%   0.5 amplitude, i.e. -6.02 dB when using 20*log10(amplitude).
%   Do not confuse this with -3 dB half-power beamwidth.

clear;
clc;
close all;

%% Physical parameters
c = 1540;               % [m/s]
fs = 40e6;              % [Hz]
fc = 5e6;               % [Hz]

lambda = c / fc;

n_elements = 64;
pitch = 0.30e-3;        % [m]
element_x = ((0:n_elements-1) - (n_elements-1)/2) * pitch;

target_x = 0;
target_z = 30e-3;       % [m]

%% Time axis and analytic pulse
max_depth = 45e-3;
t_end = 2 * max_depth / c + 8 / fc;
t = (0:1/fs:t_end).';

sigma_t = 0.55 / fc;

channel_iq = complex(zeros(numel(t), n_elements));

tau_tx_true = target_z / c;

for m = 1:n_elements
    rx_distance = sqrt((target_x - element_x(m))^2 + target_z^2);
    tau_total = tau_tx_true + rx_distance / c;

    dt = t - tau_total;

    channel_iq(:, m) = ...
        exp(-(dt.^2) / (2*sigma_t^2)) .* ...
        exp(1j * 2*pi*fc*dt);
end

%% Lateral scan
x_scan = linspace(-6e-3, 6e-3, 1201);

%% Part A: aperture-size comparison with uniform weighting
aperture_counts = [16 32 64];

response_aperture = zeros(numel(aperture_counts), numel(x_scan));
fwhm_aperture = zeros(size(aperture_counts));
fnumber_aperture = zeros(size(aperture_counts));

figure('Color', 'w');
hold on;

for k = 1:numel(aperture_counts)
    n_active = aperture_counts(k);

    active_idx = centered_indices(n_elements, n_active);
    weights = ones(1, n_active);
    weights = weights / sum(weights);

    response = beamform_lateral_response( ...
        channel_iq, t, element_x, active_idx, weights, ...
        x_scan, target_z, c);

    response = response / (max(response) + eps);
    response_aperture(k, :) = response;

    fwhm_aperture(k) = measure_width_at_level(x_scan, response, 0.5);

    % Point-element approximation for effective aperture width.
    D = (n_active - 1) * pitch;
    fnumber_aperture(k) = target_z / D;

    response_db = 20 * log10(response + eps);
    response_db(response_db < -60) = -60;

    plot(x_scan * 1e3, response_db, 'LineWidth', 1.5, ...
        'DisplayName', sprintf('%d elements, F# %.2f', ...
        n_active, fnumber_aperture(k)));
end

xlabel('Lateral focus position (mm)');
ylabel('Normalized magnitude (dB)');
title('Lateral PSF: aperture size with uniform weighting');
ylim([-60 0]);
xlim([-6 6]);
grid on;
legend('Location', 'best');

%% Part B: apodization comparison using all 64 elements
n_active = 64;
active_idx = centered_indices(n_elements, n_active);

n = 0:n_active-1;
w_uniform = ones(1, n_active);
w_hann = 0.5 - 0.5*cos(2*pi*n/(n_active-1));
w_hamming = 0.54 - 0.46*cos(2*pi*n/(n_active-1));

window_names = {'Uniform', 'Hann', 'Hamming'};
window_set = {w_uniform, w_hann, w_hamming};

fwhm_window = zeros(1, numel(window_set));
psl_window = zeros(1, numel(window_set));

figure('Color', 'w');
hold on;

for k = 1:numel(window_set)
    weights = window_set{k};
    weights = weights / sum(weights);

    response = beamform_lateral_response( ...
        channel_iq, t, element_x, active_idx, weights, ...
        x_scan, target_z, c);

    response = response / (max(response) + eps);

    fwhm_window(k) = measure_width_at_level(x_scan, response, 0.5);
    psl_window(k) = estimate_peak_sidelobe_db(response);

    response_db = 20 * log10(response + eps);
    response_db(response_db < -80) = -80;

    plot(x_scan * 1e3, response_db, 'LineWidth', 1.5, ...
        'DisplayName', window_names{k});
end

xlabel('Lateral focus position (mm)');
ylabel('Normalized magnitude (dB)');
title('Lateral PSF: apodization trade-off');
ylim([-80 0]);
xlim([-6 6]);
grid on;
legend('Location', 'best');

%% Part C: visualize aperture weights
figure('Color', 'w');
plot(1:n_active, w_uniform / max(w_uniform), 'LineWidth', 1.5);
hold on;
plot(1:n_active, w_hann / max(w_hann), 'LineWidth', 1.5);
plot(1:n_active, w_hamming / max(w_hamming), 'LineWidth', 1.5);
xlabel('Active-element index');
ylabel('Normalized weight');
title('Receive apodization weights');
legend(window_names, 'Location', 'best');
grid on;

%% Print quantitative results
fprintf('=== Aperture size experiment ===\n');
fprintf('fc = %.2f MHz, lambda = %.3f mm, target depth = %.1f mm\n\n', ...
    fc/1e6, lambda*1e3, target_z*1e3);

fprintf('Active elements | Aperture D (mm) | F-number | -6 dB amplitude width (mm)\n');
fprintf('--------------------------------------------------------------------------\n');

for k = 1:numel(aperture_counts)
    n_active = aperture_counts(k);
    D = (n_active - 1) * pitch;

    fprintf('%14d | %15.3f | %8.3f | %25.3f\n', ...
        n_active, D*1e3, fnumber_aperture(k), fwhm_aperture(k)*1e3);
end

fprintf('\n=== Apodization experiment, 64 active elements ===\n');
fprintf('Window   | -6 dB amplitude width (mm) | estimated peak sidelobe (dB)\n');
fprintf('-------------------------------------------------------------------\n');

for k = 1:numel(window_set)
    fprintf('%-8s | %26.3f | %28.2f\n', ...
        window_names{k}, fwhm_window(k)*1e3, psl_window(k));
end

fprintf('\nImportant:\n');
fprintf(['These numbers belong to this simplified pulse, geometry and sampling model.\n' ...
         'Do not treat them as universal textbook constants.\n']);

%% Local functions
function active_idx = centered_indices(n_total, n_active)
    assert(n_active <= n_total, 'n_active cannot exceed n_total.');
    assert(mod(n_total - n_active, 2) == 0, ...
        'This teaching helper expects a centered aperture with equal margins.');

    first = (n_total - n_active)/2 + 1;
    active_idx = first:(first + n_active - 1);
end

function response = beamform_lateral_response( ...
    channel_iq, t, element_x, active_idx, weights, ...
    x_scan, z_focus, c)

    response_complex = complex(zeros(size(x_scan)));

    for ix = 1:numel(x_scan)
        x_focus = x_scan(ix);

        % Broadside plane-wave transmit.
        tau_tx = z_focus / c;

        focused_samples = complex(zeros(1, numel(active_idx)));

        for k = 1:numel(active_idx)
            m = active_idx(k);

            rx_distance = sqrt((x_focus - element_x(m))^2 + z_focus^2);
            tau_total = tau_tx + rx_distance / c;

            focused_samples(k) = interp1( ...
                t, channel_iq(:, m), tau_total, 'linear', 0);
        end

        response_complex(ix) = sum(weights .* focused_samples);
    end

    response = abs(response_complex);
end

function width = measure_width_at_level(x, y, level)
    [~, peak_idx] = max(y);

    left_idx = find(y(1:peak_idx) < level, 1, 'last');
    right_relative = find(y(peak_idx:end) < level, 1, 'first');

    if isempty(left_idx) || isempty(right_relative)
        width = nan;
        return;
    end

    right_idx = peak_idx + right_relative - 1;

    x_left = linear_crossing( ...
        x(left_idx), y(left_idx), ...
        x(left_idx+1), y(left_idx+1), level);

    x_right = linear_crossing( ...
        x(right_idx-1), y(right_idx-1), ...
        x(right_idx), y(right_idx), level);

    width = x_right - x_left;
end

function x_cross = linear_crossing(x0, y0, x1, y1, level)
    x_cross = x0 + (level - y0) * (x1 - x0) / (y1 - y0);
end

function psl_db = estimate_peak_sidelobe_db(y)
    % Estimate peak sidelobe outside the first local minima surrounding
    % the main lobe. This is sufficient for this teaching demo.

    [~, peak_idx] = max(y);

    left_min = nan;
    for k = peak_idx-1:-1:2
        if y(k) <= y(k-1) && y(k) < y(k+1)
            left_min = k;
            break;
        end
    end

    right_min = nan;
    for k = peak_idx+1:numel(y)-1
        if y(k) <= y(k-1) && y(k) < y(k+1)
            right_min = k;
            break;
        end
    end

    if isnan(left_min) || isnan(right_min)
        psl_db = nan;
        return;
    end

    sidelobe_values = [y(1:left_min-1), y(right_min+1:end)];
    peak_sidelobe = max(sidelobe_values);

    psl_db = 20 * log10(peak_sidelobe + eps);
end
