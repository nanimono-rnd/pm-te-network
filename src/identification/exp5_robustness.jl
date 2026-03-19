"""
Identification Experiment 5: Placebo & Robustness

5a. Placebo test: random event dates → re-run Exp 1 classification → compare
5b. Window length sensitivity: re-run TE with 45d and 90d windows
5c. α threshold sensitivity: re-classify edges at α=0.05
5d. Half-sample stability: first-half vs second-half edge persistence

Usage:
  julia -t auto src/identification/exp5_robustness.jl
"""

include(joinpath(@__DIR__, "..", "data", "macro_filter.jl"))
include(joinpath(@__DIR__, "..", "estimation", "te.jl"))

using .MacroFilter, .TEEstimation
using CSV, DataFrames, Dates, Statistics, LinearAlgebra, Random

# ═══════════════════════════════════════════════════════════════════════════════
# Config
# ═══════════════════════════════════════════════════════════════════════════════

const VAR_LAG   = 1
const N_PERMS   = 500
const LOGIT_EPS = 0.01
const MIN_ACTIVE = 30
const STEP_DAYS = 1

# Real event dates (from experiments.jl)
const FOMC_DATES = Date.(["2024-01-31","2024-03-20","2024-05-01","2024-06-12","2024-07-31","2024-09-18","2024-11-07","2024-12-18","2025-01-29","2025-03-19","2025-05-07","2025-06-18","2025-07-30","2025-09-17","2025-10-29","2025-12-17","2026-01-28","2026-03-18"])
const CPI_DATES = Date.(["2024-01-11","2024-02-13","2024-03-12","2024-04-10","2024-05-15","2024-06-12","2024-07-11","2024-08-14","2024-09-11","2024-10-10","2024-11-13","2024-12-11","2025-01-15","2025-02-12","2025-03-12","2025-04-10","2025-05-13","2025-06-11","2025-07-10","2025-08-12","2025-09-10","2025-10-14","2025-11-12","2025-12-10","2026-01-14","2026-02-11"])
const NFP_DATES = Date.(["2024-01-05","2024-02-02","2024-03-08","2024-04-05","2024-05-03","2024-06-07","2024-07-05","2024-08-02","2024-09-06","2024-10-04","2024-11-01","2024-12-06","2025-01-10","2025-02-07","2025-03-07","2025-04-04","2025-05-02","2025-06-06","2025-07-03","2025-08-01","2025-09-05","2025-10-03","2025-11-07","2025-12-05","2026-01-09","2026-02-06"])
const ALL_EVENT_DATES = sort(unique(vcat(FOMC_DATES, CPI_DATES, NFP_DATES)))

# ═══════════════════════════════════════════════════════════════════════════════
# 5a. Placebo Test
# ═══════════════════════════════════════════════════════════════════════════════

function exp5a_placebo(ws::DataFrame, edges::DataFrame; n_placebo=100)
    println("\n── 5a: Placebo Test ($n_placebo iterations) ──"); flush(stdout)

    # Real classification
    real_counts = classify_with_dates(ws, edges, ALL_EVENT_DATES)

    # Date range for random dates
    min_date = minimum(ws.start_date)
    max_date = maximum(ws.end_date)
    n_events = length(ALL_EVENT_DATES)
    date_range = Dates.value(max_date - min_date)

    rng = MersenneTwister(42)
    placebo_genuine = Int[]
    placebo_common = Int[]

    for iter in 1:n_placebo
        # Generate random event dates
        random_dates = [min_date + Day(rand(rng, 0:date_range)) for _ in 1:n_events]
        random_dates = sort(unique(random_dates))

        counts = classify_with_dates(ws, edges, random_dates)
        push!(placebo_genuine, counts[:genuine])
        push!(placebo_common, counts[:common_shock])
    end

    # Compare
    real_g = real_counts[:genuine]
    real_c = real_counts[:common_shock]
    p_genuine = mean(placebo_genuine .>= real_g)
    p_common = mean(placebo_common .<= real_c)

    println("  Real events: genuine=$(real_g), common_shock=$(real_c)")
    println("  Placebo (mean): genuine=$(round(mean(placebo_genuine), digits=1)), common_shock=$(round(mean(placebo_common), digits=1))")
    println("  Placebo p-value (genuine ≥ real): $(round(p_genuine, digits=3))")
    println("  Placebo p-value (common_shock ≤ real): $(round(p_common, digits=3))")

    if p_genuine < 0.05
        println("  ✓ Real events produce significantly MORE genuine edges than random dates")
    else
        println("  ○ Genuine edge count not significantly different from placebo")
    end
    if p_common < 0.05
        println("  ✓ Real events produce significantly FEWER common-shock edges than random dates")
    else
        println("  ○ Common-shock edge count not significantly different from placebo")
    end
    flush(stdout)

    return (real_genuine=real_g, real_common=real_c,
            placebo_genuine_mean=round(mean(placebo_genuine), digits=1),
            placebo_common_mean=round(mean(placebo_common), digits=1),
            p_genuine=round(p_genuine, digits=4),
            p_common=round(p_common, digits=4))
end

function classify_with_dates(ws, edges, event_dates)
    # Simplified Exp 1 classification with given event dates
    event_set = Set(event_dates)

    # Count events per window
    n_events = [count(d -> r.start_date <= d <= r.end_date, event_dates) for r in eachrow(ws)]
    med = median(n_events)
    regime = [n > med ? "high" : "low" for n in n_events]
    date_regime = Dict(ws.start_date[i] => regime[i] for i in 1:nrow(ws))

    edge_pairs = unique(select(edges, :source, :target))
    counts = Dict(:genuine => 0, :common_shock => 0, :quiet_only => 0, :noise => 0, :other => 0)

    for row in eachrow(edge_pairs)
        pair_edges = filter(r -> r.source == row.source && r.target == row.target, edges)
        high = count(r -> get(date_regime, r.start_date, "") == "high", eachrow(pair_edges))
        low = count(r -> get(date_regime, r.start_date, "") == "low", eachrow(pair_edges))
        n = nrow(pair_edges)

        cls = if n <= 1; :noise
        elseif high >= 2 && low <= 1; :common_shock
        elseif low >= 2 && high <= 1; :quiet_only
        elseif high >= 2 && low >= 2; :genuine
        else; :other
        end
        counts[cls] += 1
    end
    return counts
end

# ═══════════════════════════════════════════════════════════════════════════════
# 5b. Window Length Sensitivity (re-run TE pipeline)
# ═══════════════════════════════════════════════════════════════════════════════

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
        # Forward-fill
        last_val = NaN
        for j in 1:T
            if !isnan(L[i, j]); last_val = L[i, j]
            elseif !isnan(last_val); L[i, j] = last_val
            end
        end
        last_val = NaN
        for j in T:-1:1
            if !isnan(L[i, j]); last_val = L[i, j]
            elseif !isnan(last_val); L[i, j] = last_val
            end
        end
    end

    return L, families, all_ts, has_obs
end

function run_te_with_window(L, families, timestamps, has_obs, window_days; alpha=0.01)
    N_total, T_total = size(L)
    dates = Date.(timestamps)

    family_obs_days = Dict{Int, Set{Date}}()
    for i in 1:N_total
        obs = Set{Date}()
        for j in 1:T_total
            has_obs[i, j] && push!(obs, dates[j])
        end
        family_obs_days[i] = obs
    end

    # Phase 1: Pre-generate all valid windows
    date_set = sort(unique(dates))
    w_start = date_set[1]
    w_end_max = date_set[end]

    tasks = []
    while w_start + Day(window_days) <= w_end_max
        w_end = w_start + Day(window_days)

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
                push!(tasks, L_w)
            end
        end
        w_start += Day(STEP_DAYS)
    end

    n_tasks = length(tasks)

    # Phase 2: Process all windows in parallel
    edge_counts = Vector{Int}(undef, n_tasks)
    density_vals = Vector{Float64}(undef, n_tasks)

    Threads.@threads for k in 1:n_tasks
        L_w = tasks[k]
        N_w, T_w = size(L_w)
        rng = MersenneTwister(42 + k)
        n_edges = 0
        for i in 1:N_w, j in 1:N_w
            i == j && continue
            try
                _, p_val = TEEstimation.permutation_test(
                    L_w[i, :], L_w[j, :], VAR_LAG; n_perms=N_PERMS, rng=rng)
                p_val < alpha && (n_edges += 1)
            catch; end
        end
        edge_counts[k] = n_edges
        density_vals[k] = n_edges / (N_w * (N_w - 1))
    end

    total_edges = sum(edge_counts)
    avg_density = isempty(density_vals) ? 0.0 : mean(density_vals)
    return (n_windows=n_tasks, total_edges=total_edges,
            avg_density=round(100*avg_density, digits=2))
end

function exp5b_window_sensitivity()
    println("\n── 5b: Window Length Sensitivity ──"); flush(stdout)
    println("  Loading logit matrix..."); flush(stdout)
    L, families, timestamps, has_obs = load_logit_matrix()
    println("  Matrix: $(length(families)) families × $(length(timestamps)) bars"); flush(stdout)

    results = NamedTuple[]
    for wd in [45, 60, 90]
        println("  Running $(wd)d windows (this takes a few minutes)..."); flush(stdout)
        r = run_te_with_window(L, families, timestamps, has_obs, wd)
        println("    $(wd)d: $(r.n_windows) windows, $(r.total_edges) edges, avg density=$(r.avg_density)%")
        push!(results, (window_days=wd, n_windows=r.n_windows,
                        total_edges=r.total_edges, avg_density=r.avg_density))
    end
    flush(stdout)
    return DataFrame(results)
end

# ═══════════════════════════════════════════════════════════════════════════════
# 5c. α Threshold Sensitivity
# ═══════════════════════════════════════════════════════════════════════════════

function exp5c_alpha_sensitivity(edges::DataFrame)
    println("\n── 5c: α Threshold Sensitivity ──"); flush(stdout)

    # Re-threshold existing p-values at different α levels
    results = NamedTuple[]
    for alpha in [0.001, 0.005, 0.01, 0.02, 0.05, 0.10]
        sig_edges = filter(r -> r.p_value < alpha, edges)
        n_edges = nrow(sig_edges)
        unique_pairs = nrow(unique(select(sig_edges, :source, :target)))
        println("    α=$(lpad(alpha, 5)): $(n_edges) edge instances, $(unique_pairs) unique edges")
        push!(results, (alpha=alpha, n_instances=n_edges, n_unique=unique_pairs))
    end
    flush(stdout)
    return DataFrame(results)
end

# ═══════════════════════════════════════════════════════════════════════════════
# 5d. Half-Sample Stability
# ═══════════════════════════════════════════════════════════════════════════════

function exp5d_half_sample(ws::DataFrame, edges::DataFrame)
    println("\n── 5d: Half-Sample Stability ──"); flush(stdout)

    # Split by time
    sorted_dates = sort(unique(ws.start_date))
    mid_idx = div(length(sorted_dates), 2)
    mid_date = sorted_dates[mid_idx]

    first_half_dates = Set(filter(d -> d <= mid_date, sorted_dates))
    second_half_dates = Set(filter(d -> d > mid_date, sorted_dates))

    println("  Split at $mid_date")
    println("  First half: $(length(first_half_dates)) window dates")
    println("  Second half: $(length(second_half_dates)) window dates")

    # Edges in each half
    e1 = filter(r -> r.start_date in first_half_dates, edges)
    e2 = filter(r -> r.start_date in second_half_dates, edges)

    pairs1 = Set(zip(e1.source, e1.target))
    pairs2 = Set(zip(e2.source, e2.target))

    both = intersect(pairs1, pairs2)
    only1 = setdiff(pairs1, pairs2)
    only2 = setdiff(pairs2, pairs1)

    stability = length(both) / max(length(union(pairs1, pairs2)), 1)

    println("  First half unique edges: $(length(pairs1))")
    println("  Second half unique edges: $(length(pairs2))")
    println("  Overlap (both halves): $(length(both))")
    println("  Only first half: $(length(only1))")
    println("  Only second half: $(length(only2))")
    println("  Jaccard stability: $(round(stability, digits=3))")

    # Persistence correlation
    all_pairs = union(pairs1, pairs2)
    pers1 = Dict{Tuple, Int}()
    pers2 = Dict{Tuple, Int}()
    for r in eachrow(e1)
        k = (r.source, r.target)
        pers1[k] = get(pers1, k, 0) + 1
    end
    for r in eachrow(e2)
        k = (r.source, r.target)
        pers2[k] = get(pers2, k, 0) + 1
    end

    p1_vec = [get(pers1, p, 0) for p in all_pairs]
    p2_vec = [get(pers2, p, 0) for p in all_pairs]

    if length(p1_vec) > 2
        corr = cor(Float64.(p1_vec), Float64.(p2_vec))
        println("  Persistence rank correlation: $(round(corr, digits=3))")
    end

    # Composition-adjusted: only compare edges between nodes active in BOTH halves
    w1 = filter(r -> r.start_date in first_half_dates, ws)
    w2 = filter(r -> r.start_date in second_half_dates, ws)
    nodes1 = Set{String}()
    nodes2 = Set{String}()
    for r in eachrow(w1)
        for n in split(r.nodes, ";")
            push!(nodes1, n)
        end
    end
    for r in eachrow(w2)
        for n in split(r.nodes, ";")
            push!(nodes2, n)
        end
    end
    common_nodes = intersect(nodes1, nodes2)
    println("\n  Composition-adjusted ($(length(common_nodes)) shared nodes):")

    adj_pairs1 = Set(filter(p -> p[1] in common_nodes && p[2] in common_nodes, collect(pairs1)))
    adj_pairs2 = Set(filter(p -> p[1] in common_nodes && p[2] in common_nodes, collect(pairs2)))
    adj_both = intersect(adj_pairs1, adj_pairs2)
    adj_stability = length(adj_both) / max(length(union(adj_pairs1, adj_pairs2)), 1)

    println("  Adjusted first half: $(length(adj_pairs1)) edges")
    println("  Adjusted second half: $(length(adj_pairs2)) edges")
    println("  Adjusted overlap: $(length(adj_both))")
    println("  Adjusted Jaccard: $(round(adj_stability, digits=3))")

    # Adjusted persistence correlation
    adj_all = union(adj_pairs1, adj_pairs2)
    if length(adj_all) > 2
        ap1 = [get(pers1, p, 0) for p in adj_all]
        ap2 = [get(pers2, p, 0) for p in adj_all]
        adj_corr = cor(Float64.(ap1), Float64.(ap2))
        println("  Adjusted rank correlation: $(round(adj_corr, digits=3))")
    end
    flush(stdout)

    return (n_first=length(pairs1), n_second=length(pairs2),
            n_overlap=length(both), jaccard=round(stability, digits=4),
            adj_jaccard=round(adj_stability, digits=4))
end

# ═══════════════════════════════════════════════════════════════════════════════
# Main
# ═══════════════════════════════════════════════════════════════════════════════

function main()
    println("=" ^ 70)
    println("PM-TE-Network: Experiment 5 — Placebo & Robustness")
    println("  Threads: $(Threads.nthreads())")
    println("=" ^ 70); flush(stdout)

    ws = CSV.read("data/results/window_summary.csv", DataFrame)
    edges = CSV.read("data/results/edge_list.csv", DataFrame)
    ws.start_date = Date.(ws.start_date)
    ws.end_date = Date.(ws.end_date)
    edges.start_date = Date.(edges.start_date)
    println("Loaded: $(nrow(ws)) windows, $(nrow(edges)) edges"); flush(stdout)

    # 5a: Placebo (1000 iterations for power)
    placebo = exp5a_placebo(ws, edges; n_placebo=1000)

    # 5c: α sensitivity (run before 5b since 5b is slow)
    alpha_results = exp5c_alpha_sensitivity(edges)
    CSV.write("data/results/exp5_alpha_sensitivity.csv", alpha_results)
    println("\nSaved: data/results/exp5_alpha_sensitivity.csv")

    # 5d: Half-sample
    half_sample = exp5d_half_sample(ws, edges)

    # 5b: Window sensitivity (SLOW — re-runs TE pipeline)
    println("\n  ⚠ 5b requires re-running TE pipeline with different window sizes.")
    println("  This will take ~10 minutes total (45d + 60d + 90d).")
    flush(stdout)
    window_results = exp5b_window_sensitivity()
    CSV.write("data/results/exp5_window_sensitivity.csv", window_results)
    println("\nSaved: data/results/exp5_window_sensitivity.csv")

    # Summary
    println("\n" * "=" ^ 70)
    println("ROBUSTNESS SUMMARY")
    println("=" ^ 70)
    println("\n5a Placebo: genuine edges p=$(placebo.p_genuine) ($(placebo.p_genuine < 0.05 ? "significant" : "not significant"))")
    println("5b Window sensitivity:")
    for r in eachrow(window_results)
        println("    $(r.window_days)d: $(r.n_windows) windows, $(r.total_edges) edges, density=$(r.avg_density)%")
    end
    println("5c α sensitivity:")
    for r in eachrow(alpha_results)
        println("    α=$(r.alpha): $(r.n_unique) unique edges")
    end
    println("5d Half-sample: Jaccard=$(half_sample.jaccard), overlap=$(half_sample.n_overlap)")
    println("=" ^ 70); flush(stdout)
end

main()
