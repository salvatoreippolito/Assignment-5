clc;
clear;
% Get original grid
[FlatVolTable, originalStrikes, ~] = getFlatVolGrid();
% Augment it with the bond's triggers
AugmentedVolTable = getAugmentedVolGrid(FlatVolTable, originalStrikes);
% Discount curve
[datesSet, ratesSet] = readExcelDataWindows('MktData_CurveBootstrap.xlsx', 'dd/mm/yyyy');
% Bootstrap
[dates, discounts, zeroRates]=bootstrap(datesSet, ratesSet); 
date_leggibili_dt = datetime(dates, 'ConvertFrom', 'datenum', 'Format', 'dd/MM/yyyy');

refDate = datetime(2008, 2, 15);   % Evaluation/Issue Date 
startDate = datetime(2008, 2, 18); % Swap/Bond Start Date 

% Generate the 41 quarterly dates (T0 to T40 for 10 years)
% 120 months = 10 years. This creates a column vector of dates.
scheduleDates = getAdjustedSchedule(startDate, 40, 'ModifiedFollowing');

% Calculate Year Fractions from Evaluation Date
% Using Act/360 (convention 2) for LMM time-to-maturities 
T_maturities = yearfrac(refDate, scheduleDates, 2); 

refDate_num = datenum(refDate);
full_dates = [refDate_num; dates];
full_discounts = [1.0; discounts];

% Interpolate Discount Factors for the schedule
% We use the loop to find P(0, Ti) for every quarterly date
df_schedule = df_sched(refDate, scheduleDates, full_dates, full_discounts);

% Calculate Delta (Daycount Fractions) for Forwards
% Using Act/360 for the quarterly periods between Ti and Ti+1 
delta_periods = yearfrac(scheduleDates(1:end-1), scheduleDates(2:end), 2);

% Number of quarterly periods in 10 years
numPeriods = length(scheduleDates) - 1; 

% Calculate Daycount Fractions (delta_i) for each 3-month period
% Convention 2 = Act/360 as specified in the termsheet
delta_i = yearfrac(scheduleDates(1:numPeriods), scheduleDates(2:numPeriods+1), 2);

% Calculate Forward Libor Rates (L_i)
L=forward_libor_rate(numPeriods,df_schedule,delta_i);

allStrikes = str2double(AugmentedVolTable.Properties.VariableNames);
pillarYears = 1:10;
numCaplets = 40; % 10 years * 4 quarters

%% Point a
spotVols=spot_Vol_table(allStrikes,pillarYears,AugmentedVolTable,L,delta_i,df_schedule,T_maturities);
disp(spotVols)
%% Point b
upfront(allStrikes,numPeriods,L,T_maturities,df_schedule,delta_i,spotVols)

%% Point c
disp('--- Computing Delta-Bucket Sensitivities ---');

delta_buckets = computeDeltaBuckets(allStrikes, numPeriods, L, T_maturities, df_schedule, delta_i, spotVols);

for i = 1:numPeriods
    fprintf('Bucket %2d (T = %.2f yrs) : Delta = %10.2f EUR / bp\n', i, T_maturities(i+1), delta_buckets(i));
end

figure;
bar(T_maturities(2:end), delta_buckets, 'FaceColor', [0.2 0.6 0.8]);
grid on;
title('Delta-Bucket Sensitivities (Upfront PV change per 1 bp shift in Forward Rate)');
xlabel('Forward Rate Maturity (Years)');
ylabel('Sensitivity (EUR / bp)');
xlim([0, T_maturities(end) + 0.5]);

%% Point d : Compute total Vega
disp('--- Computing Total Vega ---');

% Computation of Vega
total_vega = computeTotalVega(allStrikes, pillarYears, AugmentedVolTable, spotVols, L, T_maturities, df_schedule, delta_i, numPeriods);

fprintf('Total Vega (Sensitivity to +1 bp parallel shift in Flat Vols) : %10.2f EUR / bp\n\n', total_vega);

%% Point e : Delta hedge with 3 swaps (coarse-grained buckets)
disp('--- Point e: Delta Hedge (Coarse-Grained Buckets) ---');

bucketEdges  = [0, 2, 6, 10];
swapMaturities = [2, 6, 10];  % years — longest first in the solve

% Coarse-grained deltas of the bond
cg_bond_deltas = computeCoarseGrainedBuckets(delta_buckets, T_maturities, bucketEdges);
fprintf('Coarse-grained bond deltas:\n');
for k = 1:length(swapMaturities)
    fprintf('  Bucket %dy-%dy : %10.2f EUR/bp\n', bucketEdges(k), bucketEdges(k+1), cg_bond_deltas(k));
end

% Solve for swap notionals (system is ~lower-triangular: start longest)
[N_swaps, par_rates] = hedgeDeltaCoarseGrained(cg_bond_deltas, swapMaturities, ...
    allStrikes, numPeriods, L, T_maturities, df_schedule, delta_i, spotVols, bucketEdges);

fprintf('\nDelta hedge — Receiver IRS notionals:\n');
for j = 1:length(swapMaturities)
    fprintf('  %2dy Receiver IRS : N = %12.0f EUR  (par rate = %.4f%%)\n', ...
        swapMaturities(j), N_swaps(j), par_rates(j)*100);
end

%% Point f : Vega hedge with 6y and 10y ATM Caps
disp('--- Point f: Vega Hedge (Bucketed Vega) ---');

vegaBucketEdges = [0, 6, 10];
capMaturities   = [6, 10];  % years — longest first in the solve

% Bucketed vega of the bond
bv_bond = computeBucketedVega(allStrikes, pillarYears, AugmentedVolTable, spotVols, ...
    L, T_maturities, df_schedule, delta_i, numPeriods, vegaBucketEdges);

fprintf('Bucketed bond vega:\n');
for k = 1:length(capMaturities)
    fprintf('  Bucket %dy-%dy : %10.2f EUR/bp\n', vegaBucketEdges(k), vegaBucketEdges(k+1), bv_bond(k));
end

% Solve for cap notionals (start longest)
N_caps = hedgeVegaBucketed(bv_bond, capMaturities, allStrikes, pillarYears, ...
    AugmentedVolTable, L, T_maturities, df_schedule, delta_i, numPeriods, vegaBucketEdges);

fprintf('\nVega hedge — Long ATM Cap notionals:\n');
for j = 1:length(capMaturities)
    capPeriods_j = round(capMaturities(j) * 4);
    BPV_j = sum(delta_i(1:capPeriods_j) .* df_schedule(2:capPeriods_j+1));
    atm_j = (df_schedule(1) - df_schedule(capPeriods_j+1)) / BPV_j;
    fprintf('  %2dy ATM Cap (K = %.4f%%) : N = %12.0f EUR\n', ...
        capMaturities(j), atm_j*100, N_caps(j));
end
%% Case Study 2 - Exotic Cap

T_maturities_365 = yearfrac(refDate, scheduleDates, 3);

bmmSpotVols = spotVols;

[priceExotic, stdErrorExotic] = exotic_cap_BMM(L, df_schedule, delta_i, T_maturities_365, bmmSpotVols, allStrikes);

disp('--- CASE STUDY 2: EXOTIC CAP ---');
fprintf('Prezzo per unità di nozionale: %.8f\n', priceExotic);
fprintf('Errore standard Monte Carlo: %.8f\n', stdErrorExotic);
fprintf('Prezzo su nozionale 50M EUR: %.2f EUR\n', 50e6 * priceExotic);