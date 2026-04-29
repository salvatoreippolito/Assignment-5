function L=forward_libor_rate(numPeriods,df_schedule,delta_i)
L = zeros(numPeriods, 1);
for i = 1:numPeriods
    % Formula: L_i = [P(0, Ti) / P(0, Ti+1) - 1] / delta_i
    L(i) = (df_schedule(i) / df_schedule(i+1) - 1) / delta_i(i);
end