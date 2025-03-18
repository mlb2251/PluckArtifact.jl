start: bindings patch
	julia --project

bindings:
	cd Pluck.jl && make bindings
	cd PluckSynthesis.jl && make bindings

submodule:
	git submodule sync --recursive
	git submodule update --init --recursive

patch:
	echo "nothing to patch"

docker-build:
	docker build -t pluckartifact:latest .

docker:
	docker run -it -m 60g -p 8000:8000 -v $(PWD):/PluckArtifact.jl pluckartifact:latest
