function report = inspect_slsc_output(out,filename)
%INSPECT_SLSC_OUTPUT Four lecture views of ONE existing reconstruction.
% No new beamformer or parameter sweep is run. The last view independently
% queries one RF gate with interp1 and checks it against the core output.
x=out.x_axis*1e3; z=out.z_axis*1e3;
shape=[numel(z),numel(x)];
valid=out.valid_lag_count>0;
R=out.lag_correlations;
assert(isequal(size(out.slsc_mean),shape) && isreal(out.slsc_mean));
assert(all(isfinite(out.slsc_mean(:))) && max(abs(out.slsc_mean(:)))<=1+1e-12);
assert(isequal(sum(isfinite(R),3),out.valid_lag_count));
filled=R; filled(~isfinite(filled))=0;
sum_error=max(abs(sum(filled,3)-out.slsc_sum),[],'all');
mean_error=max(abs(out.slsc_mean(valid)- ...
    out.slsc_sum(valid)./out.valid_lag_count(valid)));
assert(sum_error<1e-12 && mean_error<1e-12);
assert(all(out.valid_lag_count(:)<=out.requested_lag_count(:)));
expected=min(out.options.max_lag,min(out.active_channel_count-1, ...
    max(1,floor(out.options.lag_fraction*out.active_channel_count))));
expected(out.active_channel_count<3)=0;
assert(isequal(expected,out.requested_lag_count));
display_reference=max(out.slsc_mean,0);
display_reference=display_reference/max(display_reference(:));
assert(max(abs(display_reference(:)-out.slsc_display(:)))<1e-12);
report=struct('sum_error',sum_error,'mean_error',mean_error);

%% 1. Aperture and lag counts: all from the same [z,scanline] grid.
figure('Color','w','Position',[40 40 1500 700]);
tiledlayout(1,3,'TileSpacing','loose','Padding','loose');
maps={out.active_channel_count,out.requested_lag_count,out.valid_lag_count};
names={'有效 Rx 阵元数 M','请求的短 lag 数','实际可计算的 lag 数'};
for k=1:3
    nexttile;
    imagesc(x,z,maps{k}); set(gca,'YDir','reverse'); axis image;
    colorbar; xlabel('横向 x（mm）'); ylabel('深度 z（mm）'); title(names{k});
end

%% 2. ROI supports are shown explicitly, rather than silently mixed.
nx=numel(x); ix=round(0.1*nx):round(0.9*nx);
iz=find(z>=15 & z<=30); assert(~isempty(iz));
cube=R(iz,ix,:); max_lag=size(R,3);
available=nan(1,max_lag); counts=zeros(1,max_lag);
for m=1:max_lag
    values=cube(:,:,m); values=values(isfinite(values));
    counts(m)=numel(values);
    if ~isempty(values), available(m)=mean(values); end
end
last=find(counts>0,1,'last'); assert(~isempty(last));
common_L=min(6,last);
common_mask=all(isfinite(cube(:,:,1:common_L)),3);
assert(any(common_mask(:)),'No common ROI support for diagnostic.');
fixed=nan(1,max_lag);
for m=1:common_L
    values=cube(:,:,m); fixed(m)=mean(values(common_mask));
end
figure('Color','w','Position',[60 60 1450 700]);
tiledlayout(1,2,'TileSpacing','loose','Padding','loose');
nexttile;
plot(1:max_lag,available,'-o','LineWidth',1.8); hold on;
plot(1:common_L,fixed(1:common_L),'-s','LineWidth',1.8);
yline(0,':'); grid on; ylim([-1 1]); xlim([1 max_lag]);
xlabel('空间 lag m（阵元间距数）'); ylabel('ROI 平均归一化相关');
legend('各 lag 的所有可用像素',sprintf('前 %d 项内的共同有效像素',common_L), ...
    'Location','best');
title('改变统计集合，曲线也可能改变');
nexttile;
bar(1:max_lag,counts,0.65); hold on;
plot(1:common_L,repmat(nnz(common_mask),1,common_L),'k--','LineWidth',1.7);
grid on; xlim([0.5 max_lag+0.5]);
xlabel('空间 lag m（阵元间距数）'); ylabel('参与平均的像素数量');
legend('该 lag 可用像素','共同有效像素','Location','best');
title('没有可用样本的 lag 保持 NaN，而不是相关性零');
sgtitle(sprintf('同一 TheGB 结果：x = %.2f 至 %.2f mm，z = %.2f 至 %.2f mm', ...
    x(ix(1)),x(ix(end)),z(iz(1)),z(iz(end))));
report.roi_available_mean=available;
report.roi_counts=counts;
report.roi_common_lags=common_L;
report.roi_common_count=nnz(common_mask);
report.roi_common_mean=fixed;

%% 3. Signed scientific data and clipped display are different arrays.
figure('Color','w','Position',[80 80 1500 600]);
tiledlayout(1,3,'TileSpacing','loose','Padding','loose');
nexttile;
h=imagesc(x,z,out.slsc_mean); h.AlphaData=valid;
set(gca,'YDir','reverse','Color',[0.8 0.87 0.92]); axis image;
caxis([-1 1]); colorbar; xlabel('横向 x（mm）'); ylabel('深度 z（mm）');
title('有符号的短 lag 平均值');
nexttile;
h=imagesc(x,z,out.slsc_display); h.AlphaData=valid;
set(gca,'YDir','reverse','Color',[0.8 0.87 0.92]); axis image;
caxis([0 1]); colormap(gca,gray(256)); colorbar;
xlabel('横向 x（mm）'); ylabel('深度 z（mm）');
title('裁负值、最大正值归一化后的显示');
nexttile;
histogram(out.slsc_mean(valid),linspace(-1,1,81)); hold on;
xline(0,'k--'); grid on;
xlabel('有效像素的有符号平均相干性'); ylabel('像素数量');
title(sprintf('负值 %d；无效像素 %d（不计入直方图）', ...
    nnz(out.slsc_mean(valid)<0),nnz(~valid)));
sgtitle('负相关是计算结果；无效像素是缺少估计，不能混为一谈');

%% 4. One physical RF gate, independently reconstructed and checked.
[~,scanline]=min(abs(x)); [~,depth]=min(abs(z-20));
gate=read_gate_with_interp1(filename,out,depth,scanline);
stored=reshape(R(depth,scanline,1:numel(gate.R)),1,[]);
assert(isequal(isfinite(gate.R),isfinite(stored)));
keep=isfinite(stored);
gate_error=max(abs(gate.R(keep)-stored(keep)));
assert(gate_error<1e-9,'Independent RF-gate check disagrees with SLSC core.');
figure('Color','w','Position',[100 100 1500 750]);
tiledlayout(1,3,'TileSpacing','loose','Padding','loose');
nexttile;
imagesc(gate.elements,z(gate.rows),gate.X/max(abs(gate.X(:))));
set(gca,'YDir','reverse'); colorbar;
xlabel('物理 Rx 阵元编号'); ylabel('深度 z（mm）');
title(sprintf('实际 RF 窗口：%d 行 × %d 列',size(gate.X)));
nexttile;
middle=max(1,floor(size(gate.X,2)/2)); pair=gate.X(:,middle:middle+1);
pair=pair./sqrt(sum(pair.^2,1));
plot(z(gate.rows),pair(:,1),'-o','LineWidth',1.8); hold on;
plot(z(gate.rows),pair(:,2),'-s','LineWidth',1.8);
yline(0,':'); grid on;
xlabel('深度 z（mm）'); ylabel('每条 RF / 自身能量范数');
legend(sprintf('阵元 %d',gate.elements(middle)), ...
    sprintf('阵元 %d',gate.elements(middle+1)),'Location','best');
title('一对近邻阵元：在同一组深度点比较');
nexttile;
plot(1:numel(gate.R),gate.R,'-o','LineWidth',1.8); hold on;
yline(0,':'); grid on; ylim([-1 1]);
xlabel('空间 lag m（阵元间距数）'); ylabel('该像素的平均归一化相关');
title('逐对归一化，再在同一 lag 内平均');
sgtitle(sprintf('同一像素 x = %.3f mm，z = %.3f mm；窗口跨度 %.3f λ', ...
    x(scanline),z(depth),out.axial_kernel_lambda_actual));
report.gate_check_scaled_error=gate_error;
report.gate_x_mm=x(scanline); report.gate_z_mm=z(depth);
report.gate_size=size(gate.X); report.gate_correlations=gate.R;

fprintf('Same-output checks PASS: [z,x], signed bounds, count maps, sum/mean and display.\n');
fprintf('SLSC sum/mean reconstruction errors: %.6e / %.6e.\n',sum_error,mean_error);
fprintf('Active Rx range: %d--%d; requested lags: %d--%d.\n', ...
    min(out.active_channel_count(:)),max(out.active_channel_count(:)), ...
    min(out.requested_lag_count(:)),max(out.requested_lag_count(:)));
fprintf('dz=%.9f mm; lambda=%.9f mm; K=%d; actual span=%.9f lambda.\n', ...
    median(diff(z)),out.lambda*1e3,out.axial_kernel_samples,out.axial_kernel_lambda_actual);
fprintf('Available-support ROI means: %s.\n',mat2str(available,8));
fprintf('Available-support ROI counts: %s.\n',mat2str(counts));
fprintf('Common support: %d pixels, first %d lags; means=%s.\n', ...
    nnz(common_mask),common_L,mat2str(fixed(1:common_L),8));
fprintf('Signed mean range: [%.9f, %.9f]; negative valid pixels: %d.\n', ...
    min(out.slsc_mean(valid)),max(out.slsc_mean(valid)),nnz(out.slsc_mean(valid)<0));
fprintf('Independent interp1 RF gate check max correlation error: %.6e.\n',gate_error);
fprintf('Gate at (x,z)=(%.9f,%.9f) mm: %d samples x %d Rx; R=%s.\n', ...
    x(scanline),z(depth),size(gate.X),mat2str(gate.R,8));
fprintf('These are descriptive diagnostics, not CNR/gCNR/SNR or clinical evidence.\n');
end

function gate=read_gate_with_interp1(filename,out,iz,iw)
% Independent scalar-channel interpolation, not the core vectorized helper.
cd=uff.read_object(filename,'/channel_data');
rf=double(cd.data(:,:,iw,out.options.frame_index));
z=out.z_axis; x=out.x_axis(iw); probe=cd.probe;
half=(out.axial_kernel_samples-1)/2;
rows=max(1,iz-half):min(numel(z),iz+half);
wave=cd.sequence(iw);
distance=sqrt((wave.source.x-x).^2+wave.source.y.^2+(wave.source.z-z(rows)).^2);
distance(z(rows)<wave.source.z)=-distance(z(rows)<wave.source.z);
tx=(distance+wave.source.distance)/wave.sound_speed-wave.delay;
rx=sqrt((probe.x(:).'-x).^2+probe.y(:).'.^2+ ...
    (z(rows)-probe.z(:).').^2)/cd.sound_speed;
query=tx+rx;
% Use exactly the core's sample-coordinate convention. UFF timing metadata
% are single precision here; constructing an explicit single-precision time
% axis would introduce a different rounding of the same interpolation query.
sample_query=(query-cd.initial_time)*cd.sampling_frequency+1;
sample_axis=(1:size(rf,1)).';
center=find(rows==iz);
u=(query(center,:)-cd.initial_time)*cd.sampling_frequency+1;
geometric=abs(probe.x(:).'-x)<=z(iz)/(2*out.options.receive_f_number);
if ~any(geometric)
    [~,nearest]=min(abs(probe.x(:).'-x)); geometric(nearest)=true;
end
elements=find(geometric & floor(u)>=1 & floor(u)<size(rf,1));
assert(numel(elements)>=3 && all(diff(elements)==1));
X=nan(numel(rows),numel(elements));
for k=1:numel(elements)
    X(:,k)=interp1(sample_axis,rf(:,elements(k)), ...
        double(sample_query(:,elements(k))),'linear',NaN);
end
L=out.requested_lag_count(iz,iw); R=nan(1,L);
for m=1:L
    rho=nan(1,numel(elements)-m);
    for i=1:numel(elements)-m
        keep=isfinite(X(:,i)) & isfinite(X(:,i+m));
        if nnz(keep)<out.options.min_valid_samples, continue; end
        a=X(keep,i); b=X(keep,i+m); den=norm(a)*norm(b);
        if den>0, rho(i)=sum(a.*b)/den; end
    end
    if any(isfinite(rho)), R(m)=mean(rho,'omitnan'); end
end
gate=struct('rows',rows,'elements',elements,'X',X,'R',R);
end
