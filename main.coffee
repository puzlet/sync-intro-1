#!vanilla

# Temp fix - to be done in puzlet.js.
Number.prototype.pow = (p) -> Math.pow this, p

WebFontConfig = google:
    families: ["Reenie+Beanie::latin"]

#$("#run_button").prop("disabled", true)

# Global stuff

pi = Math.PI
sin = Math.sin
cos = Math.cos
min = Math.min
COS = (u) -> Math.cos(u*pi/180)
SIN = (u) -> Math.sin(u*pi/180)
R2 = Math.sqrt(2)

repRow = (val, m) -> val for [1..m]

{rk, ode} = $blab.ode # Import ODE solver


# work around unicode issue
char = (id, code) -> $(".#{id}").html "&#{code};"
char "deg", "deg"
char "percent", "#37"
char "equals", "#61"


# Vector field (<a href="http://en.wikipedia.org/wiki/Van_der_Pol_oscillator">Van der Pol</a>)

# VdP equation
f = (t, v, mu) -> 
	[
        v[1]
        mu*(1-v[0]*v[0])*v[1]-v[0]
	]


class Vector

    z = -> new Vector

    constructor: (@x=0, @y=0) ->
        
    add: (v=z()) ->
        @x += v.x
        @y += v.y
        this
    
    mag: () -> Math.sqrt(@x*@x + @y*@y)
        
    ang: () -> Math.atan2(@y, @x)
        
    polar: (m, a) ->
        @x = m*Math.cos(a)
        @y = m*Math.sin(a)
        this

class Figure

    @xMax = 4 # horizontal plot limit
    @yMax = 4 # vertical plot limit
    @margin = {top: 65, right: 65, bottom: 65, left: 65}
    @width = 450 - @margin.left - @margin.top
    @height = 450 - @margin.left - @margin.top
    @xscale = d3.scale.linear()
        .domain([-@xMax, @xMax])
        .range([0, @width])
    @yscale = d3.scale.linear()
        .domain([-@yMax, @yMax])
        .range([@height, 0])

class Canvas

    margin = Figure.margin
    width = Figure.width
    height = Figure.height

    constructor: (id) ->

        @canvas = $(id) 
        @canvas[0].width = width
        @canvas[0].height = height
        @ctx = @canvas[0].getContext('2d')
        
    clear: -> @ctx.clearRect(0, 0, width, height)

    square: (pos, size, color) ->
        @ctx.fillStyle = color
        @ctx.fillRect(pos.x, pos.y, size, size)


class vfPoint # vector field point

    width  = Figure.width
    height = Figure.height
    
    constructor: (@x=1, @y=1, @mu=1) ->
        @vel = new Vector 0, 0 # velocity
        @d = 0 # distance

    updateVel: ->
        vel = f(0, [@x, @y], @mu)
        @vel.x = vel[0]
        @vel.y = vel[1]

    move: ->
        @updateVel()
        [@x, @y] = ode(rk[1], f, [0, 0.02], [@x, @y], @mu)[1]
        @d += @vel.mag()

    visible: -> (-4 <= @x <= 4) and (-4 <= @y <= 4) and @d < 200
    
class Particle extends vfPoint

    constructor: (@canvas, x, y, mu) ->
        super x, y, mu

        @size = 2
        @color = ["red", "green", "blue"][Math.floor(3*Math.random())]

    draw: ->
        pos = {x:Figure.xscale(@x), y:Figure.yscale(@y)}
        @canvas.square pos, @size, @color

            
class Emitter
    
    maxParticles: 500
    rate: 3
    ch: Figure.height
    cw: Figure.width
    
    constructor: (@canvas, @mu=1)->
        @particles = []

    directParticles: ->
        unless @particles.length > @maxParticles
            @particles.push(@newParticles()) for [1..@rate]
            
        @particles = @particles.filter (p) => p.visible()
        for particle in @particles
            particle.move()
            particle.draw()

    newParticles: ->
        u = Figure.xMax*(2*Math.random()-1)
        v = Figure.yMax*(2*Math.random()-1)
        position = new Vector u, v
        new Particle @canvas, position.x, position.y, @mu 

    updateMu: ->
        for particle in @particles
            particle.mu = @mu

    
class Checkbox

    constructor: (@id, @change) ->
        @checkbox = $ "##{id}"
        @checkbox.unbind()  # needed to clear event handlers
        @checkbox.on "change", =>
            val = @val()
            @change val
        
    val: -> @checkbox.is(":checked")
    
class d3Object

    constructor: (id) ->
        @element = d3.select "##{id}"
        @element.selectAll("svg").remove()
        @obj = @element.append "svg"
        @initAxes()
        
    append: (obj) -> @obj.append obj
    
    initAxes: -> 

        
class Oscillator extends d3Object
        
    margin = Figure.margin
    width = Figure.width
    height = Figure.height

    constructor: (X) ->
        super X 

        # Clear any previous event handlers.
        @obj.on("click", null)  
        d3.behavior.drag().on("drag", null)
       
        @obj.attr("width", width + margin.left + margin.right)
        @obj.attr("height", height + margin.top + margin.bottom)
        @obj.attr("id", "oscillator")

        @obj.append("g") # x axis
            .attr("class", "axis")
            .attr("transform", "translate(#{margin.left}, #{margin.top+height+10})")
            .call(@xAxis) 

        @obj.append("g") # y axis
            .attr("class", "axis")
            .attr("transform","translate(#{margin.left-10}, #{margin.top})")
            .call(@yAxis) 

        @plot = @obj.append("g") # Plot area
            .attr("id", "plot")
            .attr("transform", "translate(#{margin.left},#{margin.top})")

        @limitCircle = @plot.append("circle")
            .attr("cx", @xscale 0)
            .attr("cy", @yscale 0)
            .attr("r", @xscale(2)-@xscale(0))
            .style("fill", "transparent")
            .style("stroke", "ccc")

        @guide0 = @radialLine()
        @guide1 = @radialLine()

        @marker0 = @marker("black", @guide0)
        @marker1 = @marker("red", @guide1)
        
    marker: (color, guide) ->
        m = @plot.append("circle")
            .attr("r",10)
            .style("fill", color)
            .style("stroke", color)
            .style("stroke-width","1")
            .call(
                d3.behavior
                .drag()
                .origin(=>
                    x:m.attr("cx")
                    y:m.attr("cy")
                )
                .on("drag", => @dragMarker(m, d3.event.x, d3.event.y, guide))
            )
        
    radialLine: ->
        @plot.append('line')
            .attr("x1", @xscale 0)
            .attr("y1", @yscale 0)
            .style("stroke","000")
            .style("stroke-width","1")
        
    dragMarker: (marker, u, v, guide) ->
        marker.attr("cx", u)
        marker.attr("cy", v)
        phi = Math.atan2(@yscale.invert(v), @xscale.invert(u))
        guide.attr("x2", @xscale Figure.xMax*cos(phi))
        guide.attr("y2", @yscale Figure.xMax*sin(phi))

    moveMarker: (marker, u, v) ->
        marker.attr("cx", u)
        marker.attr("cy", v)

    moveGuide: (guide, phi) ->
        guide.attr("x2", @xscale Figure.xMax*cos(phi))
        guide.attr("y2", @yscale Figure.yMax*sin(phi))
         
    initAxes: ->
        @xscale = Figure.xscale
        @xAxis = d3.svg.axis()
            .scale(@xscale)
            .orient("bottom")
        @yscale = Figure.yscale
        @yAxis = d3.svg.axis()
            .scale(@yscale)
            .orient("left")

class Disturbance extends d3Object
        
    margin = Figure.margin
    width = Figure.width
    height = Figure.height
    n = 0
    phiP = 0
    phiM = 0
    omega = 1 # degree/step
    omegaP = 0
    omegaM = 0

    constructor: (X) ->
        super X 

        @spin = 0

        # Clear any previous event handlers.
        @obj.on("click", null)  
        d3.behavior.drag().on("drag", null)
       
        @obj.attr("width", width + margin.left + margin.right)
        @obj.attr("height", height + margin.top + margin.bottom)
        @obj.attr("id", "disturbance")

        @obj.append("svg:defs")
            .append("svg:marker")
            .attr("id", "arrow")
            .attr("viewBox", "0 -5 10 10")
            .attr("refX", 10)
            .attr("refY", 0)
            .attr("markerWidth", 6)
            .attr("markerHeight", 6)
            .attr("orient", "auto")
            .append("svg:path")
            .attr("d", "M0,-5L10,0L0,5")
            .style("stroke","ccc")

        @obj.append("g")
            .attr("class", "axis")
            .attr("transform","translate(#{margin.left-10}, #{margin.top})")
            .call(@yAxis) 

        @plot = @obj.append("g")
            .attr("id", "plot")
            .attr("transform", "translate(#{margin.left},#{margin.top})")

        @markerDistInner = @vector @plot, 0, 1.5
        @markerDistOuter = @vector @plot, 0, 1.5
        
        @markerEquiv1 = @vector @plot, 0, 0.75
        @markerEquiv2 = @vector @plot, 0, 0.75

        @markerSoln = @plot.append("circle")
            .attr("id", "marker-solution")
            .attr("r", 10)
            .attr("cx", @xscale 0 )
            .attr("cy", @yscale 4 )
            .attr("stroke", "black")
            .attr("fill", "transparent")

        @plot.append("circle")
            .attr("r", @xscale(0.75)-@xscale(0))
            .attr("cx", @xscale 0 )
            .attr("cy", @yscale 0 )
            .attr("stroke", "black")
            .attr("fill", "transparent")

        @plot.append("circle")
            .attr("r", @xscale(4)-@xscale(0))
            .attr("cx", @xscale 0 )
            .attr("cy", @yscale 0 )
            .attr("stroke", "black")
            .attr("fill", "transparent")
            .style("stroke-dasharray", ("10,3"))
            .attr("visibility", "visible")

        @ticks = @plot.append("g")
            .attr("id", "ticks")
            .attr("transform", "translate(#{0},#{0})")

        @ticks.selectAll("rect.tick")
            .data(d3.range(24))
            .enter()
            .append("rect")
            .attr("class", "tick")
            .attr("x", 0)
            .attr("y", 70)
            .attr("width", 1)
            .attr("height", (d, i) -> (if (i % 2) then 0 else 15*6))
            .attr("transform", (d, i) =>
                "translate(#{@xscale 0},#{@xscale 0}) rotate(#{i*15+150})"
            )
            .attr("fill", "steelblue")

        @rotate(false)


    vector: (U, x, y) ->

        U.append('line')
            .attr("marker-end", "url(#arrow)")
            .attr("x1", @xscale 0).attr("y1", @yscale x)
            .attr("x2", @xscale 0).attr("y2", @yscale y)
            .attr('id','weightGuideDim')
            .style("stroke","black")
            .style("stroke-width","1")

    rotate: (spin) ->

        if spin
            omegaP = 2*omega
            omegaM = 0
        else
            omegaP = omega
            omegaM = omega
            phiP = 0
            phiM = 0

    move: () ->
        phiP += omegaP # degrees
        phiM += omegaM

        @mag = 1.5*Math.sin(phiM*pi/180)
        
        @markerDistInner.attr("y2", @yscale @mag)
        @markerDistOuter
            .attr("x1", @xscale -4*COS(phiM)).attr("y1", @yscale 4*SIN(phiM))
            .attr("x2", @xscale -4*COS(phiM)).attr("y2", @yscale 4*SIN(phiM)+@mag)
        center = "#{@xscale(0)} #{@yscale(0)}"
        @markerEquiv1.attr("transform", "rotate(#{-phiP+90} #{center} )")
        @markerEquiv2.attr("transform", "rotate(#{phiM-90} #{center} )")
        @markerSoln.attr("transform", "rotate(#{phiM-90} #{center} )")
        @ticks.attr("transform", "rotate(#{phiM} #{center} )")
         
    initAxes: ->
        @xscale = d3.scale.linear()
            .domain([-Figure.xMax, Figure.xMax])
            .range([0, width])

        @yscale = d3.scale.linear()
            .domain([-Figure.yMax, Figure.yMax])
            .range([height, 0])

        @yAxis = d3.svg.axis()
            .scale(@yscale)
            .orient("left")

class Scope extends d3Object

    margin = Figure.margin
    width = Figure.width
    height = Figure.height
    
    constructor: (@spec)->
        
        @hist = repRow(@spec.initVal, @spec.N) # Repeat initial

        super @spec.scope

        @obj.attr("width", width + margin.left + margin.right)
        @obj.attr("height", height + margin.top + margin.bottom)
        @obj.attr("id", "oscillator")

        @obj.append("g")
            .attr("class", "axis")
            .attr("transform","translate(#{0}, #{0})")
            .call(@yAxis) 

        @screen = @obj.append('g')
            .attr("id", "screen")
            .attr('width', width)
            .attr('height', height)
            .attr("transform","translate(#{margin.left}, #{margin.top})")

        gradient = @obj.append("svg:defs") # https://gist.github.com/mbostock/1086421
            .append("svg:linearGradient")
            .attr("id", "gradient")
            .attr("x1", "100%")
            .attr("y1", "100%")
            .attr("x2", "0%")
            .attr("y2", "100%")
            .attr("spreadMethod", "pad");

        gradient.append("svg:stop")
            .attr("offset", "0%")
            .attr("stop-color", "white")
            .attr("stop-opacity", 1);

        gradient.append("svg:stop")
            .attr("offset", "100%")
            .attr("stop-color", @spec.color)
            .attr("stop-opacity", 1);

        @line = d3.svg.line()
            .x((d) =>  @x(d))
            .y((d,i) =>  @hist[i])
            .interpolate("basis")

        if @spec.fade
            strokeSpec = "url(#gradient)"
        else
            strokeSpec = @spec.color    
                                           
        @screen.selectAll('path.trace')
            .data([[0...@spec.N]])
            .enter()
            .append("path")
            .attr("d", @line)
            .attr("class", "trace")
            .style("stroke", strokeSpec)
            .style("stroke-width", 2)

    draw: (val) ->
        @hist.unshift val
        @hist = @hist[0...@hist.length-1]
        @screen.selectAll('path.trace').attr("d", @line)

    show: (bit) ->
        if bit
            @obj.attr("visibility", "visible")
        else
            @obj.attr("visibility", "hidden")
                                                                    
    initAxes: ->
        
        @y = d3.scale.linear()
            .domain([-@spec.yMin, @spec.yMax])
            .range([0, height])

        @x = d3.scale.linear()
            .domain([0, @spec.N-1])
            .range([0, width])

        @xAxis = d3.svg.axis()
            .scale(@x)
            .orient("bottom")
            .tickFormat(d3.format("d"))

        @yAxis = d3.svg.axis()
            .scale(@y)
            .orient("left")

class IntroSim

    constructor: ->

        @canvas = new Canvas "#intro-vector-field"
        @oscillator = new Oscillator "intro-oscillator"
        @vectorField = new Emitter @canvas
        @markerPoint = new vfPoint

        specX =
            scope : "x-scope"
            initVal : Figure.xscale(@markerPoint.x)
            color : "green"
            yMin : -4
            yMax : 4
            width : Figure.width
            height : Figure.height
            N: 255
            fade: 0

        specY =
            scope : "y-scope"
            initVal: Figure.yscale(@markerPoint.y)
            color : "red"
            yMin : -4
            yMax : 4
            width : Figure.width
            height : Figure.height
            N: 255
            fade: 0

        @scopeX = new Scope specX
        @scopeY = new Scope specY

        @persist = new Checkbox "persist" , (v) =>  @.checked = v

        $("#mu-slider").on "change", => @updateMu()
        @updateMu()

        d3.selectAll("#intro-stop-button").on "click", => @stop()
        d3.selectAll("#intro-start-button").on "click", => @start()

        setTimeout (=> @animate() ), 2000


    updateMu: ->
        k = parseFloat(d3.select("#mu-slider").property("value"))
        @markerPoint.mu = k
        @vectorField.mu = k
        @vectorField.updateMu() 
        d3.select("#mu-value").html(k)
        
    snapshot1: ->
        @canvas.clear() if not @.checked
        @vectorField.directParticles()
        @drawMarker()

    snapshot2: ->
        @scopeX.draw Figure.xscale(@markerPoint.x)
        @scopeY.draw Figure.yscale(@markerPoint.y)

    drawMarker: ->
        @markerPoint.move()
        @oscillator.moveMarker(@oscillator.marker0,
            Figure.xscale(@markerPoint.x),
            Figure.yscale(@markerPoint.y)
        )

    animate: ->
        @timer1 = setInterval (=> @snapshot1()), 20
        @timer2 = setInterval (=> @snapshot2()), 50

    stop: ->
        clearInterval @timer1
        clearInterval @timer2
        @timer1 = null
        @timer2 = null

    start: ->
        setTimeout (=> @animate() ), 20


class DistSim

    # Illustrate effect of disturbances with two phase trajectories.
    
    constructor: (@u0=3, @v0=-3, @u1=3, @v1=2) ->

        @oscillator = new Oscillator "dist-oscillator"
        @canvas = new Canvas "#dist-vector-field"
        @point0 = new vfPoint @u0, @v0, 0.1
        @point1 = new vfPoint @u1, @v1, 0.1
        @update()

        d3.selectAll("#dist-stop-button").on "click", => @stop()
        d3.selectAll("#dist-start-button").on "click", => @start()
        d3.selectAll("#dist-scenario-1").on "click", => @restart({x:2.2/R2, y:2.19/R2},{x:1, y:0})

        setTimeout (=> @start() ), 2000

    restart: (p0, p1) =>
        @stop()
        [@point0.x, @point0.y] = [p0.x, p0.y]
        [@point1.x, @point1.y] = [p1.x, p1.y]
        @update()
        @start()

    update: ->
        @markerUpdate(@point0,  @oscillator.marker0)
        @markerUpdate(@point1,  @oscillator.marker1)
        @guideUpdate(@point0, @oscillator.guide0)
        @guideUpdate(@point1, @oscillator.guide1)

    markerUpdate: (point, marker) ->
        marker.attr("cx", Figure.xscale point.x)
        marker.attr("cy", Figure.yscale point.y)

    guideUpdate: (point, guide) ->
        @oscillator.moveGuide(guide, Math.atan2(point.y, point.x))

    snapshot: ->
        @point0.move()
        @point1.move()

        @oscillator.moveMarker(@oscillator.marker0, Figure.xscale(@point0.x), Figure.yscale(@point0.y))
        @oscillator.moveMarker(@oscillator.marker1, Figure.xscale(@point1.x), Figure.yscale(@point1.y))

        @guideUpdate(@point0, @oscillator.guide0)
        @guideUpdate(@point1, @oscillator.guide1)

        @canvas.square {x:Figure.xscale(@point0.x), y:Figure.yscale(@point0.y)}, 2, "black"
        @canvas.square {x:Figure.xscale(@point1.x), y:Figure.yscale(@point1.y)}, 2, "red"

    animate: ->
        @timer = setInterval (=> @snapshot()), 20

    stop: ->
        clearInterval @timer
        @timer = null

    start: ->
        # Update vector field points (marker may have been dragged).
        @point0.x = Figure.xscale.invert @oscillator.marker0.attr("cx")
        @point0.y = Figure.yscale.invert @oscillator.marker0.attr("cy")
        @point1.x = Figure.xscale.invert @oscillator.marker1.attr("cx")
        @point1.y = Figure.yscale.invert @oscillator.marker1.attr("cy")

        @canvas.clear()
        
        setTimeout (=> @animate() ), 20


class SyncSim

    # Illustrate synchronization in rotating frame.
    
    constructor:  ->
        @disturbance = new Disturbance "sync-oscillator"

        spec =
            scope : "sync-scope"
            initVal: 160
            color : "green"
            yMin : -4
            yMax : 4
            width : 320
            height : 320
            N: 101
            fade: 1  
        @scope = new Scope spec

        new Checkbox "trace" , (v) =>  @scope.show(v)
        new Checkbox "spin" , (v) =>  @disturbance.rotate(v)

        setTimeout (=> @animate() ), 2000

    animate: ->
        @timer1 = setInterval (=> @snapshot1()), 20
        @timer2 = setInterval (=> @snapshot2()), 50

    snapshot1: ->
        @disturbance.move()

    snapshot2: ->
        @scope.draw(@disturbance.yscale @disturbance.mag)


new IntroSim
new DistSim
#new SyncSim

#d3.selectAll("#stop-button").on "click", ->
#    distSim.stop()
