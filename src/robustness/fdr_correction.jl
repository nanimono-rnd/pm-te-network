"""
Robustness: Benjamini-Hochberg FDR Correction

Apply FDR correction to all pairwise TE p-values across all windows.
Report how many edges survive at FDR q=0.01, 0.05, 0.10.

Usage:
  julia src/robustness/fdr_correction.jl
"""

using CSV, DataFrames, Dates, Statistics

function benjamini_hochberg(pvals::AbstractVector{<:Real}; q::Float64=0.05)
    n = length(pvals)
    sorted_idx = sortperm(pvals)
    sorted_p = pvals[sorted_idx]

    # BH threshold: p_(k) <= k/n * q
    reject = falses(n)
    max_k = 0
    for k in 1:n
        if sorted_p[k] <= k / n * q
            max_k = k
        end
    end

    # Reject all hypotheses with rank <= max_k
    if max_k > 0
        for k in 1:max_k
            reject[sorted_idx[k]] = true
        end
    end

    return reject
end

function main()
    println("=" ^ 70)
    println("Robustness: Benjamini-Hochberg FDR Correction")
    println("=" ^ 70); flush(stdout)

    edges = CSV.read("data/results/edge_list.csv", DataFrame)
    println("Loaded: $(nrow(edges)) edge instances (each is one window × one pair)")
    println("Unique pairs: $(nrow(unique(select(edges, :source, :target))))")
    flush(stdout)

    # Total tests = N*(N-1) per window, summed across all windows
    ws = CSV.read("data/results/window_summary.csv", DataFrame)
    total_tests = sum(ws.N .* (ws.N .- 1))
    println("Total pairwise tests conducted: $total_tests")
    println("Significant at α=0.01 (uncorrected): $(nrow(edges))")
    flush(stdout)

    # Reconstruct full p-value vector (significant + non-significant)
    # We only have p-values for significant edges. For FDR we need ALL p-values.
    # Since non-significant p-values are >0.01 but unknown, we conservatively
    # assume they are uniformly distributed on (0.01, 1.0).
    # Alternative: report FDR-adjusted p-values for significant edges only.

    println("\n── Approach 1: FDR on significant edges only ──")
    println("  (Conservative: treats only the $(nrow(edges)) detected edges)")

    pvals = edges.p_value
    for q in [0.01, 0.05, 0.10]
        reject = benjamini_hochberg(pvals; q=q)
        n_survive = count(reject)
        # Count unique pairs that survive
        surviving = edges[reject, :]
        n_unique = nrow(unique(select(surviving, :source, :target)))
        println("  FDR q=$(lpad(q, 4)): $(n_survive)/$(nrow(edges)) instances survive, $n_unique unique pairs")
    end

    println("\n── Approach 2: Conservative full-test FDR ──")
    println("  (Accounts for all $total_tests tests, not just significant ones)")

    # Construct full p-value vector:
    # - Significant edges: use their actual p-values
    # - Non-significant tests: assign p=1.0 (most conservative)
    n_nonsig = total_tests - nrow(edges)
    full_pvals = vcat(pvals, ones(n_nonsig))
    println("  Full p-value vector: $(length(full_pvals)) tests")

    for q in [0.01, 0.05, 0.10]
        reject = benjamini_hochberg(full_pvals; q=q)
        # Only count rejections among the actual significant edges (first nrow(edges))
        n_survive = count(reject[1:nrow(edges)])
        surviving = edges[reject[1:nrow(edges)], :]
        n_unique = nrow(unique(select(surviving, :source, :target)))
        println("  FDR q=$(lpad(q, 4)): $(n_survive)/$(nrow(edges)) instances survive, $n_unique unique pairs")
    end

    # Per-window FDR (more appropriate: correct within each window)
    println("\n── Approach 3: Per-window FDR ──")
    println("  (BH correction within each window separately)")

    edges.start_date = Date.(edges.start_date)
    ws.start_date = Date.(ws.start_date)

    # For each window, we know N and can compute n_tests = N*(N-1)
    ws_lookup = Dict(r.start_date => (r.N, r.window_idx) for r in eachrow(ws))

    total_survive = 0
    total_instances = 0
    surviving_edges = DataFrame()

    for (sd, (N_w, w_idx)) in ws_lookup
        w_edges = filter(r -> r.start_date == sd, edges)
        nrow(w_edges) == 0 && continue

        n_tests = N_w * (N_w - 1)
        n_sig = nrow(w_edges)
        n_nonsig_w = n_tests - n_sig

        # Full p-value vector for this window
        w_pvals = vcat(w_edges.p_value, ones(n_nonsig_w))

        for q in [0.05]  # just report q=0.05 for per-window
            reject = benjamini_hochberg(w_pvals; q=q)
            n_surv = count(reject[1:n_sig])
            total_survive += n_surv
            total_instances += n_sig
            if n_surv > 0
                append!(surviving_edges, w_edges[reject[1:n_sig], :])
            end
        end
    end

    n_unique_perwindow = nrow(unique(select(surviving_edges, :source, :target)))
    println("  Per-window FDR q=0.05: $total_survive/$total_instances instances survive")
    println("  Unique pairs after per-window FDR: $n_unique_perwindow")

    # Save FDR-corrected edge list
    CSV.write("data/results/fdr_edges.csv", surviving_edges)
    println("\nSaved: data/results/fdr_edges.csv")

    println("\n" * "=" ^ 70); flush(stdout)
end

main()
