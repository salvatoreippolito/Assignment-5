function bucketed_vega = computeBucketedVega(allStrikes, pillarYears, AugmentedVolTable, ...
    spotVols, L, T_maturities, df_schedule, delta_i, numPeriods, vegaBucketEdges)
% COMPUTEBUCKETEDVEGA Computes vega bucketed by tenor using parallel shocks per bucket.
%
% PURPOSE:
% For each vega bucket [T_alpha, T_beta], we shock only the flat vols whose
% tenor falls within that bucket by +1bp, recalibrate spot vols, and reprice.
% The sensitivity is the price difference.
%
% INPUTS:
%   allStrikes      - Strike vector (augmented)
%   pillarYears     - [1:10] pillar tenors
%   AugmentedVolTable - Flat vol surface table
%   spotVols        - Base calibrated spot vols
%   L, T_maturities, df_schedule, delta_i, numPeriods - market data
%   vegaBucketEdges - [1 x (K+1)] Bucket boundaries in years, e.g. [0, 6, 10]
%
% OUTPUTS:
%   bucketed_vega   - [K x 1] Vega per bucket (EUR / bp)

    bp_shift = 0.0001;
    K = length(vegaBucketEdges) - 1;
    bucketed_vega = zeros(K, 1);
    
    Upfront_base = upfront(allStrikes, numPeriods, L, T_maturities, df_schedule, delta_i, spotVols, true);
    
    volData_base = table2array(AugmentedVolTable);
    
    for k = 1:K
        T_lo = vegaBucketEdges(k);
        T_hi = vegaBucketEdges(k+1);
        
        % Identify pillar years within this bucket (strictly inside (T_lo, T_hi])
        inBucket = (pillarYears > T_lo) & (pillarYears <= T_hi);
        
        % Shock only those rows of the vol table
        volData_bumped = volData_base;
        volData_bumped(inBucket, :) = volData_bumped(inBucket, :) + bp_shift;
        
        AugVolTable_bumped = array2table(volData_bumped, ...
            'VariableNames', AugmentedVolTable.Properties.VariableNames, ...
            'RowNames',      AugmentedVolTable.Properties.RowNames);
        
        % Recalibrate spot vols
        spotVols_bumped = spot_Vol_table(allStrikes, pillarYears, AugVolTable_bumped, ...
            L, delta_i, df_schedule, T_maturities);
        
        % Reprice
        Upfront_bumped = upfront(allStrikes, numPeriods, L, T_maturities, df_schedule, delta_i, spotVols_bumped, true);
        
        bucketed_vega(k) = Upfront_bumped - Upfront_base;
    end
end
