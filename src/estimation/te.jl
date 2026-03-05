"""
VAR(p) estimation and Transfer Entropy computation.

TE from j → i (Gaussian VAR):
  TE(j→i) = ½ log(|Σ_{i|i}| / |Σ_{i|i,j}|)

where:
  Σ_{i|i}   = residual variance of AR(p) model for i using only i's own lags
  Σ_{i|i,j} = residual variance of VAR(p) model for i using i's AND j's lags
"""

module TEEstimation

using LinearAlgebra, Statistics, StatsBase, Random

# ── OLS helper ─────────────────────────────────────────────────────────────────

"""
    ols(Y, X) → (coeffs, residuals, σ²)

Simple OLS: Y = X * β + ε
"""
function ols(Y::Vector{Float64}, X::Matrix{Float64})
    β = (X'X) \ (X'Y)
    ε = Y - X * β
    σ² = var(ε)
    return β, ε, σ²
end

# ── lag matrix ─────────────────────────────────────────────────────────────────

"""
    make_lags(x, p) → Matrix{Float64}

Build design matrix [x_{t-1}, x_{t-2}, ..., x_{t-p}, 1] for scalar x.
Returns (T-p) × (p+1) matrix (includes intercept column).
"""
function make_lags(x::Vector{Float64}, p::Int)
    T = length(x)
    X = Matrix{Float64}(undef, T - p, p + 1)
    for i in 1:(T - p)
        X[i, 1:p] = x[i+p-1:-1:i]  # lags x_{t-1}, ..., x_{t-p}
        X[i, p+1] = 1.0              # intercept
    end
    return X
end

# ── pairwise TE ────────────────────────────────────────────────────────────────

"""
    pairwise_te(xi, xj, p) → Float64

Compute Transfer Entropy from j → i using VAR(p) in logit space.

TE(j→i) = ½ log(σ²_{i|i} / σ²_{i|i,j})

Positive TE = j has predictive power for i beyond i's own history.
"""
function pairwise_te(xi::Vector{Float64}, xj::Vector{Float64}, p::Int)
    T = length(xi)
    T == length(xj) || error("xi and xj must have same length")

    # Restricted model: i ~ lags of i only
    Xi = make_lags(xi, p)
    yi = xi[p+1:end]
    _, _, σ²_restricted = ols(yi, Xi)

    # Unrestricted model: i ~ lags of i AND lags of j
    Xij = hcat(make_lags(xi, p), make_lags(xj, p)[:, 1:p])  # drop intercept from xj lags
    _, _, σ²_unrestricted = ols(yi, Xij)

    # TE = ½ log(σ²_restricted / σ²_unrestricted)
    te = 0.5 * log(σ²_restricted / σ²_unrestricted)
    return max(te, 0.0)  # TE is non-negative by definition
end

# ── permutation test ───────────────────────────────────────────────────────────

"""
    permutation_test(xi, xj, p; n_perms=500) → (te_obs, p_value)

Test H0: TE(j→i) = 0 using block permutation of xj.
Block size = p to preserve local temporal structure.
"""
function permutation_test(xi::Vector{Float64}, xj::Vector{Float64}, p::Int;
                           n_perms::Int=500)
    te_obs = pairwise_te(xi, xj, p)

    # Block permutation of xj
    T = length(xj)
    block_size = max(p, 5)
    n_blocks = ceil(Int, T / block_size)

    null_dist = Float64[]
    for _ in 1:n_perms
        block_order = shuffle(1:n_blocks)
        xj_perm = vcat([xj[((b-1)*block_size+1):min(b*block_size, T)] for b in block_order]...)[1:T]
        push!(null_dist, pairwise_te(xi, xj_perm, p))
    end

    p_val = mean(null_dist .>= te_obs)
    return te_obs, p_val
end

# ── BIC lag selection ──────────────────────────────────────────────────────────

"""
    select_lag(xi; max_p=5) → Int

Select optimal VAR lag order for a univariate series using BIC.
"""
function select_lag(xi::Vector{Float64}; max_p=5)
    T = length(xi)
    best_bic = Inf
    best_p = 1
    for p in 1:max_p
        Xi = make_lags(xi, p)
        yi = xi[p+1:end]
        _, ε, σ² = ols(yi, Xi)
        n = length(yi)
        k = p + 1  # number of parameters
        bic = n * log(σ²) + k * log(n)
        if bic < best_bic
            best_bic = bic
            best_p = p
        end
    end
    return best_p
end

# ── full TE network ────────────────────────────────────────────────────────────

"""
    estimate_te_network(L; α=0.05, n_perms=500, max_p=5) → (A, TE, P)

Estimate full N×N TE network from logit-price matrix L (N×T).

Returns:
  A  : N×N adjacency matrix (1 if TE significant at level α, 0 otherwise)
  TE : N×N matrix of TE values (A[i,j] = TE from j→i)
  P  : N×N matrix of p-values
"""
function estimate_te_network(L::Matrix{Float64}; α=0.05, n_perms=500, max_p=5)
    N, T = size(L)
    println("Estimating TE network: N=$N nodes, T=$T time steps, T/N=$(round(T/N, digits=1))")

    # Reliability diagnostic (from Paper 1 thresholds)
    tn_ratio = T / N
    if tn_ratio < 5
        @warn "T/N = $(round(tn_ratio, digits=1)) < 5: node-level TE estimates unreliable. Aggregate-level conclusions only."
    elseif tn_ratio < 20
        println("  T/N = $(round(tn_ratio, digits=1)): moderate reliability. Hub-level claims require caution.")
    else
        println("  T/N = $(round(tn_ratio, digits=1)): reliable estimation regime.")
    end

    A  = zeros(N, N)
    TE = zeros(N, N)
    P  = ones(N, N)

    total = N * (N - 1)
    done = 0

    for i in 1:N
        p = select_lag(L[i, :]; max_p=max_p)
        for j in 1:N
            i == j && continue
            te_val, p_val = permutation_test(L[i, :], L[j, :], p; n_perms=n_perms)
            TE[i, j] = te_val
            P[i, j]  = p_val
            A[i, j]  = p_val < α ? 1.0 : 0.0
            done += 1
            done % 20 == 0 && print("\r  Progress: $(round(100*done/total, digits=1))%   ")
        end
    end
    println("\r  Done.                    ")

    n_edges = Int(sum(A))
    density = n_edges / (N * (N - 1))
    println("  Edges: $n_edges / $(N*(N-1)) possible (density = $(round(100*density, digits=1))%)")

    return A, TE, P
end

end # module
