function export_chapter3_figures(section)
%EXPORT_CHAPTER3_FIGURES Reproduce the Chapter 3 lecture PNGs and numeric log.
% section: 'all' (default), 'concepts', 'phantom', 'carotid', or a job ID below.
% Add USTB before the real-data sections. Existing teaching scripts clear
% their own workspace; this exporter isolates each run in a helper workspace.
if nargin < 1, section = 'all'; end
demo_dir = fileparts(mfilename('fullpath'));
addpath(fileparts(demo_dir)); % Shared Chinese figure export.
repo_dir = fileparts(fileparts(demo_dir));
addpath(demo_dir,fullfile(repo_dir,'matlab','01_DAS_Real_UFF'));
out_dir = fullfile(repo_dir,'chapters','03_MVDR','figures');
if ~exist(out_dir,'dir'), mkdir(out_dir); end

% ID, existing script/function, group, Nz, Nx, axial half-window/lambda, data.
jobs = { ...
    'demo_mvdr_building_blocks', 'demo_mvdr_building_blocks', 'concepts', 0, 0, 0, 0; ...
    'compare_manual_das_vs_mvdr_spatial_only', 'compare_manual_das_vs_mvdr', 'phantom', 256, 0, 0, 0; ...
    'compare_manual_das_vs_mvdr_axial', 'compare_manual_das_vs_mvdr', 'phantom', 256, 0, 1.5, 0; ...
    'experiment_mvdr_tradeoffs', 'experiment_mvdr_tradeoffs', 'phantom', 160, 0, 1.5, 0; ...
    'compare_rtb_das_vs_rtb_mvdr', 'compare_rtb_das_vs_rtb_mvdr', 'phantom', 181, 281, 1.5, 0; ...
    'compare_carotid_rtb_das_vs_rtb_mvdr_cross1', 'compare_carotid_rtb_das_vs_rtb_mvdr', 'carotid', 171, 161, 1.5, 1; ...
    'compare_carotid_rtb_das_vs_rtb_mvdr_cross2', 'compare_carotid_rtb_das_vs_rtb_mvdr', 'carotid', 171, 161, 1.5, 2};
if any(strcmp(section,{'concepts','phantom','carotid'}))
    jobs = jobs(strcmp(section,jobs(:,3)),:);
elseif ~strcmp(section,'all')
    keep = strcmp(section,jobs(:,1));
    assert(any(keep),'Unknown section or job ID: %s',section);
    jobs = jobs(keep,:);
end
if any(~strcmp(jobs(:,3),'concepts'))
    assert(~isempty(which('uff.read_object')), ...
        'Add USTB to the MATLAB path before exporting real-data figures.');
end

old_dir = pwd;
dir_cleanup = onCleanup(@() cd(old_dir)); %#ok<NASGU>
cd(demo_dir);
old_visibility = get(groot,'DefaultFigureVisible');
visibility_cleanup = onCleanup(@() set(groot, ...
    'DefaultFigureVisible',old_visibility)); %#ok<NASGU>
set(groot,'DefaultFigureVisible','off');
old_warning = warning('query','backtrace');
warning_cleanup = onCleanup(@() warning(old_warning)); %#ok<NASGU>
warning('off','backtrace');

log_path = fullfile(out_dir,['matlab_' section '_results.txt']);
fid = fopen(log_path,'w');
assert(fid >= 0,'Cannot open figure log.');
fprintf(fid,'MATLAB %s\n',version);
fprintf(fid,'Frame 1; complex analytic RF; binary receive F-number 1.7.\n');
fprintf(fid,'Concept demo: rng(3); narrowband complex vectors; no RF / acoustic angle.\n');
fprintf(fid,'Conventional: TheGB, 5--45 mm, Nz=256, axial half-window=0 or 1.5 lambda.\n');
fprintf(fid,'Trade-offs: TheGB, 18--22.5 mm, Nz=160; four existing configurations.\n');
fprintf(fid,'Dense RTB: TheGB, x=-4--3 mm, z=18--22.5 mm, Nx=281, Nz=181, stride=1.\n');
fprintf(fid,'Carotid: cross_1 / cross_2, x=-10--10 mm, z=8--25 mm, Nx=161, Nz=171, stride=2.\n');
fprintf(fid,'RTB: blended Tx; pw_margin=1 mm (hybrid-only, unused here); blending power=0.5; Tx F#=2; min support=3 mm; Tukey25.\n');
fprintf(fid,'Default MVDR: L/M=0.5, loading=0.01, axial half-window=1.5 lambda, FB=false.\n');
fprintf(fid,'Image amplitudes share the corresponding DAS peak unless labeled self-normalized.\n');
fclose(fid);

for k = 1:size(jobs,1)
    id = jobs{k,1};
    fprintf('Running %s ...\n',id);
    close all;
    started = tic;
    log_text = capture_script(fullfile(demo_dir,[jobs{k,2} '.m']), ...
        fullfile(repo_dir,'data','L7_FI_TheGB.uff'), ...
        jobs{k,4},jobs{k,5},jobs{k,6},jobs{k,7});
    log_text = erase(log_text,char(8));
    log_text = regexprep(log_text,'<(?:"[^"]*"|[^">])*>','');
    log_lines = regexp(log_text,'\r?\n','split');
    log_lines = cellfun(@(s) regexprep(s,'[ \t]+$',''),log_lines, ...
        'UniformOutput',false);
    keep = cellfun(@(s) ~startsWith(s,'UFF: reading'),log_lines);
    log_text = strjoin(log_lines(keep),newline);
    fid = fopen(log_path,'a');
    fprintf(fid,'\n--- %s ---\n%s\n',id,log_text);
    fclose(fid);
    figs = findall(groot,'Type','figure');
    [~,order] = sort([figs.Number]);
    figs = figs(order);
    for j = 1:numel(figs)
        pos = get(figs(j),'Position');
        pos(3) = max(pos(3),1400);
        pos(4) = max(pos(4),700);
        set(figs(j),'Position',pos);
        drawnow;
        export_figure_zh_cn(figs(j),fullfile(out_dir, ...
            sprintf('%s_%02d.png',id,j)),'Resolution',150);
    end
    elapsed = toc(started);
    fprintf('Completed %s: %d figures, %.1f s\n',id,numel(figs),elapsed);
    fid = fopen(log_path,'a');
    fprintf(fid,'Exported %d figures; elapsed %.1f s.\n',numel(figs),elapsed);
    fclose(fid);
end
close all;
fprintf('Chapter 3 figures saved to %s\n',out_dir);
end

function log_text = capture_script(script_path,filename,n_z,n_x, ...
    axial_averaging_lambda,dataset_index)
if endsWith(script_path,'demo_mvdr_building_blocks.m')
    log_text = evalc('demo_mvdr_building_blocks;');
    return;
end
z_min = 5e-3; z_max = 45e-3;
receive_f_number = 1.7; subarray_fraction = 0.5;
diagonal_loading = 0.01; forward_backward = false;
if contains(script_path,'compare_rtb_das_vs_rtb_mvdr')
    x_min = -4e-3; x_max = 3e-3; %#ok<NASGU>
    z_min = 18e-3; z_max = 22.5e-3;
    run_rtb_reference_check = true; %#ok<NASGU>
elseif contains(script_path,'compare_carotid_rtb')
    x_min = -10e-3; x_max = 10e-3; %#ok<NASGU>
    z_min = 8e-3; z_max = 25e-3;
    wave_stride = 2; %#ok<NASGU>
end
log_text = evalc('run(script_path)');
% The scripts' clearvars only affect this helper. Use their surviving out/R.
if exist('out','var') && isstruct(out)
    if isfield(out,'mvdr_analytic')
        verify_arrays(out.das_analytic,out.mvdr_analytic, ...
            out.das_envelope,out.mvdr_envelope,out.z_axis,out.x_axis);
        reference_opts = out.options;
        reference_opts.verbose = false;
        reference_text = evalc('reference = reconstruct_fi_scanline_manual(filename,reference_opts);'); %#ok<NASGU>
        error = max(abs(out.das_analytic(:)-reference.das_analytic(:)))/ ...
            max(abs(reference.das_analytic(:)));
        assert(error < 1e-10,'Conventional DAS differs from Chapter 1.');
        log_text = [log_text newline sprintf( ...
            'Verified conventional DAS against Chapter 1: scaled complex error %.3e.\n',error)];
    else
        verify_arrays(out.rtb_das_analytic,out.rtb_mvdr_analytic, ...
            out.rtb_das_envelope,out.rtb_mvdr_envelope,out.z_axis,out.x_axis);
        assert(out.mvdr_fallback_count <= out.mvdr_pixel_count);
        if exist('das_lat','var') && exist('mv_lat','var')
            add_target_profiles(out,iz_das,ix_das,iz_mv,ix_mv);
        end
    end
    dz = median(diff(out.z_axis));
    log_text = [log_text newline sprintf( ...
        ['Metadata: fs=%.9g Hz; c=%.9g m/s; lambda=%.9g mm.\n' ...
         'Axial half-window: %d output-grid steps = %.9g mm.\n' ...
         'Verified complex finite [z,x] arrays and exact abs(.) envelopes.\n'], ...
        out.fs,out.sound_speed,out.wavelength*1e3, ...
        out.axial_half_window_samples,out.axial_half_window_samples*dz*1e3)];
elseif exist('R','var') && iscell(R)
    for k = 1:numel(R)
        r = R{k};
        verify_arrays(r.das_analytic,r.mvdr_analytic, ...
            r.das_envelope,r.mvdr_envelope,r.z_axis,r.x_axis);
    end
    log_text = [log_text newline ...
        'Verified finite complex arrays/envelopes for all four trade-off configurations.' newline];
end
end

function verify_arrays(das,mv,das_env,mv_env,z,x)
assert(isequal(size(das),size(mv),[numel(z) numel(x)]), ...
    'Complex output does not have the expected [z,x] shape.');
assert(all(isfinite(das(:))) && all(isfinite(mv(:))), ...
    'Reconstruction contains non-finite complex values.');
assert(isequal(das_env,abs(das)) && isequal(mv_env,abs(mv)), ...
    'Envelope does not equal abs(complex output).');
end

function add_target_profiles(out,iz_das,ix_das,iz_mv,ix_mv)
das = out.rtb_das_envelope; mv = out.rtb_mvdr_envelope;
pd = das(iz_das,ix_das); pm = mv(iz_mv,ix_mv);
figure('Color','w','Position',[130 130 1400 950]);
tiledlayout(2,2,'TileSpacing','compact','Padding','compact');
vectors = {das(iz_das,:),mv(iz_mv,:),out.x_axis*1e3; ...
    das(:,ix_das),mv(:,ix_mv),out.z_axis*1e3};
for row = 1:2
    for col = 1:2
        nexttile((row-1)*2+col);
        plot(vectors{row,3},20*log10(max(vectors{row,1}/pd,1e-3)), ...
            'LineWidth',1.8); hold on;
        if col == 1, reference = pd; else, reference = pm; end
        plot(vectors{row,3},20*log10(max(vectors{row,2}/reference,1e-3)), ...
            'LineWidth',1.8);
        yline(-6.0206,'--'); yline(-20,':');
        ylim([-60 3]); grid on;
        if row == 1
            xlabel('Lateral x (mm)'); xlim([-2.745 1.255]);
        else
            xlabel('Depth z (mm)');
        end
        ylabel('Linear-envelope amplitude (dB)');
        if col == 1, title('Common DAS target-peak reference');
        else, title('Each method uses its own target peak'); end
        legend('RTB-DAS','RTB-MVDR','Location','southwest');
    end
end
sgtitle({'Dense-grid target profiles: separate attenuation from width', ...
    'Each method uses a lateral/axial slice through its own local peak'});
end
