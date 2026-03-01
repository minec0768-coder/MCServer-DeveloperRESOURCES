local library = require(game.ReplicatedStorage:WaitForChild("Library"))
while not library.Loaded do wait() end

local rs, ps, ts, uis, cas, rs_, cs = game:GetService("ReplicatedStorage"), game:GetService("Players"), game:GetService("TweenService"), game:GetService("UserInputService"), game:GetService("ContextActionService"), game:GetService("RunService"), game:GetService("CollectionService")
local debris, camera = workspace:WaitForChild("Debris"), workspace.CurrentCamera
local player, backpack = library.LocalPlayer, player:WaitForChild("Backpack")
local char, hrp, hum, animator = library.Character, char:WaitForChild("HumanoidRootPart"), char:WaitForChild("Humanoid"), hum:WaitForChild("Animator")
local remotes, assets, anims, charAnims = rs.Remotes, rs:WaitForChild("Assets"), assets:WaitForChild("Animations"), anims:WaitForChild("Character")

local util, spr, debug, off, weapH, projH, maid, vfx, animG, sig = library.Utility, util.Spring, library.Debug, library.Offset, library.WeaponsHandler, library.ProjectilesHandler, util.Maid, library.VFX, library.AnimationGroup, util.Signal
local mous, mov, vm, aimOff, recoil, scopeP, crosshair, guiMod = library.Mouse, library.MovementHandler, library.ViewmodelHandler, library.GetWeaponAimOffset, library.RecoilHandler, library.ScopeParallax, library.CrosshairHandler, require(player.PlayerGui:WaitForChild("GuiModule"))
local mouse = mous:GetMouse()
mouse.TargetFilter = {char, camera}

local hud, mf, chs, comHud, eqWepF, ammoF, ammoB, magA, resA = player.PlayerGui:WaitForChild("MainHud"), hud:WaitForChild("Main"), hud:WaitForChild("Crosshairs"), mf:WaitForChild("CombatHud"), comHud:WaitForChild("EquippedWeapon"), eqWepF:WaitForChild("Ammo"), ammoF:WaitForChild("Bar"), ammoB:WaitForChild("MagazineAmmo"), ammoB:WaitForChild("ReserveAmmo")
local plrHud, charDisp, pickupTxt, uiSpr = mf:WaitForChild("PlayerHud"), plrHud:WaitForChild("CharacterDisplay"), mf:WaitForChild("PickupWeapon"), spr.new(Vector3.new(0,0,0),0.35,14)

local maid, eqWepMaid = maid.new(), nil
local vmObj = vm.CreateViewmodel("Default")
vm:SetCurrentViewmodel(vmObj)
vm:PreloadWeapons()
vm:Disable()

local camOffs = off.CreateOffsetGroup("CameraOffsets")
camOffs:AddOffset("CameraAnimation",nil,nil,false)
camOffs:AddOffset("WalkSway",nil,nil,false)
camOffs:AddOffset("Slide",nil,nil,false)
camOffs:AddOffset("Jump",nil,nil,false)
camOffs:AddOffset("DamageFlinch",nil,nil,false)

local camSP, camSTilt, camSR, camJS, camFS, camWS, camWSP = spr.new(Vector3.zero,0.7,10), spr.new(Vector3.zero,0.8,10), spr.new(Vector3.zero,0.55,8), spr.new(Vector3.zero,0.6,9), spr.new(Vector3.zero,0.85,20), spr.new(Vector3.zero,0.6,10), spr.new(Vector3.zero,0.7,13)
local camACF, CAngles, camOldCF = CFrame.new(), nil, CFrame.new()
local curHoverWep, wepHoverChg = nil, sig.new()

local function LoadCharDisp()
	charDisp.WorldModel:ClearAllChildren()
	char.Archivable = true
	local clone = char:Clone()
	task.spawn(function() clone:WaitForChild("Animate"):Destroy() end)
	clone.Parent = charDisp.WorldModel
	clone:PivotTo(CFrame.new())
	local cam = Instance.new("Camera",charDisp.WorldModel)
	charDisp.CurrentCamera = cam
	local offset = CFrame.new(3, 0, -3) * CFrame.Angles(math.rad(20),math.rad(140),math.rad(0))
	cam.FieldOfView = 60
	cam.CFrame = CFrame.lookAt(clone.PrimaryPart.Position,clone.PrimaryPart.CFrame.LookVector*999)
	clone.PrimaryPart.CFrame *= CFrame.new(0.1,-1.65,-3) * CFrame.Angles(math.rad(-25),math.rad(210),0)
end

local function NewWep(wepTool) weapH.NewWeapon(wepTool) end

local function WepEq(wep)
	eqWepF.Visible = true
	eqWepMaid = maid.new()
	if wep.WeaponInfo.WeaponType[1] == "Gun" then
		guiMod.BindTextToValue(magA,wep.WeaponTool.Ammo)
		guiMod.BindTextToValue(resA,wep.WeaponTool.ReserveAmmo)
		local ammoBTwn
		eqWepMaid:GiveTask(wep.AmmoChanged:Connect(function(ammo)
			if ammoBTwn then ammoBTwn:Pause() end
			ammoBTwn = ts:Create(ammoB,TweenInfo.new(0.07),{Size = UDim2.new(ammo/wep.WeaponInfo.MagSize,0,1,0)})
			ammoBTwn:Play()
		end))
	end
end

local function WepUnEq(wep)
	if eqWepMaid then eqWepMaid:Destroy() end
	eqWepF.Visible = false
	guiMod.UnbindTextToValue(magA)
	guiMod.UnbindTextToValue(resA)
end

local function HStateCh(old,new)
	local dt = rs_:RenderStepped:Wait()
	if new == Enum.HumanoidStateType.Jumping then
		camJS:Impulse(Vector3.new(-25,0,0))
		uiSpr:Impulse(Vector3.new(0,-4,2*math.random(-100,100)/100) * dt * 60)
	end
	if new == Enum.HumanoidStateType.Freefall then
		local startT = tick()
		local fallT = 0
		local seedY, seedZ = (math.random(-10e6,10e6)/10e6) * 0.99, (math.random(-10e6,10e6)/10e6) * 0.99
		while hum:GetState() == Enum.HumanoidStateType.Freefall do
			local dt = rs_:RenderStepped:Wait()
			fallT = tick()-startT
			camJS:Impulse(Vector3.new(1,0,0) * (1+fallT) * 0.3 * dt * 60)
			camJS:Impulse(Vector3.new(0,0,1) * 50 * fallT * math.noise(fallT^2*5) * 2 * dt * 60)
			uiSpr:Impulse(Vector3.new(0,-0.3 * fallT,0.7* math.noise(fallT^2*8)) * dt * 60)
		end
		local maxFT = 1
		local fallTMult = math.clamp(fallT,0,maxFT)/maxFT
		camJS:Impulse(Vector3.new(-20,0,-20) * fallTMult^2 * 3 * dt * 60)
		uiSpr:Impulse(Vector3.new(0,14 * fallTMult,2*math.random(-100,100)/100) * fallTMult * dt * 60)
	end
end

local function MoveDirCh()
	if hum.MoveDirection.Magnitude > 0 then
		if mov:CanSprint() then
			if weapH.EquippedWeapon and weapH.EquippedWeapon.WeaponInfo.ADS then
				if weapH.EquippedWeapon:IsAiming() then return end
			end
			if mov:IsSliding() then return end
		else mov:ToggleSprint(false) end
	else if mov:IsSprinting() then mov:ToggleSprint(false) end end
end

local function InBegan(inp,gpe)
	if gpe then return end
	if inp.KeyCode == Enum.KeyCode.Y then
		if not util.IsStudio() then return end
		print(vmObj.Object.HumanoidRootPart.CFrame:Inverse() * weapH.EquippedWeapon.ViewmodelWeapon.Object.AimPart.CFrame)
	end
	if inp.KeyCode == Enum.KeyCode.I then
		if not util.IsStudio() then return end
		local x = Instance.new("Part",workspace) x.Name = "REEEEEE" x.Anchored = true x.Size = Vector3.one * 0.2 x.CanCollide = false x.CFrame = workspace.CurrentCamera.CFrame
	end
end

local function InEnd(inp,gpe) end

local function OnSprint(spr)
	if spr then else end
end

local function OnSlide(sld)
	if sld then
		camSP:Impulse(Vector3.new(0,0,-10))
		camSP.Target = Vector3.new(0,-0.5,0)
		local moveDir = mov:GetRelativeMoveDirection()
		camSR:Impulse(Vector3.new(10,0,0))
		camSTilt.Target = Vector3.new(0,0,0) + Vector3.new(0,0,moveDir.X * -6)
	else
		camSP.Target = Vector3.new(0,0,0)
		camSR.Target = Vector3.new(0,0,0)
		camSTilt.Target = Vector3.zero
	end
end

local t = 0
local function RStep(dt)
	if hum.Health <= 0 then return end
	local wep = weapH.GetEquippedWeapon()
	t += dt
	local spd = 6
	local mult = 0.5
	mult *= ((mov:IsSprinting() and 3) or 1)
	spd *= ((mov:IsSprinting() and 1.5) or 1)
	if wep then if wep.WeaponInfo.WeaponType[1] == "Gun" then mult *= math.clamp(1+(0.7)-wep.AimAlpha.Value,0,1) end end
	mult *= (mov:IsGrounded() and 1) or 0
	local x = (math.sin(t * spd )^2 - 0.5)  * 0.01
	local y = math.cos(t * spd)^2 *0.05
	y = 0
	local z = math.cos(t * spd) * 0.3
	camWS:Impulse(Vector3.new(x,y,z) * mult * ((mov:IsMoving() and 1) or 0) * 60 * dt * 20)
	camWSP:Impulse(Vector3.new(0,-math.cos(2*t*spd)/2 - 0.5,0) * 3.5 * mult * ((mov:IsMoving() and 1) or 0) * 60 * dt)
	uiSpr:Impulse(Vector3.new(x,y,z) * dt * 60 * 1.5 * mult * ((mov:IsMoving() and 1) or 0))
	local camWRot = util.RadVector3(camWS:GetDelta())
	camOffs:SetOffset("WalkSway",CFrame.new(camWSP:GetDelta().X,camWSP:GetDelta().Y,camWSP:GetDelta().Z)* CFrame.Angles(camWRot.X,camWRot.Y,camWRot.Z))
	camOffs:SetOffset("Slide",CFrame.new(camSP.Position.X,camSP.Position.Y,camSP.Position.Z) * CFrame.Angles(math.rad(camSR:GetDelta().X),math.rad(camSR:GetDelta().Y),math.rad(camSR:GetDelta().Z)) * CFrame.Angles(math.rad(camSTilt.Position.X),math.rad(camSTilt.Position.Y),math.rad(camSTilt.Position.Z)))
	camOffs:SetOffset("Jump",CFrame.Angles(math.rad(camJS:GetDelta(dt).X),math.rad(camJS:GetDelta(dt).Y),math.rad(camJS:GetDelta(dt).Z)))
	camOffs:SetOffset("DamageFlinch",CFrame.Angles(math.rad(camFS:GetDelta().X),math.rad(camFS:GetDelta().Y),math.rad(camFS:GetDelta().Z)))
	local newCamCF = vmObj.Object.CameraPart.CFrame:ToObjectSpace(vmObj.Object.PrimaryPart.CFrame)
	if camOldCF then
		local _,_,z = newCamCF:ToOrientation()
		local x,y,_ = newCamCF:ToObjectSpace(camOldCF):ToEulerAnglesXYZ()
		local camOff = CFrame.Angles(x,y, -z)
		CAngles = CFrame.fromEulerAnglesXYZ((vmObj.Object.CameraPart.CFrame * vmObj.Object.PrimaryPart.CFrame:Inverse()):ToEulerAnglesXYZ()) or CFrame.new()
		camACF = camACF:Lerp(camOff,0.93)
		camOffs:SetOffset("CameraAnimation",camACF)
	end
	camOldCF = newCamCF
	camOffs:ApplyOffsets(camera)
	camOffs:UpdateOffsets()
	local hoverWep = nil
	if mouse.Target then
		for i,v in pairs(game.CollectionService:GetTagged("Weapon")) do
			if mouse.Target:IsDescendantOf(v) then
				if (v.Weapon.Handle.Position - hrp.Position).Magnitude <= weapH.WeaponPickupRange then
					hoverWep = v
					local pos = camera:WorldToViewportPoint(v.Weapon.Handle.Position)
					pickupTxt.Position = UDim2.fromOffset(pos.X,pos.Y)
				end
				break
			end
		end
	end
	if hoverWep ~= curHoverWep then wepHoverChg:Fire(hoverWep) end
	curHoverWep = hoverWep
	local delta = uis:GetMouseDelta()
	uiSpr:Impulse(Vector3.new(-delta.X * 0.5,-delta.Y*1.1 + math.abs(delta.X) * 0.4,-delta.X * 0.5 - delta.Y * 0.8) * 0.01)
	mf.Position = UDim2.new(0.5,0,0.5,0) + UDim2.new(uiSpr.Position.X/10,0,uiSpr.Position.Y/10,0)
	mf.Rotation = uiSpr.Position.Z*3
	vm:Update(dt)
	scopeP.UpdateScopesInModel(vmObj.Object)
end

local function OnHoverWepCh(hovWep)
	if hovWep then
		pickupTxt.Text = "[F] to pickup "..hovWep.Name
		ts:Create(pickupTxt,TweenInfo.new(0.2),{TextTransparency = 0}):Play()
		ts:Create(pickupTxt.UIStroke,TweenInfo.new(0.2),{Transparency = 0.6}):Play()
		ts:Create(pickupTxt.UIGradient,TweenInfo.new(0.4),{Offset = Vector2.new(1,0)}):Play()
	else
		ts:Create(pickupTxt,TweenInfo.new(0.2),{TextTransparency = 1}):Play()
		ts:Create(pickupTxt.UIStroke,TweenInfo.new(0.2),{Transparency = 1}):Play()
		ts:Create(pickupTxt.UIGradient,TweenInfo.new(0.5),{Offset = Vector2.new(-1,0)}):Play()
	end
	script.PickupHighlight.Adornee = (hovWep and hovWep.Weapon) or nil
end

local function Cleanup() vm:Destroy(); maid:Destroy() end
local function Died() Cleanup() end

local function PlrKilled(killInfo,effectInfo)
	if killInfo.Killer == player then
		guiMod.CreateCombatMessage("Kill",killInfo.Victim.Name)
		task.spawn(function()
			ts:Create(mainHud.KillVignette,TweenInfo.new(0.02),{ImageTransparency = 0.7}):Play()
			wait(0.02)
			ts:Create(mainHud.KillVignette,TweenInfo.new(0.4),{ImageTransparency = 1}):Play()
		end)
		util.PlaySound(game.SoundService.ClientSounds.Kill,NumberRange.new(1,1))
	end
	local killEff = vfx.CreateEffect("KillEffect",unpack(effectInfo))
	if killInfo.Victim == player.Character then
		print(killEff)
		player.CameraMinZoomDistance = 9
		camera.CameraSubject = killEff
		player.CameraMode = Enum.CameraMode.Classic
	end
	guiMod.CreateKillFeedFrame(killInfo)
end

local function IncHit(attacker,wepName,dir,hitInfo)
	local mult = 100
	if hitInfo.HitPart.Name == "Head" then mult = 180 end
	camFS:Impulse(dir.Unit*mult)
end

local function ShotHit(shotID,charDamage,killed,...:any)
	if shotID == "DamageDealt" then
		local hitChar = charDamage
		local damage = killed
		local hitPos = ...
		local dmgTemp = assets.Gui:FindFirstChild("DamageDealt")
		if dmgTemp then
			local gui = dmgTemp:Clone()
			gui.Damage.Text = "-" .. math.round(damage)
			gui.Parent = workspace.Debris
			local p = Instance.new("Part")
			p.Size = Vector3.new(1,1,1)
			p.Transparency = 1
			p.CanCollide = false
			p.Anchored = true
			p.Position = hitPos + Vector3.new(math.random(-1,1), 2 + math.random(-1,1), math.random(-1,1))
			p.Parent = workspace.Debris
			gui.Adornee = p
			gui.Parent = p
			ts:Create(gui.Damage, TweenInfo.new(1, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {TextTransparency = 1}):Play()
			ts:Create(p, TweenInfo.new(1.5, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Position = p.Position + Vector3.new(0, 2, 0)}):Play()
			game:GetService("Debris"):AddItem(p, 1.5)
		end
		return
	end
	local shot = weapH.GetShotFromID(shotID)
	local wep = shot.WeaponUsed
	local wepInfo = wep.WeaponInfo
	local headshot = false
	if wepInfo.WeaponType[2] == "Hitscan" then
		headshot = shot.Headshot
		if wep.WeaponInfo.Bullets > 1 then
			for hitChar,hitParts in pairs(shot.CharsHit) do
				for i,info in pairs(hitParts) do
					local cast = info[1]
					local hitInfo = info[2]
					local originCf = cast.OriginCFrame
					local offset = originCf:ToObjectSpace(CFrame.new(hitInfo.EntryPos))
					crosshair.HitmarkerEffect(wep.WeaponInfo.Crosshair, hitInfo.HitPart.Name == "Head", killed, (camera.CFrame * offset).Position)
				end
			end
		else
			local cast = shot.Casts[1]
			for char,info in pairs(shot.CharsHit) do
				crosshair.HitmarkerEffect(wep.WeaponInfo.Crosshair, headshot,killed,info[1][2].EntryPos - (cast.Direction.Unit * 1))
			end
		end
	elseif wepInfo.WeaponType[2] == "Projectile" then
		headshot = ...
		crosshair.HitmarkerEffect(wep.WeaponInfo.Crosshair, headshot,killed)
	else
		crosshair.HitmarkerEffect(wep.WeaponInfo.Crosshair, shot.Headshot,killed)
	end
	util.PlaySound(game.SoundService.ClientSounds.Hitmarker,nil,NumberRange.new(0.91,1.59))
	if headshot then
		util.PlaySound(game.SoundService.ClientSounds.Headshot,nil,NumberRange.new(0.99,1.01))
	end
	for _,shotInfo in pairs(charDamage) do
		local hitChar = shotInfo.HitInfo.HitChar
		library.HealthBarHandler.Appear(hitChar)
		vfx.CreateEffect("HitHighlight",hitChar,shot.Headshot)
	end
end

local function RepVFX(effects:{})
	for i,effect:{Effect:string,Params:{any}} in ipairs(effects) do
		vfx.CreateEffect(effect.Effect,unpack(effect.Params))
	end
end

local function RepSound(sound,...) util.PlaySound(sound,...) end

local function ProjAct(action,id,params)
	if action == "Create" then
		local proj = projH.NewProjectile(unpack(params))
		proj:ChangeNetworkController("Server")
		proj:Start()
	elseif action == "Destroy" then
		local proj = projH.GetProjectileFromID(id)
		assert(proj,"Projectile with id: "..id.." not found")
		proj:Destroy()
	end
end

local function UpdProj(id,pos)
	local proj = projH.GetProjectileFromID(id)
	if not proj then return end
	if proj.NetworkController == "Client" then proj:ChangeNetworkController("Server") end
	proj.CurrentReceivedPos = pos
end

local charJoints = {}
local function UpdCharJoints(char_,joints)
	charJoints[char_] = charJoints[char_] or {Previous = nil,Current = nil}
	charJoints[char_].Previous = charJoints[char_].Current or joints
	charJoints[char_].Current = joints
end

rs_:RenderStepped:Connect(function()
	for char,joints in pairs(charJoints) do
		for i,jointInfo in pairs(joints.Current) do
			jointInfo[1].C0 = joints.Previous[i][2]:Lerp(jointInfo[2],0.1)
		end
	end
end)

for _,tool:Tool in pairs(backpack:GetChildren()) do NewWep(tool) end
backpack.ChildAdded:Connect(function(tool) NewWep(tool) end)

for _,crosshairFrame in pairs(chs:GetChildren()) do if crosshairFrame:IsA("Frame") then crosshair.new(crosshairFrame) end end
crosshair.SetCurrentCrosshair("Dot")

animG.new("Character",char,charAnims,true,maid)
LoadCharDisp()
OnHoverWepCh(curHoverWep)
wepHoverChg:Connect(OnHoverWepCh)
hum.StateChanged:Connect(HStateCh)
hum:GetPropertyChangedSignal("MoveDirection"):Connect(MoveDirCh)
hum.Died:Connect(Died)
mov.OnSlide:Connect(OnSlide)
mov.OnSprint:Connect(OnSprint)
rs_:RenderStepped:Connect(RStep)
uis.InputBegan:Connect(InBegan)
uis.InputEnded:Connect(InEnd)
weapH.WeaponEquipped:Connect(WepEq)
weapH.WeaponUnequipped:Connect(WepUnEq)
remotes.VFX.OnClientEvent:Connect(RepVFX)
remotes.Hit.OnClientEvent:Connect(ShotHit)
remotes.Tilt.OnClientEvent:Connect(UpdCharJoints)
remotes.Projectile.OnClientEvent:Connect(ProjAct)
remotes.ProjectileUpdate.OnClientEvent:Connect(UpdProj)
remotes.Kill.OnClientEvent:Connect(PlrKilled)
remotes.ReplicateSound.OnClientEvent:Connect(RepSound)
remotes.IncomingHit.OnClientEvent:Connect(IncHit)
if rs_:IsStudio() then else player.CameraMode = Enum.CameraMode.LockFirstPerson end
player.CameraMinZoomDistance = 0
player.CameraMaxZoomDistance = 128