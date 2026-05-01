function [N_swaps, par_rates] = hedgeDeltaCoarseGrained(cg_bond_deltas, swapMaturities, ...
    allStrikes, numPeriods, L, T_maturities, df_schedule, delta_i, spotVols, bucketEdges)
% HEDGEDELTACOARSEGRAINED Finds swap notionals that zero the coarse-grained delta buckets.
%
% PURPOSE:
% Solves the linear system:
%   cg_bond_deltas + M * N_swaps = 0
% where M(k,j) = coarse-grained bucket k delta of unit-notional swap j.
% We start with the longest swap (highest maturity) as instructed.
%
% Strategy: Sequential hedging starting from the longest swap (back-substitution).
% The longest swap mainly affects the last bucket; shorter ones the earlier buckets.
% This is why we start with the longest: its sensitivity is concentrated in the
% longest bucket, making the system nearly triangular.
%
% INPUTS:
%   cg_bond_deltas  - [K x 1] Coarse-grained delta buckets of the bond
%   swapMaturities  - [K x 1] Swap maturities in years [2, 6, 10] (ascending)
%   ...             - Market data as in irsCoarseGrainedBuckets
%   bucketEdges     - [1 x (K+1)] Coarse bucket edges
%
% OUTPUTS:
%   N_swaps   - [K x 1] Notionals of hedging swaps (positive = receiver IRS)
%   par_rates - [K x 1] Par rates of each swap

    K = length(swapMaturities);
    notional_unit = 1; % Compute per-EUR sensitivity, then scale
    
    % Build sensitivity matrix M: M(k,j) = CG bucket k of swap j (unit notional)
    M = zeros(K, K);
    par_rates = zeros(K, 1);
    for j = 1:K
        [cg_j, par_j] = irsCoarseGrainedBuckets(swapMaturities(j), ...
            allStrikes, numPeriods, L, T_maturities, df_schedule, delta_i, spotVols, ...
            bucketEdges, notional_unit);
        M(:, j) = cg_j;
        par_rates(j) = par_j;
    end
    
    % Solve: M * N_swaps = -cg_bond_deltas
    % We use backslash (full system solve) — equivalent to sequential back-substitution
    % since M is approximately lower-triangular when ordered longest-to-shortest.
    N_swaps = M \ (-cg_bond_deltas);
end
