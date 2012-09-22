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

local insert 	= table.insert
local floor		= math.floor
local ceil		= math.ceil
local max			= function(a,b) return a > b and a or b end
local setmt   = setmetatable

local path    = (...):match('^.*[%.%/]') or ''
local sap     = require(path .. 'sweepandprune')

local weakValues = {__mode = 'v'}
local weakKeys   = {__mode = 'k'}

local DEFAULT_CELL_WIDTH  = 100
local DEFAULT_CELL_HEIGHT = 100

-- change behavior of adding boxes to each sap
local sap_add = function (self,objT)
	local obj = objT.x0t.obj
	self.deletebuffer[obj] = nil
	if not self.objects[obj] then
		self.paired[obj]  = {}
		-- setup proxy tables
		self.objects[obj] = objT
		insert(self.xbuffer,objT.x0t)
		insert(self.ybuffer,objT.y0t)
		insert(self.xbuffer,objT.x1t)
		insert(self.ybuffer,objT.y1t)
	end
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
	local cell_x0 = floor(x0/self.width)
	local cell_x1 = max(ceil(x1/self.width)-1,cell_x0)
	local cell_y0 = floor(y0/self.height)
	local cell_y1 = max(ceil(y1/self.height)-1,cell_y0)
	
	local columns = self.objects[obj].columns
	-- delete object from old cells
	for sap in pairs(columns) do 
		sap:delete(obj)
		-- remove sap reference for garbage collecting
		columns[sap]        = nil
		self.activeSAP[sap] = true
	end
	
	-- put object into new cells
	for x = cell_x0,cell_x1 do
		local column  = self.cells[x] or setmt({},weakValues)
		self.cells[x] = column
		for y = cell_y0,cell_y1 do
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
		for obj2 in sap.paired:iterate(obj) do
			list[obj2] = obj2
		end
	end
	return list
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