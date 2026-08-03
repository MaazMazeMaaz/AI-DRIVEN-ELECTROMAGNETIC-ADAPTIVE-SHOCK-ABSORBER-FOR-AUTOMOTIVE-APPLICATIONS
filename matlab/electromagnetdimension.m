% min_electromagnet_expanded_inch_capped.m
% Find minimum core size for 15 kg load over 5" gap with 6A current limit
clear; clc; close all;

%% Constants
inch = 0.0254;          % m/in
gap_in = 5;             % inches
g_m = gap_in * inch;    % gap in meters

F_req = 15 * 9.81;      % required force in N

% Wire parameters (SWG22)
wire_dia = 0.001698;     % m (outer with enamel)
copper_dia = 0.00163;   % m (bare copper)
rho_cu = 1.68e-8;       % Ohm·m

% Magnetic parameters
mu0 = 4*pi*1e-7;        % H/m
B_sat = 2.16;           % Tesla, soft iron

% Power supply
Vbat = 12;              % V

% Fringing factor for effective area
alpha_fringe = 0.5;     % r_eff = r_core + alpha*g

%% Sweep parameters (expanded)
r_core_range = linspace(0.005, 0.25, 200);   % core radius up to ~10" in meters
h_coil_range = linspace(0.005, 0.15, 150);   % coil height up to ~6" in meters

best_found_force = 0;   
best_found_vol = inf;   
best_found_any = [];    

results = [];

for r_core = r_core_range
    for h_coil = h_coil_range

        % Winding space: radial_layers × turns_per_layer
        radial_layers = max(floor((r_core) / wire_dia), 1);
        turns_per_layer = floor(h_coil / wire_dia);
        if turns_per_layer < 1
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
        A_cu = pi*(copper_dia/2)^2;
        Rcoil = rho_cu * L_total / A_cu;

        % Current from supply (safe continuous limit)
        I_max = 6;  % A
        I = min(Vbat / Rcoil, I_max);

        % Effective area with fringing
        r_eff = r_core + alpha_fringe * g_m;
        A_eff = pi * r_eff^2;

        % Gap flux density
        B_gap = mu0 * N * I / g_m;

        % Core flux density
        A_core = pi * r_core^2;
        B_core = B_gap * (A_eff / A_core);

        % Saturation clamp
        if B_core > B_sat
            I_sat = B_sat * g_m * A_core / (mu0 * N * A_eff);
            I = min(I, I_sat);
            B_gap = mu0 * N * I / g_m;
            B_core = B_gap * (A_eff / A_core);
        end

        % Force calculation
        F = (B_gap^2 * A_eff) / (2 * mu0);

        % Volume of core+coil
        vol = pi * (r_core + radial_layers*wire_dia)^2 * h_coil;

        % Save result
        results = [results; r_core, h_coil, N, I, F, vol, B_core];

        % Best meeting requirement
        if F >= F_req && vol < best_found_vol
            best_found_vol = vol;
            best_design_req = [r_core, h_coil, N, I, F, vol, B_core];
        end

        % Best force overall
        if F > best_found_force
            best_found_force = F;
            best_found_any = [r_core, h_coil, N, I, F, vol, B_core];
        end
    end
end

%% Output
if exist('best_design_req','var')
    fprintf('Best design meeting force requirement:\n');
    fprintf('Core radius: %.3f in\n', best_design_req(1)/inch);
    fprintf('Coil height: %.3f in\n', best_design_req(2)/inch);
    fprintf('Turns: %d\n', best_design_req(3));
    fprintf('Current: %.2f A\n', best_design_req(4));
    fprintf('Force: %.1f N (%.1f kgf)\n', best_design_req(5), best_design_req(5)/9.81);
    fprintf('Volume: %.6f m^3\n', best_design_req(6));
    fprintf('Core flux density: %.2f T\n', best_design_req(7));
else
    fprintf('No design met the force requirement of %.1f N.\n',F_req);
end

% Always print the best found
fprintf('\nBest design overall (max force, even if below requirement):\n');
fprintf('Core radius: %.3f in\n', best_found_any(1)/inch);
fprintf('Coil height: %.3f in\n', best_found_any(2)/inch);
fprintf('Turns: %d\n', best_found_any(3));
fprintf('Current: %.2f A\n', best_found_any(4));
fprintf('Force: %.1f N (%.1f kgf)\n', best_found_any(5), best_found_any(5)/9.81);
fprintf('Volume: %.6f m^3\n', best_found_any(6));
fprintf('Core flux density: %.2f T\n', best_found_any(7));

%% Visualization
results = array2table(results, ...
    'VariableNames',{'r_core_m','h_coil_m','Turns','Current_A','Force_N','Volume_m3','B_core_T'});

figure;
scatter3(results.r_core_m/inch, results.h_coil_m/inch, results.Force_N, 40, results.Force_N, 'filled');
xlabel('Core radius (in)');
ylabel('Coil height (in)');
zlabel('Force (N)');
title('Force vs Core Radius & Coil Height');
colorbar;
grid on;
