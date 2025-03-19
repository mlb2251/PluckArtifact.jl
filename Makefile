table-1:
	julia --project -e "using PluckArtifact; PA.table1()"

# FIGURE 5 LEFT

figure-5-left: figure-5-left-dice figure-5-left-bdd figure-5-left-lazy figure-5-left-smc

figure-5-left-dice:
	julia --project -t8 -e "using PluckArtifact; PA.figure5_left_single(:dice)"

figure-5-left-bdd:
	julia --project -t8 -e "using PluckArtifact; PA.figure5_left_single(:bdd)"

figure-5-left-lazy:
	julia --project -t8 -e "using PluckArtifact; PA.figure5_left_single(:lazy)"

figure-5-left-smc:
	julia --project -t8 -e "using PluckArtifact; PA.figure5_left_single(:smc)"


# FIGURE 5 RIGHT

figure-5-right: figure-5-right-dice figure-5-right-bdd figure-5-right-lazy figure-5-right-smc

figure-5-right-dice:
	julia --project -t8 -e "using PluckArtifact; PA.figure5_right_single(:dice)"

figure-5-right-bdd:
	julia --project -t8 -e "using PluckArtifact; PA.figure5_right_single(:bdd)"

figure-5-right-lazy:
	julia --project -t8 -e "using PluckArtifact; PA.figure5_right_single(:lazy)"

figure-5-right-smc:
	julia --project -t8 -e "using PluckArtifact; PA.figure5_right_single(:smc)"



start: bindings
	julia --project

bindings:
	cd PluckSynthesis.jl && make bindings

julia-instantiate:
	julia --project -e 'using Pkg; Pkg.resolve(); Pkg.instantiate()'
	cd PluckSynthesis.jl && make julia-instantiate
