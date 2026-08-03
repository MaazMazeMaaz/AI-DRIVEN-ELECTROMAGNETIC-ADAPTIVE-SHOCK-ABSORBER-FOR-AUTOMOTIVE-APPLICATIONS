%% Short-circuit withstand time for SWG wires under 6 A
clear; clc;

% K constant for copper (from IEC 60364-5-54, theta_i=30°C, theta_f=160°C)
K_cu = 226; % A*sqrt(s)/mm^2

% SWG data (approximate diameters in mm for bare copper)
SWG_numbers = 15:23;
SWG_diam_mm = [1.83, 1.63, 1.42, 1.22, 1.02, 0.914, 0.813, 0.711, 0.610]; % bare wire diameters

% Current
I = 6; % A

% Preallocate results
results = [];

for i = 1:length(SWG_numbers)
    d = SWG_diam_mm(i);          % diameter (mm)
    S = pi*(d/2)^2;              % cross-sectional area (mm^2)
    t = ((K_cu * S)^2) / I^2;    % time to withstand 6 A (s)
    
    results = [results; SWG_numbers(i), d, S, t];
end

% Display results in table
T = array2table(results, ...
    'VariableNames', {'SWG','Dia_mm','Area_mm2','Time_s'});
disp(T);

% Plot results
figure;
bar(T.SWG, T.Time_s);
xlabel('SWG Number');
ylabel('Withstand Time at 6 A (s)');
title('Continuous Current Survival Time for SWG Copper Wires');
grid on;
