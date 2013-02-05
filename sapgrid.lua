--[[
sapgrid.lua

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
INITIAL STUFF
===================
--]]

local insert  = table.insert
local floor   = math.floor
local ceil    = math.ceil
local max     = math.max
local setmt   = setmetatable

local path    = (...):match('^.*[%.%/]') or ''
local sap     = require(path .. 'sap')

local weakValues = {__mode = 'v'}
local weakKeys   = {__mode = 'k'}

local DEFAULT_CELL_WIDTH  = 100
local DEFAULT_CELL_HEIGHT = 100

local sap_add = function (self,objT)
	local obj = objT.x0t.obj
	self.deletebuffer[obj] = nil
	if not self.objects[obj] then
		self.paired[obj]  = {}
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
	local cell_x0 = floor(x0/self.width)
	local cell_x1 = ceil(x1/self.width)-1
	local cell_y0 = floor(y0/self.height)
	local cell_y1 = ceil(y1/self.height)-1
	
	local rows = self.objects[obj].rows
	for sap in pairs(rows) do 
		sap:delete(obj)
		rows[sap]           = nil
		self.activeSAP[sap] = true
	end
	
	for y = cell_y0,cell_y1 do
		local row     = self.cells[y] or setmt({},weakValues)
		self.cells[y] = row
		for x = cell_x0,cell_x1 do
			local sap = row[x] or sap()
			row[x]    = sap
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
	for sap in pairs(self.activeSAP) do
		sap:update()
		self.activeSAP[sap] = nil
	end
end

g.query = function (self,obj)
	local list = {}
	for sap in pairs(self.objects[obj].rows) do
		for obj2 in pairs(sap.paired[obj]) do
			list[obj2] = obj2
		end
	end
	return list
end

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