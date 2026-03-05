using Pkg
pkgs = ["HTTP", "JSON3", "DataFrames", "CSV", "Plots", "Graphs", "StatsBase"]
for p in pkgs
    Pkg.add(p)
end
println("All packages installed OK")
