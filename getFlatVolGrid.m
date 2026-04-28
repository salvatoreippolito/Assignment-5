function [FlatVolTable, strikes, tenors] = getFlatVolGrid()
    % GETFLATVOLGRID Returns the market flat volatility surface as a table.
    % The grid is truncated at 10Y as required for the 10Y structured bond.
    % Data source: EUR Caps/Floors Implied Volatilities
    
    %% Define Market Axes
    % Strikes provided in the top row of the grid 
    strikes = [1.50, 1.75, 2.00, 2.25, 2.50, 3.00, 3.50, 4.00, 5.00, 6.00, 7.00, 8.00, 10.00];
    
    % Tenors provided in the first column 
    % We truncate at 10Y because the bond maturity is 10 years 
    tenors = (1:10)'; 
    
    %% Input Raw Volatility Data (Values in %)
    % Rows 1-10 correspond to tenors 1Y through 10Y 
    volData = [
        14.0, 13.0, 12.9, 12.1, 13.3, 13.8, 14.4, 15.0, 17.2, 19.1, 20.2, 21.6, 23.9; % 1Y 
        22.4, 19.7, 17.5, 18.0, 19.2, 20.4, 21.0, 21.4, 22.3, 23.6, 24.9, 26.1, 28.1; % 2Y 
        23.8, 21.7, 20.0, 19.8, 20.3, 20.5, 20.8, 21.4, 22.9, 24.3, 25.6, 26.7, 28.2; % 3Y 
        24.2, 22.4, 20.9, 20.4, 20.4, 20.2, 20.2, 20.5, 21.7, 22.9, 24.0, 25.0, 26.6; % 4Y 
        24.3, 22.6, 21.2, 20.6, 20.4, 19.8, 19.5, 19.6, 20.5, 21.5, 22.6, 23.5, 25.0; % 5Y 
        24.3, 22.7, 21.4, 20.7, 20.2, 19.4, 18.9, 18.8, 19.3, 20.2, 21.2, 22.0, 23.5; % 6Y 
        24.1, 22.6, 21.4, 20.7, 20.1, 19.1, 18.4, 18.1, 18.4, 19.1, 20.0, 20.8, 22.2; % 7Y 
        23.9, 22.5, 21.4, 20.6, 20.0, 18.8, 18.0, 17.6, 17.6, 18.2, 19.0, 19.8, 21.1; % 8Y 
        23.7, 22.4, 21.3, 20.5, 19.8, 18.5, 17.6, 17.1, 17.0, 17.6, 18.3, 19.0, 20.3; % 9Y 
        23.5, 22.2, 21.2, 20.4, 19.6, 18.3, 17.3, 16.8, 16.5, 16.9, 17.6, 18.3, 19.5  % 10Y 
    ];
    
    %% Organize into a Table
    % Converting to a table makes strike/tenor lookups much safer.
    % Divide by 100 to convert percentage to decimal.
    FlatVolTable = array2table(volData ./ 100, ...
        'VariableNames', string(strikes), ...
        'RowNames', string(tenors));
end