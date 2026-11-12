function report = demo_mvdr_building_blocks
%DEMO_MVDR_BUILDING_BLOCKS Five reproducible pictures of the MVDR calculation.
% No USTB or UFF file is needed. These are narrowband complex-vector examples,
% not ultrasound RF reconstructions or measured acoustic beam patterns.
% q is phase slope in cycles/channel, not frequency in Hz or angle in degrees.
% Run this function directly, or export_chapter3_figures('concepts').
rng(3);
close all;
report = struct();

%% 1. Fixed weights versus adaptive weights, with the SAME unit target gain
L = 16;
n = (0:L-1).';
a = ones(L,1);
q_interference = 0.14;
b = exp(1i*2*pi*n*q_interference);
R = 10*(a*a') + 100*(b*b') + eye(L);
delta = 0.01;
R_loaded = R + delta*real(trace(R))/L*eye(L);
w_das = a/L;
w_mv = unit_gain_weights(R_loaded,a);
q = linspace(-0.5,0.5,2001);
steering = exp(1i*2*pi*n*q);
response_das = abs(w_das'*steering);
response_mv = abs(w_mv'*steering);
assert(abs(w_das'*a-1) < 1e-12 && abs(w_mv'*a-1) < 1e-12);
assert(real(w_mv'*R_loaded*w_mv) <= ...
    real(w_das'*R_loaded*w_das)+1e-10);
report.unit_gain_error = abs(w_mv'*a-1);
report.loaded_power_das = real(w_das'*R_loaded*w_das);
report.loaded_power_mvdr = real(w_mv'*R_loaded*w_mv);
report.interference_gain_das = abs(w_das'*b);
report.interference_gain_mvdr = abs(w_mv'*b);

figure('Color','w','Position',[50 50 1400 650]);
tiledlayout(1,2,'TileSpacing','compact','Padding','compact');
nexttile;
plot(q,amplitude_db(response_das),'LineWidth',1.8); hold on;
plot(q,amplitude_db(response_mv),'LineWidth',1.8);
xline(0,'--','Expected target');
xline(q_interference,':','Interference');
xlim([-0.3 0.3]); ylim([-60 3]); grid on;
xlabel('Spatial phase slope q (cycles/channel)');
ylabel('Unit-gain response amplitude (dB)');
title('Both preserve q = 0; other responses differ');
legend('Normalized DAS','MVDR','Location','southwest');
nexttile;
plot(1:L,real(w_das),'-o','LineWidth',1.5); hold on;
plot(1:L,real(w_mv),'-o','LineWidth',1.5);
plot(1:L,imag(w_mv),'--s','LineWidth',1.5);
grid on; xlabel('Subarray channel'); ylabel('Complex weight component');
title('MVDR changes amplitude AND phase before summation');
legend('DAS real','MVDR real','MVDR imaginary','Location','best');
sgtitle('Narrowband vector model: same preservation constraint, different weights');

%% 2. Explicit overlapping subarray extraction: M=6, L=3, P=4
M = 6; Ls = 3; P = M-Ls+1;
index_matrix = (0:Ls-1).' + (1:P);
assert(isequal(index_matrix,[1 2 3 4;2 3 4 5;3 4 5 6]));
s = exp(1i*2*pi*(0:M-1)*0.09) + ...
    0.2*(randn(1,M)+1i*randn(1,M))/sqrt(2);
X = s(index_matrix);
Rs = X*X'/P;
assert(isequal(size(X),[Ls P]));
assert(norm(Rs-Rs','fro') < 1e-12);
figure('Color','w','Position',[70 70 1400 650]);
tiledlayout(1,3,'TileSpacing','compact','Padding','compact');
nexttile;
imagesc(index_matrix); caxis([1 M]);
for ir = 1:Ls
    for ic = 1:P
        text(ic,ir,num2str(index_matrix(ir,ic)), ...
            'HorizontalAlignment','center','FontWeight','bold','FontSize',17);
    end
end
xticks(1:P); yticks(1:Ls);
xlabel('Subarray / snapshot column'); ylabel('Within-subarray channel');
title('Indices in X: each column selects a subarray');
nexttile;
imagesc(abs(X)); colorbar; xticks(1:P); yticks(1:Ls);
xlabel('Subarray'); ylabel('Within-subarray channel');
title('|X| : 3 rows x 4 columns');
nexttile;
imagesc(abs(Rs)); axis image; colorbar;
xticks(1:Ls); yticks(1:Ls);
xlabel('Within-subarray channel'); ylabel('Within-subarray channel');
title('|R| : X X^H / 4, size 3 x 3');
sgtitle('Spatial smoothing uses Rx subarrays, not separate transmit events');

%% 3. Axial neighbors supply covariance snapshots; only the center is output
M = 12; La = 8; P = M-La+1;
indices = (0:La-1).' + (1:P);
z_lambda = (-3:3)*0.5;
channel = 0:M-1;
amplitudes = [0.25 0.55 0.85 1 0.85 0.55 0.25].';
samples = amplitudes*ones(1,M) + ...
    exp(1i*0.4*(1:7).')*exp(1i*2*pi*channel*0.19) + ...
    0.25*(randn(7,M)+1i*randn(7,M))/sqrt(2);
center = samples(4,:);
X_center = center(indices);
R_spatial = X_center*X_center'/P;
R_axial = complex(zeros(La));
for iz = 1:7
    sq = samples(iz,:);
    Xq = sq(indices);
    R_axial = R_axial+Xq*Xq';
end
R_axial = R_axial/(7*P);
rho = 0.01*real(trace(R_axial))/La;
R_axial_loaded = R_axial+rho*eye(La);
w = unit_gain_weights(R_axial_loaded,ones(La,1));
y_unit = mean(w'*X_center);
y = M*y_unit; %#ok<NASGU>
% Analytical amplitude convention: an exactly coherent aperture gives M*A.
A = 2*exp(1i*0.4);
coherent_output = M*mean(w'*(A*ones(La,P)));
assert(abs(coherent_output-M*A) < 1e-10);
assert(rank(R_spatial) <= P && rank(R_axial) == La);
assert(min(real(eig(R_axial_loaded))) > 0);
report.spatial_rank = rank(R_spatial);
report.axial_rank = rank(R_axial);
report.axial_snapshots = 7*P;
report.coherent_amplitude_error = abs(coherent_output-M*A);
figure('Color','w','Position',[90 90 1400 650]);
tiledlayout(1,2,'TileSpacing','compact','Padding','compact');
nexttile;
imagesc(1:M,z_lambda,abs(samples)); colorbar; hold on;
yline(0,'r-','CURRENT pixel','LineWidth',2);
xlabel('Active Rx channel'); ylabel('Depth offset (wavelengths)');
title('Seven rows estimate R; only the center row forms y');
nexttile;
es = sort(real(eig(R_spatial)),'descend');
ea = sort(real(eig(R_axial)),'descend');
el = sort(real(eig(R_axial_loaded)),'descend');
semilogy(1:La,max(es,1e-14),'-o','LineWidth',1.5); hold on;
semilogy(1:La,ea,'-s','LineWidth',1.5);
semilogy(1:La,el,'-^','LineWidth',1.5);
grid on; xlabel('Eigenvalue index (sorted)'); ylabel('Eigenvalue (linear power)');
title('Spatial rank <= P=5; neighbors add sample diversity');
legend('Spatial only','Spatial + axial','Axial + loading','Location','best');
sgtitle('Toy covariance example: M=12, L=8, P=5, axial half-window=1.5 wavelengths');

%% 4. Diagonal loading: regularization changes the compromise
loads = [1e-5 0.01 0.1 10];
load_colors = lines(numel(loads));
figure('Color','w','Position',[110 110 1400 650]);
tiledlayout(1,2,'TileSpacing','compact','Padding','compact');
nexttile; hold on;
for k = 1:numel(loads)
    wk = unit_gain_weights(R+loads(k)*real(trace(R))/size(R,1)*eye(size(R)),a);
    plot(q,amplitude_db(abs(wk'*steering)), ...
        'Color',load_colors(k,:),'LineWidth',1.5);
end
plot(q,amplitude_db(response_das),'k--','LineWidth',1.5);
xline(q_interference,':','Interference');
xlim([-0.1 0.25]); ylim([-60 3]); grid on;
xlabel('Spatial phase slope q (cycles/channel)'); ylabel('Response amplitude (dB)');
title('More loading tends toward normalized DAS');
legend('delta=1e-5','delta=0.01','delta=0.1','delta=10','DAS','Location','southwest');
nexttile;
load_grid = logspace(-5,3,100);
condition = zeros(size(load_grid));
weight_energy = zeros(size(load_grid));
for k = 1:numel(load_grid)
    Rk = R+load_grid(k)*real(trace(R))/size(R,1)*eye(size(R));
    wk = unit_gain_weights(Rk,a);
    condition(k) = cond(Rk);
    weight_energy(k) = real(wk'*wk);
end
yyaxis left; loglog(load_grid,condition,'LineWidth',1.8);
ylabel('Loaded matrix condition number');
yyaxis right; loglog(load_grid,weight_energy,'LineWidth',1.8); hold on;
yline(real(w_das'*w_das),'--','DAS weight energy');
ylabel('Weight energy ||w||^2'); xlabel('Relative loading delta'); grid on;
title('A more stable solve can weaken adaptive suppression');
sgtitle('Loading adds a scaled identity; it does not generate new observations');

%% 5. Preserving the assumed a does not guarantee gain 1 for the actual target
q_error = linspace(0,0.08,161);
mismatch_loads = [1e-5 0.01 0.1 1];
gain = zeros(numel(mismatch_loads),numel(q_error));
gain_das = zeros(size(q_error));
for j = 1:numel(q_error)
    a_true = exp(1i*2*pi*n*q_error(j));
    % The true target is present in the second moment. The constrained
    % steering remains a=ones: this deliberately creates model mismatch.
    R_true = 10*(a_true*a_true')+100*(b*b')+eye(numel(n));
    gain_das(j) = abs(w_das'*a_true);
    for k = 1:numel(mismatch_loads)
        Rk = R_true+mismatch_loads(k)*real(trace(R_true))/numel(n)*eye(numel(n));
        wk = unit_gain_weights(Rk,a);
        gain(k,j) = abs(wk'*a_true);
        assert(abs(wk'*a-1) < 1e-10);
    end
end
assert(max(abs(gain(:,1)-1)) < 1e-10);
figure('Color','w','Position',[130 130 1400 650]);
tiledlayout(1,2,'TileSpacing','compact','Padding','compact');
nexttile;
q_example = 0.02;
quiver(zeros(8,1),zeros(8,1),ones(8,1),zeros(8,1),0, ...
    'LineWidth',2,'Color',[0 0.45 0.75]); hold on;
atrue_example = exp(1i*2*pi*(0:7).'*q_example);
quiver(zeros(8,1),zeros(8,1),real(atrue_example),imag(atrue_example),0, ...
    'LineWidth',1.4,'Color',[0.9 0.4 0.1]);
axis equal; xlim([-0.2 1.2]); ylim([-0.2 1.2]); grid on;
xlabel('Real'); ylabel('Imaginary');
title('First eight channels: a versus a_{true}');
legend('Assumed aligned pattern','Actual pattern with residual phase slope','Location','southoutside');
nexttile;
plot(q_error,amplitude_db(gain_das),'k--','LineWidth',1.8); hold on;
for k = 1:numel(mismatch_loads)
    plot(q_error,amplitude_db(gain(k,:)),'LineWidth',1.5);
end
ylim([-60 3]); grid on;
xlabel('Residual phase slope (cycles/channel)');
ylabel('Actual target gain amplitude (dB)');
title('w^H a = 1, but |w^H a_{true}| may be smaller');
legend('Normalized DAS','delta=1e-5','delta=0.01','delta=0.1','delta=1', ...
    'Location','southwest');
sgtitle('Mismatch demonstration, not a diagnosis of the UFF target attenuation');

fprintf('Deterministic narrowband examples; rng(3); no UFF data.\n');
fprintf('Unit-gain error: %.3e\n',report.unit_gain_error);
fprintf('Loaded output power, DAS / MVDR: %.6g / %.6g\n', ...
    report.loaded_power_das,report.loaded_power_mvdr);
fprintf('Interference amplitude gain, DAS / MVDR: %.6g / %.6g\n', ...
    report.interference_gain_das,report.interference_gain_mvdr);
fprintf('Covariance rank, spatial / axial: %d / %d (L=8, P=5).\n', ...
    report.spatial_rank,report.axial_rank);
fprintf('Coherent M*A scaling error: %.3e\n',report.coherent_amplitude_error);
fprintf('Verified: complex conjugation, unit gain, PSD loading, center-only output scaling.\n');
end

function w = unit_gain_weights(R,a)
u = R\a;
w = u/(a'*u);
assert(all(isfinite(w)) && abs(w'*a-1) < 1e-10);
end

function db = amplitude_db(v)
db = 20*log10(max(abs(v),1e-3));
end
