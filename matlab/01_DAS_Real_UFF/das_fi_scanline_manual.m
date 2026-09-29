%% das_fi_scanline_manual.m
% Chapter 1 - direct-run teaching entry for conventional FI-DAS.
%
% The reusable DAS algorithm lives in:
%
%   reconstruct_fi_scanline_manual.m
%
% This script only:
%   1) collects user-facing parameters;
%   2) calls the reusable DAS core;
%   3) exposes familiar workspace variables;
%   4) displays the image and diagnostics.
%
% USTB is still used only for UFF reading inside the reusable core.
%
% Suggested use:
%   addpath(genpath('D:/USTB'));  % change to your own path
%   cd matlab/01_DAS_Real_UFF
%   filename = '../../data/L7_FI_Verasonics_CIRS_points.uff';
%   das_fi_scanline_manual

clearvars -except filename z_min z_max n_z frame_index ...
    receive_aperture_mode receive_f_number;
clc;
close all;

%% User-facing parameters
if ~exist('filename','var')
    filename = '../../data/L7_FI_Verasonics_CIRS_points.uff';
end

if ~exist('z_min','var')
    z_min = 5e-3;
end

if ~exist('z_max','var')
    z_max = 45e-3;
end

if ~exist('n_z','var')
    n_z = 1024;
end

if ~exist('frame_index','var')
    frame_index = 1;
end

if ~exist('receive_aperture_mode','var')
    receive_aperture_mode = 'full';
end

if ~exist('receive_f_number','var')
    receive_f_number = 1.7;
end

display_dynamic_range_db = 60;

%% Call the reusable DAS core
opts = struct();

opts.z_min = z_min;
opts.z_max = z_max;
opts.n_z = n_z;
opts.frame_index = frame_index;

opts.receive_aperture_mode = receive_aperture_mode;
opts.receive_f_number = receive_f_number;

opts.display_dynamic_range_db = display_dynamic_range_db;
opts.verbose = true;

result = reconstruct_fi_scanline_manual(filename,opts);

%% Expose familiar variables for interactive learning
das_analytic = result.das_analytic;
envelope = result.envelope;
image_db = result.image_db;

x_axis = result.x_axis;
z_axis = result.z_axis;

active_channel_count = result.active_channel_count;

%% Display
figure('Color','w');

imagesc(x_axis*1e3,z_axis*1e3,image_db);

set(gca,'YDir','reverse');
axis image;

xlabel('Lateral position x (mm)');
ylabel('Depth z (mm)');

title('Manual conventional FI-DAS');

colorbar;
caxis([-display_dynamic_range_db 0]);
colormap gray;

%% Diagnostics
fprintf('\n=== Diagnostics ===\n');

fprintf('Requested channel samples : %d\n', ...
    result.n_requested);

fprintf('Out-of-record samples     : %d (%.4f%%)\n', ...
    result.n_out_of_range, ...
    100*result.n_out_of_range/max(result.n_requested,1));

fprintf('Active Rx channels range  : %d to %d\n', ...
    min(active_channel_count(:)), ...
    max(active_channel_count(:)));

[~,peak_linear_idx] = max(envelope(:));
[peak_iz,peak_ix] = ind2sub(size(envelope),peak_linear_idx);

fprintf('Global image peak         : x = %.3f mm, z = %.3f mm\n', ...
    x_axis(peak_ix)*1e3, ...
    z_axis(peak_iz)*1e3);

fprintf('\nScientific status:\n');
fprintf(['  This is our own conventional scanline FI-DAS implementation.\n' ...
         '  USTB is used only for UFF reading inside the reusable core.\n' ...
         '  The full-aperture baseline has already been validated against\n' ...
         '  matched USTB conventional DAS on this dataset.\n']);
