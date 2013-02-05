--[[
Collision detection between 2 boxes
]]

function love.load()
	sap   = require 'sapgrid'
	-- sap   = require 'sap'
	sapA  = sap(100,100)	
	b1    = {x=0,y=0,w=100,h=100}
	b2    = {x=250,y=250,w=100,h=100}
	white = {255,255,255}
	red   = {255,0,0}
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
	if next(sapA:query(b1)) then b1.color = red else b1.color = white end
	if next(sapA:query(b2)) then b2.color = red else b2.color = white end
end

function love.draw()
	love.graphics.setColor(100,100,100)
	if sapA.draw then sapA:draw() end -- draw grid
	love.graphics.setColor(255,255,255)
	
	love.graphics.setColor(b1.color)
	-- draw rect that follows mouse
	love.graphics.rectangle('line',b1.x,b1.y,b1.w,b1.h)
	love.graphics.setColor(b2.color)
	-- draw static rect
	love.graphics.rectangle('line',b2.x,b2.y,b2.w,b2.h)
end