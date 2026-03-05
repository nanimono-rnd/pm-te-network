"""
Main entry point — Phase 1 pilot run.

Usage:
  julia --project=. src/main.jl

Runs the full pipeline:
  1. Fetch Polymarket macro contracts
  2. Build N×T logit-price matrix
  3. Estimate TE network
  4. Print summary + save outputs
"""

include(joinpath(@__DIR__, "estimation/nodes.jl"))
include(joinpath(@__DIR__, "estimation/te.jl"))

using .NodeConstruction, .TEEstimation
using CSV, DataFrames, Dates

println("=" ^ 60)
println("PM-TE-Network: Phase 1 Pilot")
println("=" ^ 60)

# ── Step 1: Build node matrix ──────────────────────────────────────────────────
L, node_ids, metadata, grid = NodeConstruction.build_node_matrix(
    min_volume = 0.0,
    fidelity   = 1440,       # daily candles
)

N, T = size(L)
println("\nNode summary:")
for row in eachrow(metadata)
    println("  [$(row.token_id[1:8])...] $(row.question[1:min(70,length(row.question))])")
end

# Save matrix
CSV.write("data/processed/logit_matrix.csv",
    DataFrame(L, [Symbol("t$t") for t in grid]))
CSV.write("data/processed/metadata.csv", metadata)
println("\nSaved logit matrix → data/processed/")

# ── Step 2: Estimate TE network ────────────────────────────────────────────────
println("\nEstimating TE network (this takes a few minutes)...")
A, TE_matrix, P_matrix = TEEstimation.estimate_te_network(L;
    α       = 0.05,
    n_perms = 200,   # lower for pilot speed; use 1000 for final
    max_p   = 3,
)

# ── Step 3: Summary ────────────────────────────────────────────────────────────
println("\nTop edges by TE strength:")
edges = []
for i in 1:N, j in 1:N
    i == j && continue
    A[i,j] == 1 && push!(edges, (i, j, TE_matrix[i,j], P_matrix[i,j]))
end
sort!(edges, by=x -> -x[3])

println("  j → i                                           TE      p-val")
println("  " * "-"^65)
for (i, j, te, pv) in first(edges, 15)
    qi = metadata[metadata.token_id .== node_ids[i], :question][1][1:min(30,end)]
    qj = metadata[metadata.token_id .== node_ids[j], :question][1][1:min(30,end)]
    println("  $qj → $qi   $(round(te, digits=4))   $(round(pv, digits=3))")
end

println("\nDone. Total significant edges: $(length(edges))")
println("Network density: $(round(100*length(edges)/(N*(N-1)), digits=1))%")
println("T/N ratio: $(round(T/N, digits=1))")
