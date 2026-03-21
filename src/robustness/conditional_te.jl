"""
Robustness: Conditional TE (controlling for top confounders)

For each pairwise edge A→B, re-estimate TE conditioning on the top 3
potential confounders (by total degree in the raw network). This tests
whether edges survive when common drivers are controlled for.

Conditional TE: TE(A→B|C) uses VAR with lags of A, B, AND C.
If TE(A→B|C) ≈ 0, the original edge was driven by C.

Usage:
  julia -t auto src/robustness/conditional_te.jl
"""

include(joinpath(@__DIR__, "..", "data", "macro_filter.jl"))
include(joinpath(@__DIR__, "..", "estimation", "te.jl"))

using .MacroFilter, .TEEstimation
using CSV, DataFrames, Dates, Statistics, LinearAlgebra, Random

const VAR_LAG   = 1
const N_PERMS   = 500
const ALPHA     = 0.01
const LOGIT_EPS = 0.01

function logit(p::Float64)
    p_clipped = clamp(p / 100.0, LOGIT_EPS, 1.0 - LOGIT_EPS)
    return log(p_clipped / (1.0 - p_clipped))
end

"""
    conditional_te(xi, xj, xc, p) → Float64

TE from j→i conditioning on confounders xc (matrix, each row is a confounder).
Restricted model: i ~ lags(i) + lags(c1) + lags(c2) + ...
Unrestricted model: i ~ lags(i) + lags(j) + lags(c1) + lags(c2) + ...
"""
function conditional_te(xi::Vector{Float64}, xj::Vector{Float64},
                        xc::Matrix{Float64}, p::Int)
    T = length(xi)
    n_conf = size(xc, 1)

    Xi = TEEstimation.make_lags(xi, p)
    yi = xi[p+1:end]

    # Add confounder lags to restricted model
    X_restricted = Xi
    for c in 1:n_conf
        X_restricted = hcat(X_restricted, TEEstimation.make_lags(xc[c, :], p)[:, 1:p])
    end

    _, _, σ²_restricted = TEEstimation.ols(yi, X_restricted)

    # Add j's lags for unrestricted
    X_unrestricted = hcat(X_restricted, TEEstimation.make_lags(xj, p)[:, 1:p])
    _, _, σ²_unrestricted = TEEstimation.ols(yi, X_unrestricted)

    te = 0.5 * log(σ²_restricted / σ²_unrestricted)
    return max(te, 0.0)
end

function conditional_permutation_test(xi, xj, xc, p; n_perms=500, rng=Random.default_rng())
    te_obs = conditional_te(xi, xj, xc, p)

    T = length(xj)
    block_size = max(p, 5)
    n_blocks = ceil(Int, T / block_size)
    block_ranges = [(((b-1)*block_size+1), min(b*block_size, T)) for b in 1:n_blocks]

    xj_perm = Vector{Float64}(undef, T)
    perm_order = Vector{Int}(undef, n_blocks)

    count_ge = 0
    for _ in 1:n_perms
        randperm!(rng, perm_order)
        pos = 1
        for idx in 1:n_blocks
            b = perm_order[idx]
            s, e = block_ranges[b]
            len = min(e - s + 1, T - pos + 1)
            len <= 0 && break
            copyto!(xj_perm, pos, xj, s, len)
            pos += len
        end
        te_perm = conditional_te(xi, xj_perm, xc, p)
        te_perm >= te_obs && (count_ge += 1)
    end

    return te_obs, count_ge / n_perms
end

function main()
    println("=" ^ 70)
    println("Robustness: Conditional TE (top 3 confounders)")
    println("  Threads: $(Threads.nthreads())")
    println("=" ^ 70); flush(stdout)

    # Load logit matrix
    composites_df = CSV.read("data/results/composites.csv", DataFrame)
    composites_df.datetime = DateTime.(composites_df.datetime)
    families = sort(unique(composites_df.family))
    all_ts = sort(unique(composites_df.datetime))
    T = length(all_ts)
    N = length(families)
    ts_idx = Dict(t => j for (j, t) in enumerate(all_ts))
    L = fill(NaN, N, T)
    for (i, f) in enumerate(families)
        fdata = filter(r -> r.family == f, composites_df)
        for row in eachrow(fdata)
            j = get(ts_idx, row.datetime, 0)
            j > 0 || continue
            L[i, j] = logit(row.price)
        end
        last_val = NaN
        for j in 1:T
            if !isnan(L[i, j]); last_val = L[i, j]
            elseif !isnan(last_val); L[i, j] = last_val; end
        end
        last_val = NaN
        for j in T:-1:1
            if !isnan(L[i, j]); last_val = L[i, j]
            elseif !isnan(last_val); L[i, j] = last_val; end
        end
    end
    family_idx = Dict(f => i for (i, f) in enumerate(families))
    println("Matrix: $N families × $T bars"); flush(stdout)

    # Load classified edges — only test genuine edges
    classified = CSV.read("data/results/classified_edges.csv", DataFrame)
    genuine = filter(r -> r.final_label in ["genuine", "event_amplified"], classified)
    println("Testing $(nrow(genuine)) genuine/event-amplified edges"); flush(stdout)

    # Identify top 3 confounders by total degree in raw network
    edges = CSV.read("data/results/edge_list.csv", DataFrame)
    src_counts = combine(groupby(edges, :source), nrow => :n)
    tgt_counts = combine(groupby(edges, :target), nrow => :n)
    degree = outerjoin(rename(src_counts, :source => :node, :n => :out),
                       rename(tgt_counts, :target => :node, :n => :in_), on=:node)
    degree.out = coalesce.(degree.out, 0)
    degree.in_ = coalesce.(degree.in_, 0)
    degree.total = degree.out .+ degree.in_
    sort!(degree, :total, rev=true)

    top_confounders = first(degree.node, 3)
    println("Top 3 confounders (by total degree): $(join(top_confounders, ", "))"); flush(stdout)

    # For each genuine edge, run conditional TE on the FULL time series
    # (not rolling windows — just a single full-sample test for robustness)
    results = Vector{NamedTuple}(undef, nrow(genuine))

    Threads.@threads for k in 1:nrow(genuine)
        row = genuine[k, :]
        src, tgt = string(row.source), string(row.target)
        i = get(family_idx, tgt, 0)  # target is predicted
        j = get(family_idx, src, 0)  # source is predictor

        if i == 0 || j == 0
            results[k] = (source=src, target=tgt, pairwise_te=0.0,
                          conditional_te=0.0, pairwise_p=1.0, conditional_p=1.0,
                          survives=false)
            continue
        end

        xi = L[i, :]
        xj = L[j, :]

        # Build confounder matrix (exclude source and target from confounders)
        conf_idx = [family_idx[string(c)] for c in top_confounders
                    if string(c) != src && string(c) != tgt && haskey(family_idx, string(c))]
        if isempty(conf_idx)
            results[k] = (source=src, target=tgt, pairwise_te=0.0,
                          conditional_te=0.0, pairwise_p=1.0, conditional_p=1.0,
                          survives=false)
            continue
        end

        # Remove NaN columns
        valid = [all(!isnan, L[[i; j; conf_idx], col]) for col in 1:T]
        xi_clean = xi[valid]
        xj_clean = xj[valid]
        xc_clean = L[conf_idx, valid]

        rng = MersenneTwister(42 + k)

        # Pairwise TE (no conditioning)
        pw_te, pw_p = TEEstimation.permutation_test(xi_clean, xj_clean, VAR_LAG;
                                                     n_perms=N_PERMS, rng=rng)

        # Conditional TE
        rng2 = MersenneTwister(43 + k)
        ct_te, ct_p = conditional_permutation_test(xi_clean, xj_clean, xc_clean, VAR_LAG;
                                                    n_perms=N_PERMS, rng=rng2)

        results[k] = (source=src, target=tgt,
                      pairwise_te=round(pw_te, digits=6),
                      conditional_te=round(ct_te, digits=6),
                      pairwise_p=round(pw_p, digits=4),
                      conditional_p=round(ct_p, digits=4),
                      survives=ct_p < ALPHA)
    end

    df = DataFrame(collect(results))
    sort!(df, :pairwise_te, rev=true)

    n_survive = count(df.survives)
    n_total = nrow(df)
    println("\n── Results ──")
    println("  Edges tested: $n_total")
    println("  Survive conditional TE: $n_survive ($( round(100*n_survive/n_total, digits=1))%)")
    println("  Lost to conditioning: $(n_total - n_survive)")

    # Show edges that were lost
    lost = filter(r -> !r.survives && r.pairwise_p < ALPHA, df)
    if nrow(lost) > 0
        println("\n  Edges lost after conditioning on $(join(top_confounders, ", ")):")
        for r in eachrow(first(lost, 15))
            println("    $(r.source) → $(r.target): pw_te=$(r.pairwise_te) → cond_te=$(r.conditional_te), p=$(r.conditional_p)")
        end
    end

    CSV.write("data/results/conditional_te.csv", df)
    println("\nSaved: data/results/conditional_te.csv")
    println("=" ^ 70); flush(stdout)
end

main()
