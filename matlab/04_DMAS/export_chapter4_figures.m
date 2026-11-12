function export_chapter4_figures(section)
%EXPORT_CHAPTER4_FIGURES Reproduce the Chapter 4 lecture PNGs and logs.
% 'all' (default), 'concepts' (six no-data examples), or 'uff' (TheGB).
% Real-data export uses the existing complete conventional-FI experiment;
% it adds four diagnostic views of the SAME reconstruction, not variants.
if nargin < 1, section = 'all'; end
assert(any(strcmp(section,{'all','concepts','uff'})),'Unknown section.');
demo_dir = fileparts(mfilename('fullpath'));
repo_dir = fileparts(fileparts(demo_dir));
out_dir = fullfile(repo_dir,'chapters','04_DMAS','figures');
if ~exist(out_dir,'dir'), mkdir(out_dir); end
addpath(demo_dir,fullfile(repo_dir,'matlab','01_DAS_Real_UFF'));
if ~strcmp(section,'concepts')
    assert(~isempty(which('uff.read_object')),'Add USTB before real-data export.');
end
old_dir = pwd;
cleanup_dir = onCleanup(@() cd(old_dir)); %#ok<NASGU>
cd(demo_dir);
old_visibility = get(groot,'DefaultFigureVisible');
cleanup_visible = onCleanup(@() set(groot,'DefaultFigureVisible',old_visibility)); %#ok<NASGU>
set(groot,'DefaultFigureVisible','off');
old_warning = warning('query','backtrace');
cleanup_warning = onCleanup(@() warning(old_warning)); %#ok<NASGU>
warning('off','backtrace');
log_path = fullfile(out_dir,['matlab_' section '_results.txt']);
fid = fopen(log_path,'w');
assert(fid>=0,'Cannot open output log.');
fprintf(fid,'MATLAB %s\n',version);
fprintf(fid,'Concepts: deterministic real-RF toy examples, rng(4); no acoustic PSF.\n');
fprintf(fid,'UFF: TheGB, frame 1, all 128 focused scanlines; 5--45 mm.\n');
fprintf(fid,'Rx F#=1.7; automatic dz <= lambda/16; real-RF signed-sqrt receive DMAS.\n');
fprintf(fid,'Pair normalization 2/(M-1), M>=2; FFT raised-cosine edges [1.5 1.75 2.5 2.75]*nominal f0.\n');
fprintf(fid,'Images use separate global peaks; target profiles use separate local peaks.\n');
fclose(fid);
if ~strcmp(section,'uff')
    close all;
    started = tic;
    log_text = evalc('demo_dmas_building_blocks;');
    append_log(log_path,'demo_dmas_building_blocks',log_text);
    export_open_figures(out_dir,'demo_dmas_building_blocks',6);
    fprintf('Concept figures completed in %.1f s.\n',toc(started));
end
if ~strcmp(section,'concepts')
    close all;
    started = tic;
    [log_text,out] = run_uff(fullfile(demo_dir,'compare_fi_das_vs_fdmas.m'), ...
        fullfile(repo_dir,'data','L7_FI_TheGB.uff'));
    append_log(log_path,'compare_fi_das_vs_fdmas',log_text);
    export_open_figures(out_dir,'compare_fi_das_vs_fdmas',2);
    close all;
    log_text = evalc('inspect_uff_output(out);');
    append_log(log_path,'uff_diagnostics',log_text);
    export_open_figures(out_dir,'uff_dmas_diagnostics',4);
    fprintf('UFF figures completed in %.1f s.\n',toc(started));
end
close all;
fprintf('Chapter 4 figures saved to %s\n',out_dir);
end

function [log_text,out] = run_uff(script_path,filename)
% clearvars in the teaching script only clears this helper workspace.
z_min = 5e-3; z_max = 45e-3; n_z = []; %#ok<NASGU>
receive_f_number = 1.7; run_das_reference_check = true; %#ok<NASGU>
log_text = evalc('run(script_path)');
end

function inspect_uff_output(out)
x = out.x_axis*1e3;
z = out.z_axis*1e3;
shape = [numel(z),numel(x)];
names = {'das_analytic','das_envelope','dmas_unfiltered', ...
    'fdmas_filtered','fdmas_analytic','fdmas_envelope','active_channel_count'};
for k = 1:numel(names)
    A = out.(names{k});
    assert(isequal(size(A),shape) && all(isfinite(A(:))), ...
        'Invalid [z,x] array: %s',names{k});
end
assert(isreal(out.dmas_unfiltered) && isreal(out.fdmas_filtered));
assert(isequal(out.das_envelope,abs(out.das_analytic)));
assert(isequal(out.fdmas_envelope,abs(out.fdmas_analytic)));
M = out.active_channel_count;
assert(all(M(:)==round(M(:))) && all(M(:)>=0) && all(M(:)<=128));
assert(all(out.dmas_unfiltered(M<2)==0));
assert(out.image_fs_z/2>out.filter_edges(4));
re_error = max(abs(real(out.fdmas_analytic(:))-out.fdmas_filtered(:)))/ ...
    max(abs(out.fdmas_filtered(:)));
assert(re_error<1e-12,'Analytic transform changed the real part.');

ix_roi = find(abs(x+0.745)<1.2);
iz_roi = find(abs(z-20.1)<1.2);
[iz_d,ix_d] = target_peak(out.das_envelope,iz_roi,ix_roi);
[iz_f,ix_f] = target_peak(out.fdmas_envelope,iz_roi,ix_roi);
pd = out.das_envelope(iz_d,ix_d);
pf = out.fdmas_envelope(iz_f,ix_f);
dx = median(diff(x)); dz = z(2)-z(1);
[wd,nd] = half_width(x,out.das_envelope(iz_d,:)/pd,ix_d);
[wf,nf] = half_width(x,out.fdmas_envelope(iz_f,:)/pf,ix_f);
[wzd,nzd] = half_width(z,out.das_envelope(:,ix_d)/pd,iz_d);
[wzf,nzf] = half_width(z,out.fdmas_envelope(:,ix_f)/pf,iz_f);
fprintf('Array checks PASS: finite [z,x], real DMAS, analytic envelopes, valid integer M.\n');
fprintf('Analytic-transform real-part scaled error: %.6e.\n',re_error);
fprintf('Input RF fs=%.9f MHz; nominal f0=%.9f MHz.\n',out.fs/1e6,out.nominal_f0/1e6);
fprintf('[Nz Nx]=[%d %d]; dx=%.9f mm; dz=%.9f mm.\n',shape,dx,dz);
fprintf('Image fs,z=%.9f MHz; Nyquist=%.9f MHz; band top=%.9f MHz.\n', ...
    out.image_fs_z/1e6,out.image_fs_z/2e6,out.filter_edges(4)/1e6);
fprintf('Active Rx M range: %d--%d.\n',min(M(:)),max(M(:)));
fprintf('DAS target local peak (x,z)=(%.9f,%.9f) mm.\n',x(ix_d),z(iz_d));
fprintf('fDMAS target local peak (x,z)=(%.9f,%.9f) mm.\n',x(ix_f),z(iz_f));
fprintf('Lateral half-amplitude width DAS/fDMAS: %.9f/%.9f mm, %.4f/%.4f grid intervals.\n',wd,wf,nd,nf);
fprintf('Axial half-amplitude width DAS/fDMAS: %.9f/%.9f mm, %.4f/%.4f grid intervals.\n',wzd,wzf,nzd,nzf);
fprintf('Widths use each method local peak/slice; lateral estimates are sampling-limited.\n');
fprintf('No CNR/gCNR/SNR improvement is inferred; fDMAS amplitudes are uncalibrated to DAS.\n');

%% Diagnostic 1: enlarge the same target while preserving GLOBAL references
figure('Color','w','Position',[60 60 1200 1000]);
tiledlayout(2,1,'TileSpacing','loose','Padding','loose');
images = {out.das_db,out.fdmas_db_self};
titles = {'DAS: own GLOBAL peak = 0 dB','fDMAS: own GLOBAL peak = 0 dB'};
for k = 1:2
    nexttile;
    imagesc(x,z,images{k}); set(gca,'YDir','reverse'); axis image;
    xlim(-0.745+[-3 3]); ylim([18.8 21.4]);
    caxis([-60 0]); colormap(gca,gray(256)); colorbar;
    xlabel('Lateral x (mm)'); ylabel('Depth z (mm)'); title(titles{k});
end
sgtitle('TheGB target: display crop only; separate global-peak references');

%% Diagnostic 2: local profiles with visible samples on both axes
figure('Color','w','Position',[80 80 1400 700]);
tiledlayout(1,2,'TileSpacing','compact','Padding','compact');
nexttile;
plot(x,local_db(out.das_envelope(iz_d,:)/pd),'-o','LineWidth',1.7,'MarkerSize',5); hold on;
plot(x,local_db(out.fdmas_envelope(iz_f,:)/pf),'-s','LineWidth',1.7,'MarkerSize',5);
yline(-6.0206,'--','Half amplitude');
xlim(-0.745+[-2 2]); ylim([-60 3]); grid on;
xlabel('Lateral x (mm)'); ylabel('Own LOCAL target-peak amplitude (dB)');
title(sprintf('Lateral: dx=%.4f mm; widths span %.2f / %.2f intervals',dx,nd,nf));
legend('DAS','fDMAS','Location','best');
nexttile;
plot(z,local_db(out.das_envelope(:,ix_d)/pd),'-o','LineWidth',1.6,'MarkerSize',3); hold on;
plot(z,local_db(out.fdmas_envelope(:,ix_f)/pf),'-s','LineWidth',1.6,'MarkerSize',3);
yline(-6.0206,'--','Half amplitude');
xlim([19.3 20.8]); ylim([-60 3]); grid on;
xlabel('Depth z (mm)'); ylabel('Own LOCAL target-peak amplitude (dB)');
title(sprintf('Axial: dz=%.4f mm; widths %.3f / %.3f mm',dz,wzd,wzf));
legend('DAS','fDMAS','Location','best');
sgtitle({'Separate local peaks and slices: morphology only, not absolute amplitude', ...
    'Line segments connect actual grid samples; interpolation cannot add measured scanlines'});

%% Diagnostic 3: three RF-like stages and a true filter-mask overlay
[~,ix] = min(abs(x+0.745));
figure('Color','w','Position',[100 100 1400 850]);
tiledlayout(2,2,'TileSpacing','compact','Padding','compact');
stages = {real(out.das_analytic(:,ix)),out.dmas_unfiltered(:,ix),out.fdmas_filtered(:,ix)};
stage_titles = {'Real part of analytic DAS','Normalized DMAS BEFORE bandpass','fDMAS AFTER bandpass'};
for k = 1:3
    nexttile;
    v = stages{k}; v = v/max(abs(v));
    plot(z,v,'LineWidth',1.2); xlim([19.4 20.7]); grid on;
    xlabel('Depth z (mm)'); ylabel('Stage / own full-scanline maximum');
    title(stage_titles{k});
end
nexttile;
Npad = numel(out.filter_mask);
indices = (0:Npad/2).';
f = indices*out.image_fs_z/Npad;
Y = abs(fft(out.dmas_unfiltered(:,ix),Npad,1));
Y = Y(indices+1); spectral_reference = max(Y);
plot(f/1e6,20*log10(max(Y/spectral_reference,1e-5)),'LineWidth',1.4); hold on;
plot(f/1e6,20*log10(max(Y.*out.filter_mask(indices+1)/spectral_reference,1e-5)), ...
    'LineWidth',1.4);
ylim([-80 3]); ylabel('Magnitude / raw-DMAS spectral peak (dB)');
yyaxis right;
plot(f/1e6,out.filter_mask(indices+1),'k--','LineWidth',1.5);
ylim([-0.05 1.1]); ylabel('FFT filter mask gain');
xlim([0 3.2*out.nominal_f0/1e6]); grid on;
xlabel('Axial image-time frequency (MHz)');
title('Padded spectrum Y and Y times H BEFORE cropping');
legend('Unfiltered spectrum','Masked spectrum','Actual mask H','Location','best');
sgtitle(sprintf('One actual TheGB scanline, x=%.3f mm: separate signal stages',x(ix)));

%% Diagnostic 4: dynamic active aperture in the actual reconstruction
figure('Color','w','Position',[120 120 1400 750]);
tiledlayout(1,2,'TileSpacing','compact','Padding','compact');
nexttile;
imagesc(x,z,M); set(gca,'YDir','reverse'); axis image;
colorbar; xlabel('Lateral x (mm)'); ylabel('Depth z (mm)');
title('M(z,x): aperture AND valid interpolation determine count');
nexttile;
yyaxis left;
plot(z,M(:,ix),'LineWidth',1.8); ylabel('Active Rx channels M');
yyaxis right;
plot(z,M(:,ix).*(M(:,ix)-1)/2,'LineWidth',1.8);
ylabel('Unique pairs M(M-1)/2');
xlabel('Depth z (mm)'); grid on;
title(sprintf('At x=%.3f mm: pair count grows faster than M',x(ix)));
sgtitle({'The same active Rx set is used for DAS and DMAS', ...
    '2/(M-1) removes coherent quadratic count scaling; it is not brightness calibration'});
end

function [iz,ix] = target_peak(env,iz_roi,ix_roi)
cut = env(iz_roi,ix_roi);
[~,p] = max(cut(:));
[j,i] = ind2sub(size(cut),p);
iz = iz_roi(j); ix = ix_roi(i);
end

function [width,n_intervals] = half_width(x,y,peak)
width = NaN; n_intervals = NaN;
left = find(y(1:peak)<0.5,1,'last');
right = find(y(peak:end)<0.5,1,'first');
if isempty(left) || isempty(right), return; end
right = peak+right-1;
xl = x(left)+(0.5-y(left))*(x(left+1)-x(left))/(y(left+1)-y(left));
xr = x(right-1)+(0.5-y(right-1))*(x(right)-x(right-1))/(y(right)-y(right-1));
width = xr-xl;
n_intervals = width/median(diff(x));
end

function db = local_db(v)
db = 20*log10(max(v,1e-3));
end

function append_log(path,id,log_text)
log_text = erase(log_text,char(8));
log_text = regexprep(log_text,'<(?:"[^"]*"|[^">])*>','');
lines = regexp(log_text,'\r?\n','split');
lines = cellfun(@(s) regexprep(s,'[ \t]+$',''),lines,'UniformOutput',false);
keep = cellfun(@(s) ~startsWith(s,'UFF: reading'),lines);
fid = fopen(path,'a');
assert(fid>=0,'Cannot append output log.');
fprintf(fid,'\n--- %s ---\n%s\n',id,strjoin(lines(keep),newline));
fclose(fid);
end

function export_open_figures(out_dir,id,expected)
figs = findall(groot,'Type','figure');
assert(numel(figs)==expected,'Unexpected number of figures for %s.',id);
[~,order] = sort([figs.Number]); figs = figs(order);
for k = 1:numel(figs)
    drawnow;
    exportgraphics(figs(k),fullfile(out_dir,sprintf('%s_%02d.png',id,k)), ...
        'Resolution',150);
end
fprintf('Exported %d figures: %s.\n',numel(figs),id);
end
