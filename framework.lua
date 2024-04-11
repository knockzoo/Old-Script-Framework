-- very rushed, disorginazed, improperly tested and generally unrecommended to use if you can find a better alternative
-- nothing about the state of this code represents the state of my current code quality

local connections = {};
local framework = {};
local services = {};
local friended = {};
local teammate = {};
local spoof = {};
local rawlen = rawlen;
local rawset = rawset;
local rawget = rawget;
local pairs = pairs;
local checkcaller = checkcaller or function()
    return true
end;
local setmetatable = setmetatable;
local game = game;
local table = table;
local Vector2 = Vector2;
local Ray = Ray;
local math = math;
local TweenInfo = TweenInfo;
local Enum = Enum;
local wait = task.wait;
local spawn = task.spawn;
local type = type;
local assert = assert;
local getcallingscript = getcallingscript;

connections.__newindex = function(self, i, v)
    i = rawlen(self)
    rawset(self, i, v)
end
services.__index = function(self, i)
    local c = rawget(self, i)
    if rawget(self, i) then
        return c
    end

    local s = game:GetService(i)
    if s then
        self[i] = s
        return s
    end
end
framework.unload = function()
    for i, v in pairs(connections) do
        v:Disconnect()
    end

    table.clear(connections)
end

setmetatable(connections, connections)
setmetatable(services, services)

local players = services.Players
local workspace = services.Workspace
local tweenservice = services.TweenService
local userinputservice = services.UserInputService
local replicatedstorage = services.ReplicatedStorage

local raycast = workspace.Raycast
local camera = workspace.CurrentCamera

local localplayer = players.LocalPlayer
local mouse = localplayer:GetMouse()

local function characterfunc()
    return localplayer.Character or localplayer.CharacterAdded:Wait()
end
local character = characterfunc()

local function humanoidfunc()
    return character:FindFirstChild("Humanoid") or character:WaitForChild("Humanoid")
end
local humanoid = humanoidfunc()

for i, v in pairs(players:GetPlayers()) do
    if v ~= localplayer then
        local function friendswith()
            friended[v.Name] = v:IsFriendsWith(localplayer.UserId)
        end
        local function teamswith()
            teammate[v.Name] = v.Team == localplayer.Team
        end

        friendswith()
        teamswith()

        connections['.'] = v:GetPropertyChangedSignal("Team"):Connect(function()
            if not checkcaller() then
                return
            end

            teamswith()
        end)
    end
end

local function compare(received, expected)
    local t = {}
    for i, v in pairs(expected) do
        if received[i] == nil then
            t[i] = v
        else
            t[i] = received[i]
        end
    end

    return t
end

local remotes = {}
local hookremote = {
    remote = replicatedstorage:FindFirstChildOfClass("RemoteEvent"),
    callback = function(args, callingscript)
        for i, v in pairs(args) do
            print(i, v)
        end
    end,
    checkcaller = true
}

setmetatable(hookremote, {
    __call = function(self, args)
        assert(type(args) == 'table', 'expected table arg')
        compare(args, self)

        remotes[args.remote.Name] = args
    end
})

local oldnc
oldnc = hookmetamethod(game, "__namecall", function(self, ...)
    local method = getnamecallmethod()

    if self == localplayer and method == 'kick' or method == 'Kick' then
        return
    end

    for i, v in pairs(remotes) do
        if self == v.remote and method == 'FireServer' then
            if v.checkcaller and checkcaller() then
                return oldnc(self, ...)
            end

            local r = v.callback({...}, getcallingscript(), oldnc(self, ...))
            if r ~= nil then
                return r
            end
        end
    end

    return oldnc(self, ...)
end)

local function removeconnections(event)
    for i, v in pairs(getconnections(event)) do
        v:Disable()
    end
end

local spoofedvalues = {}
local spoof = {
    object = humanoid,
    property = 'WalkSpeed',
    value = 16
}

setmetatable(spoof, {
    __call = function(self, args)
        args = args or {}
        args = compare(args, self)

        local object = args.object
        local property = args.property
        local value = args.value

        spoofedvalues[object] = {property, value}
    end
})

local unspoof = {
    object = humanoid,
    property = 'WalkSpeed'
}

setmetatable(unspoof, {
    __call = function(self, args)
        args = args or {}
        args = compare(args, self)

        local object = args.object
        local property = args.property

        spoofedvalues[object] = nil
    end
})

local oldin
oldin = hookmetamethod(game, "__index", function(self, key)
    for i, v in pairs(spoofedvalues) do
        if i == self and v[1] == key then
            return v[2]
        end
    end

    return oldin(self, key)
end)

local disablechanged = {
    object = humanoid,
    property = 'WalkSpeed'
}

disablechanged = setmetatable(disablechanged, {
    __call = function(self, args)
        args = args or {}
        args = compare(args, self)

        local object = args.object
        local property = args.property

        removeconnections(object:GetPropertyChangedSignal(property))
    end
})

local function clearconnections()
    removeconnections(character.HumanoidRootPart.Changed)
    removeconnections(humanoid.Changed)
    removeconnections(workspace.Changed)
    removeconnections(game.DescendantAdded)
    removeconnections(character.HumanoidRootPart.ChildAdded)
    removeconnections(humanoid.StateChanged)
end

local closest = {
    search = players,
    friendcheck = false,
    teamcheck = false,
    wallcheck = false,
    method = 'character',
    customchecks = {}
}

setmetatable(closest, {
    __call = function(self, args)
        args = args or {}
        args = compare(args, self)

        local teamcheck = args.teamcheck
        local friendcheck = args.friendcheck
        local wallcheck = args.wallcheck
        local customchecks = args.customchecks
        local method = args.method

        local c, l = nil, math.huge
        for i, v in pairs(args.search:GetChildren()) do
            if v ~= localplayer and v.Character then
                local cancontinue = true
                cancontinue = (friendcheck and friended[v.Name] == false) or true

                if cancontinue then
                    cancontinue = (teamcheck and teammate[v.Name] == false) or true
                end

                if cancontinue then
                    cancontinue = (wallcheck and
                                      workspace:Raycast(
                            Ray.new(character.PrimaryPart.Position, v.Character.PrimaryPart.Position)) == nil) or true
                end

                if cancontinue then
                    for _, test in pairs(customchecks) do
                        if cancontinue then
                            cancontinue = test(v)
                        end
                    end
                end

                if cancontinue then
                    if method == 'character' then
                        local mag = (v.Character.PrimaryPart.Position - character.PrimaryPart.Position).magnitude

                        if mag < l then
                            c = v
                            l = mag
                        end
                    elseif method == 'cursor' or method == 'mouse' then
                        local pos, iv = camera:WorldToViewportPoint(v.Character.PrimaryPart.Position)
                        local mousepos = Vector2.new(mouse.X, mouse.Y + 36)
                        pos = Vector2.new(pos.X, pos.Y)

                        local mag = (pos - mousepos).magnitude
                        if mag < l and iv then
                            l = mag
                            c = v
                        end
                    end
                end
            end
        end

        return c
    end
})

local furthest = {
    search = players,
    friendcheck = false,
    teamcheck = false,
    wallcheck = false,
    method = 'character',
    customchecks = {}
}

setmetatable(furthest, {
    __call = function(self, args)
        args = args or {}
        args = compare(args, self)

        local teamcheck = args.teamcheck
        local friendcheck = args.friendcheck
        local wallcheck = args.wallcheck
        local customchecks = args.customchecks
        local method = args.method

        local f, l = nil, 0
        for i, v in pairs(args.search:GetChildren()) do
            if v ~= localplayer and v.Character then
                local cancontinue = true
                cancontinue = (friendcheck and friended[v.Name] == false) or true

                if cancontinue then
                    cancontinue = (teamcheck and teammate[v.Name] == false) or true
                end

                if cancontinue then
                    cancontinue = (wallcheck and
                                      workspace:Raycast(
                            Ray.new(character.PrimaryPart.Position, v.Character.PrimaryPart.Position)) == nil) or true
                end

                if cancontinue then
                    for _, test in pairs(customchecks) do
                        if cancontinue then
                            cancontinue = test(v)
                        end
                    end
                end

                if cancontinue then
                    if method == 'character' then
                        local mag = (v.Character.PrimaryPart.Position - character.PrimaryPart.Position).magnitude

                        if mag > l then
                            f = v
                            l = mag
                        end
                    elseif method == 'cursor' or method == 'mouse' then
                        local pos, iv = camera:WorldToViewportPoint(v.Character.PrimaryPart.Position)
                        local mousepos = Vector2.new(mouse.X, mouse.Y + 36)
                        pos = Vector2.new(pos.X, pos.Y)

                        local mag = (pos - mousepos).magnitude
                        if mag > l and iv then
                            l = mag
                            f = v
                        end
                    end
                end
            end
        end

        return f
    end
})

local tweencframe = {
    part = character:FindFirstChild("HumanoidRootPart") or character:WaitForChild("HumanoidRootPart"),
    cframe = character.PrimaryPart.CFrame,
    speed = 1,
    gravitychange = false
}

local oldgravity = workspace.Gravity
setmetatable(tweencframe, {
    __call = function(self, args)
        args = args or {}
        args = compare(args, self)

        local part = args.part
        local cframe = args.cframe
        local speed = args.speed
        local changegravity = args.changegravity

        local tween = tweenservice:Create(part, TweenInfo.new(speed), {
            CFrame = cframe
        })

        if changegravity then
            workspace.Gravity = 0.1
            connections['.'] = tween.Completed:Connect(function()
                if not checkcaller() then
                    return
                end

                workspace.Gravity = oldgravity
            end)
        end

        tween:Play()
        return tween
    end
})

local keybind = {
    callback = function()
        print('hi')
    end,
    keycode = 'E',
    hold = true,
    updatedelay = 1
}

setmetatable(keybind, {
    __call = function(self, args)
        args = args or {}
        args = compare(args, self)

        local keycode = Enum.KeyCode[args.keycode:upper()]
        local callback = args.callback
        local hold = args.hold
        local updatedelay = args.updatedelay

        local down = false

        if hold == false then
            local toggle = false

            local event
            event = userinputservice.InputBegan:Connect(function(input, processed)
                if not processed and input.KeyCode == keycode then
                    toggle = not toggle
                    callback(toggle)
                end
            end)

            connections['.'] = event
            return event
        else
            local event
            event = userinputservice.InputBegan:Connect(function(input, processed)
                if not processed and input.KeyCode == keycode and not down then
                    down = true

                    spawn(function()
                        while down do
                            if down then
                                callback(event)
                                wait(updatedelay)
                            else
                                break
                            end
                        end
                    end)
                end
            end)

            connections['.'] = event
            connections['.'] = userinputservice.InputEnded:Connect(function(input)
                if input.KeyCode == keycode and down then
                    down = false
                end
            end)

            return event
        end
    end
})

local function antidetection()
    clearconnections()

    spoof({
        object = humanoid,
        property = 'JumpPower',
        value = humanoid.JumpPower
    })
    disablechanged({
        object = humanoid,
        property = 'JumpPower'
    })

    spoof({
        object = humanoid,
        property = 'WalkSpeed',
        value = humanoid.WalkSpeed
    })
    disablechanged({
        object = humanoid,
        property = 'WalkSpeed'
    })
end

antidetection()

connections['.'] = localplayer.CharacterAdded:Connect(function()
    if not checkcaller() then
        return
    end

    character = characterfunc()
    humanoid = humanoidfunc()
    antidetection()
end)
