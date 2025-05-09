# TABLE 1

# ["eager_enum", "lazy_enum", "dice", "ours"
COL = ours
# row name from table1 printout
ROW = noisy_or
# "original" or "added" where "added" is the appendix table
WHICH = original

# Whether to use the cached results if this command is run again
CACHE = false
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
	make table-1-diff-all
	make table-1-show

# Show the table
table-1-show:
	julia --project -e "using PluckArtifact; PA.show_table1(;which=:$(WHICH), latex=$(LATEX))"

# Show the diff between actual and expected table1 results
AFTER = out/table1
BEFORE = out/table1_camera_ready_apr23
table-1-diff:
	julia --project -e "using PluckArtifact; PA.diff_table1(;actual_dir=\"$(AFTER)\", expected_dir=\"$(BEFORE)\", which=:$(WHICH))"

table-1-save:
	cp -r out/table1 out/table1_$(shell date +%Y-%m-%d_%H-%M-%S)

table-1-check:
	julia --project -e "using PluckArtifact; PA.diff_results(\"$(AFTER)/$(COL)\", \"$(BEFORE)/$(COL)\")"

table-1-check-vs-dice:
	julia --project -e "using PluckArtifact; PA.diff_results(\"out/table1/ours\", \"out/table1/dice\")"

table-1-diff-correctness:
	julia --project -e "using PluckArtifact; PA.diff_results(\"$(SRC)\", \"$(DST)\")"

table-1-diff-all:
	make table-1-diff-correctness SRC=out/table1/ours DST=out/table1/dice
	make table-1-diff-correctness SRC=out/table1/ours DST=out/table1/lazy_enum
	make table-1-diff-correctness SRC=out/table1/ours DST=out/table1/eager_enum

evaluate:
	make table-1-col
	make table-1-save
	make table-1-check
	make table-1-diff

evaluate-lazy:
	make evaluate COL=lazy_enum BEFORE=out/table1_2025-04-30_22-30-59

evaluate-eager:
	make evaluate COL=eager_enum BEFORE=out/table1_2025-04-30_23-19-06

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



figure-4-plots:
	julia --project -e "using PluckArtifact; PA.plot_scaling(\"diamond\"); PA.plot_scaling(\"ladder\"); PA.plot_scaling(\"hmm\"); PA.plot_scaling(\"sorted\"); PA.plot_scaling(\"pcfg\")"
	echo "Made all non-fuel plots"


# BASICS

bindings:
	cd Pluck.jl && make bindings

julia-instantiate:
	julia --project -e 'using Pkg; Pkg.instantiate()'
	cd Pluck.jl && make julia-instantiate


# # SYNTHESIS

# # number of threads to use
# THREADS = 8
# # bdd, dice, lazy, smc
# STRATEGY = bdd

# LEFT_TRUNCATE = 10 # submission: 100
# LEFT_TIMELIMIT = 1.0 # submission: 3.0

# RIGHT_TRUNCATE = 8 # submission: 100
# RIGHT_STEPS = 500 # submission: 1000
# RIGHT_TIMELIMIT = 0.05 # submission: 0.05
# RIGHT_REPETITIONS = 1 # submission: 3
# # FIGURE 5 LEFT

# figure-5-left:
# 	make figure-5-left-line STRATEGY=bdd
# 	make figure-5-left-line STRATEGY=dice
# 	make figure-5-left-line STRATEGY=lazy
# 	make figure-5-left-line STRATEGY=smc
# 	make figure-5-left-show

# figure-5-left-show:
# 	julia --project -e "using PluckArtifact; PA.build_figure5_left()"

# figure-5-left-line:
# 	julia --project -t$(THREADS) -e "using PluckArtifact; PA.figure5_left_single(:$(STRATEGY); truncate=$(LEFT_TRUNCATE), time_limit=$(LEFT_TIMELIMIT))"

# # FIGURE 5 RIGHT

# figure-5-right:
# 	make figure-5-right-line STRATEGY=bdd
# 	make figure-5-right-line STRATEGY=dice
# 	make figure-5-right-line STRATEGY=lazy
# 	make figure-5-right-line STRATEGY=smc
# 	make figure-5-right-show

# figure-5-right-show:
# 	julia --project -e "using PluckArtifact; PA.build_figure5_right()"

# figure-5-right-line:
# 	julia --project -t$(THREADS) -e "using PluckArtifact; PA.figure5_right_single(:$(STRATEGY); truncate=$(RIGHT_TRUNCATE), mcmc_steps=$(RIGHT_STEPS), time_limit=$(RIGHT_TIMELIMIT))"
