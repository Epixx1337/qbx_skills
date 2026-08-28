return {
    radial = {
        id = 'qbx_skills',
        icon = 'diagram-project',
    },

    xp = {
        base = 100, -- experience needed to go from level 0 to level 1
        growth = 1.15, -- each level multiplies the next requirement by this
        maxLevel = 50,
    },
    pointsPerLevel = 1, -- talent points granted on every level up

    linkRequirement = 'any', -- 'any' unlocks a skill when one parent is owned, 'all' requires every parent
    activeTreePerCategory = false, -- one active tree per category (e.g. one crime and one civilian at once), false allows only one active tree total
    abandonResetsProgress = false, -- switching away from a tree wipes its experience and unlocked skills
    switchRequiresMaxLevel = false, -- the active tree must be at max level before another can be chosen
    inactivePerksApply = false, -- unlocked skills keep working while their tree is not the active one

    notifyOnLevelUp = true,
    seedExampleTrees = true, -- insert the example trees from skills_seed.sql on start; disable to build trees from scratch or to stop deleted example skills from coming back

    stats = {
        enabled = true, -- qbx_skills applies max_health, max_armour and stamina bonuses to the ped itself
        baseHealth = 200, -- game units, 200 shows as 100 hp in most huds
        baseArmour = 100,
        baseStamina = 60, -- 0-100 sprint stat
        healthCap = 25, -- highest total bonus a build can reach, on top of the base
        armourCap = 25,
        staminaCap = 40,
    },
}
