include("src/data/gamma_api.jl")
using .PolymarketGammaAPI
using JSON3

println("Checking Gamma API market structure...")

markets = PolymarketGammaAPI.fetch_markets(closed=false, limit=3)
println("Got $(length(markets)) markets\n")

if length(markets) > 0
    m = markets[1]
    println("First market keys:")
    for key in keys(m)
        println("  $key: $(typeof(get(m, key, nothing)))")
    end
    
    println("\nFull first market:")
    println(JSON3.pretty(m))
end
