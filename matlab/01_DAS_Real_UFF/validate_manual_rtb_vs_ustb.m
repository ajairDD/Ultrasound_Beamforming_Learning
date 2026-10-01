%% validate_manual_rtb_vs_ustb.m
% Chapter 1 - Manual RTB vs USTB reference.
%
% Purpose:
%   Validate our explicit RTB implementation against the official USTB
%   generalized beamformer under matched reconstruction conditions.
%
% This is a CROSS-CHECK, not the main implementation.
%
% Default parameters mirror the IUS-2018 RTB example:
%   x upsample / MLA = 4
%   Tx F#            = 2
%   Tx window        = Tukey25
%   Tx min aperture  = 3 mm
%   hybrid PW margin = 1 mm
%   blended power    = 0.5
%   Rx boxcar F#     = 1.7
%
% To keep first validation runtime reasonable, default n_z = 256.
% Increase to 512 / 1024 after the implementation is verified.

clearvars -except filename z_min z_max n_z x_upsample delay_model blending_power;
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
    n_z = 256;
end
if ~exist('x_upsample','var')
    x_upsample = 4;
end
if ~exist('delay_model','var')
    delay_model = 'blended';
end
if ~exist('blending_power','var')
    blending_power = 0.5;
end

%% ------------------------------------------------------------------------
% 1. Manual RTB
% -------------------------------------------------------------------------
fprintf('============================================================\n');
fprintf(' STEP 1 / 3 - MANUAL %s RTB\n',upper(delay_model));
fprintf('============================================================\n');

opts = struct();

opts.z_min = z_min;
opts.z_max = z_max;
opts.n_z = n_z;
opts.x_upsample = x_upsample;

opts.tx_delay_model = delay_model;
opts.pw_margin = 1e-3;
opts.blending_power = blending_power;

opts.tx_f_number = 2;
opts.tx_min_aperture = 3e-3;
opts.tx_window = 'tukey25';

opts.rx_aperture_mode = 'f_number';
opts.rx_f_number = 1.7;

opts.wave_stride = 1;
opts.normalize_tx_weights = true;
opts.verbose = true;

manual = reconstruct_fi_rtb_manual(filename,opts);

%% ------------------------------------------------------------------------
% 2. USTB RTB reference
% -------------------------------------------------------------------------
fprintf('\n============================================================\n');
fprintf(' STEP 2 / 3 - USTB %s RTB REFERENCE\n',upper(delay_model));
fprintf('============================================================\n');

channel_data = uff.read_object(filename,'/channel_data');

scan_ref = uff.linear_scan( ...
    'x_axis',manual.x_axis, ...
    'z_axis',manual.z_axis);

mid_ref = midprocess.das();

mid_ref.channel_data = channel_data;
mid_ref.scan = scan_ref;

mid_ref.dimension = dimension.both();

switch lower(delay_model)
    case 'spherical'
        mid_ref.spherical_transmit_delay_model = ...
            spherical_transmit_delay_model.spherical;

    case 'hybrid'
        mid_ref.spherical_transmit_delay_model = ...
            spherical_transmit_delay_model.hybrid;
        mid_ref.pw_margin = 1e-3;

    case 'blended'
        mid_ref.spherical_transmit_delay_model = ...
            spherical_transmit_delay_model.blended;
        mid_ref.blending_power = blending_power;

    otherwise
        error('delay_model must be spherical, hybrid, or blended.');
end

mid_ref.transmit_apodization.window = uff.window.tukey25;
mid_ref.transmit_apodization.f_number = 2;
mid_ref.transmit_apodization.MLA = x_upsample;
mid_ref.transmit_apodization.MLA_overlap = 1;
mid_ref.transmit_apodization.minimum_aperture = ...
    [3e-3 3e-3];

mid_ref.receive_apodization.window = uff.window.boxcar;
mid_ref.receive_apodization.f_number = 1.7;

% MATLAB reference avoids hiding interpolation differences in MEX code.
mid_ref.code = code.matlab;

b_ref = mid_ref.go();

% Official RTB example compensates the coherent sum by the sum of Tx
% apodization weights at each pixel.
tx_apod = mid_ref.transmit_apodization.data;
tx_weight_sum = sum(tx_apod,2);

ustb_complex_vec = b_ref.data;

valid = tx_weight_sum > eps;
ustb_complex_vec(valid) = ...
    ustb_complex_vec(valid) ./ tx_weight_sum(valid);

ustb_complex_vec(~valid) = 0;

ustb_complex = reshape( ...
    ustb_complex_vec, ...
    scan_ref.N_z_axis, ...
    scan_ref.N_x_axis);

ustb_env = abs(ustb_complex);

%% ------------------------------------------------------------------------
% 3. Compare
% -------------------------------------------------------------------------
fprintf('\n============================================================\n');
fprintf(' STEP 3 / 3 - COMPARISON\n');
fprintf('============================================================\n');

assert(isequal(size(manual.envelope),size(ustb_env)), ...
    'Manual and USTB RTB image sizes differ.');

manual_norm = manual.envelope / ...
    (max(manual.envelope(:))+eps);

ustb_norm = ustb_env / ...
    (max(ustb_env(:))+eps);

diff_linear = manual_norm-ustb_norm;

mae = mean(abs(diff_linear(:)));
rmse = sqrt(mean(diff_linear(:).^2));
maxerr = max(abs(diff_linear(:)));

a = manual_norm(:);
b = ustb_norm(:);

a0 = a-mean(a);
b0 = b-mean(b);

corr_env = sum(a0.*b0) / ...
    sqrt(sum(a0.^2)*sum(b0.^2)+eps);

[~,im] = max(manual.envelope(:));
[izm,ixm] = ind2sub(size(manual.envelope),im);

[~,iu] = max(ustb_env(:));
[izu,ixu] = ind2sub(size(ustb_env),iu);

fprintf('Image size                : [%d x %d]\n', ...
    size(manual.envelope,1),size(manual.envelope,2));

fprintf('Envelope correlation      : %.9f\n',corr_env);
fprintf('Mean abs normalized error : %.9g\n',mae);
fprintf('RMSE normalized error     : %.9g\n',rmse);
fprintf('Max abs normalized error  : %.9g\n',maxerr);

fprintf('\nManual peak : x %.4f mm, z %.4f mm\n', ...
    manual.x_axis(ixm)*1e3,manual.z_axis(izm)*1e3);

fprintf('USTB peak   : x %.4f mm, z %.4f mm\n', ...
    manual.x_axis(ixu)*1e3,manual.z_axis(izu)*1e3);

fprintf('Peak delta  : dx %.4f mm, dz %.4f mm\n', ...
    (manual.x_axis(ixm)-manual.x_axis(ixu))*1e3, ...
    (manual.z_axis(izm)-manual.z_axis(izu))*1e3);

manual_db = to_db(manual.envelope,60);
ustb_db = to_db(ustb_env,60);

figure('Color','w');

subplot(1,2,1);
imagesc(manual.x_axis*1e3,manual.z_axis*1e3,manual_db);
set(gca,'YDir','reverse');
axis image;
xlabel('x (mm)');
ylabel('z (mm)');
title(sprintf('Manual %s RTB',delay_model));
caxis([-60 0]);
colorbar;

subplot(1,2,2);
imagesc(manual.x_axis*1e3,manual.z_axis*1e3,ustb_db);
set(gca,'YDir','reverse');
axis image;
xlabel('x (mm)');
ylabel('z (mm)');
title(sprintf('USTB %s RTB',delay_model));
caxis([-60 0]);
colorbar;
colormap gray;

figure('Color','w');

imagesc( ...
    manual.x_axis*1e3, ...
    manual.z_axis*1e3, ...
    abs(diff_linear));

set(gca,'YDir','reverse');
axis image;
xlabel('x (mm)');
ylabel('z (mm)');
title('|Manual RTB normalized envelope - USTB|');
colorbar;

fprintf(['\nDo not declare RTB validated from visual similarity alone.\n' ...
    'Use correlation, error magnitude, peak location, and the difference\n' ...
    'map together. If mismatch is material, inspect Tx apodization/origin\n' ...
    'first, then the selected Tx delay model and interpolation.\n']);

%% Local helper
function db_img = to_db(env,dynamic_range)
    env = env/(max(env(:))+eps);
    db_img = 20*log10(env+eps);
    db_img(db_img < -dynamic_range) = -dynamic_range;
end
