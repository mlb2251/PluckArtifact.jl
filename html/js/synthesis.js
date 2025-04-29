"use strict";


const header = d3.select("body").append("div").style("white-space", "nowrap")
const upper_table_div = d3.select("body").append("div")
const lower_table_div = d3.select("body").append("div")
d3.select("body").append("br")
make_controls()
// add_svg()
reload()

function reload() {
    clear_svg()
    resize_svg()
    load_by_path(json => {
        console.log(json)
        let group = json.groups[url_params.get("group") || 0]

        if (group.subgroups) {
            group.subgroups = group.subgroups.map(subgroup => json.groups.find(g => g.config.task === subgroup))
            group.runs = []
            let paths = []
            let modes = []
            for (let subgroup of group.subgroups) {
                subgroup.runs = subgroup.runs.filter(r => !r.hide)
                paths.push(...subgroup.runs.map(r => r.path))
                modes.push(...subgroup.runs.map(r => r.mode))
            }
            let unique_modes = [...new Set(modes)]
            let idx_of_mode = {}
            for (let i = 0; i < unique_modes.length; i++) {
                idx_of_mode[unique_modes[i]] = i
            }

            load_jsons(paths, summaries => {
                group.runs = []
                for (let mode of unique_modes) {
                    group.runs.push({
                        mode,
                        summary: {
                            init_stubs_of_task: [],
                            task_info: [],
                        }
                    })
                }
                for (let i = 0; i < summaries.length; i++) {
                    let mode = modes[i]
                    let combined_summary = group.runs[idx_of_mode[mode]].summary
                    let summary = summaries[i]
                    // add the things
                    combined_summary.init_stubs_of_task.push(...summary.init_stubs_of_task)
                    combined_summary.task_info.push(...summary.task_info)
                }
                show_results(group)
            })
        } else {
            group.runs = group.runs.filter(r => !r.hide)
            load_jsons(group.runs.map(r => r.path), jsons => {
            for (let j = 0; j < jsons.length; j++) {
                group.runs[j].summary = jsons[j]
            }
                show_results(group)
            })
        }
    })
}

function make_controls() {
    add_controls()
    let controls = get_controls()
}



function show_results(json) {
    console.log("show_results")
    // return
    window.json = json
    console.log(json)
    let runs = json.runs
    let order = ["bdd", "lazy", "dice", "smc", "strict", "special"]
    runs.sort((a, b) => order.indexOf(a.mode) - order.indexOf(b.mode))


    let jsons = runs.map(r => r.summary)
    let num_tasks = jsons[0].init_stubs_of_task.length
    let num_repetitions = jsons[0].init_stubs_of_task[0].length
    let num_train = jsons[0].init_stubs_of_task[0][0].task.num_train
    let num_test = jsons[0].init_stubs_of_task[0][0].task.ios.length - num_train
    console.log("num_train:", num_train, "num_test:", num_test, "num_tasks:", num_tasks, "num_repetitions:", num_repetitions)

    // print links to specific runs
    for (let j = 0; j < jsons.length; j++) {
        let summary_url = window.location.origin + "/html/summary.html" + "?path=" + jsons[j].out + "/" + jsons[j].summary_path
        header.append("span").text(runs[j].mode + ": ")
        header.append("a").attr("href", summary_url).text(jsons[j].out)
        header.append("br")
    }

    // load all the stubs
    let promises = []
    for (let t = 0; t < num_tasks; t++) {
        let task_promises = []
        promises.push(task_promises)
        for (let j = 0; j < jsons.length; j++) {
            let json = jsons[j]
            for (let r = 0; r < num_repetitions; r++) {
                let init_stub = json.init_stubs_of_task[t][r]
                init_stub.stub_path = init_stub.out + "/" + init_stub.stub_path
                init_stub.full_path = init_stub.out + "/" + init_stub.path
                init_stub.flat_idx = promises.length

                promises.push(load_json_with_retry(init_stub.stub_path))
            }
        }
    }

    // wait for all promises to resolve
    Promise.all(promises).then(stubs => {
        let done_tasks = []
        let promise_errors = []

        // collect the tasks where all repetitions of all the comparable runs are done
        for (let t = 0; t < num_tasks; t++) {
            let done = true
            for (let j = 0; j < jsons.length; j++) {
                let json = jsons[j]
                for (let r = 0; r < num_repetitions; r++) {
                    let init_stub = json.init_stubs_of_task[t][r]
                    init_stub.final_stub = stubs[init_stub.flat_idx]
                    if (init_stub.final_stub.promise_failed) {
                        promise_errors.push(init_stub)
                    }
                    if (!init_stub.final_stub.done || init_stub.final_stub.promise_failed) {
                        done = false
                    }
                }
            }
            if (done) {
                done_tasks.push({
                    t: t,
                    task: jsons[0].init_stubs_of_task[t][0].task,
                    task_info: jsons[0].task_info[t]
                })
            }
        }
        console.log("total tasks:", num_tasks)
        console.log("done tasks:", done_tasks.length / num_tasks * 100 + "%")
        console.log("promise errors:", promise_errors.length)

        function isapprox(a, b, slack = 1e-3) {
            if (a == -Infinity && b == -Infinity)
                return true
            return Math.abs(a - b) < slack
        }

        // fill in null loglikelihoods with -Infinity, since JSON can't serialize -Infinity
        // also map hit_limit to -Infinity
        for (let dtask of done_tasks) {
            let tinfo = dtask.task_info
            for (let strategy of Object.keys(tinfo.res)) {
                let task_results = tinfo.res[strategy]
                for (let mode of ["train_res", "test_res"]) {
                    task_results[mode].logweight = null_to_neginf(task_results[mode].logweight)
                    for (let io_res of task_results[mode].ios_results) {
                        io_res.loglikelihood = null_to_neginf(io_res.loglikelihood)
                    }
                }
                task_results.totals = {}
                task_results.totals.loglikelihood = task_results.train_res.logweight + task_results.test_res.logweight
                task_results.totals.time = task_results.train_res.stats.time + task_results.test_res.stats.time
                task_results.totals.hit_limit = task_results.train_res.stats.hit_limit || task_results.test_res.stats.hit_limit
            }

            tinfo.train_terminating_strategy = undefined
            tinfo.test_terminating_strategy = undefined

            // for all strategies that did not hit the limit, make sure they agree on the loglikelihood
            for (let strategy of Object.keys(tinfo.res)) {
                if (strategy == "smc")
                    continue // approximate inference
                let task_results = tinfo.res[strategy]
                for (let mode of ["train", "test"]) {
                    let mode_res = mode + "_res"
                    let mode_strategy = mode + "_terminating_strategy"
                    let existing_strategy = tinfo[mode_strategy]
                    let new_hit_limit = task_results[mode_res].stats.hit_limit

                    if (!new_hit_limit) {
                        let new_ll = task_results[mode_res].logweight
                        if (existing_strategy === undefined) { // || existing_strategy === "smc"
                            tinfo[mode_strategy] = strategy
                        } else if (strategy !== "smc") {
                            // if neither strategy is smc, then they should agree
                            assert(isapprox(new_ll, tinfo.res[existing_strategy][mode_res].logweight), "ll mismatch: " + new_ll + " vs " + tinfo.res[existing_strategy][mode_res].logweight + " for " + mode + " of " + strategy + " vs " + existing_strategy)
                        }
                    }
                }
            }

            // whether the limit was hit for EVERY strategy
            tinfo.train_hit_limit = (tinfo.train_terminating_strategy === undefined)
            tinfo.test_hit_limit = (tinfo.test_terminating_strategy === undefined)

            tinfo.only_smc_terminated = tinfo.train_hit_limit && !tinfo.res.smc.train_res.stats.hit_limit
            tinfo.smc_didnt_terminate_but_others_did = !tinfo.train_hit_limit && tinfo.res.smc.train_res.stats.hit_limit
            tinfo.nobody_terminated = tinfo.train_hit_limit && tinfo.res.smc.train_res.stats.hit_limit
            tinfo.smc_and_others_terminated = !tinfo.train_hit_limit && !tinfo.res.smc.train_res.stats.hit_limit
            tinfo.smc_got_neginf = !tinfo.res.smc.train_res.hit_limit && tinfo.res.smc.train_res.logweight == -Infinity
            tinfo.others_got_neginf = !tinfo.train_hit_limit && tinfo.res[tinfo.train_terminating_strategy].train_res.logweight == -Infinity
        }

        let subset = done_tasks.filter(dtask => dtask.task_info.smc_and_others_terminated)
            // .filter(dtask => !dtask.task_info.smc_got_neginf)

        let relative_mse = subset
            .map(dtask => {
                let smc_res = dtask.task_info.res.smc.train_res
                let other_res = dtask.task_info.res[dtask.task_info.train_terminating_strategy].train_res
                return (Math.exp(smc_res.logweight - other_res.logweight) - 1) ** 2
            }).reduce((a, b) => a + b, 0) / subset.length
        console.log("relative mse:", relative_mse)

        let mae_subset = done_tasks.filter(dtask => dtask.task_info.smc_and_others_terminated)
            .filter(dtask => !dtask.task_info.smc_got_neginf)

        let mae = mae_subset
            .map(dtask => {
                let smc_res = dtask.task_info.res.smc.train_res
                let other_res = dtask.task_info.res[dtask.task_info.train_terminating_strategy].train_res
                return Math.abs(smc_res.logweight - other_res.logweight)
            }).reduce((a, b) => a + b, 0) / mae_subset.length
        console.log("mae log:", mae)


        let relative_mse_simple = subset
            .map(dtask => {
                let ll = dtask.task_info.res[dtask.task_info.train_terminating_strategy].train_res.logweight
                return Math.exp((2 * Math.log1p(-Math.exp(ll))) - ll)
            }).reduce((a, b) => a + b, 0) / subset.length
        console.log("relative_mse_simple:", relative_mse_simple)

        
        relative_mse_simple = subset
            .map(dtask => {
                let ll = dtask.task_info.res[dtask.task_info.train_terminating_strategy].train_res.logweight
                return (2 * Math.log1p(-Math.exp(ll))) - ll
            }).reduce((a, b) => logaddexp(a, b), 0) - Math.log(subset.length)
        console.log("relative_mse_simple:", relative_mse_simple)

        function get_final_stub(dtask, j, r) {
            return jsons[j].init_stubs_of_task[dtask.t][r].final_stub
        }
        function get_mcmc_result(dtask, j, r) {
            let results = get_final_stub(dtask, j, r).result
            assert(results.length == 1, "expected 1 mcmc result")
            return results[0]
        }
        function null_to_neginf(x) {
            return x === null ? -Infinity : x
        }
        function get_log_step(dtask, j, r, step) {
            let mcmc_result = get_mcmc_result(dtask, j, r)
            let log_step = mcmc_result.state_log.find(l => l.step == step)
            if (log_step === undefined) {
                // only time it should be missing is if early stopping happened bc we found a deterministic solution.
                // In that case, just use the final step
                // assert(mcmc_result.state_log.length <= log_steps.length)
                // assert(mcmc_result.state_log[mcmc_result.state_log.length - 1].step < step)
                log_step = mcmc_result.state_log[mcmc_result.state_log.length - 1]
            }
            return log_step
        }


        let log_steps = get_mcmc_result(done_tasks[0], 0, 0).state_log.map(l => l.step)
        console.log(log_steps)
        let last_step = log_steps[log_steps.length - 1]


        function inner_invperplexity(task_constrain_res, dtask) {
            let summed_output_length = dtask.task.ios.map(io => io[1].split(",").length - 1 + 1).reduce((a, b) => a + b, 0)
            if (task_constrain_res == null || summed_output_length == 0)
                return 0.
            return Math.exp(null_to_neginf(task_constrain_res.logweight) / summed_output_length)
        }


        function invperplexity(dtask, j, r, step, test = false) {
            let task_constrain_res = get_log_step(dtask, j, r, step)[test ? 'test_res' : 'train_res']
            return inner_invperplexity(task_constrain_res, dtask)
        }

        function gt_invperplexity(dtask, test = false) {
            if (dtask.task_info[test ? 'test_hit_limit' : 'train_hit_limit'])
                return 0.
            let strategy = test ? dtask.task_info.test_terminating_strategy : dtask.task_info.train_terminating_strategy
            let task_constrain_res = dtask.task_info
                .res[strategy][test ? 'test_res' : 'train_res']

            return inner_invperplexity(task_constrain_res, dtask)
        }


        function ll(dtask, j, r, step, test = false) {
            let task_constrain_res = get_log_step(dtask, j, r, step)[test ? 'test_res' : 'train_res']
            if (task_constrain_res == null) // since "nothing" signals a hit limit
                return -Infinity
            return null_to_neginf(task_constrain_res.logweight)
        }
        function lpo(dtask, j, r, step, test = false) {
            return get_log_step(dtask, j, r, step).logprior + ll(dtask, j, r, step, test)
        }

        function ll_near_gt(dtask, j, r, step, test = false, slack = Math.log(10)) {
            assert(!dtask.task_info[test ? 'test_hit_limit' : 'train_hit_limit'])
            let strategy = test ? dtask.task_info.test_terminating_strategy : dtask.task_info.train_terminating_strategy
            return dtask.task_info
                .res[strategy][test ? 'test_res' : 'train_res']
                .logweight - ll(dtask, j, r, step, test) < slack
        }

        function ll_above_other(dtask, j, j_other, r, r_other, step, test = false, slack = Math.log(10)) {
            let ll1 = ll(dtask, j, r, step, test)
            let ll2 = ll(dtask, j_other, r_other, step, test)
            // note this returns false if both are -Infinity
            return ll1 > ll2 + slack
        }

        function kld(logPs, logQs) {
            assert(logPs.every(p => p > -Infinity))
            if (logQs.some(q => q == -Infinity)) {
                return Infinity
            }
            assert(logPs.length == logQs.length)
            let kl = 0
            for (let i = 0; i < logPs.length; i++) {
                kl += logPs[i] - logQs[i]
            }
            return kl / logPs.length
        }

        function kl(dtask, j, r, step, test = false) {
            assert(!dtask.task_info[test ? 'test_hit_limit' : 'train_hit_limit'])
            let strategy = test ? dtask.task_info.test_terminating_strategy : dtask.task_info.train_terminating_strategy

            let logPs = test ? dtask.task_info.res[strategy].test_res.ios_results.map(r => null_to_neginf(r.logweight)) : dtask.task_info.res[strategy].train_res.ios_results.map(r => null_to_neginf(r.logweight))
            let res_key = test ? 'test_res' : 'train_res'
            let tc_res = get_log_step(dtask, j, r, step)[res_key]
            if (tc_res === null)
                return Infinity // since "nothing" signals a hit limit
            let logQs = tc_res.ios_results.map(r => null_to_neginf(r.logweight))
            return kld(logPs, logQs)
        }

        // linear space average over repetitions
        function avg_over_reps_linear(f) {
            return count(num_repetitions)
                .map(r => f(r))
                .reduce((a, b) => a + b) / num_repetitions
        }

        // linear space average over repetitions where each pair of repetitions is considered
        function avg_over_reps_linear_allpairs(f) {
            return count(num_repetitions * num_repetitions)
                .map(r => f(Math.floor(r / num_repetitions), r % num_repetitions))
                .reduce((a, b) => a + b) / (num_repetitions * num_repetitions)
        }

        function avg_over_tasks_linear(tasks, fn) {
            return tasks.map(dtask => fn(dtask))
                .reduce((a, b) => a + b) / tasks.length
        }

        function cumsum(xs) {
            let acc = 0
            let accumulated = []
            for (let x of xs) {
                acc += x
                accumulated.push(acc)
            }
            return accumulated
        }

        for (let j = 0; j < jsons.length; j++) {
            console.log(j + " avg over tasks of avg over reps of unique constrains")
            console.log(avg_over_tasks_linear(done_tasks, dtask => avg_over_reps_linear(r => get_final_stub(dtask, j, r).result[0].unique_constrains)))
        }

        let color_of_strategy = {
            "bdd": "green",
            "lazy": "#0077b6",
            "strict": "#e63946",
            "smc": "#ff9f1c",
            // purple
            "special": "#6a1b9a",
            "dice": "black"
        }
        let name_of_strategy = {
            "bdd": "Ours (Exact)",
            "lazy": "Lazy Enum",
            "strict": "Strict Enumeration",
            "smc": "Ours (SMC) (Approx.)",
            "special": "Special one-off",
            "dice": "Dice.jl"
        }

        // Define markers for each strategy (same as in fuzzing.js)
        let marker_of_strategy = {
            "bdd": "star", // 5-pointed star for Ours (Exact)
            "smc": "diamond", // diamond for Ours (SMC) (Approximate)
            "lazy": "triangle", // triangle for Lazy Enumeration
            "dice": "circle" // circle for Dice.jl
        }

        let strategy_of_j = runs.map(r => r.mode)

        // Function to add markers to the end of lines
        function addMarkerToLine(j, g, x, y) {
            const marker = marker_of_strategy[strategy_of_j[j]];
            
            if (marker === "star") {
                drawStar(g, x, y, 5, 13.5, 6.75, color_of_strategy[strategy_of_j[j]]);
            } else if (marker === "diamond") {
                g.append("rect")
                    .attr("x", x - 9)
                    .attr("y", y - 9)
                    .attr("width", 18)
                    .attr("height", 18)
                    .attr("fill", color_of_strategy[strategy_of_j[j]])
                    .attr("stroke", "white")
                    .attr("stroke-width", 1.5)
                    .attr("transform", `rotate(45, ${x}, ${y})`);
            } else if (marker === "triangle") {
                g.append("polygon")
                    .attr("points", `${x},${y-11.25} ${x-11.25},${y+11.25} ${x+11.25},${y+11.25}`)
                    .attr("fill", color_of_strategy[strategy_of_j[j]])
                    .attr("stroke", "white")
                    .attr("stroke-width", 1.5);
            } else if (marker === "circle") {
                g.append("circle")
                    .attr("cx", x)
                    .attr("cy", y)
                    .attr("r", 9)
                    .attr("fill", color_of_strategy[strategy_of_j[j]])
                    .attr("stroke", "white")
                    .attr("stroke-width", 1.5);
            }
        }

        let no_gt_train_hit_limit = done_tasks.filter(dtask => !dtask.task_info.train_hit_limit)
        console.log("no gt train hit limit:", no_gt_train_hit_limit.length / done_tasks.length * 100 + "%")
        let no_gt_test_hit_limit = done_tasks.filter(dtask => !dtask.task_info.test_hit_limit)
        console.log("no gt test hit limit:", no_gt_test_hit_limit.length / done_tasks.length * 100 + "%")


        {
            // build a cactus plot
            // - take the set of 100 tasks x 3 reps = 300 runs
            // - filter down to the ones that are solved (= within slack of GT)
            // - sort by time taken
            // - take cumulative sum
            // - plot the cumulative sum on y axis against number of tasks on x axis

            // console.log(done_tasks)
            // let slack_ll = Math.log(10)

            let slack_invperplexity = 0.9

            let min_time = 0
            let max_time = 0
            let subset = no_gt_train_hit_limit
            let train_series = []
            for (let j = 0; j < runs.length; j++) {
                let sorted_times = []
                for (let dtask of subset) {
                    for (let r = 0; r < num_repetitions; r++) {
                        // if (ll_near_gt(dtask, j, r, last_step, false, slack_ll)) {
                        if (invperplexity(dtask, j, r, last_step, false) / gt_invperplexity(dtask, false) > slack_invperplexity) {
                            let log_step = get_log_step(dtask, j, r, last_step)
                            // sorted_times.push(log_step.time - (log_step.time_in_eval ? log_step.time_in_eval : 0))
                            sorted_times.push(log_step.time)
                        }
                    }
                }
                sorted_times.sort((a, b) => a - b)
                let cumsummed = cumsum(sorted_times)
                train_series.push(cumsummed)
                if (cumsummed.length == 0) continue
                min_time = Math.min(min_time, cumsummed[0])
                max_time = Math.max(max_time, cumsummed[cumsummed.length - 1])
                console.log(name_of_strategy[strategy_of_j[j]], " solved ", cumsummed.length / (subset.length * num_repetitions), "% of tasks for which we have GTs")
            }

            let cfg = json.config.perp1 || {}

            // let title = json.config.task + ": Tasks within " + slack_invperplexity + "x of Ground Truth Inverse Perplexity"
            let title = cfg.title || json.config.task

            let spec = {
                x_label: "Number of Synthesis Tasks",
                y_label: "Cumulative Time (s)",
                title,
                x: 100,
                y: 50,
                xticks: cfg.xticks || undefined,
                width: 600,
                height: 300,
                xmin: 0.0,
                xmax: subset.length * num_repetitions, // maybe a little confusing that we cant include ones we cant calculate it for
                ymin: 0.,
                ymax: cfg.ymax || max_time*1.1,
                yticks: cfg.yticks || [0, 10000, 20000, 30000, 40000, 50000], // Set y-axis ticks to intervals of 10k, stopping at 50k
                legend: order
                    .filter(strategy => runs.some(r => r.mode === strategy))
                    .map(strategy => ({
                        "name": name_of_strategy[strategy],
                        "color": color_of_strategy[strategy],
                        "marker": marker_of_strategy[strategy]
                    }))
            }

            // Append a new SVG to the body
            let svg = d3.select("body").append("svg")
                .attr("width", 800) // Adjust width as needed
                .attr("height", 500); // Adjust height as needed

            spec.g = svg.append("g");

            let graph = makeGraph(spec);

            graph.y_label.attr("transform", `translate(0, -20)`)

            // Draw strategies in specific order, so BDD is on top, followed by SMC, then others
            // First draw Dice (at the bottom)
            for (let j = 0; j < jsons.length; j++) {
                if (strategy_of_j[j] !== "dice") continue;
                
                let curve = plot_curve(graph, {
                    xs: train_series[j].map((_, i) => i),
                    ys: train_series[j],
                    color: color_of_strategy[strategy_of_j[j]]
                });
                
                // Add marker at the end of the line
                if (train_series[j].length > 0) {
                    const lastIdx = train_series[j].length - 1;
                    const lastX = graph.xScale(lastIdx);
                    const lastY = graph.yScale(train_series[j][lastIdx]);
                    addMarkerToLine(j, graph.g, lastX, lastY);
                }
            }
            
            // Then draw other strategies except bdd, smc, and dice
            for (let j = 0; j < jsons.length; j++) {
                if (strategy_of_j[j] === "bdd" || strategy_of_j[j] === "smc" || strategy_of_j[j] === "dice") continue;
                
                let curve = plot_curve(graph, {
                    xs: train_series[j].map((_, i) => i),
                    ys: train_series[j],
                    color: color_of_strategy[strategy_of_j[j]]
                });
                
                // Add marker at the end of the line
                if (train_series[j].length > 0) {
                    const lastIdx = train_series[j].length - 1;
                    const lastX = graph.xScale(lastIdx);
                    const lastY = graph.yScale(train_series[j][lastIdx]);
                    addMarkerToLine(j, graph.g, lastX, lastY);
                }
            }
            
            // Then draw SMC (Approx)
            for (let j = 0; j < jsons.length; j++) {
                if (strategy_of_j[j] !== "smc") continue;
                
                let curve = plot_curve(graph, {
                    xs: train_series[j].map((_, i) => i),
                    ys: train_series[j],
                    color: color_of_strategy[strategy_of_j[j]]
                });
                
                // Add marker at the end of the line
                if (train_series[j].length > 0) {
                    const lastIdx = train_series[j].length - 1;
                    const lastX = graph.xScale(lastIdx);
                    const lastY = graph.yScale(train_series[j][lastIdx]);
                    addMarkerToLine(j, graph.g, lastX, lastY);
                }
            }
            
            // Finally draw BDD (Exact) on top
            for (let j = 0; j < jsons.length; j++) {
                if (strategy_of_j[j] !== "bdd") continue;
                
                let curve = plot_curve(graph, {
                    xs: train_series[j].map((_, i) => i),
                    ys: train_series[j],
                    color: color_of_strategy[strategy_of_j[j]]
                });
                
                // Add marker at the end of the line
                if (train_series[j].length > 0) {
                    const lastIdx = train_series[j].length - 1;
                    const lastX = graph.xScale(lastIdx);
                    const lastY = graph.yScale(train_series[j][lastIdx]);
                    addMarkerToLine(j, graph.g, lastX, lastY);
                }
            }
        }

        let graph_spec = {
            x_label: "MCMC Steps",
            y_label: "",
            x: 100,
            y: 50,
            width: 600,
            height: 300,
            xmin: 0.0,
            xmax: last_step,
            ymin: 0.0,
            ymax: 1.0,
            legend: count(jsons.length).map(j => ({
                "name": name_of_strategy[strategy_of_j[j]],
                "color": color_of_strategy[strategy_of_j[j]]
            }))
        }

        // plot invperplexity
        {
            let train_series = count(jsons.length).map(j => log_steps.map(step => avg_over_tasks_linear(no_gt_train_hit_limit, dtask => avg_over_reps_linear(r => invperplexity(dtask, j, r, step, false)))))

            let xs_series = count(jsons.length).map(j => log_steps.map(step => avg_over_tasks_linear(done_tasks, dtask => avg_over_reps_linear(r => get_log_step(dtask, j, r, step).time))))

            console.log(train_series)

            let gtp = avg_over_tasks_linear(done_tasks, dtask => gt_invperplexity(dtask, false))
            console.log("gt invperplexity:", gtp)
            let gtp_nonzero = avg_over_tasks_linear(no_gt_train_hit_limit, dtask => gt_invperplexity(dtask, false))
            console.log("gt invperplexity no limit hit:", gtp_nonzero)

            // Append a new SVG to the body
            let svg = d3.select("body").append("svg")
                .attr("width", 800) // Adjust width as needed
                .attr("height", 500); // Adjust height as needed


            let cfg = json.config.perp2 || {}

            let spec = Object.assign({}, graph_spec)
            spec.g = svg.append("g");
            // spec.title = `E_tasks[E_reps[1/perplexity]]`
            spec.title = cfg.title || json.config.task
            spec.x_label = `Time (s)`
            spec.y_label = `Inverse Perplexity`
            spec.ymin = cfg.ymin || 0.15
            // spec.ymax = .6
            spec.ymax = cfg.ymax || gtp_nonzero * 1.1
            spec.xmax = cfg.xmax || jsons.map((json, j) => xs_series[j][xs_series[j].length-1]).reduce((a, b) => Math.max(a, b), 0) + 5
            spec.yticks = cfg.yticks || undefined
            spec.legend = order
                .filter(strategy => runs.some(r => r.mode === strategy))
                .map(strategy => ({
                    "name": name_of_strategy[strategy],
                    "color": color_of_strategy[strategy],
                    "marker": marker_of_strategy[strategy]
                }))

            let graph = makeGraph(spec);

            // move legend
            graph.legend.attr("transform", `translate(${cfg.legend_x || spec.width*.6}, ${cfg.legend_y || spec.height*.7})`)
            
            // Draw strategies in this order:
            // 1. Dice.jl (at the bottom)
            // 2. Other strategies except bdd, smc, dice
            // 3. SMC (Approx)
            // 4. BDD (Exact) (on top)
            
            // First draw Dice.jl
            for (let j = 0; j < jsons.length; j++) {
                if (strategy_of_j[j] !== "dice") continue;
                
                let curve = plot_curve(graph, {
                    xs: xs_series[j],
                    ys: train_series[j],
                    color: color_of_strategy[strategy_of_j[j]]
                });
                
                // Add marker at the end of the line
                if (xs_series[j].length > 0) {
                    const lastIdx = xs_series[j].length - 1;
                    const lastX = graph.xScale(xs_series[j][lastIdx]);
                    const lastY = graph.yScale(train_series[j][lastIdx]);
                    addMarkerToLine(j, graph.g, lastX, lastY);
                }
            }
            
            // Then draw other strategies (lazy, strict, special)
            for (let j = 0; j < jsons.length; j++) {
                // Skip bdd, smc, and dice strategies
                if (strategy_of_j[j] === "dice" || 
                    strategy_of_j[j] === "bdd" || 
                    strategy_of_j[j] === "smc") continue;
                
                let curve = plot_curve(graph, {
                    xs: xs_series[j],
                    ys: train_series[j],
                    color: color_of_strategy[strategy_of_j[j]]
                });
                
                // Add marker at the end of the line
                if (xs_series[j].length > 0) {
                    const lastIdx = xs_series[j].length - 1;
                    const lastX = graph.xScale(xs_series[j][lastIdx]);
                    const lastY = graph.yScale(train_series[j][lastIdx]);
                    addMarkerToLine(j, graph.g, lastX, lastY);
                }
            }
            
            // Now plot the ground truth line
            let gt_line_nonzero = plot_curve(graph, {
                xs: [0, spec.xmax],
                ys: [gtp_nonzero, gtp_nonzero],
                color: "black",
                styles: { "stroke-dasharray": "5,5" }
            });
            
            // text right above it on the righthand side saying "Ground Truth"
            graph.g.append("text")
                .attr("transform", `translate(${spec.width-120}, ${graph.yScale(gtp_nonzero)-10})`)
                .style("font", "20px sans-serif")
                .text("Ground Truth");
                
            // Draw SMC (approximate)
            for (let j = 0; j < jsons.length; j++) {
                if (strategy_of_j[j] !== "smc") continue;
                
                let curve = plot_curve(graph, {
                    xs: xs_series[j],
                    ys: train_series[j],
                    color: color_of_strategy[strategy_of_j[j]]
                });
                
                // Add marker at the end of the line
                if (xs_series[j].length > 0) {
                    const lastIdx = xs_series[j].length - 1;
                    const lastX = graph.xScale(xs_series[j][lastIdx]);
                    const lastY = graph.yScale(train_series[j][lastIdx]);
                    addMarkerToLine(j, graph.g, lastX, lastY);
                }
            }
            
            // Finally draw BDD (exact) on top
            for (let j = 0; j < jsons.length; j++) {
                if (strategy_of_j[j] !== "bdd") continue;
                
                let curve = plot_curve(graph, {
                    xs: xs_series[j],
                    ys: train_series[j],
                    color: color_of_strategy[strategy_of_j[j]]
                });
                
                // Add marker at the end of the line
                if (xs_series[j].length > 0) {
                    const lastIdx = xs_series[j].length - 1;
                    const lastX = graph.xScale(xs_series[j][lastIdx]);
                    const lastY = graph.yScale(train_series[j][lastIdx]);
                    addMarkerToLine(j, graph.g, lastX, lastY);
                }
            }
        }



        

    })
}
