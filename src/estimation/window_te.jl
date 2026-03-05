"""
Window-level TE network estimation.
"""

module WindowTE

using DataFrames, Dates, Statistics
include(joinpath(@__DIR__, "te.jl"))
using .TEEstimation

"""
    build_window_matrix(price_data::Dict, contracts::Vector{String}, 
                        window_start::Date, window_end::Date) → Matrix{Float64}

Build logit-price matrix for a specific window.
Only include timestamps within the window.
"""
function build_window_matrix(price_data::Dict, contracts::Vector{String}, 
                             window_start::Date, window_end::Date)
    # Collect all timestamps in window
    all_ts = Set{Int}()
    for contract_id in contracts
        haskey(price_data, contract_id) || continue
        df = price_data[contract_id]
        for t in df.t
            date = Date(unix2datetime(t))
            if window_start <= date <= window_end
                push!(all_ts, t)
            end
        end
    end
    
    grid = sort(collect(all_ts))
    T = length(grid)
    N = length(contracts)
    
    T == 0 && return (zeros(0, 0), contracts, Int[])
    
    # Build matrix
    L = fill(NaN, N, T)
    ts_to_idx = Dict(t => j for (j, t) in enumerate(grid))
    
    for (i, contract_id) in enumerate(contracts)
        haskey(price_data, contract_id) || continue
        df = price_data[contract_id]
        
        for row in eachrow(df)
            date = Date(unix2datetime(row.t))
            if window_start <= date <= window_end && haskey(ts_to_idx, row.t)
                j = ts_to_idx[row.t]
                if !isnan(row.p) && 0.0 < row.p < 1.0
                    # Logit transform with clipping
                    p_clip = clamp(row.p, 0.01, 0.99)
                    L[i, j] = log(p_clip / (1.0 - p_clip))
                end
            end
        end
        
        # Forward fill NaNs
        last_val = NaN
        for j in 1:T
            if !isnan(L[i, j])
                last_val = L[i, j]
            elseif !isnan(last_val)
                L[i, j] = last_val
            end
        end
    end
    
    # Remove rows/cols with too many NaNs
    valid_rows = [count(isnan, L[i, :]) / T < 0.2 for i in 1:N]
    valid_cols = [count(isnan, L[:, j]) / N < 0.2 for j in 1:T]
    
    L = L[valid_rows, valid_cols]
    contracts = contracts[valid_rows]
    grid = grid[valid_cols]
    
    return (L, contracts, grid)
end

"""
    estimate_window_network(L::Matrix{Float64}; α=0.05, n_perms=200, max_p=3)

Estimate TE network for a single window.
Returns (A, TE_matrix, P_matrix, edges)
"""
function estimate_window_network(L::Matrix{Float64}; α=0.05, n_perms=200, max_p=3)
    N, T = size(L)
    
    if N < 3 || T < 30
        # Not enough data
        return (zeros(N, N), zeros(N, N), ones(N, N), [])
    end
    
    A, TE_matrix, P_matrix = TEEstimation.estimate_te_network(L; α=α, n_perms=n_perms, max_p=max_p)
    
    # Extract significant edges
    edges = [(i, j, TE_matrix[i,j], P_matrix[i,j]) 
             for i in 1:N, j in 1:N if i != j && A[i,j] == 1]
    sort!(edges, by=x -> -x[3])
    
    return (A, TE_matrix, P_matrix, edges)
end

end # module
