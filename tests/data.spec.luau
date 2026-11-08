-- Pure-logic tests runnable with the standalone Luau CLI:
--   luau tests/data.spec.luau
-- Roblox-only globals used by the data modules are stubbed below.

local function stubColor(r, g, b)
	return { R = r, G = g, B = b }
end
Color3 = { fromRGB = stubColor, new = stubColor }
Enum = setmetatable({}, {
	__index = function(_, enumName)
		return setmetatable({}, {
			__index = function(_, item)
				return enumName .. "." .. item
			end,
		})
	end,
})

local Recipes = require("../src/shared/Data/Recipes")
local Potions = require("../src/shared/Data/Potions")
local Ingredients = require("../src/shared/Data/Ingredients")
local Challenges = require("../src/shared/Data/Challenges")
local Reactions = require("../src/shared/Data/Reactions")

local passed, failed = 0, 0
local function test(name: string, fn: () -> ())
	local ok, err = pcall(fn)
	if ok then
		passed += 1
	else
		failed += 1
		print("FAIL  " .. name .. "\n      " .. tostring(err))
	end
end
local function expect(condition: any, message: string?)
	if not condition then
		error(message or "expectation failed", 2)
	end
end

test("recipe keys are order independent", function()
	expect(Recipes.key({ "b", "a", "a" }) == "a+a+b")
	expect(Recipes.key({ "a", "b", "a" }) == Recipes.key({ "a", "a", "b" }))
end)

test("recipe index builds without duplicates", function()
	local index = Recipes.buildIndex(Potions.List)
	local count = 0
	for _ in index do
		count += 1
	end
	expect(count >= 30, "expected at least 30 recipes, got " .. count)
end)

test("every recipe uses known ingredients", function()
	for _, potion in Potions.List do
		for _, id in potion.recipe do
			expect(Ingredients.ById[id] ~= nil, potion.id .. " uses unknown ingredient " .. id)
		end
	end
end)

test("resolve finds potions and rejects unknown mixes", function()
	local index = Recipes.buildIndex(Potions.List)
	expect(Recipes.resolve(index, { "ember_root", "ember_root" }) == "inferno_brew")
	expect(Recipes.resolve(index, { "gale_feather", "ember_root" }) == "rocket_fuel")
	expect(Recipes.resolve(index, { "storm_moss", "gale_feather", "gale_feather" }) == "tornado_tonic")
	expect(Recipes.resolve(index, { "ember_root", "slime_gel" }) == nil)
	expect(Recipes.resolve(index, { "ember_root" }) == nil)
	expect(Recipes.resolve(index, { "a", "b", "c", "d" }) == nil)
end)

test("affordability and requirements", function()
	expect(Recipes.canAfford({ ember_root = 2 }, { "ember_root", "ember_root" }))
	expect(not Recipes.canAfford({ ember_root = 1 }, { "ember_root", "ember_root" }))
	local need = Recipes.requirements({ "x", "x", "y" })
	expect(need.x == 2 and need.y == 1)
end)

test("hint search returns an undiscovered potion sharing ingredients", function()
	local id = Recipes.closestUndiscovered(Potions.List, {}, { "ember_root", "slime_gel" })
	expect(id ~= nil, "expected a hint")
	local potion = Potions.ById[id :: string]
	local shares = false
	for _, ingredient in potion.recipe do
		if ingredient == "ember_root" or ingredient == "slime_gel" then
			shares = true
		end
	end
	expect(shares, "hint should share an ingredient")
end)

test("every potion is reachable with buyable or earnable ingredients", function()
	for _, potion in Potions.List do
		for _, id in potion.recipe do
			local ingredient = Ingredients.ById[id]
			expect(ingredient.price > 0 or id == "philosophers_stone", potion.id .. " needs unobtainable " .. id)
		end
	end
end)

test("trial star thresholds are ordered", function()
	for _, trial in Challenges.Trials do
		expect(trial.stars[1] >= trial.stars[2] and trial.stars[2] >= trial.stars[3], trial.id .. " stars out of order")
		expect(Challenges.starsFor(trial, trial.stars[3]) == 3, trial.id .. " 3-star time")
		expect(Challenges.starsFor(trial, trial.timeLimit + 1) == 0, trial.id .. " over time")
	end
end)

test("only the final trial grants the Philosopher's Stone", function()
	local grants = 0
	for _, trial in Challenges.Trials do
		if trial.reward.ingredients and trial.reward.ingredients.philosophers_stone then
			grants += 1
			expect(trial.final == true, trial.id .. " is not marked final")
		end
	end
	expect(grants == 1, "expected exactly one stone source")
end)

test("trial potions exist", function()
	for _, trial in Challenges.Trials do
		for id in trial.potions do
			expect(Potions.ById[id] ~= nil, trial.id .. " provides unknown potion " .. id)
		end
	end
end)

test("daily templates have three tiers", function()
	for _, template in Challenges.Daily do
		expect(#template.targets == 3, template.id .. " needs 3 targets")
	end
end)

test("reactions have unique ids", function()
	local seen = {}
	for _, reaction in Reactions.List do
		expect(not seen[reaction.id], "duplicate reaction " .. reaction.id)
		seen[reaction.id] = true
	end
end)

print(("%d passed, %d failed"):format(passed, failed))
if failed > 0 then
	error("tests failed")
end
