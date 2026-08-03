clc; clear; close all;

%% ===== 1. INPUT PARAMETERS & DESIGN OBJECTIVES =====
fprintf('--- Research-Grade Active Suspension Spring Tool ---\n');
m = input('Enter sprung mass per wheel (kg) [e.g., 50]: ');
f_n_target = input('Enter target natural frequency (Hz) [e.g., 1.5]: ');
stroke = input('Enter total shock stroke (m) [e.g., 0.10]: ');
L = input('Enter motion ratio (Shock Travel / Wheel Travel) [e.g., 1.0]: ');
F_em = input('Enter static electromagnetic lift (N) [0 if none]: ');

% Engineering Constants (Validated by Research)
g = 9.81;               
G = 79.3e9;             % High-carbon steel / Music wire (Pa)
ID_in = 2.5;            % Inner Diameter constraint (inches)
ID = ID_in * 0.0254;    
C = 12;                 % Spring Index (Progressive/Soft geometry)
Safety_Factor = 1.2;    % Clearance factor from research (1.2 - 1.5)

%% ===== 2. SPRING RATE & STATIC SAG =====
% Calculate required wheel rate based on target frequency
k_wheel = (2 * pi * f_n_target)^2 * m;

% Convert wheel rate to actual spring rate using motion ratio (L)
% Formula: k_wheel = k_spring * L^2  --> k_spring = k_wheel / L^2
k_spring = k_wheel / (L^2);

% Calculate Static Sag accounting for electromagnetic lift
F_gravity = m * g;
F_net_load = F_gravity - F_em;
delta_static = (F_net_load / k_wheel) * L; % Sag at the shock (m)

%% ===== 3. SPRING GEOMETRY SELECTION =====
% Applying Wahl's logic for wire dimensions
d = ID / (C - 1);       
D = ID + d;             
OD = D + d;             

% Active coils (n) derived from k = (G*d^4)/(8*n*D^3)
n = (G * d^4) / (8 * (D^3) * k_spring); 
total_coils = n + 2;     
Ls = total_coils * d;   % Solid Height

% Free Length (L0) = Solid Height + Stroke + Clearance
clearance = stroke * (Safety_Factor - 1);
L0 = Ls + stroke + clearance;

%% ===== 4. EXPERIMENTAL VALIDATION REPORT =====
fprintf('\n================ SPRING DESIGN REPORT ================\n');
fprintf('TARGET: %.2f Hz Natural Frequency\n', f_n_target);
fprintf('------------------------------------------------------\n');
fprintf('Required Spring Rate (k):  %.2f N/m (%.2f N/mm)\n', k_spring, k_spring/1000);
fprintf('Static Sag at Shock:       %.1f mm\n', delta_static * 1000);
fprintf('Inner Diameter (ID):       %.2f in\n', ID_in);
fprintf('Wire Diameter (d):         %.2f mm\n', d * 1000);
fprintf('Outer Diameter (OD):       %.2f mm\n', OD * 1000);
fprintf('Active Coils (n):          %.2f\n', n);
fprintf('Solid Height (Ls):         %.1f mm\n', Ls * 1000);
fprintf('Free Length (L0):          %.1f mm\n', L0 * 1000);
fprintf('======================================================\n');

% Validation Warning based on Stroke Constraint
if delta_static > stroke
    fprintf('\n!! VALIDATION WARNING: Static sag (%.1f mm) exceeds total stroke (%.1f mm).\n', delta_static*1000, stroke*1000);
    fprintf('SOLUTION: Apply spring preload or increase the target natural frequency.\n');
end