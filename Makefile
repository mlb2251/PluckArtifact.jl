start: patch
	free -h
	julia --project

bindings:
	cd coarse-to-fine-synthesis && make bindings

patch:
	echo "nothing to patch"

docker-build:
	docker build -t pluckartifact:latest .

docker:
	docker run -it -m 60g -v $(PWD):/PluckArtifact.jl pluckartifact:latest
