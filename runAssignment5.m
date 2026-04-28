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
scheduleDates = startDate + calmonths(0:3:120)'; 

% Calculate Year Fractions from Evaluation Date
% Using Act/360 (convention 2) for LMM time-to-maturities 
T_maturities = yearfrac(refDate, scheduleDates, 2); 

refDate_num = datenum(refDate);
full_dates = [refDate_num; dates];
full_discounts = [1.0; discounts];

% Interpolate Discount Factors for the schedule
% We use the loop to find P(0, Ti) for every quarterly date
df_schedule = zeros(length(scheduleDates), 1);
for i = 1:length(scheduleDates)
    df_schedule(i) = get_discount_factor_by_zero_rates_linear_interp(refDate, scheduleDates(i), full_dates, full_discounts);
end

% Calculate Delta (Daycount Fractions) for Forwards
% Using Act/360 for the quarterly periods between Ti and Ti+1 
delta_periods = yearfrac(scheduleDates(1:end-1), scheduleDates(2:end), 2);

% Number of quarterly periods in 10 years
numPeriods = length(scheduleDates) - 1; 

% Calculate Daycount Fractions (delta_i) for each 3-month period
% Convention 2 = Act/360 as specified in the termsheet
delta_i = yearfrac(scheduleDates(1:numPeriods), scheduleDates(2:numPeriods+1), 2);

% Calculate Forward Libor Rates (L_i)
L = zeros(numPeriods, 1);
for i = 1:numPeriods
    % Formula: L_i = [P(0, Ti) / P(0, Ti+1) - 1] / delta_i
    L(i) = (df_schedule(i) / df_schedule(i+1) - 1) / delta_i(i);
end

% --- Inputs required from previous steps ---
% L: 40x1 vector of 3m forward rates
% df_schedule: 41x1 vector of discount factors
% scheduleDates: 41x1 vector of dates
% T_maturities: 41x1 vector (time from refDate to scheduleDates)
% AugmentedVolTable: table with interpolated flat vols
% delta_i: 40x1 daycount fractions for accrual periods

allStrikes = str2double(AugmentedVolTable.Properties.VariableNames);
pillarYears = 1:10;
numCaplets = 40; % 10 years * 4 quarters

% Re-initialize
spotVols = zeros(40, length(allStrikes));

for s = 1:length(allStrikes)
    try
        K = allStrikes(s) / 100; % Ensure Strike is 0.015, not 1.5
        
        for p = 1:length(pillarYears)
            flatVol_beta = AugmentedVolTable{p, s};
            T_beta_year = pillarYears(p);
            T_alpha_year = T_beta_year - 1;

            % Market Price Cap(T_beta)
            indices_beta = 1 : (4*T_beta_year - 1);
            mkt_beta = 0;
            for i = indices_beta
                mkt_beta = mkt_beta + priceCaplet(L(i+1), K, flatVol_beta, T_maturities(i+1), delta_i(i+1), df_schedule(i+2));
            end

            % Delta_C
            if p == 1
                delta_C = mkt_beta;
                sigma_alpha = flatVol_beta; 
                T_alpha = 0;
                indices_bucket = 1:3;
            else
                flatVol_alpha = AugmentedVolTable{p-1, s};
                indices_alpha = 1 : (4*T_alpha_year - 1);
                mkt_alpha = 0;
                for i = indices_alpha
                    mkt_alpha = mkt_alpha + priceCaplet(L(i+1), K, flatVol_alpha, T_maturities(i+1), delta_i(i+1), df_schedule(i+2));
                end
                delta_C = mkt_beta - mkt_alpha;
                sigma_alpha = spotVols(4*T_alpha_year - 1, s);
                T_alpha = T_alpha_year;
                indices_bucket = (4*T_alpha_year) : (4*T_beta_year - 1);
            end

            % Solve
            obj = @(sig_b) calculateBucketPrice(sig_b, sigma_alpha, T_alpha, T_beta_year, indices_bucket, L, K, T_maturities, delta_i, df_schedule) - delta_C;
            sigma_beta_sol = fzero(obj, flatVol_beta);

            % Store
            for i = indices_bucket
                t_curr = T_maturities(i+1);
                spotVols(i, s) = sigma_alpha + (t_curr - T_alpha)/(T_beta_year - T_alpha) * (sigma_beta_sol - sigma_alpha);
            end
        end
    catch ME
        fprintf('Failed at Strike %.2f: %s\n', allStrikes(s), ME.message);
    end
end
%% Point b

% Bond Parameters
Principal = 50e6; % 50 Million EUR

% Locate the indices for our specific strikes in the allStrikes array
% We divide by 100 just in case allStrikes is in percentage format (e.g., 4.20)
idx_K1 = find(abs(allStrikes - 4.2) < 1e-4);
idx_K2 = find(abs(allStrikes - 4.7) < 1e-4);
idx_K3 = find(abs(allStrikes - 3.8) < 1e-4);
idx_K4 = find(abs(allStrikes - 5.4) < 1e-4);

% Initialize Present Values
PV_LegA = 0; % Euribor 3m + 2.00%
PV_LegB = 0; % Structured Coupons

% Loop over the 40 quarters
for q = 1:numPeriods
    
    % Period Variables
    F = L(q);                    % Forward rate for the period
    T_reset = T_maturities(q);   % Reset time (T_i)
    DF_pay = df_schedule(q+1);   % Discount factor at payment time (T_{i+1})
    delta = delta_i(q);          % Daycount fraction for the period
    
    % --- LEG A (Floating Leg Paid by Bank) ---
    % Euribor 3m + 2.00%
    PV_LegA = PV_LegA + DF_pay * (F + 0.02) * delta * Principal;
    
    % --- LEG B (Structured Leg Paid by I.B.) ---
    
    if q == 1
        % First Quarter: Fixed 4% (Annualized)
        PV_LegB = PV_LegB + DF_pay * 0.04 * delta * Principal;
        
    elseif q >= 2 && q <= 12
        % Up to 3 Years: L + 1.00% if L <= 4.20% else 4.50%
        K = 0.042;
        sigma = spotVols(q-1, idx_K1); 
        
        d1 = (log(F/K) + 0.5 * sigma^2 * T_reset) / (sigma * sqrt(T_reset));
        d2 = d1 - sigma * sqrt(T_reset);
        
        % Value the components
        PV_float = DF_pay * (F + 0.01);
        AssetDig = DF_pay * F * normcdf(d1);
        CashDig  = DF_pay * (0.01 - 0.045) * normcdf(d2);
        
        PV_Coupon = PV_float - (AssetDig + CashDig);
        PV_LegB = PV_LegB + PV_Coupon * delta * Principal;
        
    elseif q >= 13 && q <= 24
        % Year 4 to 6: L + 1.20% if L <= 4.70% else 4.90%
        K = 0.047;
        sigma = spotVols(q-1, idx_K2);
        
        d1 = (log(F/K) + 0.5 * sigma^2 * T_reset) / (sigma * sqrt(T_reset));
        d2 = d1 - sigma * sqrt(T_reset);
        
        % Value the components
        PV_float = DF_pay * (F + 0.012);
        AssetDig = DF_pay * F * normcdf(d1);
        CashDig  = DF_pay * (0.012 - 0.049) * normcdf(d2);
        
        PV_Coupon = PV_float - (AssetDig + CashDig);
        PV_LegB = PV_LegB + PV_Coupon * delta * Principal;
        
    elseif q >= 25 && q <= 40
        % After Year 6: L + 1.30% capped at 5.10% if L <= 5.40% else 5.60%
        % Decomposition: Floater - Caplet(3.80%) + CashDigital(5.40%, payout 0.50%)
        
        % The Caplet (Strike 3.80%)
        K_cap = 0.038;
        sigma_cap = spotVols(q-1, idx_K3);
        d1_cap = (log(F/K_cap) + 0.5 * sigma_cap^2 * T_reset) / (sigma_cap * sqrt(T_reset));
        d2_cap = d1_cap - sigma_cap * sqrt(T_reset);
        Caplet_val = DF_pay * (F * normcdf(d1_cap) - K_cap * normcdf(d2_cap));
        
        % The Cash Digital (Strike 5.40%)
        K_dig = 0.054;
        sigma_dig = spotVols(q-1, idx_K4);
        d1_dig = (log(F/K_dig) + 0.5 * sigma_dig^2 * T_reset) / (sigma_dig * sqrt(T_reset));
        d2_dig = d1_dig - sigma_dig * sqrt(T_reset);
        CashDig_val = DF_pay * 0.005 * normcdf(d2_dig); % 0.50% jump
        
        % The Base Floater
        PV_float = DF_pay * (F + 0.013);
        
        PV_Coupon = PV_float - Caplet_val + CashDig_val;
        PV_LegB = PV_LegB + PV_Coupon * delta * Principal;
    end
end

% --- CALCULATE THE UPFRONT (X%) ---
% Fair Value requires: PV_LegA = PV_LegB + (X_percent * Principal)
Upfront_EUR = PV_LegA - PV_LegB;
X_percent = (Upfront_EUR / Principal) * 100;

fprintf('PV of Leg A (Bank pays): EUR %.2f\n', PV_LegA);
fprintf('PV of Leg B (IB pays via coupons): EUR %.2f\n', PV_LegB);
fprintf('Upfront required (EUR): EUR %.2f\n', Upfront_EUR);
fprintf('The Upfront percentage X%% is: %.4f%%\n', X_percent);