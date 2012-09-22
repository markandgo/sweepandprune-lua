local p = {}
p.__index = p

p.set = function(self,a1,a2,value)
	self[a1] = self[a1] or {}
	self[a2] = self[a2] or {}
	self[a1][a2] = value or a2
	self[a2][a1] = value or a1
end

p.unset = function(self,a1,a2)
	self[a1][a2] = nil
	self[a2][a1] = nil
end

p.get = function(self,a1,a2)
	return self[a1][a2]
end

p.getAll = function(self,a)
	local list = {}
	for a2,v in self:iterate(a) do
		list[a2] = v
	end
	return list
end

p.iterate = function(self,a)
	return next,self[a]
end

p.remove = function(self,a)
	for a2 in self:iterate(a) do
		self[a2][a] = nil
	end
	self[a] = nil
end

p.new = function(self)
	return setmetatable({
	},p)
end

return setmetatable(p,{__call = p.new})