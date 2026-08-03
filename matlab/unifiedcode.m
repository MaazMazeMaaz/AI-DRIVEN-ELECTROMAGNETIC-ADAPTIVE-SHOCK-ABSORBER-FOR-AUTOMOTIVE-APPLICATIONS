% unified_electromagnet_SWG15_23_OD1p5_height0to3_using_SWG_table.m
% -------------------------------------------------------------------------
% Consistent model across SWG 15–23 with updated constraints:
% - Total magnet OUTER DIAMETER (core + windings) <= 1.5 in
% - Coil height in [0, 3] inches (0 allowed; zero-turn designs are skipped)
%
% SWG properties:
% - Uses SWG table headings: nominal (bare) conductor diameter,
%   insulation covering grades (Fine/Medium/Thick) to set overall OD,
%   and optionally resistance per meter at 20 °C if supplied.
%
% Physics (identical across all runs):
% - Magnetic circuit: air-gap + finite-μr core
% - Fringing: A_eff = π (r_core + α*g)^2
% - Saturation clamp from same reluctance model
% - Battery-limited + 6 A current cap
%
% Outputs:
% - Best design per SWG (max force)
% - Best overall (max force)
% - Results table + plots (force vs SWG, geometry, volume, wire length)
% -------------------------------------------------------------------------

clear; clc; close all;

%% ----------------------- USER INPUTS / ASSUMPTIONS -----------------------

% Electrical, magnetic, and geometric constraints
Vbat = 12.0;                % Battery voltage (V)
I_cap = 6.0;                % Max continuous current cap (A)
rho_cu = 1.68e-8;           % Resistivity of copper (ohm·m at 20°C)
mu0 = 4 * pi * 1e-7;        % Permeability of free space (H/m)
mu_r = 4000;                % Relative permeability (soft iron)
B_sat = 2.16;               % Saturation flux density (T)
g_in = 5;                   % Air gap (in)
g = g_in * 0.0254;          % Air gap (m)
alpha_fringe = 0.5;         % Fringing factor

% Target force (optional). Leave [] to disable min-volume search.
F_req = [];                 % Example: F_req = 15 * 9.81; % N

% NEW CONSTRAINTS
outer_diam_max_in = 1.9;                                % Max OD (in)
outer_rad_max_m = (outer_diam_max_in / 2) * 0.0254;     % Max OD (m)
h_coil_min_in = 0.00;                                   % Min coil height (in)
h_coil_max_in = 3.00;                                   % Max coil height (in)

% Sweep granularity
n_r = 60; 
n_h = 80;

% Sweep ranges
r_core_min_in = 0.05;                                   % Avoid zero
r_core_max_in = outer_diam_max_in / 2;
r_core_list = linspace(r_core_min_in, r_core_max_in, n_r) * 0.0254;
h_coil_list = linspace(h_coil_min_in, h_coil_max_in, n_h) * 0.0254;

%% ------------------ SWG TABLE: 15–23 WITH COVERING OPTIONS ----------------

% Covering grade options: 'Fine' | 'Medium' | 'Thick'
covering_grade = 'Medium';

% Default covering build percentages (diameter increase)
cover_build_pct.Fine   = 0.06;     % +6% on diameter
cover_build_pct.Medium = 0.10;     % +10% on diameter
cover_build_pct.Thick  = 0.15;     % +15% on diameter

% SWG table format: [SWG, bare_diameter_mm, R_per_m_ohm_20C]
% (R = 0 → compute using resistivity)
swg_rows = [ ...
    15, 1.83, 0.0215; ...
    16, 1.63, 0.0273; ...
    17, 1.42, 0.0356; ...
    18, 1.22, 0.0485; ...
    19, 1.02, 0.0698; ...
    20, 0.914, 0.0861; ...
    21, 0.813, 0.1090; ...
    22, 0.711, 0.1420; ...
    23, 0.610, 0.1940 ...
];

%% -------------------------- TRACKING CONTAINERS --------------------------

best_overall       = struct('F', -Inf);
best_overall_req   = [];
best_overall_req_vol = Inf;
best_per_swg       = [];

%% ----------------------------- MAIN SWEEP --------------------------------

for k = 1:size(swg_rows, 1)
    SWG = swg_rows(k, 1);
    bare_mm = swg_rows(k, 2);
    Rpm_tab = swg_rows(k, 3);

    d_bare = bare_mm / 1000;                      % Bare wire diameter (m)
    A_cu = pi * (d_bare / 2)^2;                   % Copper cross-section area (m²)

    % Apply insulation covering
    build = cover_build_pct.(covering_grade);
    d_overall = d_bare * (1 + build);             % Including insulation (m)

    best = struct('F', -Inf);
    best_req = [];
    best_req_vol = Inf;

    % Sweep through all core radii and coil heights
    for ir = 1:length(r_core_list)
        r_core = r_core_list(ir);
        if r_core >= outer_rad_max_m
            continue;
        end

        for ih = 1:length(h_coil_list)
            h_coil = h_coil_list(ih);

            % ---- Winding geometry constraints ----
            radial_layers_geom = floor(r_core / d_overall);
            radial_layers_od   = floor((outer_rad_max_m - r_core) / d_overall);
            radial_layers = min(radial_layers_geom, radial_layers_od);

            turns_per_layer = floor(h_coil / d_overall);
            if radial_layers < 1 || turns_per_layer < 1
                continue;
            end

            outer_r = r_core + radial_layers * d_overall;
            if outer_r > outer_rad_max_m
                continue;
            end

            N = radial_layers * turns_per_layer;

            % ---- Wire length per layer ----
            L_total = 0;
            for L = 1:radial_layers
                r_layer = r_core + (L - 0.5) * d_overall;
                L_total = L_total + (2 * pi * r_layer) * turns_per_layer;
            end

            % ---- Electrical properties ----
            if Rpm_tab > 0
                Rcoil = Rpm_tab * L_total;
            else
                Rcoil = rho_cu * L_total / A_cu;
            end

            I_volt = Vbat / Rcoil;

            % ---- Magnetic parameters ----
            l_core = h_coil;
            A_core = pi * r_core^2;
            A_eff  = pi * (r_core + alpha_fringe * g)^2;

            % Saturation current
            I_sat = (B_sat * (g + l_core / mu_r) * A_core) / (mu0 * N * A_eff);

            % Effective current
            I_eff = min([I_cap, I_volt, I_sat]);

            % Magnetic field & force
            B_gap = mu0 * N * I_eff / (g + l_core / mu_r);
            F = (B_gap^2 * A_eff) / (2 * mu0);

            % Volume metric
            vol = pi * outer_r^2 * h_coil;

            % ---- Track best for this SWG ----
            if F > best.F
                best = struct( ...
                    'SWG', SWG, 'covering', covering_grade, ...
                    'd_bare', d_bare, 'd_overall', d_overall, ...
                    'F', F, 'r_core', r_core, 'h_coil', h_coil, ...
                    'N', N, 'layers', radial_layers, ...
                    'turns_per_layer', turns_per_layer, ...
                    'L_total', L_total, 'Rcoil', Rcoil, 'I', I_eff, ...
                    'B_gap', B_gap, 'A_eff', A_eff, 'A_core', A_core, ...
                    'outer_r', outer_r, 'vol', vol);
            end

            % ---- Best design meeting required force (if any) ----
            if ~isempty(F_req) && F >= F_req && vol < best_req_vol
                best_req = best;
                best_req_vol = vol;
            end
        end
    end

    % ---- Save results per SWG ----
    if isfield(best, 'F') && isfinite(best.F)
        best_per_swg = [best_per_swg; best]; %#ok<AGROW>

        % Update global best (max force)
        if best.F > best_overall.F
            best_overall = best;
        end

        % Update best meeting F_req (if applicable)
        if ~isempty(F_req) && ~isempty(best_req) && best_req.vol < best_overall_req_vol
            best_overall_req = best_req;
            best_overall_req_vol = best_req.vol;
        end
    end
end

%% ----------------------------- PRINT SUMMARY -----------------------------

fprintf('\n=== Best per SWG (Unified Model, 12 V, 6 A cap, gap=%d in) ===\n', g_in);
fprintf('Constraint: OUTER DIAMETER <= %.2f in, Height in [%.2f, %.2f] in | Covering: %s\n', ...
    outer_diam_max_in, h_coil_min_in, h_coil_max_in, covering_grade);

for i = 1:numel(best_per_swg)
    r = best_per_swg(i);
    fprintf(['SWG %2d: F = %.1f N (%.2f kgf) | N=%d | I=%.2f A | R=%.2f Ω | ', ...
             'core_r=%.2f in | coil_h=%.2f in | OD=%.2f in | ', ...
             'd_bare=%.3f mm | d_overall=%.3f mm | L=%.1f m\n'], ...
             r.SWG, r.F, r.F/9.81, r.N, r.I, r.Rcoil, ...
             r.r_core/0.0254, r.h_coil/0.0254, 2*r.outer_r/0.0254, ...
             1e3*r.d_bare, 1e3*r.d_overall, r.L_total);
end

fprintf('\n--- Best overall (max force) ---\n');
if isfinite(best_overall.F)
    r = best_overall;
    fprintf('SWG %d | Force = %.1f N (%.2f kgf)\n', r.SWG, r.F, r.F/9.81);
    fprintf('Core radius = %.2f in, Coil height = %.2f in, OD = %.2f in\n', ...
        r.r_core/0.0254, r.h_coil/0.0254, 2*r.outer_r/0.0254);
    fprintf('Turns = %d, I=%.2f A, Rcoil=%.2f Ω, B_gap=%.3f T, Wire L = %.1f m, Covering = %s\n', ...
        r.N, r.I, r.Rcoil, r.B_gap, r.L_total, r.covering);
else
    fprintf('No valid design found under the given constraints.\n');
end

if ~isempty(F_req) && ~isempty(best_overall_req)
    r = best_overall_req;
    fprintf('\n--- Best meeting required force %.1f N (%.2f kgf, min volume) ---\n', F_req, F_req/9.81);
    fprintf('SWG %d | F=%.1f N, Volume=%.6f m^3\n', r.SWG, r.F, r.vol);
    fprintf('Core radius=%.2f in, Coil height=%.2f in, OD=%.2f in, Turns=%d, I=%.2f A, R=%.2f Ω, Wire L=%.1f m\n', ...
        r.r_core/0.0254, r.h_coil/0.0254, 2*r.outer_r/0.0254, r.N, r.I, r.Rcoil, r.L_total);
end

%% --------------------------- RESULTS TABLE -------------------------------

if ~isempty(best_per_swg)
    SWG_vec       = arrayfun(@(x)x.SWG, best_per_swg).';
    Force_N       = arrayfun(@(x)x.F, best_per_swg).';
    kgf           = Force_N / 9.81;
    Turns         = arrayfun(@(x)x.N, best_per_swg).';
    Current_A     = arrayfun(@(x)x.I, best_per_swg).';
    R_ohm         = arrayfun(@(x)x.Rcoil, best_per_swg).';
    Bgap_T        = arrayfun(@(x)x.B_gap, best_per_swg).';
    CoreRad_in    = arrayfun(@(x)x.r_core / 0.0254, best_per_swg).';
    CoilH_in      = arrayfun(@(x)x.h_coil / 0.0254, best_per_swg).';
    OuterDia_in   = arrayfun(@(x)2*x.outer_r / 0.0254, best_per_swg).';
    d_bare_mm     = arrayfun(@(x)1e3*x.d_bare, best_per_swg).';
    d_over_mm     = arrayfun(@(x)1e3*x.d_overall, best_per_swg).';
    Vol_m3        = arrayfun(@(x)x.vol, best_per_swg).';
    Aeff_m2       = arrayfun(@(x)x.A_eff, best_per_swg).';
    Ltotal_m      = arrayfun(@(x)x.L_total, best_per_swg).';

    results_best = table(SWG_vec, d_bare_mm, d_over_mm, Force_N, kgf, ...
        Turns, Current_A, R_ohm, Bgap_T, CoreRad_in, CoilH_in, ...
        OuterDia_in, Vol_m3, Aeff_m2, Ltotal_m, ...
        'VariableNames', {'SWG','Bare_d_mm','Overall_d_mm','Force_N','Force_kgf', ...
                          'Turns','Current_A','R_ohm','B_gap_T','CoreRad_in', ...
                          'CoilH_in','OuterDia_in','Volume_m3','A_eff_m2','WireLength_m'});

    disp(' ');
    disp('=== Best per SWG (table) ===');
    disp(results_best);
else
    warning('No valid SWG solutions found under the constraints.');
end

%% ------------------------------- PLOTS -----------------------------------

if exist('results_best', 'var') && ~isempty(results_best)

    % 1) Best Force per SWG
    figure;
    stem(results_best.SWG, results_best.Force_N, 'filled');
    xlabel('SWG'); ylabel('Max Force (N)');
    title(sprintf('Best Force per SWG', ...
        outer_diam_max_in, h_coil_min_in, h_coil_max_in));
    grid on;

    % 2) Force vs Core Radius
    figure;
    scatter(results_best.CoreRad_in, results_best.Force_N, 60, results_best.SWG, 'filled');
    xlabel('Core Radius (in)'); ylabel('Force (N)');
    title('Force vs Core Radius (best per SWG)');
    grid on; cb = colorbar; ylabel(cb, 'SWG');

    % 3) Force vs Coil Height
    figure;
    scatter(results_best.CoilH_in, results_best.Force_N, 60, results_best.SWG, 'filled');
    xlabel('Coil Height (in)'); ylabel('Force (N)');
    title('Force vs Coil Height (best per SWG)');
    grid on; cb = colorbar; ylabel(cb, 'SWG');

    % 4) Force vs Turns
    figure;
    scatter(results_best.Turns, results_best.Force_N, 60, results_best.SWG, 'filled');
    xlabel('Turns (N)'); ylabel('Force (N)');
    title('Force vs Turns (best per SWG)');
    grid on; cb = colorbar; ylabel(cb, 'SWG');

    % 5) Force vs Volume (trade-off)
    figure;
    scatter(results_best.Volume_m3 * 1e6, results_best.Force_N, 60, results_best.Current_A, 'filled');
    xlabel('Envelope Volume (cm^3)'); ylabel('Force (N)');
    title('Force vs Volume (best per SWG)');
    grid on; cb = colorbar; ylabel(cb, 'Current (A)');

    % 6) Wire Length vs Force
    figure;
    scatter(results_best.WireLength_m, results_best.Force_N, 60, results_best.SWG, 'filled');
    xlabel('Wire Length (m)'); ylabel('Force (N)');
    title('Force vs Wire Length (best per SWG)');
    grid on; cb = colorbar; ylabel(cb, 'SWG');

    % 7) Outer Diameter vs Force
    figure;
    scatter(results_best.OuterDia_in, results_best.Force_N, 60, results_best.SWG, 'filled');
    xlabel('Outer Diameter (in)'); ylabel('Force (N)');
    title('Force vs Outer Diameter (best per SWG)');
    grid on; cb = colorbar; ylabel(cb, 'SWG');

end
