using BenchmarkTools
using Distributions
using JLD

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

# This provides the `plotkde` function, which is pretty convenient for plotting all the
# of the data contained in `trials`. See the code here:
# https://github.com/JuliaCI/BenchmarkTools.jl/blob/master/src/plotting.jl
BenchmarkTools.loadplotting()

function trim(t; rcut = 0.05, lcut = 0.0)
    left = floor(Int, length(t) * lcut)
    right = floor(Int, length(t) * rcut)
    return t[(1 + left):(length(t) - right)]
end

scatterest(est, trials; kwargs...) = scatter(1:length(trials), [est(t.times) for t in trials]; kwargs...)

# assumes trials[n] gives you a Trial with i samples at n evals
function evalstransform(trial)
    samples = length(first(trials))
    evals = length(trials)
    @assert all(t -> length(t) == samples, trials) "trials must all have same number of samples"
    results = [Vector{Int}(evals) for _ in 1:samples]
    for i in 1:samples
        for n in 1:evals
            results[i][n] = trials[n].times[i]
        end
    end
    return results
end

plotall(trials; kwargs...) = for t in trials plot(t; kwargs...) end

# sumindex plot #
#---------------#

minlessthan(a, b) = minimum(a) < minimum(b)

function splitmean(trials, μ; kwargs...)
    trimmed = [trim(t; kwargs...) for t in trials]
    left = trimmed[Bool[mean(t) < μ for t in trimmed]]
    right = trimmed[Bool[mean(t) >= μ for t in trimmed]]
    return sort!(left, lt = minlessthan), sort!(right, lt = minlessthan)
end

const left_sumindex, right_sumindex = splitmean(map(t -> t.times, group[:sumindex]), 190, rcut = 0.10, lcut = 0.05)

# oracle function plot #
#----------------------#

logistic(u, l, k, t, t0) = floor(Int, ((u - l) / (1 + exp(-k * (t - t0)))) + l)

function plot_oracle()
    plot(BenchmarkTools.EVALS)
    plot([logistic(1000, 1, -0.009, t, 500) for t in 1:1000], linestyle="dashed", color="black")
    plt[:locator_params](nbins=3)
    plt[:xlim]((1, 1000))
    plt[:xlabel]("time (ns)", fontsize = 35)
    plt[:ylabel]("executions per measurement", fontsize = 35)
    plt[:tick_params](axis="both", labelsize = 35)
end
