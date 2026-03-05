"""
Macro contract filtering with expanded keywords.
No time-window collapsing (term structure is informative).
"""

module MacroFilter

const MACRO_KEYWORDS = [
    # Monetary policy
    "fed", "federal reserve", "fomc", "interest rate", "rate cut", "rate hike",
    "basis point", "bps", "monetary policy",
    # Inflation
    "inflation", "cpi", "pce", "core inflation", "price level", "deflation",
    # Growth & recession
    "gdp", "recession", "economic growth", "contraction",
    # Labor
    "unemployment", "jobless", "payroll", "nonfarm", "jobs report", "labor market",
    # Fiscal & government
    "government shutdown", "debt ceiling", "federal budget", "congress",
    "senate", "house", "fiscal", "spending bill",
    # Trade & tariffs
    "tariff", "trade war", "trade deal", "sanctions", "export", "import",
    # Geopolitical (macro-relevant)
    "ceasefire", "war", "conflict", "invasion", "military",
    # Elections (macro impact)
    "election", "presidential", "midterm", "senate race", "governor",
    # Markets (as macro indicators)
    "s&p 500", "spx", "nasdaq", "dow", "vix",
    # Commodities
    "oil price", "wti", "brent", "gold", "copper",
    # Currency
    "dollar", "dxy", "euro", "yuan", "exchange rate",
]

"""
    is_macro_contract(question::String) → Bool

Check if a contract question is macro-related.
"""
function is_macro_contract(question::String)
    q = lowercase(question)
    return any(kw -> occursin(kw, q), MACRO_KEYWORDS)
end

"""
    filter_macro_markets(df::DataFrame) → DataFrame

Filter DataFrame to only macro-related contracts.
"""
function filter_macro_markets(df)
    return filter(r -> is_macro_contract(r.question), df)
end

end # module
