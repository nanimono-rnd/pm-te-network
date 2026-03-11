"""
Identification Experiments 1, 3, 4 — Post-processing on existing TE results.

Experiment 1: Event-Window Decomposition (CORE)
  Split windows by FOMC/CPI/NFP event density → classify edges.

Experiment 3: Lead-Lag Asymmetry
  AR(A→B) = (TE(A→B) - TE(B→A)) / (TE(A→B) + TE(B→A))
  High |AR| = genuine directed; AR ≈ 0 = common factor.

Experiment 4: Hierarchical Edge Analysis
  Flag logically nested pairs. HER = hierarchical / total edges.

Output: data/results/classified_edges.csv — master edge classification table.

Usage:
  julia src/identification/experiments.jl
"""

using CSV, DataFrames, Dates, Statistics, Random

# ═══════════════════════════════════════════════════════════════════════════════
# Event Calendar (FOMC, CPI, NFP)
# ═══════════════════════════════════════════════════════════════════════════════

# FOMC announcement dates (statement release)
const FOMC_DATES = Date.([
    # 2024
    "2024-01-31", "2024-03-20", "2024-05-01", "2024-06-12",
    "2024-07-31", "2024-09-18", "2024-11-07", "2024-12-18",
    # 2025
    "2025-01-29", "2025-03-19", "2025-05-07", "2025-06-18",
    "2025-07-30", "2025-09-17", "2025-10-29", "2025-12-17",
    # 2026 (scheduled)
    "2026-01-28", "2026-03-18",
])

# CPI release dates (BLS)
const CPI_DATES = Date.([
    # 2024
    "2024-01-11", "2024-02-13", "2024-03-12", "2024-04-10",
    "2024-05-15", "2024-06-12", "2024-07-11", "2024-08-14",
    "2024-09-11", "2024-10-10", "2024-11-13", "2024-12-11",
    # 2025
    "2025-01-15", "2025-02-12", "2025-03-12", "2025-04-10",
    "2025-05-13", "2025-06-11", "2025-07-10", "2025-08-12",
    "2025-09-10", "2025-10-14", "2025-11-12", "2025-12-10",
    # 2026
    "2026-01-14", "2026-02-11",
])

# Non-Farm Payrolls release dates (BLS, first Friday of month)
const NFP_DATES = Date.([
    # 2024
    "2024-01-05", "2024-02-02", "2024-03-08", "2024-04-05",
    "2024-05-03", "2024-06-07", "2024-07-05", "2024-08-02",
    "2024-09-06", "2024-10-04", "2024-11-01", "2024-12-06",
    # 2025
    "2025-01-10", "2025-02-07", "2025-03-07", "2025-04-04",
    "2025-05-02", "2025-06-06", "2025-07-03", "2025-08-01",
    "2025-09-05", "2025-10-03", "2025-11-07", "2025-12-05",
    # 2026
    "2026-01-09", "2026-02-06",
])

const ALL_EVENT_DATES = sort(unique(vcat(FOMC_DATES, CPI_DATES, NFP_DATES)))

# Hierarchical / nested pairs (within same macro concept → expect spurious edges)
const HIERARCHICAL_PAIRS = Set([
    ("core_cpi_pce", "headline_cpi"),
    ("headline_cpi", "core_cpi_pce"),
    ("fed_rate_level", "fed_rate_path"),
    ("fed_rate_path", "fed_rate_level"),
    ("fed_rate_level", "fomc_dynamics"),
    ("fomc_dynamics", "fed_rate_level"),
    ("fed_rate_path", "fomc_dynamics"),
    ("fomc_dynamics", "fed_rate_path"),
    ("fed_leadership", "fed_gov_confidence"),
    ("fed_gov_confidence", "fed_leadership"),
    ("china_tariff_rate", "china_policy"),
    ("china_policy", "china_tariff_rate"),
    ("china_tariff_rate", "global_tariffs"),
    ("global_tariffs", "china_tariff_rate"),
    ("china_policy", "global_tariffs"),
    ("global_tariffs", "china_policy"),
    ("potus_approval", "congress_narrative"),
    ("congress_narrative", "potus_approval"),
    ("congress_narrative", "congress_investigations"),
    ("congress_investigations", "congress_narrative"),
])

# ═══════════════════════════════════════════════════════════════════════════════
# Load results
# ═══════════════════════════════════════════════════════════════════════════════

function load_results()
    ws = CSV.read("data/results/window_summary.csv", DataFrame)
    edges = CSV.read("data/results/edge_list.csv", DataFrame)
    ws.start_date = Date.(ws.start_date)
    ws.end_date = Date.(ws.end_date)
    edges.start_date = Date.(edges.start_date)
    return ws, edges
end

# ═══════════════════════════════════════════════════════════════════════════════
# Experiment 1: Event-Window Decomposition
# ═══════════════════════════════════════════════════════════════════════════════

function count_events_in_window(w_start::Date, w_end::Date)
    return count(d -> w_start <= d <= w_end, ALL_EVENT_DATES)
end

function experiment1_event_window(ws::DataFrame, edges::DataFrame)
    println("\n── Experiment 1: Event-Window Decomposition ──"); flush(stdout)

    # Count events per window
    ws.n_events = [count_events_in_window(r.start_date, r.end_date) for r in eachrow(ws)]

    # Median split
    med = median(ws.n_events)
    ws.event_regime = [n > med ? "high_event" : "low_event" for n in ws.n_events]
    n_high = count(==("high_event"), ws.event_regime)
    n_low = count(==("low_event"), ws.event_regime)
    println("  Event count range: $(minimum(ws.n_events))-$(maximum(ws.n_events)), median=$med")
    println("  High-event windows: $n_high, Low-event windows: $n_low")

    # Map window start_date → event_regime
    date_regime = Dict(r.start_date => r.event_regime for r in eachrow(ws))

    # For each unique directed edge, classify
    edge_pairs = unique(select(edges, :source, :target))
    results = NamedTuple[]

    for row in eachrow(edge_pairs)
        src, tgt = row.source, row.target
        pair_edges = filter(r -> r.source == src && r.target == tgt, edges)

        # Split by event regime
        high_edges = filter(r -> get(date_regime, r.start_date, "") == "high_event", pair_edges)
        low_edges = filter(r -> get(date_regime, r.start_date, "") == "low_event", pair_edges)

        n_total = nrow(pair_edges)
        n_high_e = nrow(high_edges)
        n_low_e = nrow(low_edges)

        mean_te = mean(pair_edges.te_value)
        mean_te_high = n_high_e > 0 ? mean(high_edges.te_value) : 0.0
        mean_te_low = n_low_e > 0 ? mean(low_edges.te_value) : 0.0
        delta_te = mean_te_high - mean_te_low

        # Bootstrap ΔTE significance (if enough observations)
        delta_te_pval = NaN
        if n_high_e >= 3 && n_low_e >= 3
            rng = MersenneTwister(hash((src, tgt)))
            all_te = pair_edges.te_value
            n_boot = 1000
            boot_deltas = Float64[]
            for _ in 1:n_boot
                boot_high = all_te[rand(rng, 1:n_total, n_high_e)]
                boot_low = all_te[rand(rng, 1:n_total, n_low_e)]
                push!(boot_deltas, mean(boot_high) - mean(boot_low))
            end
            # Two-sided p-value
            delta_te_pval = mean(abs.(boot_deltas) .>= abs(delta_te))
        end

        # Classification
        classification = if n_total <= 1
            "noise"
        elseif n_high_e >= 2 && n_low_e <= 1
            "common_shock"
        elseif n_low_e >= 2 && n_high_e <= 1
            "quiet_only"
        elseif n_high_e >= 2 && n_low_e >= 2
            if !isnan(delta_te_pval) && delta_te_pval < 0.05 && delta_te > 0
                "event_amplified"
            else
                "genuine"
            end
        else
            "unclassified"
        end

        push!(results, (
            source = src, target = tgt,
            persistence = n_total,
            n_high_event = n_high_e, n_low_event = n_low_e,
            mean_te = round(mean_te, digits=6),
            mean_te_high = round(mean_te_high, digits=6),
            mean_te_low = round(mean_te_low, digits=6),
            delta_te = round(delta_te, digits=6),
            delta_te_pval = round(delta_te_pval, digits=4),
            exp1_class = classification,
        ))
    end

    df = DataFrame(results)
    sort!(df, :persistence, rev=true)

    # Summary
    for cls in ["genuine", "common_shock", "event_amplified", "quiet_only", "noise", "unclassified"]
        n = count(==(cls), df.exp1_class)
        n > 0 && println("  $cls: $n edges")
    end
    flush(stdout)

    return df
end

# ═══════════════════════════════════════════════════════════════════════════════
# Experiment 3: Lead-Lag Asymmetry
# ═══════════════════════════════════════════════════════════════════════════════

function experiment3_leadlag(edges::DataFrame, classified::DataFrame)
    println("\n── Experiment 3: Lead-Lag Asymmetry ──"); flush(stdout)

    # For each undirected pair (A, B), compute asymmetry ratio
    # AR = (TE(A→B) - TE(B→A)) / (TE(A→B) + TE(B→A))
    # Using persistence-weighted mean TE

    # Build lookup: (source, target) → (persistence, mean_te)
    edge_info = Dict{Tuple{String,String}, Tuple{Int, Float64}}()
    for r in eachrow(classified)
        edge_info[(r.source, r.target)] = (r.persistence, r.mean_te)
    end

    # Find all undirected pairs
    all_nodes = sort(unique(vcat(classified.source, classified.target)))
    asymmetry_results = Float64[]

    classified.exp3_asymmetry = fill(NaN, nrow(classified))

    for i in 1:nrow(classified)
        src, tgt = classified.source[i], classified.target[i]
        fwd = get(edge_info, (src, tgt), (0, 0.0))
        rev = get(edge_info, (tgt, src), (0, 0.0))

        te_fwd = fwd[2] * fwd[1]  # persistence-weighted
        te_rev = rev[2] * rev[1]
        total = te_fwd + te_rev

        if total > 0
            ar = (te_fwd - te_rev) / total
            classified.exp3_asymmetry[i] = round(ar, digits=4)
            push!(asymmetry_results, abs(ar))
        end
    end

    valid_ar = filter(!isnan, classified.exp3_asymmetry)
    if !isempty(valid_ar)
        println("  Mean |AR|: $(round(mean(abs.(valid_ar)), digits=3))")
        println("  High asymmetry (|AR|>0.5): $(count(x -> abs(x) > 0.5, valid_ar)) / $(length(valid_ar))")
        println("  Low asymmetry (|AR|<0.2): $(count(x -> abs(x) < 0.2, valid_ar)) / $(length(valid_ar))")
    end
    flush(stdout)

    return classified
end

# ═══════════════════════════════════════════════════════════════════════════════
# Experiment 4: Hierarchical Edge Analysis
# ═══════════════════════════════════════════════════════════════════════════════

function experiment4_hierarchical(classified::DataFrame)
    println("\n── Experiment 4: Hierarchical Edge Analysis ──"); flush(stdout)

    classified.is_hierarchical = [
        (r.source, r.target) in HIERARCHICAL_PAIRS
        for r in eachrow(classified)
    ]

    n_hier = count(classified.is_hierarchical)
    n_total = nrow(classified)
    her = n_total > 0 ? n_hier / n_total : 0.0

    println("  Hierarchical edges: $n_hier / $n_total (HER = $(round(100*her, digits=1))%)")

    # Show hierarchical edges
    hier_edges = filter(r -> r.is_hierarchical, classified)
    if nrow(hier_edges) > 0
        sort!(hier_edges, :persistence, rev=true)
        println("  Hierarchical edge details:")
        for r in eachrow(first(hier_edges, 10))
            println("    $(r.source) → $(r.target): persistence=$(r.persistence), class=$(r.exp1_class)")
        end
    end
    flush(stdout)

    return classified
end

# ═══════════════════════════════════════════════════════════════════════════════
# Final Classification
# ═══════════════════════════════════════════════════════════════════════════════

function final_classification(classified::DataFrame)
    println("\n── Final Edge Classification ──"); flush(stdout)

    # Combine Exp1 + Exp3 + Exp4 into final label
    classified.final_label = copy(classified.exp1_class)

    for i in 1:nrow(classified)
        # Override: hierarchical edges that appear "genuine" are suspicious
        if classified.is_hierarchical[i] && classified.exp1_class[i] == "genuine"
            classified.final_label[i] = "hierarchical_genuine"
        end

        # Cross-validate with asymmetry: low |AR| genuine edges may be common factor
        ar = classified.exp3_asymmetry[i]
        if !isnan(ar) && abs(ar) < 0.1 && classified.exp1_class[i] == "genuine"
            classified.final_label[i] = "genuine_symmetric"
        end
    end

    # Summary table
    println("\n  ┌─────────────────────────┬───────┬────────────┐")
    println("  │ Classification          │ Count │ Avg Pers.  │")
    println("  ├─────────────────────────┼───────┼────────────┤")
    for label in sort(unique(classified.final_label))
        sub = filter(r -> r.final_label == label, classified)
        n = nrow(sub)
        avg_p = round(mean(sub.persistence), digits=1)
        println("  │ $(rpad(label, 23)) │ $(lpad(n, 5)) │ $(lpad(avg_p, 10)) │")
    end
    println("  └─────────────────────────┴───────┴────────────┘")

    # Clean network stats
    clean = filter(r -> r.final_label in ["genuine", "genuine_symmetric", "event_amplified", "hierarchical_genuine"], classified)
    raw_n = nrow(classified)
    clean_n = nrow(clean)
    println("\n  Raw edges: $raw_n")
    println("  Clean edges (genuine + event_amplified): $clean_n ($(round(100*clean_n/raw_n, digits=1))% survive identification)")

    # Noise + common shock = removed
    removed = filter(r -> r.final_label in ["noise", "common_shock"], classified)
    println("  Removed (noise + common_shock): $(nrow(removed))")
    flush(stdout)

    return classified
end

# ═══════════════════════════════════════════════════════════════════════════════
# Main
# ═══════════════════════════════════════════════════════════════════════════════

function main()
    println("=" ^ 70)
    println("PM-TE-Network: Identification Experiments 1, 3, 4")
    println("  Event dates: $(length(FOMC_DATES)) FOMC, $(length(CPI_DATES)) CPI, $(length(NFP_DATES)) NFP")
    println("  Total macro events in calendar: $(length(ALL_EVENT_DATES))")
    println("=" ^ 70)
    flush(stdout)

    ws, edges = load_results()
    println("Loaded: $(nrow(ws)) windows, $(nrow(edges)) edges")
    n_primary = count(==("primary"), ws.regime)
    println("  Primary windows: $n_primary")
    flush(stdout)

    # Experiment 1: Event-Window Decomposition
    classified = experiment1_event_window(ws, edges)

    # Experiment 3: Lead-Lag Asymmetry
    classified = experiment3_leadlag(edges, classified)

    # Experiment 4: Hierarchical Edge Analysis
    classified = experiment4_hierarchical(classified)

    # Final classification
    classified = final_classification(classified)

    # Save
    CSV.write("data/results/classified_edges.csv", classified)
    println("\nSaved: data/results/classified_edges.csv ($(nrow(classified)) edges)")

    # Top genuine edges
    genuine = filter(r -> r.final_label in ["genuine", "event_amplified"], classified)
    sort!(genuine, :persistence, rev=true)
    println("\n── Top 15 Genuine/Event-Amplified Edges ──")
    println("  $(rpad("Edge", 45)) Pers  MeanTE   Class")
    for r in eachrow(first(genuine, 15))
        edge = "$(r.source) → $(r.target)"
        println("  $(rpad(edge, 45)) $(lpad(r.persistence, 4))  $(lpad(round(r.mean_te, digits=4), 6))   $(r.final_label)")
    end

    println("\n" * "=" ^ 70)
    flush(stdout)
end

main()
