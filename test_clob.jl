using HTTP, JSON3

# Test CLOB API with token ID from Gamma
token_id = "75467129615908319583031474642658885479135630431889036121812713428992454630178"

println("Testing CLOB API prices-history...")
url = "https://clob.polymarket.com/prices-history"
params = "?market=$token_id&interval=max&fidelity=240"

try
    resp = HTTP.get(url * params)
    data = JSON3.read(String(resp.body))
    
    history = get(data, :history, [])
    println("Got $(length(history)) price points")
    
    if length(history) > 0
        println("\nFirst 3 points:")
        for (i, h) in enumerate(history[1:min(3, length(history))])
            println("  [$i] t=$(h.t), p=$(h.p)")
        end
    end
catch e
    println("Failed: $e")
end
