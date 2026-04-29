function df_schedule=df_sched(refDate, scheduleDates, full_dates, full_discounts)
% DF_SCHED Interpolates discount factors for a specific set of schedule dates.
%
% PURPOSE:
% This function maps the bootstrapped market discount curve to the specific 
% payment and reset dates of the structured bond. It iterates through the 
% provided schedule dates and calculates the corresponding discount factor 
% using linear interpolation on the zero rates.
%
% INPUTS:
%   refDate        - [Datetime or Datenum] The evaluation date (t=0) of the bond.
%   scheduleDates  - [M x 1 Datetime array] The specific dates (e.g., quarterly 
%                    payment dates) for which discount factors are needed.
%   full_dates     - [N x 1 Array] The pillar dates from the bootstrapped 
%                    market curve.
%   full_discounts - [N x 1 Array] The bootstrapped discount factors 
%                    corresponding to the full_dates.
%
% OUTPUTS:
%   df_schedule    - [M x 1 Array] The interpolated discount factors exactly 
%                    matching the requested scheduleDates.
df_schedule = zeros(length(scheduleDates), 1);
for i = 1:length(scheduleDates)
    df_schedule(i) = get_discount_factor_by_zero_rates_linear_interp(refDate, scheduleDates(i), full_dates, full_discounts);
end