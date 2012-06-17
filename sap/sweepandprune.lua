--[[
sweepandprune.lua v1.1

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
local tinsert = table.insert
local tremove = table.remove
local tsort = table.sort
local pairs = pairs
local assert = assert

local boolop = -- table to set pairing flag
{
	x = {	TRUE 	= {[0] = 1,[1] = 0,[10] = 11,[11]	= 11},
			XOR 	= {[0] = 1,[1] = 0,[10] = 11,[11]	= 10}
		},
	
	y = {	TRUE 	= {[0] = 10,[1] = 11,[10] = 10,[11] = 11},
			XOR 	= {[0] = 10,[1] = 11,[10] = 00,[11] = 01}
		},
}

boolop.xt = boolop.x.TRUE
boolop.xx = boolop.x.XOR
boolop.yt = boolop.y.TRUE
boolop.yx = boolop.y.XOR

local removeAllReferences = function (self,axis,endpoint) -- remove object from instance
	if axis == 'y' and endpoint.interval == 1 then
		local obj = endpoint.obj
		
		for otherObj,_ in pairs(self.objects[obj].pairflags) do
			self.objects[otherObj].pairflags[obj] = nil
			self.objects[otherObj].intersections[obj] = nil
		end
		
		self.objects[obj]		= nil
		self.deletebuffer[obj]  = nil
	end
end

local ifOrder = function (endpointA,endpointB) 
	return 	endpointA.point < endpointB.point or 
			endpointA.point == endpointB.point and 
			endpointA.interval < endpointB.interval
end

local setPair = function (self,obj1,obj2) -- set pair when swapping
	local flag = self.objects[obj1].pairflags[obj2]
	
	if flag == 11 then
		self.objects[obj1].intersections[obj2] = true
		self.objects[obj2].intersections[obj1] = true
	elseif flag ~= 0 then
		self.objects[obj1].intersections[obj2] = nil
		self.objects[obj2].intersections[obj1] = nil
	end
end

local setFlag = function (self,mode,obj1,obj2) -- set flag when swapping
	local bitT 		= boolop[mode]
	local oldflag	= self.objects[obj1].pairflags[obj2] or 0
	local newflag	= bitT[oldflag]
	
	self.objects[obj1].pairflags[obj2] = newflag
	self.objects[obj2].pairflags[obj1] = newflag
end

local processSets = function (self,mode,endpoint,setMaintain,...) -- set flag on insertion events
	local setsCollide = {...}
	local obj = endpoint.obj
	
	if endpoint.interval == 0 then
		setMaintain[obj] = obj
	else
		setMaintain[obj] = nil
		for _,set in ipairs(setsCollide) do
			for obj2,_ in pairs(set) do
				setFlag(self,mode,obj,obj2)
				setPair(self,obj,obj2)
			end
		end
	end
end

local SweepAndPrune = function (self,axis)
	local intervalT
	local bufferT
	local xormode
	local truemode
	local setInsert
	local setInterval
	
	if axis == 'x' then
		intervalT 	= self.xintervals
		bufferT 	= self.xbuffer
		xormode  	= 'xx'
		truemode 	= 'xt'
	else
		intervalT 	= self.yintervals
		bufferT 	= self.ybuffer
		xormode  	= 'yx'
		truemode 	= 'yt'
	end
	
	if bufferT[1] then
		setInsert		= {}
		setInterval 	= {}
	end
	
	local i = 1
	local j = 1

	while true do
		local endpoint = intervalT[i]
		local insertEP = bufferT[j]
		
		if endpoint and self.deletebuffer[endpoint.obj] then
			tremove(intervalT,i)
			removeAllReferences(self,axis,endpoint)
		elseif insertEP and self.deletebuffer[insertEP.obj] then
			tremove(bufferT,j)
			removeAllReferences(self,axis,insertEP)
		elseif insertEP and (not endpoint or ifOrder(insertEP,endpoint)) then				
			processSets(self,truemode,insertEP,setInsert,setInsert,setInterval)
			
			tinsert(intervalT,i,insertEP)				
			tremove(bufferT,j)
			
			i = i + 1
		elseif endpoint then			
			local obj1 = endpoint.obj
			
			if bufferT[1] then
				processSets(self,truemode,endpoint,setInterval,setInsert)
			end
				
			local k = i - 1
			while k > 0 and not ifOrder(intervalT[k],endpoint) do
				local endpoint2 = intervalT[k]
				local obj2 = intervalT[k].obj
			
				intervalT[k+1] = intervalT[k]
				k = k - 1
				
				if endpoint.interval == endpoint2.interval then
					setFlag(self,truemode,obj1,obj2)
				else
					setFlag(self,xormode,obj1,obj2)
				end
							
				setPair(self,obj1,obj2)
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

local move = function (self,obj,x0,y0,x1,y1)
	self.deletebuffer[obj]		= nil -- don't delete when moving
	self.objects[obj].x0t.point = x0
	self.objects[obj].y0t.point = y0
	self.objects[obj].x1t.point = x1
	self.objects[obj].y1t.point = y1
end

local add = function (self,obj,x0,y0,x1,y1)
	if not self.objects[obj] then
		local x0t = {point = x0,interval = 0,obj = obj}
		local y0t = {point = y0,interval = 0,obj = obj}
		local x1t = {point = x1,interval = 1,obj = obj}
		local y1t = {point = y1,interval = 1,obj = obj}

		self.objects[obj] = {
			x0t				= x0t,
			y0t				= y0t,
			x1t				= x1t,
			y1t 			= y1t,
			intersections	= {},
			pairflags		= {},
		}
		
		tinsert(self.xbuffer,x0t) -- batch insertion buffer
		tinsert(self.ybuffer,y0t)
		tinsert(self.xbuffer,x1t)
		tinsert(self.ybuffer,y1t)
	else -- update instead if object is already added
		move(self,obj,x0,y0,x1,y1)
	end
	return obj
end

local delete = function (self,obj)
	assert(self.objects[obj],'no such object exist!')
	self.deletebuffer[obj] = obj -- batch deletion buffer
end

local update = function (self)
	tsort(self.xbuffer,ifOrder)
	tsort(self.ybuffer,ifOrder)
		
	SweepAndPrune (self,'x')
	SweepAndPrune (self,'y')
end

local query = function (self,obj)
	local list = {}
	for obj2,_ in pairs(self.objects[obj].intersections) do
		list[obj2] = obj2
	end
	return list
end

local mt = {
	add		= add,
	delete	= delete,
	move	= move,
	update	= update,
	query	= query,
}	
mt.__index = mt

local SAP = function ()
	local instance = {
		xintervals 	= {},
		yintervals	= {},
		objects		= {},
		deletebuffer= {},
		xbuffer		= {},
		ybuffer 	= {},
	}
	return setmetatable(instance,mt)
end

return SAP