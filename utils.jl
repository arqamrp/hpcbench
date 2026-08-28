mutable struct Particle
  state::Vector{Float64}
  logWt::Float64
end

function lse(a::Float64, b::Float64)
  if a == -Inf
    return b
  elseif b == -Inf
    return a
  else
    m = max(a, b)
    return m + log( exp(a-m) + exp(b-m))
  end
end
