using BenchmarkTools
using JLD

#######################
# Benchmark Functions #
#######################

# periodic copy + reallocation
function pushall!(collection, items)
    for item in items
        push!(collection, item)
    end
    return collection
end

# recursion, uneven branching, no allocation
function branchsum(n)
    x = 1
    if isodd(n)
        for i in 1:n
            x += iseven(i) ? -1 : 1
        end
    else
        for i in 1:n
            x += iseven(i) ? -1 : branchsum(i)
        end
    end
    return x
end

# inds can be changed to test cache effects
function sumindex(A, inds)
    s = zero(eltype(A))
    for i in inds
        s += A[i]
    end
    return s
end

# frequent reallocations of varying size
sqralloc(n) = [rand(i) for i in 1:n]

###################
# Benchmark Suite #
###################

const suite = BenchmarkGroup()
const seed = MersenneTwister(1)
const arr = rand(deepcopy(seed), 1000)
const linear_inds = collect(1:length(arr))
const rand_inds = rand(deepcopy(seed), linear_inds, length(arr))

suite[:pushall!]        = @benchmarkable pushall!(x, $arr) setup=(x = Float64[])
suite[:branchsum]       = @benchmarkable branchsum(50)
suite[:sqralloc]        = @benchmarkable sqralloc(10)
suite[:sumindex, :hit]  = @benchmarkable sumindex($arr, $linear_inds)
suite[:sumindex, :miss] = @benchmarkable sumindex($arr, $rand_inds)
suite[:noisy_scalar]    = @benchmarkable $(one(Complex{BigInt})) / $(one(BigFloat))

##############
# Experiment #
##############

# julia> JLD.save("results/evals_results.jld", "suite", evals_experiment(suite, 1000, 1:1000));
function evals_experiment(group, s, ns)
    result = BenchmarkGroup()
    for (id, bench) in group
        result[id] = BenchmarkTools.Trial[run(bench, samples = s, evals = n, seconds=1200) for n in ns]
    end
    return result
end

# julia> JLD.save("results/repeat_results.jld", "suite", repeat_experiment(suite, 100));
function repeat_experiment(group, reps)
    tune!(group)
    result = Vector{BenchmarkGroup}(reps)
    for i in 1:reps
        result[i] = run(group; verbose = true)
    end
    return result
end
