"""
Node construction pipeline.

Steps:
  1. Fetch active markets above volume threshold
  2. Filter by keyword tags (macro, Fed, recession, inflation, etc.)
  3. Fetch price history for each YES token
  4. Logit-transform prices: ℓ = log(p / (1-p))
  5. Align to common time grid, forward-fill gaps
  6. Return N×T matrix + metadata
"""

module NodeConstruction

using DataFrames, Dates, Statistics
include(joinpath(@__DIR__, "..", "data", "polymarket.jl"))
using .PolymarketAPI

# ── keyword filter ─────────────────────────────────────────────────────────────

const MACRO_KEYWORDS = [
    # Fed / interest rates — precise phrases only
    "federal reserve", "fomc", "fed rate", "fed cut", "fed hike", "fed raise",
    "fed decrease", "fed increase", "fed lower",
    "interest rate", "rate cut", "rate hike", "rate pause", "rate change",
    "basis point", "bps",
    # Inflation / price level
    "inflation", "cpi", "pce", "core inflation", "price level",
    # Growth / recession / labor
    "gdp", "recession", "unemployment rate", "nonfarm payroll", "payroll",
    "jobs report", "labor market",
    # Treasury / yields
    "10-year yield", "treasury yield", "yield curve", "debt ceiling",
    # Equity indices
    "s&p 500", "spx", "nasdaq", "dow jones",
    # Currency
    "dxy", "dollar index",
    # Commodities used as macro signals
    "wti", "brent crude", "oil price",
    # Trade / tariffs
    "tariff", "trade war", "trade deal",
    # Fiscal / government
    "government shutdown", "debt ceiling", "federal budget",
]

function is_macro_contract(question::String)
    q = lowercase(question)
    return any(kw -> occursin(kw, q), MACRO_KEYWORDS)
end

# ── logit transform ────────────────────────────────────────────────────────────

"""
    logit(p; ε=0.01) → Float64

Logit transform with boundary clipping to avoid ±Inf.
"""
function logit(p::Float64; ε=0.01)
    p_clipped = clamp(p, ε, 1.0 - ε)
    return log(p_clipped / (1.0 - p_clipped))
end

# ── time grid alignment ────────────────────────────────────────────────────────

"""
    align_to_grid(series_dict, timestamps) → Matrix{Float64}

Given a Dict{String => (timestamps, prices)}, align all series to a common
timestamp grid. Missing values are forward-filled, then backward-filled.

Returns:
  - L  : N×T matrix of logit-transformed prices (rows = nodes, cols = time)
  - ids : Vector of node IDs in row order
  - grid: Vector of timestamps (the common grid)
"""
function align_to_grid(series_dict::Dict)
    # Build common grid from union of all timestamps
    all_ts = sort(unique(vcat([collect(ts) for (_, (ts, _)) in series_dict]...)))
    T = length(all_ts)
    N = length(series_dict)
    ids = collect(keys(series_dict))

    L = fill(NaN, N, T)

    for (i, id) in enumerate(ids)
        ts, prices = series_dict[id]
        ts_to_idx = Dict(t => j for (j, t) in enumerate(all_ts))
        for (t, p) in zip(ts, prices)
            haskey(ts_to_idx, t) && (L[i, ts_to_idx[t]] = logit(p))
        end
        # Forward-fill NaNs
        last_val = NaN
        for j in 1:T
            if !isnan(L[i, j])
                last_val = L[i, j]
            elseif !isnan(last_val)
                L[i, j] = last_val
            end
        end
        # Backward-fill leading NaNs
        last_val = NaN
        for j in T:-1:1
            if !isnan(L[i, j])
                last_val = L[i, j]
            elseif !isnan(last_val)
                L[i, j] = last_val
            end
        end
    end

    # Drop columns (time steps) where ANY node is still NaN
    valid_cols = [all(x -> !isnan(x), L[:, j]) for j in 1:T]
    L = L[:, valid_cols]
    grid = all_ts[valid_cols]

    return L, ids, grid
end

# ── main pipeline ──────────────────────────────────────────────────────────────

include(joinpath(@__DIR__, "collapse.jl"))
using .EventCollapse

"""
    build_node_matrix(; min_volume=0.0, fidelity=1440)

Full pipeline: fetch → filter → price history → logit → event-family collapse → align.

Returns:
  - L        : N×T logit-price matrix
  - node_ids : Vector{String} of token IDs
  - metadata : DataFrame with question, volume, condition_id, family_size per node
  - grid     : Vector{Int} of Unix timestamps
"""
function build_node_matrix(; min_volume=0.0, fidelity=1440)
    println("Fetching active markets...")
    markets = PolymarketAPI.fetch_active_markets(; min_volume=min_volume)
    println("  Total active markets: $(nrow(markets))")

    # Filter to macro contracts
    macro_markets = filter(r -> is_macro_contract(r.question), markets)
    println("  Macro-related markets: $(nrow(macro_markets))")

    if nrow(macro_markets) == 0
        error("No macro markets found. Try lowering min_volume or broadening keywords.")
    end

    # Fetch price history for each
    series_dict = Dict{String, Tuple{Vector{Int}, Vector{Float64}}}()
    meta_rows = []

    println("Fetching price histories...")
    for row in eachrow(macro_markets)
        token_ids = PolymarketAPI.token_ids_from_market(row)
        isempty(token_ids) && continue

        token_id = token_ids[1]  # YES token
        try
            hist = PolymarketAPI.fetch_price_history(token_id; interval="max", fidelity=fidelity)
            nrow(hist) < 10 && continue  # Skip illiquid contracts with sparse data

            series_dict[token_id] = (hist.t, hist.p)
            push!(meta_rows, (
                token_id    = token_id,
                question    = row.question,
                volume      = row.volume,
                condition_id = row.condition_id,
                n_obs       = nrow(hist),
            ))
            println("  ✓ $(row.question[1:min(60,length(row.question))]) ($(nrow(hist)) obs)")
        catch e
            println("  ✗ Failed: $(row.question[1:min(40,length(row.question))]) — $e")
        end
        sleep(0.2)  # Rate limiting
    end

    # ── Event family collapse ───────────────────────────────────────────────────
    raw_meta = DataFrame(meta_rows)
    println("\nCollapsing event families...")
    collapsed = EventCollapse.collapse_families(raw_meta)
    println("  Before: $(nrow(raw_meta)) contracts → After: $(nrow(collapsed)) families")
    for row in eachrow(collapsed)
        if row.family_size > 1
            println("  [merged x$(row.family_size)] $(row.question[1:min(60,length(row.question))])")
        end
    end

    # Filter series_dict to only keep representative tokens
    keep_ids = Set(collapsed.token_id)
    series_dict_collapsed = Dict(k => v for (k, v) in series_dict if k in keep_ids)

    println("\nBuilding N×T matrix...")
    L, node_ids, grid = align_to_grid(series_dict_collapsed)

    # Filter nodes with insufficient non-zero data
    min_valid_obs = max(30, Int(floor(length(grid) * 0.2)))  # At least 30 days or 20% of window
    valid_mask = [count(x -> x != 0.0, L[i, :]) >= min_valid_obs for i in 1:size(L, 1)]
    L = L[valid_mask, :]
    node_ids = node_ids[valid_mask]
    println("  Filtered out $(sum(.!valid_mask)) nodes with <$min_valid_obs valid observations")

    # Match metadata to matrix order
    metadata = filter(r -> r.token_id in node_ids, collapsed)

    N, T = size(L)
    println("Matrix: N=$N nodes × T=$T time steps")
    println("T/N ratio: $(round(T/N, digits=1))")

    return L, node_ids, metadata, grid
end

end # module
