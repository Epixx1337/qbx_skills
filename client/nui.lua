local open = false

---@param action string
---@param data any
function SendUI(action, data)
    SendNUIMessage({ action = action, data = data })
end

---@return boolean
function IsUIOpen()
    return open
end

function OpenUI()
    open = true
    SendUI('theme', { color = GetConvar('ox:primaryColor', 'blue'), shade = GetConvarInt('ox:primaryShade', 8) })
    SendUI('setVisible', true)
    SetNuiFocus(true, true)
end

function CloseUI()
    open = false
    SendUI('setVisible', false)
    SetNuiFocus(false, false)
end

RegisterNUICallback('close', function(_, cb)
    cb(1)
    CloseUI()
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end
    SetNuiFocus(false, false)
end)
