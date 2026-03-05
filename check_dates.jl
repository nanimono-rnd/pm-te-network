using Serialization, DataFrames, Dates

cache = deserialize("data/processed/price_cache.jls")
println("Checking data time ranges...")

if length(cache) > 0
    all_dates = Date[]
    for (token_id, df) in cache
        for t in df.t
            push!(all_dates, Date(unix2datetime(t)))
        end
    end
    
    println("Data date range: $(minimum(all_dates)) to $(maximum(all_dates))")
    println("Total data points: $(length(all_dates))")
    
    # Check first window
    window_start = Date(2024, 6, 1)
    window_end = Date(2024, 7, 30)
    println("\nFirst window: $window_start to $window_end")
    
    in_window = count(d -> window_start <= d <= window_end, all_dates)
    println("Data points in first window: $in_window")
end
