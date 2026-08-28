using MPI
include("utils.jl")
include("mpi_resample.jl")

# initialise 

MPI.Init()

MPI.@RegisterOp(lse, Float64)
const lse_op = MPI.Op(lse, Float64; iscommutative = true)

comm = MPI.COMM_WORLD
rank = MPI.Comm_rank(comm)

# dim from the command line, e.g. `julia experiment.jl 100`
dim = isempty(ARGS) ? 10 : parse(Int, ARGS[1])
seed = isempty(ARGS) ? 123 : parse(Int, ARGS[2])

# initialise particle state and log weight
state = fill(float(rank), dim)
logWt = float(rank == MPI.Comm_size(comm)-1)

local_particle = Particle(state, logWt)

MPI_resample!(local_particle; global_comm = comm, seed = seed)

MPI.Finalize()
