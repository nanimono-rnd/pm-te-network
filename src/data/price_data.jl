"""
Price data fetching and staleness handling.
"""

module PriceData

using DataFrames, Dates, Statistics, JSON3

"""
    fetch_all_prices(markets::DataFrame, api_module; fidelity=240) → Dict

Fetch price histories for all markets.

Returns: Dict{String => DataFrame} where DataFrame has columns (t, p, v)
"""
function fetch_all_prices(markets::DataFrame, api_module; fidelity=240)
    price_data = Dict{String, DataFrame}()
    
    println("Fetching $(nrow(markets)) price histories...")
    for (i, row) in enumerate(eachrow(markets))
        # Extract token IDs from clob_token_ids column (JSON string)
        clob_ids_str = row.clob_token_ids
        token_ids = try
            JSON3.read(clob_ids_str)
        catch
            []
        end
        
        isempty(token_ids) && continue
        
        token_id = String(token_ids[1])
        hist = api_module.fetch_price_history(token_id; interval="max", fidelity=fidelity)
        
        if nrow(hist) >= 10
            price_data[token_id] = hist
            if i % 50 == 0
                println("  Progress: $i/$(nrow(markets))")
            end
        end
        
        sleep(0.1)  # Rate limiting
    end
    
    println("  Fetched $(length(price_data)) contracts with data")
    return price_data
end

"""
    handle_staleness(df::DataFrame, stale_threshold_bars::Int=12) → DataFrame

Mark stale prices as missing.
If no trade for stale_threshold_bars consecutive bars, mark as NaN.
"""
function handle_staleness(df::DataFrame, stale_threshold_bars::Int=12)
    result = copy(df)
    n = nrow(result)
    
    # Track consecutive zero-volume bars
    zero_count = 0
    for i in 1:n
        if result.v[i] == 0.0
            zero_count += 1
            if zero_count >= stale_threshold_bars
                result.p[i] = NaN
            end
        else
            zero_count = 0
        end
    end
    
    return result
end

end # module
