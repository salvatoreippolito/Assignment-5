function cg_buckets = computeCoarseGrainedBuckets(delta_buckets, T_maturities, bucketEdges)
% COMPUTECOARSEGRAINEDBUCKETS Aggregates fine-grained delta buckets into coarse buckets.
%
% PURPOSE:
% Each coarse bucket [T_alpha, T_beta] is a partial-shift sensitivity:
%   w(t) = linearly ramps from 0 to 1 between T_alpha and T_beta,
%   then stays at 1 for t > T_beta.
% This follows the standard linear-partition approach (Lab1 THM, Q5):
%   coarse bucket k aggregates the fine deltas with triangular weights.
%
% INPUTS:
%   delta_buckets - [N x 1] Fine-grained delta buckets (1 bp shift per forward)
%   T_maturities  - [N+1 x 1] Time-to-maturities (T_0 ... T_N) from eval date
%   bucketEdges   - [1 x (K+1)] Edges defining K coarse buckets, e.g. [0, 2, 6, 10]
%
% OUTPUTS:
%   cg_buckets    - [K x 1] Coarse-grained bucket deltas

    % T_maturities(2:end) are the reset dates of forward rates
    T_fwd = T_maturities(2:end);
    numCG = length(bucketEdges) - 1;
    cg_buckets = zeros(numCG, 1);

    for k = 1:numCG
        T_lo = bucketEdges(k);
        T_hi = bucketEdges(k+1);
        
        % Linear weight for each forward rate in this bucket:
        % w_k(T_i) = clamp( (T_i - T_lo) / (T_hi - T_lo), 0, 1 )
        % This is 0 for T_i <= T_lo, linearly rises to 1 at T_hi, stays 1 after.
        w = min(max((T_fwd - T_lo) / (T_hi - T_lo), 0), 1);
        cg_buckets(k) = dot(w, delta_buckets);
    end
end
