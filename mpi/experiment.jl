using MPI
include("../utils.jl")
include("./resample.jl")

# initialise

MPI.Init()

MPI.@RegisterOp(lse, Float64)
const lse_op = MPI.Op(lse, Float64; iscommutative = true)

comm = MPI.COMM_WORLD
rank = MPI.Comm_rank(comm)
cores = MPI.Comm_size(comm)

# usage: julia experiment.jl <dim> <seed> <wt> <nreps>
dim   = length(ARGS) >= 1 ? parse(Int, ARGS[1]) : 10
seed  = length(ARGS) >= 2 ? parse(Int, ARGS[2]) : 123
wt    = length(ARGS) >= 3 ? parse(Int, ARGS[3]) : 1  # 1: middle dies out, 2: even die out, 3: all except last die out
nreps = length(ARGS) >= 4 ? parse(Int, ARGS[4]) : 100

function init_logWt(wt, rank, cores)
  if wt == 1
    float( rank == cores ÷ 2 ? -Inf : 0.0)
  elseif wt == 2
    float( rank % 2 == 0 ? -Inf : 0.0)
  elseif wt == 3
    float( rank < cores-1 ? -Inf : 0.0)
  else
    error("unknown weight distribution: $wt")
  end
end

# initialise particle state and log weight
local_particle = Particle(fill(float(rank), dim), init_logWt(wt, rank, cores))

# warmup: first call pays JIT cost
MPI_resample!(local_particle; global_comm = comm, seed = seed)

times = zeros(nreps)
for r in 1:nreps
  
  local_particle.state .= float(rank)
  local_particle.logWt = init_logWt(wt, rank, cores)  # resample zeroes it, so reset every rep
  
  MPI.Barrier(comm)
  t0 = MPI.Wtime()
  MPI_resample!(local_particle; global_comm = comm, seed = seed + r)
  times[r] = MPI.Wtime() - t0

end

# a collective costs what the slowest rank costs: elementwise max is the critical path
worst = MPI.Reduce(times, max, comm; root = 0)

if rank == 0
  sort!(worst)
  println("$cores,$dim,$wt,$(worst[1]),$(worst[cld(nreps, 2)]),$(worst[cld(9*nreps, 10)])")
end

MPI.Finalize()
