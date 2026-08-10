--!strict

const ContentProvider = game:GetService 'ContentProvider'

const paths = require './paths'
const query = require './query'
const types = require './types'

type AssetGraph = types.AssetGraph
type Query = types.Query

-- indexing

const function index(self: AssetGraph, instance: Instance)
	const path = paths.fromInstance(instance, self._root)

	self._indexed[path] = instance
	self._records[instance] = path
end

const function unindex(self: AssetGraph, instance: Instance)
	const path = self._records[instance]

	if not path then
		return
	end

	self._records[instance] = nil
	self._indexed[path] = nil
end

-- resolution

const function resolve(self: AssetGraph, path: string, relativeTo: string | Instance?): Instance?
	const isGlobal = string.sub(path, 1, 1) == '@'

	local relativePath: string?

	if typeof(relativeTo) == 'Instance' then
		relativePath = self._records[relativeTo]
	elseif typeof(relativeTo) == 'string' then
		relativePath = paths.resolve(relativeTo)
	end

	if path == '@self' then
		if relativePath then
			path = relativePath
		else
			path = '@'
		end
	end

	const resolvedPath = paths.resolve(path, relativePath)

	const instance = self._indexed[resolvedPath]

	if instance then
		return instance
	end

	if isGlobal then
		const alias = self._aliases[resolvedPath]

		if alias and typeof(alias) == 'Instance' then
			return alias
		end
	end

	return nil
end

-- assets

const function get(self: AssetGraph, path: string, relativeTo: string | Instance?): Instance
	const instance = resolve(self, path, relativeTo)

	if not instance then
		error(`Asset not found: {path}`)
	end

	return instance
end

const function find(self: AssetGraph, path: string, relativeTo: string | Instance?): Instance?
	return resolve(self, path, relativeTo)
end

const function path(self: AssetGraph, instance: Instance): string
	const path = self._records[instance]

	if not path then
		error(`Instance is not registered in the AssetGraph: {instance:GetFullName()}`)
	end

	return path
end

const function clone(self: AssetGraph, asset: string | Instance): Instance
	local instance: Instance
	if typeof(asset) == 'string' then
		instance = get(self, asset)
	else
		instance = asset
	end

	return instance:Clone()
end

-- aliases

const function alias(self: AssetGraph, name: string, value: Instance | Query)
	if string.sub(name, 1, 1) ~= '@' then
		error(`Alias must use the @ namespace: {name}`)
	end

	const resolvedName = paths.resolve(name)

	self._aliases[resolvedName] = value
end

-- query sources

const function all(self: AssetGraph): { Instance }
	const result = {}

	for instance in self._records do
		if instance ~= self._root then
			table.insert(result, instance)
		end
	end

	return result
end

const function queryAssets(self: AssetGraph, source: any?): Query
	if source == nil then
		return query(self, function()
			return all(self)
		end)
	end

	if type(source) == 'table' and source._atlasQuery == true then
		return source
	end

	if typeof(source) == 'Instance' then
		return query(self, function()
			return {
				source,
			}
		end)
	end

	if typeof(source) == 'string' then
		if string.sub(source, 1, 1) == '@' then
			const resolvedPath = paths.resolve(source)

			const alias = self._aliases[resolvedPath]

			if alias and type(alias) == 'table' and alias._atlasQuery == true then
				return alias
			end
		end

		const instance = find(self, source)

		if not instance then
			error(`Query source not found: {source}`)
		end

		return query(self, function()
			return {
				instance,
			}
		end)
	end

	if type(source) == 'table' then
		return query(self, function()
			return source
		end)
	end

	error 'Invalid query source'
end

-- preload

const function preload(self: AssetGraph, source: any)
	const instances = {}

	if typeof(source) == 'string' then
		table.insert(instances, get(self, source))
	elseif typeof(source) == 'Instance' then
		table.insert(instances, source)
	elseif type(source) == 'table' and source._atlasQuery == true then
		for _, value in source:collect() do
			if typeof(value) == 'Instance' then
				table.insert(instances, value)
			end
		end
	elseif type(source) == 'table' then
		for _, value in source do
			if typeof(value) == 'Instance' then
				table.insert(instances, value)
			elseif typeof(value) == 'string' then
				table.insert(instances, get(self, value))
			end
		end
	else
		error 'Invalid preload source'
	end

	const preloadInstances = {}
	const seen = {}

	for _, instance in instances do
		if not seen[instance] then
			seen[instance] = true

			table.insert(preloadInstances, instance)
		end

		for _, descendant in instance:GetDescendants() do
			if not seen[descendant] then
				seen[descendant] = true

				table.insert(preloadInstances, descendant)
			end
		end
	end

	if #preloadInstances > 0 then
		ContentProvider:PreloadAsync(preloadInstances)
	end
end

-- constructor

const function assetGraph(root: Instance): AssetGraph
	const graph = {
		_root = root,
		_indexed = {},
		_records = {},
		_aliases = {},

		get = get,
		find = find,
		path = path,
		clone = clone,

		alias = alias,

		query = queryAssets,
		preload = preload,
	} :: AssetGraph

	index(graph, root)

	for _, descendant in root:GetDescendants() do
		index(graph, descendant)
	end

	root.DescendantAdded:Connect(function(instance)
		index(graph, instance)
	end)

	root.DescendantRemoving:Connect(function(instance)
		unindex(graph, instance)
	end)

	return graph
end

return assetGraph
