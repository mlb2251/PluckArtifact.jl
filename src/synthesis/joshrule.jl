

function load_joshrule(; path = "data/synthesis/list_function_250/json")
    tasks = PTask[]
    for i ∈ 1:250
        id = 'c' * lpad(i, 3, '0') # 4 => "c004"
        task = load_tasks(
            "$path/$(id)_1.json";
            getios = j -> (([io["i"]], io["o"]) for io in j["data"][1:4]),
            getname = _ -> id,
            gettype = _ -> "list -> list",
            getsolution = _ -> nothing,
        )
        @assert length(task) <= 1
        isempty(task) && continue
        push!(tasks, task[1])
    end
    tasks
end


function mar11()
    gcfgs = GConfigs()

    tasks = load_tasks("data/lafi_task.json")
    # http://localhost:8000/out/results/2025-03-10/22-54-35-000/expt/html/summary.html?path=summary.json
    # eval = ll_to_eval(bdd_ll(;time_limit=.05); temperature=1.0)
    # grammar = build(gbasic() + grand())
    # cfg = MCMCConfig(; steps=5000, pcfg=grammar, eval_builder=eval, start="(geom_list 0.5 0.2)")
    # gcfg = GroupConfig(; tasks, config=cfg, repetitions=10, warmstart=true)
    # add_gcfg!(gcfgs, :bdd, gcfg)

    # http://localhost:8000/out/results/2025-03-10/22-54-35-001/expt/html/summary.html?path=summary.json
    # perturb_eval = ll_to_eval(perturb_ll(); temperature=0.01)
    # perturb_grammar = build(gbasic())
    # perturb_cfg = MCMCConfig(; steps=50000, pcfg=perturb_grammar, eval_builder=perturb_eval, start="make_nil")
    # perturb_gcfg = GroupConfig(; tasks, config=perturb_cfg, repetitions=10, warmstart=true)
    # add_gcfg!(gcfgs, :perturb_01, perturb_gcfg)


    # tasks = load_tasks("out/results/2025-03-11/00-11-53-002/plus20.json")
    tasks = load_tasks("out/results/2025-03-11/00-12-13-002/plus20.json")

    gdet = gbasic() + "??int_nonterm => (plus20 ?int)" - "(inc ?int)" - "(dec ?int)"

    # http://localhost:8000/out/results/2025-03-11/00-23-19-000/expt/html/summary.html?path=summary.json
    eval = ll_to_eval(bdd_ll(;time_limit=.005); temperature=1.0)
    cfg = MCMCConfig(; steps=80, pcfg=build(gdet + grand()), eval_builder=eval, start="(geom_list 0.5 0.2)")
    gcfg = GroupConfig(; tasks, config=cfg, repetitions=10)
    add_gcfg!(gcfgs, :bdd, gcfg)

    # http://localhost:8000/out/results/2025-03-11/10-47-24-000/expt/html/summary.html?path=summary.json
    eval = ll_to_eval(perturb_ll(); temperature=0.01)
    cfg = MCMCConfig(; steps=50000, pcfg=build(gdet), eval_builder=eval, start="make_nil")
    gcfg = GroupConfig(; tasks, config=cfg, repetitions=10, warmstart=true)
    add_gcfg!(gcfgs, :perturb, gcfg)

    run_gcfgs!(gcfgs)
end

