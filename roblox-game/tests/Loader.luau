--!strict
-- Lune only. Makes Roblox-style requires such as require(script.Parent.Rules.Scaling) work on
-- the files on disk, following Rojo's rules:
--   folder/init.luau      -> ModuleScript named "folder" (its other files are its children)
--   folder/               -> Folder
--   Name.luau             -> ModuleScript
--   Name.server.luau      -> Script, Name.client.luau -> LocalScript (cannot be required)
-- Modules loaded this way see no `game`, so anything that touches Roblox fails loudly. That is
-- how the tests prove the shared rules are pure.
--
-- The whole folder tree is scanned once up front: instance lookups happen inside metamethods,
-- where Lune's file functions are not allowed to run.

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local Loader = {}

type Node = {
	name: string,
	kind: "folder" | "module" | "script",
	file: string?,
	parent: Node?,
	children: { [string]: Node },
	order: { string },
}

local function scan(path: string, name: string, parent: Node?): Node
	local node: Node = { name = name, kind = "folder", parent = parent, children = {}, order = {} }
	if fs.isFile(path .. "/init.luau") then
		node.kind = "module"
		node.file = path .. "/init.luau"
	end
	local entries = fs.readDir(path)
	table.sort(entries)
	for _, entry in entries do
		local full = path .. "/" .. entry
		local child: Node? = nil
		if fs.isDir(full) then
			child = scan(full, entry, node)
		elseif entry ~= "init.luau" then
			local scriptName = string.match(entry, "^(.-)%.server%.luau$")
				or string.match(entry, "^(.-)%.client%.luau$")
			local moduleName = string.match(entry, "^(.-)%.luau$")
			if scriptName then
				child = { name = scriptName, kind = "script", parent = node, children = {}, order = {} }
			elseif moduleName then
				child = { name = moduleName, kind = "module", file = full, parent = node, children = {}, order = {} }
			end
		end
		if child then
			node.children[child.name] = child
			table.insert(node.order, child.name)
		end
	end
	return node
end

export type Loader = {
	instance: (self: Loader, relativePath: string) -> any,
	require: (self: Loader, target: any) -> any,
}

function Loader.new(root: string): Loader
	local tree = scan(root, string.match(root, "([^/]+)$") or root, nil)
	local sources: { [string]: string } = {}
	local proxies: { [Node]: any } = {}
	local nodeOf: { [any]: Node } = {}
	local cache: { [string]: any } = {}
	local loading: { [string]: boolean } = {}

	-- Read every module's source now, outside any metamethod.
	local function preload(node: Node)
		if node.file then
			sources[node.file] = fs.readFile(node.file)
		end
		for _, child in node.children do
			preload(child)
		end
	end
	preload(tree)

	local function className(node: Node): string
		return if node.kind == "folder" then "Folder" elseif node.kind == "script" then "Script" else "ModuleScript"
	end

	local function proxy(node: Node): any
		local existing = proxies[node]
		if existing then
			return existing
		end
		local methods = {}
		function methods.FindFirstChild(_: any, name: string): any
			local child = node.children[name]
			return if child then proxy(child) else nil
		end
		function methods.WaitForChild(_: any, name: string): any
			local child = node.children[name]
			if child == nil then
				error(`{name} is not a child of {node.name}`, 2)
			end
			return proxy(child)
		end
		function methods.GetChildren(_: any): { any }
			local out = {}
			for _, name in node.order do
				table.insert(out, proxy(node.children[name]))
			end
			return out
		end
		function methods.IsA(_: any, name: string): boolean
			return name == className(node)
		end
		local p = setmetatable({}, {
			__index = function(_, key: string): any
				if key == "Name" then
					return node.name
				elseif key == "Parent" then
					return if node.parent then proxy(node.parent) else nil
				elseif key == "ClassName" then
					return className(node)
				elseif methods[key] then
					return methods[key]
				end
				local child = node.children[key]
				if child then
					return proxy(child)
				end
				error(`{key} is not a valid member of {node.name}`, 2)
			end,
			__tostring = function()
				return node.name
			end,
		})
		proxies[node] = p
		nodeOf[p] = node
		return p
	end

	local function requireNode(node: Node): any
		if node.kind ~= "module" or node.file == nil then
			error(`{node.name} is not a ModuleScript`, 2)
		end
		local file = node.file :: string
		if cache[file] ~= nil then
			return cache[file]
		end
		if loading[file] then
			error(`require loop involving {file}`, 2)
		end
		loading[file] = true
		local chunk = luau.load(sources[file], {
			debugName = file,
			environment = {
				script = proxy(node),
				require = function(target: any): any
					local targetNode = nodeOf[target]
					if targetNode == nil then
						error("require() needs a module from this loader", 2)
					end
					return requireNode(targetNode)
				end,
			},
		})
		local result = chunk()
		loading[file] = nil
		cache[file] = if result == nil then true else result
		return cache[file]
	end

	local function find(relativePath: string): Node
		local node = tree
		for part in string.gmatch(relativePath, "[^/]+") do
			local child = node.children[part]
			if child == nil then
				error(`no {part} in {node.name}`, 3)
			end
			node = child
		end
		return node
	end

	local self = {}
	function self.instance(_: any, relativePath: string): any
		return proxy(find(relativePath))
	end
	function self.require(_: any, target: any): any
		if type(target) == "string" then
			return requireNode(find(target))
		end
		local node = nodeOf[target]
		if node == nil then
			error("require() needs a module from this loader", 2)
		end
		return requireNode(node)
	end
	return (self :: any) :: Loader
end

return Loader
