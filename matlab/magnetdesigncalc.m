% capped_first_code_cylinder_constraints_plot.m
% Sweep version of first engineering-estimate code with current cap + physical limits + plots

clear; clc;

%% Inputs
Vbat = 12;               % Battery voltage [V]
g_in = 5;                % Air gap [inches]
g = g_in * 0.0254;        % Gap in meters

% Wire data (SWG 22)
copper_dia = 0.00163;     % Bare copper diameter [m]
wire_dia = 0.001698;       % With enamel
rho_cu = 1.68e-8;         % Resistivity [Ohm*m]

% Magnetic core
B_sat = 2.16;             % Saturation [T]
mu0 = 4*pi*1e-7;          % H/m

% Fringing factor
alpha_fringe = 0.5;

% Current limit
I_max = 6;                % [A] safe continuous for SWG 22

%% Physical constraints (shock absorber limits)
max_core_radius = (5/2) * 0.0254;  % 5 in diameter max
max_coil_height = 1 * 0.0254;      % 1 in coil height max

%% Sweep ranges (within constraints)
r_core_range = linspace(0.005, max_core_radius, 50);   
h_coil_range = linspace(0.005, max_coil_height, 40);   

% Store results
F_matrix = zeros(length(h_coil_range), length(r_core_range));

best_force = -Inf;
best_params = struct();

for i_r = 1:length(r_core_range)
    for i_h = 1:length(h_coil_range)

        r_core = r_core_range(i_r);
        h_coil = h_coil_range(i_h);

        % Winding geometry
        radial_layers = floor(r_core / wire_dia);
        turns_per_layer = floor(h_coil / wire_dia);
        if radial_layers < 1 || turns_per_layer < 1
            F_matrix(i_h, i_r) = NaN;
            continue;
        end
        N = radial_layers * turns_per_layer;

        % Mean length per turn
        L_total = 0;
        for L = 1:radial_layers
            r_layer = r_core + (L - 0.5) * wire_dia;
            L_total = L_total + 2*pi*r_layer * turns_per_layer;
        end

        % Coil resistance
        A_cu = pi * (copper_dia/2)^2;
        Rcoil = rho_cu * L_total / A_cu;

        % Current with cap
        I_no_cap = Vbat / Rcoil;
        I = min(I_no_cap, I_max);

        % Effective pole area (fringing)
        r_eff = r_core + alpha_fringe * g;
        A_eff = pi * r_eff^2;

        % Gap flux density
        B_gap = mu0 * N * I / g;

        % Core flux density
        A_core = pi * r_core^2;
        B_core = B_gap * (A_eff / A_core);

        % Saturation clamp
        if B_core > B_sat
            I_sat = B_sat * g * A_core / (mu0 * N * A_eff);
            I = min(I, I_sat);
            B_gap = mu0 * N * I / g;
            B_core = B_gap * (A_eff / A_core);
        end

        % Force
        F = (B_gap^2 * A_eff) / (2 * mu0);
        F_matrix(i_h, i_r) = F;

        % Store best design
        if F > best_force
            best_force = F;
            best_params.r_core = r_core;
            best_params.h_coil = h_coil;
            best_params.N = N;
            best_params.layers = radial_layers;
            best_params.turns_per_layer = turns_per_layer;
            best_params.Rcoil = Rcoil;
            best_params.I_no_cap = I_no_cap;
            best_params.I = I;
            best_params.B_gap = B_gap;
            best_params.B_core = B_core;
            best_params.A_eff = A_eff;
        end
    end
end

%% Output best design
fprintf('--- Best design found (within cylinder limits, capped) ---\n');
fprintf('Core radius = %.4f m (%.3f in)\n', best_params.r_core, best_params.r_core/0.0254);
fprintf('Core diameter = %.4f m (%.3f in)\n', 2*best_params.r_core, 2*best_params.r_core/0.0254);
fprintf('Coil height = %.4f m (%.3f in)\n', best_params.h_coil, best_params.h_coil/0.0254);
fprintf('Total turns N = %d (layers = %d, turns/layer = %d)\n', ...
    best_params.N, best_params.layers, best_params.turns_per_layer);
fprintf('Coil DC resistance ~ %.3f ohm\n', best_params.Rcoil);
fprintf('Applied current (capped) = %.3f A (no cap = %.3f A)\n', ...
    best_params.I, best_params.I_no_cap);
fprintf('Coil power loss = %.2f W\n', best_params.I^2 * best_params.Rcoil);
fprintf('Estimated gap field B_gap = %.3f T\n', best_params.B_gap);
fprintf('Estimated core B = %.3f T (B_sat = %.2f T)\n', best_params.B_core, B_sat);
fprintf('Estimated attraction force = %.2f N (%.2f kgf)\n', ...
    best_force, best_force/9.81);
fprintf('Effective pole area (fringing corrected) = %.5f m^2\n', best_params.A_eff);

%% Visualization
figure;
surf(r_core_range/0.0254, h_coil_range/0.0254, F_matrix);
xlabel('Core Radius [in]');
ylabel('Coil Height [in]');
zlabel('Force [N]');
title(sprintf('Force vs Core Radius & Coil Height (Gap = %.1f in, I_{max} = %.1f A)', g_in, I_max));
shading interp; colorbar;


