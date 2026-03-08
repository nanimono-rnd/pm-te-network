"""
Family Collapse v3 - Optimized with groupby
"""

using DataFrames
using CSV
using Dates
using Statistics
using JSON3

function load_candles()
    candles = CSV.read("data/candlesticks_4h.csv", DataFrame)
    candles.datetime = DateTime.(candles.datetime, dateformat"yyyy-mm-dd HH:MM:SS")
    return candles
end

function classify_tickers(candles)
    tickers = unique(candles.ticker)
    
    families = Dict(
        "fed_rate" => String[],
        "cpi_inflation" => String[],
        "gdp" => String[],
        "unemployment" => String[],
        "recession" => String[],
        "shutdown" => String[],
        "tariff" => String[]
    )
    
    for ticker in tickers
        t = lowercase(ticker)
        
        if occursin(r"fed|fomc|rate", t)
            push!(families["fed_rate"], ticker)
        elseif occursin(r"cpi|inflation", t)
            push!(families["cpi_inflation"], ticker)
        elseif occursin("gdp", t)
            push!(families["gdp"], ticker)
        elseif occursin(r"unemployment|jobless|u3", t)
            push!(families["unemployment"], ticker)
        elseif occursin("recess", t)
            push!(families["recession"], ticker)
        elseif occursin("shutdown", t)
            push!(families["shutdown"], ticker)
        elseif occursin("tariff", t)
            push!(families["tariff"], ticker)
        end
    end
    
    filter!(p -> !isempty(p.second), families)
    families
end

# Optimized composite computation
function compute_composite_fast(tickers, candles)
    # Filter to family tickers only
    family_data = filter(r -> r.ticker in tickers, candles)
    
    if nrow(family_data) == 0
        return DataFrame(datetime=DateTime[], price=Float64[])
    end
    
    # Get end_date for each ticker
    end_dates = combine(groupby(family_data, :ticker), :datetime => maximum => :end_date)
    family_data = leftjoin(family_data, end_dates, on=:ticker)
    
    # Compute days_to_resolution
    family_data.days_to_res = [Dates.value(r.end_date - r.datetime) ÷ (1000*60*60*24) for r in eachrow(family_data)]
    
    # Filter: skip last 7 days
    family_data = filter(r -> r.days_to_res > 7, family_data)
    
    if nrow(family_data) == 0
        return DataFrame(datetime=DateTime[], price=Float64[])
    end
    
    # Compute weights
    family_data.weight = [1.0 / sqrt(max(d, 1)) for d in family_data.days_to_res]
    
    # Weighted average by datetime
    composite = combine(groupby(family_data, :datetime)) do df
        (price = sum(df.weight .* df.price) / sum(df.weight),)
    end
    
    sort!(composite, :datetime)
    composite
end

# Main
function main()
    println("Loading candlestick data...")
    candles = load_candles()
    println("  → $(nrow(candles)) bars, $(length(unique(candles.ticker))) tickers")
    
    println("\nClassifying tickers...")
    families = classify_tickers(candles)
    for (name, tickers) in families
        println("  $name: $(length(tickers)) tickers")
    end
    
    println("\n" * "="^50)
    println("Starting collapse (optimized)...")
    println("="^50 * "\n")
    
    composites = Dict{String, DataFrame}()
    for (name, tickers) in families
        println("Collapsing $name...")
        comp = compute_composite_fast(tickers, candles)
        if nrow(comp) > 0
            composites[name] = comp
            println("  → $(nrow(comp)) time points")
        end
    end
    
    println("\nFinal: $(length(composites)) composite nodes")
    
    # Save
    output = Dict(name => [(datetime=string(r.datetime), price=r.price) for r in eachrow(df)] 
                  for (name, df) in composites)
    
    open("data/composite_nodes.json", "w") do f
        JSON3.write(f, output)
    end
    
    println("Saved to data/composite_nodes.json")
end

main()

