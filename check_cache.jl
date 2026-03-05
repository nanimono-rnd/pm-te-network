using Serialization, DataFrames

cache_file = "data/processed/price_cache.jls"
if isfile(cache_file)
    price_data = deserialize(cache_file)
    println("Cached price data:")
    println("  Total contracts: $(length(price_data))")
    
    if length(price_data) > 0
        # Sample first 3
        for (i, (token_id, df)) in enumerate(collect(price_data)[1:min(3, length(price_data))])
            println("\n[$i] Token: $(token_id[1:min(16, length(token_id))])")
            println("    Rows: $(nrow(df))")
            println("    Date range: $(minimum(df.t)) to $(maximum(df.t))")
            println("    Non-zero volume bars: $(count(r -> r.v > 0, eachrow(df)))")
        end
    end
else
    println("No cache file found")
end
