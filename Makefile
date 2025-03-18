start: bindings patch
	julia --project

bindings:
	cd PluckSynthesis.jl && make bindings

julia-instantiate:
	julia --project -e 'using Pkg; Pkg.resolve(); Pkg.instantiate()'
	cd PluckSynthesis.jl && make julia-instantiate

patch:
	echo "nothing to patch"

docker-build:
	docker build -t pluckartifact:latest .

docker:
	docker run -it -m 60g -p 8000:8000 -v $(PWD):/PluckArtifact.jl pluckartifact:latest
