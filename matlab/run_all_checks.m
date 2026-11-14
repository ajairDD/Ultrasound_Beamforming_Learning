function results = run_all_checks(ustb_path)
%RUN_ALL_CHECKS Run the P0 reproducibility checks for the RTB stack.
%
% Usage:
%   cd matlab
%   run_all_checks
%   run_all_checks('D:/USTB')
%
% Checks:
%   1. Synthetic canonical-interface test (no UFF/USTB).
%   2. TheGB complex RTB-DAS regression against Chapter 1.
%   3. Seven-method RTB smoke test on TheGB.
%
% This function does not write benchmark figures or MAT files.

    if nargin < 1
        ustb_path = '';
    end
    if isempty(ustb_path)
        candidates = {getenv('USTB_PATH'), 'D:\USTB', 'C:\USTB'};
        for k = 1:numel(candidates)
            if ~isempty(candidates{k}) && isfolder(candidates{k})
                ustb_path = candidates{k};
                break;
            end
        end
    end
    assert(~isempty(ustb_path) && isfolder(ustb_path), ...
        ['USTB path not found. Pass it explicitly, for example: ' ...
         'run_all_checks(''D:/USTB'').']);

    script_dir = fileparts(mfilename('fullpath'));
    project_root = fileparts(script_dir);
    source = fullfile(project_root,'data','L7_FI_TheGB.uff');
    assert(isfile(source),'Missing TheGB UFF: %s',source);

    addpath(genpath(ustb_path));
    addpath(fullfile(project_root,'matlab','01_DAS_Real_UFF'));
    addpath(fullfile(project_root,'matlab','RTB_Universal'));

    results = struct();
    results.ustb_path = ustb_path;
    results.source = source;
    results.synthetic = false;
    results.rtb_das_regression = NaN;
    results.seven_methods = false;
    results.smoke_runtime_s = NaN;
    results.elapsed_s = NaN;

    t_all = tic;

    fprintf('\n=== CHECK 1/3: synthetic canonical interface ===\n');
    test_rtb_standard_interface();
    results.synthetic = true;

    fprintf('\n=== CHECK 2/3: TheGB RTB-DAS vs Chapter 1 ===\n');
    results.rtb_das_regression = ...
        test_rtb_universal_vs_chapter1(source);
    assert(results.rtb_das_regression < 1e-10, ...
        'RTB-DAS regression failed: %.3e',results.rtb_das_regression);

    fprintf('\n=== CHECK 3/3: seven-method RTB smoke test ===\n');
    cfg = struct();
    cfg.methods = {'DAS','CF','GCF','MVDR','FDMAS','SLSC','NSI'};
    cfg.x_range_m = [-4,3]*1e-3;
    cfg.z_range_m = [18,22.5]*1e-3;
    cfg.n_x = 32;                 % compact smoke grid; Chapter 8 uses 64
    cfg.wave_stride = 8;          % 128 focused Tx -> 16 selected
    cfg.verbose = false;

    out = rtb_reconstruct_all(source,cfg);
    assert(numel(out.methods)==7, ...
        'Seven-method smoke test did not return all methods.');
    for k = 1:numel(out.methods)
        method = out.methods{k};
        image = out.images.(method);
        assert(isequal(size(image),[numel(out.z_axis_m), ...
                                   numel(out.x_axis_m)]) && ...
               all(isfinite(image(:))), ...
            'Invalid or non-finite image returned for %s.',method);
    end
    assert(out.diagnostics.mvdr_attempts>0, ...
        'MVDR branch did not execute in the smoke test.');

    results.seven_methods = true;
    results.smoke_runtime_s = out.elapsed_s;
    results.elapsed_s = toc(t_all);

    fprintf('\n=== ALL P0 CHECKS PASSED ===\n');
    fprintf('Synthetic interface: PASS\n');
    fprintf('TheGB RTB-DAS regression: %.6e\n', ...
        results.rtb_das_regression);
    fprintf('Seven-method smoke: PASS (%.2f s)\n', ...
        results.smoke_runtime_s);
    fprintf('Total check time: %.2f s\n',results.elapsed_s);
end
