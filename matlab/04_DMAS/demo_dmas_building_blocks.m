function report = demo_dmas_building_blocks
%DEMO_DMAS_BUILDING_BLOCKS Six reproducible illustrations of real-RF DMAS.
% No USTB, UFF data, or Signal Processing Toolbox is needed. These are
% deterministic numerical examples, not measured acoustic beam patterns.
% Run directly, or export_chapter4_figures('concepts') to save the PNGs.
rng(4);
close all;
report = struct();

%% 1. Every unordered pair appears once; a global sign change is invisible
S = [ones(1,4); -ones(1,4); 1 -1 1 -1];
labels = {'All +1','All -1','Alternating signs'};
expected = [6 6 -2];
figure('Color','w','Position',[40 40 1400 760]);
tiledlayout(2,3,'TileSpacing','compact','Padding','compact');
for k = 1:3
    s = S(k,:);
    nexttile(k);
    stem(1:4,s,'filled','LineWidth',1.8);
    ylim([-1.4 1.4]); xticks(1:4); grid on;
    xlabel('Active Rx channel'); ylabel('Real RF sample'); title(labels{k});
    U = sign(s).*sqrt(abs(s));
    pairs = U.'*U;
    upper = triu(true(4),1);
    nexttile(k+3);
    h = imagesc(pairs); set(h,'AlphaData',upper);
    set(gca,'Color',[0.9 0.9 0.9]); axis image;
    colormap(gca,[0.85 0.35 0.12; 1 1 1; 0.1 0.55 0.75]); caxis([-1 1]);
    xticks(1:4); yticks(1:4); xlabel('j'); ylabel('i');
    for i = 1:4
        for j = i+1:4
            text(j,i,sprintf('%+d',pairs(i,j)), ...
                'HorizontalAlignment','center','FontWeight','bold','FontSize',14);
        end
    end
    value = sum(pairs(upper));
    assert(value == expected(k) && nnz(upper) == 6);
    title(sprintf('Six pairs: DAS = %g, DMAS = %g',sum(s),value));
end
sgtitle({'Four-channel signed-sqrt examples: the upper triangle is the pair sum', ...
    'Raw scalar samples, not envelopes; the lower triangle and diagonal are excluded'});
report.four_channel_pair_sums = expected;

%% 2. O(M) identity, absolute homogeneity, and coherent-aperture scaling
max_identity_error = 0;
max_relative_error = 0;
sizes = [2 4 8 16 32 64];
for M = sizes
    for trial = 1:12
        s = randn(1,M); s(1) = 0;
        slow = explicit_pairs(s);
        fast = fast_pairs(s);
        max_identity_error = max(max_identity_error,abs(slow-fast));
        max_relative_error = max(max_relative_error, ...
            abs(slow-fast)/max(1,sum(abs(sign(s).*sqrt(abs(s))))^2));
    end
end
assert(max_relative_error < 1e-13,'Pair/reduction equality failed.');
s = [-2 0.5 1.3 -0.8 0 2.2];
scales = linspace(-3,3,121);
values = arrayfun(@(a) fast_pairs(a*s),scales);
predicted = abs(scales)*fast_pairs(s);
assert(max(abs(values-predicted)) < 1e-12);
assert(abs(fast_pairs(-s)-fast_pairs(s)) < 1e-12);
M_grid = 2:64;
raw = arrayfun(@(M) fast_pairs(ones(1,M)),M_grid);
normalized = 2*raw./(M_grid-1);
assert(max(abs(normalized-M_grid)) < 1e-12);
figure('Color','w','Position',[60 60 1400 650]);
tiledlayout(2,2,'TileSpacing','compact','Padding','compact');
nexttile([2 1]);
plot(scales,values,'LineWidth',2); hold on;
plot(scales,predicted,'--','LineWidth',1.5); grid on;
xlabel('Real input scale a'); ylabel('Unnormalized DMAS sample');
title('DMAS(a s) = |a| DMAS(s): not a linear operator');
legend('Computed pair reduction','Absolute-scale prediction','Location','best');
nexttile(2);
plot(M_grid,raw,'LineWidth',1.8); hold on;
grid on; xlabel('Active receive count M'); ylabel('Unnormalized output');
title('Raw pair sum for s_i = +1: M(M-1)/2');
nexttile(4);
plot(M_grid,normalized,'LineWidth',1.8); hold on;
plot(M_grid,M_grid,'k--','LineWidth',1.5); grid on;
xlabel('Active receive count M'); ylabel('Normalized output');
title('Project scaling: normalized output = M for s_i = +1');
legend('2/(M-1) times pair sum','DAS = M','Location','northwest');
sgtitle('The fast identity is exact algebra; floating-point results use a tolerance');
report.max_pair_identity_absolute_error = max_identity_error;
report.max_pair_identity_scaled_error = max_relative_error;

%% 3. Identical sinusoidal RF: square versus signed-sqrt pairing
f0 = 5e6;
fs = 160e6;
N = 2048;
t = (0:N-1).'/fs;
M = 8;
sine = cos(2*pi*f0*t);
Srf = repmat(sine,1,M);
raw_pair = 0.5*(sum(Srf,2).^2-sum(Srf.^2,2));
signed_pair = pair_rows(Srf);
normalized = 2*signed_pair/(M-1);
assert(max(abs(normalized-M*abs(sine))) < 1e-12);
[freq,spec_rf] = amplitude_spectrum(sine,fs);
[~,spec_squared] = amplitude_spectrum(raw_pair,fs);
[~,spec_signed] = amplitude_spectrum(signed_pair,fs);
figure('Color','w','Position',[80 80 1400 760]);
tiledlayout(2,2,'TileSpacing','compact','Padding','compact');
nexttile;
plot(t*1e6,sine,'LineWidth',1.6); xlim([0 0.8]); grid on;
xlabel('Synthetic fast time (us)'); ylabel('RF amplitude');
title('All eight channels have this same RF waveform');
nexttile;
plot(t*1e6,raw_pair/max(raw_pair),'LineWidth',1.6); hold on;
plot(t*1e6,normalized/M,'LineWidth',1.6); xlim([0 0.8]); grid on;
xlabel('Synthetic fast time (us)'); ylabel('Each curve / own maximum');
title('Pair outputs are even under global sign reversal');
legend('Plain product ~ cos^2','Signed-sqrt ~ |cos|','Location','southwest');
nexttile;
plot(freq/f0,db_self(spec_rf),'LineWidth',1.5); hold on;
plot(freq/f0,db_self(spec_squared),'LineWidth',1.5);
xlim([0 6]); ylim([-70 3]); grid on;
xlabel('Frequency / f0'); ylabel('Own-peak spectral magnitude (dB)');
title('Plain cosine multiplication: DC and 2f0');
legend('Input RF','Plain pair product','Location','best');
nexttile;
plot(freq/f0,db_self(spec_signed),'LineWidth',1.6);
xline(2,'--','2f0'); xline(4,':','4f0');
xlim([0 6]); ylim([-70 3]); grid on;
xlabel('Frequency / f0'); ylabel('Own-peak spectral magnitude (dB)');
title('Signed square roots add higher even harmonics');
sgtitle('Synthetic periodic example: the 2f0 component is generated digitally');
report.identical_rf_rectification_error = max(abs(normalized-M*abs(sine)));

%% 4. A pulse needs filtering BEFORE analytic-envelope detection
t = (0:2047).'/fs;
t_center = 6.4e-6;
pulse_envelope = exp(-0.5*((t-t_center)/(0.32e-6)).^2);
rf = pulse_envelope.*cos(2*pi*f0*(t-t_center));
raw = 2*pair_rows(repmat(rf,1,M))/(M-1);
[filtered,H,f_abs] = bandpass_2f0(raw,fs,f0);
wrong_envelope = abs(analytic_signal(raw));
good_envelope = abs(analytic_signal(filtered));
figure('Color','w','Position',[100 100 1400 790]);
tiledlayout(2,2,'TileSpacing','compact','Padding','compact');
nexttile;
plot((t-t_center)*1e6,raw,'LineWidth',1.5); hold on;
plot((t-t_center)*1e6,filtered,'LineWidth',1.5);
xlim([-1.2 1.2]); grid on;
xlabel('Time relative to pulse center (us)'); ylabel('Stage amplitude');
title('Raw DMAS contains a large non-oscillatory component');
legend('Unfiltered normalized DMAS','2f0-band output','Location','best');
nexttile;
[f,raw_spec] = amplitude_spectrum(raw,fs);
[~,filtered_spec] = amplitude_spectrum(filtered,fs);
plot(f/f0,20*log10(max(raw_spec/max(raw_spec),1e-5)),'LineWidth',1.5); hold on;
plot(f/f0,20*log10(max(filtered_spec/max(raw_spec),1e-5)),'LineWidth',1.5);
xlim([0 5]); ylim([-80 3]); grid on;
xlabel('Frequency / f0'); ylabel('Magnitude / raw-DMAS spectral peak (dB)');
title('Common spectral reference shows removal of low frequency');
legend('Before bandpass','After bandpass','Location','best');
nexttile;
plot((t-t_center)*1e6,wrong_envelope/max(wrong_envelope),'LineWidth',1.6); hold on;
plot((t-t_center)*1e6,good_envelope/max(good_envelope),'LineWidth',1.6);
plot((t-t_center)*1e6,pulse_envelope,'k--','LineWidth',1.5);
xlim([-1.5 1.5]); grid on;
xlabel('Time relative to pulse center (us)'); ylabel('Each curve / own maximum');
title('abs(analytic(raw DMAS)) is a different operation');
legend('Envelope without the bandpass','fDMAS envelope','Input pulse envelope', ...
    'Location','best');
nexttile;
positive = (0:numel(H)/2).';
plot(f_abs(positive+1)/f0,H(positive+1),'LineWidth',2);
xlim([0 4]); ylim([-0.05 1.1]); grid on;
xticks([0 1.5 1.75 2 2.5 2.75 4]);
xlabel('Frequency / f0'); ylabel('Real, even FFT mask');
title('Edges [1.5 1.75 2.5 2.75] f0');
sgtitle('Synthetic pulse: isolate the chosen band, then form its analytic envelope');
assert(max(H(f_abs<1.5*f0)) == 0);
report.synthetic_filter_stopband_max = max(H(f_abs<1.5*f0));

%% 5. Raw RF sampling and output image-depth sampling are different axes
c = 1540;
lambda = c/f0;
dz_values = [lambda/4 lambda/16];
fs_image = c./(2*dz_values);
figure('Color','w','Position',[120 120 1400 700]);
tiledlayout(2,2,'TileSpacing','compact','Padding','compact');
for k = 1:2
    nexttile(k);
    z = (0:round(2*lambda/dz_values(k))).'*dz_values(k);
    % A 2f0 sinusoid in the approximate image-time coordinate 2z/c.
    z_dense = linspace(0,2*lambda,1001).';
    plot(z_dense/lambda,cos(2*pi*2*f0*(2*z_dense/c)),'Color',[0.6 0.6 0.6]); hold on;
    stem(z/lambda,cos(2*pi*2*f0*(2*z/c)),'filled','LineWidth',1.3);
    xlabel('Depth / wavelength'); ylabel('2f0 sample'); grid on;
    if k == 1, title('dz = lambda/4: 2f0 aliases to constant samples');
    else, title('dz = lambda/16: four samples per 2f0 cycle'); end
    nexttile(k+2);
    patch([1.5 1.75 2.5 2.75],[0 1 1 0],[0.55 0.45 0.8], ...
        'FaceAlpha',0.3,'EdgeColor',[0.4 0.2 0.65],'LineWidth',1.5); hold on;
    xline(fs_image(k)/(2*f0),'r--','Image-grid Nyquist','LineWidth',1.8);
    xlim([0 4.5]); ylim([0 1.2]); grid on;
    xlabel('Frequency / f0'); ylabel('Chosen filter gain');
    title(sprintf('fs,z = %.1f f0; Nyquist = %.1f f0', ...
        fs_image(k)/f0,fs_image(k)/(2*f0)));
end
sgtitle({'Image time approximately 2z/c; fs,z = c/(2 dz)', ...
    'A finer output grid does not restore missing information in the acquired RF'});
assert(fs_image(1)/2 < 2.75*f0 && fs_image(2)/2 > 2.75*f0);
report.coarse_nyquist_over_f0 = fs_image(1)/(2*f0);
report.fine_nyquist_over_f0 = fs_image(2)/(2*f0);

%% 6. A phase error changes both methods, including genuine target response
M = 16;
q = linspace(0,0.25,151); % Residual cycles/channel, NOT an acoustic angle.
n = 0:M-1;
das_gain = zeros(size(q));
fdmas_gain = zeros(size(q));
for k = 1:numel(q)
    S = pulse_envelope.*cos(2*pi*f0*(t-t_center)+2*pi*q(k)*n);
    das_env = abs(analytic_signal(sum(S,2)));
    raw = 2*pair_rows(S)/(M-1);
    filtered = bandpass_2f0(raw,fs,f0);
    fd_env = abs(analytic_signal(filtered));
    das_gain(k) = max(das_env);
    fdmas_gain(k) = max(fd_env);
end
das_gain = das_gain/das_gain(1);
fdmas_gain = fdmas_gain/fdmas_gain(1);
assert(abs(das_gain(1)-1) < eps && abs(fdmas_gain(1)-1) < eps);
figure('Color','w','Position',[140 140 1400 650]);
tiledlayout(1,2,'TileSpacing','compact','Padding','compact');
nexttile;
phase_examples = [0 0.04 0.10];
for k = 1:numel(phase_examples)
    plot(n,2*pi*phase_examples(k)*n,'-o','LineWidth',1.5); hold on;
end
grid on; xlabel('Rx channel index (zero based)'); ylabel('Residual phase (rad)');
title('Aligned signals can still have residual phase mismatch');
legend('q = 0','q = 0.04','q = 0.10','Location','northwest');
nexttile;
plot(q,20*log10(max(das_gain,1e-4)),'LineWidth',1.8); hold on;
plot(q,20*log10(max(fdmas_gain,1e-4)),'LineWidth',1.8);
ylim([-60 3]); grid on;
xlabel('Residual phase slope q (cycles/channel)');
ylabel('Peak envelope / own q=0 reference (dB)');
title('Sensitivity to phase agreement is not a truth detector');
legend('DAS','fDMAS','Location','best');
sgtitle({'Synthetic receive-vector experiment, not an acoustic PSF or SNR test', ...
    'The same coherent receive vector is treated identically whether it comes from a target or clutter'});

fprintf('Deterministic real-RF examples; rng(4); no UFF data.\n');
fprintf('Four-channel DMAS sums: [%g %g %g].\n',expected);
fprintf('Pair identity max absolute / scaled error: %.6e / %.6e.\n', ...
    report.max_pair_identity_absolute_error,report.max_pair_identity_scaled_error);
fprintf('Identical-RF normalized M*abs(s) error: %.6e.\n', ...
    report.identical_rf_rectification_error);
fprintf('Low stopband mask maximum: %.6e.\n',report.synthetic_filter_stopband_max);
fprintf('Image Nyquist / f0, coarse / fine: %.1f / %.1f.\n', ...
    report.coarse_nyquist_over_f0,report.fine_nyquist_over_f0);
fprintf('PASS: explicit pairs, reduction, global-sign invariance, absolute scaling, coherent aperture scaling, sampling examples.\n');
end

function value = fast_pairs(s)
u = sign(s).*sqrt(abs(s));
value = 0.5*(sum(u).^2-sum(u.^2));
end

function value = explicit_pairs(s)
value = 0;
for i = 1:numel(s)-1
    for j = i+1:numel(s)
        p = s(i)*s(j);
        value = value+sign(p)*sqrt(abs(p));
    end
end
end

function value = pair_rows(S)
u = sign(S).*sqrt(abs(S));
value = 0.5*(sum(u,2).^2-sum(u.^2,2));
end

function [filtered,H,f_abs] = bandpass_2f0(raw,fs,f0)
N = size(raw,1);
Npad = 2^nextpow2(2*N);
f = (0:Npad-1).'*fs/Npad;
f_abs = min(f,fs-f);
F = [1.5 1.75 2.5 2.75]*f0;
assert(fs/2 > F(4));
H = zeros(Npad,1);
low = f_abs>=F(1) & f_abs<F(2);
mid = f_abs>=F(2) & f_abs<=F(3);
high = f_abs>F(3) & f_abs<=F(4);
H(low) = 0.5-0.5*cos(pi*(f_abs(low)-F(1))/(F(2)-F(1)));
H(mid) = 1;
H(high) = 0.5+0.5*cos(pi*(f_abs(high)-F(3))/(F(4)-F(3)));
filtered = real(ifft(fft(raw,Npad,1).*H,[],1));
filtered = filtered(1:N,:);
end

function xa = analytic_signal(x)
N = size(x,1);
h = zeros(N,1);
if mod(N,2)==0
    h(1)=1; h(N/2+1)=1; h(2:N/2)=2;
else
    h(1)=1; h(2:(N+1)/2)=2;
end
xa = ifft(fft(x,[],1).*h,[],1);
end

function [f,spectrum] = amplitude_spectrum(x,fs)
N = size(x,1);
idx = (0:floor(N/2)).';
f = idx*fs/N;
X = abs(fft(x,[],1))/N;
spectrum = X(idx+1,:);
end

function db = db_self(x)
db = 20*log10(max(x/max(x),1e-5));
end
