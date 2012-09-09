--[[
sapgrid.lua v1.4b

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
local insert 	= table.insert
local floor		= math.floor
local ceil		= math.ceil
local max			= math.max
local setmt   = setmetatable

local path    = (...):match('^.*[%.%/]') or ''
local sap     = require(path .. 'sweepandprune')
local add_mod = function (self,objT)
	local obj = objT.x0t.obj
	self.deletebuffer[obj] = nil
	if not self.objects[obj] then
		-- setup dummy tables
		self.objects[obj] = setmt({intersections = {}},objT)
		insert(self.xbuffer,setmt({stabs = 0},objT.x0t))
		insert(self.ybuffer,setmt({stabs = 0},objT.y0t))
		insert(self.xbuffer,setmt({stabs = 0},objT.x1t))
		insert(self.ybuffer,setmt({stabs = 0},objT.y1t))
	end
end

local sap_mod = function()
	local s = sap()
	s.add   = add_mod
	return s
end

local weakValues = {__mode = 'v'}
local weakKeys   = {__mode = 'k'}

local grid    = {}	
grid.__index  = function(t,k)
	t[k] = grid[k]
	return t[k]
end

grid.move = function (self,obj,x0,y0,x1,y1)
	local w,h = x1-x0,y1-y0
	self.objects[obj].x0t.value = x0
	self.objects[obj].y0t.value = y0
	self.objects[obj].x1t.value = x1
	self.objects[obj].y1t.value = y1
	-- rasterize to grid coordinates
	local cell_x0 = floor(x0/self.width)
	-- use max for point x1 = x0 cases
	local cell_x1 = max(ceil(x1/self.width)-1,cell_x0)
	local cell_y0 = floor(y0/self.height)
	local cell_y1 = max(ceil(y1/self.width)-1,cell_y0)
	
	local rows = self.objects[obj].rows
	-- delete old references so garbage collector can take 
	for sap,_ in pairs(rows) do 
		rows[sap] = nil
		sap:delete(obj)
		self.activeSAP[sap] = true
	end
	
	-- put object into new cells
	for x = cell_x0,cell_x1 do
		local row     = self.cells[x] or setmt({},weakValues)
		self.cells[x] = row
		for y = cell_y0,cell_y1 do
			local sap = row[y] or sap_mod()
			row[y]    = sap
			-- row reference to prevent garbage collecting
			rows[sap] = row 
			sap:add(self.objects[obj])
			self.activeSAP[sap] = true
		end
	end	
end

grid.add = function (self,obj,x0,y0,x1,y1)	
	self.deletebuffer[obj] = nil
	if not self.objects[obj] then
		local x0t = {value = nil,interval = 0,obj = obj}
		x0t.__index = x0t
		local y0t = {value = nil,interval = 0,obj = obj}
		y0t.__index = y0t
		local x1t = {value = nil,interval = 1,obj = obj}
		x1t.__index = x1t
		local y1t = {value = nil,interval = 1,obj = obj}
		y1t.__index = y1t

		self.objects[obj] = {
			x0t           = x0t,
			y0t           = y0t,
			x1t           = x1t,
			y1t           = y1t,
			intersections = {},
			rows          = {},
		}
		self.objects[obj].__index = self.objects[obj]
	end
	self:move(obj,x0,y0,x1,y1)
	return obj
end

grid.delete = function (self,obj)
	assert(self.objects[obj],'invalid object')
	self.deletebuffer[obj] = obj
	
	for sap,_ in pairs(self.objects[obj].rows) do
		sap:delete(obj)
		self.activeSAP[sap] = true
	end
end

local clearDeleteBuffer = function(self)
	for obj,_ in pairs(self.deletebuffer) do
		self.objects[obj]       = nil
		self.deletebuffer[obj]  = nil
	end
end

grid.update = function (self)
	clearDeleteBuffer(self)
	-- only update active cells
	-- cells count as active when there is an add,delete, or move operation called for each sap
	for sap in pairs(self.activeSAP) do
		sap:update()
		self.activeSAP[sap] = nil
	end
end

grid.query = function (self,obj)
	local list = {}
	-- check pairs reported in each sap
	for sap in pairs(self.objects[obj].rows) do
		for obj2 in pairs(sap.objects[obj].intersections) do
			list[obj2] = obj2
		end
	end
	return list
end

grid.areaQuery = function(self,x0,y0,x1,y1,mode)
	local set     = {}
	local cell_x0 = floor(x0/self.width)
	local cell_x1 = max(ceil(x1/self.width)-1,cell_x0)
	local cell_y0 = floor(y0/self.height)
	local cell_y1 = max(ceil(y1/self.width)-1,cell_y0)
	for x = cell_x0,cell_x1 do
		local row = self.cells[x]
		for y = cell_y0,cell_y1 do
			if row and row[y] then
				set[#set+1] = row[y]:areaQuery(x0,y0,x1,y1,mode)
			end
		end
	end
	-- add queries from other cells
	for i = 2,#set do
		for obj in pairs(set[i]) do
			set[1][obj] = obj
		end
	end
	return set[1]
end

grid.pointQuery = function(self,x,y)
	local x0    = floor(x/self.width)
	local y0    = floor(y/self.height)
	if self.cells[x0] and self.cells[x0][y0] then
		return self.cells[x0][y0]:pointQuery(x,y)
	end
end

local raycast = function(self,x,y,dx,dy,isCoroutine)
	local set   = {}
	local x0,y0 = floor(x/self.width),floor(y/self.height)
	local dxRatio,dyRatio,xStep,yStep,smallest
	-- cell side to check [0 1]
	-- moving positively --> add 1 to the current cell's coordinate [cell(x,y) ray ------> ]
	local xside,yside = 0,0
	-- set up our directions when stepping
	if dx > 0 then xStep = 1 xside = 1 else xStep = -1 end
	if dy > 0 then yStep = 1 yside = 1 else yStep = -1 end
	
	-- dxRatio: ((x0+xside)*width-x)/dx precalculations
	local a,b,c = self.width/dx,xside*self.width/dx,x/dx
	local d,e,f = self.height/dy,yside*self.height/dy,y/dy
	
	-- delta is length on axis to cross one voxel
	-- always take the shortest delta to reach the next nearest voxel
	local xDelta,yDelta = a*xStep,d*yStep
	dxRatio,dyRatio = a*x0+b-c,d*y0+e-f
	
	repeat
		local row = self.cells[x0]
		if row and row[y0] then
			-- if called as an iterator, iterate through all objects in the cell
			-- otherwise, do function return
			for obj,hitx,hity in row[y0]:iterRay(x,y,dx,dy) do
				if isCoroutine then
					if not set[obj] then coroutine.yield(obj,hitx,hity); set[obj]=true end
				else 
					return obj,hitx,hity 
				end
			end
		end
		
		-- dxRatio,dyRatio = a*x0+b-c,d*y0+e-f
		-- smallest distance ratio --> determines which cell wall was hit first
		if dxRatio < dyRatio then
			smallest = dxRatio
			dxRatio = dxRatio + xDelta
			x0 = x0 + xStep
		else
			smallest = dyRatio
			dyRatio = dyRatio + yDelta
			y0 = y0 + yStep
		end
	until smallest > 1
end

grid.rayQuery = raycast

grid.iterRay = function(self,x,y,dx,dy)
	return coroutine.wrap(function()
		raycast(self,x,y,dx,dy,true)
	end)
end

grid.draw = function(self)
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
	cell_width = cell_width or 100
	local instance = {
		width         = cell_width,
		height        = cell_height or cell_width,
		cells         = setmt({},weakValues),
		objects       = {},
		deletebuffer  = {},
		activeSAP     = setmetatable({},weakKeys)
	}
	return setmt(instance,grid)
end