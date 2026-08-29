#!/bin/bash
# Account comes from SBATCH_ACCOUNT; export it in ~/.bashrc on the cluster.
#SBATCH --job-name=hpcbench
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
julia --project=. -e 'using Pkg; Pkg.instantiate(); using MPI'

NREPS=100
SEED=123
RESULTS="results/bench-${SLURM_JOB_ID}.csv"
echo "cores,dim,wt,min_s,median_s,p90_s" > "$RESULTS"

# wt -- 1: middle rank dies out, 2: even ranks die out, 3: all except last die out
for cores in 4 8 16 32 64; do
  for dim in 10 100 1000; do
    for wt in 1 2 3; do
      echo "=== cores=$cores dim=$dim wt=$wt ===" >&2
      srun --nodes=1 --ntasks="$cores" --cpus-per-task=1 \
        julia --project=. mpi/experiment.jl "$dim" "$SEED" "$wt" "$NREPS" >> "$RESULTS"
    done
  done
done

echo "wrote $RESULTS"
