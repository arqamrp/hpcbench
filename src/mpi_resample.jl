using Random
function resample!(particle; global_comm, seed = 123)    
  lse_op = MPI.@RegisterOp(lse, Float64)
  log_wt = particle.logWeight

  # collective operations
  log_cum_incl = MPI.Scan(log_wt, lse_op, global_comm)
  log_cum_excl = MPI.Exscan(log_wt, lse_op, global_comm)
  log_sum_wts = MPI.Allreduce(log_wt, lse_op, global_comm)

  # find which cores to send particles to
  
  u = rand(Xoshiro(seed), Float64)
  high = exp(log_cum_incl - log_sum_wts)
  low = exp(log_cum_excl - log_sum_wts)
  first_child = ceil(Int, n_children*low - u)+1
  last_child = ceil(Int, n_children*high - u)

  # send and receive particles
  MPI.Irec!(new_particle, global_comm; source = MPI.ANY_SOURCE)
  for child in first_child:last_child
      sreq = MPI.Isend(particle, global_comm; dest = child)
  end
  
  #reset weights
  new_particle.logWeight = 0.0
  particle = new_particle
  
  return nothing
end
