start: bindings
	julia --project

bindings:
	cd Pluck.jl && make bindings

julia-instantiate:
	julia --project -e 'using Pkg; Pkg.instantiate()'
	cd Pluck.jl && make julia-instantiate