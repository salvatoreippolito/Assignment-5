function adjustedDates = getAdjustedSchedule(startDate, numQuarters, convention)
% GETADJUSTEDSCHEDULE Generates a payment schedule adjusted for business days.
%
% PURPOSE:
% This function creates a sequence of dates (e.g., quarterly roll dates) and 
% adjusts them to valid business days according to standard ISDA conventions. 
% It prevents payments from falling on weekends, ensuring accurate daycount 
% fractions and discounting.
%
% INPUTS:
%   startDate   - [Datetime] The initial start date of the swap/bond.
%   numQuarters - [Scalar] The total number of quarterly periods to generate.
%   convention  - [String/Char] The business day convention to apply. 
%                 Options are:
%                   * 'Following': Rolls to the next valid business day.
%                   * 'ModifiedFollowing': Rolls to the next business day 
%                     UNLESS it crosses into a new calendar month, in which 
%                     case it rolls backward to the previous business day.
%
% OUTPUTS:
%   adjustedDates - [(numQuarters+1) x 1 Datetime array] The complete, 
%                   business-day-adjusted schedule starting from the startDate 
%                   to the final maturity date.

    rawDates = startDate + calmonths(0:3:(numQuarters*3))';
    adjustedDates = rawDates;
    
    for i = 1:length(rawDates)
        currDate = rawDates(i);
        
        % 1. Initial Adjustment: If weekend, find the next business day
        if isweekend(currDate)
            nextBusDay = currDate;
            while isweekend(nextBusDay)
                nextBusDay = nextBusDay + caldays(1);
            end
            
            if strcmp(convention, 'ModifiedFollowing')
                % 2. Check if we crossed into a new month
                if month(nextBusDay) ~= month(currDate)
                    % Move backward instead
                    prevBusDay = currDate;
                    while isweekend(prevBusDay)
                        prevBusDay = prevBusDay - caldays(1);
                    end
                    adjustedDates(i) = prevBusDay;
                else
                    adjustedDates(i) = nextBusDay;
                end
            else
                % Just standard 'Following' for the Maturity Date
                adjustedDates(i) = nextBusDay;
            end
        end
    end
end