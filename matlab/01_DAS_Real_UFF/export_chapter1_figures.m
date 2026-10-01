function export_chapter1_figures(section)
%EXPORT_CHAPTER1_FIGURES Regenerate the Chapter 1 lecture figures.
% Add USTB to the path before running. Uses the existing teaching scripts.
% section: 'all' (default), 'experiments', 'references', or one script name.
% The scripts clear variables and close figures: use a fresh MATLAB session.
if nargin < 1, section = 'all'; end
assert(~isempty(which('uff.read_object')), 'Add USTB to the MATLAB path first.');
demo_dir = fileparts(mfilename('fullpath'));
repo_dir = fileparts(fileparts(demo_dir));
filename = fullfile(repo_dir, 'data', 'L7_FI_TheGB.uff');
out_dir = fullfile(repo_dir, 'chapters', '01_DAS_Real_UFF', 'figures');
if ~exist(out_dir,'dir'), mkdir(out_dir); end
old_visibility = get(groot,'DefaultFigureVisible');
cleanup = onCleanup(@() set(groot,'DefaultFigureVisible',old_visibility)); %#ok<NASGU>
set(groot,'DefaultFigureVisible','off');
old_warning = warning('query','backtrace');
warning_cleanup = onCleanup(@() warning(old_warning)); %#ok<NASGU>
warning('off','backtrace'); % Keep messages, omit clickable terminal stack links.
log_path = fullfile(out_dir,['matlab_' section '_results.txt']);
fid = fopen(log_path,'w');
assert(fid >= 0, 'Cannot open the figure log.');
fprintf(fid,'MATLAB %s\nData: L7_FI_TheGB.uff\n',version);
fprintf(fid,'Frame 1; depths 5--45 mm; target seed (-0.75,20.05) mm.\n');
fprintf(fid,'Reference outputs are comparisons, not automatic pass/fail verdicts.\n');
fclose(fid);

jobs = { ...
    'inspect_uff_metadata_ustb', 1024; ...
    'plot_raw_channel_overview_ustb', 1024; ...
    'demo_fi_geometry_and_sampling', 1024; ...
    'das_fi_scanline_manual', 1024; ...
    'analyze_point_target_psf', 1024; ...
    'compare_receive_aperture_full_vs_fnumber', 1024; ...
    'compare_conventional_vs_rtb', 512; ...
    'compare_rtb_spherical_plane_blended', 384; ...
    'validate_manual_vs_ustb', 512; ...
    'validate_manual_rtb_vs_ustb', 256};
if strcmp(section,'experiments'), jobs = jobs(1:8,:); end
if strcmp(section,'references'), jobs = jobs(9:10,:); end
if ~any(strcmp(section,{'all','experiments','references'}))
    selected = strcmp(section,jobs(:,1));
    assert(any(selected),'Unknown teaching script: %s',section);
    jobs = jobs(selected,:);
end

for k = 1:size(jobs,1)
    name = jobs{k,1};
    fprintf('Running %s (n_z=%d) ...\n',name,jobs{k,2});
    close all;
    started = tic;
    log_text = capture_script(fullfile(demo_dir,[name '.m']),filename,jobs{k,2});
    % Strip terminal formatting, but preserve scientific warning messages.
    log_text = erase(log_text,char(8));
    log_text = regexprep(log_text,'<(?:"[^"]*"|[^">])*>','');
    lines = regexp(log_text,'\r?\n','split');
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
            axes_set = findall(figs(j),'Type','axes');
            % Wide layouts keep multi-panel titles and legends readable.
            if numel(axes_set) >= 3
                pos = [100 100 1600 700];
            elseif numel(axes_set) == 2
                pos = [100 100 1400 720];
            else
                pos = [100 100 1100 780];
            end
            if strcmp(name,'compare_rtb_spherical_plane_blended') && j <= 3
                if j == 3
                    pos = [100 100 1400 1000];
                else
                    pos = [100 100 1600 620];
                end
            end
            set(figs(j),'Position',pos);
            drawnow;
            exportgraphics(figs(j),fullfile(out_dir, ...
                sprintf('%s_%02d.png',name,j)),'Resolution',150);
        end
        if strcmp(name,'plot_raw_channel_overview_ustb')
            ax = findall(figs(1),'Type','axes');
            ylim(ax(1),[25 34]);
            rf_image = findall(ax(1),'Type','image');
            time_us = rf_image(1).YData;
            rf_display = rf_image(1).CData;
            % imagesc may store just the first and last Y coordinate.
            if numel(time_us) == 2
                time_us = linspace(time_us(1),time_us(2),size(rf_display,1));
            end
            zoom_rows = time_us >= 25 & time_us <= 34;
            zoom_peak = max(abs(rf_display(zoom_rows,:)),[],'all');
            caxis(ax(1),[-1 1]*max(zoom_peak,eps));
            title(ax(1),'RF echo zoom | wave=64 | frame=1');
            cb = findall(figs(1),'Type','colorbar');
            cb(1).Label.String = 'RF / full-record peak';
            drawnow;
            exportgraphics(figs(1),fullfile(out_dir, ...
                'raw_channel_echo_zoom.png'),'Resolution',150);
        end
    end
    elapsed = toc(started);
    fprintf('Completed %s: %d figures, %.1f s\n',name,numel(figs),elapsed);
    fid = fopen(log_path,'a');
    fprintf(fid,'Exported %d figures; elapsed %.1f s.\n',numel(figs),elapsed);
    fclose(fid);
end
close all;
fprintf('Chapter figures saved to %s\n',out_dir);
end

function log_text = capture_script(script_path,filename,n_z)
% Each script's clearvars operates only inside this helper workspace.
z_min = 5e-3; z_max = 45e-3; frame_index = 1;
target_x_mm = -0.75; target_z_mm = 20.05;
wave_index = 64; x_upsample = 4; rtb_x_upsample = 4;
delay_model = 'blended'; blending_power = 0.5; %#ok<NASGU>
log_text = evalc('run(script_path)');
end
