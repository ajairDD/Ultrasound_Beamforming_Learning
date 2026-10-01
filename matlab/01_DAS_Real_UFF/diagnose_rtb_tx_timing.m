%% diagnose_rtb_tx_timing.m
% Reproduce the CIRS right-side dark band and test an RF timing correction.
% Run from this directory after addpath(genpath('D:/USTB')).
% Outputs: original/corrected RTB and conventional results, tx_time_offsets,
% paired Tx correlation, shared-reference images, and a saved report.
% The 16-element half-aperture is an explicit acquisition hypothesis.
% No image gain or phase-only rotation is applied.

clearvars -except filename n_z x_upsample timing_output_dir;
clc; close all;
if ~exist('filename','var')
    filename = '../../data/L7_FI_Verasonics_CIRS_points.uff';
end
if ~exist('n_z','var'), n_z = 512; end
if ~exist('x_upsample','var'), x_upsample = 4; end
if ~exist('timing_output_dir','var')
    timing_output_dir = fullfile(fileparts(mfilename('fullpath')), ...
        '..','..','artifacts','rtb_darkening');
end
if ~exist(timing_output_dir,'dir'), mkdir(timing_output_dir); end
[~,dataset_name] = fileparts(filename);
assert(strcmp(dataset_name,'L7_FI_Verasonics_CIRS_points'), ...
    'The 16-element timing hypothesis has only been checked on CIRS points.');
channel_data = uff.read_object(filename,'/channel_data',false);
tx_time_offsets = right_edge_tx_time_offsets(channel_data,16);

r = struct('n_z',n_z,'x_upsample',x_upsample, ...
    'tx_delay_model','blended','rx_f_number',1.7,'verbose',true);
c = struct('n_z',n_z,'receive_aperture_mode','f_number', ...
    'receive_f_number',1.7);
rtb_original = reconstruct_fi_rtb_manual(filename,r,channel_data);
conv_original = reconstruct_fi_scanline_manual(filename,c,channel_data);
r.tx_time_offsets = tx_time_offsets;
c.tx_time_offsets = tx_time_offsets;
rtb_corrected = reconstruct_fi_rtb_manual(filename,r,channel_data);
conv_corrected = reconstruct_fi_scanline_manual(filename,c,channel_data);

x = rtb_original.x_axis;
z = rtb_original.z_axis;
original_conv_env = interp1(conv_original.x_axis,conv_original.envelope.',x).';
corrected_conv_env = interp1(conv_corrected.x_axis,conv_corrected.envelope.',x).';
depth_mask = z >= 10e-3 & z <= 27e-3;
centers_mm = [-16 -2 15];
metrics = zeros(3,5);
for k = 1:3
    xm = abs(x-centers_mm(k)*1e-3) <= 1e-3;
    a = rtb_original.envelope(depth_mask,xm);
    b = original_conv_env(depth_mask,xm);
    d = rtb_corrected.envelope(depth_mask,xm);
    e = corrected_conv_env(depth_mask,xm);
    cf0 = rtb_original.tx_coherence(depth_mask,xm);
    cf1 = rtb_corrected.tx_coherence(depth_mask,xm);
    metrics(k,:) = [centers_mm(k),20*log10(median(a(:))/median(b(:))), ...
        20*log10(median(d(:))/median(e(:))),median(cf0(:)),median(cf1(:))];
end
region_table = array2table(metrics,'VariableNames', ...
    {'x_mm','original_RTB_minus_FI_dB','corrected_RTB_minus_FI_dB', ...
     'original_coherence','corrected_coherence'});
disp(region_table);
writetable(region_table,fullfile(timing_output_dir,'timing_regions.csv'));
fprintf('First corrected Tx: %d; max RF time offset: %.3f ns\n', ...
    find(tx_time_offsets > 1e-12,1),max(tx_time_offsets)*1e9);

% Independent phase check on shallow/deep bands. These measurements do not
% fit offsets: the correction above uses only the stated geometry model.
phase_depth_bands = [10 18;22 27;34 42]*1e-3;
phase_table = table();
for band = 1:size(phase_depth_bands,1)
    depths = linspace(phase_depth_bands(band,1),phase_depth_bands(band,2),64).';
    old_cor = adjacent_tx_correlation(channel_data,zeros(size(tx_time_offsets)),depths);
    new_cor = adjacent_tx_correlation(channel_data,tx_time_offsets,depths);
    rows = (1:numel(old_cor)).';
    t = table(repmat(band,numel(rows),1),rows,abs(old_cor), ...
        angle(old_cor)*180/pi,abs(new_cor),angle(new_cor)*180/pi, ...
        'VariableNames',{'depth_band','Tx','original_correlation', ...
        'original_phase_deg','corrected_correlation','corrected_phase_deg'});
    phase_table = [phase_table;t]; %#ok<AGROW>
end
writetable(phase_table,fullfile(timing_output_dir,'timing_phase.csv'));

% Same absolute amplitude reference for all four images. Independent peak
% normalization is intentionally not used to assess a brightness deficit.
reference = max([rtb_original.envelope(:);rtb_corrected.envelope(:); ...
    conv_original.envelope(:);conv_corrected.envelope(:)]);
images = {conv_original,rtb_original,conv_corrected,rtb_corrected};
titles = {'Original Conventional','Original RTB', ...
    'Timing-corrected Conventional','Timing-corrected RTB'};
f_images = figure('Color','w','Position',[50 50 1500 650]);
for k = 1:4
    subplot(1,4,k); rr = images{k};
    imagesc(rr.x_axis*1e3,rr.z_axis*1e3, ...
        20*log10(max(rr.envelope/reference,realmin)));
    axis image; set(gca,'YDir','reverse'); caxis([-60 0]);
    xlabel('x (mm)'); ylabel('z (mm)'); title(titles{k}); colorbar;
end
colormap gray;
exportgraphics(f_images,fullfile(timing_output_dir,'timing_comparison.png'));

f_profiles = figure('Color','w','Position',[50 50 1400 700]);
subplot(2,2,1);
old_level = median(rtb_original.envelope(depth_mask,:),1);
new_level = median(rtb_corrected.envelope(depth_mask,:),1);
old_fi_level = median(original_conv_env(depth_mask,:),1);
new_fi_level = median(corrected_conv_env(depth_mask,:),1);
plot(x*1e3,20*log10(old_level./old_fi_level), ...
    x*1e3,20*log10(new_level./new_fi_level),'LineWidth',1.5);
legend('Original','Timing corrected','Location','best'); grid on;
xlabel('x (mm)'); ylabel('RTB / Conventional (dB)');
title('10-27 mm: absolute amplitude ratio');
subplot(2,2,2);
plot(x*1e3,median(rtb_original.tx_coherence(depth_mask,:),1), ...
    x*1e3,median(rtb_corrected.tx_coherence(depth_mask,:),1),'LineWidth',1.5);
xlabel('x (mm)'); ylabel('Tx coherence'); grid on;
title('|sum(w S)| / sum(w |S|)');
subplot(2,2,3);
plot(1:numel(tx_time_offsets),tx_time_offsets*1e9,'LineWidth',1.5);
xlabel('Tx event'); ylabel('Added RF query time (ns)'); grid on;
title('Explicit right-edge timing hypothesis');
subplot(2,2,4);
shallow = phase_table.depth_band == 1;
plot(phase_table.Tx(shallow),phase_table.original_phase_deg(shallow), ...
    phase_table.Tx(shallow),phase_table.corrected_phase_deg(shallow),'LineWidth',1.5);
xlabel('First Tx of adjacent pair'); ylabel('Inter-Tx phase (degrees)');
grid on; title('Independent 10-18 mm phase check');
exportgraphics(f_profiles,fullfile(timing_output_dir,'timing_diagnostics.png'));

% Optional visual comparison at matched central background brightness.
% A SINGLE scalar display gain is shared by original/corrected RTB. It
% cannot remove an edge dip and is never written back into RF or envelope.
center = abs(x) <= 5e-3;
fi_background = corrected_conv_env(depth_mask,center);
rtb_background = rtb_corrected.envelope(depth_mask,center);
display_gain = median(fi_background(:))/median(rtb_background(:));
display_gain_db = 20*log10(display_gain);
f_matched = figure('Color','w','Position',[50 50 1400 650]);
matched_images = {conv_corrected,rtb_original,rtb_corrected};
for k = 1:3
    subplot(1,3,k); rr = matched_images{k};
    gain = 1; if k>1, gain = display_gain; end
    imagesc(rr.x_axis*1e3,rr.z_axis*1e3, ...
        20*log10(max(gain*rr.envelope/reference,realmin)));
    axis image; set(gca,'YDir','reverse'); caxis([-60 0]);
    xlabel('x (mm)'); ylabel('z (mm)'); colorbar;
    if k==1
        title('Timing-corrected Conventional');
    elseif k==2
        title(sprintf('Original RTB, display gain +%.2f dB',display_gain_db));
    else
        title(sprintf('Corrected RTB, display gain +%.2f dB',display_gain_db));
    end
end
colormap gray;
exportgraphics(f_matched,fullfile(timing_output_dir,'timing_brightness_matched.png'));
fprintf('Uniform RTB display gain for matched background: %.3f dB (display only).\n',display_gain_db);

save(fullfile(timing_output_dir,'timing_results.mat'), ...
    'rtb_original','rtb_corrected','conv_original','conv_corrected', ...
    'tx_time_offsets','region_table','phase_table','phase_depth_bands','reference', ...
    'display_gain','display_gain_db');
fprintf('RF timing correction tested; acquisition-reference mechanism remains inferred.\n');

function cor = adjacent_tx_correlation(cd,offsets,depths)
% Each pair is evaluated on the SAME pixels between its two scanlines.
% Boxcar Rx F#=1.7; full RF delay interpolation, not phase-only correction.
    cor = complex(zeros(cd.N_waves-1,1));
    a_wave = analytic_rf(double(cd.data(:,:,1,1)));
    px = double(cd.probe.x(:)).';
    pz = double(cd.probe.z(:)).';
    py = double(cd.probe.y(:)).';
    for iw = 1:cd.N_waves-1
        b_wave = analytic_rf(double(cd.data(:,:,iw+1,1)));
        midpoint = (double(cd.sequence(iw).source.x)+ ...
            double(cd.sequence(iw+1).source.x))/2;
        [xx,zz] = meshgrid(midpoint+[-0.3 0 0.3]*1e-3,depths);
        xx = xx(:); zz = zz(:);
        rx = sqrt((xx-px).^2 + py.^2 + (zz-pz).^2)/double(cd.sound_speed);
        weights = double(abs(xx-px) <= zz/(2*1.7));
        a = beam_samples(a_wave,cd,iw,xx,zz,rx,weights,offsets(iw));
        b = beam_samples(b_wave,cd,iw+1,xx,zz,rx,weights,offsets(iw+1));
        denom = sqrt(sum(abs(a).^2)*sum(abs(b).^2));
        cor(iw) = sum(conj(a).*b)/max(denom,realmin);
        a_wave = b_wave;
    end
end

function values = beam_samples(rf,cd,iw,x,z,rx,weights,offset)
    w = cd.sequence(iw);
    sx = double(w.source.x); sz = double(w.source.z);
    distance = sqrt((x-sx).^2+(z-sz).^2);
    distance(z<sz) = -distance(z<sz);
    tx = (double(w.source.distance)+distance)/double(w.sound_speed) ...
        - double(w.delay)+offset;
    u = (tx+rx-double(cd.initial_time))*double(cd.sampling_frequency)+1;
    i0 = floor(u); fraction = u-i0;
    valid = i0 >= 1 & i0 < size(rf,1);
    ch = repmat(1:size(rf,2),size(u,1),1);
    ind = sub2ind(size(rf),i0(valid),ch(valid));
    samples = complex(zeros(size(u)));
    samples(valid) = (1-fraction(valid)).*rf(ind)+fraction(valid).*rf(ind+1);
    values = sum(weights.*samples,2);
end

function rf = analytic_rf(rf)
    n = size(rf,1); h = zeros(n,1); h(1) = 1;
    if mod(n,2)==0
        h(2:n/2) = 2; h(n/2+1) = 1;
    else
        h(2:(n+1)/2) = 2;
    end
    rf = ifft(fft(rf,[],1).*h,[],1);
end
