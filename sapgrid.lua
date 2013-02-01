--[[
sapgrid.lua v1.45b

Copyright (c) 2013 <Minh Ngo>

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
PRIVATE
===================
--]]

-- default settings
local DEFAULT_CELL_WIDTH  = 100
local DEFAULT_CELL_HEIGHT = 100
local MAX_POOL_SIZE       = 20

local insert  = table.insert
local floor   = math.floor
local ceil    = math.ceil
local max     = math.max
local setmt   = setmetatable
local huge    = math.huge
local wrap    = coroutine.wrap
local yield   = coroutine.yield

local path  = (...):match('^.*[%.%/]') or ''
local sap   = require(path .. 'sap')

local weakValues = {__mode = 'v'}
local pool       = {count = 0}

-- change behavior of adding boxes to each sap
local sap_add = function (sap,objT)
	local obj             = objT.x0t.obj
	sap.deletebuffer[obj] = nil
	if sap.objects[obj] then return end
	sap.paired[obj]  = {}
	-- setup proxy tables
	sap.objects[obj] = setmt({},objT)
	insert(sap.xbuffer,setmt({stabs = 0},objT.x0t))
	insert(sap.ybuffer,setmt({stabs = 0},objT.y0t))
	insert(sap.xbuffer,setmt({stabs = 0},objT.x1t))
	insert(sap.ybuffer,setmt({stabs = 0},objT.y1t))
end

-- reuse SAP instance
local toPool = function(sap)
	local count = pool.count
	if next(sap.objects) or count >= MAX_POOL_SIZE then return end
	pool[count+1] = sap
	pool.count    = count + 1
	sap.row[sap.x]= nil
end

-- pull from pool if available
local sap   = function(row,x)
	local count = pool.count
	local s     = pool[count]
	if s then 
		pool[count] = nil
		pool.count  = count - 1
		s.row,s.x   = row,x
		return s	
	end
	s         = sap()
	s.row,s.x = row,x
	return s
end  

local toGridCoordinates = function(grid,x0,y0,x1,y1)
	local gx0 = floor(x0/grid.width)
	local gy0 = floor(y0/grid.height)
	local gx1 = max(ceil(x1/grid.width)-1,gx0)
	local gy1 = max(ceil(y1/grid.height)-1,gy0)
	return gx0,gy0,gx1,gy1
end

local initRayData = function(cell_width,i,f)
	local d       = f-i
	local cell_i  = floor(i/cell_width)
	
	local dRatio,Delta,Step,Start
	if d > 0 then 
		Step   = 1 
		Start  = 1 
	else 
		Step   = -1 
		Start  = 0
	end
	-- zero hack
	if d == 0 then
		dRatio = huge
		Delta  = 0
	else
		local dNextVoxel = cell_width*(cell_i+Start)-i
		dRatio  = (dNextVoxel)/d
		Delta   = cell_width/d * Step
	end
	
	return dRatio,Delta,Step,cell_i
end

local rayCallback = function(self,x,y,x2,y2,isCoroutine)
	local dxRatio,xDelta,xStep,gx = initRayData(self.width,x,x2)
	local dyRatio,yDelta,yStep,gy = initRayData(self.height,y,y2)
	local set,cells = {},self.cells
	local smallest
	-- Use a repeat loop so that the ray checks its starting cell
	repeat
		local row = cells[gy]
		if row and row[gx] then
			for obj,x,y in row[gx]:iterRay(x,y,x2,y2) do
				if not set[obj] then 
					if isCoroutine then yield(obj,x,y) else return obj,x,y end
				end
				set[obj] = true
			end
		end
		
		if dxRatio < dyRatio then
			smallest  = dxRatio
			dxRatio   = dxRatio + xDelta
			gx        = gx + xStep
		else
			smallest  = dyRatio
			dyRatio   = dyRatio + yDelta
			gy        = gy + yStep
		end
	until smallest > 1
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
	
	local rows = self.objects[obj].rows
	-- delete object from old cells
	for sap in pairs(rows) do 
		sap:delete(obj)
		-- remove sap reference for garbage collecting
		rows[sap]           = nil
		self.activeSAP[sap] = true
	end
	
	-- put object into new cells
	for y = gy0,gy1 do
		local row     = self.cells[y] or setmt({},weakValues)
		self.cells[y] = row
		for x = gx0,gx1 do
			local sap = row[x] or sap(row,x)
			row[x]    = sap
			-- row/sap reference to prevent garbage collecting
			rows[sap] = row 
			sap_add(sap,self.objects[obj])
			self.activeSAP[sap] = true
		end
	end	
end

-- adding cancels deletion
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
			rows    = {},
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
end

g.update = function (self)
	for obj in pairs(self.deletebuffer) do
		for sap in pairs(self.objects[obj].rows) do
			sap:delete(obj)
			self.activeSAP[sap] = true
		end
		self.objects[obj]       = nil
		self.deletebuffer[obj]  = nil
	end
	-- only update active cells
	-- A cell is active when there is an add,delete, or move operation called for each sap
	for sap in pairs(self.activeSAP) do
		sap:update()
		toPool(sap)
		self.activeSAP[sap] = nil
	end
end

g.query = function (self,obj)
	local list = {}
	-- get pairs reported in each sap
	for sap in pairs(self.objects[obj].rows) do
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
	for y = gy0,gy1 do
	
		local row = self.cells[y]
		for x = gx0,gx1 do
		
			if row and row[x] then
				-- for each sap in each cell...
				for obj2 in pairs(row[x]:areaQuery(x0,y0,x1,y1,mode)) do
					list[obj2] = obj2
				end
			end
			
		end
		
	end
	return list
end

g.pointQuery = function(self,x,y)
	local gx    = floor(x/self.width)
	local gy    = floor(y/self.height)
	local row   = self.cells[gy]
	return row and row[gx] and row[gx]:pointQuery(x,y) or {}
end

g.rayQuery = function(self,x,y,x2,y2)
	return rayCallback(self,x,y,x2,y2)
end

-- DDA algorithm through the grid
g.iterRay = function(self,x,y,x2,y2)
	return wrap(function() rayCallback(self,x,y,x2,y2,true) end)
end

-- draw grid lines in LOVE
g.draw = function(self)
	local w,h = self.width,self.height
	local f   = love.graphics.getFont()
	local fh  = f and f:getHeight() or 14
	for y,t in pairs(self.cells) do
		for x,sap in pairs(t) do
			local rx,ry = x*self.width,y*self.height
			love.graphics.rectangle('line',rx,ry,w,h)
			love.graphics.print(x .. ',' .. y,rx,ry)
			love.graphics.print(#sap.xintervals/2,rx,ry+self.height-fh)
		end
	end
end

g.clearPool = function()
	pool = {count = 0}
end

g.new = function(cell_width,cell_height)
	return setmetatable({
		width         = cell_width or DEFAULT_CELL_WIDTH,
		height        = cell_height or DEFAULT_CELL_HEIGHT,
		cells         = setmt({},weakValues),
		objects       = {},
		deletebuffer  = {},
		activeSAP     = {},
	},g)
end

return setmt(g,{__call = function(g,...) return g.new(...) end})