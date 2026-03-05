"""
Rolling window TE network estimation.

Core idea: Don't require all nodes to exist for entire period.
Each 60-day window has its own node set (contracts active in that window).
"""

module RollingWindow

using DataFrames, Dates, Statistics

"""
    WindowConfig

Configuration for rolling window analysis.
"""
struct WindowConfig
    window_days::Int        # Window size (default: 60)
    step_days::Int          # Step size (default: 1)
    min_active_days::Int    # Min active days in window (default: 40)
    max_missing_rate::Float64  # Max missing rate per contract (default: 0.2)
    stale_threshold_bars::Int  # Mark as missing if no trade for X bars (default: 12 = 48h)
end

WindowConfig() = WindowConfig(60, 1, 40, 0.2, 12)

"""
    TimeWindow

Represents a single time window.
"""
struct TimeWindow
    start_date::Date
    end_date::Date
    contracts::Vector{String}  # Contract IDs active in this window
    N::Int                     # Number of nodes
    T::Int                     # Number of time steps
end

"""
    generate_windows(start_date::Date, end_date::Date, config::WindowConfig) → Vector{TimeWindow}

Generate all rolling windows between start and end dates.
"""
function generate_windows(start_date::Date, end_date::Date, config::WindowConfig)
    windows = TimeWindow[]
    current = start_date
    
    while current + Day(config.window_days) <= end_date
        window_end = current + Day(config.window_days)
        push!(windows, TimeWindow(current, window_end, String[], 0, 0))
        current += Day(config.step_days)
    end
    
    return windows
end

"""
    filter_contracts_for_window(price_data::Dict, window::TimeWindow, config::WindowConfig) → Vector{String}

For a given window, return contract IDs that meet activity requirements:
- At least min_active_days with non-zero trade
- Missing rate < max_missing_rate
"""
function filter_contracts_for_window(price_data::Dict, window_start::Date, window_end::Date, config::WindowConfig)
    valid_contracts = String[]
    
    for (contract_id, data) in price_data
        # Count active days in this window
        active_days = 0
        total_bars = 0
        
        for (timestamp, price, volume) in data
            date = Date(unix2datetime(timestamp))
            if window_start <= date <= window_end
                total_bars += 1
                if volume > 0
                    active_days += 1
                end
            end
        end
        
        # Check criteria
        if active_days >= config.min_active_days
            missing_rate = 1.0 - (active_days / max(total_bars, 1))
            if missing_rate <= config.max_missing_rate
                push!(valid_contracts, contract_id)
            end
        end
    end
    
    return valid_contracts
end

end # module
