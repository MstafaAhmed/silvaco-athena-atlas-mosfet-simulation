%% ========================================================================
%  plot_mosfet_idvd.m
%
%  Imports Id-Vd family-of-curves data extracted from Silvaco ATLAS
%  (via the "extract ... curve(v."drain", i."drain") outfile=..." commands
%  in the ATLAS deck) and plots the MOSFET output characteristics.
%
%  Expected input files (2-column ASCII: V_drain  I_drain), one per Vgate:
%    idvd_vg1.dat   -> Vgate = 1 V
%    idvd_vg2.dat   -> Vgate = 2 V
%    idvd_vg3.dat   -> Vgate = 5 V
%
%  Place this script in the same folder as the .dat files, or edit
%  dataFolder below.
% ========================================================================

clear; clc; close all;

%% ---------------- TCAD / ATHENA-ATLAS PROCESS PARAMETERS ----------------
% These mirror the exact values used in the Silvaco ATHENA/ATLAS deck,
% kept here so the plot is self-documenting and traceable back to the
% process split that generated the device.

params.substrate_doping   = 1.0e15;   % cm^-3, boron (p-type substrate), c.boron=1.0e15
params.substrate_orient   = '100';    % crystal orientation
params.field_oxide_temp_C = 1250;     % deg C, dry O2, diffus time=250 min
params.field_oxide_time_min = 250;    % minutes
params.gate_oxide_temp_C  = 1000;     % deg C, dry O2, diffus time=50 min (after field ox strip)
params.gate_oxide_time_min = 50;      % minutes
params.poly_thickness_um  = 0.2;      % um, deposit polysilicon thick=0.2
params.poly_reox_temp_C   = 1000;     % deg C, dry O2, diffus time=10 min
params.poly_reox_time_min = 10;       % minutes
params.implant_species    = 'Arsenic';
params.implant_dose_cm2   = 5.0e14;   % cm^-2, source/drain implant
params.implant_energy_keV = 50;       % keV
params.implant_tilt_deg   = 0;
params.metal              = 'Aluminum';
params.metal_thickness_um = 0.05;     % um, deposit aluminum thick=0.05
params.fixed_oxide_charge = 3e10;     % cm^-2, interface qf=3e10
params.temperature_K      = 300;      % simulation temperature

% Bias conditions used in the ATLAS solve statements
Vgate      = [1, 2, 5];               % V, three gate bias points simulated
Vd_start   = 0;
Vd_stop    = 3.3;
Vd_step    = 0.3;

fprintf('=== TCAD Process Parameters ===\n');
fprintf('Substrate doping   : %.2e cm^-3 (boron, %s orientation)\n', ...
        params.substrate_doping, params.substrate_orient);
fprintf('Field oxide anneal : %d min @ %d C (dry O2)\n', ...
        params.field_oxide_time_min, params.field_oxide_temp_C);
fprintf('Gate oxide anneal  : %d min @ %d C (dry O2)\n', ...
        params.gate_oxide_time_min, params.gate_oxide_temp_C);
fprintf('Poly thickness     : %.2f um\n', params.poly_thickness_um);
fprintf('Poly reoxidation   : %d min @ %d C (dry O2)\n', ...
        params.poly_reox_time_min, params.poly_reox_temp_C);
fprintf('S/D implant        : %s, dose=%.2e cm^-2, energy=%d keV, tilt=%d deg\n', ...
        params.implant_species, params.implant_dose_cm2, ...
        params.implant_energy_keV, params.implant_tilt_deg);
fprintf('Metal              : %s, thickness=%.2f um\n', ...
        params.metal, params.metal_thickness_um);
fprintf('Fixed oxide charge : %.1e cm^-2\n', params.fixed_oxide_charge);
fprintf('Simulation temp    : %d K\n', params.temperature_K);
fprintf('Gate voltages      : %s V\n', mat2str(Vgate));
fprintf('Drain sweep        : %.1f -> %.1f V, step %.1f V\n\n', ...
        Vd_start, Vd_stop, Vd_step);

%% ---------------------------- FILE SETUP --------------------------------
dataFolder = pwd;   % change if .dat files are elsewhere, e.g. 'C:\atlas_run\'

files = {'idvd_vg1.dat', 'idvd_vg2.dat', 'idvd_vg3.dat'};

nCurves = numel(files);
curveData = cell(nCurves,1);

%% ---------------------------- IMPORT DATA -------------------------------
%% ---------------------------- IMPORT DATA -------------------------------
for k = 1:nCurves

    fpath = fullfile(dataFolder, files{k});

    % Check file existence (compatible with MATLAB R2017a)
    if exist(fpath,'file') ~= 2
        warning('File not found:\n%s',fpath);
        curveData{k} = [];
        continue;
    end

    fprintf('Reading: %s\n',fpath);

    % Open file
    fid = fopen(fpath,'r');

    if fid==-1
        warning('Cannot open %s',fpath);
        curveData{k}=[];
        continue;
    end

    % Skip the Silvaco header (4 lines)
    raw = textscan(fid,...
        '%f %f',...
        'HeaderLines',4,...
        'CollectOutput',true,...
        'MultipleDelimsAsOne',true);

    fclose(fid);

    data = raw{1};

    if isempty(data)
        warning('No numerical data found in %s',fpath);
        curveData{k}=[];
        continue;
    end

    % Remove NaN rows if any
    data = data(all(~isnan(data),2),:);

    curveData{k}=data;

    fprintf('  %d points imported.\n',size(data,1));

end
%% ---------------------------- PLOT Id-Vd --------------------------------
figure('Name','MOSFET Output Characteristics','Color','w');
hold on; grid on; box on;

colors = lines(nCurves);
legendEntries = cell(nCurves,1);

for k = 1:nCurves
    if isempty(curveData{k})
        continue;
    end
    Vd = curveData{k}(:,1);
    Id = abs(curveData{k}(:,2));   % magnitude, since ATLAS current sign
                                    % convention can be negative for
                                    % conventional current into an electrode

    plot(Vd, Id, '-o', 'Color', colors(k,:), 'LineWidth', 1.6, ...
         'MarkerSize', 4, 'MarkerFaceColor', colors(k,:));
    legendEntries{k} = sprintf('V_{GS} = %g V', Vgate(k));
end

xlabel('V_{DS}  (V)');
ylabel('I_D  (A)');
title(sprintf(['NMOS Output Characteristics  |  N_A = %.1e cm^{-3}, ' ...
       'AsDose = %.1e cm^{-2}, T = %d K'], ...
       params.substrate_doping, params.implant_dose_cm2, params.temperature_K));
legend(legendEntries(~cellfun(@isempty, curveData)), 'Location', 'northwest');
set(gca, 'FontSize', 11);

%% ------------------------- OPTIONAL: LOG-SCALE PLOT ----------------------
figure('Name','MOSFET Output Characteristics (log scale)','Color','w');
hold on; grid on; box on;

for k = 1:nCurves
    if isempty(curveData{k})
        continue;
    end
    Vd = curveData{k}(:,1);
    Id = abs(curveData{k}(:,2));
    semilogy(Vd, Id, '-o', 'Color', colors(k,:), 'LineWidth', 1.6, ...
             'MarkerSize', 4, 'MarkerFaceColor', colors(k,:));
end

xlabel('V_{DS}  (V)');
ylabel('I_D  (A)  [log scale]');
title('NMOS Output Characteristics -- Log Scale');
legend(legendEntries(~cellfun(@isempty, curveData)), 'Location', 'best');
set(gca, 'FontSize', 11);

%% ------------------- OPTIONAL: DERIVED PARAMETER EXTRACTION --------------
% Rough estimate of linear-region on-resistance (Ron) for each Vg curve,
% using the lowest few Vd points (linear/triode region assumption).
% This is a simple finite-difference estimate, not a fitted extraction --
% verify against TCAD/TonyPlot before using for design decisions.

fprintf('=== Approximate Linear-Region Ron (from low-Vd slope) ===\n');
for k = 1:nCurves
    if isempty(curveData{k})
        continue;
    end
    Vd = curveData{k}(:,1);
    Id = abs(curveData{k}(:,2));

    lowVdMask = Vd <= 0.6;   % first couple of points, deep triode region
    if nnz(lowVdMask) >= 2
        p = polyfit(Vd(lowVdMask), Id(lowVdMask), 1);
        Ron = 1 / p(1);      % ohms
        fprintf('  Vg = %g V  ->  Ron ~ %.3g ohm\n', Vgate(k), Ron);
    else
        fprintf('  Vg = %g V  ->  not enough low-Vd points for Ron estimate\n', Vgate(k));
    end
end

%% ------------------------------ SAVE FIGURES -----------------------------
% Uncomment to auto-save plots
% saveas(figure(1), fullfile(dataFolder, 'mosfet_idvd_linear.png'));
% saveas(figure(2), fullfile(dataFolder, 'mosfet_idvd_log.png'));

fprintf('\nDone. If curves look empty, check that idvd_vg*.dat exist in:\n  %s\n', dataFolder);