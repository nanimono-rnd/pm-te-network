"""
    MacroFilter — curated series for 21-node TE network (Draft Section 3.3).

Node decomposition:
  Monetary (5): fed_rate_level, fed_rate_path, fomc_dynamics, fed_leadership, fed_gov_confidence
  Inflation (3): headline_cpi, core_cpi_pce, cpi_subcomponents
  Growth/Employment (2): gdp, jobless_claims
  Fiscal (2): gov_shutdown, debt_funding
  Tariff/Trade (4): china_tariff_rate, china_policy, global_tariffs, congress_tariff
  Political (4): potus_approval, potus_social, congress_narrative, congress_investigations
  Equity (1): nasdaq_targets
"""
module MacroFilter

const SERIES_FAMILY_MAP = Dict{String,String}(
    # ── Monetary: Node 1 — Fed rate level ───────────────────────────────
    "FED"                 => "fed_rate_level",
    "KXFEDDECISION"       => "fed_rate_level",

    # ── Monetary: Node 2 — Fed rate path/cuts ───────────────────────────
    "KXRATECUTCOUNT"      => "fed_rate_path",
    "KXFEDCOMBO"          => "fed_rate_path",
    "KXZERORATE"          => "fed_rate_path",

    # ── Monetary: Node 3 — FOMC internal dynamics ──────────────────────
    "KXFOMCDISSENTCOUNT"  => "fomc_dynamics",
    "KXFEDDISSENT"        => "fomc_dynamics",
    "KXFOMCVOTE"          => "fomc_dynamics",

    # ── Monetary: Node 4 — Fed leadership ──────────────────────────────
    "KXFEDCHAIRNOM"       => "fed_leadership",
    "KXPRESNOMFEDCHAIR"   => "fed_leadership",
    "KXFEDGOVNOM"         => "fed_leadership",

    # ── Monetary: Node 5 — Fed-government confidence ───────────────────
    "KXCONFFEDGOV"        => "fed_gov_confidence",

    # ── Inflation: Node 6 — Headline CPI ───────────────────────────────
    "KXCPI"               => "headline_cpi",
    "KXCPIYOY"            => "headline_cpi",
    "KXCPICOMBO"          => "headline_cpi",
    "KXACPI"              => "headline_cpi",
    "KXECONSTATCPI"       => "headline_cpi",
    "KXECONSTATCPIYOY"    => "headline_cpi",

    # ── Inflation: Node 7 — Core CPI/PCE ───────────────────────────────
    "KXCPICORE"           => "core_cpi_pce",
    "KXCPICOREYOY"        => "core_cpi_pce",
    "KXCPICOREA"          => "core_cpi_pce",
    "KXPCECORE"           => "core_cpi_pce",
    "KXECONSTATCPICORE"   => "core_cpi_pce",
    "KXECONSTATCORECPIYOY"=> "core_cpi_pce",

    # ── Inflation: Node 8 — CPI sub-components ─────────────────────────
    "KXCPIGAS"            => "cpi_subcomponents",
    "KXCPISHELTER"        => "cpi_subcomponents",
    "KXCPIUSEDCAR"        => "cpi_subcomponents",
    "KXCPIAPPAREL"        => "cpi_subcomponents",

    # ── Growth: Node 9 — GDP ───────────────────────────────────────────
    "KXGDP"               => "gdp",

    # ── Employment: Node 10 — Jobless claims ───────────────────────────
    "KXJOBLESSCLAIMS"     => "jobless_claims",

    # ── Fiscal: Node 11 — Government shutdown ──────────────────────────
    "KXGOVSHUT"           => "gov_shutdown",
    "KXGOVSHUTLENGTH"     => "gov_shutdown",

    # ── Fiscal: Node 12 — Debt/funding ─────────────────────────────────
    "KXDEBTGROWTH25"      => "debt_funding",
    "KXDEBTLEVEL"         => "debt_funding",
    "KXDEBTBRAKE"         => "debt_funding",
    "KXHOUSEGOVTFUND"     => "debt_funding",

    # ── Tariff: Node 13 — China tariff rate ────────────────────────────
    "KXTARIFFRATEPRC"     => "china_tariff_rate",
    "KXTARIFFENDPRC"      => "china_tariff_rate",
    "KXTRADEDEALPRC"      => "china_tariff_rate",

    # ── Tariff: Node 14 — China policy ─────────────────────────────────
    "KXCBDECISIONCHINA"   => "china_policy",
    "KXCHINAUNRUBIO"      => "china_policy",
    "KXUSAMBCHINA"        => "china_policy",

    # ── Tariff: Node 15 — Global/other tariffs ─────────────────────────
    "KXFOREIGNTARIFF"     => "global_tariffs",
    "KXAVGTARIFF"         => "global_tariffs",
    "KXTARIFFCAN"         => "global_tariffs",
    "KXTARIFFRATECAN"     => "global_tariffs",
    "KXTARIFFRATEINDIA"   => "global_tariffs",
    "KXEUTARIFFSIZE"      => "global_tariffs",

    # ── Tariff: Node 16 — Congressional tariff action ──────────────────
    "KXSENATETARIFFVOTE"  => "congress_tariff",
    "KXUNDOTARIFFVOTE"    => "congress_tariff",

    # ── Political: Node 17 — Presidential approval ─────────────────────
    "KXAPRPOTUS"          => "potus_approval",
    "KXAPRPOTUSEOY"       => "potus_approval",

    # ── Political: Node 18 — Presidential social media ─────────────────
    "KXPOTUSTWEETS"       => "potus_social",

    # ── Political: Node 19 — Congressional narrative/mentions ──────────
    "KXCONGRESSMENTION"   => "congress_narrative",
    "KXFEDMENTION"        => "congress_narrative",
    "KXFEDGOVMENTION"     => "congress_narrative",

    # ── Political: Node 20 — Congressional investigations ──────────────
    "KXHOUSEEPSTEIN"      => "congress_investigations",
    "KXHOUSEEPSTEIN2"     => "congress_investigations",
    "KXSENATEEPSTEIN"     => "congress_investigations",
    "KXCONGRESSTESTIFY"   => "congress_investigations",

    # ── Equity: Node 21 — Nasdaq targets (includes min-year) ──────────
    "KXNASDAQ100"         => "nasdaq_targets",
    "KXNASDAQ100Y"        => "nasdaq_targets",
    "KXNASDAQ100MINY"     => "nasdaq_targets",
)

macro_series_tickers() = collect(keys(SERIES_FAMILY_MAP))

function family_for_series(series_ticker::String)
    return get(SERIES_FAMILY_MAP, uppercase(series_ticker),
               get(SERIES_FAMILY_MAP, series_ticker, "unclassified"))
end

function filter_macro_series(all_series)
    targets = Set(uppercase.(keys(SERIES_FAMILY_MAP)))
    return filter(s -> uppercase(string(get(s, :ticker, ""))) in targets, all_series)
end

end # module
