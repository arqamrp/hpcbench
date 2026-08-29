using Random
function MPI_resample!(particle; global_comm, seed = 123)    
  n_children = MPI.Comm_size(global_comm)
  rank = MPI.Comm_rank(global_comm)
  
  
  log_wt = particle.logWt

  
  # collective operations
  log_cum_incl = MPI.Scan(log_wt, lse_op, global_comm)
  log_cum_excl = MPI.Exscan(log_wt, lse_op, global_comm)
  if rank == 0
    log_cum_excl = -Inf
  end

  log_sum_wts = MPI.Allreduce(log_wt, lse_op, global_comm)

  # find which cores to send particles to

  u = rand(Xoshiro(seed), Float64)
  high = exp(log_cum_incl - log_sum_wts)
  low = exp(log_cum_excl - log_sum_wts)
  first_child = floor(Int, n_children*low - u)+1
  last_child = floor(Int, n_children*high - u)

  # send and receive particles
  new_particle_state = Array{Float64}(undef, size(particle.state))
  
  reqs = MPI.Request[]

  keep_own_particle = (rank >= first_child && rank <= last_child)
  
  if !keep_own_particle
    push!(reqs, MPI.Irecv!(new_particle_state, global_comm; source = MPI.ANY_SOURCE))
  else
    new_particle_state .= particle.state
  end

  for child in first_child:last_child
    if child != rank
      push!(reqs, MPI.Isend(particle.state, global_comm; dest = child))    
      # println("Rank $rank sending particle to rank $child") # dont print while measuring time
    end
  end

  stats = MPI.Waitall(reqs)
  
  copyto!(particle.state, new_particle_state)
  particle.logWt = 0.0

  
  return nothing
end
