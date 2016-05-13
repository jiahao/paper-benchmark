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
#  (1/6) benchmarking :noisy_scalar...
#  done (took 1.412297008 seconds)
#  (2/6) benchmarking :pushall!...
#  done (took 0.467905166 seconds)
#  (3/6) benchmarking (:sumindex,:miss)...
#  done (took 0.561127866 seconds)
#  (4/6) benchmarking :sqralloc...
#  done (took 1.377793755 seconds)
#  (5/6) benchmarking (:sumindex,:hit)...
#  done (took 0.562570577 seconds)
#  (6/6) benchmarking :branchsum...
#  done (took 0.834586241 seconds)
#  (1/6) benchmarking :noisy_scalar...
#  done (took 1.413318973 seconds)
#  (2/6) benchmarking :pushall!...
#  done (took 0.471280875 seconds)
#  (3/6) benchmarking (:sumindex,:miss)...
#  done (took 0.560402967 seconds)
#  (4/6) benchmarking :sqralloc...
#  done (took 1.378909317 seconds)
#  (5/6) benchmarking (:sumindex,:hit)...
#  done (took 0.562292214 seconds)
#  (6/6) benchmarking :branchsum...
#  done (took 0.832725015 seconds)
function repeat_experiment(group, reps)
    tune!(group)
    results = Vector{BenchmarkGroup}(reps)
    for i in 1:reps
        results[i] = run(group; verbose = true)
    end
    return flatten_repeat_results(keys(group), results)
end

function flatten_repeat_results(keys, results)
    group = BenchmarkGroup()
    reps = length(results)
    for k in keys
        trials = Vector{BenchmarkTools.Trial}(reps)
        group[k] = trials
        for i in 1:reps
            trials[i] = results[i][k]
        end
    end
    return group
end
