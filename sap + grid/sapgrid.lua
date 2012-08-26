--[[
sapgrid.lua v1.3

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
	self.deletebuffer[obj]      = nil -- override deletion when moving
	self.objects[obj].x0t.value = x0
	self.objects[obj].y0t.value = y0
	self.objects[obj].x1t.value = x1
	self.objects[obj].y1t.value = y1
	
	local cell_x0 = floor(x0/self.width)
	local cell_x1 = floor(x1/self.width)
	local cell_y0 = ceil(y0/self.height)-1 --https://love2d.org/forums/viewtopic.php?f=4&t=10462
	local cell_y1 = ceil(y1/self.height)-1
	
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
			sap:add(obj)
		end
	end	
end

grid.add = function (self,obj,x0,y0,x1,y1)	
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
		for obj2,_ in pairs(self.objects[obj].intersections) do
			self.objects[obj2].intersections[obj] = nil
		end
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
	for obj2,_ in pairs(self.objects[obj].intersections) do
		list[obj2] = obj2
	end
	return list
end

grid.queryIter = function(self,obj)
	return pairs(self:query(obj))
end

return function(cell_width,cell_height)
	-- prepare cells table and new sap behavior
	local _removeCallback	= function (self) -- remove object from instance
		for obj in pairs(self.deletebuffer) do
			self.inSAP[obj]         = nil
			self.deletebuffer[obj]  = nil
		end
	end
	local add = function (self,obj)
		self.deletebuffer[obj] = nil
		if not self.inSAP[obj] then
			self.inSAP[obj]=obj
			local x0t = self.objects[obj].x0t
			local y0t = self.objects[obj].y0t
			local x1t = self.objects[obj].x1t
			local y1t = self.objects[obj].y1t
			insert(self.xbuffer,x0t) -- batch insertion buffer
			insert(self.ybuffer,y0t)
			insert(self.xbuffer,x1t)
			insert(self.ybuffer,y1t)
		end
	end
	local objects = {}
	local yMeta   = {__index = function(t,y)
		local s           = sap()
		s.inSAP           = {}
		s._removeCallback = _removeCallback
		s.objects         = objects
		s.add             = add
		return rawset(t,y,s)[y]
	end}
	local xMeta   = {__mode = 'v',__index = function(t,x)
		return rawset(t,x,setmetatable({},yMeta))[x]
	end}

	cell_width = cell_width or 100
	local instance = {
		width         = cell_width,
		height        = cell_height or cell_width,
		cells         = setmetatable({},xMeta),
		objects       = objects,
		deletebuffer  = {},
	}
	return setmetatable(instance,grid)
end