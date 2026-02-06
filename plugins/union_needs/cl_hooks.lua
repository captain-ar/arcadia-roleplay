local PLUGIN = PLUGIN

net.Receive("ixUnionNeedsNotice", function()
    local noticeType = net.ReadUInt(3)
    local message = net.ReadString()

    notification.AddLegacy(message, noticeType, 3)
    surface.PlaySound("buttons/button15.wav")
end)

function PLUGIN:InitializedStatusBars()
    ix.bar.Add(function()
        local client = LocalPlayer()
        local character = client:GetCharacter()

        if (not character) then
            return false
        end

        local value = client:GetLocalVar("satiety", PLUGIN.maxNeed)
        return value / PLUGIN.maxNeed, Color(212, 173, 104), "SATIETY"
    end, 50, "ixSatiety")

    ix.bar.Add(function()
        local client = LocalPlayer()
        local character = client:GetCharacter()

        if (not character) then
            return false
        end

        local value = client:GetLocalVar("saturation", PLUGIN.maxNeed)
        return value / PLUGIN.maxNeed, Color(104, 176, 212), "SATURATION"
    end, 49, "ixSaturation")
end

function PLUGIN:CharacterLoaded(character)
    local client = LocalPlayer()

    if (character == client:GetCharacter()) then
        client:SetLocalVar("satiety", character:GetData("satiety", PLUGIN.maxNeed))
        client:SetLocalVar("saturation", character:GetData("saturation", PLUGIN.maxNeed))
        client._ixNeedsHint = nil
    end
end

function PLUGIN:Think()
    local client = LocalPlayer()
    local character = client:GetCharacter()

    if (not character) then
        return
    end

    if (not client._ixNeedsHint or client._ixNeedsHint < CurTime()) then
        local satiety = client:GetLocalVar("satiety", PLUGIN.maxNeed)
        local saturation = client:GetLocalVar("saturation", PLUGIN.maxNeed)

        if (satiety <= 15) then
            surface.PlaySound("npc/headcrab_poison/ph_warning2.wav")
            client._ixNeedsHint = CurTime() + 20
        elseif (saturation <= 15) then
            surface.PlaySound("ambient/water/drip1.wav")
            client._ixNeedsHint = CurTime() + 20
        end
    end
end
