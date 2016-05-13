using BenchmarkTools
using Distributions
using JLD

# This provides the `plotkde` function, which is pretty convenient for plotting all the
# of the data contained in `trials`. See the code here:
# https://github.com/JuliaCI/BenchmarkTools.jl/blob/master/src/plotting.jl
BenchmarkTools.loadplotting()

const group = JLD.load("results/results.jld", "suite");

function scankdes(trials::Array, delay = 3; kwargs...)
    for i in 1:length(trials)
        plotkde(trials[i]; kwargs...)
        @show i
        sleep(delay)
        clf()
    end
end

# translate all time samples such that minimum sample is 1
function mintranslate(t::BenchmarkTools.Trial)
    mintime = minimum(t.times) - 1
    newtimes = t.times .- mintime
    newgctimes = t.gctimes .- mintime
    return BenchmarkTools.Trial(t.params, newtimes, newgctimes, t.memory, t.allocs)
end

mintranslate(trials::Array) = map(mintranslate, trials)
mintranslate(g::BenchmarkTools.BenchmarkGroup) = BenchmarkTools.mapvals(mintranslate, g)

# assumes trials[n] gives you a Trial with i samples at n evals
function evalstransform(trials::Array)
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
