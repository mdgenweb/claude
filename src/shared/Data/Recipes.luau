--!strict
-- Pure recipe logic (no Roblox APIs) so it can be unit-tested with the standalone Luau CLI.
-- A recipe is an unordered multiset of 2–3 ingredient ids.

local Recipes = {}

export type PotionLike = { id: string, recipe: { string } }

Recipes.MinIngredients = 2
Recipes.MaxIngredients = 3

-- Canonical key: sorted ids joined with "+". {"b","a","a"} -> "a+a+b"
function Recipes.key(ingredientIds: { string }): string
	local copy = table.clone(ingredientIds)
	table.sort(copy)
	return table.concat(copy, "+")
end

-- Builds a key -> potionId lookup. Errors on duplicate recipes so data mistakes are caught early.
function Recipes.buildIndex(potions: { any }): { [string]: string }
	local index = {}
	for _, potion in potions do
		if #potion.recipe >= Recipes.MinIngredients then
			local key = Recipes.key(potion.recipe)
			if index[key] then
				error(("Duplicate recipe %s for %s and %s"):format(key, index[key], potion.id))
			end
			index[key] = potion.id
		end
	end
	return index
end

-- Returns the potion id for a mix (or nil for an unknown mix).
function Recipes.resolve(index: { [string]: string }, ingredientIds: { string }): string?
	local count = #ingredientIds
	if count < Recipes.MinIngredients or count > Recipes.MaxIngredients then
		return nil
	end
	return index[Recipes.key(ingredientIds)]
end

-- Counts how many of each ingredient a mix needs: {"a","a","b"} -> {a=2,b=1}
function Recipes.requirements(ingredientIds: { string }): { [string]: number }
	local need = {}
	for _, id in ingredientIds do
		need[id] = (need[id] or 0) + 1
	end
	return need
end

-- True when `inventory` holds everything the mix needs.
function Recipes.canAfford(inventory: { [string]: number }, ingredientIds: { string }): boolean
	for id, amount in Recipes.requirements(ingredientIds) do
		if (inventory[id] or 0) < amount then
			return false
		end
	end
	return true
end

-- Hint for an unknown mix: names an undiscovered potion that shares the most ingredients.
function Recipes.closestUndiscovered(
	potions: { any },
	discovered: { [string]: boolean },
	ingredientIds: { string }
): (string?, number)
	local mixNeed = Recipes.requirements(ingredientIds)
	local bestId, bestScore = nil, 0
	for _, potion in potions do
		if #potion.recipe >= Recipes.MinIngredients and not discovered[potion.id] then
			local score = 0
			for id, amount in Recipes.requirements(potion.recipe) do
				score += math.min(amount, mixNeed[id] or 0)
			end
			if score > bestScore then
				bestId, bestScore = potion.id, score
			end
		end
	end
	return bestId, bestScore
end

return Recipes
