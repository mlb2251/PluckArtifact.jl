"use strict";

const header = d3.select("body").append("div").style("white-space", "nowrap")
const table_div = d3.select("body").append("div")
d3.select("body").append("br")
make_controls()
add_svg()
const lower_table_div = d3.select("body").append("div")
reload()

function reload() {
    clear_svg()
    resize_svg()
    // load bdd json
    load_by_path(json => {
        // console.log(json)
        let group = json.groups[url_params.get("group") || 0]
        // let groups = url_params.getAll("group").map(i => json.groups[i])
        // console.log(group)

        if (group.subgroups) {
            let groups = group.subgroups.map(subgroup => json.groups.find(g => g.config.task === subgroup))
            load_jsons(groups.map(group => group.eval_file), jsons => {
                let combined = combine_groups(group, groups, jsons)
                show_results(combined)
            })
        } else {
            load_json(group.eval_file, json => {
                group.eval_results = json
                show_results(group)
            })
        }
    })
}

function make_controls() {
    add_controls()
    let controls = get_controls()
}

function combine_groups(group, groups, jsons) {
    group.subgroups = groups
    group.eval_results = combine_results(jsons)
    return group
}

function combine_results(jsons) {
    let combined = {
        task_info: [],
        tasks: [],
    }
    for (let json of jsons) {
        combined.task_info.push(...json.task_info)
        combined.tasks.push(...json.tasks)
    }
    return combined
}

function show_results(group) {
    let json = group.eval_results
    console.log(json)



    let tinfos = json.task_info
    window.tinfos = tinfos
    let time_limit = json.time_limit
    window.json = json


    for (let i=0; i<tinfos.length; i++) {
        tinfos[i].task = json.tasks[i]
    }

    // make header with some config info
    header.selectAll("*").remove()
    header.append("span").text("tinfos dir: " + json.dir)
    header.append("br")
    header.append("span").text("results dir: " + url_params.get("path"))
    header.append("br")
    header.append("span").text("time limit: " + time_limit)
    header.append("br")

    if (json.task_dist) {
        for (let [k, v] of Object.entries(json.task_dist)) {
            if (k === "grammar") continue
            header.append("span").text(k + ": " + v)
            header.append("br")
        }

        for (let line of json.task_dist.grammar.split("\n")) {
            header.append("span").text(line)
            header.append("br")
        }
    }

    let strategies = Object.keys(tinfos[0].res)
    console.log(strategies)

    let order = ["smc", "bdd", "lazy", "strict", "special", "dice"]

    let name_of_strategy = {
        "bdd": "Ours (Exact)",
        "lazy": "Lazy Enumeration",
        "strict": "Strict Enumeration",
        "smc": "Ours (SMC) (Approximate)",
        "special": "Special one-off",
        "dice": "Dice.jl"
    }

    let color_of_strategy = {
        "bdd": "green",
        "lazy": "#0077b6",
        "strict": "#e63946",
        "smc": "#ff9f1c",
        "special": "#6a1b9a",
        "dice": "black"
    }

    strategies.sort((a, b) => order.indexOf(a) - order.indexOf(b))

    // let strategies = ["bdd"]

    // fill in null loglikelihoods with -Infinity, since JSON can't serialize -Infinity
    // also map hit_limit to -Infinity
    for (let tinfo of json.task_info) {
        for (let strategy of strategies) {
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
            // task_results.totals.hit_limit_time = task_results.train_res.stats.hit_limit_time || task_results.test_res.stats.hit_limit_time
        }
    }


    // for (let tinfo of json.task_info) {
    //     for (let strategy of strategies) {
    //         let task_results = tinfo.res[strategy]
    //         task_results.train_res.logweight
    //         for (let io_res of task_results[mode].ios_results) {
    //             io_res.loglikelihood = null_to_neginf(io_res.loglikelihood)
    //         }
    //     }
    // }






    table_div.selectAll("*").remove()
    let table = table_div.append("table")
    let header_row = table.append("tr")

    let headers = ["strategy", "% terminated", "avg time", "avg time (hit limit)", "max time", "total loglikelihood"]
    for (let header of headers) {
        header_row.append("th").text(header)
    }


    for (let strategy of strategies) {
        let row = table.append("tr")

        console.log("strategy", strategy)
        // console.log( tinfos.filter(tinfo => tinfo.res[strategy].totals.hit_limit_time).length /
        //     tinfos.filter(tinfo => tinfo.res[strategy].totals.hit_limit).length * 100)
        let tinfos_hit_limit = tinfos.filter(tinfo => tinfo.res[strategy].totals.hit_limit)
        let tinfos_not_hit_limit = tinfos.filter(tinfo => !tinfo.res[strategy].totals.hit_limit)
        row.append("td").text(strategy)
        let finished_rate = tinfos_not_hit_limit.length / tinfos.length
        row.append("td").text((finished_rate * 100).toFixed(1) + "%")
        let avg_time = tinfos.map(tinfo => tinfo.res[strategy].totals.time).reduce((a, b) => a + b, 0) / tinfos.length
        let avg_time_hit_limit = tinfos_hit_limit
            .map(tinfo => tinfo.res[strategy].totals.time)
            .reduce((a, b) => a + b, 0) / tinfos_hit_limit.length
        row.append("td").text((avg_time * 1000).toFixed(2) + "ms")
        row.append("td").text((avg_time_hit_limit * 1000).toFixed(2) + "ms")
        let max_time = tinfos.map(tinfo => tinfo.res[strategy].totals.time).reduce((a, b) => Math.max(a, b), 0)
        row.append("td").text((max_time * 1000).toFixed(2) + "ms")

        let total_loglikelihood = tinfos
            .map(tinfo => tinfo.res[strategy].totals.loglikelihood)
            .reduce(logaddexp, -Infinity)
        row.append("td").text(total_loglikelihood.toFixed(3))
    }


    // lets make another table, this one just has the number of size 0, 1, 2, 3, etc. programs up to 8 then a 9+ column
    table_div.append("br")
    table_div.append("div").text("Program size distribution:")
    let size_table = table_div.append("table")
    let size_header_row = size_table.append("tr")
    let row = size_table.append("tr")
    for (let i = 0; i < 20; i++) {
        size_header_row.append("th").text(i)
        let num_size_i = tinfos.filter(tinfo => tinfo.size === i).length / tinfos.length
        row.append("td").text((num_size_i * 100).toFixed(1) + "%")
    }
    // 9+ row
    size_header_row.append("th").text("20+")
    let num_size_20plus = tinfos.filter(tinfo => tinfo.size >= 20).length / tinfos.length
    row.append("td").text((num_size_20plus * 100).toFixed(1) + "%")

    // cactus plot data
    let sorted = {}
    let cumulative = {}
    let min_time = 0
    let max_time = 0
    for (let strategy of strategies) {
        sorted[strategy] = tinfos
            .filter(tinfo =>
                !tinfo.res[strategy].totals.hit_limit
                // !tinfo.res[strategy].train_res.ios_results[0].stats.hit_limit
            )
            .map(tinfo => tinfo.res[strategy].totals.time)
            // .map(tinfo => tinfo.res[strategy].train_res.ios_results[0].stats.time)
            .sort((a, b) => a - b)
        cumulative[strategy] = []
        let acc = 0
        for (let time of sorted[strategy]) {
            acc += time
            cumulative[strategy].push(acc)
        }
        if (cumulative[strategy].length == 0) continue
        min_time = Math.min(min_time, cumulative[strategy][0])
        max_time = Math.max(max_time, cumulative[strategy][cumulative[strategy].length - 1])
    }

    // for (let strategy of strategies) {
    //     // add one fake data point to cumulative to make the curve reach max time
    //     cumulative[strategy].push(max_time)
    // }
    
    let graph_width = 600
    let graph_height = group.config.height || 175
    let ymax = group.config.ymax || max_time
    let y_scale = d3.scaleLinear().domain([min_time, ymax]).range([graph_height, 0])
    let x_scale = d3.scaleLinear().domain([0, tinfos.length]).range([0, graph_width])

    let g_graph = get_foreground().append("g")
        .attr("transform", `translate(200, 100)`)
    g_graph.append("g")
        .attr("transform", `translate(0, ${graph_height})`)
        .call(d3.axisBottom(x_scale));
    let leftaxis = d3.axisLeft(y_scale)
    if (group.config.yticks) {
        leftaxis.tickValues(group.config.yticks)
    }
    g_graph.append("g")
        .call(leftaxis
            // .tickValues([0,1,2,3,4,5,6,7])
        );

    // x axis label
    g_graph.append("text")
        .attr("x", graph_width / 2)
        .attr("y", graph_height + 60)
        .style("font", "18px sans-serif")
        .style("text-anchor", "middle")
        .text("Programs Successfully Evaluated")

    // y axis label
    g_graph.append("g")
        .attr("transform", `translate(-60, ${graph_height/2}) rotate(-90)`)
        .append("text")
        .style("font", "18px sans-serif")
        .style("text-anchor", "middle")
        .text("Cumulative Time (s)")
        // .style("transform", "rotate(-90deg)")

    for (let i = 0; i < strategies.length; i++) {
        let strategy = strategies[i]
        if (cumulative[strategy].length == 0) continue
        // console.log(strategy)
        // console.log(cumulative[strategy])
        let curve = g_graph.append("path")
            .datum(cumulative[strategy].map((x, j) => [x_scale(j), y_scale(x)]))
            .attr("d", d3.line().x(d => d[0]).y(d => d[1]))
            .attr("stroke", color_of_strategy[strategy])
            .attr("fill", "none")
            .attr("stroke-width", 4)
    }

    // add a legend
    if (url_params.get("hide_legend") != "true") {
        let legend = g_graph.append("g")
            .attr("transform", `translate(40, 10)`)
        for (let i = 0; i < strategies.length; i++) {
            legend.append("rect")
                .attr("x", 0)
                .attr("y", i * 20) // Reduced spacing from 25 to 20
                .attr("width", 15)
                .attr("height", 15)
                .attr("fill", color_of_strategy[strategies[i]])
            legend.append("text")
                .attr("x", 20)
                .attr("y", i * 20 + 10) // Reduced spacing from 25 to 20
                .text(name_of_strategy[strategies[i]])
                .style("font", "18px sans-serif")
                .style("dominant-baseline", "middle")
        }
    }

    // add a title
    g_graph.append("text")
        .attr("x", graph_width / 2)
        .attr("y", -30)
        .style("font", "24px sans-serif")
        .style("text-anchor", "middle")
        .text(group.config.title || group.config.task)



    // tables showing examples where each method beats others

    for (let strategy of strategies) {
        for (let other_strategy of strategies) {
            if (strategy === other_strategy) continue

            let subtinfos = tinfos
                // .filter(tinfo => tinfo.res[strategy].totals.time < time_limit && tinfo.res.totals[other_strategy].time > time_limit)
                .filter(tinfo => !tinfo.res[strategy].totals.hit_limit && tinfo.res[other_strategy].totals.hit_limit)
                // .filter(tinfo => !tinfo.res[strategy].totals.hit_limit && tinfo.res[strategy].totals.time < tinfo.res.totals[other_strategy].time)
                .sort((a, b) => a.size - b.size)

            let table = lower_table_div.append("table")
            let header_row = table.append("tr")
            header_row.append("th").text(strategy)
            header_row.append("th").text(other_strategy)
            header_row.append("th").text(`expr (total=${subtinfos.length})`)
            header_row.append("th").text("input")
            header_row.append("th").text("output")

            
            let num_to_show = Math.min(subtinfos.length, 100)
            for (let i = 0; i < num_to_show; i++) {
                let tinfo = subtinfos[i]
                let row = table.append("tr")
                row.append("td").text(tinfo.res[strategy].totals.time)
                row.append("td").text(tinfo.res[other_strategy].totals.time)
                row.append("td").text(tinfo.task.solution)
                row.append("td").text(tinfo.task.ios[0][0])
                row.append("td").text(tinfo.task.ios[0][1])
            }

        }
    }


    // expressions nobody got
    let nobody_got = tinfos.filter(tinfo => strategies.every(strategy => tinfo.res[strategy].totals.hit_limit))
        .sort((a, b) => a.size - b.size)

    lower_table_div.append("div").text("Expressions nobody got:")
    let nobody_got_table = lower_table_div.append("table")
    let nobody_got_header_row = nobody_got_table.append("tr")
    nobody_got_header_row.append("th").text("expr")
    nobody_got_header_row.append("th").text("input")
    nobody_got_header_row.append("th").text("output")
    for (let tinfo of nobody_got) {
        let row = nobody_got_table.append("tr")
        row.append("td").text(tinfo.task.solution)
        row.append("td").text(tinfo.task.ios[0][0])
        row.append("td").text(tinfo.task.ios[0][1])
    }



}

