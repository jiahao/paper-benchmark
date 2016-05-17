using BenchmarkTools
using JLD

#######################
# Benchmark Functions #
#######################

# periodic copy + reallocation
function pushall!(collection, items)
    x = 0.0
    for item in items
        x = rand()
        push!(collection, item)
    end
    return collection
end

function pushall_fast!(collection, items)
    for item in items
        push!(collection, item)
    end
    return collection
end

function pushall_slow!(collection, items)
    x, y = 0.0, 0.0
    for item in items
        x, y = rand(), rand()
        push!(collection, item)
    end
    return collection
end

# recursion, uneven branching, no allocation
# Note: The fact that these branchsum functions perform drastically differently is somewhat
# distressing, and probably points to an actual Julia performance bug.
function branchsum(n)
    x = 1
    for i in 1:n
        if iseven(i)
            x += -1
        else
            for i in 1:n
                x += ifelse(iseven(i), -1, 1)
            end
        end
    end
    return x
end

function branchsum_fast(n)
    x = 1
    if isodd(n)
        for i in 1:n
            x += iseven(i) ? -1 : 1
        end
    else
        for i in 1:n
            x += iseven(i) ? -1 : branchsum_fast(i)
        end
    end
    return x
end


function branchsum_slow(n)
    x = 1
    if isodd(n)
        for i in 1:n
            if iseven(i)
                x += -1
            else
                x += 1
            end
        end
    else
        for i in 1:n
            if iseven(i)
                x += -1
            else
                x += branchsum_slow(i)
            end
        end
    end
    return x
end

# inds can be changed to test cache effects
function sumindex_core(A, inds)
    s = zero(eltype(A))
    for i in inds
        s += A[i]
    end
    return s
end

sumindex(A) = sumindex_core(A, collect(1:length(A)))
sumindex_fast(A) = sumindex_core(A, 1:length(A))
sumindex_slow(A) = sumindex_core(A, collect(length(A):-1:1))

# frequent reallocations of varying size
manyallocs(n) = [collect(1:rand(MersenneTwister(1), 1:n)) for i in 1:n]

function manyallocs_fast(n)
    m = rand(MersenneTwister(1), 1:n)
    return [collect(1:m) for i in 1:n]
end

function manyallocs_slow(n)
    x = Any[]
    for i in 1:n
        y = Any[]
        for j in 1:rand(MersenneTwister(1), 1:n)
            push!(y, j)
        end
        push!(x, deepcopy(y))
    end
    return x
end

###################
# Benchmark Suite #
###################

const suite = BenchmarkGroup()
const A = rand(MersenneTwister(1), 100)

suite[:pushall!]      = @benchmarkable pushall!(Float64[], $A) evals=16
suite[:pushall_fast!] = @benchmarkable pushall_fast!(Float64[], $A) evals=10
suite[:pushall_slow!] = @benchmarkable pushall_slow!(Float64[], $A) evals=165

suite[:branchsum]      = @benchmarkable branchsum(50) evals=190
suite[:branchsum_fast] = @benchmarkable branchsum_fast(50) evals=200
suite[:branchsum_slow] = @benchmarkable branchsum_slow(50) evals=107

suite[:sumindex]      = @benchmarkable sumindex($A) evals=460
suite[:sumindex_fast] = @benchmarkable sumindex_fast($A) evals=947
suite[:sumindex_slow] = @benchmarkable sumindex_slow($A) evals=310

suite[:manyallocs]      = @benchmarkable manyallocs(10) evals=1
suite[:manyallocs_fast] = @benchmarkable manyallocs_fast(10) evals=1
suite[:manyallocs_slow] = @benchmarkable manyallocs_slow(10) evals=1

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

# julia> JLD.save("results/new_results.jld", "suite", repeat_experiment(suite, 100));
function repeat_experiment(group, reps)
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
