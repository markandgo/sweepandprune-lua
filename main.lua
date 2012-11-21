--[[
Collision detection between 2 boxes
Red when colliding, white otherwise.
Red when a point is contained by a box
Green when area query detects a box
]]

function love.load()
	sap   = require 'sapgrid'
	-- sap   = require 'sweepandprune'
	sapA  = sap(100,100)	
	b1    = {x=0,y=0,w=100,h=100}
	b2    = {x=250,y=250,w=100,h=100}
	b3    = {x=400,y=300,w=300,h=300}
	b4    = {x=100,y=100,w=100,h=100}
	white = {255,255,255}
	red   = {255,0,0}
	green = {0,255,0}
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
	-- queries
	a1      = sapA:areaQuery(b3.x,b3.y,b3.x+b3.w,b3.y+b3.h,true) -- enclosed boxes only
	a2      = sapA:areaQuery(b4.x,b4.y,b4.x+b4.w,b4.y+b4.h)
	p       = sapA:pointQuery(400,400)
	
end

function love.draw()
	love.graphics.setColor(100,100,100)
	sapA:draw() -- draw grid
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
	if a1 and next(a1) then -- color for area query
		love.graphics.setColor(green)
	else
		love.graphics.setColor(white)
	end
	-- draw query area
	love.graphics.rectangle('line',b3.x,b3.y,b3.w,b3.h)
	-----------------
	if a2 and next(a2) then -- color for area query
		love.graphics.setColor(green)
	else
		love.graphics.setColor(white)
	end
	-- draw query area
	love.graphics.rectangle('line',b4.x,b4.y,b4.w,b4.h)
	-----------------
	-- draw point
	if p and next(p) then -- color for point query
		love.graphics.setColor(red)
	else
		love.graphics.setColor(white)
	end
	love.graphics.circle('fill',400,400,5)
	-----------------
end