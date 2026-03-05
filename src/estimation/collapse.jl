"""
Event Family Collapse

Rules:
  1. Strip dates, months, bps values, percentages from question text
  2. Compute stem (normalized question without specifics)
  3. Group by stem → event family
  4. Per family, keep the token with most observations (most data)
  5. Return collapsed metadata and filtered token list
"""

module EventCollapse

using DataFrames
import Unicode

# ── text normalization ─────────────────────────────────────────────────────────

const MONTH_WORDS = ["january", "february", "march", "april", "may", "june",
                     "july", "august", "september", "october", "november", "december",
                     "jan", "feb", "mar", "apr", "jun", "jul", "aug", "sep", "oct",
                     "nov", "dec"]

const BPS_PATTERN = r"\d+\+?\s*bps"
const PCT_PATTERN = r"\d+\.?\d*\s*%"
const NUM_PATTERN = r"\b\d+\b"
const DATE_PATTERN = r"\b(20\d\d)\b"
const ORDINAL_PATTERN = r"\b(first|second|third|fourth|q1|q2|q3|q4|h1|h2)\b"

"""
    question_stem(q) → String

Strip all specifics from a question to get its "family stem".
Examples:
  "Will the Fed raise rates by 25 bps after its March meeting?" 
    → "will the fed raise rates after its meeting"
  "Will U.S. inflation be greater than 0.2% from August to September 2023?"
    → "will us inflation be greater than from to"
"""
function question_stem(q::String)
    s = lowercase(q)
    s = Unicode.normalize(s, :NFKC)

    # Remove months
    for m in MONTH_WORDS
        s = replace(s, Regex("\\b$m\\b") => "")
    end

    # Remove bps, percentages, years, numbers
    s = replace(s, BPS_PATTERN => "")
    s = replace(s, PCT_PATTERN => "")
    s = replace(s, DATE_PATTERN => "")
    s = replace(s, ORDINAL_PATTERN => "")
    s = replace(s, NUM_PATTERN => "")

    # Remove punctuation except spaces
    s = replace(s, r"[^\w\s]" => " ")

    # Collapse whitespace
    s = replace(s, r"\s+" => " ")
    s = strip(s)

    return s
end

# ── collapse ───────────────────────────────────────────────────────────────────

"""
    collapse_families(metadata::DataFrame) → DataFrame

Group contracts by question stem. Within each family, keep the representative
with the most observations. Returns a reduced DataFrame with one row per family.

Adds column: `family_stem` (the stem used for grouping), `family_size` (how many
contracts were collapsed), `family_members` (semicolon-joined list of all questions).
"""
function collapse_families(metadata::DataFrame)
    # Compute stems
    stems = [question_stem(r.question) for r in eachrow(metadata)]
    metadata_aug = copy(metadata)
    metadata_aug.stem = stems

    # Group by stem
    grouped = groupby(metadata_aug, :stem)

    result_rows = []
    for grp in grouped
        # Pick representative = highest n_obs
        best_idx = argmax(grp.n_obs)
        rep = grp[best_idx, :]

        push!(result_rows, (
            token_id       = rep.token_id,
            question       = rep.question,
            volume         = rep.volume,
            condition_id   = rep.condition_id,
            n_obs          = rep.n_obs,
            family_stem    = rep.stem,
            family_size    = nrow(grp),
            family_members = join(grp.question, " | "),
        ))
    end

    result = DataFrame(result_rows)

    # Sort by n_obs descending for readability
    sort!(result, :n_obs, rev=true)

    return result
end

end # module
