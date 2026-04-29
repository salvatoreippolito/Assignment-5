function L=forward_libor_rate(numPeriods,df_schedule,delta_i)
% FORWARD_LIBOR_RATE Computes the forward interest rates for a given schedule.
%
% PURPOSE:
% This function calculates the simply-compounded forward Libor rates (L_i) 
% for each period in the swap/bond schedule. It strictly relies on the 
% fundamental no-arbitrage relationship between forward rates and zero-coupon 
% discount factors.
%
% INPUTS:
%   numPeriods  - [Scalar] The total number of periods in the schedule.
%   df_schedule - [(numPeriods+1) x 1 Array] Discount factors evaluated at 
%                 the schedule dates (from T_0 to T_n).
%   delta_i     - [numPeriods x 1 Array] The daycount fractions (typically 
%                 Act/360) for each respective period.
%
% OUTPUTS:
%   L           - [numPeriods x 1 Array] The calculated forward Libor rates 
%                 for each period spanning [T_i, T_{i+1}].
L = zeros(numPeriods, 1);
for i = 1:numPeriods
    % Formula: L_i = [P(0, Ti) / P(0, Ti+1) - 1] / delta_i
    L(i) = (df_schedule(i) / df_schedule(i+1) - 1) / delta_i(i);
end