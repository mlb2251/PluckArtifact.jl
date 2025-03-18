table-1:
	julia --project -e "using PluckArtifact; PA.table1()"

start: bindings
	julia --project

bindings:
	cd PluckSynthesis.jl && make bindings

julia-instantiate:
	julia --project -e 'using Pkg; Pkg.resolve(); Pkg.instantiate()'
	cd PluckSynthesis.jl && make julia-instantiate
