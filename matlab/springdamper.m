clc; clear; close all;

%% ===== USER INPUTS =====
m = input('Enter mass supported by suspension (kg): ');
x_max = input('Enter maximum allowable displacement (m): ');
F_em = input('Enter electromagnetic repulsive force (N): ');
road_type = input('Enter road type (1=asphalt, 2=gravel, 3=speed bump): ');

%% ===== STEP 1: SPRING STIFFNESS =====
% Total force = electromagnetic + spring force
% F_total = k*x → k = (F_required - F_em)/x

g = 9.81;
F_load = m * g;

k = (F_load - F_em) / x_max;

fprintf('\nRequired Spring Stiffness (k): %.2f N/m\n', k);

%% ===== STEP 2: NATURAL FREQUENCY =====
wn = sqrt(k/m);   % rad/s
fprintf('Natural Frequency (wn): %.2f rad/s\n', wn);

%% ===== STEP 3: DAMPING COEFFICIENT =====
% Critical damping
c_critical = 2 * sqrt(k * m);

% Select damping ratio based on terrain
if road_type == 1
    zeta = 0.2;   % smooth road (comfort)
elseif road_type == 2
    zeta = 0.5;   % medium rough
elseif road_type == 3
    zeta = 0.8;   % high damping (speed bump)
else
    zeta = 0.5;
end

c = zeta * c_critical;

fprintf('Damping Coefficient (c): %.2f Ns/m\n', c);
fprintf('Damping Ratio (zeta): %.2f\n', zeta);

%% ===== STEP 4: DAMPING TYPE =====
if zeta < 1
    disp('System is UNDERDAMPED (preferred for vehicles)');
elseif zeta == 1
    disp('System is CRITICALLY DAMPED');
else
    disp('System is OVERDAMPED');
end

%% ===== STEP 5: FLUID VISCOSITY ESTIMATION =====
% Approximate relation: c ≈ μ * A / h

A = input('\nEnter piston area (m^2): ');
h = input('Enter fluid gap thickness (m): ');

mu = (c * h) / A;

fprintf('Estimated Fluid Viscosity (mu): %.4f Pa.s\n', mu);

%% ===== STEP 6: FLUID SUGGESTION =====
if mu < 0.1
    disp('Suggested Fluid: Low viscosity oil (light hydraulic oil)');
elseif mu < 0.5
    disp('Suggested Fluid: Medium viscosity oil');
else
    disp('Suggested Fluid: High viscosity damping fluid / MR fluid');
end