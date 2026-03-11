# pm-te-network

Transfer Entropy networks across Kalshi prediction market contracts. Recovers directed information flow structure among macro belief composites using VAR-based TE with permutation testing.

## Requirements

- **Julia 1.9+** with packages: `CSV`, `DataFrames`, `Dates`, `Statistics`, `LinearAlgebra`, `StatsBase`, `JSON3`, `Plots`, `Random`
- Data: `data/candlesticks_4h.csv` (4h OHLCV bars from Kalshi API)

## Project Structure

```
src/
├── main_kalshi_te.jl              # Main pipeline (multithreaded)
├── viz_te.jl                      # 3-panel visualization
├── data/
│   ├── macro_filter.jl            # SERIES_FAMILY_MAP (ticker → family)
│   └── family_collapse.jl         # Composite node construction
├── estimation/
│   ├── te.jl                      # VAR(p) TE + permutation test
│   ├── nodes.jl                   # Logit transform, grid alignment
│   └── rolling_window.jl          # Window config structs
├── identification/
│   ├── experiments.jl             # Exp 1,3,4: edge classification
│   └── springrank.jl              # Information hierarchy
└── network/
    └── graph.jl                   # Network construction helpers
```

## Replicate Results

### 1. Run TE Pipeline

```bash
julia -t auto src/main_kalshi_te.jl
```

Uses all available CPU threads. On a 16-core Ryzen 9: ~3.5 minutes for 402 rolling windows.

**Config** (edit constants at top of `main_kalshi_te.jl`):

| Parameter | Default | Description |
|-----------|---------|-------------|
| `WINDOW_DAYS` | 60 | Rolling window length |
| `STEP_DAYS` | 1 | Window step size |
| `MIN_ACTIVE` | 30 | Min active days per node per window |
| `VAR_LAG` | 1 | VAR lag order |
| `N_PERMS` | 200 | Permutation test shuffles |
| `ALPHA` | 0.01 | Significance level |

**Output** → `data/results/`:
- `window_summary.csv` — per-window metrics (N, T, density, asymmetry)
- `edge_list.csv` — all significant directed edges with TE values
- `composites.csv` — 4h composite node prices
- `adjacency/` — per-window adjacency matrices

### 2. Generate Visualizations

```bash
julia src/viz_te.jl
```

**Output** → `data/results/figures/`:
- `density_timeseries.png` — network density over time with FOMC/CPI annotations
- `network_triptych.png` — quiet / normal / peak network snapshots
- `hub_evolution.png` — top hub out-degree evolution

### 3. Run Identification Experiments

```bash
julia src/identification/experiments.jl
```

Classifies each directed edge as: `genuine`, `common_shock`, `event_amplified`, `quiet_only`, or `noise` using event-window decomposition, lead-lag asymmetry, and hierarchical edge analysis.

**Output**: `data/results/classified_edges.csv`

### 4. Compute SpringRank Hierarchy

```bash
julia src/identification/springrank.jl
```

Compresses directed TE graph into 1D information hierarchy (De Bacco et al. 2018).

**Output**:
- `data/results/springrank_scores.csv` — node rankings (all vs clean network)
- `data/results/springrank_monthly.csv` — time-varying rankings

## Method

1. **Family collapse**: 2,900+ Kalshi contracts → 19 macro composite nodes via time-to-resolution weighted averages
2. **Logit transform**: prices (0-100 cents) → log-odds space with ε=0.01 clipping
3. **Rolling windows**: 60-day windows at 4h resolution (T≈1,100-1,400 bars per window)
4. **Pairwise TE**: `TE(j→i) = ½ log(σ²_restricted / σ²_unrestricted)` from VAR(1)
5. **Permutation test**: block permutation (block_size=5), 200 shuffles, α=0.01
6. **Identification**: event-window decomposition separates genuine information flow from common-shock differential response

## References

- Schreiber (2000) — Transfer Entropy definition
- Ottaviani & Sorensen (2015, AER) — differential underreaction mechanism
- De Bacco et al. (2018) — SpringRank
- Bernanke, Boivin & Eliasz (2005, QJE) — FAVAR factor aggregation
