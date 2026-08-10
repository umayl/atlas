--!strict

const assetGraph = require '@self/assetGraph'
const types = require '@self/types'

export type AssetGraph = types.AssetGraph
export type Query = types.Query

return table.freeze {
	assetGraph = assetGraph,
}
