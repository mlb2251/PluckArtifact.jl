# TABLE 1

# ["eager_enum", "lazy_enum", "dice", "ours"
COL = ours
# row name from table1 printout
ROW = noisy_or
# "original" or "added" where "added" is the new camera-ready benchmarks
WHICH = original

# Whether to use the cached results if this command is run again
CACHE = true
# Whether to use latex formatting
LATEX = false

FORCE = true

# Make a single cell
table-1-cell:
	julia --project -e "using PluckArtifact; PA.table1_cell(\"$(COL)\", \"$(ROW)\", force=$(FORCE))"

# Make a whole column
table-1-col:
	julia --project -e "using PluckArtifact; PA.table1(\"$(COL)\"; which=:$(WHICH), cache=$(CACHE))"


# Make a whole row
table-1-row:
	make table-1-cell COL=ours ROW=$(ROW)
	make table-1-cell COL=dice ROW=$(ROW)
	make table-1-cell COL=lazy_enum ROW=$(ROW)
	make table-1-cell COL=eager_enum ROW=$(ROW)

# Make the whole table
table-1:
	make table-1-col COL=ours
	make table-1-col COL=dice
	make table-1-col COL=lazy_enum
	make table-1-col COL=eager_enum
	make table-1-sizes
	make table-1-show

# Show the table
table-1-show:
	julia --project -e "using PluckArtifact; PA.show_table1(;which=:$(WHICH), latex=$(LATEX))"

table-1-sizes:
	julia --project -e "using PluckArtifact; PA.table1_sizes(;which=:$(WHICH))"

table-1-timeout-lazy:
	make table-1-cell COL=lazy_enum ROW=alarm
	make table-1-cell COL=lazy_enum ROW=insurance
	make table-1-cell COL=lazy_enum ROW=hepar2
	make table-1-cell COL=lazy_enum ROW=pigs
	make table-1-cell COL=lazy_enum ROW=diamond
	make table-1-cell COL=lazy_enum ROW=ladder
	make table-1-cell COL=lazy_enum ROW=hmm

table-1-timeout-eager:
	make table-1-cell COL=eager_enum ROW=water
	make table-1-cell COL=eager_enum ROW=alarm
	make table-1-cell COL=eager_enum ROW=insurance
	make table-1-cell COL=eager_enum ROW=hepar2
	make table-1-cell COL=eager_enum ROW=pigs
	make table-1-cell COL=eager_enum ROW=diamond
	make table-1-cell COL=eager_enum ROW=ladder
	make table-1-cell COL=eager_enum ROW=hmm
	make table-1-cell COL=eager_enum ROW=pcfg
	make table-1-cell COL=eager_enum ROW=string_editing
	make table-1-cell COL=eager_enum ROW=sorted_list

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