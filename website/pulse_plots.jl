#-----------------------------------------------------------------------
# PackageEvaluator
# https://github.com/IainNZ/PackageEvaluator.jl
# (c) Iain Dunning 2015. MIT License.
#-----------------------------------------------------------------------
# website/pulse_plots.jl
# Makes the plots for the Pulse page:
# - The totals-by-version plot
# - The stars plot
# - The test status fraction plot
#-----------------------------------------------------------------------

using Gadfly
include("shared.jl")

# Load test history
#if length(ARGS) != 2
#    error("Expected 2 arguments, the path of the test history database and the output filename.")
#end
star_db_file = ARGS[1]
hist_db_file = ARGS[2]
output_path  = ARGS[3]

# Load history databases
hist_db, pkgnames, dates = load_hist_db(hist_db_file)

# Collect totals for each Julia version by date and status
totals = Dict()
for ver in ["0.2","0.3","0.4"]
    totals[ver] = Dict([date => Dict([status => 0 for status in keys(HUMANSTATUS)])
                        for date in dates])
    for pkg in pkgnames
        key = (pkg, ver)
        !(key in keys(hist_db)) && continue
        results = hist_db[key]
        for i in 1:size(results,1)
            date   = results[i,1]
            status = results[i,3]
            totals[ver][date][status]  += 1
            totals[ver][date]["total"] += 1
        end
    end
end

# Print some sanity check info, good for picking up massive failures
println(dates[1], "  ", dates[2])
for status in keys(HUMANSTATUS)
    print(status, "  ")
    print(totals["0.4"][dates[1]][status])
    print("  ")
    print(totals["0.4"][dates[2]][status])
    println()
end

#-----------------------------------------------------------------------
# 1. MAIN PLOT
# Shows total packages by version
println("Printing main plot...")

# Build an x-axis and y-axis for each version
x_dates  = Dict([ver=>Date[] for ver in keys(totals)])
y_totals = Dict([ver=>Int[]  for ver in keys(totals)])
for ver in keys(totals)
    for date in dates
        y = totals[ver][date]["total"]
        if y > 0
            push!(x_dates[ver], dbdate_to_date(date))
            push!(y_totals[ver], y)
        end
    end
end
# Julia releases so far
jl_date_vers = [Date(2014,08,20)  "v0.3.0"  250;
                Date(2014,09,21)  "v0.3.1"  250;
                Date(2014,10,21)  "v0.3.2"  250;
                Date(2014,11,23)  "v0.3.3"  250;
                Date(2014,12,26)  ""        250;
                Date(2015,01,08)  "v0.3.5"  250;
                Date(2015,02,17)  "v0.3.6"  250;
                Date(2015,03,23)  "v0.3.7"  250;
                Date(2015,04,30)  "v0.3.8"  250;
                Date(2015,05,30)  "v0.3.9"  250;
                Date(2015,05,30)  "v0.3.9"  250;
                Date(2015,06,24)  "v0.3.10" 250;
                Date(2015,07,27)  "v0.3.11" 250]
p = plot(
    layer(x=x_dates["0.2"],y=y_totals["0.2"],color=fill("0.2",length(x_dates["0.2"])),Geom.line),
    layer(x=x_dates["0.3"],y=y_totals["0.3"],color=fill("0.3",length(x_dates["0.3"])),Geom.line),
    layer(x=x_dates["0.4"],y=y_totals["0.4"],color=fill("0.4",length(x_dates["0.4"])),Geom.line),
    layer(xintercept=jl_date_vers[:,1],Geom.vline(color=colorant"gray20",size=1px)),
    layer(x=jl_date_vers[:,1],y=jl_date_vers[:,3],label=jl_date_vers[:,2],Geom.label),
    Scale.y_continuous(minvalue=250,maxvalue=700),
    Guide.ylabel("Number of Tagged Packages"),
    Guide.xlabel("Date"),
    Guide.colorkey("Julia ver."),
    Theme(line_width=3px,label_placement_iterations=0))
draw(SVG(joinpath(output_path,"allver.svg"), 8inch, 3inch), p)

#-----------------------------------------------------------------------
# 2. STAR PLOT
# Shows total stars across time
println("Printing star plot...")

star_hist, star_dates = load_star_db(star_db_file)
star_totals = [d => 0 for d in dates]
for pkg in keys(star_hist)
    for (date,stars) in star_hist[pkg]
        star_totals[date] += stars
    end
end

x_dates  = Date[]
y_totals = Int[]
for (date,total) in star_totals
    date == "20140925" && continue  # First entry, not accurate
    date == "20150620" && continue  # Weird spike, double counting?
    push!(x_dates, dbdate_to_date(date))
    push!(y_totals, total)
end
p = plot(
    layer(x=x_dates,y=y_totals,color=ones(length(y_totals)),Geom.line),
    Scale.color_discrete_manual(colorant"gold"),
    Guide.ylabel("Number of Stars"),
    Guide.xlabel("Date"),
    Theme(line_width=3px,key_position=:none))
draw(SVG(joinpath(output_path,"stars.svg"), 8inch, 3inch), p)






#=
plot_status_ver(totals, dates, "0.2", "../test02.svg")
plot_status_ver(totals, dates, "0.3", "../test03.svg")
plot_status_ver(totals, dates, "0.4", "../test04.svg")
plot_status_ver(totals, dates, "0.2", "../test02per.svg",aspercent=true)
plot_status_ver(totals, dates, "0.3", "../test03per.svg",aspercent=true)
plot_status_ver(totals, dates, "0.4", "../test04per.svg",aspercent=true)
=#


# plot_total_allvers
# Plot (with Gadfly) the total number of packages over
# all time and Julia versions.
function plot_status_ver(totals, dates, ver, outfile=""; aspercent=false)
    # Build one x-axis, and y-axis for each status
    # Because we changed over to a new system 6/20/2015, we actually
    # need to collect two different histories otherwise we'll get
    # unsightly 0 totals for the old status forever.
    x_dates_old = Date[]
    x_dates = Date[]
    y_totals_old = [key=>Any[] for key in DBSTATUSCODES[1:5]]
    y_totals = [key=>Any[] for key in DBSTATUSCODES[5:8]]
    for i = 1:length(dates)
        v = totals[ver][dates[i]]
        d = dbdate_to_date(dates[i])
        if d <= Date(2015,6,18)
            # Old statuses
            if v["total"] > 0
                push!(x_dates_old, d)
                for key in DBSTATUSCODES[1:5]
                    push!(y_totals_old[key], 
                        aspercent ? v[key] / v["total"] * 100 :
                                    v[key])
                end
            end
        else
            # New statuses
            if v["total"] > 0
                push!(x_dates, d)
                for key in DBSTATUSCODES[5:8]
                    push!(y_totals[key],
                        aspercent ? v[key] / v["total"] * 100 :
                                    v[key])
                end
            end
        end
    end
    p = plot(
        [layer(x=x_dates_old,y=y_totals_old[key],color=fill("old"*key,length(x_dates_old)),Geom.line) 
            for key in DBSTATUSCODES[1:5]]...,
        [layer(x=x_dates,y=y_totals[key],color=fill("new"*key,length(x_dates)),Geom.line) 
            for key in DBSTATUSCODES[5:8]]...,
        Scale.y_continuous(minvalue=0,maxvalue=aspercent?100:350),
        Guide.ylabel((aspercent?"Percentage":"Number")*" of Packages",orientation=:vertical),
        Guide.xlabel("Date"),
        Guide.title("Julia $ver"),
        #Scale.x_continuous(labels=f->string(f)),
        Scale.color_discrete_manual("green","orange","blue","red","grey",
                                    "grey","green","red","blue"),
        Theme(#=line_width=3px,=#key_position=:none))
    if outfile == ""
        draw(SVG(4inch, 3inch), p)
    else
        draw(SVG(outfile, 4inch, 3inch), p)
    end
end