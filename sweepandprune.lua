--[[
sweepandprune.lua

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
local insert  = table.insert
local remove  = table.remove
local sort    = table.sort
local pairs   = pairs
local min     = function(a,b) return a < b and a or b end
--[[
===================
PRIVATE
===================
--]]

-- comparison function for insertion sort
local isSorted = function (endpointA,endpointB)
	return endpointA.value < endpointB.value or 
	endpointA.value == endpointB.value and 
	endpointA.interval < endpointB.interval
end

-- check for overlapping pairs when swapping endpoints
local setPair = function (sap,obj1,obj2)
	local ax1 = sap.objects[obj1].x0t.value
	local ay1 = sap.objects[obj1].y0t.value
	local ax2 = sap.objects[obj1].x1t.value
	local ay2 = sap.objects[obj1].y1t.value
	
	local bx1 = sap.objects[obj2].x0t.value
	local by1 = sap.objects[obj2].y0t.value
	local bx2 = sap.objects[obj2].x1t.value
	local by2 = sap.objects[obj2].y1t.value

	if ax1 <= bx2 and ax2 >= bx1 and ay1 <= by2 and ay2 >= by1 then
		sap.paired[obj1][obj2] = obj2
		sap.paired[obj2][obj1] = obj1
	end
end

-- insertion sort collects objects into setMaintain
-- if endpoint is an upperbound, then remove object from setMaintain 
-- and check its with objects in setsCollide
local processSets = function (sap,endpoint,setMaintain,setsCollide)
	local obj1 = endpoint.obj
	
	if endpoint.interval == 0 then
		setMaintain[obj1] = obj1
	else
		setMaintain[obj1] = nil
		for _,set in ipairs(setsCollide) do
			for obj2 in pairs(set) do
				setPair(sap,obj1,obj2)
			end
		end
	end
end

local swapCallback = function(sap,endpoint2,endpoint)
	-- [0 ep2 1] [0 ep1 1] pre swap
	local obj1,obj2 = endpoint.obj,endpoint2.obj
	if endpoint.interval == 0 and endpoint2.interval == 1 then 
		setPair(sap,obj1,obj2)
		
	-- [0 ep2 [0  1] ep1 1] pre swap
	elseif endpoint.interval == 1 and endpoint2.interval == 0 then
		sap.paired[obj1][obj2] = nil
		sap.paired[obj2][obj1] = nil		
	end
end

local insertSort = function(sap,list,i)
	local k = i - 1
	local v = list[i]
	while k > 0 and isSorted(v,list[k]) do
		swapCallback(sap,list[k],v)
		list[k+1] = list[k]
		k         = k - 1
	end
	list[k+1] = v
end

-- sap loop
local SweepAndPrune = function (sap,axis,intervalT,bufferT,deletebuffer)
	local setInsert,setInterval
	
	if bufferT[1] then setInsert = {}; setInterval = {} end
	
	local i = 1
	while intervalT[i] do
		local endpoint    = intervalT[i]
		local newEndpoint = bufferT[1]
		
		-- prioritize deletion and insertion events first
		if deletebuffer[endpoint.obj] then
			remove(intervalT,i)
		elseif newEndpoint and deletebuffer[newEndpoint.obj] then
			remove(bufferT,1)
		elseif newEndpoint and isSorted(newEndpoint,endpoint) then
			if axis == 'y' then
				processSets(sap,newEndpoint,setInsert,{setInsert,setInterval})
			end
			
			insert(intervalT,i,newEndpoint)
			remove(bufferT,1)
			
			i = i + 1
		
		else
			-- insertion sort block
		
			if bufferT[1] and axis == 'y' then
				processSets(sap,endpoint,setInterval,{setInsert})
			end
				
			insertSort(sap,intervalT,i)
			i = i + 1
		end
	end
	-- insert the rest of the new endpoints
	while bufferT[1] do
		local newEndpoint = bufferT[1]
		if newEndpoint and deletebuffer[newEndpoint.obj] then
			remove(bufferT,1)
		else
			if axis == 'y' then
				processSets(sap,newEndpoint,setInsert,{setInsert})
			end
			
			insert(intervalT,i,newEndpoint)
			remove(bufferT,1)
			
			i = i + 1
		end
	end
end

--[[
===================
PUBLIC
===================
--]]
local s   = {}
s.__index = s

s.move = function (self,obj,x0,y0,x1,y1)
	self.objects[obj].x0t.value = x0
	self.objects[obj].y0t.value = y0
	self.objects[obj].x1t.value = x1
	self.objects[obj].y1t.value = y1
end

s.add = function (self,obj,x0,y0,x1,y1)
	self.deletebuffer[obj] = nil
	if not self.objects[obj] then
		local x0t = {value = x0,interval = 0,obj = obj}
		local y0t = {value = y0,interval = 0,obj = obj}
		local x1t = {value = x1,interval = 1,obj = obj}
		local y1t = {value = y1,interval = 1,obj = obj}
		
		self.objects[obj] = {
			x0t     = x0t,
			y0t     = y0t,
			x1t     = x1t,
			y1t     = y1t,
		}
		
		self.paired[obj] = {}
		
		insert(self.xbuffer,x0t) -- batch insertion buffer
		insert(self.ybuffer,y0t)
		insert(self.xbuffer,x1t)
		insert(self.ybuffer,y1t)
	else
		self:move(obj,x0,y0,x1,y1)
	end
	return obj
end

s.delete = function (self,obj)
	self.deletebuffer[obj] = obj 
end

s._delCallback = function(self)
	for obj in pairs(self.deletebuffer) do
		for obj2 in pairs(self.paired[obj]) do
			self.paired[obj2][obj] = nil
		end
		self.paired[obj]        = nil
		self.objects[obj]       = nil
		self.deletebuffer[obj]  = nil
	end	
end

s.update = function (self)
	sort(self.xbuffer,isSorted)
	sort(self.ybuffer,isSorted)
	SweepAndPrune (self,'x',self.xintervals,self.xbuffer,self.deletebuffer)
	SweepAndPrune (self,'y',self.yintervals,self.ybuffer,self.deletebuffer)
	self:_delCallback()
end

s.query = function (self,obj)
	local t = {}
	for obj2 in pairs(self.paired[obj]) do
		t[obj2]=obj2
	end
	return t
end

s.new = function()
	return setmetatable({
			xintervals   = {},
			yintervals   = {},
			objects      = {},
			deletebuffer = {},
			xbuffer      = {},
			ybuffer      = {},
			paired       = {},
		},s)
end

return setmetatable(s,{__call = s.new})