%% demo_das_failure_modes.m
% Final teaching demo for Chapter 1:
% intentionally break the ideal assumptions behind DAS.
%
% No USTB, no external data, and no third-party toolbox are required.
%
% Scenarios:
%   A) two lateral targets that are too close to resolve;
%   B) a weak target masked by the response of a strong nearby target;
%   C) additive independent channel noise;
%   D) sound-speed mismatch;
%   E) synthetic phase-aberration-like channel delay errors.
%
% Important scientific note:
%   Independent random noise is NOT simply a "DAS failure".
%   For M coherent channels with independent equal-variance noise,
%   normalized DAS improves ideal SNR by about M in power
%   (10*log10(M) dB). The limitation is that real clutter,
%   reverberation and phase-correlated interference are not generally
%   independent white noise.

clear;
clc;
close all;

%% Common physical model
c_true = 1540;           % true sound speed [m/s]
fs = 40e6;               % sampling frequency [Hz]
fc = 5e6;                % center frequency [Hz]

n_elements = 64;
pitch = 0.30e-3;         % [m]
element_x = ((0:n_elements-1) - (n_elements-1)/2) * pitch;

target_z = 30e-3;        % [m]
sigma_t = 0.35 / fc;

max_depth = 45e-3;
t_end = 2 * max_depth / c_true + 10 / fc;
t = (0:1/fs:t_end).';

x_scan = linspace(-4e-3, 4e-3, 801);
uniform_weights = ones(1, n_elements) / n_elements;

%% ------------------------------------------------------------------------
% A) Two-target resolution
% -------------------------------------------------------------------------
close_sep = 0.40e-3;     % deliberately smaller than the current lateral PSF
wide_sep  = 1.20e-3;

targets_close = [ ...
    -close_sep/2, target_z, 1.0;
     close_sep/2, target_z, 1.0];

targets_wide = [ ...
    -wide_sep/2, target_z, 1.0;
     wide_sep/2, target_z, 1.0];

ch_close = generate_targets_iq( ...
    t, element_x, targets_close, c_true, fc, sigma_t, zeros(1,n_elements));

ch_wide = generate_targets_iq( ...
    t, element_x, targets_wide, c_true, fc, sigma_t, zeros(1,n_elements));

resp_close = beamform_lateral( ...
    ch_close, t, fs, element_x, uniform_weights, x_scan, target_z, c_true);

resp_wide = beamform_lateral( ...
    ch_wide, t, fs, element_x, uniform_weights, x_scan, target_z, c_true);

resp_close = resp_close / (max(resp_close) + eps);
resp_wide  = resp_wide  / (max(resp_wide) + eps);

figure('Color','w');
plot(x_scan*1e3, 20*log10(resp_close+eps), 'LineWidth',1.5);
hold on;
plot(x_scan*1e3, 20*log10(resp_wide+eps), '--', 'LineWidth',1.5);
xlabel('Lateral focus position (mm)');
ylabel('Normalized magnitude (dB)');
title('Failure mode A: two-target lateral resolution');
legend(sprintf('Separation %.2f mm', close_sep*1e3), ...
       sprintf('Separation %.2f mm', wide_sep*1e3), ...
       'Location','best');
ylim([-50 0]);
xlim([-2 2]);
grid on;

%% ------------------------------------------------------------------------
% B) Strong target masks a weak nearby target
% -------------------------------------------------------------------------
strong_x = -1.50e-3;
weak_x   = -0.69e-3;
weak_amp = 0.03;         % about -30.5 dB in amplitude

strong_only = [strong_x, target_z, 1.0];
strong_weak = [ ...
    strong_x, target_z, 1.0;
    weak_x,   target_z, weak_amp];

ch_strong = generate_targets_iq( ...
    t, element_x, strong_only, c_true, fc, sigma_t, zeros(1,n_elements));

ch_strong_weak = generate_targets_iq( ...
    t, element_x, strong_weak, c_true, fc, sigma_t, zeros(1,n_elements));

resp_strong = beamform_lateral( ...
    ch_strong, t, fs, element_x, uniform_weights, x_scan, target_z, c_true);

resp_strong_weak = beamform_lateral( ...
    ch_strong_weak, t, fs, element_x, uniform_weights, x_scan, target_z, c_true);

reference_peak = max(resp_strong) + eps;
resp_strong_db = 20*log10(resp_strong/reference_peak + eps);
resp_strong_weak_db = 20*log10(resp_strong_weak/reference_peak + eps);

figure('Color','w');
plot(x_scan*1e3, resp_strong_db, 'LineWidth',1.5);
hold on;
plot(x_scan*1e3, resp_strong_weak_db, '--', 'LineWidth',1.5);
xline(strong_x*1e3, ':', 'Strong target');
xline(weak_x*1e3, ':', 'Weak target');
xlabel('Lateral focus position (mm)');
ylabel('Magnitude relative to strong-target peak (dB)');
title('Failure mode B: strong-target response can mask a weak target');
legend('Strong target only', 'Strong + weak target', 'Location','best');
ylim([-55 2]);
xlim([-3 1]);
grid on;

%% ------------------------------------------------------------------------
% C) Independent additive channel noise
% -------------------------------------------------------------------------
clean_target = [0, target_z, 1.0];

ch_clean = generate_targets_iq( ...
    t, element_x, clean_target, c_true, fc, sigma_t, zeros(1,n_elements));

rng(7);
noise_std = 0.50;
complex_noise = noise_std/sqrt(2) * ( ...
    randn(size(ch_clean)) + 1j*randn(size(ch_clean)));

ch_noisy = ch_clean + complex_noise;

resp_clean = beamform_lateral( ...
    ch_clean, t, fs, element_x, uniform_weights, x_scan, target_z, c_true);

resp_noisy = beamform_lateral( ...
    ch_noisy, t, fs, element_x, uniform_weights, x_scan, target_z, c_true);

reference_peak = max(resp_clean) + eps;
resp_clean_db = 20*log10(resp_clean/reference_peak + eps);
resp_noisy_db = 20*log10(resp_noisy/reference_peak + eps);

figure('Color','w');
plot(x_scan*1e3, resp_clean_db, 'LineWidth',1.5);
hold on;
plot(x_scan*1e3, resp_noisy_db, '--', 'LineWidth',1.2);
xlabel('Lateral focus position (mm)');
ylabel('Magnitude relative to clean peak (dB)');
title('Scenario C: DAS suppresses independent noise by coherent averaging');
legend('Clean', 'With independent complex noise', 'Location','best');
ylim([-50 5]);
xlim([-4 4]);
grid on;

ideal_snr_gain_db = 10*log10(n_elements);

%% ------------------------------------------------------------------------
% D) Sound-speed mismatch: axial misregistration + loss of focus
% -------------------------------------------------------------------------
z_scan = linspace(27e-3, 33e-3, 601);
c_wrong = 1500;

resp_z_correct = beamform_axial( ...
    ch_clean, t, fs, element_x, uniform_weights, 0, z_scan, c_true);

resp_z_wrong = beamform_axial( ...
    ch_clean, t, fs, element_x, uniform_weights, 0, z_scan, c_wrong);

ref = max(resp_z_correct) + eps;
resp_z_correct_db = 20*log10(resp_z_correct/ref + eps);
resp_z_wrong_db = 20*log10(resp_z_wrong/ref + eps);

[~, idx_correct] = max(resp_z_correct);
[~, idx_wrong] = max(resp_z_wrong);

figure('Color','w');
plot(z_scan*1e3, resp_z_correct_db, 'LineWidth',1.5);
hold on;
plot(z_scan*1e3, resp_z_wrong_db, '--', 'LineWidth',1.5);
xline(target_z*1e3, ':', 'True depth');
xlabel('Axial focus depth (mm)');
ylabel('Magnitude relative to correct peak (dB)');
title('Failure mode D: sound-speed mismatch');
legend(sprintf('Beamforming c = %d m/s', c_true), ...
       sprintf('Beamforming c = %d m/s', c_wrong), ...
       'Location','best');
ylim([-50 3]);
xlim([27 33]);
grid on;

%% ------------------------------------------------------------------------
% E) Phase-aberration-like channel delay perturbation
% -------------------------------------------------------------------------
rng(11);
raw_delay = randn(1, n_elements);

% Add spatial correlation without any toolbox.
kernel = ones(1,9) / 9;
smooth_delay = conv(raw_delay, kernel, 'same');
smooth_delay = smooth_delay / (std(smooth_delay) + eps);

aberration_rms = 25e-9;  % [s]
channel_delay_error = aberration_rms * smooth_delay;

ch_aberrated = generate_targets_iq( ...
    t, element_x, clean_target, c_true, fc, sigma_t, channel_delay_error);

resp_aberrated = beamform_lateral( ...
    ch_aberrated, t, fs, element_x, uniform_weights, x_scan, target_z, c_true);

ref = max(resp_clean) + eps;
resp_aberrated_db = 20*log10(resp_aberrated/ref + eps);
resp_clean_ab_db = 20*log10(resp_clean/ref + eps);

peak_loss_db = 20*log10(max(resp_aberrated)/ref + eps);

figure('Color','w');
subplot(2,1,1);
plot(element_x*1e3, channel_delay_error*1e9, 'LineWidth',1.5);
xlabel('Element lateral position (mm)');
ylabel('Added delay error (ns)');
title('Synthetic spatially-correlated channel delay error');
grid on;

subplot(2,1,2);
plot(x_scan*1e3, resp_clean_ab_db, 'LineWidth',1.5);
hold on;
plot(x_scan*1e3, resp_aberrated_db, '--', 'LineWidth',1.5);
xlabel('Lateral focus position (mm)');
ylabel('Magnitude relative to clean peak (dB)');
title('Failure mode E: phase-aberration-like delay errors reduce coherence');
legend('Ideal propagation', 'Aberrated channels', 'Location','best');
ylim([-50 3]);
xlim([-4 4]);
grid on;

%% ------------------------------------------------------------------------
% Print summary
% -------------------------------------------------------------------------
fprintf('=== DAS failure-mode teaching demo ===\n\n');

fprintf('[A] Two-target resolution\n');
fprintf('Close separation = %.3f mm\n', close_sep*1e3);
fprintf('Wide  separation = %.3f mm\n\n', wide_sep*1e3);

fprintf('[B] Strong / weak target\n');
fprintf('Weak target amplitude = %.3f = %.2f dB relative amplitude\n\n', ...
    weak_amp, 20*log10(weak_amp));

fprintf('[C] Independent noise\n');
fprintf('M = %d coherent channels\n', n_elements);
fprintf('Ideal normalized-DAS SNR gain for independent noise ~= 10log10(M) = %.2f dB\n\n', ...
    ideal_snr_gain_db);

fprintf('[D] Sound-speed mismatch\n');
fprintf('True c = %.0f m/s, beamforming c = %.0f m/s\n', c_true, c_wrong);
fprintf('Correct-model axial peak = %.3f mm\n', z_scan(idx_correct)*1e3);
fprintf('Wrong-model axial peak   = %.3f mm\n\n', z_scan(idx_wrong)*1e3);

fprintf('[E] Phase-aberration-like delay error\n');
fprintf('RMS channel delay error ~= %.2f ns\n', ...
    sqrt(mean(channel_delay_error.^2))*1e9);
fprintf('Peak response change = %.2f dB relative to ideal\n\n', peak_loss_db);

fprintf(['Interpretation:\n' ...
    'DAS is a strong baseline, but finite aperture, dynamic range and\n' ...
    'propagation-model errors limit what fixed coherent summation can do.\n']);

%% =========================================================================
% Local functions
% =========================================================================
function channel_iq = generate_targets_iq( ...
    t, element_x, targets, c, fc, sigma_t, channel_delay_error)

    n_elements = numel(element_x);
    channel_iq = complex(zeros(numel(t), n_elements));

    if nargin < 7 || isempty(channel_delay_error)
        channel_delay_error = zeros(1, n_elements);
    end

    assert(size(targets,2) == 3, ...
        'targets must be [x, z, amplitude].');
    assert(numel(channel_delay_error) == n_elements, ...
        'channel_delay_error must have one value per receive element.');

    for q = 1:size(targets,1)
        target_x = targets(q,1);
        target_z = targets(q,2);
        amplitude = targets(q,3);

        % Broadside plane-wave transmit.
        tau_tx = target_z / c;

        for m = 1:n_elements
            rx_distance = sqrt((target_x-element_x(m))^2 + target_z^2);

            tau_total = tau_tx + rx_distance/c + channel_delay_error(m);
            dt = t - tau_total;

            channel_iq(:,m) = channel_iq(:,m) + amplitude * ...
                exp(-(dt.^2)/(2*sigma_t^2)) .* ...
                exp(1j*2*pi*fc*dt);
        end
    end
end

function response = beamform_lateral( ...
    channel_iq, t, fs, element_x, weights, x_scan, z_focus, c_bf)

    n_elements = numel(element_x);
    response_complex = complex(zeros(size(x_scan)));

    for ix = 1:numel(x_scan)
        x_focus = x_scan(ix);

        tau_tx = z_focus / c_bf;
        tau_rx = sqrt((x_focus-element_x).^2 + z_focus^2) / c_bf;
        tau_total = tau_tx + tau_rx;

        focused_samples = sample_channels_linear( ...
            channel_iq, t, fs, tau_total);

        response_complex(ix) = sum(weights .* focused_samples);
    end

    response = abs(response_complex);
end

function response = beamform_axial( ...
    channel_iq, t, fs, element_x, weights, x_focus, z_scan, c_bf)

    response_complex = complex(zeros(size(z_scan)));

    for iz = 1:numel(z_scan)
        z_focus = z_scan(iz);

        tau_tx = z_focus / c_bf;
        tau_rx = sqrt((x_focus-element_x).^2 + z_focus^2) / c_bf;
        tau_total = tau_tx + tau_rx;

        focused_samples = sample_channels_linear( ...
            channel_iq, t, fs, tau_total);

        response_complex(iz) = sum(weights .* focused_samples);
    end

    response = abs(response_complex);
end

function values = sample_channels_linear(channel_data, t, fs, query_time)
    % Linear interpolation for uniformly sampled data.
    %
    % channel_data shape: [samples, channels]
    % query_time shape:   [1, channels]
    % output shape:       [1, channels]

    n_samples = size(channel_data,1);
    n_channels = size(channel_data,2);

    assert(numel(query_time) == n_channels, ...
        'query_time must contain one delay per channel.');

    t0 = t(1);

    % MATLAB 1-based fractional sample position.
    u = (query_time - t0) * fs + 1;

    i0 = floor(u);
    alpha = u - i0;

    values = complex(zeros(1,n_channels));

    valid = (i0 >= 1) & (i0 < n_samples);
    ch = 1:n_channels;

    idx0 = sub2ind(size(channel_data), i0(valid), ch(valid));
    idx1 = sub2ind(size(channel_data), i0(valid)+1, ch(valid));

    values(valid) = ...
        (1-alpha(valid)).*channel_data(idx0) + ...
        alpha(valid).*channel_data(idx1);
end
