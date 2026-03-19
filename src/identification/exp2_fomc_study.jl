"""
Identification Experiment 2: FOMC Event-Study

For each FOMC date, analyze TE edge behavior in nearby rolling windows:
  - Pre-FOMC: windows ending within 10 days before announcement
  - Post-FOMC: windows starting within 10 days after announcement
  - Baseline: all other windows

Classify edges by temporal pattern around FOMC announcements:
  - info_leader: higher TE pre-FOMC (anticipatory information flow)
  - common_shock_responder: higher TE post-FOMC (differential reaction)
  - persistent: similar TE in both periods (structural channel)
  - event_catalyzed: TE appears mainly near FOMC (dormant otherwise)

Usage:
  julia src/identification/exp2_fomc_study.jl
"""

using CSV, DataFrames, Dates, Statistics, Random

# ═══════════════════════════════════════════════════════════════════════════════
# FOMC dates (same as experiments.jl)
# ═══════════════════════════════════════════════════════════════════════════════

const FOMC_DATES = Date.([
    "2024-01-31", "2024-03-20", "2024-05-01", "2024-06-12",
    "2024-07-31", "2024-09-18", "2024-11-07", "2024-12-18",
    "2025-01-29", "2025-03-19", "2025-05-07", "2025-06-18",
    "2025-07-30", "2025-09-17", "2025-10-29", "2025-12-17",
    "2026-01-28", "2026-03-18",
])

const PROXIMITY_DAYS = 10  # ±10 days around FOMC

# ═══════════════════════════════════════════════════════════════════════════════
# Load data
# ═══════════════════════════════════════════════════════════════════════════════

function load_data()
    ws = CSV.read("data/results/window_summary.csv", DataFrame)
    edges = CSV.read("data/results/edge_list.csv", DataFrame)
    ws.start_date = Date.(ws.start_date)
    ws.end_date = Date.(ws.end_date)
    edges.start_date = Date.(edges.start_date)
    return ws, edges
end

# ═══════════════════════════════════════════════════════════════════════════════
# Tag windows by FOMC proximity
# ═══════════════════════════════════════════════════════════════════════════════

function tag_fomc_windows(ws::DataFrame)
    n = nrow(ws)
    nearest_fomc = Vector{Date}(undef, n)
    fomc_distance = Vector{Int}(undef, n)
    fomc_phase = Vector{String}(undef, n)

    for idx in 1:n
        w_mid = ws.start_date[idx] + Day(div(Dates.value(ws.end_date[idx] - ws.start_date[idx]), 2))

        min_dist = typemax(Int)
        nearest = Date("2020-01-01")
        for fd in FOMC_DATES
            d = abs(Dates.value(w_mid - fd))
            if d < min_dist
                min_dist = d
                nearest = fd
            end
        end

        nearest_fomc[idx] = nearest
        fomc_distance[idx] = min_dist

        days_from_fomc = Dates.value(w_mid - nearest)
        if abs(days_from_fomc) <= PROXIMITY_DAYS
            if days_from_fomc < 0
                fomc_phase[idx] = "pre_fomc"
            elseif days_from_fomc > 0
                fomc_phase[idx] = "post_fomc"
            else
                fomc_phase[idx] = "fomc_day"
            end
        else
            fomc_phase[idx] = "baseline"
        end
    end

    ws.nearest_fomc = nearest_fomc
    ws.fomc_distance = fomc_distance
    ws.fomc_phase = fomc_phase
    return ws
end

# ═══════════════════════════════════════════════════════════════════════════════
# Per-FOMC event analysis
# ═══════════════════════════════════════════════════════════════════════════════

function per_fomc_analysis(ws::DataFrame, edges::DataFrame)
    println("\n── Per-FOMC Event Analysis ──"); flush(stdout)

    results = NamedTuple[]
    date_set = Set(ws.start_date)

    for fd in FOMC_DATES
        # Find windows near this FOMC
        near_windows = filter(r -> abs(Dates.value(
            (r.start_date + Day(div(Dates.value(r.end_date - r.start_date), 2))) - fd
        )) <= PROXIMITY_DAYS, ws)

        nrow(near_windows) == 0 && continue

        # Edges in near-FOMC windows
        near_dates = Set(near_windows.start_date)
        near_edges = filter(r -> r.start_date in near_dates, edges)

        n_windows = nrow(near_windows)
        n_edges = nrow(near_edges)
        unique_edges = nrow(unique(select(near_edges, :source, :target)))
        avg_density = n_windows > 0 ? round(mean(near_windows.density), digits=4) : 0.0

        push!(results, (
            fomc_date = fd,
            n_windows = n_windows,
            n_edge_instances = n_edges,
            n_unique_edges = unique_edges,
            avg_density = avg_density,
            avg_N = n_windows > 0 ? round(mean(near_windows.N), digits=1) : 0.0,
        ))

        println("  FOMC $fd: $n_windows windows, $unique_edges unique edges, density=$(round(100*avg_density, digits=1))%")
    end
    flush(stdout)
    return DataFrame(results)
end

# ═══════════════════════════════════════════════════════════════════════════════
# Edge classification by FOMC temporal pattern
# ═══════════════════════════════════════════════════════════════════════════════

function classify_fomc_edges(ws::DataFrame, edges::DataFrame)
    println("\n── FOMC Edge Classification ──"); flush(stdout)

    # Map window start_date → fomc_phase
    phase_map = Dict(r.start_date => r.fomc_phase for r in eachrow(ws))

    # Tag each edge instance
    edges.fomc_phase = [get(phase_map, d, "unknown") for d in edges.start_date]

    # Get unique directed edges
    edge_pairs = unique(select(edges, :source, :target))
    results = NamedTuple[]

    for row in eachrow(edge_pairs)
        src, tgt = row.source, row.target
        pair_edges = filter(r -> r.source == src && r.target == tgt, edges)

        pre = filter(r -> r.fomc_phase == "pre_fomc", pair_edges)
        post = filter(r -> r.fomc_phase == "post_fomc", pair_edges)
        day_of = filter(r -> r.fomc_phase == "fomc_day", pair_edges)
        baseline = filter(r -> r.fomc_phase == "baseline", pair_edges)

        n_pre = nrow(pre)
        n_post = nrow(post)
        n_day = nrow(day_of)
        n_baseline = nrow(baseline)
        n_near = n_pre + n_post + n_day
        n_total = nrow(pair_edges)

        mean_te_pre = n_pre > 0 ? mean(pre.te_value) : 0.0
        mean_te_post = n_post > 0 ? mean(post.te_value) : 0.0
        mean_te_near = n_near > 0 ? mean(vcat(pre.te_value, post.te_value, day_of.te_value)) : 0.0
        mean_te_baseline = n_baseline > 0 ? mean(baseline.te_value) : 0.0

        # Count total windows in each phase for rate computation
        n_pre_windows = count(==("pre_fomc"), ws.fomc_phase)
        n_post_windows = count(==("post_fomc"), ws.fomc_phase)
        n_baseline_windows = count(==("baseline"), ws.fomc_phase)

        rate_pre = n_pre_windows > 0 ? n_pre / n_pre_windows : 0.0
        rate_post = n_post_windows > 0 ? n_post / n_post_windows : 0.0
        rate_baseline = n_baseline_windows > 0 ? n_baseline / n_baseline_windows : 0.0

        # Classification
        fomc_ratio = rate_baseline > 0 ? (rate_pre + rate_post) / (2 * rate_baseline) : Inf
        pre_post_ratio = (rate_pre + 0.01) / (rate_post + 0.01)

        classification = if n_total <= 2
            "insufficient_data"
        elseif n_near == 0 && n_baseline >= 2
            "fomc_independent"  # never appears near FOMC
        elseif n_baseline == 0 && n_near >= 2
            "event_catalyzed"   # only near FOMC
        elseif fomc_ratio > 1.5 && pre_post_ratio > 1.5
            "info_leader"       # concentrated pre-FOMC
        elseif fomc_ratio > 1.5 && pre_post_ratio < 0.67
            "common_shock_responder"  # concentrated post-FOMC
        elseif fomc_ratio > 1.5
            "event_catalyzed"   # concentrated near FOMC (both pre and post)
        elseif abs(fomc_ratio - 1.0) < 0.3
            "persistent"        # similar rate near and far from FOMC
        else
            "fomc_independent"
        end

        push!(results, (
            source = src, target = tgt,
            persistence = n_total,
            n_pre_fomc = n_pre, n_post_fomc = n_post, n_fomc_day = n_day,
            n_baseline = n_baseline,
            rate_pre = round(rate_pre, digits=4),
            rate_post = round(rate_post, digits=4),
            rate_baseline = round(rate_baseline, digits=4),
            mean_te_pre = round(mean_te_pre, digits=6),
            mean_te_post = round(mean_te_post, digits=6),
            mean_te_baseline = round(mean_te_baseline, digits=6),
            fomc_ratio = round(fomc_ratio, digits=3),
            pre_post_ratio = round(pre_post_ratio, digits=3),
            exp2_class = classification,
        ))
    end

    df = DataFrame(results)
    sort!(df, :persistence, rev=true)

    # Summary
    println("\n  Classification summary:")
    for cls in sort(unique(df.exp2_class))
        n = count(==(cls), df.exp2_class)
        println("    $cls: $n edges")
    end
    flush(stdout)

    return df
end

# ═══════════════════════════════════════════════════════════════════════════════
# Main
# ═══════════════════════════════════════════════════════════════════════════════

function main()
    println("=" ^ 70)
    println("PM-TE-Network: Experiment 2 — FOMC Event-Study")
    println("  FOMC dates: $(length(FOMC_DATES))")
    println("  Proximity window: ±$(PROXIMITY_DAYS) days")
    println("=" ^ 70); flush(stdout)

    ws, edges = load_data()
    println("Loaded: $(nrow(ws)) windows, $(nrow(edges)) edges")

    # Tag windows
    ws = tag_fomc_windows(ws)
    for phase in ["pre_fomc", "fomc_day", "post_fomc", "baseline"]
        n = count(==(phase), ws.fomc_phase)
        println("  $phase: $n windows")
    end
    flush(stdout)

    # Per-FOMC analysis
    fomc_summary = per_fomc_analysis(ws, edges)
    CSV.write("data/results/exp2_fomc_summary.csv", fomc_summary)
    println("\nSaved: data/results/exp2_fomc_summary.csv")

    # Edge classification
    classified = classify_fomc_edges(ws, edges)
    CSV.write("data/results/exp2_fomc_edges.csv", classified)
    println("Saved: data/results/exp2_fomc_edges.csv ($(nrow(classified)) edges)")

    # Top info leaders
    leaders = filter(r -> r.exp2_class == "info_leader", classified)
    if nrow(leaders) > 0
        sort!(leaders, :persistence, rev=true)
        println("\n── Top Info Leaders (pre-FOMC signal) ──")
        for r in eachrow(first(leaders, 10))
            println("  $(r.source) → $(r.target): pers=$(r.persistence), rate_pre=$(r.rate_pre), rate_baseline=$(r.rate_baseline)")
        end
    end

    # Top common shock responders
    responders = filter(r -> r.exp2_class == "common_shock_responder", classified)
    if nrow(responders) > 0
        sort!(responders, :persistence, rev=true)
        println("\n── Top Common Shock Responders (post-FOMC reaction) ──")
        for r in eachrow(first(responders, 10))
            println("  $(r.source) → $(r.target): pers=$(r.persistence), rate_post=$(r.rate_post), rate_baseline=$(r.rate_baseline)")
        end
    end

    println("\n" * "=" ^ 70); flush(stdout)
end

main()
