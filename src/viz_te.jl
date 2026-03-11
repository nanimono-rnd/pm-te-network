"""
TE Network Visualization — 3 panels:
  1. Density time series with FOMC/CPI annotations
  2. Three representative network graphs (quiet / normal / peak)
  3. Hub centrality evolution over time

Usage:
  julia src/viz_te.jl
"""

using CSV, DataFrames, Dates, Statistics, Plots, Plots.PlotMeasures

# ═══════════════════════════════════════════════════════════════════════════════
# Load data
# ═══════════════════════════════════════════════════════════════════════════════

ws = CSV.read("data/results/window_summary.csv", DataFrame)
edges = CSV.read("data/results/edge_list.csv", DataFrame)

ws.start_date = Date.(ws.start_date)
ws.end_date   = Date.(ws.end_date)
edges.start_date = Date.(edges.start_date)

println("Loaded $(nrow(ws)) windows, $(nrow(edges)) edges"); flush(stdout)

# ═══════════════════════════════════════════════════════════════════════════════
# Event calendar — FOMC decisions & CPI releases (2025 actual dates)
# ═══════════════════════════════════════════════════════════════════════════════

const FOMC_DATES = Date.([
    "2025-01-29", "2025-03-19", "2025-05-07", "2025-06-18",
    "2025-07-30", "2025-09-17", "2025-10-29", "2025-12-17",
])

const CPI_DATES = Date.([
    "2025-01-15", "2025-02-12", "2025-03-12", "2025-04-10",
    "2025-05-13", "2025-06-11", "2025-07-11", "2025-08-12",
    "2025-09-10", "2025-10-14", "2025-11-13", "2025-12-10",
])

# ═══════════════════════════════════════════════════════════════════════════════
# Panel 1: Network density time series
# ═══════════════════════════════════════════════════════════════════════════════

function plot_density_timeseries(ws)
    println("Panel 1: Density time series..."); flush(stdout)

    pri = filter(r -> r.regime == "primary", ws)
    sec = filter(r -> r.regime == "secondary", ws)

    plt = plot(
        size=(1200, 500),
        title="TE Network Density Over Time (VAR(1), α=0.01, 200 perms)",
        xlabel="Window start date",
        ylabel="Edge density (%)",
        legend=:topleft,
        background_color=:white,
        grid=true,
        gridstyle=:dot,
        gridalpha=0.3,
        left_margin=10mm,
        bottom_margin=10mm,
        titlefontsize=12,
    )

    # FOMC vertical lines
    ymax = maximum(ws.density) * 100 * 1.15
    for d in FOMC_DATES
        if minimum(ws.start_date) <= d <= maximum(ws.start_date)
            vline!(plt, [d], color=:red, alpha=0.25, linewidth=1.5, linestyle=:dash, label="")
        end
    end
    # CPI vertical lines
    for d in CPI_DATES
        if minimum(ws.start_date) <= d <= maximum(ws.start_date)
            vline!(plt, [d], color=:blue, alpha=0.15, linewidth=1, linestyle=:dot, label="")
        end
    end

    # Secondary windows (gray, background)
    if nrow(sec) > 0
        scatter!(plt, sec.start_date, sec.density .* 100,
                 markersize=2, alpha=0.3, color=:gray,
                 markerstrokewidth=0, label="Secondary (N<8)")
    end

    # Primary windows (colored by N)
    scatter!(plt, pri.start_date, pri.density .* 100,
             markersize=3, alpha=0.6,
             marker_z=pri.N, color=:viridis,
             markerstrokewidth=0, label="Primary (N≥8)",
             colorbar_title="N")

    # 7-day rolling mean for primary
    if nrow(pri) >= 7
        sort!(pri, :start_date)
        roll_den = [mean(pri.density[max(1,i-3):min(nrow(pri),i+3)]) * 100
                    for i in 1:nrow(pri)]
        plot!(plt, pri.start_date, roll_den,
              linewidth=2.5, color=:black, alpha=0.7, label="7-day MA")
    end

    # Legend markers for FOMC/CPI (invisible dummy points at valid date)
    legend_date = minimum(ws.start_date)
    plot!(plt, [legend_date], [-999], color=:red, alpha=0.5,
          linewidth=2, linestyle=:dash, label="FOMC")
    plot!(plt, [legend_date], [-999], color=:blue, alpha=0.3,
          linewidth=1.5, linestyle=:dot, label="CPI")

    ylims!(plt, (0, ymax))
    xlims!(plt, (Dates.value(minimum(ws.start_date) - Day(10)),
                 Dates.value(maximum(ws.start_date) + Day(10))))

    return plt
end

# ═══════════════════════════════════════════════════════════════════════════════
# Panel 2: Three representative network graphs
# ═══════════════════════════════════════════════════════════════════════════════

function load_adjacency_and_te(w_idx)
    fname = "data/results/adjacency/window_$(lpad(w_idx, 4, '0')).csv"
    adj = CSV.read(fname, DataFrame)
    families = adj.node
    A = Matrix{Float64}(adj[:, 2:end])

    # Get TE values from edge list
    w_edges = filter(r -> r.window_idx == w_idx, edges)
    N = length(families)
    TE = zeros(N, N)
    fam_idx = Dict(f => i for (i, f) in enumerate(families))
    for r in eachrow(w_edges)
        i = get(fam_idx, r.target, 0)
        j = get(fam_idx, r.source, 0)
        (i > 0 && j > 0) && (TE[i, j] = r.te_value)
    end

    return A, TE, String.(families)
end

function short_label(name::String)
    replacements = Dict(
        "fed_rate_level" => "Fed Rate",
        "fed_rate_path" => "Rate Path",
        "fomc_dynamics" => "FOMC",
        "fed_leadership" => "Fed Chair",
        "fed_gov_confidence" => "Fed-Gov",
        "headline_cpi" => "CPI",
        "core_cpi_pce" => "Core CPI",
        "cpi_subcomponents" => "CPI Sub",
        "gdp" => "GDP",
        "jobless_claims" => "Jobless",
        "gov_shutdown" => "Shutdown",
        "debt_funding" => "Debt",
        "china_tariff_rate" => "CN Tariff",
        "china_policy" => "CN Policy",
        "global_tariffs" => "Tariffs",
        "congress_tariff" => "Cong Tariff",
        "potus_approval" => "POTUS",
        "potus_social" => "POTUS Social",
        "congress_narrative" => "Congress",
        "congress_investigations" => "Cong Invest",
        "nasdaq_targets" => "Nasdaq",
    )
    return get(replacements, name, name)
end

function plot_network(A, TE, families; title="")
    N = size(A, 1)
    labels = short_label.(families)

    # Circular layout — shrink radius so labels fit inside the plot area
    R = 0.7
    θ = [2π * i / N for i in 0:(N-1)]
    x = R .* cos.(θ)
    y = R .* sin.(θ)

    out_deg = vec(sum(A, dims=2))
    in_deg  = vec(sum(A, dims=1))
    total_deg = out_deg .+ in_deg
    max_deg = max(maximum(total_deg), 1)

    plt = plot(
        size=(600, 600),
        title=title,
        titlefontsize=9,
        background_color=:white,
        legend=false,
        axis=nothing,
        border=:none,
        xlims=(-1.3, 1.3),
        ylims=(-1.3, 1.3),
    )

    # Edges
    te_vals = [TE[i,j] for i in 1:N, j in 1:N if A[i,j] == 1]
    te_max = isempty(te_vals) ? 1.0 : maximum(te_vals)
    te_min = isempty(te_vals) ? 0.0 : minimum(te_vals)

    for i in 1:N, j in 1:N
        A[i,j] != 1 && continue
        norm_te = te_max > te_min ? (TE[i,j] - te_min) / (te_max - te_min) : 1.0
        lw = 1.0 + 3.0 * norm_te
        alpha = 0.4 + 0.6 * norm_te
        col = RGBA(0.15, 0.35, 0.85, alpha)

        # Curved edge via midpoint pulled toward center
        mx = (x[j] + x[i]) / 2 * 0.82
        my = (y[j] + y[i]) / 2 * 0.82
        plot!(plt, [x[j], mx, x[i]], [y[j], my, y[i]],
              linewidth=lw, color=col, arrow=true)
    end

    # Nodes + labels directly adjacent
    for i in 1:N
        node_size = 6 + 10 * (total_deg[i] / max_deg)
        c = out_deg[i] > 0 ? RGBA(0.85, 0.25, 0.15, 0.9) : RGBA(0.5, 0.5, 0.5, 0.7)
        scatter!(plt, [x[i]], [y[i]],
                 markersize=node_size, color=c, markerstrokewidth=0.5,
                 markerstrokecolor=:white)

        # Label: tight offset + thin connector line
        lx = x[i] / R * 1.05
        ly = y[i] / R * 1.05
        halign = x[i] > 0.05 ? :left : (x[i] < -0.05 ? :right : :center)
        valign = abs(x[i]) < 0.05 ? (y[i] > 0 ? :bottom : :top) : :vcenter

        # Connector line from node edge to label
        plot!(plt, [x[i], lx], [y[i], ly],
              linewidth=0.3, color=RGBA(0.4, 0.4, 0.4, 0.4))
        annotate!(plt, lx, ly, text(labels[i], 7, :black, halign, valign))
    end

    return plt
end

function plot_three_networks(ws)
    println("Panel 2: Three network graphs..."); flush(stdout)
    pri = filter(r -> r.regime == "primary", ws)
    sort!(pri, :n_edges)

    # Quiet: primary window with fewest edges (>0)
    has_edges = filter(r -> r.n_edges > 0, pri)
    quiet_w = first(has_edges).window_idx

    # Peak: window with most edges
    peak_w = last(pri).window_idx

    # Normal: median-edge primary window
    mid_idx = div(nrow(has_edges), 2)
    normal_w = has_edges[mid_idx, :window_idx]

    println("  Quiet:  W$quiet_w ($(first(has_edges).start_date), edges=$(first(has_edges).n_edges))")
    println("  Normal: W$normal_w ($(has_edges[mid_idx, :start_date]), edges=$(has_edges[mid_idx, :n_edges]))")
    println("  Peak:   W$peak_w ($(last(pri).start_date), edges=$(last(pri).n_edges))")
    flush(stdout)

    A_q, TE_q, f_q = load_adjacency_and_te(quiet_w)
    A_n, TE_n, f_n = load_adjacency_and_te(normal_w)
    A_p, TE_p, f_p = load_adjacency_and_te(peak_w)

    p1 = plot_network(A_q, TE_q, f_q,
        title="Quiet: W$quiet_w ($(first(has_edges).start_date), $(first(has_edges).n_edges) edges)")
    p2 = plot_network(A_n, TE_n, f_n,
        title="Normal: W$normal_w ($(has_edges[mid_idx, :start_date]), $(has_edges[mid_idx, :n_edges]) edges)")
    p3 = plot_network(A_p, TE_p, f_p,
        title="Peak: W$peak_w ($(last(pri).start_date), $(last(pri).n_edges) edges)")

    combined = plot(p1, p2, p3, layout=@layout([a b; c _]), size=(1200, 1200))
    return combined
end

# ═══════════════════════════════════════════════════════════════════════════════
# Panel 3: Hub centrality evolution
# ═══════════════════════════════════════════════════════════════════════════════

function plot_hub_evolution(ws, edges)
    println("Panel 3: Hub centrality evolution..."); flush(stdout)
    pri = filter(r -> r.regime == "primary", ws)
    sort!(pri, :start_date)

    # All families that appear as source or target in primary regime
    pri_edges = filter(r -> r.start_date in Set(pri.start_date), edges)
    all_families = sort(unique(vcat(pri_edges.source, pri_edges.target)))

    # Top families by total appearances (source + target)
    family_total = Dict{String,Int}()
    for f in vcat(pri_edges.source, pri_edges.target)
        family_total[f] = get(family_total, f, 0) + 1
    end
    top_families = first(sort(collect(family_total), by=x->-x[2]), min(8, length(family_total)))
    top_names = [x[1] for x in top_families]

    # Compute per-window out-degree for each top family
    # (out-degree = number of targets this family drives)
    dates_vec = pri.start_date
    out_series = Dict{String, Vector{Float64}}()
    for f in top_names
        out_series[f] = zeros(nrow(pri))
    end

    for (k, row) in enumerate(eachrow(pri))
        w_edges = filter(r -> r.window_idx == row.window_idx, edges)
        for f in top_names
            out_series[f][k] = Float64(count(==(f), w_edges.source))
        end
    end

    # Colors
    palette = [:firebrick, :royalblue, :forestgreen, :darkorange,
               :purple, :teal, :brown, :hotpink]

    plt = plot(
        size=(1200, 500),
        title="Hub Out-Degree Evolution (Primary Regime, N≥8)",
        xlabel="Window start date",
        ylabel="Out-degree (# targets driven)",
        legend=:topright,
        background_color=:white,
        grid=true,
        gridstyle=:dot,
        gridalpha=0.3,
        left_margin=10mm,
        bottom_margin=10mm,
        titlefontsize=12,
    )

    # FOMC/CPI event lines
    for d in FOMC_DATES
        if minimum(dates_vec) <= d <= maximum(dates_vec)
            vline!(plt, [d], color=:red, alpha=0.15, linewidth=1, linestyle=:dash, label="")
        end
    end

    for (k, f) in enumerate(top_names)
        # 7-day rolling mean
        raw = out_series[f]
        smoothed = [mean(raw[max(1,i-3):min(length(raw),i+3)]) for i in 1:length(raw)]
        cidx = mod1(k, length(palette))
        plot!(plt, dates_vec, smoothed,
              linewidth=2, color=palette[cidx], alpha=0.8,
              label=short_label(f))
    end

    return plt
end

# ═══════════════════════════════════════════════════════════════════════════════
# Main
# ═══════════════════════════════════════════════════════════════════════════════

function main()
    println("=" ^ 60)
    println("TE Network Visualization")
    println("=" ^ 60); flush(stdout)

    mkpath("data/results/figures")

    # Panel 1
    p1 = plot_density_timeseries(ws)
    savefig(p1, "data/results/figures/density_timeseries.png")
    println("  Saved: density_timeseries.png"); flush(stdout)

    # Panel 2
    p2 = plot_three_networks(ws)
    savefig(p2, "data/results/figures/network_triptych.png")
    println("  Saved: network_triptych.png"); flush(stdout)

    # Panel 3
    p3 = plot_hub_evolution(ws, edges)
    savefig(p3, "data/results/figures/hub_evolution.png")
    println("  Saved: hub_evolution.png"); flush(stdout)

    println("\n" * "=" ^ 60)
    println("All figures saved to data/results/figures/")
    println("=" ^ 60)
end

main()
