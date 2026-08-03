clc; clear; close all;

%% --------------------- CONSTANTS ---------------------
mu0 = 4 * pi * 1e-7;        % H/m
mu_r = 4000;                % Relative permeability of core (soft iron)
alpha_fringe = 0.5;         % Fringing factor
B_sat = 2.16;               % T (saturation)
Vbat = 12;                  % V
I_cap = 6;                  % A max

%% --------------------- BEST DESIGN PARAMETERS ---------------------
SWG = 18;
N = 448;                    % Turns
Rcoil = 1.80;               % Ohms
I_nominal = 5.86;           % A (from earlier)
r_core_in = 0.31;           % in
h_coil_in = 3.00;           % in
outer_diam_in = 1.46;       % in

% Convert to meters
r_core = r_core_in * 0.0254;
h_coil = h_coil_in * 0.0254;

%% --------------------- AIR GAP RANGE ---------------------
gaps_in = linspace(5, 0, 200);    % in
gaps_m = gaps_in * 0.0254;        % m

%% --------------------- PREPARE STORAGE ---------------------
F = zeros(size(gaps_m));
B_gap = zeros(size(gaps_m));
I_eff = zeros(size(gaps_m));

%% --------------------- LOOP OVER AIR GAPS ---------------------
for k = 1:length(gaps_m)
    g = gaps_m(k);
    if g <= 0
        g = 1e-5; % avoid divide-by-zero
    end

    % ---- Magnetic circuit geometry ----
    l_core = h_coil;                 % core length (approx)
    A_core = pi * r_core^2;
    A_eff = pi * (r_core + alpha_fringe * g)^2;  % fringing adjusted

    % ---- Electrical side ----
    I_volt = Vbat / Rcoil;
    I_eff(k) = min(I_cap, I_volt);   % still 6A cap

    % ---- Saturation current ----
    I_sat = (B_sat * (g + l_core/mu_r) * A_core) / (mu0 * N * A_eff);
    I_eff(k) = min(I_eff(k), I_sat); % apply saturation clamp

    % ---- Magnetic field ----
    B_gap(k) = mu0 * N * I_eff(k) / (g + l_core/mu_r);
    F(k) = (B_gap(k)^2 * A_eff) / (2 * mu0);
end

%% --------------------- DISPLAY ---------------------
tableData = table(gaps_in.', F.', I_eff.', B_gap.', ...
    'VariableNames', {'AirGap_in','Force_N','Current_A','FluxDensity_T'});
disp(tableData(1:10,:)); % show first 10 entries

%% --------------------- PLOTS ---------------------
figure;
yyaxis left
plot(gaps_in, F, 'LineWidth', 1.8);
ylabel('Force (N)');
yyaxis right
plot(gaps_in, B_gap, '--', 'LineWidth', 1.5);
ylabel('Flux Density (T)');
xlabel('Air Gap (in)');
title(sprintf('Force and Flux Density vs Air Gap (SWG %d Coil)', SWG));
legend('Force','Flux Density','Location','northwest');
grid on;
