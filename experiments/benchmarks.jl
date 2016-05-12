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
const linear_inds = 1:length(arr)
const rand_inds = rand(deepcopy(seed), linear_inds, length(arr))

suite[:pushall!]        = @benchmarkable pushall!(x, $arr) setup=(x = Float64[])
suite[:branchsum]       = @benchmarkable branchsum(50)
suite[:sqralloc]        = @benchmarkable sqralloc(10)
suite[:sumindex, :hit]  = @benchmarkable sumindex($arr, $linear_inds)
suite[:sumindex, :miss] = @benchmarkable sumindex($arr, $rand_inds)

# tune!(suite)
# JLD.save("params.jld", "suite", params(suite))
loadparams!(suite, JLD.load("params.jld", "suite"), :evals)
