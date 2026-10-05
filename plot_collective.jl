#!/usr/bin/env julia
# Plot collective-ops (broadcast) median runtime for mpi vs spmd, linear scale:
#   1. cores on x, one panel per dim
#   2. dim on x, one panel per cores
#
# Usage: julia plot_collective.jl [mpi.csv] [spmd.csv]
# With no args, picks the most recently modified results/bench-collective-{mpi,spmd}-*.csv

using DelimitedFiles
using CairoMakie

function latest(pattern)
    files = filter(f -> occursin(pattern, f), readdir(joinpath(@__DIR__, "results"); join = true))
    isempty(files) && error("no results/$pattern* found")
    files[argmax(mtime.(files))]
end

const mpi_csv  = length(ARGS) >= 1 ? ARGS[1] : latest("bench-collective-mpi-")
const spmd_csv = length(ARGS) >= 2 ? ARGS[2] : latest("bench-collective-spmd-")

function load(csvpath)
    raw, header = readdlm(csvpath, ',', Float64, '\n'; header = true)
    col(name) = raw[:, findfirst(==(name), vec(header))]
    return (cores = col("cores"), dim = col("dim"), median = col("median_s"))
end

backends = [("mpi", load(mpi_csv)), ("spmd", load(spmd_csv))]

dims = sort(unique(vcat((b.dim for (_, b) in backends)...)))
corevals = sort(unique(vcat((b.cores for (_, b) in backends)...)))
allmedian = vcat((b.median for (_, b) in backends)...)

# y tick labels in µs (linear scale, ticks chosen by Makie)
fmt_y(vals) = [string(v * 1e6 < 10 ? round(v * 1e6; digits = 1) : round(Int, v * 1e6), " µs") for v in vals]
fmt_x(vals) = [string(Int(round(v))) for v in vals]

colors = Makie.wong_colors()

# panels: one axis per `panelvals` (using `panelkey` field), x = `xkey` field
function grid_plot(panelkey, panelvals, panellabel, xkey, xvals, xlabel, outname)
    fig = Figure(size = (480 * length(panelvals), 430), fontsize = 15)
    for (i, p) in enumerate(panelvals)
        ax = Axis(fig[1, i];
            title = "$panellabel = $(Int(p))",
            xlabel = xlabel, ylabel = "median runtime",
            # cores: one tick per measured value; dim spans decades, so let Makie pick linear ticks
            xticks = xkey == :cores ? (xvals, string.(Int.(xvals))) : Makie.automatic,
            xtickformat = xkey == :cores ? Makie.automatic : fmt_x,
            ytickformat = fmt_y,
            xminorgridvisible = false, yminorgridvisible = false,
        )
        for (j, (name, b)) in enumerate(backends)
            m = getfield(b, panelkey) .== p
            any(m) || continue
            idx = sortperm(getfield(b, xkey)[m])
            xs = getfield(b, xkey)[m][idx]
            ys = b.median[m][idx]
            scatterlines!(ax, xs, ys; color = colors[j], markercolor = colors[j], label = name)
        end
        i == 1 && axislegend(ax; position = :lt)
    end
    axs = filter(x -> x isa Axis, fig.content)
    linkyaxes!(axs...)
    ylims!.(axs, 0, nothing)
    outpath = joinpath(@__DIR__, "results", outname)
    save(outpath, fig; px_per_unit = 2)
    println("wrote ", outpath)
end

grid_plot(:dim, dims, "dim", :cores, corevals, "cores", "bench-collective-vs-cores.png")
grid_plot(:cores, corevals, "cores", :dim, dims, "dim", "bench-collective-vs-dim.png")
