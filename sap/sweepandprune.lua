--[[
sweepandprune.lua v1.3

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
local insert = table.insert
local remove = table.remove
local sort = table.sort
local pairs = pairs

local isOverlapping = function (self,obj1,obj2) -- bounding box overlap test
	local ax1 = self.objects[obj1].x0t.value
	local ay1 = self.objects[obj1].y0t.value
	local ax2 = self.objects[obj1].x1t.value
	local ay2 = self.objects[obj1].y1t.value
	
	local bx1 = self.objects[obj2].x0t.value
	local by1 = self.objects[obj2].y0t.value
	local bx2 = self.objects[obj2].x1t.value
	local by2 = self.objects[obj2].y1t.value

	return ax1 <= bx2 and ax2 >= bx1 and ay1 <= by2 and ay2 >= by1
end

local isSorted = function (endpointA,endpointB) -- comparison function
	return 	endpointA.value < endpointB.value or 
			endpointA.value == endpointB.value and 
			endpointA.interval < endpointB.interval
end

local setPair = function (self,obj1,obj2) -- set pair when swapping
	if isOverlapping(self,obj1,obj2) then
		self.objects[obj1].intersections[obj2] = obj2
		self.objects[obj2].intersections[obj1] = obj1
	end
end

local processSets = function (self,axis,endpoint,setMaintain,...) -- test object in setMaintain vs objects in setCollide
	if axis == 'y' then
		local setsCollide = {...}
		local obj1 = endpoint.obj
		
		if endpoint.interval == 0 then
			setMaintain[obj1] = obj1
		else
			setMaintain[obj1] = nil
			for _,set in ipairs(setsCollide) do
				for obj2,_ in pairs(set) do
					setPair(self,obj1,obj2)
				end
			end
		end
	end
end

local SweepAndPrune = function (self,axis)
	local intervalT
	local bufferT
	local setInsert
	local setInterval
	
	if axis == 'x' then
		intervalT 	= self.xintervals
		bufferT 	= self.xbuffer
	else
		intervalT 	= self.yintervals
		bufferT 	= self.ybuffer
	end
	
	if bufferT[1] then
		setInsert		= {}
		setInterval 	= {}
	end
	
	local i = 1
	local j = 1

	while true do
		local endpoint		= intervalT[i]
		local newEndpoint	= bufferT[j]
		
		if endpoint and self.deletebuffer[endpoint.obj] then
			remove(intervalT,i)
		elseif newEndpoint and self.deletebuffer[newEndpoint.obj] then
			remove(bufferT,j)
		elseif newEndpoint and (not endpoint or isSorted(newEndpoint,endpoint)) then
			processSets(self,axis,newEndpoint,setInsert,setInsert,setInterval)
			
			insert(intervalT,i,newEndpoint)				
			remove(bufferT,j)
			
			i = i + 1
		elseif endpoint then			
			if bufferT[1] then
				processSets(self,axis,endpoint,setInterval,setInsert)
			end
				
			local k = i - 1
			while k > 0 and not isSorted(intervalT[k],endpoint) do -- swap if not in order
				local endpoint2	= intervalT[k] -- ep2 > ep
				intervalT[k+1]	= endpoint2
				
				if endpoint.interval == 0 and endpoint2.interval == 1 then -- [0 ep2 1] [0 ep1 1] // boxes art ^_^
					setPair(self,endpoint.obj,endpoint2.obj)
				elseif endpoint.interval == 1 and endpoint2.interval == 0 then
					self.objects[endpoint.obj].intersections[endpoint2.obj] = nil
					self.objects[endpoint2.obj].intersections[endpoint.obj] = nil
				end
				
				k = k - 1
			end
			intervalT[k+1] = endpoint
			i = i + 1
		else
			break
		end
	end
end
-------------------
-- public interface
local s = {}
s.__index = s

s.move = function (self,obj,x0,y0,x1,y1)
	self.deletebuffer[obj]		= nil -- don't delete when moving
	self.objects[obj].x0t.value = x0
	self.objects[obj].y0t.value = y0
	self.objects[obj].x1t.value = x1
	self.objects[obj].y1t.value = y1
end

s.add = function (self,obj,x0,y0,x1,y1)
	if not self.objects[obj] then
		local x0t = {value = nil,interval = 0,obj = obj}
		local y0t = {value = nil,interval = 0,obj = obj}
		local x1t = {value = nil,interval = 1,obj = obj}
		local y1t = {value = nil,interval = 1,obj = obj}

		self.objects[obj] = {
			x0t				= x0t,
			y0t				= y0t,
			x1t				= x1t,
			y1t 			= y1t,
			intersections	= {},
		}
		
		insert(self.xbuffer,x0t) -- batch insertion buffer
		insert(self.ybuffer,y0t)
		insert(self.xbuffer,x1t)
		insert(self.ybuffer,y1t)
	end
	self.move(self,obj,x0,y0,x1,y1)
	return obj
end

s.delete = function (self,obj)
	assert(self.objects[obj],'no such object exist!')
	self.deletebuffer[obj] = obj -- batch deletion buffer
end

s._removeCallback = function (self) -- remove object from instance
	for obj in pairs(self.deletebuffer) do
		for otherObj,_ in pairs(self.objects[obj].intersections) do
			self.objects[otherObj].intersections[obj] = nil
		end
		self.objects[obj]		= nil
		self.deletebuffer[obj]  = nil
	end
end

s.update = function (self)
	sort(self.xbuffer,isSorted)
	sort(self.ybuffer,isSorted)
	SweepAndPrune (self,'x')
	SweepAndPrune (self,'y')
	self._removeCallback(self)
end

s.query = function (self,obj)
	local list = {}
	for obj2,_ in pairs(self.objects[obj].intersections) do
		list[obj2] = obj2
	end
	return list
end

s.queryIter = function(self,obj)
	return pairs(self:query(obj))
end

return function ()
	local instance = {
		xintervals 	= {},
		yintervals	= {},
		objects		= {},
		deletebuffer= {},
		xbuffer		= {},
		ybuffer 	= {},
	}
	return setmetatable(instance,s)
end