%% inspect_real_cf_aperture_vectors.m
% Chapter 2 - Inspect REAL delay-aligned receive aperture vectors.
%
% PURPOSE
% -------
% Move from synthetic aperture vectors to real UFF channel data.
%
% For each user-selected pixel on a conventional focused-imaging DAS image:
%
%   one focused Tx / scanline
%       ->
%   Tx delay + Rx delay
%       ->
%   fractional-sample interpolation on every Rx channel
%       ->
%   receive-aperture selection
%       ->
%   aligned complex aperture vector
%       ->
%   DAS coherent sum + CF + aperture spatial spectrum
%
% IMPORTANT
% ---------
% This subsection intentionally uses CONVENTIONAL FI, not RTB.
% That isolates receive-domain coherence:
%
%   one pixel -> one Tx -> many Rx channels
%
% The delay / interpolation / Rx-aperture conventions are matched to
% Chapter 1 reconstruct_fi_scanline_manual.m.
%
% Run:
%   addpath(genpath('D:/USTB'));
%   addpath('../01_DAS_Real_UFF');
%   cd matlab/02_CF_GCF
%   inspect_real_cf_aperture_vectors

clearvars -except filename z_min z_max n_z receive_f_number selected_pixels_mm;
clc;
close all;

if ~exist('filename','var')
    filename = '../../data/L7_FI_TheGB.uff';
end
if ~exist('z_min','var')
    z_min = 5e-3;
end
if ~exist('z_max','var')
    z_max = 45e-3;
end
if ~exist('n_z','var')
    n_z = 512;
end
if ~exist('receive_f_number','var')
    receive_f_number = 1.7;
end

assert(~isempty(which('reconstruct_fi_scanline_manual')), ...
    ['Chapter 1 function reconstruct_fi_scanline_manual.m was not found. ' ...
     'Add matlab/01_DAS_Real_UFF to the MATLAB path.']);

%% ------------------------------------------------------------------------
% 1. Reconstruct the conventional FI reference image
% -------------------------------------------------------------------------
opts = struct();
opts.z_min = z_min;
opts.z_max = z_max;
opts.n_z = n_z;
opts.receive_aperture_mode = 'f_number';
opts.receive_f_number = receive_f_number;
opts.verbose = false;

fprintf('============================================================\n');
fprintf(' REAL RECEIVE-APERTURE CF INSPECTION\n');
fprintf('============================================================\n');
fprintf('Reconstructing Chapter-1 conventional FI-DAS image ...\n');

das = reconstruct_fi_scanline_manual(filename,opts);

%% ------------------------------------------------------------------------
% 2. Read the same UFF data
% -------------------------------------------------------------------------
cd = uff.read_object(filename,'/channel_data');

probe = cd.probe;
sequence = cd.sequence;

fs = cd.sampling_frequency;
t0 = cd.initial_time;
c = cd.sound_speed;

assert(abs(cd.modulation_frequency) < eps, ...
    'This teaching script currently expects real RF data.');
assert(isreal(cd.data), ...
    'This teaching script currently expects real RF channel data.');

%% ------------------------------------------------------------------------
% 3. Let the user choose three pixels
% -------------------------------------------------------------------------
figure('Color','w','Position',[100 100 900 700]);

imagesc( ...
    das.x_axis*1e3, ...
    das.z_axis*1e3, ...
    das.image_db);

set(gca,'YDir','reverse');
axis image;

xlabel('x (mm)');
ylabel('z (mm)');
title({ ...
    'Select THREE pixels', ...
    'Suggested: bright target / speckle / weak or suspicious region'});

caxis([-60 0]);
colorbar;
colormap gray;

fprintf('\nSelect three pixels on the DAS image.\n');
fprintf('Suggested order:\n');
fprintf('  1) bright / point-like target\n');
fprintf('  2) ordinary speckle\n');
fprintf('  3) weak / clutter / suspicious region\n\n');

% For lecture export, use three reproducible [x,z] rows instead of clicks.
if exist('selected_pixels_mm','var')
    assert(isequal(size(selected_pixels_mm),[3 2]) && ...
        all(isfinite(selected_pixels_mm(:))), ...
        'selected_pixels_mm must contain three finite [x,z] rows in mm.');
    x_click_mm = selected_pixels_mm(:,1);
    z_click_mm = selected_pixels_mm(:,2);
else
    [x_click_mm,z_click_mm] = ginput(3);
end

hold on;
plot(x_click_mm,z_click_mm,'o','MarkerSize',10,'LineWidth',1.5);
for k = 1:3
    text( ...
        x_click_mm(k), ...
        z_click_mm(k), ...
        sprintf('  P%d',k), ...
        'FontWeight','bold');
end

%% ------------------------------------------------------------------------
% 4. Extract the REAL aligned aperture vectors
% -------------------------------------------------------------------------
points = repmat(struct(),3,1);

for k = 1:3

    % Conventional FI has one Tx per scanline. Snap the clicked x to the
    % nearest actual transmit/scanline position.
    [~,iw] = min(abs(das.x_axis - x_click_mm(k)*1e-3));

    % Also snap z to the existing Chapter-1 reconstruction grid so that the
    % independently extracted coherent sum can be checked exactly against
    % das.das_analytic(iz,iw).
    [~,iz] = min(abs(das.z_axis - z_click_mm(k)*1e-3));

    x_pixel = das.x_axis(iw);
    z_pixel = das.z_axis(iz);

    wave = sequence(iw);

    rf_wave = double(cd.data(:,:,iw,1));
    analytic_wave = analytic_signal_fft_local(rf_wave);

    % Tx delay: scalar for this conventional scanline pixel.
    tau_tx = focused_tx_delay_spherical_local( ...
        wave,x_pixel,0,z_pixel);

    % Rx delay: one value per receive element.
    rx_distance = sqrt( ...
        (probe.x(:).' - x_pixel).^2 + ...
        (probe.y(:).' - 0).^2 + ...
        (probe.z(:).' - z_pixel).^2);

    tau_rx = rx_distance / c;

    % Shape [1, N_channels].
    query_time = tau_tx + tau_rx;

    [focused_samples,valid] = ...
        sample_channels_linear_uniform_local( ...
            analytic_wave,t0,fs,query_time);

    rx_weights = receive_weights_local( ...
        probe.x(:).', ...
        x_pixel, ...
        z_pixel, ...
        receive_f_number);

    rx_weights(~valid) = 0;

    active = rx_weights > 0;

    s = focused_samples(active);
    active_channels = find(active);

    M = numel(s);

    coherent_sum = sum(s);
    incoherent_energy = sum(abs(s).^2);

    CF = abs(coherent_sum).^2 / ...
        (M*incoherent_energy + eps);

    % Aperture spatial spectrum.
    X = fftshift(fft(s));
    spectrum = abs(X).^2;
    spectrum = spectrum/(sum(spectrum)+eps);

    spatial_bin = ...
        (-floor(M/2)):(ceil(M/2)-1);

    % Verify this aperture vector reproduces the Chapter-1 DAS pixel.
    das_reference = das.das_analytic(iz,iw);

    reconstruction_abs_error = ...
        abs(coherent_sum-das_reference);

    % A relative error normalized only by |DAS| is numerically unstable
    % when the coherent sum is small because of channel cancellation.
    % Use the total active-aperture magnitude as the primary scale.
    aperture_scale = sum(abs(s));

    reconstruction_scaled_error = ...
        reconstruction_abs_error / ...
        (aperture_scale + eps);

    reconstruction_das_relative_error = ...
        reconstruction_abs_error / ...
        (abs(das_reference) + eps);

    assert(reconstruction_scaled_error < 1e-10, ...
        ['Extracted aperture vector does not reproduce Chapter-1 DAS. ' ...
         'Aperture-scaled complex error = %.3e'], ...
        reconstruction_scaled_error);

    points(k).iw = iw;
    points(k).iz = iz;

    points(k).x = x_pixel;
    points(k).z = z_pixel;

    points(k).tau_tx = tau_tx;
    points(k).tau_rx = tau_rx;
    points(k).query_time = query_time;

    points(k).active_channels = active_channels;
    points(k).samples = s;

    points(k).M = M;
    points(k).coherent_sum = coherent_sum;
    points(k).CF = CF;

    points(k).spatial_bin = spatial_bin;
    points(k).spectrum = spectrum;

    points(k).das_reference = das_reference;
    points(k).absolute_check_error = reconstruction_abs_error;
    points(k).aperture_scaled_check_error = reconstruction_scaled_error;
    points(k).das_relative_check_error = reconstruction_das_relative_error;

    fprintf('P%d\n',k);
    fprintf('  clicked       : x %.3f mm, z %.3f mm\n', ...
        x_click_mm(k),z_click_mm(k));
    fprintf('  snapped pixel : x %.3f mm, z %.3f mm\n', ...
        x_pixel*1e3,z_pixel*1e3);
    fprintf('  Tx / scanline : %d\n',iw);
    fprintf('  active Rx     : %d / %d\n',M,cd.N_channels);
    fprintf('  CF            : %.6f\n',CF);
    fprintf('  |DAS sum|     : %.6g\n',abs(coherent_sum));
    fprintf('  DAS abs err   : %.3e\n',reconstruction_abs_error);
    fprintf('  scaled err    : %.3e (primary check)\n', ...
        reconstruction_scaled_error);
    fprintf('  DAS-rel err   : %.3e (can inflate near cancellation)\n\n', ...
        reconstruction_das_relative_error);
end

%% ------------------------------------------------------------------------
% 5. Plot the three real aperture vectors
% -------------------------------------------------------------------------
figure('Color','w','Position',[40 40 1500 1050]);

for k = 1:3

    p = points(k);

    ch = p.active_channels;
    s = p.samples;

    % -------------------------------------------------------------
    % Column 1: query-time / delay curve
    % -------------------------------------------------------------
    subplot(3,4,(k-1)*4+1);

    plot( ...
        ch, ...
        p.query_time(ch)*1e6, ...
        'o-','LineWidth',1);

    xlabel('Active Rx channel');
    ylabel('RF query time (\mus)');
    title(sprintf('P%d: Tx+Rx delay',k));
    grid on;

    % -------------------------------------------------------------
    % Column 2: amplitude and phase across the aperture
    % -------------------------------------------------------------
    subplot(3,4,(k-1)*4+2);

    yyaxis left;
    plot(ch,abs(s),'o-','LineWidth',1);
    ylabel('|aligned sample|');

    yyaxis right;
    plot(ch,angle(s)*180/pi,'.-','LineWidth',1);
    ylabel('Phase (deg)');

    xlabel('Active Rx channel');
    title(sprintf('Aligned aperture, CF=%.3f',p.CF));
    grid on;

    % -------------------------------------------------------------
    % Column 3: complex phasors
    % -------------------------------------------------------------
    subplot(3,4,(k-1)*4+3);
    hold on;

    scale = max(abs(s));
    if scale <= eps
        scale = 1;
    end

    s_plot = s/scale;

    for q = 1:numel(s_plot)
        plot( ...
            [0 real(s_plot(q))], ...
            [0 imag(s_plot(q))], ...
            '-');

        plot( ...
            real(s_plot(q)), ...
            imag(s_plot(q)), ...
            '.', ...
            'MarkerSize',10);
    end

    axis equal;
    xlim([-1.1 1.1]);
    ylim([-1.1 1.1]);

    xlabel('Real');
    ylabel('Imag');
    title('Normalized complex phasors');
    grid on;

    % -------------------------------------------------------------
    % Column 4: aperture spatial spectrum
    % -------------------------------------------------------------
    subplot(3,4,(k-1)*4+4);

    stem( ...
        p.spatial_bin, ...
        p.spectrum, ...
        'filled');

    xlabel('Aperture FFT bin');
    ylabel('Normalized energy');
    title('Spatial spectrum');
    grid on;
end

sgtitle({ ...
    'REAL delay-aligned receive aperture vectors', ...
    'One conventional FI pixel = one Tx + many aligned Rx samples'});

%% ------------------------------------------------------------------------
% 6. Compact summary
% -------------------------------------------------------------------------
fprintf('============================================================\n');
fprintf(' SUMMARY\n');
fprintf('============================================================\n');

for k = 1:3
    fprintf(['P%d: x=%7.3f mm, z=%7.3f mm, Tx=%3d, ' ...
             'active Rx=%3d, CF=%.4f\n'], ...
        k, ...
        points(k).x*1e3, ...
        points(k).z*1e3, ...
        points(k).iw, ...
        points(k).M, ...
        points(k).CF);
end

fprintf('\nWhat to inspect:\n');
fprintf(['  1) query-time curves differ across Rx elements because each element\n' ...
         '     has a different receive propagation distance.\n']);
fprintf(['  2) after those delays are applied, a well-focused pixel should show\n' ...
         '     more consistent complex phase across the active aperture.\n']);
fprintf(['  3) CF measures that consistency; it is not simply signal amplitude.\n']);
fprintf(['  4) coherent aperture vectors concentrate more spatial-spectrum\n' ...
         '     energy near DC; this will lead directly to GCF.\n']);

%% =========================================================================
% Local functions
% =========================================================================

function tau_tx = focused_tx_delay_spherical_local(wave,x,y,z)

    sx = wave.source.x;
    sy = wave.source.y;
    sz = wave.source.z;

    d = sqrt( ...
        (sx-x).^2 + ...
        (sy-y).^2 + ...
        (sz-z).^2);

    if z < sz
        signed_d = -d;
    else
        signed_d = d;
    end

    source_reference_distance = wave.source.distance;

    tau_tx = ...
        (signed_d + source_reference_distance) ...
        / wave.sound_speed ...
        - wave.delay;
end

function [values,valid] = ...
    sample_channels_linear_uniform_local( ...
        channel_data,t0,fs,query_time)

    N_samples = size(channel_data,1);
    N_channels = size(channel_data,2);

    assert(numel(query_time) == N_channels, ...
        'query_time must have one value per receive channel.');

    u = (query_time-t0)*fs + 1;

    i0 = floor(u);
    alpha = u-i0;

    valid = i0 >= 1 & i0 < N_samples;

    values = complex(zeros(1,N_channels));

    ch = 1:N_channels;

    idx0 = sub2ind( ...
        size(channel_data), ...
        i0(valid), ...
        ch(valid));

    idx1 = sub2ind( ...
        size(channel_data), ...
        i0(valid)+1, ...
        ch(valid));

    values(valid) = ...
        (1-alpha(valid)).*channel_data(idx0) + ...
        alpha(valid).*channel_data(idx1);
end

function w = receive_weights_local( ...
    element_x,x_pixel,z_pixel,f_number)

    aperture_width = z_pixel/f_number;
    half_width = aperture_width/2;

    w = double( ...
        abs(element_x-x_pixel) <= half_width);

    if ~any(w)
        [~,idx] = min(abs(element_x-x_pixel));
        w(idx) = 1;
    end
end

function xa = analytic_signal_fft_local(x)

    N = size(x,1);
    X = fft(x,[],1);

    h = zeros(N,1);

    if mod(N,2) == 0
        h(1) = 1;
        h(N/2+1) = 1;
        h(2:N/2) = 2;
    else
        h(1) = 1;
        h(2:(N+1)/2) = 2;
    end

    xa = ifft(X.*h,[],1);
end
