
## Factors to test

* Dimension of particle: 10, 100, 1000
* Number of cores: 4, 16, 64
* Weight distributions
    - Middle rank dies out: logWt = float( rank == cores//2? -Inf : 0.0)
    - Even ranks die out: logWt = float( rank % 2 == 0 ? -Inf : 0.0)
    - All except last die out: logWt = float( rank < cores-1 ? -Inf : 0.0)

