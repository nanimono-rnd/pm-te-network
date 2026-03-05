using HTTP, JSON3

# Test 1: Active markets
println("=== ACTIVE MARKETS ===")
url1 = "https://gamma-api.polymarket.com/markets?closed=false&limit=5"
resp1 = HTTP.get(url1)
data1 = JSON3.read(String(resp1.body))
println("Total: ", length(data1))
for (i, m) in enumerate(data1[1:min(3, length(data1))])
    println("\n[$i] $(get(m, :question, "N/A"))")
    println("    End date: $(get(m, :end_date_iso, "N/A"))")
    println("    Volume: $(get(m, :volume, 0))")
end

# Test 2: Check if there's a date filter
println("\n\n=== TESTING DATE FILTER ===")
try
    url2 = "https://gamma-api.polymarket.com/markets?closed=true&end_date_min=2024-01-01&limit=5"
    resp2 = HTTP.get(url2)
    data2 = JSON3.read(String(resp2.body))
    println("With date filter: ", length(data2), " markets")
    if length(data2) > 0
        println("First market end date: ", get(data2[1], :end_date_iso, "N/A"))
    end
catch e
    println("Date filter not supported: $e")
end
