include("src/data/gamma_api.jl")
using .PolymarketGammaAPI
using DataFrames

println("Testing Gamma API price fetching...")

# Get one active market
markets = PolymarketGammaAPI.fetch_markets(closed=false, limit=5)
println("Got $(length(markets)) markets")

if length(markets) > 0
    m = markets[1]
    println("\nTesting market: $(get(m, :question, "N/A"))")
    
    # Get token ID
    tokens = get(m, :tokens, [])
    if length(tokens) > 0
        token_id = String(tokens[1][:token_id])
        println("Token ID: $token_id")
        
        # Fetch price history
        println("\nFetching price history...")
        hist = PolymarketGammaAPI.fetch_price_history(token_id; interval="max", fidelity=240)
        println("Got $(nrow(hist)) rows")
        
        if nrow(hist) > 0
            println("First 3 rows:")
            println(first(hist, 3))
        end
    else
        println("No tokens found")
    end
else
    println("No markets returned")
end
