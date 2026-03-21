"""
Robustness: Non-Overlapping Windows (step=60d)

Re-run TE pipeline with non-overlapping windows to verify that
persistence counts are not inflated by 59/60 data overlap.

Usage:
  julia -t auto src/robustness/nonoverlap_windows.jl
"""

include(joinpath(@__DIR__, "..", "data", "macro_filter.jl"))
include(joinpath(@__DIR__, "..", "estimation", "te.jl"))

using .MacroFilter, .TEEstimation
using CSV, DataFrames, Dates, Statistics, LinearAlgebra, Random

const WINDOW_DAYS = 60
const STEP_DAYS   = 60   # NON-OVERLAPPING
const MIN_ACTIVE  = 30
const VAR_LAG     = 1
const N_PERMS     = 500
const ALPHA       = 0.01
const LOGIT_EPS   = 0.01

function logit(p::Float64)
    p_clipped = clamp(p / 100.0, LOGIT_EPS, 1.0 - LOGIT_EPS)
    return log(p_clipped / (1.0 - p_clipped))
end

function load_logit_matrix()
    composites_df = CSV.read("data/results/composites.csv", DataFrame)
    composites_df.datetime = DateTime.(composites_df.datetime)
    families = sort(unique(composites_df.family))
    all_ts = sort(unique(composites_df.datetime))
    T = length(all_ts)
    N = length(families)
    ts_idx = Dict(t => j for (j, t) in enumerate(all_ts))
    L = fill(NaN, N, T)
    has_obs = falses(N, T)
    for (i, f) in enumerate(families)
        fdata = filter(r -> r.family == f, composites_df)
        for row in eachrow(fdata)
            j = get(ts_idx, row.datetime, 0)
            j > 0 || continue
            L[i, j] = logit(row.price)
            has_obs[i, j] = true
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
    return L, families, all_ts, has_obs
end

function main()
    println("=" ^ 70)
    println("Robustness: Non-Overlapping Windows (step=$(STEP_DAYS)d)")
    println("  Threads: $(Threads.nthreads())")
    println("=" ^ 70); flush(stdout)

    L, families, timestamps, has_obs = load_logit_matrix()
    N_total, T_total = size(L)
    dates = Date.(timestamps)
    println("Matrix: $(N_total) families × $(T_total) bars"); flush(stdout)

    family_obs_days = Dict{Int, Set{Date}}()
    for i in 1:N_total
        obs = Set{Date}()
        for j in 1:T_total
            has_obs[i, j] && push!(obs, dates[j])
        end
        family_obs_days[i] = obs
    end

    # Pre-generate non-overlapping windows
    date_set = sort(unique(dates))
    w_start = date_set[1]
    w_end_max = date_set[end]

    tasks = []
    w_idx = 0
    while w_start + Day(WINDOW_DAYS) <= w_end_max
        w_end = w_start + Day(WINDOW_DAYS)
        w_idx += 1
        active_families = Int[]
        for i in 1:N_total
            active_days = count(d -> w_start <= d <= w_end, family_obs_days[i])
            active_days >= MIN_ACTIVE && push!(active_families, i)
        end
        if length(active_families) >= 3
            col_mask = [w_start <= dates[j] <= w_end for j in 1:T_total]
            L_w = L[active_families, col_mask]
            valid_cols = [all(!isnan, L_w[:, j]) for j in 1:size(L_w, 2)]
            L_w = L_w[:, valid_cols]
            N_w, T_w = size(L_w)
            if T_w >= 30 && N_w >= 3
                push!(tasks, (w_idx=w_idx, w_start=w_start, L_w=L_w,
                              active_families=active_families))
            end
        end
        w_start += Day(STEP_DAYS)
    end

    n_tasks = length(tasks)
    println("Non-overlapping windows: $n_tasks (vs 402 overlapping)"); flush(stdout)

    # Process in parallel
    result_edges = Vector{Vector{NamedTuple}}(undef, n_tasks)
    result_summaries = Vector{NamedTuple}(undef, n_tasks)

    Threads.@threads for k in 1:n_tasks
        task = tasks[k]
        rng = MersenneTwister(42 + k)
        L_w = task.L_w
        N_w, T_w = size(L_w)
        w_families = families[task.active_families]

        A = zeros(N_w, N_w)
        TE_mat = zeros(N_w, N_w)
        for i in 1:N_w, j in 1:N_w
            i == j && continue
            try
                te_val, p_val = TEEstimation.permutation_test(
                    L_w[i, :], L_w[j, :], VAR_LAG; n_perms=N_PERMS, rng=rng)
                TE_mat[i, j] = te_val
                A[i, j] = p_val < ALPHA ? 1.0 : 0.0
            catch; end
        end

        n_edges = Int(sum(A))
        density = n_edges / (N_w * (N_w - 1))

        result_summaries[k] = (window_idx=task.w_idx, start_date=task.w_start,
                                N=N_w, T=T_w, n_edges=n_edges,
                                density=round(density, digits=4))

        edges_k = NamedTuple[]
        for i in 1:N_w, j in 1:N_w
            A[i, j] == 1.0 || continue
            push!(edges_k, (window_idx=task.w_idx, start_date=task.w_start,
                            source=w_families[j], target=w_families[i],
                            te_value=round(TE_mat[i, j], digits=6)))
        end
        result_edges[k] = edges_k
    end

    # Collect
    all_edges = NamedTuple[]
    for ek in result_edges
        append!(all_edges, ek)
    end
    edges_df = DataFrame(all_edges)
    summaries_df = DataFrame(collect(result_summaries))
    sort!(summaries_df, :window_idx)

    # Compare with overlapping
    println("\n── Results ──")
    println("  Non-overlapping windows: $(n_tasks)")
    println("  Total edge instances: $(nrow(edges_df))")
    unique_pairs = nrow(unique(select(edges_df, :source, :target)))
    println("  Unique directed pairs: $unique_pairs")
    println("  Avg density: $(round(100*mean(summaries_df.density), digits=2))%")

    # Persistence comparison
    if nrow(edges_df) > 0
        pers = combine(groupby(edges_df, [:source, :target]), nrow => :persistence)
        sort!(pers, :persistence, rev=true)
        println("\n  Top 10 edges by non-overlapping persistence:")
        for r in eachrow(first(pers, 10))
            println("    $(r.source) → $(r.target): $(r.persistence) / $n_tasks windows")
        end

        # Compare with overlapping persistence
        overlap_edges = CSV.read("data/results/edge_list.csv", DataFrame)
        overlap_pers = combine(groupby(overlap_edges, [:source, :target]), nrow => :overlap_pers)

        merged = leftjoin(pers, overlap_pers, on=[:source, :target])
        merged.overlap_pers = coalesce.(merged.overlap_pers, 0)
        if nrow(merged) > 2
            corr = cor(Float64.(merged.persistence), Float64.(merged.overlap_pers))
            println("\n  Persistence rank correlation (non-overlap vs overlap): $(round(corr, digits=3))")
        end
    end

    CSV.write("data/results/nonoverlap_summary.csv", summaries_df)
    CSV.write("data/results/nonoverlap_edges.csv", edges_df)
    println("\nSaved: data/results/nonoverlap_summary.csv, nonoverlap_edges.csv")
    println("=" ^ 70); flush(stdout)
end

main()
