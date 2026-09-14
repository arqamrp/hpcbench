using Distributed
using DistributedArrays

op = length(ARGS) >= 1 ? parse(Int, ARGS[1]) : 1
dim   = length(ARGS) >= 2 ? parse(Int, ARGS[2]) : 10
nreps = length(ARGS) >= 3 ? parse(Int, ARGS[3]) : 100
verbose = length(ARGS) >= 4 ? parse(Int, ARGS[4]) : 0
workers_n = length(ARGS) >= 5 ? parse(Int, ARGS[5]) : 4

addprocs(workers_n-1)
@everywhere using DistributedArrays.SPMD
@everywhere dim = $dim
@everywhere op = $op
@everywhere nreps = $nreps
@everywhere verbose = $verbose

@everywhere function collective_test()
    rank = myid()

    if rank == 1
        glo = [i for i in 1:dim]
    else
        glo = Array{Int64}(undef, dim)
    end

    times = zeros(nreps)

    for r in 1:nreps
        barrier()
        t0 = time()
        if op == 1 # broadcast
            glo = bcast(glo, 1)
            if verbose > 0 && rank != 1
                println("Recieved broadcast $(glo[1]) at rank $(rank)")
            end
        elseif op == 2 # scatter
        else #gather
        end
        times[r] = time() - t0
    end

    all_times = gather(times, 1)

    if rank == 1
        worst = [maximum(t[r] for t in all_times) for r in 1:nreps]
        sort!(worst)
        cores = nprocs()
        println("$cores,$dim,$op,$(worst[1]),$(worst[cld(nreps, 2)]),$(worst[cld(9*nreps, 10)])")
    end
end

spmd(collective_test)
