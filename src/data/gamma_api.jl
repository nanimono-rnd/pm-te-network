"""
Polymarket Gamma API client.

Endpoints:
  - GET /markets          → list markets (active or closed)
  - GET /prices-history   → historical prices with 4h bars
"""

module PolymarketGammaAPI

using HTTP, JSON3, DataFrames, Dates

const BASE_URL = "https://gamma-api.polymarket.com"

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
    fetch_markets(; closed=false, end_date_min="", limit=500) → Vector

Fetch markets from Gamma API.

Args:
  closed       : true = resolved markets, false = active markets
  end_date_min : ISO date string (e.g., "2024-06-01") to filter by end date
  limit        : max results per page

Returns: Vector of market objects (JSON3 objects)
"""
function fetch_markets(; closed=false, end_date_min="", limit=500)
    params = Dict{String,Any}("limit" => limit, "closed" => closed)
    !isempty(end_date_min) && (params["end_date_min"] = end_date_min)
    
    data = _get("/markets"; params=params)
    return data
end

"""
    fetch_macro_universe(; start_date="2024-06-01") → DataFrame

Fetch complete macro contract universe: active + recently resolved.

Returns DataFrame with columns:
  condition_id, question, end_date_iso, closed, volume, tokens (JSON string)
"""
function fetch_macro_universe(; start_date="2024-06-01")
    println("Fetching active markets...")
    active = fetch_markets(closed=false, limit=1000)
    println("  Active: $(length(active))")
    
    println("Fetching resolved markets since $start_date...")
    resolved = fetch_markets(closed=true, end_date_min=start_date, limit=1000)
    println("  Resolved: $(length(resolved))")
    
    all_markets = vcat(active, resolved)
    println("  Total: $(length(all_markets))")
    
    # Convert to DataFrame
    rows = []
    for m in all_markets
        vol_raw = get(m, :volume, nothing)
        vol = if vol_raw === nothing
            0.0
        elseif vol_raw isa Number
            Float64(vol_raw)
        else
            tryparse(Float64, string(vol_raw)) |> x -> isnothing(x) ? 0.0 : x
        end
        
        push!(rows, (
            condition_id = string(get(m, :conditionId, "")),
            question     = string(get(m, :question, "")),
            end_date_iso = string(get(m, :endDateIso, "")),
            closed       = get(m, :closed, false) === true,
            volume       = vol,
            clob_token_ids = string(get(m, :clobTokenIds, "[]")),
        ))
    end
    
    return DataFrame(rows)
end

# ── price history (via CLOB API) ────────────────────────────────────────────────

const CLOB_URL = "https://clob.polymarket.com"

"""
    fetch_price_history(token_id::String; interval="max", fidelity=240) → DataFrame

Fetch historical prices via CLOB API.

Args:
  token_id : Token ID (from clobTokenIds)
  interval : Time range ("max", "1d", "1w", "1m", "3m", "6m", "1y")
  fidelity : Bar width in minutes (240 = 4h, 1440 = daily)

Returns DataFrame with: t (Unix timestamp), p (price), v (volume=0)
"""
function fetch_price_history(token_id::String; interval="max", fidelity=240)
    url = "$CLOB_URL/prices-history"
    params = "?market=$token_id&interval=$interval&fidelity=$fidelity"
    
    try
        resp = HTTP.get(url * params, ["Accept" => "application/json"])
        data = JSON3.read(String(resp.body))
        history = get(data, :history, [])
        
        isempty(history) && return DataFrame(t=Int[], p=Float64[], v=Float64[])
        
        return DataFrame(
            t = [Int(h[:t]) for h in history],
            p = [Float64(h[:p]) for h in history],
            v = fill(0.0, length(history)),  # CLOB doesn't provide volume
        )
    catch e
        @warn "Failed to fetch price history for $token_id: $e"
        return DataFrame(t=Int[], p=Float64[], v=Float64[])
    end
end

"""
    token_ids_from_market(market_row) → Vector{String}

Extract token IDs from a Gamma API market.
Gamma API uses 'clobTokenIds' field (JSON string array).
"""
function token_ids_from_market(market_row)
    clob_ids = get(market_row, :clobTokenIds, "[]")
    if clob_ids isa String
        ids = JSON3.read(clob_ids)
        return [String(id) for id in ids]
    else
        return String[]
    end
end

end # module
