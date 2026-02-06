local PLUGIN = PLUGIN

PLUGIN.name = "Union Nutritional Needs"
PLUGIN.author = "Arcadia Roleplay"
PLUGIN.description = "Adds a persistent hunger and hydration loop for UU-branded provisions."

ix.util.Include("sh_utils.lua")
ix.util.Include("sv_hooks.lua")
ix.util.Include("cl_hooks.lua")

if (SERVER) then
    util.AddNetworkString("ixUnionNeedsNotice")
end

ix.config.Add("unionNeedsTickInterval", 180, "How often (in seconds) the characters lose satiety and saturation.", nil, {
    data = {min = 30, max = 600},
    category = "Union Needs"
})

ix.config.Add("unionNeedsSatietyLoss", 2, "How much satiety is lost every tick.", nil, {
    data = {min = 0, max = 10},
    category = "Union Needs"
})

ix.config.Add("unionNeedsSaturationLoss", 3, "How much saturation is lost every tick.", nil, {
    data = {min = 0, max = 10},
    category = "Union Needs"
})

ix.config.Add("unionNeedsStarvationDamage", 5, "Damage applied whenever a starving character reaches a tick.", nil, {
    data = {min = 0, max = 15},
    category = "Union Needs"
})

ix.config.Add("unionNeedsWarningThreshold", 30, "Threshold that triggers hunger and thirst warnings.", nil, {
    data = {min = 5, max = 80},
    category = "Union Needs"
})

function PLUGIN:InitializedPlugins()
    if (SERVER) then
        self:InitializeNeedTimers()
    end

    self:SetupConsumableItems()
end

function PLUGIN:OnItemRegistered(itemTable)
    self:SetupConsumableItem(itemTable)
end

function PLUGIN:SetupConsumableItems()
    for _, itemTable in pairs(ix.item.list) do
        self:SetupConsumableItem(itemTable)
    end
end

function PLUGIN:SetupConsumableItem(itemTable)
    if (not itemTable or itemTable.__unionNeedsSetup) then
        return
    end

    if (not itemTable.RestoreSatiety and not itemTable.RestoreSaturation) then
        return
    end

    itemTable.__unionNeedsSetup = true
    itemTable.RestoreSatiety = itemTable.RestoreSatiety or 0
    itemTable.RestoreSaturation = itemTable.RestoreSaturation or 0
    itemTable.RemainingDefault = itemTable.RemainingDefault or 1
    itemTable.useSound = itemTable.useSound or "npc/barnacle/barnacle_crunch2.wav"
    itemTable.category = itemTable.category or "UU-Branded Provisions"

    local originalDescription = itemTable.GetDescription
    function itemTable:GetDescription()
        local description = originalDescription and originalDescription(self) or self.description or ""
        description = description:gsub("\n+$", "")

        local info = {}

        if ((self.RestoreSatiety or 0) > 0) then
            info[#info + 1] = string.format("Satiety: +%s", self.RestoreSatiety)
        end

        if ((self.RestoreSaturation or 0) > 0) then
            info[#info + 1] = string.format("Saturation: +%s", self.RestoreSaturation)
        end

        local servings = self:GetData("servings", self.RemainingDefault or 1)
        if ((self.RemainingDefault or 1) > 1 or servings > 1) then
            info[#info + 1] = string.format("Servings Remaining: %s", servings)
        end

        if (#info > 0) then
            description = description .. "\n\n" .. table.concat(info, "\n")
        end

        return description
    end

    itemTable.functions = itemTable.functions or {}

    local function OnConsume(item)
        local client = item.player
        if (not IsValid(client)) then
            return false
        end

        local plugin = ix.plugin.list and ix.plugin.list["union_needs"]
        if (plugin) then
            plugin:HandleConsumption(client, item)
        end

        local servings = item:GetData("servings", item.RemainingDefault or 1)
        servings = math.max(servings - 1, 0)

        if (servings > 0) then
            item:SetData("servings", servings)
            return false
        else
            return true
        end
    end

    local function CanConsume(item)
        return not IsValid(item.entity)
    end

    local actionName
    local actionIcon
    if ((itemTable.RestoreSaturation or 0) > (itemTable.RestoreSatiety or 0)) then
        actionName = "Drink"
        actionIcon = "icon16/cup.png"
    elseif ((itemTable.RestoreSatiety or 0) > 0) then
        actionName = "Eat"
        actionIcon = "icon16/cake.png"
    else
        actionName = "Consume"
        actionIcon = "icon16/pill.png"
    end

    itemTable.functions.Consume = {
        name = actionName,
        icon = actionIcon,
        OnRun = OnConsume,
        OnCanRun = CanConsume
    }

    if (itemTable.RationContents and itemTable.functions.Open == nil) then
        itemTable.openSound = itemTable.openSound or "items/ammocrate_open.wav"

        local function OpenRation(item)
            local client = item.player
            if (not IsValid(client)) then
                return false
            end

            local character = client:GetCharacter()
            if (not character) then
                return false
            end

            local inventory = character:GetInventory()
            if (not inventory) then
                return false
            end

            local contents = item.RationContents or {}
            for _, entry in ipairs(contents) do
                local uniqueID = entry[1]
                local amount = entry[2] or 1

                if (inventory.CanAdd and not inventory:CanAdd(uniqueID, amount)) then
                    client:Notify("You do not have enough inventory space to open this ration.")
                    return false
                end
            end

            for _, entry in ipairs(contents) do
                local uniqueID = entry[1]
                local amount = entry[2] or 1
                local data = entry[3]

                local added = inventory:Add(uniqueID, amount, data)
                if (not added) then
                    client:Notify("Unable to add ration contents to your inventory.")
                    return false
                end
            end

            if (item.openSound) then
                client:EmitSound(item.openSound)
            end

            ix.chat.Send(client, "me", string.format("opens their %s.", string.lower(item.name or "ration")))
            return true
        end

        itemTable.functions.Open = {
            name = "Open",
            icon = "icon16/box.png",
            OnRun = OpenRation,
            OnCanRun = CanConsume
        }
    end
end
