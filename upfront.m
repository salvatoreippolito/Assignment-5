function PV_Upfront = upfront(allStrikes, numPeriods, L, T_maturities, df_schedule, delta_i, spotVols, silent_mode)
% UPFRONT Prices a structured bond and computes the required upfront percentage.
%
% PURPOSE:
% This function calculates the Present Value (PV) of both legs of the structured 
% swap/bond. Leg A is a standard floating leg (Euribor 3m + spread) paid 
% by the bank. Leg B is a structured coupon leg paid by the investor, containing 
% digital options. It decomposes the structured payoff into 
% vanilla components, prices them using Black's formula with the calibrated 
% LMM spot volatilities, and finds the upfront percentage (X%) to balance the swap.
%
% INPUTS:
%   allStrikes        - [1 x S] Array of strike rates used to locate the correct 
%                       volatility columns.
%   numPeriods        - [Scalar] Total number of quarterly payment periods (e.g., 40).
%   L                 - [N x 1] Vector of forward Libor rates for each period.
%   T_maturities      - [N x 1] Vector of time-to-maturities (Act/360) for 
%                       the reset dates.
%   df_schedule       - [(N+1) x 1] Vector of discount factors for the payment dates.
%   delta_i           - [N x 1] Vector of daycount fractions (Act/360) for 
%                       each period.
%   spotVols          - [N x S] Matrix of calibrated LMM spot volatilities.
%   silent_mode       - [Boolean] (Optional) Set to true to suppress console output.
%
% OUTPUTS:
%   PV_Upfront        - [Scalar] The absolute upfront amount in EUR (PV Leg A - PV Leg B).
%   (Implicit)        - Calculates and prints the PV of Leg A, the PV of Leg B, 
%                       the absolute upfront amount in EUR, and the upfront 
%                       percentage (X%) to the command window (if silent_mode=false).

    % Si le paramètre silent_mode n'est pas fourni, on le met à false par défaut
    if nargin < 8
        silent_mode = false;
    end

    % Bond Parameters
    Principal = 50e6; % 50 Million EUR

    % Locate the indices for our specific strikes in the allStrikes array
    idx_K1 = find(abs(allStrikes - 4.2) < 1e-4);
    idx_K2 = find(abs(allStrikes - 4.7) < 1e-4);
    idx_K3 = find(abs(allStrikes - 5.4) < 1e-4);

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
        PV_LegA = PV_LegA + DF_pay * (F + 0.02) * delta * Principal;
        
        % --- LEG B (Structured Leg Paid by I.B.) ---
        
        if q == 1
            % First Quarter: Fixed 4% (Annualized)
            PV_LegB = PV_LegB + DF_pay * 0.04 * delta * Principal;
            
        elseif q >= 2 && q <= 12
            % Up to 3 Years: L + 1.00% if L <= 4.20% else 4.50%
            K = 0.042;
            sigma = spotVols(q-1, idx_K1); 
            
            d1 = (log(F/K) + 0.5 * sigma.^2 * T_reset) / (sigma * sqrt(T_reset));
            d2 = d1 - sigma * sqrt(T_reset);
            
            PV_float = DF_pay * (F + 0.01);
            AssetDig = DF_pay * F * normcdf(d1);
            CashDig  = DF_pay * (0.01 - 0.045) * normcdf(d2);
            
            PV_Coupon = PV_float - (AssetDig + CashDig);
            PV_LegB = PV_LegB + PV_Coupon * delta * Principal;
            
        elseif q >= 13 && q <= 24
            % Year 4 to 6: L + 1.20% if L <= 4.70% else 4.90%
            K = 0.047;
            sigma = spotVols(q-1, idx_K2);
            
            d1 = (log(F/K) + 0.5 * sigma.^2 * T_reset) / (sigma * sqrt(T_reset));
            d2 = d1 - sigma * sqrt(T_reset);
            
            PV_float = DF_pay * (F + 0.012);
            AssetDig = DF_pay * F * normcdf(d1);
            CashDig  = DF_pay * (0.012 - 0.049) * normcdf(d2);
            
            PV_Coupon = PV_float - (AssetDig + CashDig);
            PV_LegB = PV_LegB + PV_Coupon * delta * Principal;
            
        elseif q >= 25 && q <= 40
            % After Year 6: L + 1.30% if L <= 5.40% else 5.60%
            
            K_cap = 0.054;
            sigma_cap = spotVols(q-1, idx_K3);
            d1_cap = (log(F/K_cap) + 0.5 * sigma_cap.^2 * T_reset) / (sigma_cap * sqrt(T_reset));
            d2_cap = d1_cap - sigma_cap * sqrt(T_reset);
            
            % Value the components
            PV_float = DF_pay * (F + 0.013);
            AssetDig = DF_pay * F * normcdf(d1_cap);
            CashDig  = DF_pay * (0.013 - 0.056) * normcdf(d2_cap);
            PV_Coupon = PV_float - (AssetDig + CashDig);
            PV_LegB = PV_LegB + PV_Coupon * delta * Principal;
        end
    end

    % --- CALCULATE THE UPFRONT (X%) ---
    Upfront_EUR = PV_LegA - PV_LegB;
    
    % Return value for risk functions (Delta, Vega)
    PV_Upfront = Upfront_EUR;
    
    X_percent = (Upfront_EUR / Principal) * 100;

    % --- CONDITIONAL DISPLAY ---
    % Only print if silent_mode is false
    if ~silent_mode
        fprintf('PV of Leg A (Bank pays): EUR %.2f\n', PV_LegA);
        fprintf('PV of Leg B (IB pays via coupons): EUR %.2f\n', PV_LegB);
        fprintf('Upfront required (EUR): EUR %.2f\n', Upfront_EUR);
        fprintf('The Upfront percentage X%% is: %.4f%%\n', X_percent);
    end
end