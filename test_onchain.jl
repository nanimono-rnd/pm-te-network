"""
Test fetching Polymarket trade data from Polygon blockchain via Alchemy.

Polymarket uses Conditional Token Framework (CTF) on Polygon.
Contract: 0x4D97DCd97eC945f40cF65F87097ACe5EA0476045 (CTF Exchange)

We need to fetch Transfer events to reconstruct price history.
"""

using HTTP, JSON3, Dates

# Alchemy Polygon endpoint (you need an API key)
# Get free key at: https://www.alchemy.com/
ALCHEMY_KEY = "demo"  # Replace with real key
ALCHEMY_URL = "https://polygon-mainnet.g.alchemy.com/v2/$ALCHEMY_KEY"

# CTF Exchange contract
CTF_EXCHANGE = "0x4D97DCd97eC945f40cF65F87097ACe5EA0476045"

# Example token ID from earlier
TOKEN_ID = "0xa67e71296196199083031474642658885479135630431889036121812713428992454630178"

println("Testing Polygon blockchain data fetch...")
println("Token ID: $(TOKEN_ID[1:20])...")

# Construct eth_getLogs request
# Get Transfer events for this token in last 1000 blocks
params = Dict(
    "jsonrpc" => "2.0",
    "id" => 1,
    "method" => "eth_getLogs",
    "params" => [Dict(
        "address" => CTF_EXCHANGE,
        "fromBlock" => "latest",
        "toBlock" => "latest",
        "topics" => [
            "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef",  # Transfer event signature
            nothing,
            nothing,
            TOKEN_ID
        ]
    )]
)

try
    resp = HTTP.post(ALCHEMY_URL, 
        ["Content-Type" => "application/json"],
        JSON3.write(params))
    
    result = JSON3.read(String(resp.body))
    
    if haskey(result, :result)
        logs = result.result
        println("Got $(length(logs)) transfer events")
        
        if length(logs) > 0
            println("\nFirst event:")
            println("  Block: $(logs[1].blockNumber)")
            println("  TxHash: $(logs[1].transactionHash)")
        end
    else
        println("Error: $(get(result, :error, "Unknown"))")
    end
catch e
    println("Failed: $e")
    println("\nNote: You need a real Alchemy API key.")
    println("Get one at: https://www.alchemy.com/")
end
