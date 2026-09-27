function export_tutorial_figures
% Regenerate the chapter figures using the original, self-contained demos.
% Run from MATLAB: export_tutorial_figures
% The demos clear their workspace and close figures; run in a fresh session.
demo_dir = fileparts(mfilename('fullpath'));
out_dir = fullfile(demo_dir, '..', '..', 'chapters', '00_Fundamentals', 'figures');
if ~exist(out_dir, 'dir'), mkdir(out_dir); end
old_visibility = get(groot, 'DefaultFigureVisible');
cleanup = onCleanup(@() set(groot, 'DefaultFigureVisible', old_visibility)); %#ok<NASGU>
set(groot, 'DefaultFigureVisible', 'off');
diary(fullfile(out_dir, 'matlab_results.txt'));
diary_cleanup = onCleanup(@() diary('off')); %#ok<NASGU>
fprintf('MATLAB %s\n', version);
demos = {'demo_synthetic_point_target', 'demo_delay_alignment', ...
    'demo_aperture_psf_apodization', 'demo_axial_lateral_2d_psf', ...
    'demo_das_failure_modes'};
for k = 1:numel(demos)
    fprintf('\n--- %s ---\n', demos{k});
    run_demo(fullfile(demo_dir, [demos{k} '.m']));
    figs = findall(groot, 'Type', 'figure');
    [~, order] = sort([figs.Number]);
    figs = figs(order);
    for j = 1:numel(figs)
        set(figs(j), 'Position', [100 100 1000 620]);
        % Zoom the raw RF display to the echo; values are unchanged.
        if j == 1 && k <= 2
            ax = findall(figs(j), 'Type', 'axes');
            ylim(ax(1), [38 41]);
        end
        if k == 2 && j == 3
            % Reserve space for the long y-label in R2021b exports.
            ax = findall(figs(j), 'Type', 'axes');
            set(ax(1), 'Position', [0.14 0.13 0.72 0.78]);
        end
        drawnow;
        filename = sprintf('%s_%02d.png', demos{k}, j);
        exportgraphics(figs(j), fullfile(out_dir, filename), 'Resolution', 150);
        fprintf('Exported %s\n', filename);
    end
end
close all;
end

function run_demo(filename)
% Isolate each script's clear command from the export driver's workspace.
run(filename);
end
