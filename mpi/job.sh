#!/bin/bash
#SBATCH --job-name=hpcbench
#SBATCH --time=00:15:00
#SBATCH --nodes=1                  # all 64 ranks on one node: intra-node only
#SBATCH --ntasks-per-node=64
#SBATCH --cpus-per-task=1
#SBATCH --mem-per-cpu=1G           # ~370M measured per rank; the particle itself is 8K
#SBATCH --output=logs/%x-%j.out
#SBATCH --error=logs/%x-%j.err
#SBATCH --account=CHANGEME        # EDIT

set -euo pipefail

module purge
module load julia                  # EDIT to match your cluster

cd "$SLURM_SUBMIT_DIR"
mkdir -p logs results

export JULIA_NUM_THREADS=1         # one Julia thread per MPI rank

# Precompile ONCE on a single process. Letting 64 ranks race on the
# precompile cache at startup corrupts it.
julia --project=. -e 'using Pkg; Pkg.instantiate(); using MPI'

NREPS=100
SEED=123
RESULTS="results/bench-${SLURM_JOB_ID}.csv"
echo "cores,dim,wt,min_s,median_s,p90_s" > "$RESULTS"

# factors from readme.md
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
