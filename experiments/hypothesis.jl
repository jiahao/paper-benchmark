# This code isn't featured in this paper, but was used to experiment with different
# hypothesis testing methods.

##################################
# aggregate testing on real data #
##################################
# These tests
# julia> allpairs(alltrials(group, :branchsum), trials = 1000, threshold = 0.05, gamma = 0.01)
#   (322 false positives / 15150 actual negatives)  = 0.02
#   (2065 false negatives / 15150 actual positives) = 0.13
#
# julia> allpairs(alltrials(group, :pushall!), trials = 1000, threshold = 0.05, gamma = 1/5)
#   (0 false positives / 15150 actual negatives)  = 0.0
#   (0 false negatives / 15150 actual positives) = 0.0
#
# julia> allpairs(alltrials(group, :manyallocs), trials = 1000, threshold = 0.05, gamma = 1/5)
#   (0 false positives / 15150 actual negatives)  = 0.0
#   (0 false negatives / 15150 actual positives) = 0.0
#
# julia> allpairs(alltrials(group, :sumindex), trials = 1000, threshold = 0.05, gamma = 1/7)
#   (103 false positives / 15150 actual negatives)  = 0.006
#   (0 false negatives / 15150 actual positives) = 0.0

# test every pairwise combination, assuming test of i vs j == test of j vs i
function allpairs(populations; verbose = true, threshold = 0.05, kwargs...)
    false_positives = 0
    false_negatives = 0
    actual_positives = 0
    actual_negatives = 0
    for i in 1:length(populations), j in 1:i
        for m in 1:length(populations[i]), n in 1:m
            judgement = BenchmarkTools.judge(populations[i][m], populations[j][n]; threshold = threshold, kwargs...)
            p, effect = pvalue(judgement), time(ratio(judgement))
            detected_positive = p < threshold
            is_positive = i != j
            if is_positive
                actual_positives += 1
            else
                actual_negatives += 1
            end
            if detected_positive != is_positive
                verbose && print("[$i][$m] vs. [$j][$n]: $p | EFFECT: $effect")
                if detected_positive
                    verbose && println(" | FALSE POSITIVE")
                    false_positives += 1
                else
                    verbose && println(" | FALSE NEGATIVE")
                    false_negatives += 1
                end
            end
        end
    end
    return (false_positives, actual_negatives), (false_negatives, actual_positives)
end

function basepairs(x, y; verbose = true, threshold = 0.05, trials = 1000, kwargs...)
    total = 0
    # there are no oppportunities for false negatives in our BaseBenchmarks dataset
    false_positives = Any[]
    for (k, v) in BenchmarkTools.leaves(x)
        judgement = BenchmarkTools.judge(v, y[k]; time_tolerance = threshold, kwargs...)
        p, effect, status = pvalue(judgement), time(ratio(judgement)), time(judgement)
        if reject(p, threshold)
            str = "$(k): $p | THRESHOLD: $threshold | EFFECT: $effect"
            verbose && println(str)
            push!(false_positives, str)
        end
        total += 1
    end
    return total, false_positives
end
