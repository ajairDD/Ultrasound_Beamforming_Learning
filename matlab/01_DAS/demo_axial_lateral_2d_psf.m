%% demo_axial_lateral_2d_psf.m
% Demonstrate the different physical origins of axial and lateral PSF.
%
% No USTB, no external data, and no third-party toolbox are required.
%
% Model:
%   - 1-D linear array
%   - broadside plane-wave transmit
%   - one point target at x = 0, z = 30 mm
%   - complex analytic (IQ-like) Gaussian-modulated pulse
%
% Goals:
%   1) compare axial PSF for short vs long pulses;
%   2) compare lateral PSF for different apertures;
%   3) visualize one 2-D PSF around the target.
%
% Important:
%   This is a teaching model. Exact FWHM constants depend on pulse shape,
%   transmit/receive configuration, apodization and width definition.

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
target_z = 30e-3;

%% Time axis
max_depth = 45e-3;
t_end = 2 * max_depth / c + 10 / fc;
t = (0:1/fs:t_end).';

%% Part A: axial PSF versus pulse duration
% Smaller sigma_t -> shorter pulse -> broader bandwidth -> better axial resolution.
sigma_short = 0.35 / fc;
sigma_long  = 0.85 / fc;

pulse_names = {'Short pulse', 'Long pulse'};
sigma_set = [sigma_short, sigma_long];

z_scan = linspace(27e-3, 33e-3, 1201);

axial_response = zeros(numel(sigma_set), numel(z_scan));
axial_fwhm = zeros(size(sigma_set));
frac_bw_approx = zeros(size(sigma_set));

figure('Color', 'w');
hold on;

for k = 1:numel(sigma_set)
    sigma_t = sigma_set(k);

    channel_iq = generate_point_target_iq( ...
        t, element_x, target_x, target_z, c, fc, sigma_t);

    response = beamform_axial_response( ...
        channel_iq, t, element_x, target_x, z_scan, c);

    response = response / (max(response) + eps);
    axial_response(k, :) = response;

    axial_fwhm(k) = measure_width_at_level(z_scan, response, 0.5);

    % For Gaussian envelope exp(-t^2/(2 sigma_t^2)),
    % the envelope spectrum is also Gaussian.
    % Approximate -6 dB amplitude bandwidth:
    %   BW_6dB ~= 2*sqrt(2*ln(2)) / (2*pi*sigma_t)
    bw_6db = sqrt(2*log(2)) / (pi*sigma_t);
    frac_bw_approx(k) = bw_6db / fc;

    response_db = 20*log10(response + eps);
    response_db(response_db < -60) = -60;

    plot(z_scan*1e3, response_db, 'LineWidth', 1.5, ...
        'DisplayName', sprintf('%s, BW_{6dB}/f_c ~= %.2f', ...
        pulse_names{k}, frac_bw_approx(k)));
end

xlabel('Axial focus depth (mm)');
ylabel('Normalized magnitude (dB)');
title('Axial PSF: pulse duration / bandwidth');
ylim([-60 0]);
xlim([27 33]);
grid on;
legend('Location', 'best');

%% Part B: lateral PSF versus receive aperture
sigma_t = sigma_short;
channel_iq = generate_point_target_iq( ...
    t, element_x, target_x, target_z, c, fc, sigma_t);

x_scan = linspace(-5e-3, 5e-3, 1001);
aperture_counts = [16 32 64];

lateral_fwhm = zeros(size(aperture_counts));

figure('Color', 'w');
hold on;

for k = 1:numel(aperture_counts)
    n_active = aperture_counts(k);
    active_idx = centered_indices(n_elements, n_active);
    weights = ones(1, n_active) / n_active;

    response = beamform_lateral_response( ...
        channel_iq, t, element_x, active_idx, weights, ...
        x_scan, target_z, c);

    response = response / (max(response) + eps);
    lateral_fwhm(k) = measure_width_at_level(x_scan, response, 0.5);

    D = (n_active - 1) * pitch;
    f_number = target_z / D;

    response_db = 20*log10(response + eps);
    response_db(response_db < -60) = -60;

    plot(x_scan*1e3, response_db, 'LineWidth', 1.5, ...
        'DisplayName', sprintf('%d elements, F# %.2f', ...
        n_active, f_number));
end

xlabel('Lateral focus position (mm)');
ylabel('Normalized magnitude (dB)');
title('Lateral PSF: receive aperture');
ylim([-60 0]);
xlim([-5 5]);
grid on;
legend('Location', 'best');

%% Part C: one 2-D PSF
% Use a modest grid so the demo remains readable and fast.
x2 = linspace(-2.5e-3, 2.5e-3, 201);
z2 = linspace(28e-3, 32e-3, 201);

active_idx = 1:n_elements;
weights = ones(1, n_elements) / n_elements;

psf2d = zeros(numel(z2), numel(x2));

for iz = 1:numel(z2)
    z_focus = z2(iz);

    for ix = 1:numel(x2)
        x_focus = x2(ix);

        tau_tx = z_focus / c;
        focused_samples = complex(zeros(1, n_elements));

        for m = 1:n_elements
            rx_distance = sqrt((x_focus - element_x(m))^2 + z_focus^2);
            tau_total = tau_tx + rx_distance / c;

            focused_samples(m) = interp1( ...
                t, channel_iq(:,m), tau_total, 'linear', 0);
        end

        psf2d(iz, ix) = abs(sum(weights .* focused_samples));
    end
end

psf2d = psf2d / (max(psf2d(:)) + eps);
psf2d_db = 20*log10(psf2d + eps);
psf2d_db(psf2d_db < -50) = -50;

figure('Color', 'w');
imagesc(x2*1e3, z2*1e3, psf2d_db);
axis xy;
axis image;
xlabel('Lateral position (mm)');
ylabel('Depth (mm)');
title('2-D PSF, 64-element uniform receive aperture');
colorbar;
caxis([-50 0]);
hold on;
plot(target_x*1e3, target_z*1e3, 'wo', ...
    'MarkerSize', 7, 'LineWidth', 1.5);

%% Print summary
fprintf('=== Axial PSF experiment ===\n');
fprintf('Pulse       | sigma_t (ns) | approx frac BW_6dB | -6 dB axial width (mm)\n');
fprintf('-----------------------------------------------------------------------\n');

for k = 1:numel(sigma_set)
    fprintf('%-11s | %12.2f | %18.3f | %22.3f\n', ...
        pulse_names{k}, sigma_set(k)*1e9, frac_bw_approx(k), ...
        axial_fwhm(k)*1e3);
end

fprintf('\n=== Lateral PSF experiment ===\n');
fprintf('Active elements | Aperture D (mm) | F-number | -6 dB lateral width (mm)\n');
fprintf('--------------------------------------------------------------------------\n');

for k = 1:numel(aperture_counts)
    n_active = aperture_counts(k);
    D = (n_active - 1)*pitch;
    f_number = target_z / D;

    fprintf('%14d | %15.3f | %8.3f | %25.3f\n', ...
        n_active, D*1e3, f_number, lateral_fwhm(k)*1e3);
end

fprintf('\nKey idea:\n');
fprintf(['Axial resolution is controlled mainly by pulse length / bandwidth,\n' ...
         'whereas lateral resolution is controlled mainly by aperture / focusing.\n']);

%% Local functions
function channel_iq = generate_point_target_iq( ...
    t, element_x, target_x, target_z, c, fc, sigma_t)

    n_elements = numel(element_x);
    channel_iq = complex(zeros(numel(t), n_elements));

    tau_tx = target_z / c;

    for m = 1:n_elements
        rx_distance = sqrt((target_x - element_x(m))^2 + target_z^2);
        tau_total = tau_tx + rx_distance/c;

        dt = t - tau_total;

        channel_iq(:,m) = ...
            exp(-(dt.^2)/(2*sigma_t^2)) .* ...
            exp(1j*2*pi*fc*dt);
    end
end

function response = beamform_axial_response( ...
    channel_iq, t, element_x, x_focus, z_scan, c)

    n_elements = numel(element_x);
    weights = ones(1, n_elements) / n_elements;

    response_complex = complex(zeros(size(z_scan)));

    for iz = 1:numel(z_scan)
        z_focus = z_scan(iz);
        tau_tx = z_focus / c;

        focused_samples = complex(zeros(1, n_elements));

        for m = 1:n_elements
            rx_distance = sqrt((x_focus-element_x(m))^2 + z_focus^2);
            tau_total = tau_tx + rx_distance/c;

            focused_samples(m) = interp1( ...
                t, channel_iq(:,m), tau_total, 'linear', 0);
        end

        response_complex(iz) = sum(weights .* focused_samples);
    end

    response = abs(response_complex);
end

function response = beamform_lateral_response( ...
    channel_iq, t, element_x, active_idx, weights, ...
    x_scan, z_focus, c)

    response_complex = complex(zeros(size(x_scan)));

    for ix = 1:numel(x_scan)
        x_focus = x_scan(ix);
        tau_tx = z_focus/c;

        focused_samples = complex(zeros(1, numel(active_idx)));

        for k = 1:numel(active_idx)
            m = active_idx(k);

            rx_distance = sqrt((x_focus-element_x(m))^2 + z_focus^2);
            tau_total = tau_tx + rx_distance/c;

            focused_samples(k) = interp1( ...
                t, channel_iq(:,m), tau_total, 'linear', 0);
        end

        response_complex(ix) = sum(weights .* focused_samples);
    end

    response = abs(response_complex);
end

function active_idx = centered_indices(n_total, n_active)
    assert(n_active <= n_total, 'n_active cannot exceed n_total.');
    assert(mod(n_total-n_active,2) == 0, ...
        'Centered aperture requires equal margins in this teaching demo.');

    first = (n_total-n_active)/2 + 1;
    active_idx = first:(first+n_active-1);
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
    x_cross = x0 + (level-y0)*(x1-x0)/(y1-y0);
end
