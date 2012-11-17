--[[
sweepandprune.lua v1.42a

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
local huge    = math.huge
local setfenv = setfenv

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

-- stab number = number of lower bound endpoints - number of upper bound endpoints to the left of list[i]
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

local swapCallback = function(sap,endpoint2,endpoint)
	-- [0 ep2 1] [0 ep1 1] pre swap
	local obj1,obj2 = endpoint.obj,endpoint2.obj
	if endpoint.interval == 0 and endpoint2.interval == 1 then 
		setPair(sap,obj1,obj2)
		
		endpoint2.stabs = endpoint2.stabs + 1
		endpoint.stabs = endpoint.stabs + 1
		
	-- [0 ep2 [0  1] ep1 1] pre swap
	elseif endpoint.interval == 1 and endpoint2.interval == 0 then
		sap.paired[obj1][obj2] = nil
		sap.paired[obj2][obj1] = nil
		
		endpoint2.stabs = endpoint2.stabs - 1
		endpoint.stabs = endpoint.stabs - 1
	else
		endpoint2.stabs,endpoint.stabs = endpoint.stabs,endpoint2.stabs
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
	local checkStab = setInsert or next(deletebuffer)
	
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
			setStabs(intervalT,i)
			remove(bufferT,1)
			
			i = i + 1
		
		else
			-- insertion sort block
			if checkStab then setStabs(intervalT,i) end
		
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
			setStabs(intervalT,i)
			remove(bufferT,1)
			
			i = i + 1
		end
	end
end

-- http://lua-userlocal org/wiki/BinarySearch
-- return left index and right index of v where li < v < ri
local default_fcompval  = function( e ) return e and e.value end
local fcomp             = function( a,b ) return a < b end
local binsearch         = function( t,value)
	-- Initialise functions
	local fcompval = default_fcompval
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

-- iterate backward in the list and return stabbed endpoints
local iterStabs = function(state,i)
	if state.stabs > 0 then
		i           = i-1
		local t     = state[1]
		local skip  = state.skip
		local ep,obj= t[i],t[i].obj
		if ep.interval == 0 and not skip[obj] then 
			state.stabs = state.stabs - 1
			return i,obj
		else skip[obj] = true end
	end
end

local iterateStabs = function(t,i)
	return iterStabs,{t,skip = {},stabs = t[i] and t[i].stabs or 0},i
end

local addStabsToSet = function(intervalT,index,set)
	for i,obj in iterateStabs(intervalT,index) do
		set[obj] = set[obj] and set[obj]+1 or 1
	end
end

local initRayData = function(cI,cF,iT)
	local step,sidehit
	local _,i   = binsearch(iT,cI)
	local delta = cF - cI
	if delta > 0 then
		step,sidehit   = 1,0
	else
		i,step,sidehit = i-1,-1,1
	end
	-- set to infinity if key-value doesn't exist
	local indexV  = iT[i] and iT[i].value or step*math.huge
	-- set to infinity when diving by zero
	local dRatio  = delta == 0 and math.huge or (indexV - cI)/delta
	return delta,i,indexV,step,sidehit,dRatio
end

local getRayState = function(sap,x,y,x2,y2)
	local s = 
	{
		x=x,y=y,x2=x2,y2=y2,
		multiset = {},
		xt = sap.xintervals,
		yt = sap.yintervals,
	}

	-- initial voxel configurations
	s.dx,s.xi,s.xv,s.xStep,s.xsidehit,s.dxRatio = initRayData(x,x2,s.xt)
	s.dy,s.yi,s.yv,s.yStep,s.ysidehit,s.dyRatio = initRayData(y,y2,s.yt)
		
	return s
end

local raycast = function(s,obj)
	setfenv(1,s)
	-- take the shortest path to the next voxel
	local smallest = min(dxRatio,dyRatio)
	
	-- the first voxel is checked for internal collision
	-- one time only block
	if not obj then
		addStabsToSet(xt,xi+xsidehit,multiset)
		for i,obj in iterateStabs(yt,yi+ysidehit) do
			multiset[obj] = multiset[obj] and multiset[obj] + 1 or 1
			if multiset[obj] > 1 then return obj,x+smallest*dx,y+smallest*dy end
		end
	end

	-- voxel traversal loop
	while smallest <= 1 do
		-- if the the next line is vertical...
		if smallest == dxRatio then
			-- if the ray is hitting a box from the outside...
			if xt[xi].interval == xsidehit then
				multiset[xt[xi].obj] = multiset[xt[xi].obj] and multiset[xt[xi].obj] + 1 or 1
			else
				multiset[xt[xi].obj] = 0
			end
			
			local oxi,oRatio  = xi,dxRatio
			-- update the ratio for the next step
			xi      = xi + xStep
			xv      = xt[xi] and xt[xi].value or xStep*huge
			dxRatio = (xv - x)/dx
			
			-- if the box is hit on both axes
			if multiset[xt[oxi].obj] > 1 then 
				local xv = xt[oxi].value
				return xt[oxi].obj, xv, oRatio*dy+y
			end
		else
			if yt[yi].interval == ysidehit then
				multiset[yt[yi].obj] = multiset[yt[yi].obj] and multiset[yt[yi].obj] + 1 or 1
			else
				multiset[yt[yi].obj] = 0
			end
			
			local oyi,oRatio  = yi,dyRatio
			yi      = yi + yStep
			yv      = yt[yi] and yt[yi].value or yStep*huge
			dyRatio = (yv - y)/dy
			
			if multiset[yt[oyi].obj] > 1 then 
				local yv = yt[oyi].value
				return yt[oyi].obj, oRatio*dx+x, yv
			end
		end
		
		smallest  = min(dxRatio,dyRatio)
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
		local x0t = {value = x0,interval = 0,obj = obj,stabs = 0}
		local y0t = {value = y0,interval = 0,obj = obj,stabs = 0}
		local x1t = {value = x1,interval = 1,obj = obj,stabs = 0}
		local y1t = {value = y1,interval = 1,obj = obj,stabs = 0}
		
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
		t[obj2] = obj2
	end
	return t
end

s.areaQuery = function(self,x0,y0,x1,y1,enclosed)
	-- endpoint's score outside of area = 1
	-- endpoint's score inside of area = 2
	local minScore     = enclosed and 3 or 0
	local xset,yset = {},{}
	local xt,yt = self.xintervals,self.yintervals
	-- find leftmost index > x0 and y0
	local _,xi = binsearch(xt,x0)
	local _,yi = binsearch(yt,y0)
	if not enclosed then
		-- iterate backward and collect objects that overlaps the area
		addStabsToSet(xt,xi,xset)
		addStabsToSet(yt,yi,yset)
	end
	-- iterate within the area's intervals and collect overlapping boxes
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
	for obj in pairs(xset) do
		if yset[obj] and xset[obj] > minScore and yset[obj] > minScore then
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
	local _,xi  = binsearch(xt,x)
	local _,yi  = binsearch(yt,y)
	addStabsToSet(xt,xi,xset)
	for i,obj in iterateStabs(yt,yi) do
		if xset[obj] then yset[obj] = obj end
	end
	
	return yset
end

-- Raycast through a voxel grid
s.rayQuery = function(self,x,y,x2,y2)
	return raycast( getRayState(self,x,y,x2,y2) )
end

s.iterRay = function(self,x,y,x2,y2)
	return raycast,getRayState(self,x,y,x2,y2)
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