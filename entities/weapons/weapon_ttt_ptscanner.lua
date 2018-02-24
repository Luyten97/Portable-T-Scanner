if SERVER then
   resource.AddFile("materials/VGUI/ttt/icon_ptscanner.vmt")
end

GLOBAL = {}
GLOBAL.OneTimeUse           = true
GLOBAL.AmountOfUses         = 3
GLOBAL.LimitedStock         = true
GLOBAL.Cooldown             = 5
GLOBAL.FreezeDuration       = 3
GLOBAL.SuccessChance        = 100
GLOBAL.HUDFont              = "CloseCaption_Bold"
GLOBAL.MenuDescription      = "Portable traitor scanner by Dr Kleiner.\nAlthough, his engineering is... quesionable"

if CLIENT then
	SWEP.PrintName           = "Portable Scanner"
	SWEP.Slot                = 6

	SWEP.ViewModelFlip       = false
	SWEP.ViewModelFOV        = 54
	SWEP.DrawCrosshair       = false

	SWEP.EquipMenuData = {
		type = "item_weapon",
		desc = GLOBAL.MenuDescription
	};

	SWEP.Icon                = "vgui/ttt/icon_ptscanner"
	SWEP.IconLetter          = "j"
end

SWEP.Base                   = "weapon_tttbase"

SWEP.UseHands               = false
SWEP.ViewModel              = "models/weapons/v_stunbaton.mdl"
SWEP.WorldModel             = "models/weapons/w_stunbaton.mdl"
SWEP.NoSights               = true
SWEP.HoldType               = "camera"

SWEP.Primary.Damage         = 0
SWEP.Primary.Automatic      = false
SWEP.Primary.Delay          = GLOBAL.Cooldown
SWEP.Primary.Ammo           = "none"
SWEP.Primary.ClipSize       = -1
SWEP.Primary.DefaultClip    = -1

SWEP.Kind                   = WEAPON_EQUIP2
SWEP.CanBuy                 = {ROLE_DETECTIVE}
SWEP.LimitedStock           = GLOBAL.LimitedStock



if GLOBAL.OneTimeUse then
	SWEP.Primary.ClipSize       = GLOBAL.AmountOfUses
	SWEP.Primary.DefaultClip    = GLOBAL.AmountOfUses
end

if SERVER then
	util.AddNetworkString("SendResults")
end

local SoundInProgress = Sound("ambient/energy/electric_loop.wav")
local SoundInnocent = Sound("buttons/button1.wav")
local SoundTraitor = Sound("buttons/button19.wav")


function SWEP:PrimaryAttack()
	if not IsValid(self:GetOwner()) then return end

	if GLOBAL.OneTimeUse then
		if ( !self:CanPrimaryAttack() ) then return end
	end

	self.Weapon:SetNextPrimaryFire( CurTime() + 1 )

	local spos = self:GetOwner():GetShootPos()
	local sdest = spos + (self:GetOwner():GetAimVector() * 70)

	local kmins = Vector(1,1,1) * -10
	local kmaxs = Vector(1,1,1) * 10

	local tr = util.TraceHull({start=spos, endpos=sdest, filter=self:GetOwner(), mask=MASK_SHOT_HULL, mins=kmins, maxs=kmaxs})

	if not IsValid(tr.Entity) then
		tr = util.TraceLine({start=spos, endpos=sdest, filter=self:GetOwner(), mask=MASK_SHOT_HULL})
	end

	if IsValid(tr.Entity) then
		self.Weapon:SendWeaponAnim( ACT_VM_HITCENTER )

		if tr.Entity:IsPlayer() and not (timer.Exists("ScanInProgress")) then
			if CLIENT then
				self:EmitSound(SoundInProgress)
				return
			end
			self.Weapon:SetNextPrimaryFire( CurTime() + (GLOBAL.FreezeDuration + GLOBAL.Cooldown) )
			self:RunTest(self.Owner, tr.Entity)
			if GLOBAL.OneTimeUse then
				self:TakePrimaryAmmo(1)
			end
		end
	else
		self.Weapon:SendWeaponAnim(ACT_VM_MISSCENTER)
	end

	if SERVER then
		self:GetOwner():SetAnimation(PLAYER_ATTACK1)
	end

end

function SWEP:OnRemove()
	if CLIENT and IsValid(self:GetOwner()) and self:GetOwner() == LocalPlayer() and self:GetOwner():Alive() then
		RunConsoleCommand("lastinv")
	end
end

function SWEP:RunTest(attacker, victim)

	attacker:SetEyeAngles((victim:EyePos() - attacker:GetShootPos()):Angle())
	victim:SetEyeAngles((attacker:EyePos() - victim:GetShootPos()):Angle())

	attacker:Freeze(true)
	victim:Freeze(true)

	timer.Create("ScanInProgress", GLOBAL.FreezeDuration, 1, function()
		self:StopSound(SoundInProgress)
		if self:CalculateSuccessChance(GLOBAL.SuccessChance) then
			if (victim:GetRole() == ROLE_TRAITOR) then
				self:EmitSound(SoundTraitor)
				self:SetNetworkedString("ScanResults", "Traitor")
			elseif (victim:GetRole() == ROLE_INNOCENT) or (victim:GetRole() == ROLE_DETECTIVE) then
				self:EmitSound(SoundInnocent)
				self:SetNetworkedString("ScanResults", "Innocent")
			end
		else
			local rand = math.random(1, 100)
			if rand > 50 then
				self:EmitSound(SoundTraitor)
				self:SetNetworkedString("ScanResults", "Traitor")
			else
				self:EmitSound(SoundInnocent)
				self:SetNetworkedString("ScanResults", "Innocent")
			end
		end

		local t = {attacker, victim, self:GetNetworkedString("ScanResults")}
		net.Start("SendResults")
		net.WriteTable(t)
		net.Broadcast()

		attacker:Freeze(false)
		victim:Freeze(false)
		timer.Simple(5, function()
			timer.Remove("ScanInProgress")
			self:SetNetworkedString("ScanResults", "None")
		end)

	end)

end

function SWEP:CalculateSuccessChance(chance)
	if math.random(1, 100) < chance then return true end
end

net.Receive("SendResults", function(len, ply)
	local t = net.ReadTable()
	local attacker, victim, results = t[1], t[2], t[3]

	if results == "Traitor" then
	chat.AddText(
		Color(255,255,255), attacker, 
		Color(255,255,255)," completed a scan on ", 
		Color(255,255,255), victim, 
		Color(255,255,255), ". The results indicate, ", 
		Color(255,0,0), string.upper(results)
	) else
	chat.AddText(
		Color(255,255,255), attacker, 
		Color(255,255,255)," completed a scan on ", 
		Color(255,255,255), victim, 
		Color(255,255,255), ". The results indicate, ", 
		Color(0,255,0), string.upper(results)
	)
	end
end)

function SWEP:PreDrawViewModel(vm, wep, ply)
	local results = self:GetNetworkedString("ScanResults")
	if results == "Innocent" then
		render.SetColorModulation(0, 100, 0)
	elseif results == "Traitor" then
		render.SetColorModulation(100,0,0)
	else
		render.SetColorModulation(0, 0, 100)
	end
end

if CLIENT then
	function SWEP:DrawHUD()
		local tr = self:GetOwner():GetEyeTrace(MASK_SHOT)
		local results = self:GetNetworkedString("ScanResults")
		
		local x = ScrW() / 2.0
		local y = ScrH() / 2.0

		if tr.HitNonWorld and IsValid(tr.Entity) and tr.Entity:IsPlayer() then
			surface.SetDrawColor(255, 0, 0, 255)

			local outer = 20
			local inner = 10
			surface.DrawLine(x - outer, y - outer, x - inner, y - inner)
			surface.DrawLine(x + outer, y + outer, x + inner, y + inner)

			surface.DrawLine(x - outer, y + outer, x - inner, y + inner)
			surface.DrawLine(x + outer, y - outer, x + inner, y - inner)

			if !( timer.Exists("ScanInProgress") ) then
				draw.SimpleText("Scan Target", "TabLarge", x, y - 30, COLOR_GREEN, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
			end
		end
		
		if timer.Exists("ScanInProgress") then
			draw.SimpleText(". . . Scanning . . .", "TabLarge", x, y - 30, COLOR_GREEN, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
		end

		if results == "Traitor" then
			draw.SimpleText(results, GLOBAL.HUDFont, x, y + 100, COLOR_RED, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		elseif results == "Innocent" then
			draw.SimpleText(results, GLOBAL.HUDFont, x, y + 100, COLOR_GREEN, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
		end


		return self.BaseClass.DrawHUD(self)
	end
	
	function SWEP:GetViewModelPosition(pos, ang)
          pos = pos + ang:Forward() * 15
          return pos, ang
	end
end




