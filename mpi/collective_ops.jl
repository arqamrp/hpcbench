using MPI

MPI.Init()

comm = MPI.COMM_WORLD
rank = MPI.Comm_rank(comm)
cores = MPI.Comm_size(comm)

op = length(ARGS) >= 1 ? parse(Int, ARGS[1]) : 1
dim   = length(ARGS) >= 2 ? parse(Int, ARGS[2]) : 10
nreps = length(ARGS) >= 3 ? parse(Int, ARGS[3]) : 100
verbose = length(ARGS) >= 4 ? parse(Int, ARGS[4]) : 0

loc = zeros(dim) .+ rank

if rank == 0
    glo = [i for i in 1:dim]
else glo =  Array{Int64}(undef, dim)
end

times = zeros(nreps)

for r in 1:nreps
  MPI.Barrier(comm)
  t0 = MPI.Wtime()
  if op == 1 # broadcast
    MPI.Bcast!(glo, 0, comm)
    if verbose > 0 && rank != 0
        println("Recieved broadcast $(glo[1]) at rank $(rank)")
    end
  elseif op == 2 # scatter
  else #gather
  end
  
  times[r] = MPI.Wtime() - t0

end

worst = MPI.Reduce(times, max, comm; root = 0)

if rank == 0
  sort!(worst)
  println("$cores,$dim,$op,$(worst[1]),$(worst[cld(nreps, 2)]),$(worst[cld(9*nreps, 10)])")
end

MPI.Finalize()

