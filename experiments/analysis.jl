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
    return mean(estsamps .<= leftbound) + mean(rightbound .<= estsamps)
end

function hypotest(est, nullval, a, b; rcut = 0.05, lcut = rcut, kwargs...)
    @assert length(a) == length(b)
    trimmed_a = trim(a, rcut, lcut)
    trimmed_b = trim(b, rcut, lcut)
    estsamps = bootstrap(est, trimmed_a, trimmed_b; kwargs...)
    return pvalue(estsamps, nullval, est(trimmed_a, trimmed_b))
end

#############
# bootstrap #
#############

function bootstrap(est::Function, a, b; resamps = 100, trials = 5000)
    estsamps = zeros(trials)
    for i in 1:trials
        estsamps[i] = est(rand(a, resamps), rand(b, resamps))
    end
    return sort!(estsamps)
end

function bootstrap(est::Function, a::BenchmarkTools.Trial, b::BenchmarkTools.Trial; kwargs...)
    return bootstrap(est, a.times, b.times; kwargs...)
end

##############
# estimators #
##############

location(t) = (minimum(t) + median(t)) / 2
iqr(t) = quantile(t, 0.85) - quantile(t, 0.15)
estimator(t) = location(t) + iqr(t)
estdiff(a, b) = estimator(a) - estimator(b)
estratio(a, b) = estimator(a) / estimator(b)

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

function randpairs(iters, est, nullval, trials; threshold = 0.05, kwargs...)
    k = length(trials)
    passed_all = true
    for _ in 1:iters
        i, j = rand(1:k), rand(1:k)
        m, n = rand(1:length(trials[i])), rand(1:length(trials[j]))
        p = hypotest(est, nullval, trials[i][m], trials[j][n]; kwargs...)
        reject = p < threshold
        invariant = i == j
        print("[$i][$m] vs. [$j][$n]: $p")
        reject && print("| REJECT ")
        passed = reject != invariant
        passed ? println() : println("| FAIL")
        passed_all &= passed
    end
    return passed_all
end


############################################################################################
# old code #################################################################################
############################################################################################
# The idea is to have a test statistic that characterizes both location and dispersion,
# with an estimator taking the form (in code, not stats notation):
#
# est(x::Vector) = dispersion(x) + r * location(x)
#
# where `r` is a relative weight coefficient that can be tuned empirically.

# good (there are values of c that cause the expected result for every case) #
#----------------------------------------------------------------------------#

# Gives correct/consistent classification when samples = 100, trials = 5000, and
# threshold = 0.05. It works for:
#   - `testsamples` (no matter what `est` is passed to `picksamples`)
#   - `testrandsamples` for all `trials` except `Vector[group[:branchsum_fast]]`
# location(x) = (minimum(x) + median(x)) / 2
# dispersion(x) = quantile(x, 0.) - quantile(x, 0.10)
# estimate(x) = dispersion(x) + location(x)

# estimate(x) = minimum(x)
# bad (there are not values of c that cause the expected result for every case) #
#-------------------------------------------------------------------------------#
# dispersion(x) = mean(x) - median(x)
# dispersion(x) = mean(x) - minimum(x)
# _est1(r) = x -> abs(mean(x) - median(x)) + r * minimum(x
# _est2(r) = x -> abs(mean(x) - minimum(x)) + r * median(x)
# _est3(r) = x -> (quantile(x, 0.75) - quantile(x, 0.25)) + r * minimum(x)
# _est4(r) = x -> (quantile(x, 0.90) - quantile(x, 0.40)) + r * minimum(x)
# _est5(r) = x -> var(x) + r * minimum(x)

#####################
# pvalues and tests #
#####################

# If z is more on the right of the distribution, integrate from right to left,
# otherwise, integrate from left to right. This might not be the proper thing
# to do, but at least solves the problem that the pvalue should be "close to"
# invariant under exchanging src1 and src2.

# Assuming group is stuctured like the benchmark group in benchmarks.jl, this function
# returns t1, t2, t_fast, t_slow where:
#
# t1 vs t2 -> invariant
# t_fast vs (t1 || t2) -> improvement
# t_slow vs (t1 || t2) -> regression
#
# The samples are selected to be "difficult" to classify relative to each other.
# function picksamples(est, group, id)
#     idstr = string(id)
#     if last(idstr) == '!'
#         idstr = idstr[1:end-1]
#         endstr = "!"
#     else
#         endstr = ""
#     end
#     id_fast = Symbol(string(idstr, "_fast", endstr))
#     id_slow = Symbol(string(idstr, "_slow", endstr))
#     times = [t.times for t in group[id]]
#     times_fast = [t.times for t in group[id_fast]]
#     times_slow = [t.times for t in group[id_slow]]
#     group_estimates = map(est, times)
#     t1 = group[id][indmin(group_estimates)].times
#     t2 = group[id][indmax(group_estimates)].times
#     t_fast = group[id_fast][indmax(map(est, times_fast))].times
#     t_slow = group[id_slow][indmin(map(est, times_slow))].times
#     return t1, t2, t_fast, t_slow
# end

# function testsamples(est, group; kwargs...)
#     for id in keys(group)
#         idstr = string(id)
#         if !(endswith(idstr, "_fast") || endswith(idstr, "_slow") ||
#              endswith(idstr, "_fast!") || endswith(idstr, "_slow!"))
#             testsamples(est, group, id; kwargs...)
#         end
#     end
# end
#
# function testsamples(est, group, id; threshold = 0.05, kwargs...)
#     t1, t2, t_fast, t_slow = picksamples(est, group, id)
#     println("id: $id")
#     println("--diff:")
#     println("\tt1 vs t2: ", pvalue_string(diffdist(est, t1, t2; kwargs...), threshold, 0.0))
#     println("\tt_fast vs t1: ", pvalue_string(diffdist(est, t_fast, t1; kwargs...), threshold, 0.0))
#     println("\tt_fast vs t2: ", pvalue_string(diffdist(est, t_fast, t2; kwargs...), threshold, 0.0))
#     println("\tt_slow vs t1: ", pvalue_string(diffdist(est, t_slow, t1; kwargs...), threshold, 0.0))
#     println("\tt_slow vs t2: ", pvalue_string(diffdist(est, t_slow, t2; kwargs...), threshold, 0.0))
#     println("\tt_slow vs t_fast: ", pvalue_string(diffdist(est, t_slow, t_fast; kwargs...), threshold, 0.0))
#     println("--div:")
#     println("\tt1 vs t2: ", pvalue_string(divdist(est, t1, t2; kwargs...), threshold, 1.0))
#     println("\tt_fast vs t1: ", pvalue_string(divdist(est, t_fast, t1; kwargs...), threshold, 1.0))
#     println("\tt_fast vs t2: ", pvalue_string(divdist(est, t_fast, t2; kwargs...), threshold, 1.0))
#     println("\tt_slow vs t1: ", pvalue_string(divdist(est, t_slow, t1; kwargs...), threshold, 1.0))
#     println("\tt_slow vs t2: ", pvalue_string(divdist(est, t_slow, t2; kwargs...), threshold, 1.0))
#     println("\tt_slow vs t_fast: ", pvalue_string(divdist(est, t_slow, t_fast; kwargs...), threshold, 1.0))
# end


########
# misc #
########

# function scankdes(trials::Array, delay = 0.001; kwargs...)
#     for i in 1:length(trials)
#         plotkde(trials[i]; kwargs...)
#         @show i
#         sleep(delay)
#         clf()
#     end
# end
#
# translate all time samples such that minimum sample is 1
# function eqmin(t::BenchmarkTools.Trial)
#     mintime = minimum(t.times) - 1
#     newtimes = t.times .- mintime
#     newgctimes = t.gctimes .- mintime
#     return BenchmarkTools.Trial(t.params, newtimes, newgctimes, t.memory, t.allocs)
# end
#
# eqmin(trials::Array) = map(eqmin, trials)
# eqmin(g::BenchmarkTools.BenchmarkGroup) = BenchmarkTools.mapvals(eqmin, g)

# # assumes trials[n] gives you a Trial with i samples at n evals
# function evalstransform(trials::Array)
#     samples = length(first(trials))
#     evals = length(trials)
#     @assert all(t -> length(t) == samples, trials) "trials must all have same number of samples"
#     results = [Vector{Int}(evals) for _ in 1:samples]
#     for i in 1:samples
#         for n in 1:evals
#             results[i][n] = trials[n].times[i]
#         end
#     end
#     return results
# end
