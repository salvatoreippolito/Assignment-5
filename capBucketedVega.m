function cap_bucketed_vega = capBucketedVega(capMaturityYears, allStrikes, pillarYears, ...
    AugmentedVolTable, L, T_maturities, df_schedule, delta_i, numPeriods, ...
    vegaBucketEdges, notional)

    bp_shift    = 0.0001;
    K           = length(vegaBucketEdges) - 1;
    cap_bucketed_vega = zeros(K, 1);

    capPeriods  = 4 * capMaturityYears - 1;   % e.g. 39 for 10y, 23 for 6y
    swapPeriods = 4 * capMaturityYears;        % for ATM strike computation

    % ATM strike = par swap rate
    BPV        = sum(delta_i(1:swapPeriods) .* df_schedule(2:swapPeriods+1));
    atm_strike = (df_schedule(1) - df_schedule(swapPeriods+1)) / BPV;
    atm_pct    = atm_strike * 100;

    volData_base  = table2array(AugmentedVolTable);
    base_spotVols = spot_Vol_table(allStrikes, pillarYears, AugmentedVolTable, ...
                        L, delta_i, df_schedule, T_maturities);

    % Base cap price — inline loop using priceCaplet
    cap_base = 0;
    for i = 1:capPeriods
        sigma_i  = interp1(allStrikes, base_spotVols(i,:), atm_pct, 'spline', 'extrap');
        cap_base = cap_base + priceCaplet(L(i+1), atm_strike, sigma_i, ...
                       T_maturities(i+1), delta_i(i+1), df_schedule(i+2)) * notional;
    end

    for k = 1:K
        inBucket = (pillarYears > vegaBucketEdges(k)) & (pillarYears <= vegaBucketEdges(k+1));

        volData_bumped = volData_base;
        volData_bumped(inBucket, :) = volData_bumped(inBucket, :) + bp_shift;

        AugVolTable_bumped = array2table(volData_bumped, ...
            'VariableNames', AugmentedVolTable.Properties.VariableNames, ...
            'RowNames',      AugmentedVolTable.Properties.RowNames);

        spotVols_bumped = spot_Vol_table(allStrikes, pillarYears, AugVolTable_bumped, ...
                              L, delta_i, df_schedule, T_maturities);

        cap_bumped = 0;
        for i = 1:capPeriods
            sigma_i    = interp1(allStrikes, spotVols_bumped(i,:), atm_pct, 'spline', 'extrap');
            cap_bumped = cap_bumped + priceCaplet(L(i+1), atm_strike, sigma_i, ...
                             T_maturities(i+1), delta_i(i+1), df_schedule(i+2)) * notional;
        end

        cap_bucketed_vega(k) = cap_bumped - cap_base;
    end
end