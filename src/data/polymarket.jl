"""
Polymarket CLOB API client.

Endpoints used:
  - GET /markets          → list all markets with metadata
  - GET /prices-history   → OHLC price history for a market token
"""

module PolymarketAPI

using HTTP, JSON3, DataFrames, Dates

const BASE_URL = "https://clob.polymarket.com"

# ── helpers ────────────────────────────────────────────────────────────────────

function _get(endpoint::String; params=Dict())
    url = BASE_URL * endpoint
    if !isempty(params)
        query = join(["$k=$(HTTP.escapeuri(string(v)))" for (k,v) in params], "&")
        url *= "?" * query
    end
    resp = HTTP.get(url, ["Accept" => "application/json"]; connect_timeout=10, readtimeout=30)
    return JSON3.read(String(resp.body))
end

# ── markets ────────────────────────────────────────────────────────────────────

"""
    fetch_markets(; limit=100, next_cursor="") → DataFrame

Fetch active markets from Polymarket. Returns a DataFrame with:
  condition_id, question, end_date_iso, active, volume, tokens (JSON string)
"""
function fetch_markets(; limit=100, next_cursor="MA==")
    rows = []
    cursor = next_cursor
    while true
        params = Dict("next_cursor" => cursor, "limit" => limit)
        data = _get("/markets"; params=params)

        for m in data["data"]
            push!(rows, (
                condition_id = get(m, "condition_id", ""),
                question     = get(m, "question", ""),
                end_date     = get(m, "end_date_iso", ""),
                active       = get(m, "active", false),
                closed       = get(m, "closed", false),
                volume       = parse(Float64, string(get(m, "volume", "0"))),
                tokens       = JSON3.write(get(m, "tokens", [])),
            ))
        end

        cursor = get(data, "next_cursor", "LTE=")
        # LTE= is Polymarket's "end of results" cursor
        if cursor == "LTE=" || isempty(get(data, "data", []))
            break
        end
        # Safety: stop after 10 pages
        length(rows) >= limit * 10 && break
    end

    return DataFrame(rows)
end

"""
    fetch_active_markets(; min_volume=10000.0) → DataFrame

Fetch all active, unclosed markets above a volume threshold.
"""
function fetch_active_markets(; min_volume=10000.0)
    df = fetch_markets(; limit=500)
    return filter(r -> r.active && !r.closed && r.volume >= min_volume, df)
end

# ── price history ───────────────────────────────────────────────────────────────

"""
    fetch_price_history(token_id; interval="1d", fidelity=60) → DataFrame

Fetch OHLC price history for a single market token.

Args:
  token_id  : the token's ID string (from market's `tokens` field)
  interval  : time range — "1d", "1w", "1m", "3m", "6m", "1y", "all"
  fidelity  : candle width in minutes (60 = hourly, 1440 = daily)

Returns DataFrame with columns: t (Unix timestamp), o, h, l, c (prices in [0,1])
"""
function fetch_price_history(token_id::String; interval="all", fidelity=1440)
    params = Dict(
        "market"   => token_id,
        "interval" => interval,
        "fidelity" => fidelity,
    )
    data = _get("/prices-history"; params=params)
    history = get(data, "history", [])
    isempty(history) && return DataFrame(t=Int[], o=Float64[], h=Float64[], l=Float64[], c=Float64[])

    return DataFrame(
        t = [h["t"] for h in history],
        o = [h["o"] for h in history],
        h = [h["h"] for h in history],
        l = [h["l"] for h in history],
        c = [h["c"] for h in history],
    )
end

"""
    token_ids_from_market(market_row) → Vector{String}

Extract YES token IDs from a market DataFrame row.
Polymarket markets have two tokens (YES/NO); we use YES prices (= contract probability).
"""
function token_ids_from_market(market_row)
    tokens = JSON3.read(market_row.tokens)
    return [String(t["token_id"]) for t in tokens if get(t, "outcome", "") == "Yes"]
end

end # module
