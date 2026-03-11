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
    # datetime is already String, parse it
    candles.datetime = DateTime.(candles.datetime, dateformat"yyyy-mm-dd HH:MM:SS")
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

# Identify families (20-25 nodes, event-driven)
function identify_families(macro_markets)
    families = Dict(
        # Economics (8-10 nodes)
        "fed_cut" => [],
        "fed_hike" => [],
        "fed_rate_bracket" => [],
        "recession" => [],
        "gdp_growth" => [],
        "unemployment" => [],
        "cpi_inflation" => [],
        "debt_ceiling" => [],
        
        # Politics (6-8 nodes)
        "pres_approval" => [],
        "house_control" => [],
        "senate_control" => [],
        "gov_shutdown" => [],
        "candidate_1" => [],
        "candidate_2" => [],
        
        # Geopolitical (5-7 nodes)
        "russia_ukraine" => [],
        "china_taiwan" => [],
        "us_china_tariff" => [],
        "iran_mideast" => [],
        "trade_deal" => []
    )
    
    for m in macro_markets
        ticker = lowercase(get(m, :ticker, ""))
        title = lowercase(get(m, :title, ""))
        text = ticker * " " * title
        
        # Economics
        if occursin(r"rate cut|decrease|lower", text) && occursin(r"fed|fomc", text)
            push!(families["fed_cut"], m)
        elseif occursin(r"rate hike|increase|raise", text) && occursin(r"fed|fomc", text)
            push!(families["fed_hike"], m)
        elseif occursin(r"fed.*rate|fomc", text) && !occursin(r"cut|hike", text)
            push!(families["fed_rate_bracket"], m)
        elseif occursin("recess", text)
            push!(families["recession"], m)
        elseif occursin("gdp", text)
            push!(families["gdp_growth"], m)
        elseif occursin(r"unemployment|jobless|u3", text)
            push!(families["unemployment"], m)
        elseif occursin(r"cpi|inflation", text)
            push!(families["cpi_inflation"], m)
        elseif occursin(r"debt ceiling|debt limit", text)
            push!(families["debt_ceiling"], m)
        
        # Politics
        elseif occursin(r"approval|rating", text) && occursin(r"president|biden|trump", text)
            push!(families["pres_approval"], m)
        elseif occursin(r"house|congress", text) && occursin(r"control|majority", text)
            push!(families["house_control"], m)
        elseif occursin("senate", text) && occursin(r"control|majority", text)
            push!(families["senate_control"], m)
        elseif occursin("shutdown", text)
            push!(families["gov_shutdown"], m)
        
        # Geopolitical
        elseif occursin(r"russia|ukraine|putin|zelensky", text)
            push!(families["russia_ukraine"], m)
        elseif occursin(r"china.*taiwan|taiwan.*china|strait", text)
            push!(families["china_taiwan"], m)
        elseif occursin("tariff", text) && occursin("china", text)
            push!(families["us_china_tariff"], m)
        elseif occursin(r"iran|israel|gaza|mideast|middle east", text)
            push!(families["iran_mideast"], m)
        elseif occursin(r"trade.*deal|trade.*agreement|fta", text)
            push!(families["trade_deal"], m)
        end
    end
    
    # Remove empty families
    filter!(p -> !isempty(p.second), families)
    
    families
end

# Compute composite price (time-to-resolution weighted)
function compute_composite(members, candles)
    # First, get end_date for each ticker from candlestick data
    ticker_end_dates = Dict{String, DateTime}()
    for ticker in unique(candles.ticker)
        ticker_data = filter(r -> r.ticker == ticker, candles)
        if !isempty(ticker_data)
            ticker_end_dates[ticker] = maximum(ticker_data.datetime)
        end
    end
    
    println("  DEBUG: ticker_end_dates size = $(length(ticker_end_dates))")
    println("  DEBUG: members tickers = ", [get(m, :ticker, "N/A") for m in members[1:min(3, length(members))]])
    
    timestamps = unique(candles.datetime) |> sort
    composite = DataFrame(datetime=DateTime[], price=Float64[])
    
    valid_count = 0
    for t in timestamps
        weighted_sum = 0.0
        weight_sum = 0.0
        
        for m in members
            ticker = get(m, :ticker, nothing)
            isnothing(ticker) && continue
            
            # Get end_date from candlestick data
            end_date = get(ticker_end_dates, ticker, nothing)
            if isnothing(end_date)
                continue
            end
            
            # Get price at time t
            rows = filter(r -> r.ticker == ticker && r.datetime == t, candles)
            if isempty(rows)
                continue
            end
            
            price = rows[1, :price]
            
            # Weight by 1/sqrt(days_to_resolution)
            days_to_res = Dates.value(end_date - t) ÷ (1000*60*60*24)
            if days_to_res ≤ 7 || days_to_res ≤ 0
                continue
            end
            
            weight = 1.0 / sqrt(max(days_to_res, 1))
            weighted_sum += weight * price
            weight_sum += weight
            valid_count += 1
        end
        
        if weight_sum > 0
            push!(composite, (datetime=t, price=weighted_sum/weight_sum))
        end
    end
    
    println("  DEBUG: valid_count = $valid_count, composite rows = $(nrow(composite))")
    
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
    macro_markets = filter_macro(markets)
    println("  → $(length(macro_markets)) macro markets")
    
    println("\nIdentifying families...")
    families = identify_families(macro_markets)
    for (name, members) in families
        println("  $name: $(length(members)) markets")
    end
    
    println("\n" * "="^50)
    println("Starting family collapse...")
    println("="^50 * "\n")
    
    composites = collapse_all(families, candles)
    
    println("\nFinal composite nodes: $(length(composites))")
    
    # Save
    output = Dict(name => [(datetime=string(r.datetime), price=r.price) for r in eachrow(df)] 
                  for (name, df) in composites)
    
    open("data/composite_nodes.json", "w") do f
        JSON3.write(f, output)
    end
    
    println("Saved to data/composite_nodes.json")
end

main()

