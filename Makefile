# TABLE 1

table-1:
	julia --project -e "using PluckArtifact; PA.table1()"

# FIGURE 4

figure-4: figure-4-diamond figure-4-ladder figure-4-hmm figure-4-sorted figure-4-pcfg figure-4-fuel

figure-4-diamond:
	julia --project -e "using PluckArtifact; PA.run_scaling(\"diamond\")"
	julia --project -e "using PluckArtifact; PA.plot_scaling(\"diamond\")"

figure-4-ladder:
	julia --project -e "using PluckArtifact; PA.run_scaling(\"ladder\")"
	julia --project -e "using PluckArtifact; PA.plot_scaling(\"ladder\")"

figure-4-hmm:
	julia --project -e "using PluckArtifact; PA.run_scaling(\"hmm\")"
	julia --project -e "using PluckArtifact; PA.plot_scaling(\"hmm\")"

figure-4-sorted:
	julia --project -e "using PluckArtifact; PA.run_scaling(\"sorted\")"
	julia --project -e "using PluckArtifact; PA.plot_scaling(\"sorted\")"

figure-4-pcfg:
	julia --project -e "using PluckArtifact; PA.run_scaling(\"pcfg\")"
	julia --project -e "using PluckArtifact; PA.plot_scaling(\"pcfg\")"

figure-4-fuel:
	julia --project -e "using PluckArtifact; PA.run_fuel_plot()"
	julia --project -e "using PluckArtifact; PA.make_fuel_plot()"


# BASICS

bindings:
	cd Pluck.jl && make bindings

julia-instantiate:
	julia --project -e 'using Pkg; Pkg.instantiate()'
	cd Pluck.jl && make julia-instantiate