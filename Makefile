table-1:
	julia --project -e "using PluckArtifact; PA.table1()"

start: bindings
	julia --project

bindings:
	cd Pluck.jl && make bindings

julia-instantiate:
	julia --project -e 'using Pkg; Pkg.resolve(); Pkg.instantiate()'
	cd Pluck.jl && make julia-instantiate