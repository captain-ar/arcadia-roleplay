local PLUGIN = PLUGIN

PLUGIN.maxNeed = 100

function PLUGIN:GetNeed(client, key)
    local character = client.GetCharacter and client:GetCharacter()

    if (character) then
        return character:GetData(key, self.maxNeed)
    end

    return self.maxNeed
end

function PLUGIN:SetNeed(client, key, value)
    local character = client.GetCharacter and client:GetCharacter()

    if (not character) then
        return
    end

    value = math.Clamp(math.Round(value, 2), 0, self.maxNeed)

    character:SetData(key, value)
    client:SetLocalVar(key, value)
end

function PLUGIN:AdjustNeed(client, key, delta)
    local value = self:GetNeed(client, key)

    self:SetNeed(client, key, value + delta)
end

local function BuildActionText(item, satiety, saturation)
    local itemName = string.lower(item.name or "ration")

    if (saturation > satiety) then
        return string.format("takes a drink from their %s.", itemName)
    elseif (satiety > 0) then
        return string.format("takes a bite of their %s.", itemName)
    end

    return string.format("consumes their %s.", itemName)
end

function PLUGIN:HandleConsumption(client, item)
    local satiety = item.RestoreSatiety or 0
    local saturation = item.RestoreSaturation or 0

    if (satiety ~= 0) then
        self:AdjustNeed(client, "satiety", satiety)
    end

    if (saturation ~= 0) then
        self:AdjustNeed(client, "saturation", saturation)
    end

    if (item.useSound) then
        client:EmitSound(item.useSound)
    end

    ix.chat.Send(client, "me", BuildActionText(item, satiety, saturation))

    local servings = item:GetData("servings", item.RemainingDefault or 1) - 1

    if (servings > 0) then
        self:NeedsNotice(client, string.format("Satiety %+d | Saturation %+d (%d servings left)", satiety, saturation, servings), 0)
    else
        self:NeedsNotice(client, string.format("Satiety %+d | Saturation %+d", satiety, saturation), 0)
    end
end

function PLUGIN:NeedsNotice(client, message, noticeType)
    noticeType = noticeType or 0

    if (SERVER) then
        net.Start("ixUnionNeedsNotice")
            net.WriteUInt(noticeType, 3)
            net.WriteString(message)
        net.Send(client)
    else
        notification.AddLegacy(message, noticeType, 3)
        surface.PlaySound("buttons/button15.wav")
    end
end
