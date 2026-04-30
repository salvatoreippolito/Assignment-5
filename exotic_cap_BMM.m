function [price, stdError] = exotic_cap_BMM(L, dfSchedule, deltaI, tMaturities, spotVols, allStrikes)

    %% 1. Parameters and Input Pre-processing
    correlationDecay = 0.1;
    strikeSpread = 0.0005;
    numSimulations = 500000;
    numSteps = 16;

    fwdRates = L(1:numSteps);
    discountFactors = dfSchedule(2:numSteps+1);
    yearFractions = deltaI(1:numSteps);
    fixingTimes = tMaturities(1:numSteps);

    fwdRates = fwdRates(:);
    discountFactors = discountFactors(:);
    yearFractions = yearFractions(:);
    fixingTimes = fixingTimes(:);

    %% 2. Spot Volatility Interpolation
    if max(allStrikes) > 1
        strikeGrid = allStrikes / 100;
    else
        strikeGrid = allStrikes;
    end

    interpolatedVols = zeros(numSteps, 1);

    interpolatedVols(1) = 0;

    for i = 2:numSteps
        interpolatedVols(i) = interp1(strikeGrid, spotVols(i-1,:), fwdRates(i), 'spline', 'extrap');
    end

    if max(interpolatedVols) > 2
        interpolatedVols = interpolatedVols / 100;
    end

    %% 3. Terminal Correlation Matrix Construction
    corrMatrix = eye(numSteps);

    for i = 1:numSteps
        for j = 1:numSteps
            if i ~= j
                instantaneousCorr = exp(-correlationDecay * abs(fixingTimes(i) - fixingTimes(j)));
                corrMatrix(i,j) = instantaneousCorr * sqrt(min(fixingTimes(i), fixingTimes(j)) / max(fixingTimes(i), fixingTimes(j)));
            end
        end
    end

    %% 4. Vectorized Monte Carlo Simulation
    lowerCholesky = chol(corrMatrix, 'lower');

    rng(1);

    randomShocks = lowerCholesky * randn(numSteps, numSimulations);

    simulatedL = fwdRates .* exp(-0.5 * (interpolatedVols.^2 .* fixingTimes) + (interpolatedVols .* sqrt(fixingTimes)) .* randomShocks);

    simulatedL(1, :) = fwdRates(1);

    %% 5. Payoff Calculation and Discounting
    periodicPayoffs = zeros(numSteps, numSimulations);

    for i = 2:numSteps
        periodicPayoffs(i, :) = yearFractions(i) * max(simulatedL(i, :) - simulatedL(i-1, :) - strikeSpread, 0);
    end

    totalPathPayoff = sum(discountFactors .* periodicPayoffs, 1);

    %% 6. Final Results
    price = mean(totalPathPayoff);
    stdError = std(totalPathPayoff) / sqrt(numSimulations);

end