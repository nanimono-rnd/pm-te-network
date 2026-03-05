"""
Rolling window TE network estimation - main pipeline.

Usage:
  julia src/main_rolling.jl
"""

include(joinpath(@__DIR__, "data/gamma_api.jl"))
include(joinpath(@__DIR__, "data/macro_filter.jl"))
include(joinpath(@__DIR__, "data/price_data.jl"))
include(joinpath(@__DIR__, "estimation/rolling_window.jl"))

using .PolymarketGammaAPI, .MacroFilter, .PriceData, .RollingWindow
using DataFrames, Dates, CSV, Serialization

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
println("\n[4/5] Estimating TE networks...")
println("  (Implement in next step)")

# ── Step 5: Aggregate and visualize ────────────────────────────────────────────
println("\n[5/5] Generating outputs...")
println("  (Implement in next step)")

println("\n" * "=" ^ 70)
println("Pipeline structure ready. Next: implement price fetching + TE estimation.")
println("=" ^ 70)
