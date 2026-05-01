function N_caps = hedgeVegaBucketed(bv_bond, capMaturities, allStrikes, pillarYears, ...
    AugmentedVolTable, L, T_maturities, df_schedule, delta_i, numPeriods, vegaBucketEdges)
% HEDGEVEGABUCKETED Finds cap notionals to zero both vega buckets.
%
% PURPOSE:
% Solves: M_vega * N_caps = -bv_bond
% where M_vega(k,j) = bucketed vega of cap j (unit notional) in bucket k.
% We start with the longest cap (it mainly affects the last bucket),
% which makes the 2x2 system nearly triangular.
%
% INPUTS:
%   bv_bond       - [K x 1] Bucketed vega of the bond
%   capMaturities - [K x 1] Cap maturities e.g. [6, 10]
%   ...           - Market data
%
% OUTPUTS:
%   N_caps        - [K x 1] Notionals for each cap (positive = long cap)

    K = length(capMaturities);
    notional_unit = 1;
    
    M_vega = zeros(K, K);
    for j = 1:K
        bv_j = capBucketedVega(capMaturities(j), allStrikes, pillarYears, ...
            AugmentedVolTable, L, T_maturities, df_schedule, delta_i, numPeriods, ...
            vegaBucketEdges, notional_unit);
        M_vega(:, j) = bv_j;
    end
    
    % Solve the 2x2 system
    N_caps = M_vega \ (-bv_bond);
end
