%% demo_fi_geometry_and_sampling.m
% Inspect real UFF geometry, then plot explicit teaching-model quantities.
% These plots use the same definitions as reconstruct_fi_rtb_manual.m.
% They are geometry / numerical examples, not measured acoustic fields.
clearvars -except filename;
if ~exist('filename','var'), filename = '../../data/L7_FI_TheGB.uff'; end
channel_data = uff.read_object(filename,'/channel_data');
seq = channel_data.sequence;
sx = arrayfun(@(w) w.source.x,seq);
sz = arrayfun(@(w) w.source.z,seq);
wd = arrayfun(@(w) w.delay,seq);

figure('Color','w');
subplot(1,2,1);
plot(channel_data.probe.x*1e3,channel_data.probe.z*1e3,'ks', ...
    'MarkerSize',4); hold on;
plot(sx*1e3,sz*1e3,'o','MarkerSize',3);
set(gca,'YDir','reverse'); grid on;
xlabel('x (mm)'); ylabel('z (mm)');
title('Element centers and focused virtual sources');
legend('128 Rx elements','128 Tx focuses','Location','best');
subplot(1,2,2);
plot(sx*1e3,wd*1e6,'LineWidth',1.6); grid on;
xlabel('Tx focus x (mm)'); ylabel('wave.delay (\mus)');
title('The transmit timing offset is not zero');

%% Actual blended definition: compare an on-axis and an off-axis path.
[~,iw] = min(abs(sx));
wave = seq(iw); c = wave.sound_speed; Rf = wave.source.distance;
z = linspace(wave.source.z-6e-3,wave.source.z+6e-3,1201).';
x_set = [wave.source.x, wave.source.x+1e-3];
figure('Color','w');
for k = 1:2
    x = x_set(k)*ones(size(z));
    signed = sqrt((x-wave.source.x).^2+(z-wave.source.z).^2);
    signed(z<wave.source.z) = -signed(z<wave.source.z);
    sph = Rf+signed;
    plane = Rf+z-wave.source.z;
    q = min(abs(Rf-sqrt(x.^2+z.^2))/Rf,1);
    alpha = q.^0.5;
    blend = alpha.*sph+(1-alpha).*plane;
    subplot(1,2,k);
    % Subtract only the constant reference time so jumps remain visible.
    plot(z*1e3,(sph-Rf)/c*1e6,'LineWidth',1.4); hold on;
    plot(z*1e3,(plane-Rf)/c*1e6,'--','LineWidth',1.4);
    plot(z*1e3,(blend-Rf)/c*1e6,'LineWidth',1.7);
    xline(wave.source.z*1e3,':','Focus depth');
    xlabel('Pixel depth z (mm)'); ylabel('Tx time relative to focus (\mus)');
    title(sprintf('Lateral offset %.1f mm',abs(x_set(k)-wave.source.x)*1e3));
    legend('Spherical','Plane','Blended','Location','best'); grid on;
    x_at_focus = x_set(k);
    alpha_focus = min(abs(Rf-hypot(x_at_focus,wave.source.z))/Rf,1)^0.5;
    fprintf('Model limit at focal depth: offset %.1f mm; spherical jump %.3f ns; blended jump %.3f ns\n', ...
        abs(x_set(k)-wave.source.x)*1e3, ...
        2*abs(x_set(k)-wave.source.x)/c*1e9, ...
        alpha_focus*2*abs(x_set(k)-wave.source.x)/c*1e9);
end

%% Tx support and Rx aperture: same F-number definitions as the core.
x = linspace(-10e-3,10e-3,401);
depth = linspace(5e-3,45e-3,401).';
Ftx = 2; min_width = 3e-3;
z_eff = max(abs(depth-wave.source.z),min_width*Ftx);
ratio = Ftx*abs(x-wave.source.x)./z_eff;
w = zeros(size(ratio));
w(ratio<=0.375) = 1;
taper = ratio>0.375 & ratio<0.5;
w(taper) = 0.5*(1+cos(2*pi/0.25*(ratio(taper)-0.25/2-1/2)));
figure('Color','w');
subplot(1,2,1);
imagesc(x*1e3,depth*1e3,w); set(gca,'YDir','reverse');
axis image; colorbar; caxis([0 1]);
xlabel('Pixel x (mm)'); ylabel('Pixel z (mm)');
title('One Tx: F# 2, 3 mm minimum width, Tukey25');
hold on; plot(wave.source.x*1e3,wave.source.z*1e3,'r+');
subplot(1,2,2);
ex = channel_data.probe.x(:).';
rx_mask = double(abs(ex-wave.source.x)<=depth/1.7/2);
imagesc(ex*1e3,depth*1e3,rx_mask); set(gca,'YDir','reverse');
xlabel('Rx element x (mm)'); ylabel('Pixel z (mm)');
title('One center line: Rx F# 1.7'); colorbar; caxis([0 1]);

%% Fractional sample query on a known continuous real sinusoid.
fs = channel_data.sampling_frequency;
fc = channel_data.pulse.center_frequency;
ts = (0:8)/fs;
t_dense = linspace(ts(1),ts(end),1001);
rf = cos(2*pi*fc*ts);
tq = 2.35/fs; u = tq*fs+1;
linear_value = interp1(ts,rf,tq,'linear');
nearest_value = interp1(ts,rf,tq,'nearest');
true_value = cos(2*pi*fc*tq);
figure('Color','w');
plot(t_dense*1e9,cos(2*pi*fc*t_dense),'Color',[0.65 0.65 0.65], ...
    'LineWidth',1.5); hold on;
plot(ts*1e9,rf,'o-','LineWidth',1.3);
plot(tq*1e9,linear_value,'rs','MarkerFaceColor','r');
plot(tq*1e9,nearest_value,'md','MarkerFaceColor','m');
plot(tq*1e9,true_value,'k+','MarkerSize',10,'LineWidth',1.5);
xline(tq*1e9,':'); grid on;
xlabel('Time (ns)'); ylabel('Signed RF amplitude');
title(sprintf('Fractional query u = %.2f; fs/fc = %.2f',u,fs/fc));
legend('Underlying teaching sinusoid','Stored samples / linear segments', ...
    'Linear query','Nearest query','Exact sinusoid value','Location','best');
fprintf('Sampling demo: fs %.6f MHz; fc %.6f MHz; u %.2f; linear %.6f; nearest %.6f; exact %.6f\n', ...
    fs/1e6,fc/1e6,u,linear_value,nearest_value,true_value);
