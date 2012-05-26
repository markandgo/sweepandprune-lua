--[[
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

-- sweep and prune (SAP)	
-- x0 < x1 and y0 < y1
local tinsert = table.insert
local tremove = table.remove
local tsort = table.sort
local pairs = pairs
local assert = assert
local weakValues = {_mode = 'v'}

local boolop = 
{
	x = {	TRUE 	= {[0] = 1,[1] = 0,[10] = 11,[11]	= 11},
			XOR 	= {[0] = 1,[1] = 0,[10] = 11,[11]	= 10}
		},
	
	y = {	TRUE 	= {[0] = 10,[1] = 11,[10] = 10,[11] = 11},
			XOR 	= {[0] = 10,[1] = 11,[10] = 00,[11] = 01},
		},
}

boolop.xt = boolop.x.TRUE
boolop.xx = boolop.x.XOR
boolop.yt = boolop.y.TRUE
boolop.yx = boolop.y.XOR

local deletePairing = function (t,obj)
	for obj2,_ in pairs(t[obj]) do
		t[obj2][obj] = nil
	end
end

local removeAllReferences = function (self,axis,endpoint)
	if axis == 'y' and endpoint.interval == 1 then
		local obj = endpoint.obj
		deletePairing(self.actives,obj)
		deletePairing(self.boolflags,obj)
		
		self.boolflags[obj] 	= nil
		self.actives[obj] 		= nil
		self.endrefs[obj] 		= nil
		self.deletebuffer[obj]  = nil
	end
end

local ifOrder = function (endpointA,endpointB) 
	return 	endpointA.point < endpointB.point or 
			endpointA.point == endpointB.point and 
			endpointA.interval < endpointB.interval
end

local checkAndSetPair = function (self,obj1,obj2)
	local pairflags = self.boolflags[obj1][obj2]
	
	if pairflags == 11 then
		self.actives[obj1][obj2] = true
		self.actives[obj2][obj1] = true
	elseif pairflags == 10 or pairflags == 01 then
		self.actives[obj1][obj2] = nil
		self.actives[obj2][obj1] = nil
	end
end

local changeFlags = function (self,mode,obj1,obj2)
	local bitT 		= boolop[mode]
	local inputflag = self.boolflags[obj1][obj2] or 0
	local newflag	= bitT[inputflag]
	
	self.boolflags[obj1][obj2] = newflag
	self.boolflags[obj2][obj1] = newflag
end

local processSets = function (self,mode,endpoint,obj,setMaintain,...)
	local setsCollide = {...}
	
	if endpoint.interval == 0 then
		setMaintain[obj] = obj
	else
		setMaintain[obj] = nil
		for _,set in ipairs(setsCollide) do
			for obj2,_ in pairs(set) do
				changeFlags(self,mode,obj,obj2)
				checkAndSetPair(self,obj,obj2)
			end
		end
	end
end

local SweepAndPrune = function (self,axis)
	local intervalT
	local bufferT
	local setInsert
	local setInterval
	local xormode
	local truemode
	
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
			processSets(self,truemode,insertEP,insertEP.obj,setInsert,setInsert,setInterval)
			
			tinsert(intervalT,i,insertEP)				
			tremove(bufferT,j)
			
			i = i + 1
		elseif endpoint then			
			local obj1 = endpoint.obj
			
			if setInsert then
				processSets(self,truemode,endpoint,obj1,setInterval,setInsert)
			end
				
			local k = i - 1
			while k > 0 and not ifOrder(intervalT[k],endpoint) do
				local endpoint2 = intervalT[k]
				local obj2 = intervalT[k].obj
			
				intervalT[k+1] = intervalT[k]
				k = k - 1
				
				if endpoint.interval == endpoint2.interval then
					changeFlags(self,truemode,obj1,obj2)
				else
					changeFlags(self,xormode,obj1,obj2)
				end
							
				checkAndSetPair(self,obj1,obj2)
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

local add = function (self,obj,x0,y0,x1,y1)
	assert(not self.endrefs[obj],'object already inserted')
	local x0t = {point = x0,interval = 0,obj = obj}
	local y0t = {point = y0,interval = 0,obj = obj}
	local x1t = {point = x1,interval = 1,obj = obj}
	local y1t = {point = y1,interval = 1,obj = obj}

	self.boolflags[obj] = {}
	self.actives[obj] = {}
	self.endrefs[obj] = 
		{
		x0t = x0t,
		y0t = y0t,
		x1t = x1t,
		y1t = y1t,
		}
	
	tinsert(self.xbuffer,	x0t)
	tinsert(self.ybuffer,	y0t)
	tinsert(self.xbuffer,	x1t)
	tinsert(self.ybuffer,	y1t)
	
	return obj
end

local delete = function (self,obj)
	assert(self.endrefs[obj],'no such object exist!')
	self.deletebuffer[obj] = obj
end

local move = function (self,obj,x0,y0,x1,y1)
	assert(not self.deletebuffer[obj],'Cannot move object before deletion!')
	local x0t = self.endrefs[obj].x0t
	local y0t = self.endrefs[obj].y0t
	local x1t = self.endrefs[obj].x1t
	local y1t = self.endrefs[obj].y1t
	
	x0t.point = x0
	y0t.point = y0
	x1t.point = x1
	y1t.point = y1
end

local update = function (self)
	tsort(self.xbuffer,ifOrder)
	tsort(self.ybuffer,ifOrder)
		
	SweepAndPrune (self,'x')
	SweepAndPrune (self,'y')
end

local query = function (self,obj)
	local list = {}
	for obj2,_ in pairs(self.actives[obj]) do
		list[obj2] = obj2
	end
	return list
end

local SAP = function ()
	local instance = {
		xintervals 	= {},
		yintervals	= {},
		add 		= add,
		delete 		= delete,
		move		= move,
		update		= update,
		query		= query,
		endrefs 	= {},
		boolflags	= {},
		actives		= {},
		deletebuffer= {},
		xbuffer		= {},
		ybuffer 	= {},
	}
	return instance
end

return SAP