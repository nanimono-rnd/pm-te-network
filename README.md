# pm-te-network

Directed information flow networks in macro prediction markets. Identifies genuine belief propagation channels among 19 Kalshi composite nodes using scheduled announcements (FOMC, CPI, NFP) as natural experiments.

**Paper:** *Identifying Directed Belief Propagation in Macro Prediction Markets* (Yang, 2026)

## Requirements

- **Julia 1.9+** with packages: `CSV`, `DataFrames`, `Dates`, `Statistics`, `LinearAlgebra`, `StatsBase`, `JSON3`, `Plots`, `Random`
- Data: `data/candlesticks_4h.csv` (4h OHLCV bars from Kalshi API)

## Project Structure

```
src/
├── main_kalshi_te.jl              # Main pipeline (multithreaded, 32 threads)
├── viz_te.jl                      # 3-panel visualization
├── data/
│   ├── macro_filter.jl            # SERIES_FAMILY_MAP (ticker → family)
│   └── family_collapse.jl         # Composite node construction
├── estimation/
│   ├── te.jl                      # VAR(p) TE + permutation test (thread-safe)
│   ├── nodes.jl                   # Logit transform, grid alignment
│   └── rolling_window.jl          # Window config structs
├── identification/
│   ├── experiments.jl             # Exp 1,3,4: edge classification
│   ├── exp2_fomc_study.jl         # Exp 2: FOMC event-study
│   ├── exp5_robustness.jl         # Exp 5: placebo, window sensitivity
│   └── springrank.jl              # Information hierarchy
├── robustness/
│   ├── fdr_correction.jl          # Benjamini-Hochberg FDR
│   ├── nonoverlap_windows.jl      # Non-overlapping window check
│   ├── expanded_events.jl         # Expanded event calendar (+tariff/budget)
│   └── conditional_te.jl          # Conditional TE (top 3 confounders)
└── network/
    └── graph.jl                   # Network construction helpers
```

## Replicate Results

### 1. TE Pipeline

```bash
julia -t auto src/main_kalshi_te.jl
```

32 threads, ~10 min on Ryzen 9 8945HX. Produces 402 windows, 4,665 edges, 176 unique pairs.

| Parameter | Default | Description |
|-----------|---------|-------------|
| `WINDOW_DAYS` | 60 | Rolling window length |
| `STEP_DAYS` | 1 | Window step size |
| `MIN_ACTIVE` | 30 | Min active days per node per window |
| `VAR_LAG` | 1 | VAR lag order |
| `N_PERMS` | 500 | Permutation test shuffles |
| `ALPHA` | 0.01 | Significance level |

### 2. Identification Experiments

```bash
julia src/identification/experiments.jl        # Exp 1,3,4: edge classification
julia src/identification/exp2_fomc_study.jl    # Exp 2: FOMC event-study
julia -t auto src/identification/exp5_robustness.jl  # Exp 5: robustness
julia src/identification/springrank.jl         # SpringRank hierarchy
```

### 3. Robustness Suite

```bash
julia src/robustness/fdr_correction.jl                # BH FDR correction
julia -t auto src/robustness/nonoverlap_windows.jl    # Non-overlapping windows
julia src/robustness/expanded_events.jl               # +tariff/budget events
julia -t auto src/robustness/conditional_te.jl        # Conditional TE
```

### 4. Visualizations

```bash
julia src/viz_te.jl
```

Produces `data/results/figures/`: density time series, network triptych, hub evolution.

## Key Results

- **19** composite nodes from 4,003 Kalshi markets
- **176** unique directed edges, **62%** survive identification as genuine
- **3.4%** common-shock artifacts (vs >80% in equity networks)
- **148/176** edges survive Benjamini-Hochberg FDR at q=0.01
- **48/88** genuine edges survive conditional TE (top 3 confounders)

### Three Findings

1. **FOMC dynamics > rate decisions.** Markets extract more directional information from *how* the Fed deliberates than from *what* it decides.
2. **Tariffs as central relay.** Tariff expectations absorb monetary/fiscal signals and retransmit to growth, inflation, and political categories.
3. **Shutdown → tariffs → GDP.** Government shutdown risk is the dominant fiscal information source, but its growth effect is fully mediated by the tariff relay.

## Method

1. **Family collapse**: 2,900+ contracts → 19 composites (FAVAR-style weighted averages)
2. **Logit transform**: prices → log-odds with ε=0.01 clipping
3. **Rolling windows**: 60-day, sub-daily resolution (T≈1,100–1,400 per window, T/N≈129)
4. **Pairwise TE**: `TE(j→i) = ½ log(σ²_restricted / σ²_unrestricted)` from VAR(1)
5. **Permutation test**: block permutation (block_size=5), 500 shuffles, α=0.01
6. **Identification**: event-window decomposition + FOMC event-study + lead-lag asymmetry (triangulation)
7. **Conditional TE**: controls for top 3 network hubs; mediation analysis

## References

- Ottaviani & Sorensen (2015, AER) — differential underreaction mechanism
- Angrist & Pischke (2014) — quasi-experimental identification framework
- Bernanke, Boivin & Eliasz (2005, QJE) — FAVAR factor aggregation
- De Bacco et al. (2018) — SpringRank information hierarchy
- Schreiber (2000) — Transfer Entropy
- Yang (2026, SSRN 6282818) — TE network reliability audit
