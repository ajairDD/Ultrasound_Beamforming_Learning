function out = run_chapter8_rtb_comparison()
%RUN_CHAPTER8_RTB_COMPARISON Reproduce the Chapter-8 seven-method RTB study.
%
% Requires: USTB on MATLAB path, local data/L7_FI_TheGB.uff.
% From MATLAB:
%   addpath(genpath('D:/YOUR_USTB_PATH'));
%   cd matlab/08_RTB_Comparison
%   out = run_chapter8_rtb_comparison;
%
% This is a reproducible wrapper around the shared RTB_Universal engine.
% No reconstruction algorithm is duplicated or redefined here.
%
% Local outputs (not committed with raw data):
%   output/benchmark/ch08/RTB_seven_methods_own.png
%   output/benchmark/ch08/RTB_seven_methods_common.png
%   output/benchmark/ch08/RTB_seven_methods_results.mat
%
% The "common" view uses DAS peak for compatible envelope methods;
% fDMAS remains own-peak/non-calibrated and SLSC remains linear.

    script_dir = fileparts(mfilename('fullpath'));
    project_root = fileparts(fileparts(script_dir));
    addpath(fullfile(project_root,'matlab','RTB_Universal'));

    source = fullfile(project_root,'data','L7_FI_TheGB.uff');
    assert(isfile(source), ...
        'Missing TheGB UFF. See data/README.md for the download instructions.');
    assert(~isempty(which('uff.read_object')), ...
        'USTB is required to read UFF. Add USTB to the MATLAB path.');

    % Freeze the SAME parameters as the user's verified seven-method demo.
    % TheGB point-target region, NOT a full-FOV or all-Tx comparison.
    cfg = struct();
    cfg.methods = {'DAS','CF','GCF','MVDR','FDMAS','SLSC','NSI'};
    cfg.frame_index = 1;
    cfg.x_range_m = [-4,3]*1e-3;
    cfg.z_range_m = [18,22.5]*1e-3;
    cfg.n_x = 64;
    cfg.n_z = [];                    % lambda/16 via RTB_Universal
    cfg.wave_stride = 4;             % 128 focused Tx -> 32 selected
    cfg.tx_delay_model = 'blended';
    cfg.blending_power = 0.5;
    cfg.tx_f_number = 2;
    cfg.tx_min_aperture_m = 3e-3;
    cfg.tx_window = 'tukey25';
    cfg.rx_f_number = 1.7;
    cfg.gcf_M0 = 1;
    cfg.mvdr_fraction = 0.5;
    cfg.mvdr_loading = 0.01;
    cfg.mvdr_axial_lambda = 1.5;
    cfg.slsc_lag_fraction = 0.15;
    cfg.slsc_max_lag = 12;
    cfg.slsc_axial_lambda = 1;
    cfg.slsc_min_samples = 3;
    cfg.nsi_dc = 0.8;
    cfg.fdmas_edges_ratio = [1.5,1.75,2.5,2.75];
    cfg.dynamic_range_db = 60;
    cfg.verbose = true;

    out = rtb_reconstruct_all(source,cfg);

    % Smoke-check the contract before exporting, without inventing metrics.
    assert(numel(out.methods)==7, ...
        'Not all seven methods were reconstructed.');
    for k = 1:numel(out.methods)
        method = out.methods{k};
        img = out.images.(method);
        assert(isequal(size(img),[numel(out.z_axis_m), ...
                                  numel(out.x_axis_m)]) && ...
               all(isfinite(img(:))), ...
            'Invalid or non-finite image returned for %s.',method);
    end

    f_own = rtb_show_methods(out,'own');
    f_common = rtb_show_methods(out,'common');

    result_dir = fullfile(project_root,'output','benchmark','ch08');
    if ~isfolder(result_dir)
        mkdir(result_dir);
    end
    exportgraphics(f_own, ...
        fullfile(result_dir,'RTB_seven_methods_own.png'), ...
        'Resolution',180);
    exportgraphics(f_common, ...
        fullfile(result_dir,'RTB_seven_methods_common.png'), ...
        'Resolution',180);

    % Reproducible metadata, axis and image results. Raw channel data is
    % NOT embedded in this file.
    image_results = out; %#ok<NASGU>
    save(fullfile(result_dir,'RTB_seven_methods_results.mat'), ...
        'image_results','cfg','source','-v7.3');

    fprintf('\n=== CHAPTER 8: SEVEN RTB METHODS ===\n');
    fprintf('Methods: %s\n',strjoin(out.methods,', '));
    fprintf('Selected Tx: %d / %d\n', ...
        numel(out.options.selected_tx),out.input_audit.n_tx);
    fprintf('Grid: %d z x %d x pixels\n', ...
        numel(out.z_axis_m),numel(out.x_axis_m));
    fprintf('Full multi-method pipeline: %.2f seconds (NOT per-method)\n', ...
        out.elapsed_s);
    fprintf('MVDR fallback: %d / %d\n', ...
        out.diagnostics.mvdr_fallback,out.diagnostics.mvdr_attempts);
    fprintf('SLSC unavailable pixel-Tx: %d\n', ...
        out.diagnostics.slsc_missing);
    fprintf('Saved figures and MAT to: %s\n',result_dir);
end
