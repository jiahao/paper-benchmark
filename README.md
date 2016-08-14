# Robust benchmarking in noisy environments

A paper by Jiahao Chen and Jarrett Revels,
[Julia Labs, MIT CSAIL](https://julia.mit.edu),
to be published in the _Proceedings of the 20th Annual [IEEE High Performance Extreme
Computing Conference](http://www.ieee-hpec.org) (HPEC 2016)_

[![Build Status](https://travis-ci.org/jiahao/paper-benchmark.svg?branch=master)](https://travis-ci.org/jiahao/paper-benchmark)

## Abstract

We propose a benchmarking strategy that is robust in the presence of timer
error, OS jitter and other environmental fluctuations, and is insensitive to
the highly nonideal statistics produced by timing measurements. We construct a
model that explains how these strongly nonideal statistics can arise from
environmental fluctuations, and also justifies our proposed strategy. We
implement this strategy in the
[BenchmarkTools](https://github.com/JuliaCI/BenchmarkTools.jl) Julia package,
where it is used in production continuous integration (CI) pipelines for
developing the Julia language and its ecosystem.

