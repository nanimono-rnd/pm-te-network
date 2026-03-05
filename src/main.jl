"""
Main entry point — Phase 1 pilot run.

Usage:
  julia --project=. src/main.jl
"""

include(joinpath(@__DIR__, "estimation/nodes.jl"))
include(joinpath(@__DIR__, "estimation/te.jl"))
include(joinpath(@__DIR__, "network/graph.jl"))

using .NodeConstruction, .TEEstimation, .NetworkViz
using CSV, DataFrames, Dates, Plots

println("=" ^ 60)
println("PM-TE-Network: Phase 1 Pilot")
println("=" ^ 60)

# ── Step 1: Build node matrix ──────────────────────────────────────────────────
L, node_ids, metadata, grid = NodeConstruction.build_node_matrix(
    min_volume = 0.0,
    fidelity   = 1440,
)

# Drop noise nodes (SPX meme tokens, non-macro that slipped through)
NOISE_KEYWORDS = ["spx6900", "meme", "solana", "bitcoin", "btc", "eth"]
keep_mask = [!any(kw -> occursin(kw, lowercase(r.question)), NOISE_KEYWORDS)
             for r in eachrow(metadata)]
keep_idx = findall(keep_mask)

L        = L[keep_idx, :]
node_ids = node_ids[keep_idx]
metadata = metadata[keep_idx, :]

N, T = size(L)
println("\nNode summary (after noise filter):")
for row in eachrow(metadata)
    println("  $(row.question[1:min(72,length(row.question))])")
end
println("  → N=$N, T=$T, T/N=$(round(T/N, digits=1))")

# Save
CSV.write("data/processed/logit_matrix.csv",
    DataFrame(L, [Symbol("t$t") for t in grid]))
CSV.write("data/processed/metadata.csv", metadata)

# ── Step 2: Estimate TE network ────────────────────────────────────────────────
println("\nEstimating TE network...")
A, TE_matrix, P_matrix = TEEstimation.estimate_te_network(L;
    α       = 0.05,
    n_perms = 200,
    max_p   = 3,
)

# ── Step 3: Summary ────────────────────────────────────────────────────────────
edges = [(i, j, TE_matrix[i,j], P_matrix[i,j])
         for i in 1:N, j in 1:N if i != j && A[i,j] == 1]
sort!(edges, by=x -> -x[3])

get_question(token_id) = begin
    idx = findfirst(==(token_id), metadata.token_id)
    return idx === nothing ? token_id[1:min(8,length(token_id))] * "..." : metadata.question[idx]
end

println("\nTop edges by TE strength:")
println("  j → i                                           TE      p-val")
println("  " * "-"^65)
for (i, j, te, pv) in first(edges, 15)
    qi = get_question(node_ids[i]); qi_s = qi[1:min(30,length(qi))]
    qj = get_question(node_ids[j]); qj_s = qj[1:min(30,length(qj))]
    println("  $qj_s → $qi_s   $(round(te, digits=4))   $(round(pv, digits=3))")
end

println("\nTotal significant edges: $(length(edges))")
println("Network density: $(round(100*length(edges)/(N*(N-1)), digits=1))%")
println("T/N ratio: $(round(T/N, digits=1))")

# ── Step 4: Visualize ─────────────────────────────────────────────────────────
println("\nGenerating network plot...")
labels = [NetworkViz.shorten_label(get_question(id)) for id in node_ids]

plt = NetworkViz.plot_te_network(A, TE_matrix, labels;
    title="Polymarket Macro Belief TE Network (Phase 1 Pilot)",
    min_te=0.01)

savefig(plt, "data/processed/te_network.png")
println("Saved → data/processed/te_network.png")
