# number of threads to use
THREADS = 8
# bdd, dice, lazy, smc
STRATEGY = bdd

LEFT_TRUNCATE = 10 # submission: 100
LEFT_TIMELIMIT = 1.0 # submission: 3.0

RIGHT_TRUNCATE = 8 # submission: 100
RIGHT_STEPS = 500 # submission: 1000
RIGHT_TIMELIMIT = 0.05 # submission: 0.05
RIGHT_REPETITIONS = 1 # submission: 3
# FIGURE 5 LEFT

figure-5-left:
	make figure-5-left-line STRATEGY=bdd
	make figure-5-left-line STRATEGY=dice
	make figure-5-left-line STRATEGY=lazy
	make figure-5-left-line STRATEGY=smc
	make figure-5-left-show

figure-5-left-show:
	julia --project -e "using PluckArtifact; PA.build_figure5_left()"

figure-5-left-line:
	julia --project -t$(THREADS) -e "using PluckArtifact; PA.figure5_left_single(:$(STRATEGY); truncate=$(LEFT_TRUNCATE), time_limit=$(LEFT_TIMELIMIT))"

# FIGURE 5 RIGHT

figure-5-right:
	make figure-5-right-line STRATEGY=bdd
	make figure-5-right-line STRATEGY=dice
	make figure-5-right-line STRATEGY=lazy
	make figure-5-right-line STRATEGY=smc
	make figure-5-right-show

figure-5-right-show:
	julia --project -e "using PluckArtifact; PA.build_figure5_right()"

figure-5-right-line:
	julia --project -t$(THREADS) -e "using PluckArtifact; PA.figure5_right_single(:$(STRATEGY); truncate=$(RIGHT_TRUNCATE), mcmc_steps=$(RIGHT_STEPS), time_limit=$(RIGHT_TIMELIMIT))"

# BASICS

bindings:
	cd PluckSynthesis.jl && make bindings

julia-instantiate:
	julia --project -e 'using Pkg; Pkg.instantiate()'
	cd PluckSynthesis.jl && make julia-instantiate
