# Prediction Market Transfer Entropy Network

## Comprehensive Project Summary

**Haotian Yang (Sora)**
BEMACS, Bocconi University

March 11, 2026

## Contents

1. Project Overview and Intellectual Arc
2. Theoretical Foundations
3. Feedback from Senior Scholars
4. What Has Been Done
5. Current Results
6. Identification Strategy Results
7. Paper Structure: Economics Paper vs. Quant Paper
8. Future Extensions and Applications
9. Acknowledgments and Feedback
10. Timeline and Priorities

---

## 1. Project Overview and Intellectual Arc

This project estimates Transfer Entropy (TE) networks across prediction market contracts on Kalshi to recover the directed predictive structure of macro belief dynamics. The core insight is that prediction markets — where each contract price is a named event probability — provide a setting where TE edges have clean economic interpretation, manageable dimensionality, and known event timing that enables identification of edge meaning.

### 1.1 The Four-Paper Arc

| # | Paper | Contribution | Status |
|---|-------|-------------|--------|
| 1 | TE Network Audit (solo, ECoSta 2026) | OLS-TE precision <17% at published T/N ratios; 7 papers operate in unreliable regimes. SSRN 6282818. | Accepted (oral) |
| 2 | Minimax Bounds (w/ Yifeng Li, ECoSta) | Information-theoretic lower bounds for VAR graph recovery. Lemma 4: RE guarantee for block subsamples of stable Gaussian VAR(1). | Accepted (oral) |
| 3 | PM-TE: Identification + Economic Value | Decompose TE edges into genuine information flow vs. common shock. Macro narrative detection. TE is tool, not novelty. | **In progress (this project)** |
| 4 | PM-TE: Quant Applications | Cross-contract hedging, SpringRank hierarchy, ETF bridge nodes, neural TE comparison. | Planned |

Logic chain: Discover estimation failure (Paper 1) → Prove it's fundamental (Paper 2) → Propose correct setting + solve identification (Paper 3) → Demonstrate economic and quantitative value (Paper 4).

### 1.2 Key Strategic Decision: Two-Paper Split

Based on feedback from Professor Ottaviani (Bocconi, met March 10): TE is not mainstream in economics. The project is therefore split into two papers with different audiences:

**Paper 1 (Economics):** Lead with identification framework and economic findings. TE is merely the estimation tool — the contribution is the quasi-experimental decomposition of directed financial network edges and the economic interpretation (macro narrative detection, regime signals, belief propagation maps). Target: *Quantitative Finance* or *Journal of Financial Econometrics*.

**Paper 2 (Quantitative):** Lead with applications — network-informed cross-contract hedging (Avellaneda-Stoikov extension), SpringRank information hierarchy for market-making quoting priority, ETF bridge node validation, linear vs. neural TE comparison. Target: *Quantitative Finance* or arXiv q-fin.

---

## 2. Theoretical Foundations

### 2.1 Transfer Entropy

TE measures directed information flow: $\text{TE}(X \to Y) = I(Y_t;\, X_{<t} \mid Y_{<t})$. In words: how much does knowing $X$'s past reduce uncertainty about $Y$'s future, beyond what $Y$'s own past tells you? A significant TE edge from contract A to contract B means A's price history contains predictive information for B's future price, conditional on B's own history. In the linear Gaussian case, this is algebraically equivalent to Granger causality with a log-ratio formulation:

$$\text{TE}(j \to i) = \tfrac{1}{2} \log \frac{\sigma^2_{i|i}}{\sigma^2_{i|i,j}}$$

### 2.2 Why Prediction Markets Are TE's Natural Setting

In equity markets, TE edges are uninterpretable — "Stock A → Stock B" conflates fundamental linkages, attention spillover, and common factor exposure. Our Paper 1 shows >80% of detected edges are spurious at typical sample sizes. Prediction markets resolve this: (1) each price is a named event probability — edges have clean semantic meaning; (2) $N$ is naturally small (~20 nodes) — estimation stays in reliable $T/N$ regime; (3) scheduled announcements provide exogenous shocks with known timing — enables identification.

### 2.3 The Identification Problem (Ottaviani-Sørensen Mechanism)

Even in prediction markets, TE edges may reflect differential processing speed under common shocks rather than genuine information flow. The theoretical mechanism is from Ottaviani & Sørensen (2015, AER lead article): in a binary market with heterogeneous prior beliefs, prices underreact to public information. The degree of underreaction depends on belief heterogeneity (their parameter $\gamma$). When an FOMC announcement hits both a "Fed rate" contract and a "Recession" contract, each adjusts at a speed determined by its trader population's belief heterogeneity and liquidity. TE detects this speed differential as a directed edge — but it's differential underreaction, not genuine information propagation.

Our identification framework exploits the known timing of scheduled macro announcements to decompose TE edges into genuine information flow vs. common-shock differential response. This is a quasi-experimental design inspired by Angrist & Pischke (2014) *Mastering Metrics*, recommended by Professor Zitzewitz (Dartmouth).

### 2.4 Factor Aggregation (Family Collapse)

Multiple contracts reference the same macro concept at different expiries/strikes. Following Bernanke, Boivin & Eliasz (2005, QJE) FAVAR logic — individual series are noisy measurements of latent macro concepts — we collapse contracts into composites via time-to-resolution weighted averages. Categories follow Stock & Watson (2016) standard macro variable classification. Family collapse is the first line of identification: it eliminates within-family spurious edges before estimation.

### 2.5 Key Literature

| Paper | Relevance to Project |
|-------|---------------------|
| Ottaviani & Sørensen (2015) AER | Theoretical mechanism for differential underreaction → why spurious TE edges arise from common shocks |
| Ottaviani & Sørensen (2010) AEJ:Micro | Favorite-longshot bias from noise vs. information → affects logit-space TE at extreme probabilities |
| Bergemann & Ottaviani (2021) HIO Ch.8 | Survey of information markets — gap: no cross-contract information dynamics or network perspective |
| Angrist & Pischke (2014) | Quasi-experimental identification framework → DiD/event-study design for edge decomposition |
| Bernanke, Boivin & Eliasz (2005) QJE | FAVAR: factor aggregation of macro series → justifies family collapse methodology |
| Stock & Watson (2016) HoM | DFM variable categories → standard grouping for composites |
| Billio et al. (2012) JFE | Equity Granger networks → our Paper 1 audits this literature |
| Diebold & Yilmaz (2014) | Connectedness framework → no identification of edge meaning |
| Dalen (2025) arXiv | Logit jump-diffusion for PMs → calibration for hedging extension |
| De Bacco et al. (2018) | SpringRank → compress TE network into information hierarchy |

---

## 3. Feedback from Senior Scholars

### 3.1 Eric Zitzewitz (Dartmouth) — Two Email Exchanges

**Feedback 1:**

> "Teasing out causal relationships from correlations is of course a huge endeavor. I use the book Mastering Metrics with my students."

**Impact:** Introduced quasi-experimental thinking (Angrist-Pischke) into our identification framework. We now use scheduled macro announcements as natural experiments rather than relying solely on permutation tests.

**Feedback 2:**

> "Even with event probabilities, sorting out the causal relationships is non-trivial. For example, suppose 'Trump to win' and 'Trump to win PA' both rise on the same day. Was that due to a poll in PA? A national poll? Or maybe a poll in MI?"

**Impact:** Crystallized the common-shock identification problem. Led to our edge taxonomy (common shock / genuine / event-amplified / quiet-only). Also led to re-thinking family collapse as the first line of identification — hierarchically nested contracts must be collapsed to avoid trivially significant edges.

Zitzewitz also suggested contacting Marco Ottaviani at Bocconi and recommended framing edges as "directed predictive associations" rather than making causal claims.

### 3.2 Marco Ottaviani (Bocconi) — In-Person Meeting, March 10

Met for 1 hour in his office. He was not familiar with Transfer Entropy — we searched Google Scholar together and found no mainstream economics applications. His key feedback:

**(1) TE will be hard to get recognized by mainstream economics.** It comes from physics/information theory (Schreiber 2000) and has been applied mainly in complexity science journals (*Entropy*, *Physica A*), not AER/QJE/JFE. This motivated the two-paper split: Paper 1 must lead with identification and economics, treating TE as a tool.

**(2) Don't rush to publish.** He emphasized that serious papers take years of polishing. Advice taken — we will ensure identification results are thorough and robust before submitting.

**Status:** Not an advisor or collaborator for this project (expertise mismatch on TE), but the relationship is open. Will follow up when identification results are ready — the identification framework itself is economics, even if TE is not.

### 3.3 Synthesis: How Feedback Shaped the Project

Zitzewitz gave us the identification problem. Ottaviani's AER 2015 gives the theoretical mechanism behind the problem. Angrist-Pischke gives the toolkit to solve it. Ottaviani's advice to not rush and to lead with economics rather than TE reshaped the paper strategy. The project is now fundamentally about identification, with TE as an estimation method.

---

## 4. What Has Been Done

### 4.1 Data Pipeline (COMPLETE)

| Component | Detail | Status |
|-----------|--------|--------|
| Kalshi market fetch | 4,003 macro markets, 2+ years of data | Done |
| Candlestick data | 2,921 markets with price data | Done |
| 1h bars | 283,504 raw hourly bars | Done |
| 4h bar aggregation | 149,425 aggregated bars | Done |
| Storage | All saved to CSV | Done |

### 4.2 Family Collapse (COMPLETE)

157 Kalshi series collapsed into **19 active composite nodes** (21 designed; cpi_subcomponents and potus_social dropped for thin data; congress_tariff dropped below 50-point threshold).

| Category | Nodes | Key Series |
|----------|-------|------------|
| Monetary (5) | fed_rate_level, fed_rate_path, fomc_dynamics, fed_leadership, fed_gov_confidence | FED, KXFEDDECISION, KXRATECUTCOUNT |
| Inflation (2) | headline_cpi, core_cpi_pce | KXCPI, KXCPIYOY, KXCPICORE, KXPCECORE |
| Growth (2) | gdp, jobless_claims | KXGDP, KXJOBLESSCLAIMS |
| Fiscal (2) | gov_shutdown, debt_funding | KXGOVSHUT, KXDEBTGROWTH25 |
| Tariff (3) | china_tariff_rate, china_policy, global_tariffs | KXTARIFFRATEPRC, KXFOREIGNTARIFF |
| Political (3) | potus_approval, congress_narrative, congress_investigations | KXAPRPOTUS, KXCONGRESSMENTION |
| Equity (1) | nasdaq_targets (merged with nasdaq_min_year) | KXNASDAQ100 |

**Ticker alignment:** Metadata tickers are series-level ('FED'), candlestick tickers are contract-level ('FED-25JUL-T4.25'). Alignment via `series = ticker.split('-')[0]` — 157/157 prefixes match.

### 4.3 TE Estimation Pipeline (COMPLETE — Multithreaded)

| Parameter | Value |
|-----------|-------|
| Resolution | **4-hour bars** |
| Window | 60 days, step=1 day |
| MinActive | 30 days per node per window |
| Transform | Logit: $z = \log(p/(1-p))$ |
| Model | VAR(1), linear Gaussian TE |
| Significance | Permutation test, 200 shuffles, $\alpha = 0.01$ |
| Implementation | Julia, **32 threads** (window-level parallelism) |
| Runtime | **~3.5 minutes** on Ryzen 9 8945HX (vs. ~3 hours single-threaded) |

**Threading details:** Window-level parallelism via `Threads.@threads` with per-task RNG (`MersenneTwister` seeded by task index for reproducibility). Restricted model cached across permutations (halves OLS calls). Pre-allocated buffers for zero-allocation permutation hot loop.

### 4.4 Identification Experiments (COMPLETE — Experiments 1, 3, 4)

| Experiment | Method | Status |
|------------|--------|--------|
| 1. Event-Window Decomposition (CORE) | Split windows by FOMC/CPI/NFP event density (median split). Bootstrap $\Delta$TE. | **Done** |
| 2. FOMC Event-Study | TE in $\pm$10-day mini-windows around each FOMC | Planned |
| 3. Lead-Lag Asymmetry | $\text{AR} = (\text{TE}(A \to B) - \text{TE}(B \to A)) / \text{sum}$ | **Done** |
| 4. Hierarchical Edge Analysis | Flag logically nested pairs. $\text{HER} = \text{hierarchical} / \text{total}$ | **Done** |
| 5. Placebo & Robustness | Random event dates, window sensitivity, $\alpha$ threshold | Planned |

### 4.5 SpringRank Hierarchy (COMPLETE)

SpringRank (De Bacco et al. 2018) computed on both raw and identification-cleaned networks. Monthly time-varying rankings produced.

### 4.6 Visualizations Produced

(1) Network density time series with FOMC/CPI event markers and $N$ color-coding. (2) Hub out-degree evolution over time showing narrative regime shifts. (3) Network triptych: quiet (1 edge), normal (8 edges), peak (71 edges) snapshots. All figures available as high-resolution PNGs.

### 4.7 Documents Produced

research_summary.docx (cold email pitch), project_draft_v3.md (full execution plan with identification module and 5 experiment designs), project_summary_ottaviani.md (academic summary connecting to Ottaviani's work), presentation PDF (15-slide landscape deck), project_memory_export.md (complete state dump for continuity).

---

## 5. Current Results

### 5.1 Summary Statistics (4h Resolution, Primary Regime, $N \geq 8$)

| Metric | Value |
|--------|-------|
| Total windows estimated | **402** (341 in primary regime) |
| Significant directed edges | **4,579** |
| Avg asymmetry (primary) | **0.686** |
| Avg edges/window (primary) | **12.3** |
| Avg density (primary) | **11.9%** |
| Avg $T/N$ ratio (primary) | **128.8** |
| Peak density | **~39%** in Nov 2025 (W441–453, $N = 14$) |
| Top information senders | global_tariffs (738), gov_shutdown (714), fed_rate_level (395) |
| Top information receivers | congress_narrative (488), headline_cpi (474), gdp (464) |

### 5.2 Secondary Regime ($N < 8$)

| Metric | Value |
|--------|-------|
| Windows | 61 |
| $N$ range | 3–7 |
| Avg $T/N$ | 157.6 |
| Avg density | 21.6% |
| Avg asymmetry | 0.718 |
| Top senders | global_tariffs (91), gov_shutdown (89), core_cpi_pce (65) |
| Top receivers | headline_cpi (98), fed_rate_path (63), gov_shutdown (62) |

### 5.3 Estimation Reliability

With 4h resolution, $T/N \approx 129$ in the primary regime — well above the reliability threshold established in Paper 1 ($T/N \geq 20$). Every single primary window produces significant edges (100% hit rate), compared to ~56% at daily resolution. The 4h resolution was the key methodological decision: $T$ jumps from ~60 (daily) to ~1,100–1,400 (4h), increasing precision by an order of magnitude.

| Resolution | Avg $T/N$ | Avg density | Edges | Windows w/ edges |
|------------|-----------|-------------|-------|-----------------|
| Daily | ~4.6 | ~2.0% | ~821 | ~56% |
| **4-hour** | **128.8** | **11.9%** | **4,579** | **100%** |

### 5.4 Key Structural Finding: Tariffs as Information Relay

Global tariffs is simultaneously a top sender (738 outgoing edges) and a major receiver. The network asymmetry of 0.686 indicates substantial bidirectional flow — tariffs is an **information relay node**, absorbing signals from monetary/growth contracts (fed_rate_level, gdp → tariffs) and transmitting them to political/trade contracts (tariffs → china_tariff_rate, congress_narrative, potus_approval). This relay structure is not predictable from single-market theory (Ottaviani-Sørensen 2015 models individual markets in isolation).

### 5.5 Temporal Dynamics

Network density shows a clear regime shift in late 2025 coinciding with tariff escalation — density rises from ~5–10% to ~39%. Hub evolution reveals a **narrative regime shift**: Fed Rate, GDP, and Shutdown alternate as information leaders through most of 2025; tariffs suddenly dominates from ~October 2025 (out-degree peaks at 10+). This is an automated macro narrative detector.

---

## 6. Identification Strategy Results

### 6.1 Experiment 1: Event-Window Decomposition (CORE)

**Method:** Event calendar of 69 scheduled macro announcements (18 FOMC, 26 CPI, 26 NFP). For each rolling window, count events falling within the window. Median split (median = 5 events): 159 high-event windows, 243 low-event windows. For each unique directed edge, classify by where it appears.

**Bootstrap $\Delta$TE:** For edges appearing $\geq 3$ times in each regime, 1,000-iteration bootstrap test for significant difference in mean TE between high-event and low-event windows ($p < 0.05$).

### 6.2 Edge Classification Results

| Classification | Count | Avg Persistence | Interpretation |
|---------------|-------|----------------|----------------|
| **genuine** | 86 | 36.2 | Real information channels — persistent in both event and quiet windows |
| **genuine_symmetric** | 10 | 39.2 | Bidirectional flow — possible common factor |
| **quiet_only** | 44 | 11.8 | Slow-burn flow masked by event noise |
| **event_amplified** | 9 | 21.3 | Real channel amplified during macro events |
| **hierarchical_genuine** | 7 | 46.4 | Within-concept edges (e.g., core CPI ↔ headline CPI) |
| **common_shock** | 6 | 3.5 | Differential underreaction speed (Ottaviani-Sørensen mechanism) |
| **noise** | 14 | 1.0 | Statistical artifacts ($\leq 1$ window) |

**Key result: 63.3% of edges survive identification** (112/177 unique directed edges classified as genuine, genuine_symmetric, or event_amplified). Only 6 edges (3.4%) are identified as common-shock artifacts — dramatically lower than the >80% spurious rate in equity TE networks (Paper 1). This validates prediction markets as TE's natural setting.

### 6.3 Top Genuine Edges

| Edge | Persistence | Mean TE | Economic Interpretation |
|------|------------|---------|----------------------|
| global_tariffs → gdp | 180 | 0.0079 | Tariff policy drives growth expectations |
| gov_shutdown → global_tariffs | 133 | 0.0084 | Fiscal risk feeds trade policy |
| gov_shutdown → gdp | 132 | 0.0093 | Fiscal risk drives growth |
| global_tariffs → congress_narrative | 127 | 0.0098 | Tariffs shape legislative discourse |
| gov_shutdown → headline_cpi | 95 | 0.0079 | Fiscal risk transmits to inflation expectations |
| global_tariffs → headline_cpi | 90 | 0.0063 | Trade policy affects inflation |
| fed_rate_level → headline_cpi | 90 | 0.0042 | Monetary stance feeds inflation expectations |
| global_tariffs → gov_shutdown | 81 | 0.0073 | Trade policy pressures fiscal policy |
| global_tariffs → fed_rate_path | 74 | 0.0065 | Tariffs inform rate expectations |
| gov_shutdown → congress_narrative | 71 | 0.0136 | Fiscal crisis shapes legislative discourse |

### 6.4 Experiment 3: Lead-Lag Asymmetry

$\text{AR}(A \to B) = \frac{\text{TE}(A \to B) - \text{TE}(B \to A)}{\text{TE}(A \to B) + \text{TE}(B \to A)}$

- Mean $|\text{AR}|$: **0.57** — predominantly directional flow
- High asymmetry ($|\text{AR}| > 0.5$): **103 / 177** edges (58%) — clear sender/receiver roles
- Low asymmetry ($|\text{AR}| < 0.2$): **32 / 177** edges (18%) — potential common factor candidates

### 6.5 Experiment 4: Hierarchical Edge Analysis

**Hierarchical Edge Ratio (HER) = 6.2%** (11/177 edges are between logically nested pairs).

Key hierarchical edges:
- core_cpi_pce → headline_cpi (persistence = 91, genuine)
- fed_rate_level ↔ fed_rate_path (75 + 18 = 93 total, genuine)
- china_tariff_rate ↔ global_tariffs (53 + 42 = 95 total, genuine)

These edges are genuine (not common-shock), but represent within-concept information processing order rather than cross-concept information flow. Family collapse successfully contains most within-concept edges; the remaining 6.2% reflect genuine lead-lag dynamics between sub-concepts.

### 6.6 SpringRank Information Hierarchy

**Clean Network (Genuine Edges Only):**

| Rank | Node | Score | Role |
|------|------|-------|------|
| 1 | fomc_dynamics | +0.43 | **sender** |
| 2 | gov_shutdown | +0.43 | **sender** |
| 3 | global_tariffs | +0.29 | relay |
| 4 | debt_funding | +0.21 | relay |
| 5 | core_cpi_pce | +0.16 | relay |
| 6 | china_policy | +0.05 | relay |
| 7 | fed_leadership | +0.03 | relay |
| 8 | congress_investigations | 0.00 | relay |
| 9 | china_tariff_rate | −0.00 | relay |
| 10 | potus_approval | −0.01 | relay |
| 11 | fed_rate_level | −0.04 | relay |
| 12 | gdp | −0.17 | relay |
| 13 | congress_narrative | −0.25 | relay |
| 14 | fed_rate_path | −0.34 | **receiver** |
| 15 | nasdaq_targets | −0.37 | **receiver** |
| 16 | headline_cpi | −0.41 | **receiver** |

**Interpretation:** FOMC dynamics and fiscal risk (gov_shutdown) are the primary information originators. Tariffs serve as relay — absorbing monetary/fiscal signals and retransmitting to political/trade contracts. Headline CPI, NASDAQ, and rate path expectations are terminal receivers — they absorb information from the rest of the network.

**Key rank shift from identification:** congress_investigations drops from #1 (raw network) to #8 (clean network) — its edges were largely noise/common-shock artifacts. fomc_dynamics jumps from #5 to #1 — its edges are genuinely informative. Stable nodes across identification: gov_shutdown (#2), global_tariffs (#3), gdp (#12), headline_cpi (#16).

---

## 7. Paper Structure

### 7.1 Paper 1: Economics (Identification + Economic Value)

**Working title:** "Identifying Directed Information Flow in Prediction Markets: Separating Belief Propagation from Common Shocks"

**Audience:** Financial economists, macro-finance researchers, prediction market researchers

**Structure:**

1. Introduction: The identification gap in financial network estimation
2. Theoretical framework: Ottaviani-Sørensen underreaction as source of spurious TE edges
3. Data and network construction: Kalshi, family collapse, estimation
4. Identification experiments: Event-window decomposition, event-study, robustness
5. Results: Classified edge table, clean network, what fraction survives identification
6. Economic interpretation: Macro narrative detection, hub dynamics, regime signals
7. Discussion: Why equity TE networks fail (identification failure, not just estimation failure)

**Target journals:** *Quantitative Finance* (primary), *Finance Research Letters* (fast track)

### 7.2 Paper 2: Quantitative Applications

**Working title:** "Network-Informed Cross-Contract Hedging and Information Hierarchy in Prediction Markets"

**Structure:**

1. Network-informed Avellaneda-Stoikov: cross-contract hedging in logit space
2. SpringRank information hierarchy for market-making quoting priority
3. ETF bridge nodes: external validation of network's information content
4. Linear vs. neural TE (MINE): nonlinear information flow detection
5. Deep Hedging: neural hedging with TE edge weights + identification labels as input

**Target:** *Quantitative Finance*, arXiv q-fin, or SSRN working paper

---

## 8. Future Extensions and Applications

### 8.1 ETF Bridge Nodes (External Validation)

Add SPY (S&P 500), TLT (long bonds), GLD (gold), USO (oil), UUP (dollar), HYG (high yield credit) as nodes in the TE network. If TE edges from PM composites predict ETF returns, this validates that PM prices carry genuine macro information. Framed as **external validation**, not alpha discovery. Data: Yahoo Finance 4h bars. $N$ increases from ~19 to ~25.

### 8.2 Neural TE via MINE (HPC Extension)

Compare linear VAR-based TE with neural mutual information estimation (MINE, Belghazi et al. 2018). Ottaviani-Sørensen predict nonlinear price reactions from wealth effects — neural TE may capture nonlinear dependencies that linear TE misses. Implementation on Bocconi's student HPC cluster (8× NVIDIA A100 80GB, MIG-partitioned to 56× 10GB slices). 10GB per slice is sufficient for our scale ($N \approx 25$ nodes, ~600 pairs).

### 8.3 Cross-Contract Hedging (Avellaneda-Stoikov Extension)

Extended reservation price:

$$r_i = S_i - \gamma(T-t) \sum_j \Sigma_{ij} q_j$$

where $\Sigma$ is informed by the TE network. Key innovation: identification labels determine hedge reliability — genuine edges → full hedge weight, common-shock edges → activate only during event windows. Testable prediction: FOMC weeks → density increases → cross-hedge more effective → spreads should narrow.

### 8.4 Deep Hedging (Neural Extension)

Buehler et al. (2019) framework: neural network parameterizes hedging strategy $\delta_\theta(t, S, q)$. Input: time, all contract prices, inventory vector, TE edge weights, **identification labels** (genuine/common-shock). Loss: CVaR of terminal P&L. Training on calibrated logit jump-diffusion (Dalen 2025). Requires HPC.

### 8.5 Economic Value and Practical Applications

**For macro researchers:** Real-time directed map of how market beliefs about macro events interact. Automated macro narrative tracker — hub identity shift detects when market focus pivots (e.g., from monetary policy to trade war). Network density as leading indicator for macro volatility.

**For market makers (Daedalus and similar):** The TE dependency structure informs which contracts to cross-hedge. Updated daily/every few hours — a slowly-updating signal layer, not a latency-sensitive component. The identification labels tell you whether a hedge relationship is reliable across regimes or only during events.

**For methodologists:** The identification framework retroactively explains why equity TE networks are unreliable — not just an estimation failure (Paper 1), but an identification failure. No one has quantified what fraction of financial network edges are common-shock artifacts.

---

## 9. Acknowledgments and Feedback

This project has benefited from feedback and guidance from several researchers. Professor Marco Ottaviani (Bocconi) and Professor Lin Peng (Princeton / Baruch College, CUNY) have provided valuable comments on the research direction and are potential advisor-level feedback sources as the project develops. Professor Eric Zitzewitz (Dartmouth) contributed the key identification critique that shaped our event-window decomposition framework. We are also in discussion with Daedalus Research, a prediction market firm, regarding the practical applicability of the network methodology.

---

## 10. Timeline and Priorities

### 10.1 Completed (March 2026)

| Priority | Task | Status |
|----------|------|--------|
| 1 | Fix composite frequency (daily → 4h bars) | **DONE** |
| 2 | Re-run TE pipeline on 4h composites (multithreaded) | **DONE** (3.5 min, 32 threads) |
| 3 | Build FOMC/CPI/NFP event calendar | **DONE** (69 events) |
| 4 | Run Identification Experiments 1, 3, 4 | **DONE** |
| 5 | Produce classified edge table | **DONE** (177 edges, 63.3% survive) |
| 6 | SpringRank on raw and clean networks | **DONE** |

### 10.2 Remaining (March–April 2026)

| Priority | Task | Est. Time |
|----------|------|-----------|
| 7 | Identification Experiment 2: FOMC event-study ($\pm$10d mini-windows) | 1–2 days |
| 8 | Identification Experiment 5: Placebo & robustness (random dates, 45/60/90d, $\alpha$ sweep) | 2–3 days |
| 9 | Write Paper 1 draft (identification + economic findings) | 2–3 weeks |

### 10.3 Near-Term (April–May 2026)

Add ETF bridge nodes for external validation. Share results with feedback advisors. Submit Paper 1 to target journal by May.
Neural TE implementation on Bocconi A100. Begin Paper 2 draft (quant applications). Cross-contract hedging backtesting.

### 10.5 Summer 2026 and Beyond

Deep Hedging implementation. Paper 2 submission. 

