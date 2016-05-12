using BenchmarkTools
using Distributions
using JLD

BenchmarkTools.loadplotting()

########################
# distribution fitting #
########################
# t = trim(run(b), 0.10)
# plot(kde(normtimes(t)))
# plot(kde(rand(fit(t), 10000)))
#
# Note that removing outliers allows less alteration of the bandwidth of KDE on the experimental data

normtimes(t::BenchmarkTools.Trial) = t.times / minimum(t.times)
Distributions.fit{D<:Distributions.Distribution}(::Type{D}, t::BenchmarkTools.Trial) = fit(D, normtimes(t))
Distributions.fit(t::BenchmarkTools.Trial) = fit(Gamma, t)
