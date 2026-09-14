#!/bin/bash
# Sweeps core count and dimension for the broadcast collective, once for the
# MPI implementation and once for the SPMD (DistributedArrays) implementation.
# op is fixed at 1 (broadcast): scatter/gather aren't implemented in either
# mpi/collective_ops.jl or spmd/collective_ops.jl yet.
#SBATCH --job-name=hpcbench-collective
#SBATCH --time=00:15:00
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=64
#SBATCH --cpus-per-task=1
#SBATCH --mem-per-cpu=1500M
#SBATCH --output=logs/%x-%j.out
#SBATCH --error=logs/%x-%j.err

set -euo pipefail

# No `module purge`: it would drop the openmpi that LocalPreferences.toml binds to,
# while sticky StdEnv/gentoo survive, leaving a broken-but-plausible environment.
module load StdEnv/2023 gcc/12.3 openmpi/4.1.5
module load julia/1.12.5

cd "$SLURM_SUBMIT_DIR"
mkdir -p logs results

export JULIA_NUM_THREADS=1

# Precompile once
julia --project=. -e 'using Pkg; Pkg.instantiate(); using MPI; using DistributedArrays'

# Fail fast if LocalPreferences.toml is missing: the bundled MPICH_jll cannot talk
# PMIx and every srun below would abort.
julia --project=. -e 'using MPI; MPI.MPI_LIBRARY == "OpenMPI" ||
  error("expected system OpenMPI, got $(MPI.MPI_LIBRARY) $(MPI.MPI_LIBRARY_VERSION)")'

OP=1
NREPS=100
MPI_RESULTS="results/bench-collective-mpi-${SLURM_JOB_ID}.csv"
SPMD_RESULTS="results/bench-collective-spmd-${SLURM_JOB_ID}.csv"
echo "cores,dim,op,min_s,median_s,p90_s" > "$MPI_RESULTS"
echo "cores,dim,op,min_s,median_s,p90_s" > "$SPMD_RESULTS"

for cores in 4 8 16 32 64; do
  for dim in 1000 10000 100000 1000000; do
    echo "=== mpi cores=$cores dim=$dim ===" >&2
    srun --nodes=1 --ntasks="$cores" --cpus-per-task=1 \
      julia --project=. mpi/collective_ops.jl "$OP" "$dim" "$NREPS" 0 >> "$MPI_RESULTS"

    # spmd/collective_ops.jl is single-process: it addprocs its own workers,
    # so it gets one task bound to $cores cpus rather than $cores tasks.
    echo "=== spmd cores=$cores dim=$dim ===" >&2
    srun --nodes=1 --ntasks=1 --cpus-per-task="$cores" \
      julia --project=. spmd/collective_ops.jl "$OP" "$dim" "$NREPS" 0 "$cores" >> "$SPMD_RESULTS"
  done
done

echo "wrote $MPI_RESULTS"
echo "wrote $SPMD_RESULTS"
