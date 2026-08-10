--!strict

local assetGraph = require '@self/assetGraph'
local types = require '@self/types'

export type AssetGraph = types.AssetGraph
export type Query = types.Query

return table.freeze {
	assetGraph = assetGraph,
}
