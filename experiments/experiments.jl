using BenchmarkTools
using BenchmarkTools: lineartrial
using Distributions
using JLD

BenchmarkTools.loadplotting()

#####################
# Theoretical Model #
#####################

const TIMES = 0.0:0.01:100.0  # noise in multiples of true benchmark time

# an occurence vector where each entry counts how many times a given amount of noise was emitted by some source
occurs(rng, n) = sprand(rng, 0:n, length(TIMES))

# a configuration of occurence vectors for a number of evaluations
config(i, evals) = (rng = MersenneTwister(i); return [occurs(rng, n) for n in 1:evals])

# a sample of a given configuration at n evaluations
sample(config, n) = dot(config[n], TIMES)

# time incorporating noise from discretization
# r is resolution, n is evaluations, t is true
# benchmark time (automatically set to 1)
tdisc(r, n) = tdisc(1, r, n)
tdisc(t, r, n) = (ceil(n * t / r) * r) / n
maxdisc(t, r) = tdisc(t, r, 1) # (ceil(t / r) * r)

# give the minimum number of evaluations necessary to eliminate discretization noise
nevals(t::Int, r::Int) = div(r, gcd(t, r))

# a line for a theoretical benchmark
bench(r, config) = bench(1, r, config)
bench(t, r, config) = [(tdisc(t, r, n) + (sample(config, n) / n)) for n in 1:length(config)]

###################
# Test Benchmarks #
###################

# distribution is sum1000.png
# b = tune!(@benchmarkable sum($(rand(1000))))

# distribution is gamma-like
# b = tune!(@benchmarkable $(one(Complex{BigInt})) / $(one(Complex{BigFloat}))))

# distribution is ?
# b = tune!(@benchmarkable eig($(rand(10, 10))))

# distribution is
# function f(n)
#     x = 1
#     for i in 1:(n*10)
#        x += ifelse(iseven(i), -1, 1)
#     end
#     return x
# end
# b = tune!(@benchmarkable f(1))

#######################################
# Experiment 1: Distributions fitting #
#######################################
# b = tune!(@benchmarkable ...)
# t = run(b)
# tt = trim(t, 0.10)
# plot(kde(rand(fit(tt), 10000)))
# plot(kde(normtimes(tt)))
#
# Note that removing outliers allows less alteration of the bandwidth of KDE on the experimental data

normtimes(t::BenchmarkTools.Trial) = t.times / minimum(t.times)
Distributions.fit{D<:Distributions.Distribution}(::Type{D}, t::BenchmarkTools.Trial) = fit(D, normtimes(t))
Distributions.fit(t::BenchmarkTools.Trial) = fit(Gamma, t)

#################################################
# Experiment 2: Minima Comparison Distributions #
#################################################

# `src` is the source of samples, and could be
# raw data, resampled data, or a fitted distribution
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

# b = tune!(@benchmarkable ...)
# t = trim(run(b), 0.10)
# raw = normtimes(t)
# dist = fit(t)

# using raw data
# plot(kde(mindist(raw)))

# using fitted distribution
# plot(kde(mindist(dist)))

# using resampled raw data
# plot(kde(mindist(rand(raw, 10000)))

# using samples from distribution
# plot(kde(mindist(rand(dist, 10000)))

###################################
# Experiment 3: Many lineartrials #
###################################
# See fmanytrials.png
# ts = [BenchmarkTools.lineartrial(b)[2] for _ in 1:1000]
# ts = JLD.load(joinpath(homedir(), "data", "code", "benchpaper", "lintrials.jld"), "f1")
# maxs = [maximum(map(t->t[i], ts)) for i in 1:1000]
# mins = [minimum(map(t->t[i], ts)) for i in 1:1000]
