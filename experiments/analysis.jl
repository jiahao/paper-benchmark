using BenchmarkTools
using Distributions
using JLD

########
# data #
########

const branchsum_evals = JLD.load("results/branchsum_eval_results.jld", "results")
const group = JLD.load("results/results.jld", "suite")
const base1 = JLD.load("results/base/first.jld", "results")
const base2 = JLD.load("results/base/second.jld", "results")

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

##########
# pvalue #
##########

function pvalue(estsamps, nullval, testval)
    flipval = 2testval - nullval # nullval flipped around testval
    leftbound = min(flipval, nullval)
    rightbound = max(flipval, nullval)
    return 1 - mean(leftbound .< estsamps .< rightbound)
end

################################
# hardcoded hypothesis testing #
################################

function sametest(a::BenchmarkTools.Trial, b::BenchmarkTools.Trial; kwargs...)
    return sametest(a.times, b.times; kwargs...)
end

function sametest{T}(a::T, b::T; kwargs...)
    estsamps = bootstrap(a, b; kwargs...)
    return pvalue(estsamps, 1.0, minimum(a) / minimum(b))
end

function bootstrap(a::BenchmarkTools.Trial, b::BenchmarkTools.Trial; kwargs...)
    return bootstrap(a.times, b.times; kwargs...)
end

function bootstrap(a, b; resamps = 5, trials = 100)
    estsamps = zeros(trials)
    for i in 1:trials
        x = Inf
        y = Inf
        for _ in 1:resamps
            x = min(rand(a), x)
            y = min(rand(b), y)
        end
        estsamps[i] = x / y
    end
    return estsamps
end

# For a given benchmark trial, estimate the minimum percent shift in the trial's location
# necessary to achieve a rejection with a given threshold and bootstrap parameters.
rejectchange(trial::BenchmarkTools.Trial; kwargs...) = rejectchange(trial.times; kwargs...)

function rejectchange(trial; threshold = 0.01, kwargs...)
    percent_unit = 0.001
    shift_unit = ceil(Int, minimum(trial) * percent_unit)
    total_percent = percent_unit
    trial_shifted = copy(trial)
    while total_percent < 1.0
        for i in eachindex(trial_shifted)
            trial_shifted[i] += shift_unit
        end
        if sametest(trial, trial_shifted; kwargs...) < threshold
            return total_percent
        else
            total_percent += percent_unit
        end
    end
    return total_percent
end

function randpairs(iters, populations; threshold = 0.01, verbose = true, kwargs...)
    k = length(populations)
    false_positives = Any[]
    false_negatives = Any[]
    total = 0
    for _ in 1:iters
        i, j = rand(1:k), rand(1:k)
        m, n = rand(1:length(populations[i])), rand(1:length(populations[j]))
        p = sametest(populations[i][m], populations[j][n]; kwargs...)
        reject = p < threshold
        if reject == (i == j)
            str = "[$i][$m] vs. [$j][$n]: $p"
            verbose && print(str)
            if reject
                verbose && println(" | FALSE POSITIVE")
                push!(false_positives, str)
            else
                verbose && println(" | FALSE NEGATIVE")
                push!(false_negatives, str)
            end
        end
        total += 1
    end
    return total, false_positives, false_negatives
end

function allpairs(populations; threshold = 0.01, verbose = true, kwargs...)
    false_positives = Any[]
    false_negatives = Any[]
    total = 0
    for i in 1:length(populations), j in 1:length(populations)
        for m in 1:length(populations[i]), n in 1:length(populations[j])
            p = sametest(populations[i][m], populations[j][n]; kwargs...)
            reject = p < threshold
            if reject == (i == j)
                str = "[$i][$m] vs. [$j][$n]: $p"
                verbose && print(str)
                if reject
                    verbose && println(" | FALSE POSITIVE")
                    push!(false_positives, str)
                else
                    verbose && println(" | FALSE NEGATIVE")
                    push!(false_negatives, str)
                end
            end
            total += 1
        end
    end
    return total, false_positives, false_negatives
end

function basepairs(x, y; threshold = 0.01, verbose = true, kwargs...)
    total = 0
    # there are no oppportunities for false negatives in our BaseBenchmarks dataset
    false_positives = Any[]
    for (k, v) in BenchmarkTools.leaves(x)
        if isa(x[k], BenchmarkTools.Trial)
            # only test trials with at least 10000 timings
            if length(v) >= 10000
                p = sametest(v, y[k]; kwargs...)
                if p < threshold
                    str = "$(k): $(p)"
                    verbose && println(str)
                    push!(false_positives, str)
                end
                total += 1
            end
        else # there's some bug in BenchmarkTools.leaves, this works around it
            t, childkeys = basepairs(x[k], y[k]; threshold = threshold, kwargs...)
            total += t
            for c in childkeys
                push!(false_positives, append!(k, childkeys))
            end
        end
    end
    return total, false_positives
end

############
# plotting #
############

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
