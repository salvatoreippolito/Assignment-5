function delta_buckets = computeDeltaBuckets(allStrikes, numPeriods, L_base, T_maturities, df_schedule_base, delta_i, spotVols)
    bp_shift = 0.0001;
    delta_buckets = zeros(numPeriods, 1);
    
    % Base Price
    Upfront_base = upfront(allStrikes, numPeriods, L_base, T_maturities, df_schedule_base, delta_i, spotVols, true);
    
    for k = 1:numPeriods
        L_bumped = L_base;
        L_bumped(k) = L_base(k) + bp_shift;
        
        df_bumped = df_schedule_base;
        for j = k:numPeriods
            df_bumped(j+1) = df_bumped(j) / (1 + L_bumped(j) * delta_i(j));
        end
        
        % Bumped Price
        Upfront_bumped = upfront(allStrikes, numPeriods, L_bumped, T_maturities, df_schedule_base, delta_i, spotVols, true);
        
        delta_buckets(k) = Upfront_bumped - Upfront_base;
    end
end