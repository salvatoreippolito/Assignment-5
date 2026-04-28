function [dates, discounts, zeroRates] = bootstrap(datesSet, ratesSet)
% Bootstrap the discount factors from the given bid/ask market data. 
% Deposit rates are used until the first future settlement date (included),
% futures rates are used until the 2y-swap settlement.

%% INPUTS:
% datesSet: struct that contains the settlement date, depos, futures, swaps
%           related dates
% ratesSet: struct that contains the rates in (Mx2 matrix, bid and ask 
%           respectively in the columns) in column vectors of the depos, 
%           futures and swaps

%% OUTPUTS:
% dates:    end dates of underlying contracts (not settlement date)
% discounts:bootstrapped discounts
% zeroRates: bootstrapped zero rates

ref_date = datesSet.settlement;
    
% Initialize the vectors with the initial date and the initial DF (ie, 1)
termDates = ref_date;
discounts_list = 1;

% Calculate directly the rates: the 'readExcelData' gives as output for the
% rates a matrix nx2, where on the rows of the matrix there are written the
% bid/ask rates, ie we use the mid rate of the mkt:

depoRates_all = mean(ratesSet.depos, 2);
futRates_all = mean(ratesSet.futures, 2);
swapRates_all = mean(ratesSet.swaps, 2);
    
%% DEPOS
% As written in the description of this function, we use the depos until
% the first futures is available, then we use the futures:
first_fut_start = datesSet.futures(1, 1);
depo_idx = datesSet.depos <= first_fut_start;

% We use only the dates and rates of the depos before the first futures
depoDates = datesSet.depos(depo_idx);
depoRates = depoRates_all(depo_idx);
    
% Convention Act/360 for Depos as written in the slides on BasicIR
ref_date_vec = ref_date*ones(size(depoDates));
depo_year_fracs = yearfrac(ref_date_vec, depoDates, 2); 
depo_discounts = 1 ./ (1 + depoRates .* depo_year_fracs);

% Update the vectors of dates and discounts

termDates = [termDates; depoDates(:)];
discounts_list = [discounts_list; depo_discounts(:)];
    
%% FUTURES
% We select the 7 first futures, this is due to the fact that, as written
% in the incipit of this function, we will use futures for the bootstrap
% until the 2y swap comes in. This is also given by the fact that after 2y
% the futures become less liquid and it is better to use swaps
%% IMPORTANT: 
% the fact that we use only the first 7 futures holds ONLY in 
% this dataset. If we change the dataset it is possible that we would 
% have to change also this kind of condition.
fut_idx = 1:7;
futStart = datesSet.futures(fut_idx, 1);
futEnd   = datesSet.futures(fut_idx, 2);

futRates = futRates_all(fut_idx);
    
% It is not necessary to calculate the rates of the futures
% (100-price)/100, since it is done by the function 'readExcelData'
    
for i = 1:length(futStart)
    t_start = futStart(i);
    t_end = futEnd(i);
    tau = yearfrac(t_start, t_end, 2); % Act/360
        
    % Interpolate to find the DF at the start
    df_start = get_discount_factor_by_zero_rates_linear_interp(ref_date, t_start, termDates, discounts_list);
        
    % Calculate the DF at the end of the future
    df_end = df_start / (1 + futRates(i) * tau);
    
    % Update the vector of dates and of DF
    termDates = [termDates; t_end];
    discounts_list = [discounts_list; df_end];
end
    
%% SWAPS
swapDates = datesSet.swaps;
swapRates = swapRates_all;
  
% Initialize the BPV value
swap_old = ref_date;
BPV = 0;
    
% The first swap is covered by the futures, we use it to start the BPV
date_1y = swapDates(1);
% For year frac in swaps we have to use the 30/360 convention, which is the
% number 6 (30E/360 o 30/360 European)
yf_1y = yearfrac(swap_old, date_1y, 6);
df_1y = get_discount_factor_by_zero_rates_linear_interp(ref_date, date_1y, termDates, discounts_list);
    
BPV = BPV + df_1y * yf_1y;
swap_old = date_1y;

% for cycle for the next swaps    
for i = 2:length(swapDates)
    swapDate = swapDates(i);
    rate = swapRates(i);
    yf = yearfrac(swap_old, swapDate, 6);
        
    % Iterative DF
    df = (1.0 - rate * BPV) / (1.0 + rate * yf);
        
    termDates = [termDates; swapDate];
    discounts_list = [discounts_list; df];
    
    %Update for the BPV
    BPV = BPV + df * yf;
    swap_old = swapDate;
end
    
%% OUTPUT
% We sort the dates from the smallest to the biggest
[termDates, sort_idx] = sort(termDates);
discounts_list = discounts_list(sort_idx);
% We use the auxiliary function to pass from the DF to the zero rates
zeroRates = from_discount_factors_to_zero_rates(termDates, discounts_list);

% We remove the initial date (settlement date) from the termDates as
% requested in the Assignment. We have to do the same for the discounts
% since the outputs of this function have to have the same dimension
% For the zero rates the settlement date is directly removed by the 
% 'from_discount_factors_to_zero_rates' function
dates = termDates(2:end);
discounts = discounts_list(2:end);

    
% Additional: we verify that all the outputs are column vectors. This is
% only a 
dates = dates(:);
discounts = discounts(:);
zeroRates = zeroRates(:);
end




