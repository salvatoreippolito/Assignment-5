function bucketPrice = calculateBucketPrice(sigma_beta, sigma_alpha, T_alpha, T_beta, ...
                                           indices, L, K, T_mat, delta, df)
    bucketPrice = 0;
    for i = indices
        % Linear constraint: sigma_i = sigma_alpha + slope * (T_i - T_alpha)
        t_curr = T_mat(i+1);
        sigma_i = sigma_alpha + (t_curr - T_alpha)/(T_beta - T_alpha) * (sigma_beta - sigma_alpha);
        
        bucketPrice = bucketPrice + priceCaplet(L(i+1), K, sigma_i, ...
                      T_mat(i+1), delta(i+1), df(i+2));
    end
end