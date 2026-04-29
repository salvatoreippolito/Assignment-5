function df_schedule=df_sched(refDate, scheduleDates, full_dates, full_discounts)
    df_schedule = zeros(length(scheduleDates), 1);
for i = 1:length(scheduleDates)
    df_schedule(i) = get_discount_factor_by_zero_rates_linear_interp(refDate, scheduleDates(i), full_dates, full_discounts);
end