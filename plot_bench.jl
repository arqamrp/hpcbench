#!/usr/bin/env julia
# Plot benchmark scaling: cores vs median_s, log-log, one panel per wt, one line per dim.
#
# Usage: julia plot_bench.jl [results/bench-57298146.csv]

using DelimitedFiles
using CairoMakie

const csvpath = length(ARGS) >= 1 ? ARGS[1] : joinpath(@__DIR__, "results", "bench-57298146.csv")

raw, header = readdlm(csvpath, ',', Float64, '\n'; header = true)
col(name) = raw[:, findfirst(==(name), vec(header))]

cores  = col("cores")
dim    = col("dim")
wt     = col("wt")
median = col("median_s")

wts  = sort(unique(wt))
dims = sort(unique(dim))
corevals = sort(unique(cores))

# y ticks: nice 1-2-5 decades spanning the data
function nice_ticks(lo, hi)
    ts = Float64[]
    e = floor(Int, log10(lo))
    while 10.0^e <= hi * 10
        for m in (1, 2, 5)
            push!(ts, m * 10.0^e)
        end
        e += 1
    end
    filter(t -> t >= lo / 2 && t <= hi * 2, ts)
end
ymin, ymax = extrema(median)
yticks = nice_ticks(ymin, ymax)
fmt_y(v) = string(round(v * 1e6; digits = 1), " µs")

colors = Makie.wong_colors()

fig = Figure(size = (500 * length(wts), 430), fontsize = 15)

for (i, w) in enumerate(wts)
    ax = Axis(fig[1, i];
        title = "wt = $(Int(w))",
        xlabel = "cores", ylabel = "median runtime",
        xscale = log10, yscale = log10,
        xticks = (corevals, string.(Int.(corevals))),
        yticks = (yticks, fmt_y.(yticks)),
        xminorgridvisible = false, yminorgridvisible = false,
    )
    for (j, d) in enumerate(dims)
        m = (wt .== w) .& (dim .== d)
        idx = sortperm(cores[m])
        scatterlines!(ax, cores[m][idx], median[m][idx];
            color = colors[j], markercolor = colors[j],
            label = "dim = $(Int(d))")
    end
    i == 1 && axislegend(ax; position = :lt)
end

linkyaxes!(filter(x -> x isa Axis, fig.content)...)

outpath = joinpath(@__DIR__, "results", "bench-57298146-scaling.png")
save(outpath, fig; px_per_unit = 2)
println("wrote ", outpath)

for w in wts
    f = Figure(size = (600, 460), fontsize = 15)
    ax = Axis(f[1, 1];
        title = "wt = $(Int(w))",
        xlabel = "cores", ylabel = "median runtime",
        xscale = log10, yscale = log10,
        xticks = (corevals, string.(Int.(corevals))),
        yticks = (yticks, fmt_y.(yticks)),
        xminorgridvisible = false, yminorgridvisible = false,
    )
    for (j, d) in enumerate(dims)
        m = (wt .== w) .& (dim .== d)
        idx = sortperm(cores[m])
        scatterlines!(ax, cores[m][idx], median[m][idx];
            color = colors[j], markercolor = colors[j], label = "dim = $(Int(d))")
    end
    axislegend(ax; position = :lt)
    op = joinpath(@__DIR__, "results", "bench-57298146-wt$(Int(w)).png")
    save(op, f; px_per_unit = 2)
    println("wrote ", op)
end
