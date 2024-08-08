--!nocheck

--[[

Blox2D v2
A module to help you on your journey to develop a game using only UI

Current featureset:
Collision detection
Raycasting
Point containment detection

Developed by EmK530 :)

]]

local module = {}

local initialized = false

local MainGame

--[[
Prepares the module for use in an environment specified by `obj`
Any checks done on objects outside the environment may fail.
Either ScreenGui or other objects like Frames are valid inputs here.
]]--
module.Init = function(obj)
	MainGame = obj
	initialized = true
end

--[[
Changes the behavior of the module.
]]--
module.Config = {
	HollowShapesWhenCasting = false,
	CacheCornerCalculations = true
}

local function notLoadedWarning(action)
	warn("Cannot perform "..action.." when module is not initialized. Check the Init function of the module.")
	return nil
end

local a = {'X', 'Y'}
local modC = {{2,2,1},{3,1,2},{4,2,1},{1,1,2}}
local function IsPointInCoords(point, c)
	for i,v in pairs(modC) do
		local c1,a2,a3 = v[1],a[v[2]],a[v[3]]
		local div = c[c1][a2].Scale-c[i][a2].Scale
		local target = c[i][a3].Scale+((div==0 and 0 or (c[c1][a3].Scale-c[i][a3].Scale)/div)*(point[a2].Scale-c[i][a2].Scale))
		if (i<=2 and point[a3].Scale<target) or (i>2 and point[a3].Scale>target) then return false end
	end
	return true
end
local function IsPointInCoordsT(point, c)
	for i,v in pairs(modC) do
		local c1,c2,c3 = v[1],v[2],v[3]
		local div = c[c1][c2]-c[i][c2]
		local target = c[i][c3]+((div==0 and 0 or (c[c1][c3]-c[i][c3])/div)*(point[c2]-c[i][c2]))
		if (i<=2 and point[c3]<target) or (i>2 and point[c3]>target) then return false end
	end
	return true
end

local requiresRecalc = true
local lastPos = nil
local lastSize = nil

local function optimalGetGameScale()
	if requiresRecalc then
		requiresRecalc = false
		local offset = MainGame.AbsolutePosition
		local gameScale = MainGame.AbsoluteSize
		lastPos = offset
		lastSize = gameScale
		MainGame.Changed:Once(function()
			requiresRecalc = true
		end)
		return offset,gameScale
	else
		return lastPos, lastSize
	end
end

local cachedCorners = {}

--[[
Returns four UDim2 coordinates (in scale) for the corners of `obj`
`scale`: Simulate a different object size by using this as a multiplier.
`asArray`: Return the coordinates in table format instead of UDim2, usually more performant to have a table.
]]--
module.GetObjectCorners = function(obj,scale: number,asArray: boolean)
	if not initialized then return notLoadedWarning("GetObjectCorners") end
	local doCache = module.Config.CacheCornerCalculations
	local c = if doCache then cachedCorners[obj] else nil
	if c then
		return c
	end
	debug.profilebegin("GetObjectCorners")
	scale = scale or 1
	local offset,gameScale = optimalGetGameScale()
	local pos = obj.AbsolutePosition
	local size = obj.AbsoluteSize
	local rotation = obj.Rotation
	local midX, midY = pos.X + (size.X / 2*scale), pos.Y + (size.Y / 2*scale)
	local angle = obj.Rotation
	local radang = angle==0 and 0 or math.rad(angle)
	local cosang = angle==0 and 1 or math.cos(radang)
	local sinang = angle==0 and 0 or math.sin(radang)
	local coords = {}
	for i = 1, 4 do
		local cornerX = (i <= 2 and midX - (size.X / 2*scale) or midX + (size.X / 2*scale))
		local cornerY = (i%4 <= 1 and midY + (size.Y / 2*scale) or midY - (size.Y / 2*scale))
		local originX = cornerX - midX
		local originY = cornerY - midY
		local rX = (originX * cosang) - (originY * sinang)
		local rY = (originX * sinang) + (originY * cosang)
		if asArray then
			table.insert(coords,{((rX+midX)-offset.X)/gameScale.X,((rY+midY)-offset.Y)/gameScale.Y})
		else
			table.insert(coords,UDim2.fromScale(((rX+midX)-offset.X)/gameScale.X,((rY+midY)-offset.Y)/gameScale.Y))
		end
	end
	local sort = {}
	local calc = math.floor((obj.Rotation+45)/90)
	for i = 0, 3 do
		sort[i+1] = coords[(i-calc)%4+1]
	end
	if doCache then
		cachedCorners[obj] = sort
		obj.Changed:Once(function()
			cachedCorners[obj] = nil
		end)
	end
	debug.profileend()
	return sort
end

--[[
Returns true or false for whether the two objects are colliding.
`o1` and `o2` are your objects to compare.

-- NOTE --
This is an old function lacking certain checks to be fully precise.
Please consider checking out CheckCollisionFPNR or CheckCollisionFP which utilize this function better.

If you want to write more performant code, you can make this function
skip checking for object corners by supplying your own table from the function,
instead of instances for `o1` and `o2`
]]--
module.CheckCollisionLegacy = function(o1,o2,_internal_CollisionFPdoNotCheckInputs)
	if not initialized then return notLoadedWarning("CheckCollision") end
	debug.profilebegin("CheckCollision")
	local targetFunc = IsPointInCoordsT
	if not _internal_CollisionFPdoNotCheckInputs then
		if typeof(o1) ~= "table" then o1 = module.GetObjectCorners(o1,1,true) else targetFunc = (typeof(o1[1])=="table" and IsPointInCoordsT or IsPointInCoords) end
		if typeof(o2) ~= "table" then o2 = module.GetObjectCorners(o2,1,true) end
	end
	for i,v in pairs(o1) do
		if targetFunc(v,o2) then
			debug.profileend()
			return true
		end
	end
	for i,v in pairs(o2) do
		if targetFunc(v,o1) then
			debug.profileend()
			return true
		end
	end
	debug.profileend()
	return false
end

--[[
Returns true or false for whether an object's AnchorPoint is inside another object's hitbox.
Argument 1 requires an instance to check the AnchorPoint of.
Argument 2 can accept either a table variant of GetObjectCorners or an instance.
]]--
module.IsCenterColliding = function(o1,o2)
	if not initialized then return notLoadedWarning("IsCenterColliding") end
	debug.profilebegin("IsCenterColliding")
	if typeof(o2) ~= "table" then o2 = module.GetObjectCorners(o2,1,true) end
	local _,gameScale = optimalGetGameScale()
	local ap1,ap2 = o1.AbsolutePosition,o1.AnchorPoint
	local as = o1.AbsoluteSize
	if IsPointInCoordsT({(ap1.X+as.X*ap2.X)/gameScale.X,(ap1.Y+as.Y*ap2.Y)/gameScale.Y},o2) then
		debug.profileend()
		return true
	end
	debug.profileend()
	return false
end

--[[
Returns true or false for whether a coordinate (Scale type) is inside an object's hitbox.
Argument 1 requires a table input with two numbers inside, X and Y coordinates.
Argument 2 can accept either a table variant of GetObjectCorners or an instance.

This function expects coordinates of Scale type, so they should be from 0 to 1.
]]--
module.IsPointColliding = function(o1:{},o2)
	if not initialized then return notLoadedWarning("IsPointColliding") end
	debug.profilebegin("IsPointColliding")
	if typeof(o2) ~= "table" then o2 = module.GetObjectCorners(o2,1,true) end
	if IsPointInCoordsT(o1,o2) then
		debug.profileend()
		return true
	end
	debug.profileend()
	return false
end

local function isIntersecting(s1, e1, s2, e2)
	local x1, y1 = s1[1], s1[2]
	local x2, y2 = e1[1], e1[2]
	local x3, y3 = s2[1], s2[2]
	local x4, y4 = e2[1], e2[2]
	local d = (x1 - x2) * (y3 - y4) - (y1 - y2) * (x3 - x4)
	if d == 0 then
		return false
	end
	local t = ((x1 - x3) * (y3 - y4) - (y1 - y3) * (x3 - x4)) / d
	if t >= 0 and t <= 1 then
		local u = -((x1 - x2) * (y1 - y3) - (y1 - y2) * (x1 - x3)) / d
		if u >= 0 and u <= 1 then
			return true
		else
			return false
		end
	else
		return false
	end
end

local function CheckCollisionOneWay(o1,o2)
	local targetFunc = (typeof(o2[1])=="table" and IsPointInCoordsT or IsPointInCoords)
	for i,v in pairs(o1) do
		if targetFunc(v,o2) then
			return true
		end
	end
	return false
end

--[[
(Full Precision No Rotation)
Collision check variant of CheckCollisionFP that cuts out
a fourth of the line intersection checks and half of the legacy collision detection.
This however does not work for rotated objects, please don't try it.

Requires table variant of GetObjectCorners, not UDim2.

If you want to write more performant code, you can make this function
skip checking for object corners by supplying your own table from the function,
instead of instances for `o1` and `o2`
]]--
module.CheckCollisionFPNR = function(o1,o2)
	if not initialized then return notLoadedWarning("CheckCollisionFPNR") end
	debug.profilebegin("CheckCollisionFPNR")
	if typeof(o1) ~= "table" then o1 = module.GetObjectCorners(o1,1,true) end
	if typeof(o2) ~= "table" then o2 = module.GetObjectCorners(o2,1,true) end
	if CheckCollisionOneWay(o1,o2) then debug.profileend() return true end
	if isIntersecting(o1[1],o1[2],o2[2],o2[3]) then debug.profileend() return true end
	if isIntersecting(o1[3],o1[4],o2[2],o2[3]) then debug.profileend() return true end
	if isIntersecting(o1[1],o1[2],o2[4],o2[1]) then debug.profileend() return true end
	if isIntersecting(o1[3],o1[4],o2[4],o2[1]) then debug.profileend() return true end
	debug.profileend()
	return false
end

--[[
(Full Precision)
The most precise yet expensive collision check function, performs 16 line intersect checks.
Also uses the full legacy collision detection to check if an object is inside the target, where no sides would be intersecting.
Not recommended for common use, use CheckCollisionFPNR when not dealing with rotation.

Requires table variant of GetObjectCorners, not UDim2.

If you want to write more performant code, you can make this function
skip checking for object corners by supplying your own table from the function,
instead of instances for `o1` and `o2`
]]--
module.CheckCollisionFP = function(o1,o2)
	if not initialized then return notLoadedWarning("CheckCollisionFP") end
	debug.profilebegin("CheckCollisionFP")
	if typeof(o1) ~= "table" then o1 = module.GetObjectCorners(o1,1,true) end
	if typeof(o2) ~= "table" then o2 = module.GetObjectCorners(o2,1,true) end
	if module.CheckCollisionLegacy(o1,o2,true) then debug.profileend() return true end
	for x = 1, 4 do
		local x2 = math.max(1,(x+1)%5)
		for y = 1, 4 do
			local y2 = math.max(1,(y+1)%5)
			if isIntersecting(o1[x],o1[x2],o2[y],o2[y2]) then debug.profileend() return true end
		end
	end
	debug.profileend()
	return false
end

local function getIntersect(s1, e1, s2, e2)
	local x1, y1 = s1[1], s1[2]
	local x2, y2 = e1[1], e1[2]
	local x3, y3 = s2[1], s2[2]
	local x4, y4 = e2[1], e2[2]
	local d = (x1 - x2) * (y3 - y4) - (y1 - y2) * (x3 - x4)
	if d == 0 then
		return nil
	end
	local t = ((x1 - x3) * (y3 - y4) - (y1 - y3) * (x3 - x4)) / d
	if t >= 0 and t <= 1 then
		local u = -((x1 - x2) * (y1 - y3) - (y1 - y2) * (x1 - x3)) / d
		if u >= 0 and u <= 1 then
			return {x1 + t * (x2 - x1), y1 + t * (y2 - y1)}
		else
			return nil
		end
	else
		return nil
	end
end

local constant = 1.5707963267948966

local function getNormalFromCoords(l1,l2)
	debug.profilebegin("CalculateNormal")
	local x1,x2,y1,y2 = l1[1],l2[1],l1[2],l2[2]
	local ax,ay = x1-x2,y1-y2
	local offset,gameScale = optimalGetGameScale()
	local ang = math.atan2(ax,ay*(gameScale.Y/gameScale.X))
	local midX = x2+(ax)/2
	local midY = y2+(ay)/2
	local res = Vector2.new(math.sin(ang-constant),math.cos(ang-constant))
	debug.profileend()
	return res
end

local function scaleOnly(dim)
	local as = MainGame.AbsoluteSize
	local dx,dy,vx,vy = dim.X,dim.Y,as.X,as.Y
	return {dx.Scale+dx.Offset/vx,dy.Scale+dy.Offset/vy}
end

--[[
Perform a raycast operation, returns a table of info or nil if nothing is hit.
`src`: Raycast source.
`dir`: Raycast direction from source as offset.
`ignore`: Table of objects to ignore when casting.
`collection`: (optional) Table of objects to perform raycasting checks on or an instance whose children will be checked.

If successful, returns a table containing:
Position: UDim2 where the ray hit something (only scale),
Instance: Object that the ray hit,
Distance: Distance to the ray hit,
Normal: Vector2 normal calculated from the intersected object side
]]--
module.Raycast = function(src: UDim2,dir: UDim2,ignore: {},collection)
	if not initialized then return notLoadedWarning("Raycast") end
	debug.profilebegin("Raycast")
	local dest = scaleOnly(src+dir)
	src=scaleOnly(src)
	dir=scaleOnly(dir)
	local dist = math.huge
	local intersect = nil
	local inst = nil
	local i1,i2 = nil,nil
	local iter = (collection and (typeof(collection)~="table" and collection:GetChildren() or collection) or MainGame:GetChildren())
	for _,v in pairs(iter) do
		if not table.find(ignore,v) then
			local c = module.GetObjectCorners(v,1,true)
			if not module.Config.HollowShapesWhenCasting and IsPointInCoordsT(src,c) then intersect = src dist = 0 inst = v break end
			for i = 1, 4 do
				local l1,l2=c[i],c[i%4+1]
				local temp = getIntersect(src,dest,l1,l2)
				if temp then
					local dst = math.sqrt((temp[1]-src[1])^2 + (temp[2]-src[2])^2)
					if dst < dist then
						i1,i2=l1,l2
						intersect = temp
						dist = dst
						inst = v
					end
				end
			end
		end
	end
	local nrm = (intersect and i1 and i2) and getNormalFromCoords(i1,i2) or Vector2.new(0,0)
	debug.profileend()
	return intersect and {
		Position = UDim2.fromScale(intersect[1],intersect[2]),
		Instance = inst,
		Distance = dist,
		Normal = nrm
	} or nil
end

return module
