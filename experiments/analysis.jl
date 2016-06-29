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

#############################
# significance calculations #
#############################

reject(p, threshold) = p <= threshold

function pvalue(estsamps, nullval, testval)
    flipval = 2testval - nullval # nullval flipped around testval
    leftbound = min(flipval, nullval)
    rightbound = max(flipval, nullval)
    return 1 - mean(leftbound .< estsamps .< rightbound)
end

# For a given benchmark trial, estimate the minimum percent shift in the trial's location
# necessary to achieve a rejection with a given threshold and bootstrap parameters.
reject_effect(trial::BenchmarkTools.Trial; kwargs...) = reject_effect(trial.times; kwargs...)

function reject_effect(trial; threshold = 0.01, kwargs...)
    percent_unit = 0.001
    shift_unit = ceil(Int, minimum(trial) * percent_unit)
    total_percent = percent_unit
    trial_shifted = copy(trial)
    while total_percent < 1.0
        for i in eachindex(trial_shifted)
            trial_shifted[i] += shift_unit
        end
        if bootstrap_pvalue(trial, trial_shifted; kwargs...) < threshold
            return total_percent
        else
            total_percent += percent_unit
        end
    end
    return total_percent
end

# inverse of reject_effect; returns the appropriate threshold to reject at a given effect size
reject_threshold(trial::BenchmarkTools.Trial; kwargs...) = reject_threshold(trial.times; kwargs...)

function reject_threshold(trial; effect = 0.05, kwargs...)
    shift_unit = ceil(Int, minimum(trial) * effect)
    trial_shifted = copy(trial)
    for i in eachindex(trial_shifted)
        trial_shifted[i] += shift_unit
    end
    return bootstrap_pvalue(trial, trial_shifted; kwargs...)
end

################################
# bootstrap hypothesis testing #
################################

function bootstrap(a::BenchmarkTools.Trial, b::BenchmarkTools.Trial; kwargs...)
    return bootstrap(a.times, b.times; kwargs...)
end

function bootstrap(a, b; effect = 0.05, threshold = 0.01, auto = :threshold, kwargs...)
    p = bootstrap_pvalue(a, b; kwargs...)
    if auto == :threshold
        threshold_value = reject_threshold(a; effect = effect, kwargs...)
        effect_value = effect
    elseif auto == :effect
        threshold_value = threshold
        effect_value = reject_effect(a; threshold = threshold, kwargs...)
    else
        error("bad value for keyword argument auto: $auto")
    end
    return p, threshold_value, effect_value
end

function bootstrap_pvalue{T}(a::T, b::T; kwargs...)
    estsamps = bootstrap_dist(a, b; kwargs...)
    return pvalue(estsamps, 1.0, minimum(a) / minimum(b))
end

# m-out-of-n bootstrap with replacement
function bootstrap_dist(a, b; resample = 0.01, trials = min(1000, length(a), length(b)))
    estsamps = zeros(trials)
    a_resample = zeros(ceil(Int, resample*length(a)))
    b_resample = zeros(ceil(Int, resample*length(b)))
    for i in 1:trials
        estsamps[i] = minimum(rand!(a_resample, a)) / minimum(rand!(b_resample, b))
    end
    return estsamps
end

##################################
# aggregate testing on real data #
##################################

function allpairs(populations; verbose = true, kwargs...)
    false_positives = Any[]
    false_negatives = Any[]
    total = 0
    for i in 1:length(populations), j in 1:length(populations)
        for m in 1:length(populations[i]), n in 1:length(populations[j])
            p, threshold, effect = bootstrap(populations[i][m], populations[j][n]; kwargs...)
            rejectbool = reject(p, threshold)
            if rejectbool == (i == j)
                str = "[$i][$m] vs. [$j][$n]: $p | THRESHOLD: $threshold | EFFECT: $effect"
                verbose && print(str)
                if rejectbool
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

function basepairs(x, y; verbose = true, kwargs...)
    total = 0
    # there are no oppportunities for false negatives in our BaseBenchmarks dataset
    false_positives = Any[]
    for (k, v) in BenchmarkTools.leaves(x)
        p, threshold, effect = bootstrap(v, y[k]; kwargs...)
        if reject(p, threshold)
            str = "$(k): $p | THRESHOLD: $threshold | EFFECT: $effect"
            verbose && println(str)
            push!(false_positives, str)
        end
        total += 1
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
