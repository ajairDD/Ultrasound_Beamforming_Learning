%% demo_cf_aperture_vectors.m
% Chapter 2 - Coherence Factor intuition from simple aperture vectors.
%
% No USTB and no external data are required.
%
% Each vector represents the delay-aligned complex receive samples for ONE
% candidate pixel:
%
%   s = [s1, s2, ... , sM]
%
% CF = |sum(s)|^2 / (M * sum(|s|^2))

clear;
clc;
close all;

M = 32;
m = 0:M-1;

rng(1);

cases = cell(4,1);
names = cell(4,1);

% 1. Perfect coherence.
cases{1} = ones(1,M);
names{1} = 'Fully coherent';

% 2. Mostly coherent: smooth phase error across aperture.
phase_error = 0.45*sin(2*pi*m/(M-1));
cases{2} = exp(1j*phase_error);
names{2} = 'Partially coherent';

% 3. Random phase.
cases{3} = exp(1j*2*pi*rand(1,M));
names{3} = 'Random phase';

% 4. One strong amplitude/phase outlier.
cases{4} = ones(1,M);
cases{4}(round(M*0.72)) = 3*exp(1j*pi);
names{4} = 'One strong outlier';

fprintf('============================================================\n');
fprintf(' CF APERTURE-VECTOR DEMO\n');
fprintf('============================================================\n');

figure('Color','w','Position',[80 80 1300 900]);

for k = 1:4

    s = cases{k};

    coherent_sum = sum(s);
    incoherent_energy = sum(abs(s).^2);

    CF = abs(coherent_sum).^2 / ...
        (M*incoherent_energy + eps);

    X = fftshift(fft(s));
    spectrum = abs(X).^2;
    spectrum = spectrum/(sum(spectrum)+eps);

    fprintf('%-22s : CF = %.6f | |DAS sum| = %.6f\n', ...
        names{k},CF,abs(coherent_sum));

    subplot(4,3,(k-1)*3+1);
    stem(1:M,angle(s)*180/pi,'filled');
    xlabel('Receive channel');
    ylabel('Phase (deg)');
    title(names{k});
    ylim([-190 190]);
    grid on;

    subplot(4,3,(k-1)*3+2);
    hold on;
    for ch = 1:M
        plot([0 real(s(ch))],[0 imag(s(ch))],'-');
        plot(real(s(ch)),imag(s(ch)),'.','MarkerSize',12);
    end
    axis equal;
    xlim([-3.2 3.2]);
    ylim([-3.2 3.2]);
    xlabel('Real');
    ylabel('Imag');
    title(sprintf('Phasors, CF = %.3f',CF));
    grid on;

    subplot(4,3,(k-1)*3+3);
    spatial_bin = (-floor(M/2)):(ceil(M/2)-1);
    stem(spatial_bin,spectrum,'filled');
    xlabel('Aperture spatial-frequency bin');
    ylabel('Normalized energy');
    title('Aperture spatial spectrum');
    grid on;
end

sgtitle({ ...
    'Coherence Factor intuition', ...
    'After correct delay, coherent echoes align across the receive aperture'});

fprintf('\nInterpretation:\n');
fprintf(['  CF near 1: most channel energy contributes coherently to the sum.\n' ...
         '  CF near 0: channels contain energy, but much of it cancels.\n' ...
         '  A coherent aperture vector concentrates spectrum near DC.\n' ...
         '  GCF generalizes this by integrating a low-frequency band.\n']);
