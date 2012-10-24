--[[
sapgrid.lua v1.41

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

--[[
===================
INITIAL STUFF
===================
--]]

local insert  = table.insert
local floor   = math.floor
local ceil    = math.ceil
local max     = function(a,b) return a > b and a or b end
local setmt   = setmetatable

local path    = (...):match('^.*[%.%/]') or ''
local sap     = require(path .. 'sweepandprune')

local weakValues = {__mode = 'v'}
local weakKeys   = {__mode = 'k'}

local DEFAULT_CELL_WIDTH  = 100
local DEFAULT_CELL_HEIGHT = 100

-- change behavior of adding boxes to each sap
local sap_add = function (self,objT)
	local obj               = objT.x0t.obj
	self.deletebuffer[obj]  = nil
	if not self.objects[obj] then
		self.paired[obj]  = {}
		-- setup proxy tables
		self.objects[obj] = setmt({},objT)
		insert(self.xbuffer,setmt({stabs = 0},objT.x0t))
		insert(self.ybuffer,setmt({stabs = 0},objT.y0t))
		insert(self.xbuffer,setmt({stabs = 0},objT.x1t))
		insert(self.ybuffer,setmt({stabs = 0},objT.y1t))
	end
end

local toGridCoordinates = function(self,x0,y0,x1,y1)
	local gx0 = floor(x0/self.width)
	local gy0 = floor(y0/self.height)
	local gx1 = max(ceil(x1/self.width)-1,gx0)
	local gy1 = max(ceil(y1/self.height)-1,gy0)
	return gx0,gy0,gx1,gy1
end

--[[
===================
PUBLIC
===================
--]]
local g   = {}
g.__index = g

g.move = function (self,obj,x0,y0,x1,y1)
	self.objects[obj].x0t.value = x0
	self.objects[obj].y0t.value = y0
	self.objects[obj].x1t.value = x1
	self.objects[obj].y1t.value = y1
	-- rasterize to grid coordinates
	local gx0,gy0,gx1,gy1 = toGridCoordinates(self,x0,y0,x1,y1)
	
	local columns = self.objects[obj].columns
	-- delete object from old cells
	for sap in pairs(columns) do 
		sap:delete(obj)
		-- remove sap reference for garbage collecting
		columns[sap]        = nil
		self.activeSAP[sap] = true
	end
	
	-- put object into new cells
	for x = gx0,gx1 do
		local column  = self.cells[x] or setmt({},weakValues)
		self.cells[x] = column
		for y = gy0,gy1 do
			local sap = column[y] or sap()
			column[y] = sap
			-- column/sap reference to prevent garbage collecting
			columns[sap]  = column 
			sap_add(sap,self.objects[obj])
			self.activeSAP[sap] = true
		end
	end	
end

g.add = function (self,obj,x0,y0,x1,y1)	
	self.deletebuffer[obj] = nil
	if not self.objects[obj] then
		local x0t   = {value = x0,interval = 0,obj = obj}
		local y0t   = {value = y0,interval = 0,obj = obj}
		local x1t   = {value = x1,interval = 1,obj = obj}
		local y1t   = {value = y1,interval = 1,obj = obj}
		
		local objT = {
			x0t     = x0t,
			y0t     = y0t,
			x1t     = x1t,
			y1t     = y1t,
			columns = {},
		}
		self.objects[obj] = objT
		
		-- for sap's proxy tables
		x0t.__index   = x0t
		y0t.__index   = y0t
		x1t.__index   = x1t
		y1t.__index   = y1t
		objT.__index  = objT
		
	end
	self:move(obj,x0,y0,x1,y1)
	return obj
end

g.delete = function (self,obj)
	self.deletebuffer[obj] = obj
	
	for sap in pairs(self.objects[obj].columns) do
		sap:delete(obj)
		self.activeSAP[sap] = true
	end
end

g.update = function (self)
	-- only update active cells
	-- A cell is active when there is an add,delete, or move operation called for each sap
	for sap in pairs(self.activeSAP) do
		sap:update()
		self.activeSAP[sap] = nil
	end
	for obj in pairs(self.deletebuffer) do
		self.objects[obj]       = nil
		self.deletebuffer[obj]  = nil
	end
end

g.query = function (self,obj)
	local list = {}
	-- get pairs reported in each sap
	for sap in pairs(self.objects[obj].columns) do
		for obj2 in pairs(sap.paired[obj]) do
			list[obj2] = obj2
		end
	end
	return list
end

g.areaQuery = function(self,x0,y0,x1,y1,mode)
	local list            = {}
	local gx0,gy0,gx1,gy1 = toGridCoordinates(self,x0,y0,x1,y1)
	-- for each cell the area touches...
	for x = gx0,gx1 do
	
		local column = self.cells[x]
		for y = gy0,gy1 do
		
			if column and column[y] then
				-- for each sap in each cell...
				for obj2 in pairs(column[y]:areaQuery(x0,y0,x1,y1,mode)) do
					list[obj2] = obj2
				end
			end
			
		end
		
	end
	return list
end

g.pointQuery = function(self,x,y)
	local gx0    = floor(x/self.width)
	local gy0    = floor(y/self.height)
	if self.cells[gx0] and self.cells[gx0][gy0] then
		return self.cells[gx0][gy0]:pointQuery(x,y)
	end
end

-- DDA algorithm
g.rayQuery = function(self,x,y,x2,y2,isCoroutine)
	local dx,dy   = x2-x,y2-y
	local set     = {}
	local gx0,gy0 = floor(x/self.width),floor(y/self.height)
	
	local dxRatio,dyRatio,xDelta,yDelta,xStep,yStep,smallest,xStart,yStart
	if dx > 0 then 
		xStep   = 1 
		xStart  = 1 
	else 
		xStep   = -1 
		xStart  = 0
	end
	if dy > 0 then 
		yStep   = 1 
		yStart  = 1
	else 
		yStep   = -1 
		yStart  = 0
	end
	
	-- dx and dy zero hack
	if dx == 0 then
		dxRatio = math.huge
		xDelta  = 0
	else
		local a,b = self.width/dx,x/dx
		dxRatio   = a*(gx0+xStart)-b
		xDelta    = a*xStep
	end
	if dy == 0 then
		dyRatio = math.huge
		yDelta  = 0
	else
		local a,b = self.height/dy,y/dy
		dyRatio   = a*(gy0+yStart)-b
		yDelta    = a*yStep
	end
	
	-- Use a repeat loop so that the ray checks its starting cell
	repeat
		local column = self.cells[gx0]
		if column and column[gy0] then
			-- if called as an iterator, iterate through all objects that overlaps the ray
			-- otherwise, just look for the earliest hit and return
			if isCoroutine then
				for obj,hitx,hity in column[gy0]:iterRay(x,y,x2,y2) do
						if not set[obj] then coroutine.yield(obj,hitx,hity); set[obj]=true end
				end
			else
				local obj,hitx,hity = column[gy0]:rayQuery(x,y,x2,y2)
				if obj then return obj,hitx,hity end
			end
		end
		
		if dxRatio < dyRatio then
			smallest  = dxRatio
			dxRatio   = dxRatio + xDelta
			gx0        = gx0 + xStep
		else
			smallest  = dyRatio
			dyRatio   = dyRatio + yDelta
			gy0        = gy0 + yStep
		end
	until smallest > 1
end

g.iterRay = function(self,x,y,x2,y2)
	return coroutine.wrap(function()
		g.rayQuery(self,x,y,x2,y2,true)
	end)
end

g.draw = function(self)
	for x,t in pairs(self.cells) do
		for y,sap in pairs(t) do
			love.graphics.rectangle('line',x*self.width,y*self.height,self.width,self.height)
			love.graphics.print(x .. ',' .. y,x*self.width,y*self.height)
			love.graphics.print(#sap.xintervals/2,x*self.width,y*self.height+self.height-15)
		end
	end
end

g.new = function(self,cell_width,cell_height)
	return setmetatable({
		width         = cell_width or DEFAULT_CELL_WIDTH,
		height        = cell_height or DEFAULT_CELL_HEIGHT,
		cells         = setmt({},weakValues),
		objects       = {},
		deletebuffer  = {},
		activeSAP     = setmetatable({},weakKeys),
	},g)
end

return setmetatable(g,{__call = g.new})