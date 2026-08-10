--!strict

const CollectionService = game:GetService 'CollectionService'

const types = require './types'

type Query = types.Query
type AssetGraph = types.AssetGraph
type Operation = types.Operation
type Predicate = types.Predicate
type Mapper = types.Mapper
type Comparator = types.Comparator

local constructQuery: (graph: AssetGraph, source: () -> { any }, operations: { Operation }) -> Query

const function derive(self: Query, operation: Operation): Query
	const operations = table.clone(self._operations)

	table.insert(operations, operation)

	return constructQuery(self._graph, self._source, operations)
end

-- results

const function collect(self: Query): { any }
	local values = self._source()

	for _, operation in self._operations do
		values = operation(values)
	end

	return values
end

const function first(self: Query): any?
	return self:collect()[1]
end

const function single(self: Query): any
	const values = self:collect()

	if #values ~= 1 then
		error(`Expected exactly one result, got {#values}`)
	end

	return values[1]
end

const function any(self: Query): boolean
	return self:first() ~= nil
end

const function count(self: Query): number
	return #self:collect()
end

-- assets

const function clone(self: Query): Instance
	const instance = self:single()

	if typeof(instance) ~= 'Instance' then
		error 'Query:clone() requires an Instance result'
	end

	return instance:Clone()
end

const function factory(self: Query): () -> Instance
	return function()
		const instance = self:single()

		if typeof(instance) ~= 'Instance' then
			error 'Query:factory() requires an Instance result'
		end

		return instance:Clone()
	end
end

const function preload(self: Query)
	self._graph:preload(self)
end

-- filters

const function class(self: Query, className: string): Query
	return derive(self, function(values)
		const result = {}

		for _, value in values do
			if typeof(value) == 'Instance' and value:IsA(className) then
				table.insert(result, value)
			end
		end

		return result
	end)
end

const function tag(self: Query, tagName: string): Query
	return derive(self, function(values)
		const result = {}

		for _, value in values do
			if typeof(value) == 'Instance' and CollectionService:HasTag(value, tagName) then
				table.insert(result, value)
			end
		end

		return result
	end)
end

const function attribute(self: Query, name: string, expected: any): Query
	return derive(self, function(values)
		const result = {}

		for _, value in values do
			if typeof(value) ~= 'Instance' then
				continue
			end

			const actual = value:GetAttribute(name)

			if typeof(expected) == 'function' then
				if expected(actual) then
					table.insert(result, value)
				end
			elseif actual == expected then
				table.insert(result, value)
			end
		end

		return result
	end)
end

const function property(self: Query, name: string, expected: any): Query
	return derive(self, function(values)
		const result = {}

		for _, value in values do
			if typeof(value) ~= 'Instance' then
				continue
			end

			const success, actual = pcall(function()
				return (value :: any)[name]
			end)

			if not success then
				continue
			end

			if typeof(expected) == 'function' then
				if expected(actual) then
					table.insert(result, value)
				end
			elseif actual == expected then
				table.insert(result, value)
			end
		end

		return result
	end)
end

const function where(self: Query, predicate: Predicate): Query
	return derive(self, function(values)
		const result = {}

		for _, value in values do
			if typeof(value) == 'Instance' and predicate(value) then
				table.insert(result, value)
			end
		end

		return result
	end)
end

-- hierarchy

const function children(self: Query): Query
	return derive(self, function(values)
		const result = {}

		for _, value in values do
			if typeof(value) ~= 'Instance' then
				continue
			end

			for _, child in value:GetChildren() do
				table.insert(result, child)
			end
		end

		return result
	end)
end

const function descendants(self: Query): Query
	return derive(self, function(values)
		const result = {}

		for _, value in values do
			if typeof(value) ~= 'Instance' then
				continue
			end

			for _, descendant in value:GetDescendants() do
				table.insert(result, descendant)
			end
		end

		return result
	end)
end

const function parent(self: Query): Query
	return derive(self, function(values)
		const result = {}
		const seen = {}

		for _, value in values do
			if typeof(value) ~= 'Instance' then
				continue
			end

			const parentInstance = value.Parent

			if parentInstance and not seen[parentInstance] then
				seen[parentInstance] = true

				table.insert(result, parentInstance)
			end
		end

		return result
	end)
end

-- sets

const function intersect(self: Query, other: Query): Query
	return derive(self, function(values)
		const allowed = {}

		for _, value in other:collect() do
			allowed[value] = true
		end

		const result = {}

		for _, value in values do
			if allowed[value] then
				table.insert(result, value)
			end
		end

		return result
	end)
end

const function union(self: Query, other: Query): Query
	return derive(self, function(values)
		const result = {}
		const seen = {}

		for _, value in values do
			if not seen[value] then
				seen[value] = true

				table.insert(result, value)
			end
		end

		for _, value in other:collect() do
			if not seen[value] then
				seen[value] = true

				table.insert(result, value)
			end
		end

		return result
	end)
end

const function exclude(self: Query, other: Query): Query
	return derive(self, function(values)
		const excluded = {}

		for _, value in other:collect() do
			excluded[value] = true
		end

		const result = {}

		for _, value in values do
			if not excluded[value] then
				table.insert(result, value)
			end
		end

		return result
	end)
end

-- transformations

const function map(self: Query, mapper: Mapper): Query
	return derive(self, function(values)
		const result = {}

		for _, value in values do
			table.insert(result, mapper(value))
		end

		return result
	end)
end

const function sort(self: Query, comparator: Comparator): Query
	return derive(self, function(values)
		table.sort(values, comparator)

		return values
	end)
end

const function random(self: Query): Query
	return derive(self, function(values)
		if #values == 0 then
			return {}
		end

		return {
			values[math.random(1, #values)],
		}
	end)
end

-- constructor

constructQuery = function(graph: AssetGraph, source: () -> { any }, operations: { Operation }): Query
	return table.freeze {
		_graph = graph,
		_source = source,
		_operations = table.freeze(operations),
		_atlasQuery = true,

		collect = collect,
		first = first,
		single = single,
		any = any,
		count = count,

		clone = clone,
		factory = factory,
		preload = preload,

		class = class,
		tag = tag,
		attribute = attribute,
		property = property,
		where = where,

		children = children,
		descendants = descendants,
		parent = parent,

		intersect = intersect,
		union = union,
		exclude = exclude,

		map = map,
		sort = sort,
		random = random,
	}
end

const function query(graph: AssetGraph, source: () -> { any }): Query
	return constructQuery(graph, source, {})
end

return query
