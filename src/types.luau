--!strict

export type Predicate = (instance: Instance) -> boolean
export type Mapper = (value: any) -> any
export type Comparator = (a: any, b: any) -> boolean
export type Operation = (values: { any }) -> { any }

export type Query = {
	_graph: AssetGraph,
	_source: () -> { any },
	_operations: { Operation },
	_atlasQuery: boolean,

	collect: (self: Query) -> { any },
	first: (self: Query) -> any?,
	single: (self: Query) -> any,
	any: (self: Query) -> boolean,
	count: (self: Query) -> number,

	clone: (self: Query) -> Instance,
	factory: (self: Query) -> () -> Instance,
	preload: (self: Query) -> (),

	class: (self: Query, className: string) -> Query,
	tag: (self: Query, tagName: string) -> Query,
	attribute: (self: Query, name: string, expected: any) -> Query,
	property: (self: Query, name: string, expected: any) -> Query,
	where: (self: Query, predicate: Predicate) -> Query,

	children: (self: Query) -> Query,
	descendants: (self: Query) -> Query,
	parent: (self: Query) -> Query,

	intersect: (self: Query, other: Query) -> Query,
	union: (self: Query, other: Query) -> Query,
	exclude: (self: Query, other: Query) -> Query,

	map: (self: Query, mapper: Mapper) -> Query,
	sort: (self: Query, comparator: Comparator) -> Query,
	random: (self: Query) -> Query,
}

export type AssetGraph = {
	_root: Instance,
	_indexed: { [string]: Instance },
	_records: { [Instance]: string },
	_aliases: { [string]: Instance | Query },

	get: (self: AssetGraph, path: string, relativeTo: string | Instance?) -> Instance,
	find: (self: AssetGraph, path: string, relativeTo: string | Instance?) -> Instance?,
	path: (self: AssetGraph, instance: Instance) -> string,
	clone: (self: AssetGraph, asset: string | Instance) -> Instance,

	alias: (self: AssetGraph, name: string, value: Instance | Query) -> (),

	query: (self: AssetGraph, source: any?) -> Query,
	preload: (self: AssetGraph, source: any) -> (),
}

return nil
