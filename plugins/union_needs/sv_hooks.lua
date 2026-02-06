local PLUGIN = PLUGIN

function PLUGIN:InitializeNeedTimers()
    if (timer.Exists("ixUnionNeedsTick")) then
        timer.Remove("ixUnionNeedsTick")
    end

    local interval = math.max(ix.config.Get("unionNeedsTickInterval", 180), 10)

    timer.Create("ixUnionNeedsTick", interval, 0, function()
        self:ProcessNeedTick()
    end)
end

function PLUGIN:ProcessNeedTick()
    for _, client in ipairs(player.GetHumans()) do
        if (not IsValid(client) or not client:Alive()) then
            continue
        end

        if (client:GetMoveType() == MOVETYPE_NOCLIP) then
            continue
        end

        local character = client:GetCharacter()

        if (not character) then
            continue
        end

        local satietyLoss = ix.config.Get("unionNeedsSatietyLoss", 2)
        local saturationLoss = ix.config.Get("unionNeedsSaturationLoss", 3)

        local velocity = client:GetVelocity():Length2D()

        if (velocity > 150) then
            satietyLoss = satietyLoss + 1
            saturationLoss = saturationLoss + 1.5
        elseif (velocity < 10) then
            satietyLoss = math.max(satietyLoss - 0.5, 0)
            saturationLoss = math.max(saturationLoss - 0.5, 0)
        end

        if (client:IsOnFire()) then
            saturationLoss = saturationLoss + 2
        end

        self:AdjustNeed(client, "satiety", -satietyLoss)
        self:AdjustNeed(client, "saturation", -saturationLoss)

        self:EvaluateNeedState(client)
    end
end

function PLUGIN:EvaluateNeedState(client)
    local satiety = self:GetNeed(client, "satiety")
    local saturation = self:GetNeed(client, "saturation")
    local threshold = ix.config.Get("unionNeedsWarningThreshold", 30)

    client._ixUnionNeedsWarnings = client._ixUnionNeedsWarnings or {}

    if (satiety <= threshold) then
        self:NeedsWarning(client, "satiety", satiety <= 0 and "You are starving!" or "Your stomach growls. You need to eat soon.")
    end

    if (saturation <= threshold) then
        self:NeedsWarning(client, "saturation", saturation <= 0 and "You are dehydrated!" or "Your mouth feels dry. Find something to drink.")
    end

    if (satiety <= 0 or saturation <= 0) then
        self:HandleStarvation(client)
    end
end

function PLUGIN:NeedsWarning(client, channel, message)
    local now = CurTime()
    local cooldown = 45

    if (client._ixUnionNeedsWarnings[channel] and client._ixUnionNeedsWarnings[channel] > now) then
        return
    end

    client._ixUnionNeedsWarnings[channel] = now + cooldown
    self:NeedsNotice(client, message, 1)
end

function PLUGIN:HandleStarvation(client)
    client._ixUnionNeedsStarve = client._ixUnionNeedsStarve or 0

    if (client._ixUnionNeedsStarve > CurTime()) then
        return
    end

    client._ixUnionNeedsStarve = CurTime() + 10

    local damage = ix.config.Get("unionNeedsStarvationDamage", 5)

    if (damage > 0) then
        local attacker = game.GetWorld()
        client:TakeDamage(damage, attacker, attacker)
    end
end

function PLUGIN:PlayerLoadedCharacter(client, character)
    self:SetNeed(client, "satiety", character:GetData("satiety", self.maxNeed))
    self:SetNeed(client, "saturation", character:GetData("saturation", self.maxNeed))

    client._ixUnionNeedsWarnings = {}
    client._ixUnionNeedsStarve = 0
end

function PLUGIN:OnCharacterCreated(client, character)
    character:SetData("satiety", self.maxNeed)
    character:SetData("saturation", self.maxNeed)
end

function PLUGIN:PlayerDisconnected(client)
    client._ixUnionNeedsWarnings = nil
    client._ixUnionNeedsStarve = nil
end

function PLUGIN:PlayerSpawn(client)
    if (not IsValid(client)) then
        return
    end

    local character = client:GetCharacter()

    if (character) then
        self:SetNeed(client, "satiety", character:GetData("satiety", self.maxNeed))
        self:SetNeed(client, "saturation", character:GetData("saturation", self.maxNeed))
    end
end

function PLUGIN:ShutDown()
    if (timer.Exists("ixUnionNeedsTick")) then
        timer.Remove("ixUnionNeedsTick")
    end
end

function PLUGIN:OnConfigChanged(key, oldValue, newValue)
    if (key == "unionNeedsTickInterval") then
        self:InitializeNeedTimers()
    end
end

ix.command.Add("CharSetNeeds", {
    description = "Forcefully set a character's satiety and saturation.",
    adminOnly = true,
    arguments = {ix.type.character, ix.type.number, ix.type.number},
    OnRun = function(self, client, target, satiety, saturation)
        local satietyValue = math.Clamp(satiety, 0, PLUGIN.maxNeed)
        local saturationValue = math.Clamp(saturation, 0, PLUGIN.maxNeed)
        local player = target:GetPlayer()

        if (IsValid(player)) then
            PLUGIN:SetNeed(player, "satiety", satietyValue)
            PLUGIN:SetNeed(player, "saturation", saturationValue)

            PLUGIN:NeedsNotice(player, string.format("Your needs were adjusted by %s.", client:Name()), 1)
        else
            target:SetData("satiety", satietyValue)
            target:SetData("saturation", saturationValue)
        end

        client:Notify(string.format("Adjusted needs for %s.", target:GetName()))
    end
})
