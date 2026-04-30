function AugmentedVolTable = getAugmentedVolGrid(FlatVolTable, originalStrikes)
    % GETAUGMENTEDVOLGRID Interpolates the flat volatility grid for specific strikes.
    % Input: 
    %   FlatVolTable - Table from getFlatVolGrid()
    %   originalStrikes - Vector of original market strikes [1.5, ..., 10.0]
    
    %% Define the Bond's Specific Trigger Strikes
    % These are the key levels found in the Party B payment terms 
    targetStrikes = [4.20, 4.70, 5.40];
    
    %% Extraction and Initialization
    rawVols = table2array(FlatVolTable);
    tenors = str2double(FlatVolTable.Properties.RowNames);
    numTenors = size(rawVols, 1);
    numTargets = length(targetStrikes);
    
    interpValues = zeros(numTenors, numTargets);
    
    %% Spline Interpolation Loop
    % We interpolate row-by-row (for each tenor) across the strike dimension.
    for i = 1:numTenors
        % Use 'spline' as suggested to capture the smile curvature 
        interpValues(i, :) = interp1(originalStrikes, rawVols(i, :), targetStrikes, 'spline');
    end
    
    %% Combine and Re-organize
    % Merge original strikes with the new target strikes
    allStrikes = [originalStrikes, targetStrikes];
    allVols = [rawVols, interpValues];
    
    % Sort strikes in ascending order so the table is logically organized
    [sortedStrikes, idx] = sort(allStrikes);
    sortedVols = allVols(:, idx);
    
    %% Create Augmented Table
    AugmentedVolTable = array2table(sortedVols, ...
        'VariableNames', string(sortedStrikes), ...
        'RowNames', string(tenors));
end