%% demo_cf_failure_and_gcf_motivation.m
% Chapter 2 - Why ordinary CF can be too strict, and why GCF was proposed.
%
% This is a synthetic receive-aperture experiment.
%
% We compare several delay-aligned complex aperture vectors:
%
%   A) perfect coherence
%   B) smooth phase ramp (deterministic, not random)
%   C) random phase
%
% Ordinary CF mainly rewards energy exactly at aperture-FFT DC.
% A smooth phase ramp can shift most energy from DC into a nearby
% low-spatial-frequency bin. CF then drops sharply even though the aperture
% pattern still has strong low-order structure.
%
% GCF generalizes the idea by integrating a small low-frequency band around
% DC instead of only the DC bin.
%
% Teaching definition used here:
%
%   GCF(K) =
%       energy in FFT bins [-K, ..., 0, ..., +K]
%       ------------------------------------------------
%       total aperture-spectrum energy
%
% Therefore:
%
%   K = 0  -> exactly CF
%
% This script is a concept demo only. Later Chapter 2 code will map the
% teaching K convention explicitly to USTB / literature parameter naming.

clear;
clc;
close all;

M = 64;
m = 0:M-1;

rng(2);

cases = cell(3,1);
names = cell(3,1);

% A. Perfectly coherent.
cases{1} = ones(1,M);
names{1} = 'Perfect coherence';

% B. Deterministic smooth phase ramp.
% Exactly one aperture-FFT bin of phase progression across M channels.
cases{2} = exp(1j*2*pi*m/M);
names{2} = 'Smooth 1-bin phase ramp';

% C. Random phase.
cases{3} = exp(1j*2*pi*rand(1,M));
names{3} = 'Random phase';

K_values = [0 1 2 4];

fprintf('============================================================\n');
fprintf(' CF LIMITATION AND GCF MOTIVATION\n');
fprintf('============================================================\n');

figure('Color','w','Position',[50 50 1500 900]);

for k = 1:numel(cases)

    s = cases{k};

    X = fftshift(fft(s));
    power_spec = abs(X).^2;
    total_power = sum(power_spec);

    bins = (-floor(M/2)):(ceil(M/2)-1);

    CF = abs(sum(s)).^2 / ...
        (M*sum(abs(s).^2)+eps);

    GCF = zeros(size(K_values));

    for q = 1:numel(K_values)

        K = K_values(q);

        low_mask = abs(bins) <= K;

        GCF(q) = ...
            sum(power_spec(low_mask)) / ...
            (total_power+eps);
    end

    fprintf('\n%s\n',names{k});
    fprintf('  CF          : %.6f\n',CF);

    for q = 1:numel(K_values)
        fprintf('  GCF K=%d     : %.6f\n', ...
            K_values(q),GCF(q));
    end

    % Phase across aperture
    subplot(3,3,(k-1)*3+1);

    plot(m,unwrap(angle(s))*180/pi,'o-','LineWidth',1.2);

    xlabel('Receive element index');
    ylabel('Unwrapped phase (deg)');
    title(names{k});
    grid on;

    % Complex phasors
    subplot(3,3,(k-1)*3+2);
    hold on;

    for ch = 1:M

        plot( ...
            [0 real(s(ch))], ...
            [0 imag(s(ch))], ...
            '-');

        plot( ...
            real(s(ch)), ...
            imag(s(ch)), ...
            '.', ...
            'MarkerSize',8);
    end

    axis equal;
    xlim([-1.1 1.1]);
    ylim([-1.1 1.1]);

    xlabel('Real');
    ylabel('Imag');
    title(sprintf('CF = %.3f',CF));
    grid on;

    % Aperture spectrum
    subplot(3,3,(k-1)*3+3);

    stem( ...
        bins, ...
        power_spec/(total_power+eps), ...
        'filled');

    hold on;
    xline(-1,':');
    xline(1,':');

    xlabel('Aperture FFT bin');
    ylabel('Normalized spectral energy');
    title(sprintf( ...
        'GCF K=1 = %.3f',GCF(K_values==1)));

    xlim([-10 10]);
    grid on;
end

sgtitle({ ...
    'Why GCF generalizes ordinary CF', ...
    'CF only rewards DC; GCF can include neighboring low spatial frequencies'});

%% ------------------------------------------------------------------------
% 4. Plot CF / GCF values directly
% -------------------------------------------------------------------------
values = zeros(numel(cases),numel(K_values));

for k = 1:numel(cases)

    s = cases{k};

    X = fftshift(fft(s));
    power_spec = abs(X).^2;
    total_power = sum(power_spec);

    bins = (-floor(M/2)):(ceil(M/2)-1);

    for q = 1:numel(K_values)

        low_mask = abs(bins) <= K_values(q);

        values(k,q) = ...
            sum(power_spec(low_mask)) / ...
            (total_power+eps);
    end
end

figure('Color','w','Position',[150 150 900 520]);

for k = 1:numel(cases)
    plot( ...
        K_values, ...
        values(k,:), ...
        'o-', ...
        'LineWidth',1.5);
    hold on;
end

xlabel('Low-frequency half-width K');
ylabel('Coherence weight');
title('CF is the K=0 special case of the teaching GCF definition');
legend(names,'Location','best');
ylim([0 1.05]);
grid on;

fprintf('\nInterpretation:\n');
fprintf(['  Perfect coherence stays near 1 even for K=0 because its spectrum\n' ...
         '  is concentrated exactly at DC.\n']);
fprintf(['  A smooth phase ramp can have CF near 0 because its spectral peak\n' ...
         '  moved from DC to a neighboring low-frequency bin.\n']);
fprintf(['  GCF with a small K can recognize that low-order structure.\n']);
fprintf(['  Increasing K too far is not automatically better: eventually more\n' ...
         '  incoherent / high-frequency energy is also admitted.\n']);
