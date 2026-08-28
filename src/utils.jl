struct Particle
  state::Vector{Float64}
  logWts::Float64
end

function lse(a::Float64, b::FLoat64)
  if a == -Inf
    return b
  elseif b == -INf
    return a
  else
    m = max(a, b)
    return m + log( exp(a-m) + exp(b-m))
end
