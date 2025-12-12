%% MODWT SETUP

% (1) Extract temperature and time columns for analysis
T = readtable('C:\Users\marik\Documents\Graduate Program Courses\Fall 2025\MATH 663\MATLAB Files\Vancouver_2015_2024_daily_MATLAB.csv');
temp = T.Mean_Temp;
time = T.Date_Time;

% (2) Define important numbers
%N = numel(temp);                       % Number of Samples
fs = 1;                                 % Samples per day
ds = 1;                                 % Days per sample
days_per_year = 365.25;

% (3) MODWT settings and computation
signal = temp;
wname = 'db4';                          % Daubechies 4
J = 9;                                  % Number of decomposition levels
W = modwt(signal, wname, J);            % Compute MODWT

fprintf('Computed MODWT with wavelet = %s and J = %d.\n', wname, J);

%% (4) Global Wavelet Power Plot
scale_rows = 1:J;                       % Identify scale rows (1 to J)
energy = W(scale_rows,:).^2;            % Square coefficients to compute energy
wavelet_power = mean(energy, 2);        % Find global wavelet power per scale (variance)
period_center = (2.^(1:J))' * ds;       % Approximate center period per scale (days)

% Plot global wavelet power
figure('Name','Global Wavelet Power','Units','normalized','Position',[0.1 0.4 0.8 0.35]);
bar(period_center, wavelet_power);
set(gca,'XScale','log');               % log scale to fix x-axis spacing
xlabel('Approximate period (days)', 'FontWeight', 'bold');
ylabel('Wavelet variance (°C)^2', 'FontWeight', 'bold');
title('Global wavelet power (MODWT (db4))');

% (5) Find top scales by variance
[~, scaleOrder] = sort(wavelet_power,'descend');
fprintf('\nTop 5 MODWT scales by wavelet variance:\n');
for k = 1:min(5,J)
    jidx = scaleOrder(k);
    fprintf('%d: j=%d | approx period = %d days | variance = %.4e\n', k, jidx, round(period_center(jidx)), wavelet_power(jidx));
end
topScale = scaleOrder(1);
fprintf('Top MODWT scale (highest variance) = j = %d (~%d days)\n', topScale, round(period_center(topScale)));

%% (6) Multiresolution analysis
MRA = modwtmra(W, wname);                  % Apply MRA

% Check that the full reconstruction is approx equal to original signal
reconstructed_sum = sum(MRA,1)';
max_recon_err = max(abs(reconstructed_sum - signal));
fprintf('\nMRA reconstruction numerical max error = %g\n', max_recon_err);

% Group scales into interpretable bands for plots
D1_D2 = sum(MRA(1:min(2,J),:),1);           % High-frequency band
D4_D5 = sum(MRA(4:min(5,J),:),1);           % Mid-range band
D7 = MRA(7,:);
D8 = MRA(8,:);
D9 = MRA(9,:);
S_J = MRA(end,:);                           % Smooth band (broad trend)

% Plot MRA components
figure('Name','MRA Components (Full Series)','Units','normalized','Position',[0.1 0.1 0.8 0.9]);
subplot(7,1,1); plot(time, signal); title('Original'); ylabel('°C'); grid on;
subplot(7,1,2); plot(time, D1_D2); title('D1-D2 (High-Frequency)'); ylabel('°C'); grid on;
subplot(7,1,3); plot(time, D4_D5); title('D4–D5 (Mid-Frequency)'); ylabel('°C'); grid on;
subplot(7,1,4); plot(time, D7); title('D7 (Semiannual)'); ylabel('°C'); grid on;
subplot(7,1,5); plot(time, D8); title('D8 (Annual)'); ylabel('°C'); grid on;
subplot(7,1,6); plot(time, D9); title('D9 Long-term Trend (Low-Frequency)'); ylabel('°C'); grid on;
subplot(7,1,7); plot(time, S_J); title('Baseline Trend (S_J)'); ylabel('°C'); xlabel('Time'); grid on;

% Define 2020-2023 window for plot
t_start = datetime(2020,1,1);
t_end   = datetime(2023,12,31);
idx_window = (time >= t_start) & (time <= t_end);
time_win = time(idx_window);
signal_win = signal(idx_window);

% Plot MRA components only using years 2020-2023
figure('Name','MRA Components (2020–2023)','Units','normalized','Position',[0.15 0.15 0.8 0.9]);
subplot(7,1,1); plot(time_win, signal_win); title('Original (2020–2023)'); ylabel('°C'); grid on;
subplot(7,1,2); plot(time_win, D1_D2(idx_window)); title('D1-D2 (High-Frequency)'); ylabel('°C'); grid on;
subplot(7,1,3); plot(time_win, D4_D5(idx_window)); title('D4–D5 (Mid-Frequency)'); ylabel('°C'); grid on;
subplot(7,1,4); plot(time_win, D7(idx_window)); title('D7 (Semiannual)'); ylabel('°C'); grid on;
subplot(7,1,5); plot(time_win, D8(idx_window)); title('D8 (Annual)'); ylabel('°C'); grid on;
subplot(7,1,6); plot(time_win, D9(idx_window)); title('D9 Long-term Trend (Low-Frequency)'); ylabel('°C'); grid on;
subplot(7,1,7); plot(time_win, S_J(idx_window)); title('Baseline Trend (S_J)'); ylabel('°C'); xlabel('Time'); grid on;

%% (7) Reconstruct from top MODWT scale(s) and compute MSEs

% Single dominant scale reconstruction
dominant_scale_recon = MRA(topScale, :)' + MRA(end,:)';
MODWT_MSE_single = mean((signal - dominant_scale_recon).^2);

% Reconstruction from top 3 scales combined
numTopScales = min(3, J);                   % Top 3 scales selected
topScales = scaleOrder(1:numTopScales);
recon_topScales = sum(MRA(topScales, :), 1)' + MRA(end,:)';
MODWT_MSE_topK = mean((signal - recon_topScales).^2);

fprintf('\nMODWT (db4) reconstruction MSEs:\n');
fprintf('Single top scale j=%d MSE = %.5e\n', topScale, MODWT_MSE_single);
fprintf('Top %d scales (j=%s) combined MSE = %.5e\n', numTopScales, mat2str(topScales'), MODWT_MSE_topK);

% Plot comparisons: original vs single scale and top-K reconstruction
figure('Name','MODWT Reconstructions','Units','normalized','Position',[0.12 0.12 0.75 0.6]);

% Original signal
plot(time, signal, 'k', 'LineWidth',1.5, 'DisplayName','Original'); hold on;

% Top-K scales + baseline
plot(time, recon_topScales, 'Color',[137 207 240]/255, 'LineWidth',1.5, 'DisplayName', sprintf('Top %d scales + baseline', numTopScales));

% Single dominant scale + baseline
plot(time, dominant_scale_recon, 'Color',[231 124 74]/255, 'LineWidth',1.5, 'DisplayName', sprintf('Single top scale j=%d + baseline', topScale));

% Labels, grid, and legend
xlabel('Time'); 
ylabel('Temperature (°C)');
title('Original vs MODWT Reconstructions');
legend('Location','best'); 
grid on; 
