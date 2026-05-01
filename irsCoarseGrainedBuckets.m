function [irs_delta_buckets, par_rate] = irsCoarseGrainedBuckets(swapMaturityYears, ...
    allStrikes, numPeriods, L, T_maturities, df_schedule, delta_i, spotVols, ...
    bucketEdges, notional)
% IRSCOARSEGRAINEDBUCKETS Computes coarse-grained delta buckets of a par IRS.
%
% PURPOSE:
% Builds a receiver IRS (fixed leg - floating leg) at the par rate for a given
% swap maturity, then computes its sensitivity to 1 bp bumps of each forward rate,
% aggregated into coarse-grained buckets.
%
% INPUTS:
%   swapMaturityYears - Swap maturity in years (e.g. 2, 6, 10)
%   allStrikes        - As in upfront()
%   numPeriods        - 40 (total bond quarters)
%   L                 - Forward Libor rates (40x1)
%   T_maturities      - Time-to-maturities (41x1)
%   df_schedule       - Discount factors (41x1)
%   delta_i           - Daycount fractions (40x1)
%   spotVols          - (unused for linear IRS, kept for interface consistency)
%   bucketEdges       - Coarse bucket edges e.g. [0, 2, 6, 10]
%   notional          - IRS notional (e.g. 1 EUR for sensitivity per EUR)
%
% OUTPUTS:
%   irs_delta_buckets - [K x 1] Coarse-grained delta buckets of this IRS
%   par_rate          - Par swap rate

    bp_shift = 0.0001;
    
    % Number of quarters in the swap
    swapPeriods = round(swapMaturityYears * 4);
    swapPeriods = min(swapPeriods, numPeriods);
    
    % Par rate: S = (P(0,T0) - P(0,T_n)) / BPV
    % Here P(0,T0) = df_schedule(1) (start date discount)
    % P(0,T_n)    = df_schedule(swapPeriods+1)
    BPV = sum(delta_i(1:swapPeriods) .* df_schedule(2:swapPeriods+1));
    par_rate = (df_schedule(1) - df_schedule(swapPeriods+1)) / BPV;
    
    % IRS PV function: receiver IRS PV = Fixed leg - Float leg
    % Fixed leg PV = par_rate * sum_i delta_i * df(T_{i+1}) * N
    % Float leg PV = (df(T_0) - df(T_n)) * N  (standard no-arbitrage)
    % At inception receiver IRS PV = 0 by construction (par rate)
    % For delta we bump forward rates (which changes df) and reprice.
    
    irs_pv_base = irs_pv(L, df_schedule, delta_i, swapPeriods, par_rate, notional);
    
    fine_deltas = zeros(numPeriods, 1);
    for k = 1:swapPeriods
        L_bumped = L;
        L_bumped(k) = L(k) + bp_shift;
        
        % Rebuild discount factors from period k onwards
        df_bumped = df_schedule;
        for j = k:numPeriods
            df_bumped(j+1) = df_bumped(j) / (1 + L_bumped(j) * delta_i(j));
        end
        
        pv_bumped = irs_pv(L_bumped, df_bumped, delta_i, swapPeriods, par_rate, notional);
        fine_deltas(k) = pv_bumped - irs_pv_base;
    end
    
    irs_delta_buckets = computeCoarseGrainedBuckets(fine_deltas, T_maturities, bucketEdges);
end

function pv = irs_pv(L, df, delta, swapPeriods, par_rate, notional)
    % Receiver IRS: receive fixed (par_rate), pay floating
    fixed_leg = par_rate * sum(delta(1:swapPeriods) .* df(2:swapPeriods+1)) * notional;
    % Float leg = df(T0) - df(Tn) (standard floating leg at par)
    float_leg = (df(1) - df(swapPeriods+1)) * notional;
    pv = fixed_leg - float_leg;
end
