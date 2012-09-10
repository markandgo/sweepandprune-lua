--[[
sweepandprune.lua v1.4e

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
local min     = math.min
local select  = select
local unpack  = unpack

--[[
for interval a [a1 a2] and b [b1 b2]:
overlap when
b1 <= a1 <= b2 and b1 <= a2 or a1 <= b1 <= a2 and a1 <= b2
--]]
local isOverlapping = function (ax1,ay1,ax2,ay2,bx1,by1,bx2,by2)
	return ax1 <= bx2 and ax2 >= bx1 and ay1 <= by2 and ay2 >= by1
end

-- comparison function for insertion sort
local isSorted = function (endpointA,endpointB)
	return endpointA.value < endpointB.value or 
	endpointA.value == endpointB.value and 
	endpointA.interval < endpointB.interval
end

-- check and set intersection pair when swapping endpoints
local setPair = function (self,obj1,obj2)
	local ax1 = self.objects[obj1].x0t.value
	local ay1 = self.objects[obj1].y0t.value
	local ax2 = self.objects[obj1].x1t.value
	local ay2 = self.objects[obj1].y1t.value
	
	local bx1 = self.objects[obj2].x0t.value
	local by1 = self.objects[obj2].y0t.value
	local bx2 = self.objects[obj2].x1t.value
	local by2 = self.objects[obj2].y1t.value

	if isOverlapping(ax1,ay1,ax2,ay2,bx1,by1,bx2,by2) then
		self.objects[obj1].intersections[obj2] = obj2
		self.objects[obj2].intersections[obj1] = obj1
	end
end

-- forward insertion sort collects objects into setMaintain
-- if endpoint is an upperbound, then remove object from setMaintain and check if it intersects with setCollide
-- check on the last axis only
local processSets = function (self,axis,endpoint,setMaintain,...)
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

-- stab number = number of intervals to the left of index i that contains the value at i
-- stab number = number of lower bound endpoints - number of upper bound endpoints to the left of i
local setStabs = function(list,i) 
	if list[i-1] then
		local leftstab = list[i-1].stabs
		if list[i-1].interval == 1 then
			list[i].stabs = leftstab - 1
		else
			list[i].stabs = leftstab + 1
		end
	else
		list[i].stabs = 0
	end
end

-- insertion sort loop
local SweepAndPrune = function (self,axis)
	local intervalT
	local bufferT
	local setInsert
	local setInterval
	
	if axis == 'x' then
		intervalT = self.xintervals
		bufferT   = self.xbuffer
	else
		intervalT = self.yintervals
		bufferT   = self.ybuffer
	end
	
	if bufferT[1] then
		setInsert   = {}
		setInterval = {}
	end
	
	local checkStab = setInsert or next(self.deletebuffer)
	
	local i = 1
	local j = 1

	-- update stabbing number when there are insertion,deletion, and swap events
	while true do
		local endpoint    = intervalT[i]
		local newEndpoint = bufferT[j]
		
		-- prioritize deletion and insertion events first
		if endpoint and self.deletebuffer[endpoint.obj] then
			remove(intervalT,i)
		elseif newEndpoint and self.deletebuffer[newEndpoint.obj] then
			remove(bufferT,j)
		elseif newEndpoint and (not endpoint or isSorted(newEndpoint,endpoint)) then
			processSets(self,axis,newEndpoint,setInsert,setInsert,setInterval)
			
			insert(intervalT,i,newEndpoint)
			setStabs(intervalT,i)
			remove(bufferT,j)
			
			i = i + 1
		
		-- insertion sort block
		elseif endpoint then
			if checkStab then setStabs(intervalT,i) end
		
			if bufferT[1] then
				processSets(self,axis,endpoint,setInterval,setInsert)
			end
				
			local k = i - 1
			while k > 0 and not isSorted(intervalT[k],endpoint) do
				
				-- ep2 ---> ep
				local endpoint2 = intervalT[k]
				intervalT[k+1]  = endpoint2
				
				-- [0 ep2 1] [0 ep1 1] pre swap
				if endpoint.interval == 0 and endpoint2.interval == 1 then 
					setPair(self,endpoint.obj,endpoint2.obj)
					
					endpoint2.stabs = endpoint2.stabs + 1
					endpoint.stabs = endpoint.stabs + 1
					
				-- [0 ep2 [0  1] ep1 1] pre swap
				elseif endpoint.interval == 1 and endpoint2.interval == 0 then
					self.objects[endpoint.obj].intersections[endpoint2.obj] = nil
					self.objects[endpoint2.obj].intersections[endpoint.obj] = nil
					
					endpoint2.stabs = endpoint2.stabs - 1
					endpoint.stabs = endpoint.stabs - 1
				else
					endpoint2.stabs,endpoint.stabs = endpoint.stabs,endpoint2.stabs
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

-- cache k for next lookup
local s = {}
s.__index = function(t,k)
	t[k] = s[k]
	return s[k]
end

s.move = function (self,obj,x0,y0,x1,y1)
	self.objects[obj].x0t.value = x0
	self.objects[obj].y0t.value = y0
	self.objects[obj].x1t.value = x1
	self.objects[obj].y1t.value = y1
end

s.add = function (self,obj,x0,y0,x1,y1)
	self.deletebuffer[obj] = nil
	if not self.objects[obj] then
		local x0t = {value = nil,interval = 0,obj = obj,stabs = 0}
		local y0t = {value = nil,interval = 0,obj = obj,stabs = 0}
		local x1t = {value = nil,interval = 1,obj = obj,stabs = 0}
		local y1t = {value = nil,interval = 1,obj = obj,stabs = 0}

		self.objects[obj] = {
			x0t           = x0t,
			y0t           = y0t,
			x1t           = x1t,
			y1t           = y1t,
			intersections = {},
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
	self.deletebuffer[obj] = obj 
end

s._removeCallback = function (self)
	for obj in pairs(self.deletebuffer) do
		for otherObj,_ in pairs(self.objects[obj].intersections) do
			self.objects[otherObj].intersections[obj] = nil
		end
		self.objects[obj]       = nil
		self.deletebuffer[obj]  = nil
	end
end

s.update = function (self)
	sort(self.xbuffer,isSorted)
	sort(self.ybuffer,isSorted)
	SweepAndPrune (self,'x')
	SweepAndPrune (self,'y')
	self:_removeCallback()
end

s.query = function (self,obj)
	local list = {}
	for obj2,_ in pairs(self.objects[obj].intersections) do
		list[obj2] = obj2
	end
	return list
end

-- ===============
-- ADVANCE QUERIES
-- ===============

-- http://lua-users.org/wiki/BinarySearch
-- return left index and right index of v where li < v < ri
local default_fcompval = function( e ) return e and e.value end
local fcomp = function( a,b ) return a < b end
local binsearch = function( t,value,fcompval )
	-- Initialise functions
	local fcompval = fcompval or default_fcompval
	--  Initialise numbers
	local iStart,iEnd,iMid 	= 1,#t,0
	-- assume 0 = -inf,#t+1 = inf
	local start,last = 0,#t+1
	-- Binary Search
	while iStart <= iEnd do
		-- calculate middle
		iMid = math.floor( (iStart+iEnd)/2 )
		-- get compare value
		local value2 = fcompval( t[iMid] )
		-- get all values that match
		if value == value2 then
			start,last = iMid,iMid
			local num = iMid - 1
			while value == fcompval( t[num] ) do
				start		= num
				num 		= num - 1
			end
			num = iMid + 1
			while value == fcompval( t[num] ) do
				last	= num
				num 	= num + 1
			end
			return start-1,last+1
		-- keep searching
		elseif fcomp( value,value2 ) then
			last = iMid
			iEnd = iMid - 1
		else
			start	 = iMid
			iStart = iMid + 1
		end
	end
	return start,last
end

-- to reuse coroutines
local coReuse = coroutine.wrap(function(t) -- for iterators
	while true do
		t =  coroutine.yield(t[1]( select( 2,unpack(t) ) ) ) 
	end
end)

-- iterate backward in the list until stabbing number = 0, return stabbed endpoint's object
local iterStabs = function(t,i)
	local unset = {}
	local stabs = t[i] and t[i].stabs or 0
	-- iterate backward and return stabbed endpoints
	while stabs > 0 do
		i = i - 1
		local ep,obj = t[i],t[i].obj
		if ep.interval == 0 and not unset[obj] then 
			coroutine.yield(i,obj)
			stabs     = stabs - 1
		else
			unset[obj] = true
		end
	end
end

local iterateStabs = function(t,i)
	return coReuse,{iterStabs,t,i}
end

s.areaQuery = function(self,x0,y0,x1,y1,enclosed)
	local score = 0
	if enclosed then score = 3 end
	local xset,yset = {},{}
	local xt,yt = self.xintervals,self.yintervals
	-- find leftmost index > x and y
	local xi,a = binsearch(xt,x0) ; xi = a
	local yi,a = binsearch(yt,y0) ; yi = a
	-- iterate backward and collect objects that contains the area
	for i,obj in iterateStabs(xt,xi) do
		xset[obj] = xset[obj] and xset[obj]+1 or 1
	end
	for i,obj in iterateStabs(yt,yi) do
		yset[obj] = yset[obj] and yset[obj]+1 or 1
	end
	-- iterate from x0 to x1,y0 to y1 and collect boxes in the interval
	while xt[xi] and xt[xi].value <= x1 do
		local obj = xt[xi].obj
		xset[obj] = xset[obj] and xset[obj]+2 or 2
		xi = xi + 1
	end
	while yt[yi] and yt[yi].value <= y1 do
		local obj = yt[yi].obj
		yset[obj] = yset[obj] and yset[obj]+2 or 2
		yi = yi + 1
	end
	-- when score > 0 for an object on all axes, it's overlapping the query
	-- 2 points for each endpoint in the interval --> 4 points mean the box intervals are enclosed on that axis
	-- when score > 3 for an object on all axes, it's enclosed by the query
	for obj in pairs(xset) do
		if yset[obj] and xset[obj] > score and yset[obj] > score then
			xset[obj] = obj
		else
			xset[obj] = nil
		end
	end
	return xset
end

s.pointQuery = function(self,x,y)
	local xset,yset = {},{}
	local xt,yt = self.xintervals,self.yintervals
	local xi,a = binsearch(xt,x) ; xi = a
	local yi,a = binsearch(yt,y) ; yi = a
	for i,obj in iterateStabs(xt,xi) do
		xset[obj] = obj
	end
	for i,obj in iterateStabs(yt,yi) do
		if xset[obj] then yset[obj] = obj end
	end
	
	return yset
end

-- Raycast through a voxel grid
local raycast = function(self,x,y,dx,dy,isCoroutine)
	local multiset  = {}
	local xt,yt     = self.xintervals,self.yintervals
	local xi,yi,_   = 1,1
	-- find left most index > x and y
	_,xi = binsearch(xt,x)
	_,yi = binsearch(yt,y)
	-- Iterate backward and collect intervals that contains the starting point.
	-- Say that there is a ray pointing up and there is a box right above it. 
	-- The ray is enclosed in the box left and right interval so it has a multiset value of 1.
	-- Since the ray is vertical, it won't sweep the x axis list and collect objects.
	-- When the ray touches the box bottom interval, it will return it as a collision instead of
	-- missing it.
	for i,obj in iterateStabs(xt,xi) do
		multiset[obj] = 1
	end
	for i,obj in iterateStabs(yt,yi) do
		multiset[obj] = multiset[obj] and multiset[obj] + 1 or 1
	end
	
	-- initial configurations
	local xStep,yStep,smallest,dxRatio,dyRatio,xv,yv,xsidehit,ysidehit
	local xt,yt = self.xintervals,self.yintervals
	-- moving right(+), check left bound hit
	if dx > 0 then 
		xStep    = 1
		xsidehit = 0
	else
		-- start at the left endpoint (<= x) when ray points left
		xi       = xi - 1
		xStep    = -1
		xsidehit = 1
	end
	-- moving down(+) check top bound hit
	if dy > 0 then 
		yStep    = 1
		ysidehit = 0
	else
		-- start at the top endpoint (<= y) when ray points up
		yi       = yi - 1
		yStep    = -1
		ysidehit = 1
	end
	
	-- initial calculation
	xv = xt[xi] and xt[xi].value or xStep*math.huge
	yv = yt[yi] and yt[yi].value or yStep*math.huge
	-- hack for diving by zero
	dxRatio,dyRatio = dx == 0 and math.huge or (xv - x)/dx,dy == 0 and math.huge or (yv - y)/dy
	smallest        = min(dxRatio,dyRatio)
	
	-- voxel traversal loop
	-- the shortest distance to the next line is used
	while smallest <= 1 do
		-- if the the next line is vertical...
		if smallest == dxRatio then
			-- if the line is an outside bound...
			if xt[xi].interval == xsidehit then
				multiset[xt[xi].obj] = multiset[xt[xi].obj] and multiset[xt[xi].obj] + 1 or 1
			else
				multiset[xt[xi].obj] = 0
			end
			-- if the box is hit on both axes
			if multiset[xt[xi].obj] > 1 then
				if isCoroutine then coroutine.yield(xt[xi].obj,xv,dxRatio*dy+y) 
				else return xt[xi].obj,xv,dxRatio*dy+y end
			end
			-- update the ratio for the next step
			xi      = xi + xStep
			xv      = xt[xi] and xt[xi].value or xStep*math.huge
			dxRatio = (xv - x)/dx
		else
			if yt[yi].interval == ysidehit then
				multiset[yt[yi].obj] = multiset[yt[yi].obj] and multiset[yt[yi].obj] + 1 or 1
			else
				multiset[yt[yi].obj] = 0
			end
			if multiset[yt[yi].obj] > 1 then
				if isCoroutine then coroutine.yield(yt[yi].obj,dyRatio*dx+x,yv)
				else return yt[yi].obj,dyRatio*dx+x,yv end
			end
			yi      = yi + yStep
			yv      = yt[yi] and yt[yi].value or yStep*math.huge
			dyRatio = (yv - y)/dy
		end
		-- calculate for next loop
		smallest        = min(dxRatio,dyRatio)
	end
end

s.rayQuery = raycast

s.iterRay = function(self,x,y,dx,dy)
	return coroutine.wrap(function()
		raycast(self,x,y,dx,dy,true)
	end)
end

return function ()
	local instance = {
		xintervals   = {},
		yintervals   = {},
		objects      = {},
		deletebuffer = {},
		xbuffer      = {},
		ybuffer      = {},
	}
	return setmetatable(instance,s)
end