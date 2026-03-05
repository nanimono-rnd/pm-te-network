"""
Network visualization.
"""

module NetworkViz

using Plots, LinearAlgebra, DataFrames

"""
    plot_te_network(A, TE, labels; title="TE Network", min_te=0.0)

Draw a circular directed network graph.

Args:
  A      : N×N adjacency matrix (1 = significant edge)
  TE     : N×N TE values
  labels : Vector{String} of short node labels
  title  : plot title
  min_te : only draw edges with TE >= min_te (for visual clarity)
"""
function plot_te_network(A::Matrix{Float64}, TE::Matrix{Float64},
                          labels::Vector{String};
                          title::String="TE Network", min_te::Float64=0.0)
    N = size(A, 1)

    # Node positions: circle layout
    θ = [2π * i / N for i in 0:(N-1)]
    x = cos.(θ)
    y = sin.(θ)

    # Compute node out-degree for sizing
    out_deg = vec(sum(A, dims=2))
    max_deg = max(maximum(out_deg), 1)

    plt = plot(
        size=(1000, 900),
        title=title,
        titlefontsize=13,
        background_color=:white,
        legend=false,
        axis=nothing,
        border=:none,
    )

    # Draw edges
    te_vals = [TE[i,j] for i in 1:N, j in 1:N if A[i,j] == 1 && TE[i,j] >= min_te]
    te_max = isempty(te_vals) ? 1.0 : maximum(te_vals)
    te_min = isempty(te_vals) ? 0.0 : minimum(te_vals)

    for i in 1:N, j in 1:N
        (A[i,j] != 1 || TE[i,j] < min_te) && continue

        # Edge thickness and color proportional to TE
        norm_te = te_max > te_min ? (TE[i,j] - te_min) / (te_max - te_min) : 1.0
        lw = 0.5 + 2.5 * norm_te
        alpha = 0.3 + 0.7 * norm_te
        col = RGBA(0.2, 0.4, 0.9, alpha)  # blue edges

        # Slight curve: midpoint offset
        mx = (x[j] + x[i]) / 2 * 0.85
        my = (y[j] + y[i]) / 2 * 0.85

        plot!(plt, [x[j], mx, x[i]], [y[j], my, y[i]],
              linewidth=lw, color=col, arrow=true)
    end

    # Draw nodes
    for i in 1:N
        node_size = 6 + 14 * (out_deg[i] / max_deg)
        scatter!(plt, [x[i]], [y[i]],
                 markersize=node_size,
                 color=RGBA(0.9, 0.3, 0.2, 0.85),
                 markerstrokewidth=0)

        # Label: offset outward
        lx = x[i] * 1.22
        ly = y[i] * 1.22
        halign = x[i] > 0.1 ? :left : (x[i] < -0.1 ? :right : :center)
        annotate!(plt, lx, ly, text(labels[i], 7, :black, halign))
    end

    return plt
end

"""
    shorten_label(question; max_len=28) → String

Make a short readable label from a question string.
Strips "Will ", "the ", common prefixes.
"""
function shorten_label(q::String; max_len::Int=28)
    s = q
    for prefix in ["Will the ", "Will ", "Will there be a ", "Will there be ",
                   "Will US ", "Will U.S. ", "No change in "]
        startswith(s, prefix) && (s = s[length(prefix)+1:end]; break)
    end
    length(s) <= max_len && return s
    return s[1:max_len-1] * "…"
end

end # module
