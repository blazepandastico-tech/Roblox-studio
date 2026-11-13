--!strict
--[[
	StudVoxelBuilder
	Builds a StudVox model at runtime from its generated data module
	(`out/<category>/<name>/<name>.luau`, put it in ReplicatedStorage).
	It produces the same structure as the generated .rbxmx file:

	  Model (PrimaryPart = Root, pivot at the bottom centre)
	    Root                      invisible box around the model
	    <rig part> (Model)
	      <rig part>Joint         invisible joint part with a Motor6D named after the rig part
	      boxes + studs           welded to the joint
	    Clip (StringValue)        clip name for StudVoxelAnimator / the Animate script
	    Outline (Highlight)

	Static models are anchored boxes; weapons are Tools with a Handle.

	local Builder = require(path.to.StudVoxelBuilder)
	local Animator = require(path.to.StudVoxelAnimator)
	local data = require(ReplicatedStorage.StudVox.duck)
	local model = Builder.Build(data, { parent = workspace, cframe = CFrame.new(0, 0, -10) })
	local anim = Animator.new(model, data.clips)  -- run animators on the client
	anim:Start(); anim:Play("idle")
]]

export type BuildOptions = {
	parent: Instance?,
	cframe: CFrame?,
	studs: string?, -- override: "surface" | "universal" | "texture" | "none"
	studTexture: string?, -- image id for "texture" mode (upload roblox/assets/stud_tile.png)
	highlight: boolean?,
	anchored: boolean?,
	name: string?,
}

local Builder = {}

local function makePart(data: any, colorIndex: number, cf: CFrame, size: Vector3): Part
	local c = data.palette[colorIndex]
	local p = Instance.new("Part")
	p.Name = string.gsub(string.gsub(c.name, "#", "c"), ":", "_")
	p.Size = size
	p.CFrame = cf
	p.Color = Color3.fromRGB(c.rgb[1], c.rgb[2], c.rgb[3])
	p.Material = (Enum.Material :: any)[c.material] or Enum.Material.Plastic
	p.Transparency = c.transparency
	p.Reflectance = c.reflectance
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	return p
end

local function weld(a: BasePart, b: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = b
	w.Parent = b
end

-- Studs come from Roblox's own surfaces: Studs / Inlet / Universal only render on Plastic.
-- "texture" tiles an uploaded stud image once per voxel (for voxels smaller than 1 stud).
local function applyStuds(p: Part, studded: boolean, studs: string, data: any, textureId: string?)
	local plastic = p.Material == Enum.Material.Plastic
	if studs == "surface" and plastic then
		if studded then
			p.TopSurface = Enum.SurfaceType.Studs
		end
		p.BottomSurface = Enum.SurfaceType.Inlet
	elseif studs == "universal" and plastic then
		if studded then
			p.TopSurface = Enum.SurfaceType.Universal
		end
	elseif studs == "texture" and studded and textureId then
		local t = Instance.new("Texture")
		t.Name = "Studs"
		t.Texture = textureId
		t.Face = Enum.NormalId.Top
		t.StudsPerTileU = data.voxelSize
		t.StudsPerTileV = data.voxelSize
		t.Parent = p
	end
end

local function addGeometry(
	data: any,
	part: any,
	container: Instance,
	joint: BasePart?,
	static: boolean,
	studs: string,
	textureId: string?
)
	local boxes = part.boxes
	for i = 1, #boxes, 8 do
		local cf = CFrame.new(boxes[i], boxes[i + 1], boxes[i + 2])
		local size = Vector3.new(boxes[i + 3], boxes[i + 4], boxes[i + 5])
		local p = makePart(data, boxes[i + 6], cf, size)
		applyStuds(p, boxes[i + 7] == 1, studs, data, textureId)
		p.Anchored = static
		p.CanCollide = static and data.collide
		p.CanTouch = static and data.collide
		p.Massless = not static
		p.Parent = container
		if joint then
			weld(joint, p)
		end
	end
end

local function invisible(name: string, cf: CFrame, size: Vector3): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Transparency = 1
	p.CanCollide = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	return p
end

local function vec(t: { number }): Vector3
	return Vector3.new(t[1], t[2], t[3])
end

function Builder.Build(data: any, options: BuildOptions?): Instance
	local opts: BuildOptions = options or {}
	local studs = opts.studs or data.studStyle
	local textureId = opts.studTexture or data.studTexture
	if studs == "texture" and not textureId then
		studs = "surface"
	end
	local kind = data.kind
	local root: Instance

	if kind == "tool" then
		local g = data.grip
		local tool = Instance.new("Tool")
		tool.Name = opts.name or data.title
		tool.ToolTip = data.title
		tool.RequiresHandle = true
		tool.Grip = CFrame.fromMatrix(Vector3.zero, vec(g.x), vec(g.y), vec(g.z))
		local handle = invisible("Handle", CFrame.new(vec(g.pos)), Vector3.new(0.4, 0.4, 0.4))
		handle.Parent = tool
		for _, part in data.parts do
			addGeometry(data, part, tool, handle, false, studs, textureId)
		end
		root = tool
	elseif kind == "static" then
		local model = Instance.new("Model")
		model.Name = opts.name or data.title
		for _, part in data.parts do
			addGeometry(data, part, model, nil, true, studs, textureId)
		end
		model.WorldPivot = CFrame.identity
		root = model
	else
		local model = Instance.new("Model")
		model.Name = opts.name or data.title
		local bmin, bmax = vec(data.bounds[1]), vec(data.bounds[2])
		local center = (bmin + bmax) / 2
		local size = (bmax - bmin):Max(Vector3.new(0.2, 0.2, 0.2))
		local rootPart = invisible("Root", CFrame.new(center), size)
		rootPart.Anchored = if opts.anchored ~= nil then opts.anchored else data.anchored
		rootPart.CanCollide = data.collide
		rootPart.PivotOffset = CFrame.new(-center)
		rootPart.Parent = model
		model.PrimaryPart = rootPart

		local joints: { [string]: BasePart } = {}
		for _, part in data.parts do
			local group = Instance.new("Model")
			group.Name = part.name
			local pivot = vec(part.pivot)
			local joint = invisible(part.name .. "Joint", CFrame.new(pivot), Vector3.new(0.2, 0.2, 0.2))
			joint.Massless = true
			joint.CanQuery = false
			joint.Parent = group
			local parentPart: BasePart = if part.parent then joints[part.parent] else rootPart
			local motor = Instance.new("Motor6D")
			motor.Name = part.name
			motor.Part0 = parentPart
			motor.Part1 = joint
			motor.C0 = parentPart.CFrame:ToObjectSpace(joint.CFrame)
			motor.C1 = CFrame.identity
			motor.Parent = joint
			joints[part.name] = joint
			addGeometry(data, part, group, joint, false, studs, textureId)
			group.Parent = model
		end
		local clip = Instance.new("StringValue")
		clip.Name = "Clip"
		clip.Value = data.defaultClip or ""
		clip.Parent = model
		root = model
	end

	local wantHighlight = if opts.highlight ~= nil then opts.highlight else data.highlight
	if wantHighlight then
		local h = Instance.new("Highlight")
		h.Name = "Outline"
		h.FillTransparency = 1
		h.OutlineTransparency = 0
		h.OutlineColor = Color3.new(0.07, 0.07, 0.08)
		h.DepthMode = Enum.HighlightDepthMode.Occluded
		h.Parent = root
	end

	if opts.cframe and root:IsA("Model") then
		root:PivotTo(opts.cframe)
	end
	if opts.parent then
		root.Parent = opts.parent
	end
	return root
end

return Builder
