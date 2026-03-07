"""
Family Collapse for PM TE Network
Draft Section 3.3: Identification-driven collapse rules
"""

using JSON3
using DataFrames
using CSV
using Dates
using Statistics

# Load data
function load_data()
    markets = JSON3.read(read("data/all_series.json", String))
    candles = CSV.read("data/candlesticks_4h.csv", DataFrame)
    candles.t = DateTime.(candles.t)
    return markets, candles
end

# Filter macro markets
function filter_macro(markets)
    keywords = ["fed", "fomc", "rate", "inflation", "cpi", "gdp", 
                "recession", "unemployment", "jobless", "shutdown", "tariff"]
    
    filter(m -> any(kw -> occursin(kw, lowercase(get(m, :ticker, ""))) || 
                          occursin(kw, lowercase(get(m, :title, ""))), keywords), 
           markets)
end

# Identify families
function identify_families(macro_markets)
    families = Dict(
        "fed_rate" => [],
        "cpi_inflation" => [],
        "gdp" => [],
        "unemployment" => [],
        "recession" => [],
        "shutdown" => [],
        "tariff" => []
    )
    
    for m in macro_markets
        ticker = lowercase(get(m, :ticker, ""))
        title = lowercase(get(m, :title, ""))
        
        if occursin(r"fed|fomc|rate", ticker * title)
            push!(families["fed_rate"], m)
        elseif occursin(r"cpi|inflation", ticker * title)
            push!(families["cpi_inflation"], m)
        elseif occursin("gdp", ticker * title)
            push!(families["gdp"], m)
        elseif occursin(r"unemployment|jobless|u3", ticker * title)
            push!(families["unemployment"], m)
        elseif occursin("recess", ticker * title)
            push!(families["recession"], m)
        elseif occursin("shutdown", ticker * title)
            push!(families["shutdown"], m)
        elseif occursin("tariff", ticker * title)
            push!(families["tariff"], m)
        end
    end
    
    families
end

# Compute composite price (time-to-resolution weighted)
function compute_composite(members, candles)
    timestamps = unique(candles.t) |> sort
    composite = DataFrame(t=DateTime[], price=Float64[])
    
    for t in timestamps
        weighted_sum = 0.0
        weight_sum = 0.0
        
        for m in members
            ticker = get(m, :ticker, nothing)
            end_date = get(m, :end_date_iso, nothing)
            
            isnothing(ticker) || isnothing(end_date) && continue
            
            # Get price at time t
            rows = filter(r -> r.ticker == ticker && r.t == t, candles)
            isempty(rows) && continue
            
            price = rows[1, :c]
            
            # Weight by 1/sqrt(days_to_resolution)
            days_to_res = (DateTime(end_date) - t).value ÷ (1000*60*60*24)
            days_to_res ≤ 7 && continue  # Skip last 7 days
            days_to_res ≤ 0 && continue
            
            weight = 1.0 / sqrt(max(days_to_res, 1))
            weighted_sum += weight * price
            weight_sum += weight
        end
        
        weight_sum > 0 && push!(composite, (t=t, price=weighted_sum/weight_sum))
    end
    
    composite
end

# Main collapse function
function collapse_all(families, candles)
    composites = Dict{String, DataFrame}()
    
    for (name, members) in families
        isempty(members) && continue
        println("Collapsing $name: $(length(members)) markets...")
        
        comp = compute_composite(members, candles)
        if nrow(comp) > 0
            composites[name] = comp
            println("  → $(nrow(comp)) time points")
        end
    end
    
    composites
end

# Main execution
function main()
    println("Loading data...")
    markets, candles = load_data()
    
    println("Filtering macro markets...")
    macro = filter_macro(markets)
    println("  → $(length(macro)) macro markets")
    
    println("\nIdentifying families...")
    families = identify_families(macro)
    for (name, members) in families
        println("  $name: $(length(members)) markets")
    end
    
    println("\n" * "="^50)
    println("Starting family collapse...")
    println("="^50 * "\n")
    
    composites = collapse_all(families, candles)
    
    println("\nFinal composite nodes: $(length(composites))")
    
    # Save
    output = Dict(name => [(t=string(r.t), price=r.price) for r in eachrow(df)] 
                  for (name, df) in composites)
    
    open("data/composite_nodes.json", "w") do f
        JSON3.write(f, output)
    end
    
    println("Saved to data/composite_nodes.json")
end

main()

