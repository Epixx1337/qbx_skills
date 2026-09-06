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

Values are reapplied on spawn, whenever the player's skills change (including switching to a
tree without the perks, which drops them back to base), and after the medical script touches
the ped — see the medical bridge below. Set `stats.enabled = false` if a different resource
manages these natives and read the bonuses yourself with `GetSkillBonus`.

### Medical script bridge

Medical scripts rewrite health and max health on revive, respawn and hospital check-in, which
would silently drop the perks. `bridge/` holds one small client file per medical script that
calls `ReapplyStats()` after those moments. Every bridge guards on its resource being started,
so all of them ship enabled and only the matching one does anything:

| bridge | reapplies after |
| --- | --- |
| `bridge/qbx_medical.lua` | `qbx_medical:client:playerRevived` (full heal, 3 s settle) |
| `bridge/randol_medical.lua` | `randol_medical:onRevive`, `randol_medical:onCheckIn`, `randol_medical:client:onRespawn`, `randol_medical:client:revivePlayer` (full heal, 4 s settle), `randol_medical:onBedExit` (2 s settle), and the persisted health restore after character load (8 s settle) |

`ReapplyStats(fullHeal, settleMs)` takes two arguments. `fullHeal = true` also fills health up
to the boosted maximum: medical scripts heal to their own idea of "full" — 200 game units — so
without it a revived player with Thick Skin would stand up at 200/205 instead of full. Pass it
on revive, respawn and check-in; leave it off for anything that must keep the current health,
like randol_medical's persisted health restore on load. `settleMs` keeps reapplying every
500 ms for that long — medical scripts write health after their own fades and animations, at
times a bridge cannot know, so a single write would just get overwritten. A few seconds of
settling wins that race without any knowledge of the script's internals.

**Prefer keeping the hook in the medical script's own files?** `ReapplyStats` is also a client
export, so the same call can live in randol_medical's `cl_open.lua` instead of the bridge —
handy when you already keep every medical hook there. Delete `bridge/randol_medical.lua` if you
do, so the perks are not reapplied twice:

```lua
-- randol_medical/client/cl_open.lua
AddEventHandler('randol_medical:onRevive', function()
    exports.qbx_skills:ReapplyStats(true, 4000)
end)

AddEventHandler('randol_medical:onCheckIn', function()
    exports.qbx_skills:ReapplyStats(true, 4000)
end)

RegisterNetEvent('randol_medical:client:onRespawn', function()
    exports.qbx_skills:ReapplyStats(true, 4000)
end)
```

The timing is the same either way: `onRevive` fires before randol writes its health, which
is why the settle window stays. Only randol itself could remove the need for it, by healing
to `GetEntityMaxHealth(ped)` instead of 200.

#### Example: more health with randol_medical

Nothing is configured inside randol_medical. The extra health comes from the tree:

1. In the editor, give a skill a `max_health` bonus — the seeded Thick Skin carries `5`,
   Unbreakable `10`. Values are display hp, so `5` turns 100 hp into 105. `stats.healthCap`
   in `config/shared.lua` bounds what a full build can stack.
2. The moment the skill is unlocked, qbx_skills raises the ped's maximum (`SetEntityMaxHealth`
   to 205) and publishes `{ maxHealth = 205, ... }` on the `qbx_skills_stats` statebag. Nothing
   heals: the player keeps their current health and grows into the new room through normal
   healing. Losing the perk (switching tree) lowers the cap and clamps health to it.
3. randol_medical revives, respawns or checks the player in → it heals them to its own full
   (200) somewhere during its fade → `bridge/randol_medical.lua` runs `ReapplyStats(true, 4000)`,
   which keeps restoring the 205 maximum and filling health to it for four seconds, so
   whenever randol's write lands, the last word is 205/205. On relog, randol restores the
   player's persisted health and armour ~2 s after load; the bridge settles the maximum for
   8 s after load without touching the restored value.
4. randol's own thresholds are absolute game units and need no change — the knockout
   threshold (`Knockout.Health`) and `PostAdrenalineHealth` in its `shared.lua` simply sit
   further below a boosted player's maximum. Its heal items add fixed amounts, so they heal
   toward the boosted maximum automatically.

The same walk-through applies to `max_armour` (randol persists armour too) and, without any
medical involvement, to `stamina`.

**The cap you cannot see.** randol_medical's revive and check-in write health to a literal
200 inside its escrowed code — a revived player with a 215 maximum shows `200/215` until the
bridge fills them, which is exactly why the bridge treats revive and check-in as full heals.
No readable config controls it. Its heal items and EMS heals may carry the same constant:
test it once by using a bandage at `200/215` — if health rises above 200 randol clamps to
the ped's real maximum and every heal already benefits from the perk; if it stays at 200,
randol clamps at 200 and only revive/check-in reach the boosted value until the author swaps
the constant for `GetEntityMaxHealth(ped)`, a one-line change worth requesting. qbx_skills
never heals on its own: outside a bridge's short settle window after a heal event, no code
here writes health.

#### Example: an EMS tree on randol_medical's open handlers

randol_medical ships its integration points unencrypted in `client/cl_open.lua`,
`server/sv_open.lua` and `shared.lua`, and every one of them is a place qbx_skills can plug
into. The bridge already consumes `randol_medical:onRevive`, `onCheckIn`, `onBedExit`,
`client:onRespawn` and `client:revivePlayer` — adding your own handlers for the same events
alongside it is fine.

**Feed a job-locked EMS tree.** Create a tree in the editor, lock it to `ambulance`, and award
its experience from the two open payment hooks in `sv_open.lua`, which run once per treated
patient:

```lua
-- randol_medical/server/sv_open.lua
function PayForRevive(src)
    local player = GetPlayer(src)
    if not player then return end

    addMoney(player, 'bank', Server.PayPerRevive.amount)
    DoNotification(src, ('You received $%s for treating the patient.'):format(Server.PayPerRevive.amount))
    exports.qbx_skills:AddTreeXp(src, 'paramedic', 30)
end

function PayForHeal(src)
    -- existing body ...
    exports.qbx_skills:AddTreeXp(src, 'paramedic', 15)
end
```

`AddTreeXp` targets the tree by name, so it works whether or not the medic has it active;
use `AddXp(src, 30, 'ems')` instead if the tree's category should gate it like every other
activity.

**Read perks inside randol's open code.** Any of its open functions can consult the player's
skills. A discount on the automatic bill, server side:

```lua
-- randol_medical/server/sv_open.lua
function AutoBillPlayer(id, job)
    if not Server.AutoBill.enable then return end

    local player = GetPlayer(id)
    if not player then return end

    local amount = math.floor(Server.AutoBill.amount * (1 - exports.qbx_skills:GetSkillBonus(id, 'medical_discount')))
    RemoveMoney(player, 'bank', amount)
    -- society deposit as before, with `amount`
end
```

A shorter crutch walk after leaving the bed, client side:

```lua
-- randol_medical/client/cl_open.lua
AddEventHandler('randol_medical:onBedExit', function()
    if exports.qbx_skills:HasSkill('quick_recovery') then return end
    forceWalkEffect(1)
end)
```

An easier civilian revive minigame for a first-aid skill — `CivReviveMinigame` in
`shared.lua` only ever runs on the client, so the client export is safe there:

```lua
-- randol_medical/shared.lua
CivReviveMinigame = function()
    local trained = exports.qbx_skills:HasSkill('first_aid')
    return lib.skillCheck(trained and { 'easy', 'easy' } or { 'medium', 'medium', 'hard' })
end,
```

**Use the statebags as guards.** Activities should not pay experience to someone who is
down. Server side the states are replicated:

```lua
local state = Player(src).state
if state.dead or state.laststand then return end
exports.qbx_skills:AddXp(src, 15, 'crime')
```

Client side the same flags are `LocalPlayer.state.dead`, `.laststand`, `.knockedOut`,
`.isInHospitalBed` and the numeric `.bleeding`. The server hooks `randol_medical:server:death`,
`randol_medical:server:lastStand` (both `(src, state)`) and `randol_medical:server:onRespawn`
(`(src)`) fire when those states change, which is where a death penalty or a respawn log
belongs if you want one.

#### Example: another medical script

Copy `bridge/custom.lua`, put your resource name in the guard, and hook the events your
script fires when it heals, revives or respawns a player — the file is picked up automatically
by the `bridge/*.lua` glob in the manifest:

```lua
if GetResourceState('your_medical') ~= 'started' then return end

RegisterNetEvent('your_medical:client:revived', function()
    ReapplyStats(true, 3000)
end)
```

#### Example: healing against the real maximum

Any script that heals by fraction should read the boosted maximum instead of assuming 200.
Client side use the export, server side read the replicated statebag:

```lua
-- client: heal half of the missing health
local stats = exports.qbx_skills:GetStats()
local maxHealth = stats and stats.maxHealth or 200
SetEntityHealth(cache.ped, math.min(maxHealth, GetEntityHealth(cache.ped) + math.floor((maxHealth - 100) / 2)))

-- server: what "full" means for this player, e.g. inside a heal item or an EMS action
local stats = Player(src).state.qbx_skills_stats
local maxHealth = stats and stats.maxHealth or 200
```

Huds keep working the same way regardless of the medical script: read the `qbx_skills_stats`
statebag described above.

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
