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

function T(n, t, r, src)
    X = 0
    for i in 1:(n*t)
        X += i*rand(src)
    end
    return n*t + d(n,t,r) + X
end

function d(n, t, r)
    for i in r:r:typemax(Int)
        if i >= n*t
            return i - n*t
        end
    end
end

#####################################
# Estimator distributions and tests #
#####################################

function diffmintest(src1, src2; trials = 1000)
    @assert length(src1) == length(src2)
    samples = length(src1)
    diff = zeros(trials)
    for t in 1:trials
        x1 = Inf
        x2 = Inf
        for _ in 1:samples
            x1 = min(x1, rand(src1))
            x2 = min(x2, rand(src2))
        end
        diff[t] = x1 - x2
    end
    return sort!(diff)
end

function diffmedtest(src1, src2; trials = 1000)
    @assert length(src1) == length(src2)
    samples = length(src1)
    diff = zeros(trials)
    for t in 1:trials
        diff[t] = median(rand(src1, samples)) - median(rand(src2, samples))
    end
    return sort!(diff)
end

pairdiff(x1, x2) = vec([i - j for i in x1, j in x2])

function distmin(src; trials = 1000)
    samples = length(src)
    result = zeros(trials)
    for t in 1:trials
        x = Inf
        for _ in 1:samples
            x = min(x, rand(src))
        end
        result[t] = x
    end
    return sort!(result)
end

function distmed(src; trials = 1000)
    samples = length(src)
    result = zeros(trials)
    for t in 1:trials
        result[t] = median(rand(src, samples))
    end
    return sort!(result)
end
