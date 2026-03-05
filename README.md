# pm-te-network

**Directed Information Networks in Prediction Markets**

Estimating Transfer Entropy networks across Polymarket/Kalshi contracts to recover market-implied macro belief transmission graphs.

## Project structure

```
pm-te-network/
├── src/
│   ├── data/
│   │   └── polymarket.jl    # Polymarket CLOB API client
│   ├── estimation/
│   │   ├── nodes.jl         # Node construction (logit transform, event family collapse)
│   │   ├── var.jl           # VAR(p) estimation
│   │   └── te.jl            # Transfer Entropy + permutation test
│   ├── network/
│   │   └── graph.jl         # Network construction, centrality, visualization
│   └── main.jl              # Entry point
├── data/
│   ├── raw/                 # Raw API responses
│   └── processed/           # Cleaned N×T matrices
├── notebooks/               # Analysis and exploration
├── Project.toml
└── README.md
```

## Intellectual arc

1. **Paper 1** (ECoSta 2026 oral): Proved equity TE networks fail at T/N < 5
2. **Paper 2** (ECoSta 2026 oral): Information-theoretic impossibility barriers for VAR graph recovery
3. **This project**: Prediction markets as the natural habitat for TE

## Phase 1 checklist

- [ ] Polymarket CLOB API data pipeline
- [ ] Pilot cluster selection (Fed cycle 2025, ~30-50 contracts)
- [ ] Logit transform + event family collapse → N×T matrix
- [ ] VAR(p) estimation + TE computation
- [ ] Permutation test for edge significance
- [ ] T/N reliability diagnostic
- [ ] First network plot

## Data sources

- Polymarket CLOB API: `https://clob.polymarket.com`
- Kalshi REST API (later): `https://trading-api.kalshi.com`
