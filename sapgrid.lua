--[[
sapgrid.lua v1.42b

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
PRIVATE
===================
--]]

local insert  = table.insert
local floor   = math.floor
local ceil    = math.ceil
local max     = function(a,b) return a > b and a or b end
local setmt   = setmetatable

local huge      = math.huge
local setfenv   = setfenv
local yield     = coroutine.yield
local wrap      = coroutine.wrap

local path  = (...):match('^.*[%.%/]') or ''
local sap   = require(path .. 'sweepandprune')

local weakValues = {__mode = 'v'}

local DEFAULT_CELL_WIDTH  = 100
local DEFAULT_CELL_HEIGHT = 100
local MAX_POOL_SIZE       = 10

-- change behavior of adding boxes to each sap
local sap_add = function (sap,objT)
	local obj               = objT.x0t.obj
	sap.deletebuffer[obj]  = nil
	if not sap.objects[obj] then
		sap.paired[obj]  = {}
		-- setup proxy tables
		sap.objects[obj] = setmt({},objT)
		insert(sap.xbuffer,setmt({stabs = 0},objT.x0t))
		insert(sap.ybuffer,setmt({stabs = 0},objT.y0t))
		insert(sap.xbuffer,setmt({stabs = 0},objT.x1t))
		insert(sap.ybuffer,setmt({stabs = 0},objT.y1t))
	end
end

-- reuse SAP instance
local toSAPpool = function(grid,sap)
	local pool = grid.SAPpool
	if not next(sap.objects) and pool.count < MAX_POOL_SIZE then
		pool[ pool.count+1 ] = sap
		pool.count    = pool.count + 1
		sap.parent[1][ sap.parent[2] ] = nil
		sap.parent[1] = nil
		sap.parent[2] = nil
	end
end

local getSpareSAP = function(pool,yt,keyToSap)
	local s = pool[ pool.count ]
	if s then
		pool[ pool.count ] = nil
		pool.count    = pool.count - 1
		s.parent[1]   = yt
		s.parent[2]   = keyToSap
		return s
	end
end

local sap   = function(grid,yt,k)
	local s   = getSpareSAP(grid.SAPpool,yt,k) or sap()
	s.parent  = not s.parent and {yt,k} or s.parent
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
			local sap = row[x] or sap(self,row,x)
			row[x]    = sap
			-- row/sap reference to prevent garbage collecting
			rows[sap] = row 
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
	for sap in pairs(self.objects[obj].rows) do
		sap:delete(obj)
		self.activeSAP[sap] = true
	end
end

g.update = function (self)
	-- only update active cells
	-- A cell is active when there is an add,delete, or move operation called for each sap
	for sap in pairs(self.activeSAP) do
		sap:update()
		toSAPpool(self,sap)
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
	if self.cells[gy] and self.cells[gy][gx] then
		return self.cells[gy][gx]:pointQuery(x,y)
	end
end

g.rayQuery = function(self,x,y,x2,y2)
	return self:iterRay(x,y,x2,y2)()
end

g.iterRay = function(self,x,y,x2,y2)
	return wrap(function()
		local dxRatio,xDelta,xStep,gx = initRayData(self.width,x,x2)
		local dyRatio,yDelta,yStep,gy = initRayData(self.height,y,y2)
		local set,cells = {},self.cells
		local smallest
		-- Use a repeat loop so that the ray checks its starting cell
		repeat
			local row = cells[gy]
			if row and row[gx] then
				for obj,x,y in row[gx]:iterRay(x,y,x2,y2) do
					if not set[obj] then yield(obj,x,y) end
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
	end)
end

g.draw = function(self)
	for y,t in pairs(self.cells) do
		for x,sap in pairs(t) do
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
		activeSAP     = {},
		SAPpool       = {count = 0},
	},g)
end

return setmetatable(g,{__call = g.new})