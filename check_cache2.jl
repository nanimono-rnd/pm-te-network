using Serialization, DataFrames

cache = deserialize("data/processed/price_cache.jls")
println("Cache has $(length(cache)) entries")

if length(cache) > 0
    println("\nFirst 3 token IDs:")
    for (i, (token_id, df)) in enumerate(collect(cache)[1:min(3, length(cache))])
        println("[$i] $(token_id[1:20])... → $(nrow(df)) rows")
    end
end
