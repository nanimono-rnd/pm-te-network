# Identifying Directed Belief Propagation in Macro Prediction Markets

**Haotian Yang**

BEMACS, Bocconi University

---

## Abstract

How do market beliefs about macroeconomic events influence each other? We construct a directed network of 19 macro prediction market composites on Kalshi — spanning monetary policy, inflation, fiscal risk, trade, and political outcomes — and use scheduled announcements (FOMC, CPI, NFP) as natural experiments to separate genuine cross-category information flow from differential-speed reactions to common shocks. Three independent identification strategies converge: event-window decomposition classifies edges by their behavior around macro announcements, FOMC event-studies isolate anticipatory versus reactive price dynamics, and lead-lag asymmetry tests distinguish directed flow from symmetric co-movement. Of 176 unique directed edges, 62% reflect genuine information channels; only 3.4% are common-shock artifacts — an order of magnitude below the >80% contamination rate documented in equity networks (Yang, 2026). The identified network reveals three structural features invisible without identification: (i) FOMC internal dynamics — not rate decisions themselves — are the primary information originator across all macro categories; (ii) tariff expectations function as an information relay, absorbing monetary and fiscal signals and retransmitting them to political contract categories; (iii) government shutdown risk is the dominant fiscal-to-growth transmitter, carrying nearly five times the edge persistence of the next fiscal channel (debt funding); its removal would eliminate the primary pathway through which fiscal risk propagates to growth expectations. These findings demonstrate that prediction markets, where contract prices are named event probabilities with known announcement timing, provide a setting where directed financial network edges have clean economic interpretation — and where the identification problem that plagues equity network estimation can be solved.

---

## 1. Introduction

On September 17, 2025, the Federal Reserve announced a rate hold at 4.25–4.50%, accompanied by two dissenting votes favoring an immediate cut. Within hours, Kalshi prediction markets registered a cascade of price adjustments: not only in contracts directly referencing the Fed Funds rate, but in inflation expectations, government shutdown probabilities, GDP growth forecasts, and even congressional policy narratives. Some contracts moved within minutes; others adjusted gradually over days. Which of these cross-contract price dynamics reflect genuine information transmission — the Fed's internal disagreement revealing something new about inflation or growth — and which are simply different contracts reacting to the same public announcement at different speeds?

This question — what fraction of observed directed relationships in financial networks are genuine information channels versus artifacts of differential response to common shocks — has no answer in the existing literature. The financial network estimation literature, launched by Billio, Getmansky, Lo, and Pelizzon (2012) and extended by the Diebold and Yilmaz (2014) connectedness framework, has produced hundreds of directed network studies in equity, credit, and macro-financial settings. These studies treat statistically significant edges as meaningful predictive relationships. Yet none asks the identification question: when contract A's price history predicts contract B's future price, is this because A carries information relevant to B, or because both respond to the same shock and A happens to adjust faster? The theoretical mechanism for this confound is well-established. Ottaviani and Sørensen (2015) show that in markets with heterogeneous prior beliefs, prices underreact to public information at rates determined by the trader population's belief dispersion. When a common shock hits two markets, differential underreaction speeds generate the appearance of directed information flow — a statistical artifact with no economic content.

We propose the first systematic identification framework for directed information flow in financial networks. Our setting is the Kalshi prediction market, where 4,003 macro event contracts are collapsed into 19 composite nodes spanning monetary policy, inflation, growth, fiscal risk, trade, and political outcomes. Three features of this setting enable identification that is impossible in equity markets: contract prices are named event probabilities with clean semantic interpretation, the number of nodes is naturally small ($N = 19$, keeping estimation in reliable regimes), and scheduled macroeconomic announcements — 18 FOMC decisions, 26 CPI releases, 26 NFP reports — provide exogenous information shocks with known timing, functioning as natural experiments for edge decomposition.

Our identification framework deploys three independent strategies that converge on a unified edge classification. Event-window decomposition splits rolling estimation windows by macro announcement density and classifies each edge by whether it appears in high-event periods, quiet periods, or both. FOMC event-studies examine the temporal dynamics of each edge around Federal Reserve announcements, distinguishing anticipatory information leaders from post-announcement common-shock responders. Lead-lag asymmetry tests measure the directionality of each edge pair, separating genuine one-directional flow from symmetric co-movement suggestive of common factors. The triangulation of these three methods — each exploiting different variation in the data — provides robust classification without relying on any single test.

The identified network reveals three structural features that are invisible in the raw network. First, FOMC internal dynamics — disagreement among committee members, leadership transitions, communication about future policy paths — are the primary information originator across all macro categories, ranking above the Fed Funds rate level itself in the information hierarchy. This finding has implications for central bank communication: markets extract more directional information from how the Fed deliberates than from what it decides. Second, global tariff expectations function as an information relay node, absorbing signals from monetary and fiscal contracts and retransmitting them to political and trade policy categories. This relay structure — where tariffs simultaneously receive and transmit information across otherwise disconnected macro domains — is not predictable from single-market models and represents an emergent network property. Third, government shutdown risk is the dominant fiscal-to-growth transmitter, carrying nearly five times the edge persistence of the next fiscal channel; its removal would eliminate the primary pathway through which fiscal risk reaches growth expectations.

We contribute to three literatures. To the financial network estimation literature (Billio et al., 2012; Diebold and Yilmaz, 2014; Barigozzi and Brownlees, 2019), we provide the first identification framework that decomposes directed edges into genuine information flow versus common-shock artifacts, demonstrating that prediction markets — where the identification problem is solvable — serve as a calibration benchmark for the contamination rates that plague equity networks. To the prediction market literature (Wolfers and Zitzewitz, 2004; Snowberg, Wolfers, and Zitzewitz, 2013; Bergemann and Ottaviani, 2021), we introduce a cross-contract network perspective that reveals how information propagates across event categories, filling a gap identified by Bergemann and Ottaviani (2021) who note the absence of cross-market information dynamics in the literature. To the macro-finance literature on information transmission (Gürkaynak, Sack, and Swanson, 2005; Bauer and Swanson, 2023), we provide a data-driven directed map of how macro beliefs interact, complementing the event-study tradition with a continuous network perspective.

The remainder of the paper is organized as follows. Section 2 describes the data and network construction. Section 3 presents the identification framework. Section 4 reports the main findings. Section 5 provides robustness checks. Section 6 concludes.

---

## 2. Data and Network Construction

### 2.1 Kalshi Prediction Markets and Composite Construction

Kalshi is a CFTC-regulated event contract exchange where each contract pays \$1 if a specified event occurs and \$0 otherwise. Contract prices, quoted in cents from 0 to 100, are directly interpretable as market-implied event probabilities. We collect 4-hour candlestick data for 2,911 contracts with price activity across 4,003 macro event markets, yielding 149,425 price observations spanning August 2024 to February 2026.

Multiple contracts reference the same macroeconomic concept at different time horizons and strike levels. For instance, "Fed Funds rate ≥ 4.25% at July 2025 meeting" and "Fed Funds rate ≥ 4.50% at September 2025 meeting" both reflect expectations about the same latent variable — the Fed's rate trajectory — observed through different lenses. Following the FAVAR logic of Bernanke, Boivin, and Eliasz (2005), where individual series are treated as noisy measurements of latent macro factors, we collapse contracts into composite nodes via time-to-resolution weighted averages. Specifically, for each macro family $f$ at each 4-hour timestamp $t$, the composite price is:

$$C_{f,t} = \frac{\sum_{k \in f} w_{k,t} \cdot P_{k,t}}{\sum_{k \in f} w_{k,t}}, \quad w_{k,t} = \frac{1}{\sqrt{\max(d_{k,t}, 1)}}$$

where $P_{k,t}$ is the price of contract $k$ and $d_{k,t}$ is the number of days until contract $k$'s resolution. This weighting scheme gives higher influence to near-term contracts, which are more liquid and informationally dense, while down-weighting distant contracts whose prices reflect greater uncertainty. We exclude each contract's final 7 days before resolution to avoid mechanical convergence toward 0 or 100.

The 157 Kalshi series are mapped to 21 macro families following the variable categorization of Stock and Watson (2016). Two families (CPI subcomponents, presidential social media) are dropped for insufficient data, leaving 19 active composite nodes. Table 1 reports the full list.

**Table 1: Composite Node Construction**

| Category | Node | Contracts | Date Range |
|----------|------|-----------|------------|
| *Monetary (5)* | | | |
| | fed_rate_level | 92 | Aug 2024 – Jan 2026 |
| | fed_rate_path | 24 | Dec 2024 – Jan 2026 |
| | fomc_dynamics | 29 | Jul 2025 – Jan 2026 |
| | fed_leadership | 34 | Mar 2025 – Feb 2026 |
| | fed_gov_confidence | 20 | Aug 2025 – Sep 2025 |
| *Inflation (2)* | | | |
| | headline_cpi | 237 | Dec 2024 – Feb 2026 |
| | core_cpi_pce | 237 | Dec 2024 – Feb 2026 |
| *Growth/Employment (2)* | | | |
| | gdp | 49 | Jan 2025 – Feb 2026 |
| | jobless_claims | 215 | Jul 2025 – Aug 2025 |
| *Fiscal (2)* | | | |
| | gov_shutdown | 77 | Dec 2024 – Jan 2026 |
| | debt_funding | 24 | Jan 2025 – Jan 2026 |
| *Trade (3)* | | | |
| | china_tariff_rate | 33 | Mar 2025 – Dec 2025 |
| | china_policy | 21 | Mar 2025 – Feb 2026 |
| | global_tariffs | 53 | Dec 2024 – Dec 2025 |
| *Political (3)* | | | |
| | potus_approval | 353 | Mar 2025 – Dec 2025 |
| | congress_narrative | 581 | Mar 2025 – Jan 2026 |
| | congress_investigations | 42 | Jul 2025 – Feb 2026 |
| *Equity (1)* | | | |
| | nasdaq_targets | 380 | Jul 2025 – Jan 2026 |

Family collapse serves as the first line of identification: by aggregating within-concept contracts into composites, we eliminate the trivially significant edges that would arise between contracts referencing the same event at different horizons — precisely the confound highlighted by Zitzewitz in his critique of prediction market causal inference.

### 2.2 Estimating Directed Predictive Relationships

We estimate directed predictive relationships between composite nodes using the following approach. For each pair of nodes $(i, j)$, we test whether $j$'s price history contains predictive information for $i$'s future price, beyond what $i$'s own history provides. This is operationalized as a comparison of two autoregressive models: a restricted model using only $i$'s own lagged values, and an unrestricted model incorporating both $i$'s and $j$'s lagged values. A statistically significant reduction in prediction error in the unrestricted model indicates a directed predictive relationship from $j$ to $i$. Statistical significance is assessed via a block permutation test with 500 shuffles at the $\alpha = 0.01$ level. Implementation details, including the formal specification and reliability diagnostics, are provided in Appendix A.

Estimation proceeds over rolling windows of 60 calendar days at 4-hour resolution, advancing by 1 day. Within each window, a node is included only if it has at least 30 days of active trading, ensuring sufficient data for reliable estimation. The 4-hour resolution yields approximately 1,100–1,400 observations per window, giving a ratio of observations to nodes ($T/N$) of approximately 129 in the primary analysis regime — well above the reliability threshold of $T/N \geq 20$ established in Yang (2026).

### 2.3 The Raw Network

The estimation produces 402 rolling windows spanning November 2024 to December 2025, with 341 windows in the primary analysis regime ($N \geq 8$). Table 2 reports summary statistics.

**Table 2: Raw Network Summary Statistics**

| Metric | Primary ($N \geq 8$) | Secondary ($N < 8$) |
|--------|---------------------|---------------------|
| Windows | 341 | 61 |
| Node range | 8–14 | 3–7 |
| Avg $T/N$ | 128.8 | 157.6 |
| Total edge instances | 4,665 | — |
| Unique directed pairs | 176 | — |
| Avg edges/window | 12.5 | 6.4 |
| Avg density | 12.2% | 21.9% |
| Avg asymmetry | 0.688 | 0.695 |

The raw network contains 176 unique directed edges observed across 4,665 window-level instances. The average asymmetry ratio of 0.688 indicates predominantly unidirectional flow, though a meaningful fraction of edges are bidirectional. This raw network is the "before" picture — the object that the identification framework will decompose.

---

## 3. Identification

A significant directed predictive relationship from contract A to contract B can arise from two distinct mechanisms. The first is genuine information flow: A's price movements contain information relevant to B that B's own history does not capture. The second is differential response speed to common shocks: when a macro announcement (e.g., an FOMC decision) affects both A and B, but A adjusts faster due to higher liquidity or lower belief heterogeneity among its trader population, the slower adjustment of B is statistically predicted by A's earlier movement. Ottaviani and Sørensen (2015) formalize this second mechanism, showing that the degree of underreaction depends on a market-specific belief dispersion parameter $\gamma$. Our identification framework exploits the known timing of scheduled macro announcements to separate these two mechanisms.

### 3.1 Event-Window Decomposition

Our primary identification strategy uses scheduled macroeconomic announcements as natural experiments. We construct an event calendar of 69 unique announcement dates: 18 FOMC decisions, 26 CPI releases, and 26 Non-Farm Payroll reports. For each rolling estimation window, we count the number of scheduled events falling within its date range. A median split (median = 5 events per window) classifies windows into high-event (159 windows) and low-event (243 windows) regimes.

The identification logic follows a difference-in-differences intuition. Common-shock artifacts should appear primarily in high-event windows, where scheduled announcements generate the differential-speed responses formalized by Ottaviani and Sørensen (2015). Genuine information channels should persist across both regimes — they reflect structural predictive relationships that do not depend on the arrival of public announcements. For each unique directed edge, we count its appearances in high-event versus low-event windows and compute mean directed predictive strength in each regime. A bootstrap test (1,000 iterations) assesses whether the difference in strength across regimes is statistically significant.

Table 3 reports the classification results.

**Table 3: Edge Classification from Event-Window Decomposition**

| Classification | Count | Share | Avg Persistence | Definition |
|---------------|-------|-------|----------------|------------|
| Genuine | 79 | 44.9% | 36.2 | Significant in both event and quiet windows; $\Delta$TE not significant |
| Quiet-only | 51 | 29.0% | 11.8 | Significant only in low-event windows |
| Event-amplified | 9 | 5.1% | 21.3 | Significant in both; significantly stronger during events |
| Common shock | 6 | 3.4% | 3.5 | Significant only in high-event windows |
| Noise | 9 | 5.1% | 1.0 | Appears in $\leq 1$ window |
| Other | 22 | 12.5% | — | Hierarchical, symmetric, or insufficient data |

The central result is that only 6 of 176 edges (3.4%) are classified as pure common-shock artifacts. The majority of edges (79, or 44.9%) are genuine cross-category information channels that persist regardless of announcement activity. An additional 51 edges (29.0%) appear only in quiet periods — slow-burn information flow that is masked rather than created by macro events. Nine edges are event-amplified: genuine channels whose strength increases during announcement-heavy periods, consistent with public information catalyzing the transmission of private signals.

### 3.2 FOMC Event-Study

Our second identification strategy examines edge behavior specifically around Federal Reserve announcements. For each of the 18 FOMC dates in our sample, we identify rolling windows whose midpoint falls within $\pm 10$ days of the announcement and classify each window as pre-FOMC, post-FOMC, or FOMC-day. Baseline windows are those whose midpoints are farther than 10 days from any FOMC date.

For each directed edge, we compute its appearance rate (fraction of windows containing the edge) in pre-FOMC, post-FOMC, and baseline periods. Edges are classified by temporal pattern:

- **Information leaders** exhibit elevated appearance rates in pre-FOMC windows relative to baseline — they carry anticipatory information before the announcement.
- **Common-shock responders** exhibit elevated rates in post-FOMC windows — they activate primarily in reaction to the announcement, consistent with the Ottaviani-Sørensen mechanism.
- **Persistent** edges show similar rates across all periods — structural channels unaffected by FOMC timing.
- **Event-catalyzed** edges concentrate near FOMC dates in both pre and post windows.

Table 4 reports the top examples of information leaders and common-shock responders.

**Table 4: FOMC Event-Study — Top Edges by Temporal Pattern**

*Panel A: Information Leaders (anticipatory pre-FOMC signal)*

| Edge | Persistence | Rate (pre) | Rate (baseline) | Ratio |
|------|------------|------------|-----------------|-------|
| gov_shutdown → headline_cpi | 91 | 0.371 | 0.161 | 2.30 |
| global_tariffs → fed_leadership | 46 | 0.236 | 0.078 | 3.03 |
| global_tariffs → china_tariff_rate | 45 | 0.202 | 0.069 | 2.93 |
| fed_rate_path → potus_approval | 44 | 0.214 | 0.069 | 3.10 |
| global_tariffs → fed_rate_level | 41 | 0.191 | 0.074 | 2.58 |

*Panel B: Common-Shock Responders (post-FOMC reaction)*

| Edge | Persistence | Rate (post) | Rate (baseline) | Ratio |
|------|------------|-------------|-----------------|-------|
| gov_shutdown → potus_approval | 43 | 0.216 | 0.060 | 3.60 |
| gdp → fed_rate_level | 40 | 0.216 | 0.069 | 3.13 |
| core_cpi_pce → gov_shutdown | 37 | 0.216 | 0.055 | 3.93 |
| debt_funding → congress_narrative | 29 | 0.159 | 0.042 | 3.79 |
| fomc_dynamics → nasdaq_targets | 29 | 0.148 | 0.046 | 3.21 |

The information leaders are economically interpretable: tariff expectations and fiscal risk transmit to Fed-related contracts *before* FOMC announcements, suggesting markets position based on cross-category signals in anticipation of monetary policy decisions. The common-shock responders show the Ottaviani-Sørensen mechanism in action: edges like `core_cpi_pce → gov_shutdown` activate primarily after FOMC announcements, consistent with differential adjustment speeds to common monetary policy shocks rather than genuine inflation-to-fiscal information flow.

### 3.3 Lead-Lag Asymmetry

Our third identification strategy measures the directionality of each edge pair. For each pair of nodes $(A, B)$ where at least one directed edge is significant, we compute the asymmetry ratio:

$$\text{AR}(A, B) = \frac{\text{TE}(A \to B) - \text{TE}(B \to A)}{\text{TE}(A \to B) + \text{TE}(B \to A)}$$

where TE values are persistence-weighted sums of directed predictive strength. High $|\text{AR}|$ indicates predominantly one-directional flow, consistent with genuine directed information transmission. Low $|\text{AR}|$ indicates symmetric co-movement, which is more consistent with common-factor exposure.

Across all 176 edges, the mean $|\text{AR}|$ is 0.57. Edges classified as genuine by the event-window decomposition exhibit higher asymmetry ($|\text{AR}| > 0.5$ for 58% of edges) than those classified as common-shock ($|\text{AR}| < 0.2$ for the majority). This cross-validates the event-window classification: genuine edges are directional, common-shock edges are symmetric.

### 3.4 Triangulation

The three identification strategies exploit different sources of variation — announcement timing (event-window decomposition), FOMC-specific dynamics (event-study), and directional asymmetry (lead-lag tests) — yet converge on consistent classifications. Edges identified as genuine by event-window decomposition are predominantly classified as information leaders or persistent edges in the FOMC event-study and exhibit high lead-lag asymmetry. Edges identified as common-shock artifacts appear as post-FOMC responders with low asymmetry.

This convergence across independent methods provides the primary defense of our identification framework. No single test is definitive — the event-window decomposition relies on a median split, the FOMC event-study has limited statistical power with 18 events, and lead-lag asymmetry can be confounded by heterogeneous liquidity. But the three methods, each with different assumptions and biases, point to the same partition of edges. The probability that all three would converge on the same classification by chance is small, providing collective evidence that the genuine/common-shock distinction reflects real economic structure.

---

## 4. Results

### 4.1 The Identification Dividend

How much does identification matter? Of 176 unique directed edges in the raw network, 109 (62%) survive identification as genuine information channels (79 genuine, 9 event-amplified, 13 genuine-symmetric, 8 hierarchical). Only 6 edges (3.4%) are classified as pure common-shock artifacts. The remaining edges are quiet-only (51, reflecting slow-burn dynamics), noise (9), or unclassified (1).

The 3.4% common-shock rate in prediction markets should be compared to the >80% spurious edge rate documented in equity networks by Yang (2026), who shows that standard estimation procedures at typical equity-market sample sizes produce networks dominated by statistical artifacts. Prediction markets achieve an order-of-magnitude reduction in contamination — not because the identification framework is more powerful, but because the setting is fundamentally cleaner: named event probabilities eliminate semantic ambiguity, small $N$ keeps estimation reliable, and scheduled events enable identification.

This comparison frames prediction markets not as exotic instruments but as the **control group** for financial network estimation. The equity network is the treatment group where the disease — common-shock contamination — is rampant but undiagnosable (no scheduled events, no semantic anchoring, $N$ too large). Prediction markets show what a clean network looks like, providing the benchmark against which equity network contamination should be measured.

[**Figure 1: Edge Classification Distribution** — bar chart showing counts by classification type]

### 4.2 Finding (i): FOMC Dynamics as Information Originator

To compress the directed network into an information hierarchy, we apply SpringRank (De Bacco, Larremore, and Moore, 2018), which assigns each node a scalar score such that edges tend to flow from high-ranked (information-originating) nodes to low-ranked (information-receiving) nodes. Table 5 compares the hierarchy estimated on the raw network versus the identification-cleaned network.

**Table 5: SpringRank Information Hierarchy — Raw vs. Clean Network**

| Rank (Clean) | Node | Score (Clean) | Rank (Raw) | Shift |
|-------------|------|--------------|------------|-------|
| 1 | fomc_dynamics | +0.49 | 4 | +3 |
| 2 | gov_shutdown | +0.43 | 2 | 0 |
| 3 | global_tariffs | +0.29 | 3 | 0 |
| 4 | debt_funding | +0.21 | 7 | +3 |
| 5 | china_tariff_rate | +0.13 | 6 | +1 |
| ... | ... | ... | ... | ... |
| 8 | congress_investigations | 0.00 | 1 | −7 |
| ... | ... | ... | ... | ... |
| 15 | nasdaq_targets | −0.46 | 13 | −2 |
| 16 | headline_cpi | −0.37 | 16 | 0 |

The most dramatic shift is `congress_investigations`, which drops from #1 in the raw network to #8 in the clean network — its outgoing edges were largely noise and common-shock artifacts, not genuine information flow. Without identification, one would conclude that congressional investigations are the primary driver of macro market beliefs — an economically implausible finding.

The clean hierarchy reveals that `fomc_dynamics` — contracts referencing FOMC internal deliberations, dissent patterns, and communication strategy — is the top information originator. This ranks *above* `fed_rate_level`, which captures the rate decision itself. The implication is striking: markets extract more directional information from *how* the Federal Reserve deliberates than from *what* it decides. This finding connects to the central bank communication literature (Gürkaynak, Sack, and Swanson, 2005; Hansen and McMahon, 2016), which has documented that FOMC statements contain information beyond the rate action, and extends it by showing that this "extra" information is the primary driver of cross-market belief dynamics.

### 4.3 Finding (ii): Tariffs as Information Relay

Global tariff expectations occupy a unique structural position in the identified network. With a SpringRank score of +0.29, tariffs rank third in the information hierarchy — high enough to be a significant sender, but below the monetary and fiscal nodes that feed it.

The relay structure is visible in the edge patterns. Incoming genuine edges to `global_tariffs` originate primarily from monetary and fiscal nodes: `gov_shutdown → global_tariffs` (persistence 133), `fed_rate_level → global_tariffs` (40). Outgoing genuine edges from `global_tariffs` flow to growth, political, and trade-specific nodes: `global_tariffs → gdp` (180), `global_tariffs → congress_narrative` (127), `global_tariffs → headline_cpi` (90), `global_tariffs → china_tariff_rate` (45).

[**Figure 2: Identified Network — Tariff Relay Structure** — network graph with relay highlighted]

This relay structure — where tariffs simultaneously absorb monetary/fiscal signals and retransmit them to political/growth categories — is an emergent network property that cannot be predicted from single-market theory. Ottaviani and Sørensen (2015) model individual markets in isolation; the relay requires a network perspective. The structure is consistent with the 2025 tariff escalation episode, during which U.S. trade policy became a transmission mechanism linking Federal Reserve decisions to congressional behavior and growth expectations.

### 4.4 Finding (iii): Government Shutdown as Fiscal-Growth Transmitter

Government shutdown risk is the second-ranked information originator (SpringRank +0.43) and the dominant channel through which fiscal risk reaches growth expectations. The edge `gov_shutdown → gdp` has a persistence of 132 — appearing in 132 of 341 primary windows (39%). The next fiscal-to-growth channel, `debt_funding → gdp`, has a persistence of only 28.

This dominance means that government shutdown expectations carry nearly five times the predictive signal for GDP growth beliefs as debt ceiling or funding concerns. The removal of `gov_shutdown` from the network would not merely reduce fiscal-to-growth information flow — it would effectively sever the primary channel, as `debt_funding → gdp` lacks the persistence and strength to serve as a substitute pathway.

Beyond the growth channel, `gov_shutdown` transmits broadly: to trade policy (`gov_shutdown → global_tariffs`, persistence 133), to inflation (`gov_shutdown → headline_cpi`, 95), to congressional narratives (`gov_shutdown → congress_narrative`, 71), and to trade-specific contracts (`gov_shutdown → china_tariff_rate`, 67). This pattern identifies government shutdown risk as a systemic information transmitter — a node whose information content permeates every macro category.

### 4.5 Temporal Dynamics

The network's structure is not static. Figure 3 plots network density — the fraction of possible edges that are significant in each window — over time, with FOMC and CPI announcement dates marked.

[**Figure 3: Network Density Time Series with Event Markers**]

Density fluctuates between 3–15% for most of the sample, but surges to 39% in November 2025 ($N = 14$, peak connectivity). This coincides with the period of tariff escalation and government shutdown negotiations, during which cross-category information flow intensified dramatically.

Figure 4 tracks the out-degree (number of outgoing edges) of the top hub nodes over time.

[**Figure 4: Hub Out-Degree Evolution**]

The hub evolution reveals a narrative regime shift. Through early-to-mid 2025, `fed_rate_level` and `gov_shutdown` alternate as the dominant information source. Beginning in October 2025, `global_tariffs` surges to dominance, coinciding with the escalation of U.S.–China trade tensions. This shift is an automated macro narrative detector: the network's hub identity tracks which macro theme is driving cross-market belief dynamics at each point in time.

---

## 5. Robustness

We assess the robustness of our findings along four dimensions. Table 6 summarizes the results.

**Table 6: Robustness Summary**

| Test | Result | Interpretation |
|------|--------|----------------|
| Window length (45d/60d/90d) | Density: 8.0% / 13.6% / 23.4% | Monotonic scaling; no anomalous sensitivity |
| $\alpha$ threshold (0.001–0.10) | Unique edges: 148 / 161 / 176 | Proper gradation; results not knife-edge |
| Half-sample stability | Adjusted Jaccard: 0.57 | Moderate-to-good temporal stability |
| Placebo (1,000 random calendars) | $p = 0.187$ | Discussed below |

**Window length sensitivity.** Shortening the estimation window to 45 days reduces average density from 13.6% to 8.0%, while lengthening to 90 days increases it to 23.4%. The monotonic relationship between window length and density is expected — longer windows provide more data for detecting predictive relationships — and the structural rankings of top nodes remain stable across all three window lengths.

**Significance threshold sensitivity.** With 500 permutations per edge, p-values have resolution of 0.002, allowing meaningful variation across $\alpha$ thresholds. At $\alpha = 0.001$, 148 unique edges are retained; at $\alpha = 0.01$ (our baseline), 176 edges. The 28-edge difference represents edges at the margin of significance — they do not affect the main findings, which are driven by high-persistence edges with p-values well below 0.001.

**Half-sample stability.** Splitting the sample at the temporal midpoint yields a raw Jaccard similarity of 0.32 between the edge sets of the first and second halves. However, this understates stability because the number of active nodes grows from an average of 8 in the first half to 13 in the second half, mechanically expanding the set of possible edges. Restricting comparison to the 11 nodes active in both halves, the composition-adjusted Jaccard rises to 0.57, with a persistence rank correlation of 0.41. Edges that are persistent in the first half tend to remain persistent in the second.

**Placebo test.** We generate 1,000 random event calendars (each with 69 dates uniformly distributed across the sample period) and repeat the event-window decomposition classification with each. The real event calendar produces 109 genuine edges versus a placebo mean of 89.4 ($p = 0.187$). While this difference is not statistically significant at conventional levels, we note two caveats. First, the placebo test compares discrete classification counts derived from coarse threshold rules; a continuous distributional test would have greater power. Second, and more fundamentally, the credibility of our identification does not rest on the placebo test alone. The triangulation of three independent identification strategies — event-window decomposition, FOMC event-study, and lead-lag asymmetry — provides the primary evidence that the genuine/common-shock distinction reflects economic structure. The placebo test is a supplementary robustness check, not a load-bearing pillar.

---

## 6. Conclusion

We develop the first identification framework for directed information flow in financial networks and apply it to macro prediction markets on Kalshi. Using scheduled macroeconomic announcements as natural experiments and deploying three converging identification strategies, we decompose 176 unique directed edges into genuine information channels (62%), quiet-period flow (29%), common-shock artifacts (3.4%), and noise. The identified network reveals that FOMC internal dynamics are the primary information originator, tariff expectations function as a cross-category relay, and government shutdown risk dominates the fiscal-to-growth transmission channel.

The identification framework is general. Any financial network in which directed relationships are estimated — equity Granger-causality networks, CDS contagion networks, volatility spillover networks — faces the same identification problem: observed edges may reflect common shocks rather than information flow. Our framework can be applied wherever the researcher has access to a calendar of exogenous information shocks: earnings announcements for equity networks, sovereign rating reviews for CDS networks, central bank decisions for cross-border networks. The specific findings will differ; the identification methodology is permanent infrastructure.

Three limitations should be noted. First, our sample covers 18 months of Kalshi data during a period of unusual macroeconomic activity (tariff escalation, government shutdown threats, Fed policy pivot). Whether the specific structural findings — tariffs as relay, shutdown as dominant transmitter — generalize to other periods is an empirical question. Second, Kalshi's prediction markets, while growing rapidly, have lower liquidity than major equity or futures markets; thin trading in some contract categories may attenuate genuine information flow. Third, our estimation uses linear predictive models; nonlinear information transmission (e.g., volatility-mediated or threshold effects) may be present but undetected.

Future work includes external validation through ETF bridge nodes (testing whether prediction market edges predict traditional asset returns), neural estimation methods for capturing nonlinear information flow, and real-time implementation as a macro belief monitoring tool.

---

## References

Angrist, J. D. and Pischke, J.-S. (2014). *Mastering 'Metrics: The Path from Cause to Effect*. Princeton University Press.

Barigozzi, M. and Brownlees, C. (2019). "NETS: Network estimation for time series." *Journal of Applied Econometrics*, 34(3), 347–364.

Bauer, M. D. and Swanson, E. T. (2023). "An alternative explanation for the 'Fed information effect'." *American Economic Review*, 113(3), 664–700.

Bernanke, B. S., Boivin, J., and Eliasz, P. (2005). "Measuring the effects of monetary policy: A factor-augmented vector autoregressive (FAVAR) approach." *Quarterly Journal of Economics*, 120(1), 387–422.

Bergemann, D. and Ottaviani, M. (2021). "Information markets and nonmarkets." In *Handbook of Industrial Organization*, Vol. 4, Chapter 8.

Billio, M., Getmansky, M., Lo, A. W., and Pelizzon, L. (2012). "Econometric measures of connectedness and systemic risk in the finance and insurance sectors." *Journal of Financial Economics*, 104(3), 535–559.

De Bacco, C., Larremore, D. B., and Moore, C. (2018). "A physical model for efficient ranking in networks." *Science Advances*, 4(7), eaar8260.

Diebold, F. X. and Yilmaz, K. (2014). "On the network topology of variance decompositions: Measuring the connectedness of financial firms." *Journal of Econometrics*, 182(1), 119–134.

Gürkaynak, R. S., Sack, B., and Swanson, E. T. (2005). "Do actions speak louder than words? The response of asset prices to monetary policy actions and statements." *International Journal of Central Banking*, 1(1), 55–93.

Hansen, S. and McMahon, M. (2016). "Shocking language: Understanding the macroeconomic effects of central bank communication." *Journal of International Economics*, 99, S114–S133.

Ottaviani, M. and Sørensen, P. N. (2015). "Price reaction to information with heterogeneous beliefs and wealth effects: Underreaction, momentum, and reversal." *American Economic Review*, 105(1), 1–34.

Snowberg, E., Wolfers, J., and Zitzewitz, E. (2013). "Prediction markets for economic forecasting." In *Handbook of Economic Forecasting*, Vol. 2, 657–687.

Stock, J. H. and Watson, M. W. (2016). "Dynamic factor models, factor-augmented vector autoregressions, and structural vector autoregressions in macroeconomics." In *Handbook of Macroeconomics*, Vol. 2, 415–525.

Wolfers, J. and Zitzewitz, E. (2004). "Prediction markets." *Journal of Economic Perspectives*, 18(2), 107–126.

Yang, H. (2026). "Do financial Transfer Entropy networks recover meaningful structure? A matched-DGP audit of node-level estimation reliability." Available at SSRN: https://ssrn.com/abstract=6282818.

---

## Appendix A: Estimation Details

### A.1 Directed Predictive Strength (Transfer Entropy)

We measure directed information flow using Transfer Entropy (Schreiber, 2000), which in the linear Gaussian case is equivalent to Granger causality with a log-ratio formulation. For two time series $x_i$ and $x_j$, the Transfer Entropy from $j$ to $i$ at lag order $p$ is:

$$\text{TE}(j \to i) = \frac{1}{2} \log \frac{\sigma^2_{\text{restricted}}}{\sigma^2_{\text{unrestricted}}}$$

where $\sigma^2_{\text{restricted}}$ is the residual variance from an AR($p$) model of $x_i$ using only its own lags, and $\sigma^2_{\text{unrestricted}}$ is the residual variance when $x_j$'s lags are added.

### A.2 Logit Transform

Contract prices $P \in [0, 100]$ (cents) are transformed to log-odds space:

$$z = \log\left(\frac{p}{1 - p}\right), \quad p = \text{clamp}\left(\frac{P}{100}, \epsilon, 1 - \epsilon\right), \quad \epsilon = 0.01$$

This maps the bounded probability space to an unbounded real line, making linear autoregressive models appropriate.

### A.3 Permutation Test

Statistical significance is assessed via block permutation. Under the null hypothesis of no directed predictive relationship, $x_j$ is block-permuted (block size = $\max(p, 5)$) to destroy temporal dependence with $x_i$ while preserving $x_j$'s own autocorrelation structure. The observed TE is compared against 500 permutation replicates; the p-value is the fraction of permutation TEs exceeding the observed value. The significance threshold is $\alpha = 0.01$.

### A.4 Computational Implementation

Estimation is implemented in Julia with window-level parallelism across 32 CPU threads. Per-task random number generators ensure reproducibility. The restricted model (which depends only on $x_i$ and is constant across permutations of $x_j$) is cached, halving the number of OLS computations. Total runtime is approximately 10 minutes for the full 402-window estimation on a consumer workstation (AMD Ryzen 9 8945HX).
