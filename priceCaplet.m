function price = priceCaplet(L, K, sigma, T_expiry, delta, df_pay)
    % Standard Black-76 for a caplet
    if T_expiry <= 0
        price = 0; return;
    end
    
    d1 = (log(L/K) + 0.5 * sigma^2 * T_expiry) / (sigma * sqrt(T_expiry));
    d2 = d1 - sigma * sqrt(T_expiry);
    
    % Caplet price formula
    price = df_pay * delta * (L * normcdf(d1) - K * normcdf(d2));
end