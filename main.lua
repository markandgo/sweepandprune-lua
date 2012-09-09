--[[
Collision detection between 2 boxes
Red when colliding, white otherwise.
Yellow when enclosure has a box
]]

function love.load()
	sap   = require 'sapgrid'
	-- sap   = require 'sweepandprune'
	sapA  = sap(100,100)	
	b1    = {x=0,y=0,w=100,h=100}
	b2    = {x=250,y=300,w=100,h=100}
	white = {255,255,255}
	red   = {255,0,0}
	line  = {400,300}
	line2 = {200,300}
	b1.color = white
	b2.color = white
	sapA:add(b1,b1.x,b1.y,b1.x+b1.w,b1.y+b1.h)
	sapA:add(b2,b2.x,b2.y,b2.x+b2.w,b2.y+b2.h)
end

t = 0
function love.update(dt)
	t = t+dt
	b1.x,b1.y = love.mouse.getPosition()
	sapA:move(b1,b1.x,b1.y,b1.x+b1.w,b1.y+b1.h)
	sapA:update()
	-----------------
	-- ray coordinates
	line[3],line[4]   = math.cos(t)*400+line[1],math.sin(t)*400+line[2]
	line2[3],line2[4] = math.cos(t)*400+line2[1],math.sin(t)*400+line2[2]
	
	-- queries
	a1      = sapA:areaQuery(400,300,700,600,'enclosed') -- enclosed boxes only
	a2      = sapA:areaQuery(100,100,120,120)
	p       = sapA:pointQuery(400,400)
	r,px,py = sapA:rayQuery(line[1],line[2],line[3]-line[1],line[4]-line[2])
	
	-- returns in order all objects that intersects the line
	for obj,hitx,hity in sapA:iterRay(line2[1],line2[2],line2[3]-line2[1],line2[4]-line2[2]) do
		r2,p2x,p2y = obj,hitx,hity
	end
end

function love.draw()
	love.graphics.setColor(100,100,100)
	-- sapA:draw() -- draw grid
	love.graphics.setColor(255,255,255)
	
	if next(sapA:query(b1)) then b1.color = red else b1.color = white end
	if next(sapA:query(b2)) then b2.color = red else b2.color = white end
	love.graphics.setColor(b1.color)
	-- draw rect that follows mouse
	love.graphics.rectangle('line',b1.x,b1.y,b1.w,b1.h)
	love.graphics.setColor(b2.color)
	-- draw static rect
	love.graphics.rectangle('line',b2.x,b2.y,b2.w,b2.h)
	-----------------
	if a1 and next(a1) then -- color for enclosure query
		love.graphics.setColor(255,255,0)
	else
		love.graphics.setColor(white)
	end
	-- draw query area
	love.graphics.rectangle('line',400,300,300,300)
	-----------------
	if a2 and next(a2) then -- color for enclosure query
		love.graphics.setColor(255,255,0)
	else
		love.graphics.setColor(white)
	end
	-- draw query area
	love.graphics.rectangle('line',100,100,20,20)
	-----------------
	-- draw point
	if p and next(p) then -- color for point query
		love.graphics.setColor(red)
	else
		love.graphics.setColor(white)
	end
	love.graphics.circle('fill',400,400,5)
	-----------------
	-- draw ray
	love.graphics.setColor(white)	
	if r then love.graphics.setColor(red) end
	love.graphics.line(line[1],line[2],px or line[3],py or line[4])
	-----------------
		-- draw ray
	love.graphics.setColor(white)	
	if r2 then love.graphics.setColor(red) end
	love.graphics.line(line2[1],line2[2],p2x or line2[3],p2y or line2[4])
	-----------------
end