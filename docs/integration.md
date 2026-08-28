# Integrating qbx_skills into other resources

The pattern is always the same:

1. **Award experience** when the player completes an activity — `AddXp` with the category the
   activity belongs to. The player only progresses if their active specialization is in that
   category, which is what makes choosing a specialization matter.
2. **Read skills or bonuses** where the activity resolves — `HasSkill` for on/off perks,
   `GetSkillBonus` for stacking numeric modifiers.

Skill identifiers and bonus keys are whatever you set in the in-game editor. Everything below
uses the seeded `shadow_work` tree (`crime` category) as the example.

## Example: car lockpicking (qbx_vehiclekeys)

### Award crime experience on a successful pick

The lockpick minigame resolves client side in `qbx_vehiclekeys/client/functions.lua` —
`lockpickSuccessCallback` runs when the lock opens and already reports the result to the
server. Award the experience in the server handlers that process the result, so a civilian
spec gains nothing from stealing cars while a crime spec levels:

```lua
-- qbx_vehiclekeys/server/main.lua
RegisterNetEvent('qbx_vehiclekeys:server:hotwiredVehicle', function(netId)
    GiveKeys(source, NetworkGetEntityFromNetworkId(netId))
    exports.qbx_skills:AddXp(source, 20, 'crime')
end)
```

`AddXp` returns `true` when the experience applied — the player has an active tree and it
belongs to the `crime` category, so there is nothing to check yourself. Use
`AddTreeXp(source, 'shadow_work', 15)` instead when the experience should ignore the category
and always hit one specific tree.

### Make unlocked skills matter

The client cache is synced automatically, so perk checks are free and can run inside skill
checks and animations. `getVehicleInVehicleLockpickingRadius` in
`qbx_vehiclekeys/client/functions.lua` runs the `lib.skillCheck` — ease it for skilled players:

```lua
-- qbx_vehiclekeys/client/functions.lua, before the skillcheck starts
local skillCheckConfig = config.skillCheck[isAdvancedLockedpick and 'advancedLockpick' or 'lockpick']

-- 'lockpick_speed' sums over every unlocked skill that carries it,
-- so Steady Hands (0.1) + Master Locksmith (0.25) = 0.35
if exports.qbx_skills:GetSkillBonus('lockpick_speed') >= 0.25 then
    skillCheckConfig = { 'easy', 'easy', 'medium' }
end
```

On/off perks use `HasSkill` — for example around `SendPoliceAlertAttempt` in
`lockpickCallback`:

```lua
if exports.qbx_skills:HasSkill('quick_entry') then
    Wait(exports.qbx_skills:GetSkillBonus('alarm_delay') * 1000)
end
SendPoliceAlertAttempt('carjack', vehicle)
```

### Trusting the server

Client exports read a synced cache and are fine for UX (skillcheck difficulty, animation
speed). Anything that touches items or money must check on the server, where the cache is
authoritative. The lockpick break chance is a good example — qbx_vehiclekeys breaks picks via
`qb-vehiclekeys:server:breakLockpick`, so apply Nimble Fingers there instead of on the client:

```lua
-- qbx_vehiclekeys/server/main.lua
RegisterNetEvent('qb-vehiclekeys:server:breakLockpick', function(itemName)
    if not (itemName == 'lockpick' or itemName == 'advancedlockpick') then return end
    if math.random() < exports.qbx_skills:GetSkillBonus(source, 'lockpick_durability') then return end
    exports.ox_inventory:RemoveItem(source, itemName, 1)
end)
```

## More examples: one mechanic at a time

Bonus keys are free-form — a skill carries whatever keys you give it in the editor, and a
script reads them with `GetSkillBonus`. These are the common mechanics, each shown on a real
resource:

| mechanic | bonus style | example below |
| --- | --- | --- |
| bigger payouts | `payout_bonus` fraction | qbx_garbagejob |
| extra yield chance | `harvest_yield_chance` roll | qbx_weed |
| lower alert chance | negative `police_alert_chance` | qbx_storerobbery |
| faster actions | `repair_speed` on durations | qbx_mechanicjob |
| better prices | `street_rep` multiplier | qbx_drugs corner selling |
| gated content | `HasSkill` on/off | qbx_drugs deliveries |
| faster levelling | `xp_bonus` | built into qbx_skills |

### Payout bonus — qbx_garbagejob

The payslip is paid in `qbx_garbagejob/server/main.lua` (the `AddMoney('bank', totalToPay, ...)`
call). Scale it with the Blue Collar perks and award civilian experience for the run:

```lua
totalToPay = math.floor(totalToPay * (1 + exports.qbx_skills:GetSkillBonus(src, 'payout_bonus')))
player.Functions.AddMoney('bank', totalToPay, 'garbage-payslip')
exports.qbx_core:Notify(src, locale('success.pay_slip', totalToPay, payoutDeposit), 'success')

exports.qbx_skills:AddXp(src, 35, 'civilian')
```

With the seeded tree, Work Ethic (0.05) + Overtime (0.1) makes every payslip 15% larger.
The same one-liner fits any job payout: taxi fares, trucker deliveries, tow invoices.

### Extra yield chance — qbx_weed

`qbx_weed:server:harvestPlant` in `qbx_weed/server/main.lua` rolls `harvestAmount`. A
"green thumb" style skill with a `harvest_yield_chance` bonus (e.g. `0.25` = 25%) grants a
bonus bag on a lucky roll:

```lua
local harvestAmount = math.random(config.randomHarvestAmount.min, config.randomHarvestAmount.max)
if math.random() < exports.qbx_skills:GetSkillBonus(player.PlayerData.source, 'harvest_yield_chance') then
    harvestAmount += 1
end
```

Players without the skill get a bonus of `0`, so the roll never passes — no `HasSkill` check
needed. The same shape covers golden fish, double scrap, or bonus ore.

### Lower alert chance — qbx_storerobbery

`qbx_storerobbery/client/main.lua` rolls `config.policeAlertChance` when a register is hit.
A stealth skill carrying `police_alert_chance = -0.2` (negative, like the seeded Ghost skill)
subtracts from it:

```lua
local chance = config.policeAlertChance
if GetClockHours() >= 22 or GetClockHours() <= 5 then
    chance = config.policeNightAlertChance
end
chance += exports.qbx_skills:GetSkillBonus('police_alert_chance')
if math.random() < chance then
    TriggerServerEvent('police:server:policeAlert')
end
```

This is a client read, which is fine — the alert roll already happens on the client in this
resource, and the cache only contains what the server granted.

### Faster actions — qbx_mechanicjob

Any `lib.progressBar`/`lib.progressCircle` duration can honor a speed perk. In
`qbx_mechanicjob/client/main.lua` the repair progress bar becomes:

```lua
if lib.progressBar({
    duration = math.floor(5000 * (1 - exports.qbx_skills:GetSkillBonus('repair_speed'))),
    label = locale('progress.repairing'),
    ...
```

Keep speed bonuses as fractions (`0.1` = 10% faster) so stacked skills stay readable, and cap
the total in the editor by what you hand out — three skills of `0.2` means 60% faster.

### Better prices — qbx_drugs corner selling

`qbx_drugs/server/cornerselling.lua` computes `price` before
`player.Functions.AddMoney('cash', price, 'sold-cornerdrugs')`. A reputation skill with a
`street_rep` bonus raises it:

```lua
price = math.floor(price * (1 + exports.qbx_skills:GetSkillBonus(player.PlayerData.source, 'street_rep')))
player.Functions.AddMoney('cash', price, 'sold-cornerdrugs')
exports.qbx_skills:AddXp(player.PlayerData.source, 10, 'crime')
```

### Gated content — qbx_drugs deliveries

`HasSkill` gates whole features on/off. To lock the high-tier dealer deliveries in
`qbx_drugs/server/deliveries.lua` behind a skill:

```lua
if sharedConfig.dealers[dealer].minLevel and not exports.qbx_skills:HasSkill(source, 'trusted_supplier') then
    exports.qbx_core:Notify(source, 'This dealer does not trust you yet.', 'error')
    return
end
```

The same pattern gates crafting recipes, advanced minigames, shop tabs or job vehicles.
Remember `HasSkill` only returns `true` while the skill's tree is active (unless
`inactivePerksApply` is enabled), so gates automatically close when a player switches
specialization.

### Faster levelling — built in

`xp_bonus` is a bonus key qbx_skills reads itself: every `AddXp`/`AddTreeXp` grant is
multiplied by `1 + xp_bonus` before it is applied. The seeded Foreman skill (`xp_bonus = 0.1`)
makes its owner level 10% faster with no integration work — just put the key on a skill in the
editor.

## Stat perks: health, armour and stamina — built in

Three more bonus keys are applied by qbx_skills itself, straight onto the ped. The seeded
**Second Wind** tree (civilian) uses all of them:

| key | unit | applied as |
| --- | --- | --- |
| `max_health` | display hp (5 = +5 hp over 100) | `SetEntityMaxHealth(ped, baseHealth + bonus)` |
| `max_armour` | armour points | `SetPlayerMaxArmour(player, baseArmour + bonus)` |
| `stamina` | 0–100 sprint stat points | `StatSetInt('MP0_STAMINA', baseStamina + bonus)` |

The base values and per-build caps live in `config/shared.lua` under `stats`:

```lua
stats = {
    enabled = true, -- set false if another resource owns these natives
    baseHealth = 200, -- game units, 200 shows as 100 hp in most huds
    baseArmour = 100,
    baseStamina = 60,
    healthCap = 25, -- highest total bonus a build can reach, on top of the base
    armourCap = 25,
    staminaCap = 40,
},
```

Values are reapplied on spawn, on revive (after qbx_medical resets max health to 200), and
whenever the player's skills change — including switching to a tree without the perks, which
drops them back to base. Set `stats.enabled = false` if a different resource manages these
natives and read the bonuses yourself with `GetSkillBonus`.

### Telling huds about the buffed values

Boosted maximums mean `health = GetEntityHealth(ped) - 100` can now exceed 100, and a hud that
hardcodes `/ 100` will overflow its bar. qbx_skills publishes the applied values on the player
statebag **`qbx_skills_stats`** (`{ maxHealth, maxArmour, stamina }`, game units), and the same
table is available via the client export `exports.qbx_skills:GetStats()`.

Scale a health bar against the real maximum:

```lua
-- e.g. qbx_hud/client/main.lua where the hud data is assembled
local stats = LocalPlayer.state.qbx_skills_stats
local maxHealth = (stats?.maxHealth or 200) - 100
local healthPercent = (GetEntityHealth(cache.ped) - 100) / maxHealth * 100
```

React to changes instead of polling (the statebag is replicated, so this also works in
server-side or other-player contexts):

```lua
AddStateBagChangeHandler('qbx_skills_stats', nil, function(bagName, _, value)
    local player = GetPlayerFromStateBagName(bagName)
    if player ~= cache.playerId then return end
    -- value is { maxHealth, maxArmour, stamina } or nil on logout — refresh hud scaling here
end)
```

If the statebag is `nil` (resource not running, player not loaded) fall back to 200/100.

## Job-locked trees

A tree can be restricted to jobs in the editor (tree settings → **Job lock**) with
`police, ambulance:2` syntax — job names with an optional minimum grade. The lock is enforced
server-side everywhere:

- players who don't hold the job can preview the tree but never select it,
- `AddXp`/`AddTreeXp` refuse to apply to a job-locked tree the player no longer qualifies for,
- on job change or login the active tree is deactivated automatically (progress is kept,
  perks stop applying) and the player is notified.

This is how you build a police-only specialization: create the tree, lock it to `police`, and
award XP from your police resources with `AddTreeXp(src, 'thin_blue_line', 25)` on arrests,
evidence work, etc.

## Integration summary

Mapped onto the stock qbx resources, the examples above look like this:

| resource | XP awarded | perks read |
| --- | --- | --- |
| qbx_vehiclekeys | 15 crime per lockpick, 20 per hotwire | `lockpick_speed` eases the skillcheck, `quick_entry`/`alarm_delay` delays the police alert on a failed pick, `lockpick_durability` saves picks from breaking |
| qbx_storerobbery | 25 crime per register, 75 per safe | `police_alert_chance` (negative) lowers the alert roll |
| qbx_weed | 10 crime per harvest | `harvest_yield_chance` rolls a bonus bag |
| qbx_drugs (corner selling) | 10 crime per sale | `street_rep` raises the sale price |
| qbx_garbagejob | 35 civilian per completed shift | `payout_bonus` raises the payslip |
| qbx_mechanicjob | — | `repair_speed` shortens the repair progress bar |

Seeded skills cover every key: Shadow Work carries the lockpick perks plus Street Smarts
(`street_rep`) and Green Thumb (`harvest_yield_chance`); Blue Collar carries `payout_bonus`,
`xp_bonus` and Shop Hands (`repair_speed`); Second Wind carries the stat perks.

## One active tree per category

By default only one specialization is active per player. With
`activeTreePerCategory = true` in `config/shared.lua`, players can keep **one active tree per
category** — e.g. a crime spec and a civilian spec levelling side by side. Everything scales
naturally:

- `AddXp(source, amount, category)` routes to the active tree of that category, so a
  lockpick feeds the crime tree while a garbage run feeds the civilian tree.
- `AddXp` without a category (and `GetLevel`/`GetActiveTree` without arguments) resolves only
  when exactly one tree is active — pass the category (`GetActiveTree(source, 'crime')`) or
  use `GetActiveTrees(source)`, which returns the full `category → tree` map (also available
  as a client export).
- Perks from every active tree apply simultaneously; switch policies (`abandonResetsProgress`,
  `switchRequiresMaxLevel`) apply per category.

## Suggested XP values

With the default curve (`base = 100`, `growth = 1.15`), level 10 needs ~405 XP and level 25
needs ~3,290 XP for the *next* level alone. As a rule of thumb:

| activity | XP |
| --- | --- |
| small, spammable action (pick a car, pick a plant) | 5–15 |
| completing a job run / delivery | 25–50 |
| big scripted event (store robbery, boss delivery) | 100–250 |

## Adding new skills for your integration

Open the skills UI as admin → **Edit**. Click an empty cell in a tree to create the skill,
give it an identifier (what `HasSkill` checks), a description, an icon, and add bonus rows
(what `GetSkillBonus` sums). Use **Link** to connect it under its prerequisite. The change is
live for every player immediately — your integration only ever refers to identifiers and bonus
keys, so no code changes are needed when admins rebalance the tree.
