function export_chapter2_figures(section)
%EXPORT_CHAPTER2_FIGURES Regenerate Chapter 2 lecture PNGs and result logs.
% section: 'all' (default), 'concepts', 'phantom', 'carotid', or script name.
% Add USTB before real-data sections. Existing scripts clear their workspace
% and close figures, so use a fresh MATLAB session.
if nargin < 1, section = 'all'; end
demo_dir = fileparts(mfilename('fullpath'));
repo_dir = fileparts(fileparts(demo_dir));
addpath(fullfile(repo_dir,'matlab','01_DAS_Real_UFF'));
out_dir = fullfile(repo_dir,'chapters','02_CF_GCF','figures');
if ~exist(out_dir,'dir'), mkdir(out_dir); end

jobs = { ...
    'demo_cf_aperture_vectors', 0, 'concepts'; ...
    'demo_cf_failure_and_gcf_motivation', 0, 'concepts'; ...
    'inspect_real_cf_aperture_vectors', 512, 'phantom'; ...
    'compare_manual_das_vs_cf', 512, 'phantom'; ...
    'compare_manual_das_cf_gcf', 512, 'phantom'; ...
    'experiment_gcf_m0_sweep', 256, 'phantom'; ...
    'analyze_das_vs_cf_point_target', 1024, 'phantom'; ...
    'analyze_gcf_m0_point_target', 512, 'phantom'; ...
    'analyze_gcf_speckle_roi', 512, 'phantom'; ...
    'compare_carotid_fi_cf_gcf_oneclick', 512, 'carotid'; ...
    'analyze_carotid_cf_gcf_depth_dependence', 512, 'carotid'};
if any(strcmp(section,{'concepts','phantom','carotid'}))
    jobs = jobs(strcmp(section,jobs(:,3)),:);
elseif ~strcmp(section,'all')
    selected = strcmp(section,jobs(:,1));
    assert(any(selected),'Unknown section or teaching script: %s',section);
    jobs = jobs(selected,:);
end
if any(~strcmp(jobs(:,3),'concepts'))
    assert(~isempty(which('uff.read_object')), ...
        'Add USTB to the MATLAB path before exporting real-data figures.');
end

old_dir = pwd;
dir_cleanup = onCleanup(@() cd(old_dir)); %#ok<NASGU>
cd(demo_dir); % Existing carotid scripts resolve relative dataset paths.
old_visibility = get(groot,'DefaultFigureVisible');
visibility_cleanup = onCleanup(@() set(groot, ...
    'DefaultFigureVisible',old_visibility)); %#ok<NASGU>
set(groot,'DefaultFigureVisible','off');
old_warning = warning('query','backtrace');
warning_cleanup = onCleanup(@() warning(old_warning)); %#ok<NASGU>
warning('off','backtrace');

log_path = fullfile(out_dir,['matlab_' section '_results.txt']);
fid = fopen(log_path,'w');
assert(fid >= 0,'Cannot open the figure log.');
fprintf(fid,'MATLAB %s\n',version);
fprintf(fid,'Phantom: L7_FI_TheGB.uff; carotid: cross_1 and cross_2.\n');
fprintf(fid,'Frame 1; depth 5--45 mm; binary Rx F-number 1.7.\n');
fprintf(fid,'Target seed [x,z]=[-0.75,20.05] mm.\n');
fprintf(fid,'Aperture-vector seeds: [-0.75,20.05;8,22;10,10] mm.\n');
fprintf(fid,'Speckle demonstration ROI corners: [5,18;11,24] mm.\n');
fprintf(fid,'Full-image M0=1; sweep [0,1,2,4]; target M0 [0,1,2].\n');
fprintf(fid,'Common-reference images use the corresponding dataset DAS peak.\n');
fprintf(fid,'The selected ROI has no verified ideal-speckle ground truth.\n');
fclose(fid);

for k = 1:size(jobs,1)
    name = jobs{k,1};
    fprintf('Running %s (n_z=%d) ...\n',name,jobs{k,2});
    close all;
    started = tic;
    log_text = capture_script(fullfile(demo_dir,[name '.m']), ...
        fullfile(repo_dir,'data','L7_FI_TheGB.uff'),jobs{k,2});
    log_text = erase(log_text,char(8));
    log_text = regexprep(log_text,'<(?:"[^"]*"|[^">])*>','');
    lines = regexp(log_text,'\r?\n','split');
    lines = cellfun(@(s) regexprep(s,'[ \t]+$',''),lines, ...
        'UniformOutput',false);
    keep = cellfun(@(s) ~startsWith(s,'UFF: reading'),lines);
    log_text = strjoin(lines(keep),newline);
    fid = fopen(log_path,'a');
    fprintf(fid,'\n--- %s | n_z=%d ---\n%s\n',name,jobs{k,2},log_text);
    fclose(fid);
    figs = findall(groot,'Type','figure');
    if ~isempty(figs)
        [~,order] = sort([figs.Number]);
        figs = figs(order);
        for j = 1:numel(figs)
            % Preserve the teaching scripts' row/column layout. A 4x3 grid
            % needs height; forcing every multi-panel plot wide cuts labels.
            pos = get(figs(j),'Position');
            pos(3) = max(pos(3),1100);
            pos(4) = max(pos(4),650);
            if strcmp(name,'demo_cf_aperture_vectors')
                pos(3:4) = [1500 1150];
            elseif strcmp(name,'inspect_real_cf_aperture_vectors') && j == 2
                pos(3:4) = [1800 1100];
            end
            set(figs(j),'Position',pos);
            drawnow;
            exportgraphics(figs(j),fullfile(out_dir, ...
                sprintf('%s_%02d.png',name,j)),'Resolution',150);
        end
    end
    elapsed = toc(started);
    fprintf('Completed %s: %d figures, %.1f s\n',name,numel(figs),elapsed);
    fid = fopen(log_path,'a');
    fprintf(fid,'Exported %d figures; elapsed %.1f s.\n',numel(figs),elapsed);
    fclose(fid);
end
close all;
fprintf('Chapter 2 figures saved to %s\n',out_dir);
end

function log_text = capture_script(script_path,filename,n_z)
% Each script's clearvars/clear affects only this helper workspace.
z_min = 5e-3; z_max = 45e-3; receive_f_number = 1.7;
target_x_mm = -0.75; target_z_mm = 20.05;
selected_pixels_mm = [-0.75 20.05;8 22;10 10]; %#ok<NASGU>
roi_corners_mm = [5 18;11 24]; %#ok<NASGU>
M0 = 1; M0_values = [0 1 2 4]; %#ok<NASGU>
if endsWith(script_path,'analyze_gcf_m0_point_target.m')
    M0_values = [0 1 2];
end
log_text = evalc('run(script_path)');
% Additional checks on outputs, without changing the teaching algorithms.
if exist('cf','var') && isstruct(cf)
    verify_result(cf,'cf_map','cf_analytic');
end
if exist('gcf','var') && isstruct(gcf)
    verify_result(gcf,'gcf_map','gcf_analytic');
end
if exist('result','var') && isstruct(result)
    verify_result(result,'cf_map','cf_analytic');
end
if exist('results','var') && iscell(results)
    for k = 1:numel(results)
        verify_result(results{k},'gcf_map','gcf_analytic');
        if k > 1
            delta = results{k}.gcf_map-results{k-1}.gcf_map;
            assert(min(delta(:)) >= -1e-10, ...
                'Widening M0 unexpectedly decreased a pixel weight.');
            assert(isequal(results{k}.das_analytic,results{1}.das_analytic), ...
                'The M0 sweep changed its DAS baseline.');
        end
    end
    log_text = [log_text newline ...
        'Verified every sweep pixel: weights non-decreasing with M0; DAS unchanged.' newline];
end
end

function verify_result(r,weight_field,analytic_field)
weights = r.(weight_field);
weighted = r.(analytic_field);
assert(isequal(size(r.das_analytic),size(weights),size(weighted)), ...
    'Image, weight, and complex output dimensions differ.');
assert(all(isfinite(r.das_analytic(:))) && all(isfinite(weighted(:))), ...
    'Reconstruction contains non-finite values.');
assert(all(weights(:) >= 0 & weights(:) <= 1), ...
    'A coherence weight is outside [0,1].');
assert(isequal(weighted,weights.*r.das_analytic), ...
    'Complex image does not equal weight times DAS.');
assert(all(abs(weighted(:)) <= abs(r.das_analytic(:))+eps), ...
    'A coherence weight increased the linear envelope.');
end
