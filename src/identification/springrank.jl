"""
SpringRank Information Hierarchy (De Bacco et al. 2018)

Compress directed TE network into 1D hierarchy ranking.
Net senders rank high, net receivers rank low, relay nodes in the middle.

Also computes time-varying hierarchy (monthly) for regime detection.

Usage:
  julia src/identification/springrank.jl
"""

using CSV, DataFrames, Dates, Statistics, LinearAlgebra

# ═══════════════════════════════════════════════════════════════════════════════
# SpringRank Algorithm
# ═══════════════════════════════════════════════════════════════════════════════

"""
    springrank(A; λ=1.0) → scores

Compute SpringRank scores from directed adjacency matrix A.
A[i,j] = weight of edge from i to j (i is source, j is target).

Solves: min Σ_{ij} A_{ij} (s_i - s_j - 1)²
Via:     (L + λI) s = d_out - d_in
Where L = D - (A + A^T) is the symmetric graph Laplacian.
"""
function springrank(A::Matrix{Float64}; λ::Float64=1.0)
    N = size(A, 1)

    # Symmetric adjacency for Laplacian
    S = A + A'

    # Degree matrix
    d_total = vec(sum(S, dims=2))
    D = diagm(d_total)

    # Laplacian + regularization
    L_reg = D - S + λ * I

    # RHS: out-degree minus in-degree
    d_out = vec(sum(A, dims=2))  # row sums = out-degree
    d_in = vec(sum(A, dims=1))   # col sums = in-degree
    b = d_out - d_in

    # Solve
    s = L_reg \ b

    # Center at zero
    s .-= mean(s)

    return s
end

# ═══════════════════════════════════════════════════════════════════════════════
# Build aggregated adjacency from edge list
# ═══════════════════════════════════════════════════════════════════════════════

function build_adjacency(edges::DataFrame, nodes::AbstractVector;
                         weight_col::Symbol=:persistence)
    N = length(nodes)
    node_idx = Dict(n => i for (i, n) in enumerate(nodes))
    A = zeros(N, N)

    for r in eachrow(edges)
        i = get(node_idx, r.source, 0)
        j = get(node_idx, r.target, 0)
        i > 0 && j > 0 || continue
        if weight_col == :persistence
            A[i, j] += r.persistence
        elseif weight_col == :te
            A[i, j] += r.mean_te * r.persistence
        else
            A[i, j] += 1.0
        end
    end

    return A
end

# ═══════════════════════════════════════════════════════════════════════════════
# Time-varying SpringRank (monthly windows)
# ═══════════════════════════════════════════════════════════════════════════════

function monthly_springrank(edge_list::DataFrame, nodes::AbstractVector)
    println("\n── Time-Varying SpringRank (Monthly) ──"); flush(stdout)

    # Group edges by month
    edge_list.month = Dates.format.(edge_list.start_date, "yyyy-mm")
    months = sort(unique(edge_list.month))

    results = NamedTuple[]
    for m in months
        m_edges = filter(r -> r.month == m, edge_list)
        nrow(m_edges) == 0 && continue

        # Build adjacency (count-weighted)
        N = length(nodes)
        node_idx = Dict(n => i for (i, n) in enumerate(nodes))
        A = zeros(N, N)
        for r in eachrow(m_edges)
            i = get(node_idx, r.source, 0)
            j = get(node_idx, r.target, 0)
            i > 0 && j > 0 && (A[i, j] += 1.0)
        end

        scores = springrank(A)

        for (i, node) in enumerate(nodes)
            push!(results, (month=m, node=node, rank_score=round(scores[i], digits=4)))
        end
    end

    return DataFrame(results)
end

# ═══════════════════════════════════════════════════════════════════════════════
# Main
# ═══════════════════════════════════════════════════════════════════════════════

function main()
    println("=" ^ 70)
    println("PM-TE-Network: SpringRank Information Hierarchy")
    println("=" ^ 70); flush(stdout)

    # Load classified edges
    classified = CSV.read("data/results/classified_edges.csv", DataFrame)
    edge_list = CSV.read("data/results/edge_list.csv", DataFrame)
    edge_list.start_date = Date.(edge_list.start_date)
    println("Loaded: $(nrow(classified)) classified edges, $(nrow(edge_list)) raw edge instances")

    # All nodes
    nodes = sort(unique(vcat(classified.source, classified.target)))
    N = length(nodes)
    println("Nodes: $N"); flush(stdout)

    # ── 1. Full-sample SpringRank (all edges) ─────────────────────────────
    println("\n── SpringRank: All Edges ──")
    A_all = build_adjacency(classified, nodes; weight_col=:persistence)
    scores_all = springrank(A_all)

    ranking_all = sort(collect(zip(nodes, scores_all)), by=x -> -x[2])
    println("  Rank │ Node                    │ Score  │ Role")
    println("  ─────┼─────────────────────────┼────────┼──────────")
    for (rank, (node, score)) in enumerate(ranking_all)
        role = score > 0.3 ? "sender" : score < -0.3 ? "receiver" : "relay"
        println("  $(lpad(rank, 4)) │ $(rpad(node, 23)) │ $(lpad(round(score, digits=3), 6)) │ $role")
    end
    flush(stdout)

    # ── 2. Clean-network SpringRank (genuine + event_amplified only) ──────
    println("\n── SpringRank: Clean Network (Genuine Only) ──")
    clean = filter(r -> r.final_label in ["genuine", "genuine_symmetric", "event_amplified"], classified)
    A_clean = build_adjacency(clean, nodes; weight_col=:persistence)
    scores_clean = springrank(A_clean)

    ranking_clean = sort(collect(zip(nodes, scores_clean)), by=x -> -x[2])
    println("  Rank │ Node                    │ Score  │ Role")
    println("  ─────┼─────────────────────────┼────────┼──────────")
    for (rank, (node, score)) in enumerate(ranking_clean)
        role = score > 0.3 ? "sender" : score < -0.3 ? "receiver" : "relay"
        println("  $(lpad(rank, 4)) │ $(rpad(node, 23)) │ $(lpad(round(score, digits=3), 6)) │ $role")
    end
    flush(stdout)

    # ── 3. Time-varying SpringRank ────────────────────────────────────────
    monthly = monthly_springrank(edge_list, nodes)
    CSV.write("data/results/springrank_monthly.csv", monthly)
    println("\nSaved: data/results/springrank_monthly.csv ($(nrow(monthly)) rows)")

    # ── 4. Save full-sample rankings ──────────────────────────────────────
    rank_df = DataFrame(
        node = [x[1] for x in ranking_all],
        score_all = [round(x[2], digits=4) for x in ranking_all],
        score_clean = [round(Dict(zip(nodes, scores_clean))[x[1]], digits=4) for x in ranking_all],
        rank_all = 1:length(ranking_all),
    )
    # Add clean rank
    clean_order = sort(collect(zip(nodes, scores_clean)), by=x -> -x[2])
    clean_rank_map = Dict(x[1] => i for (i, x) in enumerate(clean_order))
    rank_df.rank_clean = [clean_rank_map[n] for n in rank_df.node]
    rank_df.rank_shift = rank_df.rank_all .- rank_df.rank_clean

    CSV.write("data/results/springrank_scores.csv", rank_df)
    println("Saved: data/results/springrank_scores.csv")

    # Rank stability
    println("\n── Rank Stability (All vs Clean) ──")
    for r in eachrow(rank_df)
        shift_str = r.rank_shift == 0 ? "  =" : (r.rank_shift > 0 ? " +$(r.rank_shift)" : " $(r.rank_shift)")
        println("  $(rpad(r.node, 25)) all=#$(r.rank_all) clean=#$(r.rank_clean) shift=$shift_str")
    end

    println("\n" * "=" ^ 70); flush(stdout)
end

main()
