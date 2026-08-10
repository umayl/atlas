--!strict

local function split(path: string): { string }
	local parts = {}

	for part in string.gmatch(path, '[^/]+') do
		table.insert(parts, part)
	end

	return parts
end

local function normalize(path: string): string
	local parts = {}

	for _, part in split(path) do
		if part == '' or part == '.' then
			continue
		end

		if part == '..' then
			if #parts > 0 then
				table.remove(parts)
			end

			continue
		end

		table.insert(parts, part)
	end

	return `@{table.concat(parts, '/')}`
end

local function resolve(path: string, relativeTo: string?): string
	if string.sub(path, 1, 1) == '@' then
		return normalize(string.sub(path, 2))
	end

	if path == '.' or string.sub(path, 1, 2) == './' or path == '..' or string.sub(path, 1, 3) == '../' then
		return normalize(`{relativeTo or '@'}/{path}`)
	end

	return normalize(path)
end

local function fromInstance(instance: Instance, root: Instance): string
	if instance == root then
		return '@'
	end

	local parts = {}
	local current: Instance? = instance

	while current and current ~= root do
		table.insert(parts, 1, current.Name)

		current = current.Parent
	end

	if current ~= root then
		error(`Instance is outside the AssetGraph: {instance:GetFullName()}`)
	end

	return `@{table.concat(parts, '/')}`
end

return table.freeze {
	resolve = resolve,
	fromInstance = fromInstance,
}
