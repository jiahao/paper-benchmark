using BenchmarkTools
using JLD

BenchmarkTools.loadplotting()

#####################
# Theoretical Model #
#####################
# Our model for an individual sample is `T = n*t + d(n,t,r) + X = n*t + d(n,t,r) + ∑(i*xᵢ)`, where:
#
# - `T` is total observed sample time
# - `n*t` is the minimum theoretical sample time, where:
#     - `n` is the number of evaluations performed per sample
#     - `t` is the minimum theoretical benchmark time
# - `d(n,t,r)` is the noise due to discretization, where:
#     - `r` is the resolution of the timing method
# - `X = ∑(i*xᵢ)` is noise due to deviations from the ideal configuration, where:
#     - `i` is a time variation from `1` to `n*t`.
#     - `xᵢ` is the number of occurrences of `i` during our sample

# function T(n, t, r, src)
#     X = 0
#     for i in 1:(n*t)
#         X += i*rand(src)
#     end
#     return n*t + d(n,t,r) + X
# end
#
# function d(n, t, r)
#     for i in r:r:typemax(Int)
#         if i >= n*t
#             return i - n*t
#         end
#     end
# end

#####################################
# Estimator distributions and tests #
#####################################

const group = JLD.load("results/results.jld", "suite");

function diffdist(est, src1, src2;
                  samples = fld(length(src1), 100),
                  trials = 10*length(src1))
    @assert length(src1) == length(src2)
    diff = zeros(trials)
    for t in 1:trials
        diff[t] = est(rand(src1, samples)) - est(rand(src2, samples))
    end
    return sort!(diff)
end

diffdist(args...; kwargs...) = diffdist(iqratio, args...; kwargs...)

# Tried using the difference instead of the ratio, but it wasn't sensitive enough in
# the case of "actual" regressions (e.g. it didn't result in null hypothesis rejection
# when it should have). The same goes for picking the actual quantile values; 0.25 to 0.75
# seems to result in more accurate detection than 0.0 to 0.5 (or 0.0 to 0.25).
iqratio(x, p=(0.75, 0.25)) = quantile(x, p[1]) / quantile(x, p[2])

# If z is more on the right of the distribution, integrate from right to left,
# otherwise, integrate from left to right. This might not be the proper thing
# to do, but at least solves the problem that the pvalue should be invariant
# under exchanging src1 and src2.
pvalue(estz, z = 0.0) = min(mean(z .<= estz), mean(z .>= estz))
