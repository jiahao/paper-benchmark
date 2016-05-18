using BenchmarkTools
using Distributions
using JLD

# This provides the `plotkde` function, which is pretty convenient for plotting all the
# of the data contained in `trials`. See the code here:
# https://github.com/JuliaCI/BenchmarkTools.jl/blob/master/src/plotting.jl
BenchmarkTools.loadplotting()

const evals_group = JLD.load("results/evals_results.jld", "suite")
const group = JLD.load("results/results.jld", "suite")

######################
# hypothesis testing #
######################

function trim(t, rcut = 0.05, lcut = rcut)
    left = floor(Int, length(t) * lcut)
    right = floor(Int, length(t) * lcut)
    return t[(1 + left):(length(t) - right)]
end

function pvalue(estsamps, nullval, testval)
    flipval = 2testval - nullval # nullval flipped around testval
    leftbound = min(flipval, nullval)
    rightbound = max(flipval, nullval)
    return 1 - mean(leftbound .< estsamps .< rightbound)
end

function hypotest(est, nullval, a::BenchmarkTools.Trial, b::BenchmarkTools.Trial; kwargs...)
    return hypotest(est, nullval, a.times, b.times; kwargs...)
end

function hypotest(est, nullval, a, b; rcut = 0.0, lcut = rcut, kwargs...)
    @assert length(a) == length(b)
    trimmed_a = trim(a, rcut, lcut)
    trimmed_b = trim(b, rcut, lcut)
    estsamps = bootstrap(est, trimmed_a, trimmed_b; kwargs...)
    return pvalue(estsamps, nullval, est(trimmed_a, trimmed_b))
end

#############
# bootstrap #
#############

function bootstrap(est::Function, a, b; resamps = 5, trials = 100)
    estsamps = zeros(trials)
    for i in 1:trials
        estsamps[i] = est(rand(a, resamps), rand(b, resamps))
    end
    return estsamps
end

function bootstrap(est::Function, a::BenchmarkTools.Trial, b::BenchmarkTools.Trial; kwargs...)
    return bootstrap(est, a.times, b.times; kwargs...)
end

##############
# estimators #
##############

location(a, b) = minimum(a) / minimum(b)

#########
# tests #
#########

function alltrials(group, id)
    idstr = string(id)
    if last(idstr) == '!'
        idstr = idstr[1:end-1]
        endstr = "!"
    else
        endstr = ""
    end
    id_fast = Symbol(string(idstr, "_fast", endstr))
    id_slow = Symbol(string(idstr, "_slow", endstr))
    return group[id_fast], group[id], group[id_slow]
end

function randpairs(iters, est, nullval, trials; threshold = 0.0001, kwargs...)
    k = length(trials)
    fails = 0
    for _ in 1:iters
        i, j = rand(1:k), rand(1:k)
        m, n = rand(1:length(trials[i])), rand(1:length(trials[j]))
        p = hypotest(est, nullval, trials[i][m], trials[j][n]; kwargs...)
        reject = p < threshold
        invariant = i == j
        print("[$i][$m] vs. [$j][$n]: $p")
        reject && print("| REJECT ")
        if reject == invariant
            fails += 1
            println("| FAIL")
        else
            println()
        end
    end
    return fails
end
