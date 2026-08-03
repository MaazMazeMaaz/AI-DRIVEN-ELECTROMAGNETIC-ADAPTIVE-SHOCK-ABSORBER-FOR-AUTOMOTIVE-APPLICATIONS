% swg_best_wire_for_force_batteryLimited.m
% Finds best SWG and core geometry for max force with:
%   - 12 VDC 185 Ah battery (Vbat hard limit)
%   - 6 A wire safety limit
%   - 2.16 T saturation limit
%   - 5" air gap
%   - Max electromagnet diameter = 5"

clear; clc;

%% Constants
mu0   = 4*pi*1e-7;        % H/m
mu_r  = 4000;             % soft iron
B_sat = 2.16;             % Tesla
rho_cu = 1.68e-8;         % ohm*m (copper resistivity)
I_cap = 6.0;              % A (wire heating limit)
Vbat  = 12.0;             % V (battery)
g_in  = 5;                % in (air gap)
g     = g_in * 0.0254;    % m

% Core dimension constraints
r_core_min_in = 0.25;     % in
r_core_max_in = 2.5;      % in (diameter ≤ 5 in)
h_coil_min_in = 0.25;     % in
h_coil_max_in = 1.00;     % in
n_r = 60; n_h = 40;
r_core_list = linspace(r_core_min_in, r_core_max_in, n_r) * 0.0254;
h_coil_list = linspace(h_coil_min_in, h_coil_max_in, n_h) * 0.0254;

% SWG table (SWG, diameter mm)
swg_data = [ ...
  15, 1.83;
  16, 1.63;
  17, 1.42;
  18, 1.22;
  19, 1.02;
  20, 0.914;
  21, 0.813;
  22, 0.711;
  23, 0.610];

%% Tracking
best_overall.F = -Inf;
results = [];

for k = 1:size(swg_data,1)
    SWG = swg_data(k,1);
    wire_mm = swg_data(k,2);
    wire_d  = wire_mm/1000;            % m
    A_cu = pi*(wire_d/2)^2;           % copper cross-section

    best.F = -Inf;

    for ir = 1:length(r_core_list)
        r_core = r_core_list(ir);
        for ih = 1:length(h_coil_list)
            h_coil = h_coil_list(ih);

            % Fit layers and turns
            radial_layers    = floor((r_core) / wire_d);
            turns_per_layer  = floor(h_coil / wire_d);
            if radial_layers < 1 || turns_per_layer < 1
                continue;
            end
            N = radial_layers * turns_per_layer;

            % Mean turn length
            L_total = 0;
            for L = 1:radial_layers
                r_layer = r_core + (L - 0.5) * wire_d;
                L_total = L_total + 2*pi*r_layer * turns_per_layer;
            end

            % Coil resistance
            Rcoil = rho_cu * L_total / A_cu;

            % Max current from battery
            I_volt = Vbat / Rcoil;

            % Saturation limit
            A_core = pi * r_core^2;
            A_eff  = pi * (r_core + g)^2;   % fringing approximation
            l_core = h_coil;                % path length through core
            I_sat = B_sat * (g + l_core/mu_r) * A_core / (mu0 * N * A_eff);

            % Effective current
            I_eff = min([I_cap, I_volt, I_sat]);

            % Magnetic field in gap
            B_gap = mu0 * N * I_eff / (g + l_core/mu_r);

            % Force from Maxwell stress
            F = (B_gap^2 * A_eff) / (2*mu0);

            % Track best for this SWG
            if F > best.F
                best.F = F;
                best.SWG = SWG;
                best.wire_d = wire_d;
                best.r_core = r_core;
                best.h_coil = h_coil;
                best.N = N;
                best.layers = radial_layers;
                best.turns_per_layer = turns_per_layer;
                best.L_total = L_total;
                best.Rcoil = Rcoil;
                best.I_eff = I_eff;
                best.V_required = I_eff * Rcoil;
                best.B_gap = B_gap;
            end
        end
    end

    results = [results; best]; %#ok<AGROW>

    if best.F > best_overall.F
        best_overall = best;
    end
end

%% Print results
fprintf('\n=== Best per SWG (Battery-limited, 6 A cap, 5" gap, ≤5" dia) ===\n');
for i=1:numel(results)
    r = results(i);
    fprintf('SWG %2d: F = %.2f N | r_core = %.3f in | h_coil = %.3f in | N=%d | I_eff=%.2f A | Vreq=%.1f V\n', ...
        r.SWG, r.F, r.r_core/0.0254, r.h_coil/0.0254, r.N, r.I_eff, r.V_required);
end

fprintf('\n--- Best overall ---\n');
r = best_overall;
fprintf('SWG %2d | Force = %.2f N (%.2f kgf)\n', r.SWG, r.F, r.F/9.81);
fprintf('Core radius = %.3f in (diameter %.3f in)\n', r.r_core/0.0254, 2*r.r_core/0.0254);
fprintf('Coil height = %.3f in\n', r.h_coil/0.0254);
fprintf('Turns N = %d (layers=%d, turns/layer=%d)\n', r.N, r.layers, r.turns_per_layer);
fprintf('I_eff = %.2f A; V_required = %.1f V; R_coil = %.2f ohm\n', r.I_eff, r.V_required, r.Rcoil);
fprintf('B_gap = %.3f T\n', r.B_gap);

%% Visualize
SWGs = arrayfun(@(x)x.SWG, results);
Forces = arrayfun(@(x)x.F, results);
figure; stem(SWGs, Forces, 'filled');
xlabel('SWG'); ylabel('Max Force [N]');
title('Best Force per SWG (Battery-Limited, 6 A cap, ≤5" dia, 5" air gap)');
grid on;
