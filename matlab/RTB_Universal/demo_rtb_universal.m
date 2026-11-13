function out = demo_rtb_universal(source,cfg)
%DEMO_RTB_UNIVERSAL One-call all-method RTB reconstruction + figures.
%
% Example for supplied TheGB UFF (fast local ROI):
%   addpath(genpath('D:/YOUR_USTB_PATH'));
%   cd matlab/RTB_Universal
%   demo_rtb_universal
%
% Example for a vendor's already-normalized canonical acquisition:
%   out=demo_rtb_universal(acq,cfg);
%
% Source can be UFF filename, MAT filename containing 'acq', or acq
% struct built with rtb_from_vendor_array.
%
% Default preview does NOT claim full-FOV clinical quality. To reconstruct
% larger/full-FOV grids set cfg.x_range_m/z_range_m/n_x/n_z/selected_tx and
% explicitly authorize larger compute via cfg.allow_large=true.

    if nargin<1 || isempty(source)
        source='../../data/L7_FI_TheGB.uff';
    end
    if nargin<2 || isempty(cfg)
        cfg=struct();
    end

    if (ischar(source) || isstring(source)) && ...
           contains(lower(char(source)),'l7_fi_thegb')
        % A known reproducible point-target ROI used in earlier chapters.
        if ~isfield(cfg,'x_range_m'),cfg.x_range_m=[-4,3]*1e-3;end
        if ~isfield(cfg,'z_range_m'),cfg.z_range_m=[18,22.5]*1e-3;end
        if ~isfield(cfg,'n_x'),cfg.n_x=64;end
        if ~isfield(cfg,'wave_stride'),cfg.wave_stride=4;end
    end

    if ~isfield(cfg,'methods')
        cfg.methods={'DAS','CF','GCF','MVDR','FDMAS','SLSC','NSI'};
    end

    out=rtb_reconstruct_all(source,cfg);
    rtb_show_methods(out,'own');
    rtb_show_methods(out,'common');

    fprintf('\nInput QA:\n');
    disp(out.input_audit);
    fprintf('Methods completed: %s\n',strjoin(out.methods,', '));
    if ~isempty(out.skipped)
        fprintf('Methods skipped: %s\n',strjoin(out.skipped,', '));
    end
    fprintf('Total full-pipeline runtime: %.2f s\n',out.elapsed_s);
end
