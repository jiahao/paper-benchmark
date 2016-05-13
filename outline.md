# A Robust Method For Detecting Performance Regressions

## Introduction

We present a statistically rigorous approach to performance regression testing that is valid in the presence of OS jitter, such as frequency scaling, thread rescheduling, and variations in memory layout (ASLR, swapping, etc.).

portability

List relevant work:

- reducing OS jitter to increase data reproducibility
- reducing OS jitter to increase performance
- randomization of  to induce Gaussian timing distributions
- strategies for orchestrating performance counters

## Modeling Program Timing Distributions

We only focus on programs without side effects, allowing us to assume that each benchmark execution is logically independent. The problem we encounter is that programs without internal, logical side effects can still have practical side effects at external abstraction levels, notably at the OS level. These side effects, as well as side effects induced by external programs, can introduce variations in the runtime of otherwise "pure" programs. In order to classify regressions in the presence of these variations, we need to develop a rigorous statistical model for our runtime that incorporates them.

The first step to defining this model is to write down a definition for the "true" runtime of a benchmark, so that we can subsequently define the meaning of "timing variation". To do this, we must assume a model of computation. The computer on which our benchmark programs execute can be fully described by a set of configuration values that determine its state. The act of running a program is to mutate this configuration in a deterministic way.



that our computer is defined by an explicit state configuration whose value is sufficient to deterministically reproduce the entire execution path of a program run on the computer.




In an ideal universe, we can obtain the ideal, deterministic benchmark time, which is the runtime of the benchmark in some ideal configuration of the hardware/OS that minimizes the runtime. Any deviation from the ideal configuration can be seen as the triggering of a noise source (or maybe any noise source is the result of a deviation from this ideal configuration). Triggering factors of OS jitter is not the same as triggering a noise source - in fact, the optimal configuration "path" that a program executes along (traverses as it executes?) will probably include factors that, for some other benchmark, would cause deviation from the optimal runtime. Thus, noise sources are defined by the combined properties of the benchmark, OS, and hardware configuration that minimizes benchmark runtime compared to any other OS/hardware configuration.

Imagine the whole universe of possible environment (OS/hardware) starting configurations. Each configuration is specified so precisely that you have enough information to deterministically reproduce the entire execution of the program. Our definition of "ideal runtime" is equivalent to the minimum runtime over all the possible runtimes obtained from all possible points in the starting configurations space.


For a typical OS configuration, OS jitter can either add to, or decrease program runtime. In the  

We postulate that OS jitter contributes only positively to benchmark runtime. This is

In order to perform statistical regression detection, we must first assume the program to have a "true" runtime, `t`, that is the theoretical minimum runtime of the program with respect to a given hardware specification. Using this definition of `t`, we are implicitly modeling all noise as positive. **(does this require further justification?)**

Our model for an individual sample is `T = n*t + d(r,t,n) + ∑(i*xᵢ)`, where:

- `T` is total observed sample time
- `n*t` is the minimum theoretical sample time, where:
    - `n` is the number of evaluations performed per sample
    - `t` is the minimum theoretical benchmark time
- `d(r,t,n)` is the noise due to discretization, where:
    - `r` is the resolution of the timing method
- `∑(i*xᵢ)` is noise due to deviations from the ideal configuration, where:
    - `i` is a time variation from `1` to `∞`.
    - `xᵢ` is the number of occurrences of `i` during our sample

In order to avoid the OS jitter term blowing up, we define each `xᵢ` to be a discrete, not necessarily independent, random variable following a distribution that is sublinear **(???)** in `n`. Given this model, we show that it generates `T` distributions

## A Hypothesis Test for Regression Detection

Our test statistic is the difference of the two minima of the distribution


<!-- As shown in the previous section, `T` follows a Gamma/Erlang distribution. The minimum is a robust estimator of the location parameter of the distribution followed by `T`, and so we'll use the distance between the minima to characterize a code change as an invariant, improvement, or a regression with respect to performance.

However, the location parameters alone are not enough to determine whether translations in the distribution are due to a code change or due to noise. To make our detection procedure robust, we need to incorporate distribution shape as an indicator of the statistical significance of location translations.

To do this, we define the following hypothesis test:

1. Our null hypothesis is that the code change between experiment `A` and experiment `B` is not a regression. Our test statistic is the minimum estimator.
2. For each set of time samples `T_A` and `T_B`, obtain a distribution of the minima via resampling.
3. Calculate the area of the critical region (the non-overlapping area of the two minima distributions)
4. Within some tolerance suitable to the benchmark, use the area of the critical region to reject or accept the null hypothesis.

For whole benchmark suites, this calculation can be -->

Γ^(-1)(... l_x; q = 0) - Γ^(-1)(... l_y; q = 0)

## Empirical results on benchmarks of the Julia language

Samples generally appears to follow a Gamma distribution, plus modes at points of high-frequency noise (large `xᵢ`s). The modality/phase structure of the samples seems to be a property inherent to each benchmark, . This could be interpreted as either the benchmark is characteristically vulnerable to certain sources of noise, or that the benchmark triggers certain sources of noise with high frequency.

To demonstrate the effectiveness of our hypothesis test
