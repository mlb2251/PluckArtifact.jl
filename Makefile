start: patch
	free -h
	julia --project



bindings:
	cd coarse-to-fine-synthesis && make bindings

patch:
	apt-get install -y curl procps

docker:
	docker run -it -m 60g -v $(PWD):/PluckArtifact.jl pluckartifact:latest
