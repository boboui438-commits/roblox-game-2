--!nonstrict
--[[
	Util
	----
	Petites fonctions partagées (formatage, hasard pondéré, maths).
]]

local Util = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi" }

--- Formate un nombre court : 1234 -> "1.2K"
function Util.formatNumber(value: number): string
	if value ~= value or value == math.huge then
		return "∞"
	end
	local negative = value < 0
	value = math.abs(value)
	local suffix = 1
	while value >= 1000 and suffix < #SUFFIXES do
		value /= 1000
		suffix += 1
	end
	local text
	if value >= 100 then
		text = string.format("%d", math.floor(value))
	elseif value >= 10 then
		text = string.format("%.1f", value)
	else
		text = string.format("%.2f", value)
	end
	text = text:gsub("%.?0+$", "")
	if negative then
		text = "-" .. text
	end
	return text .. SUFFIXES[suffix]
end

--- Formate un nombre avec séparateurs : 1234567 -> "1 234 567"
function Util.formatFull(value: number): string
	local rounded = math.floor(math.abs(value) + 0.5)
	local text = tostring(rounded)
	local formatted = text:reverse():gsub("(%d%d%d)", "%1 "):reverse()
	formatted = formatted:gsub("^%s+", "")
	if value < 0 then
		formatted = "-" .. formatted
	end
	return formatted
end

--- 95 -> "1:35"
function Util.formatClock(seconds: number): string
	seconds = math.max(0, math.floor(seconds + 0.5))
	local minutes = math.floor(seconds / 60)
	local rest = seconds % 60
	if minutes > 0 then
		return string.format("%d:%02d", minutes, rest)
	end
	return string.format("%ds", rest)
end

function Util.clamp(value: number, minValue: number, maxValue: number): number
	if value < minValue then
		return minValue
	elseif value > maxValue then
		return maxValue
	end
	return value
end

function Util.round(value: number): number
	return math.floor(value + 0.5)
end

function Util.isFiniteNumber(value: any): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

function Util.isSafeInteger(value: any): boolean
	return Util.isFiniteNumber(value) and math.floor(value) == value
end

--- Copie profonde d'une table (sans métatables).
function Util.deepCopy(source: any): any
	if type(source) ~= "table" then
		return source
	end
	local copy = {}
	for key, value in pairs(source) do
		copy[key] = Util.deepCopy(value)
	end
	return copy
end

--- Choisi un élément au hasard selon un poids.
function Util.weightedPick(items: { any }, weightOf: (any) -> number, rng: Random?): any
	local total = 0
	local weights = {}
	for index, item in ipairs(items) do
		local weight = math.max(0, weightOf(item))
		weights[index] = weight
		total += weight
	end
	if total <= 0 then
		return items[1]
	end
	local roll = (rng and rng:NextNumber() or math.random()) * total
	for index, item in ipairs(items) do
		roll -= weights[index]
		if roll <= 0 then
			return item
		end
	end
	return items[#items]
end

function Util.randomChoice(items: { any }, rng: Random?): any
	if #items == 0 then
		return nil
	end
	local index = rng and rng:NextInteger(1, #items) or math.random(1, #items)
	return items[index]
end

--- Mélange une copie du tableau.
function Util.shuffled(items: { any }, rng: Random?): { any }
	local copy = table.clone(items)
	for index = #copy, 2, -1 do
		local other = rng and rng:NextInteger(1, index) or math.random(1, index)
		copy[index], copy[other] = copy[other], copy[index]
	end
	return copy
end

--- Limite une chaîne de caractères (anti spam / anti injection UI).
function Util.trim(text: string, maxLength: number): string
	text = tostring(text)
	if #text > maxLength then
		text = text:sub(1, maxLength)
	end
	return text
end

--- Couleur hexadécimale -> Color3 avec protection.
function Util.hex(value: string, fallback: Color3?): Color3
	local ok, result = pcall(Color3.fromHex, value)
	if ok then
		return result
	end
	return fallback or Color3.fromRGB(200, 200, 200)
end

return Util
