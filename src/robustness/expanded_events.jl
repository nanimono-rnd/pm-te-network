"""
Robustness: Expanded Event Calendar

Re-run Experiment 1 classification with expanded event set including
tariff announcements and budget/shutdown deadlines.

Usage:
  julia src/robustness/expanded_events.jl
"""

using CSV, DataFrames, Dates, Statistics, Random

# ═══════════════════════════════════════════════════════════════════════════════
# Original event calendar
# ═══════════════════════════════════════════════════════════════════════════════

const FOMC_DATES = Date.(["2024-01-31","2024-03-20","2024-05-01","2024-06-12","2024-07-31","2024-09-18","2024-11-07","2024-12-18","2025-01-29","2025-03-19","2025-05-07","2025-06-18","2025-07-30","2025-09-17","2025-10-29","2025-12-17","2026-01-28","2026-03-18"])
const CPI_DATES = Date.(["2024-01-11","2024-02-13","2024-03-12","2024-04-10","2024-05-15","2024-06-12","2024-07-11","2024-08-14","2024-09-11","2024-10-10","2024-11-13","2024-12-11","2025-01-15","2025-02-12","2025-03-12","2025-04-10","2025-05-13","2025-06-11","2025-07-10","2025-08-12","2025-09-10","2025-10-14","2025-11-12","2025-12-10","2026-01-14","2026-02-11"])
const NFP_DATES = Date.(["2024-01-05","2024-02-02","2024-03-08","2024-04-05","2024-05-03","2024-06-07","2024-07-05","2024-08-02","2024-09-06","2024-10-04","2024-11-01","2024-12-06","2025-01-10","2025-02-07","2025-03-07","2025-04-04","2025-05-02","2025-06-06","2025-07-03","2025-08-01","2025-09-05","2025-10-03","2025-11-07","2025-12-05","2026-01-09","2026-02-06"])

# ═══════════════════════════════════════════════════════════════════════════════
# NEW: Tariff announcements and budget deadlines
# ═══════════════════════════════════════════════════════════════════════════════

# Key tariff announcements (executive orders, USTR announcements, tariff rate changes)
const TARIFF_DATES = Date.([
    "2025-02-01",   # Trump 25% tariff on Canada/Mexico, 10% on China
    "2025-02-04",   # Canada/Mexico tariff pause announced
    "2025-03-04",   # Tariffs reimposed on Canada/Mexico
    "2025-03-12",   # 25% steel/aluminum tariffs expanded
    "2025-04-02",   # "Liberation Day" reciprocal tariffs announced
    "2025-04-09",   # 90-day tariff pause (except China)
    "2025-05-12",   # US-China Geneva trade agreement (tariff reduction)
    "2025-05-20",   # EU tariff negotiations begin
    "2025-07-08",   # US-China tariff rate adjustment
    "2025-08-01",   # New tariff schedule effective date
    "2025-10-15",   # USTR tariff review announcement
    "2025-11-01",   # Tariff escalation on remaining imports
])

# Government shutdown / budget deadlines
const BUDGET_DATES = Date.([
    "2024-09-30",   # FY2024 end / CR deadline
    "2024-11-21",   # Continuing resolution extension
    "2024-12-20",   # Government shutdown deadline (averted)
    "2025-01-19",   # CR expiration
    "2025-03-14",   # Funding deadline
    "2025-03-28",   # Shutdown averted (6-month CR)
    "2025-09-30",   # FY2025 end
    "2025-12-20",   # CR expiration
])

const ORIGINAL_EVENTS = sort(unique(vcat(FOMC_DATES, CPI_DATES, NFP_DATES)))
const EXPANDED_EVENTS = sort(unique(vcat(ORIGINAL_EVENTS, TARIFF_DATES, BUDGET_DATES)))

# ═══════════════════════════════════════════════════════════════════════════════
# Classification (same logic as experiments.jl Exp 1)
# ═══════════════════════════════════════════════════════════════════════════════

function classify_with_events(ws, edges, event_dates)
    n_events = [count(d -> r.start_date <= d <= r.end_date, event_dates) for r in eachrow(ws)]
    med = median(n_events)
    regime = [n > med ? "high" : "low" for n in n_events]
    date_regime = Dict(ws.start_date[i] => regime[i] for i in 1:nrow(ws))

    n_high = count(==("high"), regime)
    n_low = count(==("low"), regime)

    edge_pairs = unique(select(edges, :source, :target))
    results = NamedTuple[]

    for row in eachrow(edge_pairs)
        src, tgt = row.source, row.target
        pair_edges = filter(r -> r.source == src && r.target == tgt, edges)
        high = count(r -> get(date_regime, r.start_date, "") == "high", eachrow(pair_edges))
        low = count(r -> get(date_regime, r.start_date, "") == "low", eachrow(pair_edges))
        n = nrow(pair_edges)

        cls = if n <= 1; "noise"
        elseif high >= 2 && low <= 1; "common_shock"
        elseif low >= 2 && high <= 1; "quiet_only"
        elseif high >= 2 && low >= 2; "genuine"
        else; "other"
        end

        push!(results, (source=src, target=tgt, persistence=n,
                        n_high=high, n_low=low, classification=cls))
    end

    return DataFrame(results), (n_high=n_high, n_low=n_low, median_events=med,
                                 n_events_range=(minimum(n_events), maximum(n_events)))
end

function main()
    println("=" ^ 70)
    println("Robustness: Expanded Event Calendar")
    println("  Original events: $(length(ORIGINAL_EVENTS))")
    println("  + Tariff dates: $(length(TARIFF_DATES))")
    println("  + Budget dates: $(length(BUDGET_DATES))")
    println("  Expanded total: $(length(EXPANDED_EVENTS))")
    println("=" ^ 70); flush(stdout)

    ws = CSV.read("data/results/window_summary.csv", DataFrame)
    edges = CSV.read("data/results/edge_list.csv", DataFrame)
    ws.start_date = Date.(ws.start_date)
    ws.end_date = Date.(ws.end_date)
    edges.start_date = Date.(edges.start_date)

    # Original classification
    orig_df, orig_stats = classify_with_events(ws, edges, ORIGINAL_EVENTS)
    println("\n── Original Calendar ($(length(ORIGINAL_EVENTS)) events) ──")
    println("  Median events/window: $(orig_stats.median_events)")
    println("  High/Low split: $(orig_stats.n_high)/$(orig_stats.n_low)")
    for cls in ["genuine", "quiet_only", "common_shock", "noise", "other"]
        n = count(==(cls), orig_df.classification)
        n > 0 && println("    $cls: $n")
    end

    # Expanded classification
    exp_df, exp_stats = classify_with_events(ws, edges, EXPANDED_EVENTS)
    println("\n── Expanded Calendar ($(length(EXPANDED_EVENTS)) events) ──")
    println("  Median events/window: $(exp_stats.median_events)")
    println("  High/Low split: $(exp_stats.n_high)/$(exp_stats.n_low)")
    for cls in ["genuine", "quiet_only", "common_shock", "noise", "other"]
        n = count(==(cls), exp_df.classification)
        n > 0 && println("    $cls: $n")
    end

    # Compare: which edges changed classification?
    merged = innerjoin(
        select(rename(orig_df, :classification => :orig_class), :source, :target, :persistence, :orig_class),
        select(rename(exp_df, :classification => :exp_class), :source, :target, :exp_class),
        on=[:source, :target])

    changed = filter(r -> r.orig_class != r.exp_class, merged)
    println("\n── Classification Changes ──")
    println("  Edges that changed: $(nrow(changed)) / $(nrow(merged))")

    if nrow(changed) > 0
        println("\n  Details:")
        for r in eachrow(changed)
            println("    $(r.source) → $(r.target): $(r.orig_class) → $(r.exp_class) (pers=$(r.persistence))")
        end
    end

    # Key question: do tariff/shutdown edges reclassify?
    tariff_edges = filter(r -> occursin("tariff", r.source) || occursin("tariff", r.target) ||
                               occursin("shutdown", r.source) || occursin("shutdown", r.target) ||
                               occursin("china", r.source) || occursin("china", r.target), changed)
    if nrow(tariff_edges) > 0
        println("\n  Tariff/shutdown-related reclassifications:")
        for r in eachrow(tariff_edges)
            println("    $(r.source) → $(r.target): $(r.orig_class) → $(r.exp_class)")
        end
    else
        println("\n  No tariff/shutdown edges reclassified.")
    end

    CSV.write("data/results/expanded_events_classification.csv", exp_df)
    println("\nSaved: data/results/expanded_events_classification.csv")
    println("=" ^ 70); flush(stdout)
end

main()
