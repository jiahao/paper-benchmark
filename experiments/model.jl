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

###########################
# Estimator distributions #
###########################

function mindist(src; trials = 10000, comps = 10000)
    diff = zeros(comps)
    for c in 1:comps
        x = Inf
        y = Inf
        for _ in 1:trials
            x = min(x, rand(src))
            y = min(y, rand(src))
        end
        diff[c] = x - y
    end
    return diff
end
