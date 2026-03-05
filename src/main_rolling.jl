"""
Rolling window TE network estimation - main pipeline.

Usage:
  julia src/main_rolling.jl
"""

include(joinpath(@__DIR__, "data/gamma_api.jl"))
include(joinpath(@__DIR__, "data/macro_filter.jl"))
include(joinpath(@__DIR__, "data/price_data.jl"))
include(joinpath(@__DIR__, "estimation/rolling_window.jl"))
include(joinpath(@__DIR__, "estimation/window_te.jl"))

using .PolymarketGammaAPI, .MacroFilter, .PriceData, .RollingWindow, .WindowTE
using DataFrames, Dates, CSV, Serialization, Statistics

println("=" ^ 70)
println("PM-TE-Network: Rolling Window Pipeline")
println("=" ^ 70)

# ── Step 1: Fetch macro contract universe ──────────────────────────────────────
println("\n[1/5] Fetching macro contract universe...")
all_markets = PolymarketGammaAPI.fetch_macro_universe(start_date="2024-06-01")
macro_markets = MacroFilter.filter_macro_markets(all_markets)
println("  Macro contracts: $(nrow(macro_markets))")

# Save universe
CSV.write("data/processed/contract_universe.csv", macro_markets)
println("  Saved → data/processed/contract_universe.csv")

# ── Step 2: Fetch price histories (4h bars) ────────────────────────────────────
println("\n[2/5] Fetching price histories (4h bars)...")

# Check if cached
cache_file = "data/processed/price_cache.jls"
if isfile(cache_file)
    println("  Loading from cache...")
    price_data = deserialize(cache_file)
    println("  Loaded $(length(price_data)) contracts")
else
    price_data = PriceData.fetch_all_prices(macro_markets, PolymarketGammaAPI; fidelity=240)
    
    # Handle staleness
    println("  Handling stale prices...")
    for (token_id, df) in price_data
        price_data[token_id] = PriceData.handle_staleness(df, 12)
    end
    
    # Cache results
    serialize(cache_file, price_data)
    println("  Cached → $cache_file")
end

# ── Step 3: Generate rolling windows ───────────────────────────────────────────
println("\n[3/5] Generating rolling windows...")
config = RollingWindow.WindowConfig()
start_date = Date(2024, 6, 1)
end_date = Date(2026, 3, 5)
windows = RollingWindow.generate_windows(start_date, end_date, config)
println("  Total windows: $(length(windows))")
println("  Window size: $(config.window_days) days")
println("  Step size: $(config.step_days) day")

# ── Step 4: Estimate TE network for each window ────────────────────────────────
println("\n[4/5] Estimating TE networks for rolling windows...")

config = RollingWindow.WindowConfig()
window_results = []

# Sample first 10 windows for pilot (full run would be all 583)
n_windows = min(10, length(windows))
println("  Running pilot on first $n_windows windows...")

for (idx, window) in enumerate(windows[1:n_windows])
    window_start = window.start_date
    window_end = window.end_date
    
    # Filter contracts active in this window
    active_contracts = String[]
    for (token_id, df) in price_data
        active_days = count(row -> begin
            date = Date(unix2datetime(row.t))
            window_start <= date <= window_end && row.v > 0
        end, eachrow(df))
        
        if active_days >= config.min_active_days
            push!(active_contracts, token_id)
        end
    end
    
    if length(active_contracts) < 5
        println("  Window $idx: skipped (only $(length(active_contracts)) contracts)")
        continue
    end
    
    # Build matrix for this window
    L, contracts, grid = WindowTE.build_window_matrix(price_data, active_contracts, window_start, window_end)
    N, T = size(L)
    
    if N < 5 || T < 30
        println("  Window $idx: skipped (N=$N, T=$T too small)")
        continue
    end
    
    # Estimate TE network
    A, TE_matrix, P_matrix, edges = WindowTE.estimate_window_network(L; α=0.05, n_perms=100, max_p=3)
    
    density = length(edges) / (N * (N - 1))
    println("  Window $idx ($window_start): N=$N, T=$T, T/N=$(round(T/N, digits=1)), edges=$(length(edges)), density=$(round(100*density, digits=1))%")
    
    push!(window_results, (
        window_idx = idx,
        start_date = window_start,
        end_date = window_end,
        N = N,
        T = T,
        n_edges = length(edges),
        density = density,
        contracts = contracts,
        edges = edges,
    ))
end

println("  Completed $(length(window_results)) windows")

# ── Step 5: Aggregate and visualize ────────────────────────────────────────────
println("\n[5/5] Generating outputs...")

# Save summary statistics
summary_df = DataFrame(
    window_idx = [r.window_idx for r in window_results],
    start_date = [r.start_date for r in window_results],
    N = [r.N for r in window_results],
    T = [r.T for r in window_results],
    T_N_ratio = [r.T / r.N for r in window_results],
    n_edges = [r.n_edges for r in window_results],
    density = [r.density for r in window_results],
)

CSV.write("data/processed/window_summary.csv", summary_df)
println("  Saved → data/processed/window_summary.csv")

# Save detailed results
serialize("data/processed/window_results.jls", window_results)
println("  Saved → data/processed/window_results.jls")

# Print summary
println("\n" * "=" ^ 70)
println("SUMMARY")
println("=" ^ 70)
println("Total windows analyzed: $(length(window_results))")
if length(window_results) > 0
    println("Average N: $(round(mean(summary_df.N), digits=1))")
    println("Average T/N: $(round(mean(summary_df.T_N_ratio), digits=1))")
    println("Average edges: $(round(mean(summary_df.n_edges), digits=1))")
    println("Average density: $(round(100*mean(summary_df.density), digits=1))%")
else
    println("No windows successfully analyzed. Check data availability.")
end
println("=" ^ 70)
