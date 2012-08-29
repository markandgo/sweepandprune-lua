--[[
sapgrid.lua v1.3a

Copyright (c) <2012> <Minh Ngo>

Permission is hereby granted, free of charge, to any person obtaining a copy of this software 
and associated documentation files (the "Software"), to deal in the Software without 
restriction, including without limitation the rights to use, copy, modify, merge, publish, 
distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the 
Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or 
substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING 
BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND 
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, 
DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING 
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
]]--
local insert,floor,ceil,pairs = table.insert,math.floor,math.ceil,pairs

local path  = (...):match('^.*[%.%/]') or ''
local sap   = require(path .. 'sweepandprune')

local grid    = {}	
grid.__index  = grid

grid.move = function (self,obj,x0,y0,x1,y1)
	self.objects[obj].x0t.value = x0
	self.objects[obj].y0t.value = y0
	self.objects[obj].x1t.value = x1
	self.objects[obj].y1t.value = y1
	
	local cell_x0 = floor(x0/self.width)
	local cell_x1 = floor(x1/self.width)
	local cell_y0 = floor(y0/self.height)
	local cell_y1 = floor(y1/self.height)
	
	local rows = self.objects[obj].rows
	for sap,_ in pairs(rows) do -- delete old cells
		rows[sap] = nil
		sap:delete(obj)
	end
	
	for x = cell_x0,cell_x1 do -- put object into new cells
		for y = cell_y0,cell_y1 do
			local row = self.cells[x]
			local sap = row[y]
			rows[sap] = row -- row reference to prevent garbage collecting
			sap:add(self.objects[obj])
		end
	end	
end

grid.add = function (self,obj,x0,y0,x1,y1)	
	self.deletebuffer[obj] = nil
	if not self.objects[obj] then
		local x0t = {value = nil,interval = 0,obj = obj}
		local y0t = {value = nil,interval = 0,obj = obj}
		local x1t = {value = nil,interval = 1,obj = obj}
		local y1t = {value = nil,interval = 1,obj = obj}

		self.objects[obj] = {
			x0t           = x0t,
			y0t           = y0t,
			x1t           = x1t,
			y1t           = y1t,
			intersections = {},
			rows          = {},
		}
	end
	self:move(obj,x0,y0,x1,y1)
	return obj
end

grid.delete = function (self,obj)
	assert(self.objects[obj],'invalid object')
	self.deletebuffer[obj] = obj
	
	for sap,_ in pairs(self.objects[obj].rows) do
		sap:delete(obj)
	end
end

local clearDeleteBuffer = function(self)
	for obj,_ in pairs(self.deletebuffer) do -- clear objects in delete buffer
		self.objects[obj]       = nil
		self.deletebuffer[obj]  = nil
	end
end

grid.update = function (self)
	clearDeleteBuffer(self)

	for x,xt in pairs(self.cells) do
		for y,sap in pairs(xt) do
			sap:update()
		end
	end
end

grid.query = function (self,obj)
	local list = {}
	for sap in pairs(self.objects[obj].rows) do -- check pairs reported in each sap
		for obj2 in pairs(sap.objects[obj].intersections) do
			list[obj2] = obj2
		end
	end
	return list
end

grid.queryIter = function(self,obj)
	return pairs(self:query(obj))
end

grid.draw = function(self) -- for debugging/visualization
	for x,t in pairs(self.cells) do
		for y,sap in pairs(t) do
				if next(sap.objects) then
					love.graphics.rectangle('line',x*self.width,y*self.height,self.width,self.height)
					love.graphics.print(x .. ',' .. y,x*self.width,y*self.height)
				end
		end
	end
end

return function(cell_width,cell_height)
	local add = function (self,objT)
		local obj = objT.x0t.obj
		self.deletebuffer[obj] = nil
		if not self.objects[obj] then
			self.objects[obj] = {x0t=objT.x0t,y0t=objT.y0t,x1t=objT.x1t,y1t=objT.y1t,intersections={}} -- dummy objT
			insert(self.xbuffer,objT.x0t)
			insert(self.ybuffer,objT.y0t)
			insert(self.xbuffer,objT.x1t)
			insert(self.ybuffer,objT.y1t)
		end
	end
	local yMeta   = {__index = function(t,y)
		local s           = sap()
		s.add             = add
		t[y]              = s
		return s
	end}
	local xMeta   = {__mode = 'v',__index = function(t,x)
		t[x] = setmetatable({},yMeta)
		return t[x]
	end}

	cell_width = cell_width or 100
	local instance = {
		width         = cell_width,
		height        = cell_height or cell_width,
		cells         = setmetatable({},xMeta),
		objects       = {},
		deletebuffer  = {},
	}
	return setmetatable(instance,grid)
end