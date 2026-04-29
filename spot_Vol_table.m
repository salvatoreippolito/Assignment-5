function spotVols=spot_Vol_table(allStrikes,pillarYears,AugmentedVolTable,L,delta_i,df_schedule,T_maturities)
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
