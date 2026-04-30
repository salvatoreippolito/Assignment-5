function Total_Vega = computeTotalVega(allStrikes, pillarYears, AugmentedVolTable, spotVols_base, L, T_maturities, df_schedule, delta_i, numPeriods)
%
% PURPOSE:
% Applies a parallel shock of +1 basis point (+0.0001) across the entire flat market volatility surface.
%  Then recalibrates the spot volatility LMMs and recalculates the upfront.
%  Vega is the price difference.

    bp_shift = 0.0001; % Choc
    
    % 1. Base Upfront
    Upfront_base = upfront(allStrikes, numPeriods, L, T_maturities, df_schedule, delta_i, spotVols_base, true);
    
    % 2. Vol choc
    volData_bumped = table2array(AugmentedVolTable) + bp_shift;
    
    AugmentedVolTable_bumped = array2table(volData_bumped, ...
        'VariableNames', AugmentedVolTable.Properties.VariableNames, ...
        'RowNames', AugmentedVolTable.Properties.RowNames);
        
    % 3. Spot Vols LMM recalibration
    spotVols_bumped = spot_Vol_table(allStrikes, pillarYears, AugmentedVolTable_bumped, L, delta_i, df_schedule, T_maturities);
    
    % 4. Repricing of vol
    Upfront_bumped = upfront(allStrikes, numPeriods, L, T_maturities, df_schedule, delta_i, spotVols_bumped, true);
    
    % 5. Computing Vega
    Total_Vega = Upfront_bumped - Upfront_base;
end