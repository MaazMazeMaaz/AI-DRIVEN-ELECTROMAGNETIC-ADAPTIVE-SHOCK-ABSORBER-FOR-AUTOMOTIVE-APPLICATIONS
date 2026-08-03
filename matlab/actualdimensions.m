% unified_electromagnet_SWG15_23_OD1p5_height0to3_using_SWG_table.m
% -------------------------------------------------------------------------
% Consistent model across SWG 15–23 with updated constraints:
%   - Total magnet OUTER DIAMETER (core + windings) <= 1.5 in
%   - Coil height in [0, 3] inches (0 allowed; zero-turn designs are skipped)
%
% SWG properties:
%   - Uses SWG table headings: nominal (bare) conductor diameter,
%     insulation covering grades (Fine/Medium/Thick) to set overall OD,
%     and (optionally) resistance per meter at 20 °C if supplied.
%
% Physics (identical across all runs):
%   - Magnetic circuit: air-gap + finite-μr core
%   - Fringing: A_eff = π (r_core + α*g)^2
%   - Saturation clamp from same reluctance model
%   - Battery-limited + 6 A current cap
%
% Outputs:
%   - Best design per SWG (max force)
%   - Best overall (max force)
%   - Results table + plots (force vs SWG, geometry, volume, wire length)
% -------------------------------------------------------------------------
clear; clc; close all;

%% ----------------------- User Inputs / Assumptions -----------------------
% Electrical, magnetic, and geometric constraints
Vbat  = 12.0;            % V  (battery)
I_cap = 6.0;             % A  (safe continuous current cap)
rho_cu = 1.68e-8;        % ohm·m (copper resistivity @ 20C)
mu0   = 4*pi*1e-7;       % H/m
mu_r  = 4000;            % relative permeability (soft iron, order-of-mag)
B_sat = 2.16;            % Tesla (soft iron saturation estimate)

g_in  = 5;               % air gap in inches
g     = g_in * 0.0254;   % m

alpha_fringe = 0.5;      % fringing factor

% Target force (optional). Set [] to disable min-volume search.
F_req = [];              % e.g., F_req = 15*9.81;  % N   (leave [] to disable)

% NEW CONSTRAINTS:
% Total magnet OUTER DIAMETER (core + windings) <= 1.5 in
outer_diam_max_in = 1.5;                    % in
outer_rad_max_m   = (outer_diam_max_in/2) * 0.0254;  % m

% Coil height range: 0–3 inches
h_coil_min_in = 0.00;                       % in
h_coil_max_in = 3.00;                       % in

% Sweep granularity
n_r = 60; 
n_h = 80;

% We sweep the *core radius* between small >0 up to outer radius max
r_core_min_in = 0.05; % avoid zero
r_core_max_in = outer_diam_max_in/2;        % cannot exceed outer radius limit
r_core_list = linspace(r_core_min_in, r_core_max_in, n_r) * 0.0254; % m
h_coil_list = linspace(h_coil_min_in, h_coil_max_in, n_h) * 0.0254; % m

%% ------------------ SWG table: 15–23 with covering options ----------------
% NOTE: Fill in *exact* R_per_m_ohm_20C and covering builds from your PDF if available.
% If R_per_m_ohm_20C == 0, the script computes resistance from rho_cu & bare area.
% Covering is applied as a *percentage increase in diameter* (build factor).
%
% You can set one of: 'Fine','Medium','Thick' as the active covering grade below.
covering_grade = 'Medium';  % 'Fine' | 'Medium' | 'Thick'

% Default covering build (%) for each grade (diameter increase).
% Replace these with exact values from your vendor table if you have them.
cover_build_pct.Fine   = 0.06;   % +6% on diameter
cover_build_pct.Medium = 0.10;   % +10% on diameter
cover_build_pct.Thick  = 0.15;   % +15% on diameter

% SWG  | bare_d_mm | R_per_m_ohm_20C (0 => compute from rho_cu)
swg_rows = [ ...
  15, 1.829, 0.0;  % SWG15
  16, 1.626, 0.0;  % SWG16
  17, 1.422, 0.0;  % SWG17
  18, 1.219, 0.0;  % SWG18
  19, 1.016, 0.0;  % SWG19
  20, 0.914, 0.0;  % SWG20
  21, 0.813, 0.0;  % SWG21
  22, 0.711, 0.0;  % SWG22
  23, 0.610, 0.0]; % SWG23

% If your PDF gives exact OD after covering per grade, you can instead
% replace the percentage builds above with literal OD values and bypass
% the percentage logic (see the compute section where OD is set).

%% -------------------------- Tracking containers --------------------------
best_overall = struct('F',-Inf);
best_overall_req = [];         % min-volume meeting F_req
best_overall_req_vol = Inf;

best_per_swg = [];             % array of structs, one per SWG

%% ----------------------------- Main sweep --------------------------------
for k = 1:size(swg_rows,1)
    SWG = swg_rows(k,1);
    bare_mm = swg_rows(k,2);
    Rpm_tab = swg_rows(k,3);   % ohm/m at 20C (0 => compute)

    d_bare  = bare_mm/1000;    % m, nominal conductor diameter (no insulation)
    A_cu    = pi*(d_bare/2)^2; % m^2 (copper cross-section)

    % Overall diameter incl. insulation via percentage build
    build = cover_build_pct.(covering_grade);
    d_overall = d_bare * (1 + build);  % m

    best = struct('F',-Inf);
    best_req = [];
    best_req_vol = Inf;

    for ir = 1:length(r_core_list)
        r_core = r_core_list(ir);
        if r_core >= outer_rad_max_m
            continue; % cannot place insulation if core radius already at limit
        end

        for ih = 1:length(h_coil_list)
            h_coil = h_coil_list(ih);

            % --- Packing with OUTER DIAMETER LIMIT enforced ---
            % Layers limited by geometry and OD cap
            radial_layers_geom = floor(r_core / d_overall);
            radial_layers_od   = floor((outer_rad_max_m - r_core) / d_overall);
            radial_layers      = min(radial_layers_geom, radial_layers_od);

            turns_per_layer  = floor(h_coil / d_overall);

            if radial_layers < 1 || turns_per_layer < 1
                continue; % cannot wind
            end

            % Final outer radius check
            outer_r = r_core + radial_layers * d_overall;
            if outer_r > outer_rad_max_m
                continue;
            end

            N = radial_layers * turns_per_layer;

            % Mean copper length per turn uses *layer circumference* at copper radius.
            % We approximate copper centerline radius ~ r_core + (L-0.5)*d_overall
            % (enamel thickness << wire OD for copper area computation).
            L_total = 0;
            for L = 1:radial_layers
                r_layer = r_core + (L - 0.5) * d_overall;
                L_total = L_total + (2*pi*r_layer) * turns_per_layer;
            end

            % Coil DC resistance
            if Rpm_tab > 0
                % Use vendor's resistance per meter directly
                Rcoil = Rpm_tab * L_total;
            else
                % Compute from resistivity and bare copper area
                Rcoil = rho_cu * L_total / A_cu;
            end

            % Electrical/battery limit
            I_volt = Vbat / Rcoil;

            % Magnetic geometry
            l_core = h_coil;                 % approximate core path length
            A_core = pi * r_core^2;
            A_eff  = pi * (r_core + alpha_fringe*g)^2;

            % Saturation current using same (gap + core) reluctance model
            I_sat = B_sat * (g + l_core/mu_r) * A_core / (mu0 * N * A_eff);

            % Effective current
            I_eff = min([I_cap, I_volt, I_sat]);

            % Gap flux density
            B_gap = mu0 * N * I_eff / (g + l_core/mu_r);

            % Force
            F = (B_gap^2 * A_eff) / (2*mu0);

            % Volume metric (envelope)
            vol = pi * outer_r^2 * h_coil;

            % Track best force for this SWG
            if F > best.F
                best = struct( ...
                    'SWG', SWG, 'covering', covering_grade, ...
                    'd_bare', d_bare, 'd_overall', d_overall, ...
                    'F', F, 'r_core', r_core, 'h_coil', h_coil, ...
                    'N', N, 'layers', radial_layers, 'turns_per_layer', turns_per_layer, ...
                    'L_total', L_total, 'Rcoil', Rcoil, 'I', I_eff, ...
                    'B_gap', B_gap, 'A_eff', A_eff, 'A_core', A_core, ...
                    'outer_r', outer_r, 'vol', vol);
            end

            % Track min-volume design meeting target (if enabled)
            if ~isempty(F_req) && F >= F_req && vol < best_req_vol
                best_req = struct( ...
                    'SWG', SWG, 'covering', covering_grade, ...
                    'd_bare', d_bare, 'd_overall', d_overall, ...
                    'F', F, 'r_core', r_core, 'h_coil', h_coil, ...
                    'N', N, 'layers', radial_layers, 'turns_per_layer', turns_per_layer, ...
                    'L_total', L_total, 'Rcoil', Rcoil, 'I', I_eff, ...
                    'B_gap', B_gap, 'A_eff', A_eff, 'A_core', A_core, ...
                    'outer_r', outer_r, 'vol', vol);
                best_req_vol = vol;
            end
        end
    end

    % Save per-SWG best
    if isfield(best,'F') && isfinite(best.F)
        best_per_swg = [best_per_swg; best]; %#ok<AGROW>
        % Update overall best force
        if best.F > best_overall.F
            best_overall = best;
        end
        % Update overall best meeting F_req
        if ~isempty(F_req) && ~isempty(best_req) && best_req.vol < best_overall_req_vol
            best_overall_req = best_req;
            best_overall_req_vol = best_req.vol;
        end
    end
end

%% ----------------------------- Print summary -----------------------------
fprintf('\n=== Best per SWG (Unified Model, 12 V, 6 A cap, gap=%d in) ===\n', g_in);
fprintf('Constraint: OUTER DIAMETER <= %.2f in, Height in [%.2f, %.2f] in | Covering: %s\n', ...
    outer_diam_max_in, h_coil_min_in, h_coil_max_in, covering_grade);

for i = 1:numel(best_per_swg)
    r = best_per_swg(i);
    fprintf(['SWG %2d: F = %.1f N (%.2f kgf) | N=%d | I=%.2f A | R=%.2f Ω | ', ...
             'core_r=%.2f in | coil_h=%.2f in | OD=%.2f in | d_bare=%.3f mm | d_overall=%.3f mm | L=%.1f m\n'], ...
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

%% --------------------------- Results table -------------------------------
if ~isempty(best_per_swg)
    SWG_vec     = arrayfun(@(x)x.SWG, best_per_swg).';
    Force_N     = arrayfun(@(x)x.F, best_per_swg).';
    kgf         = Force_N/9.81;
    Turns       = arrayfun(@(x)x.N, best_per_swg).';
    Current_A   = arrayfun(@(x)x.I, best_per_swg).';
    R_ohm       = arrayfun(@(x)x.Rcoil, best_per_swg).';
    Bgap_T      = arrayfun(@(x)x.B_gap, best_per_swg).';
    CoreRad_in  = arrayfun(@(x)x.r_core/0.0254, best_per_swg).';
    CoilH_in    = arrayfun(@(x)x.h_coil/0.0254, best_per_swg).';
    OuterDia_in = arrayfun(@(x)2*x.outer_r/0.0254, best_per_swg).';
    d_bare_mm   = arrayfun(@(x)1e3*x.d_bare, best_per_swg).';
    d_over_mm   = arrayfun(@(x)1e3*x.d_overall, best_per_swg).';
    Vol_m3      = arrayfun(@(x)x.vol, best_per_swg).';
    Aeff_m2     = arrayfun(@(x)x.A_eff, best_per_swg).';
    Ltotal_m    = arrayfun(@(x)x.L_total, best_per_swg).';

    results_best = table(SWG_vec, d_bare_mm, d_over_mm, Force_N, kgf, Turns, Current_A, R_ohm, Bgap_T, ...
                         CoreRad_in, CoilH_in, OuterDia_in, Vol_m3, Aeff_m2, Ltotal_m, ...
                         'VariableNames', {'SWG','Bare_d_mm','Overall_d_mm','Force_N','Force_kgf','Turns', ...
                                           'Current_A','R_ohm','B_gap_T','CoreRad_in', ...
                                           'CoilH_in','OuterDia_in','Volume_m3','A_eff_m2','WireLength_m'});
    disp(' ');
    disp('=== Best per SWG (table) ===');
    disp(results_best);
else
    warning('No valid SWG solutions found under the constraints.');
end

%% ------------------------------- Plots -----------------------------------
if exist('results_best','var') && ~isempty(results_best)

    % 1) Best Force per SWG
    figure;
    stem(results_best.SWG, results_best.Force_N, 'filled');
    xlabel('SWG'); ylabel('Max Force (N)');
    title(sprintf('Best Force per SWG (OD \\le %.1f", H \\in [%.1f, %.1f]")', ...
        outer_diam_max_in, h_coil_min_in, h_coil_max_in));
    grid on;

    % 2) Force vs Core Radius (best per SWG)
    figure;
    scatter(results_best.CoreRad_in, results_best.Force_N, 60, results_best.SWG, 'filled');
    xlabel('Core Radius (in)'); ylabel('Force (N)');
    title('Force vs Core Radius (best per SWG)'); grid on; cb=colorbar; ylabel(cb,'SWG');

    % 3) Force vs Coil Height (best per SWG)
    figure;
    scatter(results_best.CoilH_in, results_best.Force_N, 60, results_best.SWG, 'filled');
    xlabel('Coil Height (in)'); ylabel('Force (N)');
    title('Force vs Coil Height (best per SWG)'); grid on; cb=colorbar; ylabel(cb,'SWG');

    % 4) Force vs Turns (colored by SWG)
    figure;
    scatter(results_best.Turns, results_best.Force_N, 60, results_best.SWG, 'filled');
    xlabel('Turns (N)'); ylabel('Force (N)');
    title('Force vs Turns (best per SWG)'); grid on; cb=colorbar; ylabel(cb,'SWG');

    % 5) Volume vs Force (trade-off), colored by current
    figure;
    scatter(results_best.Volume_m3*1e6, results_best.Force_N, 60, results_best.Current_A, 'filled');
    xlabel('Envelope Volume (cm^3)'); ylabel('Force (N)');
    title('Force vs Volume (best per SWG)'); grid on; cb=colorbar; ylabel(cb,'Current (A)');

    % 6) Wire length vs Force (sanity check of copper usage)
    figure;
    scatter(results_best.WireLength_m, results_best.Force_N, 60, results_best.SWG, 'filled');
    xlabel('Wire Length (m)'); ylabel('Force (N)');
    title('Force vs Wire Length (best per SWG)'); grid on; cb=colorbar; ylabel(cb,'SWG');

    % 7) Outer diameter check vs Force
    figure;
    scatter(results_best.OuterDia_in, results_best.Force_N, 60, results_best.SWG, 'filled');
    xlabel('Outer Diameter (in)');
    ylabel('Force (N)');
    title('Force vs Outer Diameter (best per SWG)');
    grid on; cb=colorbar; ylabel(cb,'SWG');

end
