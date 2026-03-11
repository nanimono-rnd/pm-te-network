"""
Rolling Window VAR(1) Transfer Entropy Network — Kalshi Composite Nodes

Pipeline:
  1. Load candlestick data + classify tickers by SERIES_FAMILY_MAP
  2. Compute composite nodes (time-to-resolution weighted, 4h resolution)
  3. Logit transform
  4. Align to common 4h grid
  5. Rolling windows (60 days, step=1 day, ≥30 active days filter)
  6. Per-window: VAR(1) TE + permutation test (200 shuffles, α=0.01)
  7. Output: adjacency matrices, edge list, density, asymmetry ratio

Usage:
  julia -t auto src/main_kalshi_te.jl
"""

include(joinpath(@__DIR__, "data", "macro_filter.jl"))
include(joinpath(@__DIR__, "estimation", "te.jl"))

using .MacroFilter, .TEEstimation
using CSV, DataFrames, Dates, Statistics, LinearAlgebra, JSON3, Random

# ═══════════════════════════════════════════════════════════════════════════════
# Configuration
# ═══════════════════════════════════════════════════════════════════════════════

const WINDOW_DAYS   = 60
const STEP_DAYS     = 1
const MIN_ACTIVE    = 30    # min distinct active DAYS per node in window
const MIN_N_PRIMARY = 8     # N≥8 = primary analysis regime
const VAR_LAG       = 1     # fixed VAR(1)
const N_PERMS       = 200
const ALPHA         = 0.01
const LOGIT_EPS     = 0.01

# ═══════════════════════════════════════════════════════════════════════════════
# Step 1: Load candlestick data & classify tickers
# ═══════════════════════════════════════════════════════════════════════════════

function load_and_classify()
    println("[1/7] Loading candlestick data..."); flush(stdout)
    candles = CSV.read("data/candlesticks_4h.csv", DataFrame)
    candles.datetime = DateTime.(candles.datetime, dateformat"yyyy-mm-dd HH:MM:SS")
    println("  $(nrow(candles)) bars, $(length(unique(candles.ticker))) tickers"); flush(stdout)

    # Extract series prefix and classify
    candles.series_prefix = [split(t, '-')[1] for t in candles.ticker]
    candles.family = [get(MacroFilter.SERIES_FAMILY_MAP, p, "unclassified")
                      for p in candles.series_prefix]

    classified = filter(r -> r.family != "unclassified", candles)
    families = sort(unique(classified.family))
    println("  Classified: $(nrow(classified)) bars → $(length(families)) families"); flush(stdout)
    for f in families
        n = count(==(f), classified.family)
        nt = length(unique(filter(r -> r.family == f, classified).ticker))
        println("    $f: $nt tickers, $n bars")
    end
    flush(stdout)

    return classified, families
end

# ═══════════════════════════════════════════════════════════════════════════════
# Step 2: Compute composite nodes (time-to-resolution weighted, 4h bars)
# ═══════════════════════════════════════════════════════════════════════════════

function compute_composites(classified, families)
    println("\n[2/7] Computing composite nodes (4h resolution)..."); flush(stdout)
    composites = Dict{String, DataFrame}()

    for family in families
        fdata = filter(r -> r.family == family, classified)
        nrow(fdata) == 0 && continue

        # Infer end_date per ticker
        end_dates = combine(groupby(fdata, :ticker), :datetime => maximum => :end_date)
        fdata = leftjoin(fdata, end_dates, on=:ticker)

        # days_to_resolution (DateTime difference → milliseconds → days)
        fdata.days_to_res = [max(Dates.value(r.end_date - r.datetime) ÷ (1000*60*60*24), 0)
                             for r in eachrow(fdata)]

        # Skip last 7 days (mechanical convergence)
        fdata = filter(r -> r.days_to_res > 7, fdata)
        nrow(fdata) == 0 && continue

        # Weight: 1/sqrt(days_to_res)
        fdata.weight = [1.0 / sqrt(max(d, 1)) for d in fdata.days_to_res]

        # Weighted average at each 4h timestamp
        comp = combine(groupby(fdata, :datetime)) do df
            (price = sum(df.weight .* df.price) / sum(df.weight),)
        end
        sort!(comp, :datetime)

        if nrow(comp) > 0
            composites[family] = comp
            n_days = length(unique(Date.(comp.datetime)))
            date_range = Date(minimum(comp.datetime)), Date(maximum(comp.datetime))
            println("  $family: $(nrow(comp)) bars, $n_days days ($(date_range[1]) → $(date_range[2]))")
        end
    end

    println("  → $(length(composites)) composite nodes"); flush(stdout)
    return composites
end

# ═══════════════════════════════════════════════════════════════════════════════
# Step 3: Logit transform + align to common 4h grid → N×T matrix
# ═══════════════════════════════════════════════════════════════════════════════

function logit(p::Float64)
    p_clipped = clamp(p / 100.0, LOGIT_EPS, 1.0 - LOGIT_EPS)
    return log(p_clipped / (1.0 - p_clipped))
end

function build_logit_matrix(composites)
    println("\n[3/7] Building 4h logit matrix..."); flush(stdout)
    family_names = sort(collect(keys(composites)))
    N = length(family_names)

    # Union of all 4h timestamps
    all_ts = sort(unique(vcat([composites[f].datetime for f in family_names]...)))
    T = length(all_ts)
    ts_idx = Dict(t => j for (j, t) in enumerate(all_ts))

    L = fill(NaN, N, T)

    # Track which (family, timestamp) had an original observation
    has_obs = falses(N, T)

    for (i, f) in enumerate(family_names)
        for row in eachrow(composites[f])
            j = ts_idx[row.datetime]
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
        # Backward-fill leading NaNs
        last_val = NaN
        for j in T:-1:1
            if !isnan(L[i, j]); last_val = L[i, j]
            elseif !isnan(last_val); L[i, j] = last_val
            end
        end
    end

    println("  Matrix: $N families × $T bars (4h)")
    println("  Date range: $(Date(all_ts[1])) → $(Date(all_ts[end]))")
    println("  Expected T per 60d window: ~$(60*6) bars")
    flush(stdout)

    return L, family_names, all_ts, has_obs
end

# ═══════════════════════════════════════════════════════════════════════════════
# Step 4-6: Rolling windows → parallel TE estimation → metrics
# ═══════════════════════════════════════════════════════════════════════════════

function run_rolling_te(L, family_names, timestamps, has_obs)
    N_total, T_total = size(L)
    dates = Date.(timestamps)
    n_threads = Threads.nthreads()

    println("\n[4/7] Generating rolling windows...")
    println("  Window: $(WINDOW_DAYS)d, step: $(STEP_DAYS)d, min_active: $(MIN_ACTIVE) days")
    println("  Resolution: 4h bars")
    println("  Threads: $n_threads")
    flush(stdout)

    # Precompute: for each family, which DAYS have at least one 4h observation?
    family_obs_days = Dict{Int, Set{Date}}()
    for i in 1:N_total
        obs = Set{Date}()
        for j in 1:T_total
            has_obs[i, j] && push!(obs, dates[j])
        end
        family_obs_days[i] = obs
    end

    # ── Phase 1: Pre-generate all valid windows (sequential, fast) ──────────
    date_set = sort(unique(dates))
    w_start = date_set[1]
    w_end_max = date_set[end]

    tasks = NamedTuple{(:w_idx, :w_start, :w_end, :L_w, :active_families),
                       Tuple{Int, Date, Date, Matrix{Float64}, Vector{Int}}}[]
    w_idx = 0
    n_skipped = 0

    while w_start + Day(WINDOW_DAYS) <= w_end_max
        w_end = w_start + Day(WINDOW_DAYS)
        w_idx += 1

        # Filter families with ≥MIN_ACTIVE distinct DAYS in this window
        active_families = Int[]
        for i in 1:N_total
            active_days = count(d -> w_start <= d <= w_end, family_obs_days[i])
            active_days >= MIN_ACTIVE && push!(active_families, i)
        end

        if length(active_families) < 3
            n_skipped += 1
            w_start += Day(STEP_DAYS)
            continue
        end

        # Extract sub-matrix for this window (all 4h bars within the date range)
        col_mask = [w_start <= dates[j] <= w_end for j in 1:T_total]
        L_w = L[active_families, col_mask]
        N_w, T_w = size(L_w)

        # Drop columns with any NaN
        valid_cols = [all(!isnan, L_w[:, j]) for j in 1:T_w]
        L_w = L_w[:, valid_cols]
        N_w, T_w = size(L_w)

        if T_w < 30 || N_w < 3
            n_skipped += 1
            w_start += Day(STEP_DAYS)
            continue
        end

        push!(tasks, (w_idx=w_idx, w_start=w_start, w_end=w_end,
                      L_w=L_w, active_families=active_families))
        w_start += Day(STEP_DAYS)
    end

    n_tasks = length(tasks)
    println("  Generated $n_tasks valid windows ($n_skipped skipped)")
    flush(stdout)

    # ── Phase 2: Process all windows in parallel ────────────────────────────
    println("\n[5/7] Estimating TE networks ($n_tasks windows × $n_threads threads)...")
    flush(stdout)

    # Pre-allocate result storage (one slot per window)
    result_summaries = Vector{NamedTuple}(undef, n_tasks)
    result_edges = Vector{Vector{NamedTuple}}(undef, n_tasks)
    result_adj = Vector{Tuple{Int, Matrix{Float64}, Vector{String}}}(undef, n_tasks)

    done_count = Threads.Atomic{Int}(0)
    progress_lock = ReentrantLock()

    Threads.@threads for k in 1:n_tasks
        task = tasks[k]
        rng = MersenneTwister(42 + k)  # reproducible, independent per task

        w_idx_k = task.w_idx
        w_start_k = task.w_start
        w_end_k = task.w_end
        L_w = task.L_w
        active_fam = task.active_families
        N_w, T_w = size(L_w)

        # ── TE estimation for this window ──────────────────────────────
        A = zeros(N_w, N_w)
        TE_mat = zeros(N_w, N_w)
        P_mat = ones(N_w, N_w)

        for i in 1:N_w
            for j in 1:N_w
                i == j && continue
                try
                    te_val, p_val = TEEstimation.permutation_test(
                        L_w[i, :], L_w[j, :], VAR_LAG; n_perms=N_PERMS, rng=rng)
                    TE_mat[i, j] = te_val
                    P_mat[i, j] = p_val
                    A[i, j] = p_val < ALPHA ? 1.0 : 0.0
                catch
                    # Singular matrix (constant series) → no TE
                end
            end
        end

        # ── Metrics ────────────────────────────────────────────────────
        n_edges = Int(sum(A))
        density = n_edges / (N_w * (N_w - 1))

        n_bidir = 0
        for i in 1:N_w, j in (i+1):N_w
            if A[i, j] == 1.0 && A[j, i] == 1.0
                n_bidir += 1
            end
        end
        asym = n_edges > 0 ? 1.0 - 2.0 * n_bidir / n_edges : NaN

        w_families = family_names[active_fam]
        regime = N_w >= MIN_N_PRIMARY ? "primary" : "secondary"

        # Store summary
        result_summaries[k] = (
            window_idx   = w_idx_k,
            start_date   = w_start_k,
            end_date     = w_end_k,
            N            = N_w,
            T            = T_w,
            T_N_ratio    = round(T_w / N_w, digits=1),
            n_edges      = n_edges,
            density      = round(density, digits=4),
            asymmetry    = round(asym, digits=4),
            regime       = regime,
            nodes        = join(w_families, ";"),
        )

        # Store edges
        edges_k = NamedTuple[]
        for i in 1:N_w, j in 1:N_w
            A[i, j] == 1.0 || continue
            push!(edges_k, (
                window_idx = w_idx_k,
                start_date = w_start_k,
                source     = w_families[j],
                target     = w_families[i],
                te_value   = round(TE_mat[i, j], digits=6),
                p_value    = round(P_mat[i, j], digits=4),
            ))
        end
        result_edges[k] = edges_k

        # Store adjacency
        result_adj[k] = (w_idx_k, A, w_families)

        # Progress (thread-safe)
        Threads.atomic_add!(done_count, 1)
        d = done_count[]
        if d % 25 == 0 || d == n_tasks
            lock(progress_lock) do
                marker = regime == "primary" ? "●" : "○"
                pct = round(100 * d / n_tasks, digits=1)
                println("  [$d/$n_tasks $pct%] $marker W$(w_idx_k) ($w_start_k): N=$N_w T=$T_w edges=$n_edges den=$(round(100*density, digits=1))%")
                flush(stdout)
            end
        end
    end

    # ── Phase 3: Collect and sort results ───────────────────────────────────
    window_summaries = sort(collect(result_summaries), by=s -> s.window_idx)

    all_edges = NamedTuple[]
    for edges_k in result_edges
        append!(all_edges, edges_k)
    end

    adjacency_data = Dict{Int, Tuple{Matrix{Float64}, Vector{String}}}()
    for (w_idx_k, A, fams) in result_adj
        adjacency_data[w_idx_k] = (A, fams)
    end

    println("  → $(length(window_summaries)) windows estimated")
    flush(stdout)
    return window_summaries, all_edges, adjacency_data
end

# ═══════════════════════════════════════════════════════════════════════════════
# Step 7: Output
# ═══════════════════════════════════════════════════════════════════════════════

function save_results(composites, window_summaries, all_edges, adjacency_data)
    println("\n[7/7] Saving results..."); flush(stdout)

    mkpath("data/results/adjacency")

    # 1. Composites CSV (4h)
    rows = NamedTuple[]
    for (family, df) in composites
        for r in eachrow(df)
            push!(rows, (datetime=r.datetime, family=family,
                         price=round(r.price, digits=2),
                         logit_price=round(logit(r.price), digits=4)))
        end
    end
    CSV.write("data/results/composites.csv", DataFrame(rows))
    println("  data/results/composites.csv ($(length(rows)) rows)")

    # 2. Window summary
    if !isempty(window_summaries)
        CSV.write("data/results/window_summary.csv", DataFrame(window_summaries))
        println("  data/results/window_summary.csv ($(length(window_summaries)) windows)")
    end

    # 3. Edge list
    if !isempty(all_edges)
        CSV.write("data/results/edge_list.csv", DataFrame(all_edges))
        println("  data/results/edge_list.csv ($(length(all_edges)) edges)")
    else
        println("  data/results/edge_list.csv (no significant edges)")
    end

    # 4. Adjacency matrices
    n_saved = 0
    for (w_idx, (A, families)) in adjacency_data
        adj_df = DataFrame(A, families)
        insertcols!(adj_df, 1, :node => families)
        CSV.write("data/results/adjacency/window_$(lpad(w_idx, 4, '0')).csv", adj_df)
        n_saved += 1
    end
    println("  data/results/adjacency/ ($n_saved adjacency matrices)")
    flush(stdout)
end

# ═══════════════════════════════════════════════════════════════════════════════
# Main
# ═══════════════════════════════════════════════════════════════════════════════

function main()
    n_threads = Threads.nthreads()
    println("=" ^ 70)
    println("PM-TE-Network: Rolling Window VAR(1) TE Estimation")
    println("  Window=$(WINDOW_DAYS)d  Step=$(STEP_DAYS)d  MinActive=$(MIN_ACTIVE)d")
    println("  VAR lag=$VAR_LAG  Perms=$N_PERMS  α=$ALPHA")
    println("  Resolution: 4h bars  Primary regime: N≥$MIN_N_PRIMARY")
    println("  Threads: $n_threads  (launch with: julia -t auto)")
    if n_threads == 1
        println("  ⚠ WARNING: Running single-threaded! Use 'julia -t auto' for full CPU utilization.")
    end
    println("=" ^ 70)
    flush(stdout)

    classified, families = load_and_classify()
    composites = compute_composites(classified, families)
    L, family_names, timestamps, has_obs = build_logit_matrix(composites)
    window_summaries, all_edges, adjacency_data = run_rolling_te(L, family_names, timestamps, has_obs)
    save_results(composites, window_summaries, all_edges, adjacency_data)

    # Final summary
    println("\n" * "=" ^ 70)
    println("SUMMARY")
    println("=" ^ 70)
    println("Composite nodes: $(length(composites))")
    println("Windows estimated: $(length(window_summaries))")
    println("Threads used: $n_threads")
    if !isempty(window_summaries)
        ws = DataFrame(window_summaries)
        println("Total significant edges: $(length(all_edges))")

        for regime in ["primary", "secondary"]
            rs = filter(r -> r.regime == regime, ws)
            isempty(rs) && continue
            n_with_edges = count(>(0), rs.n_edges)
            pct_edges = round(100 * n_with_edges / nrow(rs), digits=1)
            valid_asym = filter(!isnan, rs.asymmetry)
            avg_asym = isempty(valid_asym) ? NaN : round(mean(valid_asym), digits=3)
            label = regime == "primary" ? "● PRIMARY (N≥$MIN_N_PRIMARY)" : "○ SECONDARY (N<$MIN_N_PRIMARY)"
            println("\n  $label: $(nrow(rs)) windows")
            println("    N range: $(minimum(rs.N))-$(maximum(rs.N))")
            println("    Avg T/N: $(round(mean(rs.T_N_ratio), digits=1))")
            println("    Windows w/ edges: $n_with_edges ($pct_edges%)")
            println("    Avg density: $(round(100*mean(rs.density), digits=2))%")
            println("    Avg edges/window: $(round(mean(rs.n_edges), digits=1))")
            !isnan(avg_asym) && println("    Avg asymmetry: $avg_asym")
            regime_edges = filter(r -> r.start_date in Set(rs.start_date), DataFrame(all_edges))
            if nrow(regime_edges) > 0
                src_counts = combine(groupby(regime_edges, :source), nrow => :n)
                sort!(src_counts, :n, rev=true)
                tgt_counts = combine(groupby(regime_edges, :target), nrow => :n)
                sort!(tgt_counts, :n, rev=true)
                println("    Top sources: ", join(["$(r.source)($(r.n))" for r in eachrow(first(src_counts, 3))], ", "))
                println("    Top targets: ", join(["$(r.target)($(r.n))" for r in eachrow(first(tgt_counts, 3))], ", "))
            end
        end
    end
    println("\n" * "=" ^ 70)
    flush(stdout)
end

main()
