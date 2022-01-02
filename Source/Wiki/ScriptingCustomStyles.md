> ***Scripting is still under heavy development and therefore the API for it is not stable and will be changed
> frequently. Any scripts you write, must be updated regularly to stay functional.***
>
> ***Also, be aware that this will change your Threat Plates settings in a way that you cannot go back to the release version. So,
> be sure to make a backup of your settings.***

> ***Version 2: Working, but restricted in functionality as no changes to core code of Threat Plates were yet made.***

Scripting is a new feature of Threat Plates that will be introduced in one of the upcoming versions of Threat Plates.
It allows you to extend the functionality with custom Lua scripts. Once finished, you should be able to change all
aspects of nameplates. Currently, functionality is still restricted to a high degree as internal functions of
Threat Plates (like, e.g., scaling) are not easily accessible to scripts. So overwriting or changing them to, e.g.,
implement custom scaling is not that easy or may even be impossible right now.

***Note that the Scripting API as is is not fully secure.*** Critical WoW functions should be blocked (like, e.g. GuildDisband,
thanks to WeakAuras and Plater for this information), but there might be holes. So, be especially careful when you import
scripted custom styles from other users.

### Download

[Threat Plates v. 10.2.0-Beta1](https://drive.google.com/file/d/1ssqbgtCmwB4CYf8cz1vMQpxs0FUfi4TH/view?usp=sharing)

### Script Types

Currently, there are two types of scripted styles (or custom nameplates): scripts that work on all nameplates (trigger Script)
or scripts that work only on nameplates where the trigger fired (like units with a certain name or units casting a particular
spell).

### Script Functions and Events

Every script must be assigned to either a Threat Plates function or a WoW event. The following Threat Plates functions are
available:

- IsEnabled
- OnEnable
- OnDisable
- EnabledForStyle
- Create
- UpdateFrame
- UpdateSettings
- UpdateLayout
- OnUnitAdded: Only available for standard (non-target/focus-based) scripts.
- OnUnitRemoved: Only available for (non-target/focus-based) scripts.
- OnUpdate
- OnTargetUnitAdded: Only available for target-based scripts.
- OnTargetUnitRemoved: Only available for target-based scripts.
- OnFocusUnitAdded: Only available for focus-based scripts.
- OnFocusUnitRemoved: Only available for focus-based scripts.
- WoWEvent: Add script code for any WoW event. The name of the event must be entered in field "Event Name".

### Global Variables

- Environment: A table that currently contains the style (custom nameplate) that defined the script. You can also use
  this table to store variables that should be accessed across the different script functions for a style (e.g. to
  transfer information between OnEnable and OnUnitAdded, see examples below).
  - Style: A table containing all settings for the custom style. 
- PlatesByUnit: Hashtable with all nameplates accessible by unitid.
- PlatesByGUID: Hashtable with all nameplates accessible by GUID.

To access the Threat Plates nameplate, use, e.g.: PlatesByUnit["target"].TPFrame

###  Current Restrictions

- Target- and focus-based scripts are not really tested - they might not work or not work efficiently
- Some, mostly security-related functions and tables are blocked.

### Example 1: Execute - Color the healthbar in a particular color once the unit's health is in execute range.

As internal functions (like coloring) are not accessible to scripts right now, this script uses `hooksecurefunc` to
change the color after Threat Plates's calculation if health is below the execute range. Not very efficient as the
Threat Plates color calculation is done unnecessary in these cases, but it works.

As color, the color from the custom style defined under Appearance is used.

**Function: IsEnabled**

    function()
      -- Return false or nil, to disable the script, e.g., when it should be only active on a certain class
      local player_class = select(2, UnitClass("player"))
      return player_class == "WARRIOR"
    end

Only enable this script for class Warrior.

**Function: Create**

    function(widget_frame)
      local healthbar = widget_frame:GetParent().visual.healthbar
      hooksecurefunc(healthbar, "SetAllColors", function()
        local unitid = healthbar:GetParent().unit.unitid
        local health = _G.UnitHealth(unitid) or 0
        local healthmax = _G.UnitHealthMax(unitid) or 1
        local pct = health  / healthmax
    
        if pct < 0.20 then
          local color = Environment.Style.color
          healthbar:SetStatusBarColor(color.r, color.g, color.b)
        end
      end)
    end

If you change this code, you need to reload the UI to take effect as the hooked script cannot be removed otherwise.

**Import String**

> 9vv3UPTsq43fUcKoXhGKCYjvNEHdLK6OespS0u1BmEXEaVQBwJ2Dn)CJF27mJnGjvTcjy2z(MF3D(iEq8SyXRG1PkmXIb9dgg0)I7aVCqSyuPZx8MWVxdoe2eg7yJCHgiPVAu(PGm1tUINNm(RZMg(u8DXI7NgnEYNE67K8NFrml6PXOOpw8sP)LLrgNxAsXGIMNaBaB8IyrK5m9hoe9j3P0MXarncmyy4C5fBJsX0JoisTQ1Eg89LM6QsmYcspelMTFn(TaJyM0MHHBdyq)rafzCZ8eSsMUN0WMOW4pfioQrUdfHyzJ(U9QESkPk5IlQsMc(sRPkzPu7GQKcBvIrP)RQeFrvsMYrUIhYXVCCPIMGGvb4pBZb0rLhTKxuQZQswqrWO3xLqZ3n8juUkjfSEPcLt1sNRo76IuPUkzTwUhSZRnK8rmyGgs9DhIzGURgrg62PgwNEnLUTPSFN3O7D(w40PrVmTt1JGj70S8yZVvLTc8ZxALVb9oRuYbP2NVqA56OnUp8a4)I0IJ4U9c2OCLsDWj0CmYlk(HdslTaLPUhTITrhb4d16rf6cRRdQ49xeTQHsSLvzCbCmeNLDcqqdQ37CThSZZFiGMEFM10TgFV673()g)EtU7xD9z5UZ9EWV496uFR6Lm83Td5JNCqTSb9)HvrWW(8dlZj7TcAknS4Wo2SrzlmVHTFaVvhuB7mVonRWznUW4lD3jT8eVldpGUiQLwDuArR5p(yP(ak0R(TJVEDT0bCGO1vfT2kIM868NvU05)Fj4OlYNL2FeSqVgPxCqyjY)i9Q0d74OUz50ZWh0fBjUabsaGJ3mTYaVQaw3mRA1kKtbxzhjDEE11SUKx3dDHwRCpVD7pslWRJive((8pHoS0k)t2BIZVhHVvhupiWYvQxNljYvX4LlX9vMRH7pQbyum37K(b3ED8KHheUKeUepEfzLiRO9lSlkmhj8(IAhOpqKFiJCDi1ygOHnsNHd2cKe2QYGqUyw0mleJ3H7H0opEZXVyAJvGpVacBAtrkwWTXkSWIf247V66Hdg(p9)3(dV8MBV52HXlV46lzAB2tclrGtPczF8a)xe0N4Fc

### Example 2: Silence Effect - Show the duration for which a player is unable to cast a spell after a successful interrupt.

The effect is currently shown on NPCs (which might be wrong) and no matter who interrupted the unit.

**Function: OnEnable**

    function()
    Environment.INTERRUPT_SPELLS = {
      [1766]   = 5, -- Kick (Rogue) 
      [1766]   = 5, -- Kick (Rogue)
      [2139]   = 6, -- Counterspell (Mage)
      [6552]   = 4, -- Pummel (Warrior)
      [13491]  = 5, -- Pummel (Iron Knuckles Item) 
      [19647]  = 6, -- Spell Lock (felhunter) (Warlock) 
      [29443]  = 10, -- Counterspell (Clutch of Foresight) 
      [47528]  = 3, -- Mind Freeze (Death Knight) 
      [57994]  = 3, -- Wind Shear (Shaman) 
      [91802]  = 2, -- Shambling Rush (Death Knight) 
      [96231]  = 4, -- Rebuke (Paladin) 
      [93985]  = 4, -- Skull Bash (Druid Feral) 
      [97547]  = 5, -- Solar Beam (Druid Balance) 
      [115781] = 6, -- Optical Blast (Warlock) 
      [116705] = 4, -- Spear Hand Strike (Monk) 
      [132409] = 6, -- Spell Lock (command demon) (Warlock) 
      [147362] = 3, -- Countershot (Hunter) 
      [183752] = 3, -- Consume Magic (Demon Hunter) 
      [187707] = 3, -- Muzzle (Hunter) 
      [212619] = 6, -- Call Felhunter (Warlock) 
      [217824] = 4, -- Shield of Virtue (Protec Paladin) 
      [231665] = 3, -- Avengers Shield (Paladin)
    }
    end

List of interrupts with silence duration, thanks to bambziqt for this list.

**Function: Create**

    function(widget_frame)
      local frame  = _G.CreateFrame("Frame", nil, widget_frame)    
      frame:SetAllPoints(widget_frame)
      frame:Hide()
      widget_frame.InterruptFrame = frame
      
      local icon = frame:CreateTexture(nil, "OVERLAY")  
      icon:SetSize(32, 32) 
      icon:SetPoint("RIGHT", frame, "LEFT", -10, 0)
      icon:Show()
      frame.Icon = icon
      
      local time = frame:CreateFontString(nil, "OVERLAY") -- Duration Text
      time:SetJustifyH("CENTER")
      time:SetJustifyV("CENTER")
      time:SetShadowOffset(1, -1)
      time:SetShadowColor(0, 0, 0, 1)
      time:SetFont("Fonts\\FRIZQT__.TTF", 14, "OUTLINE")
      time:SetTextColor(1, 0, 0)
      time:SetAllPoints(icon)
      time:Show()
      frame.Time = time
      
      frame:SetScript("OnUpdate", function(self, elapsed) 
          self.ElapsedTime = self.ElapsedTime - elapsed
          local cooldown = ceil(self.ElapsedTime * 10) / 10
          frame.Time:SetText(cooldown)
          if self.ElapsedTime < 0 then
            self:Hide()
          end
      end)
    end

Code should be pretty straighforward. Once the silence effect expires, the frame is hidden and the OnUpdate function will
stop to be executed.

**Event: COMBAT_LOG_EVENT_UNFILTERED**

    function(...)  
      local timeStamp, event, hideCaster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, spellID, spellName, spellSchool = CombatLogGetCurrentEventInfo()
      local counterspell_duration =  Environment.INTERRUPT_SPELLS[spellID or 0]
      
      if event == "SPELL_INTERRUPT" and counterspell_duration then
        local frame = PlatesByGUID[destGUID]
        if frame then
          frame = frame.TPFrame.widgets.Script.InterruptFrame
          frame.ElapsedTime = counterspell_duration
          frame.Icon:SetTexture(GetSpellTexture(spellID))
          frame:Show()     
        end
      end
    end

**Import String**

> nE12Yjoot43fUYS1ewS5uyQ)9cGysCgcWGDYuZodhe2cqvSTOKLNmj)1YZ(2T8bmGtQTOWwwQ7V(SK6f6lCwy)eveX4HlS1RxZOw9R6tLe9f2dIJK8aB5R(0iGSXkAndjR9P4OhdzYzuIRezf(ES5JoZ6nAr)f2dNzzo(MrFhhF3eBhRrMWq5c7jXYjBScJKKqxauy5X0FrflwVW2k8K5Z(W6MOJI1trimJnagax0o(lwUG4bgSDfS9sfXdJdt0k7jHP6RTZR7HN2aMEeHha4VOHacdM8q)Eolhn52LMpzo2z5JJhAnYXCM5nWICpLLoIUL4(ki0eUuY4dzCtQcOvRwTQhwb)UhF6ZDj(hwjzbuqrc2)PdROiGW7Dmp6asKKkGpI4Xcx6TpADt(hJjb08pg6t2gL)1mcZlBgpAKmLpCykx4WIuuKJO9uF)ebHJYKdo22DhNd67FDy1aEWAICeF7Tu5GyHauALRWkCdxR6jwNlpoemdfcl9Ife0rOa5WkZWFXe8WaGZAwJbN1ShN6S0EQ5Or2)ivtoSIloSQ(8eqtEY2K6PaCaGQO4yzocvoSccRVROL7OHPODun3ialvPwt9jsAu)xr)2pYCGZpYak8uQpfj83ryuJQ5mDO69lmVTuzuTKSYAwOEjI3lvRwce1m9j7JOEoSu4k3wkHrm))Z2uPd93YybvdIq2itzFN6wRwTeM)SnuaPvTW850qbh695dGhy9wwHvsfGGcoUcj7j28sfYNMtK6Lug2YBRLWPYvOvr9QcKZfY8HNNcYjQvQktL989NYzqHyzImHQ7G6PSeZIeDEKipYvmDlvRzUPjUjqMO1zU1eTTYKNmNnQ33RuOkNLgqSzVr1Ayau1WO65lQ0FTkZSU9oh04vIabCK5q1exPxhEwVAr2scwhTsvSxPHkv9slqYkAIPwWqEO0wkyHBlXiU6QdRUjVYbn2earKq9(E4mb2MxVtRYatS8Rs1sx)P3BD7Dep(lt2SjIk10v2zPumG7ZfAkxq6)ZPdndi7bEg9ZFch483F1z5YAoodrVNEtLD9OZiRXMNRdOvLGVEg(NrXXem0XEYIxedYRyvo77ljDnzpaTktcFCVheauX7SIMiQ)g8CGKY)88KSF4YxS3WLtEvocNYE(EYCFWPMKR4sz(AxcXFaEnWpS6pX3LTrJtb3NwgINTRcUx5Lq))apCzBEMzGNuTM9R4gqvt2bQWX55(pyPp6ufLf))ta6h6DA3EEc6WST(us6(xyUpFyL2m(2yAU)))eTjuAO3O7rkBNs5Gc7FdC8azBodTB1Y4idntzyACqafj9BeHGXfzuR3Ozx95NPh5eBjW60Veg7(mClTdRSK0Gcgr32n7m)mnZorLgXvMYgQ)oLMwnr0qgZZhbWOBZMnYaqTJuj22a)yP7o4CBi4pKlOrST7KhXOzNwgxNHrJuiEGHhypuqPVbjiA3aBmTdTJtzTvNUDBEoRFtXQ9okbUNGgSDraj8ilD1VUUrglgzMmq0AFyhVdRMfhT79fy32gnYD2zrMz01XpJA5uIpXJvuyn6EDRZj3(5y0T0NKiirmdTuQG4xGXoTogyYcQ2CF0K6tjbhzSpit4AWfIP6T6CnQJfcPt2lzQc9((WDillqQR3Ut9wZpvr3RCH3PU7eEIGYiFGhwKVggnR3D(hKa5Ydcui4rdW9klt4n70OTX8tIIz5q74O(Exwkyghx3OtRl4imkg3obQLyUQyyaM8FjVD6uVZP8(q8BV5tlrqg6gT1pZ(gqqZBywHrP1f6DU2O5zUZDmQVxszWtmHmwLYi4skOSxK6a5zTB36uTShCf3TGp5iwht5U)FYUfMQZN4iQ6imSZh8mkOTOXpT8bwK7YVgd3Hf2A8bI45AR93dDQfr7fdTYbNQ7M1UemNZo8(a36ZFbBRcpz7okXdktOpXOQ5CeSTGcPUThKyHVTc3hlXwH6f1tiiVcZPuO0(Ruh1bD1bhy8ru3dUIXhTEkoVpfYcwqIJauxI)(DeSpvBZnBOUjnQPSp0auuPAJDC9ADBTySr2Gg4GgWNnXvX75Ih4bwbpmVZXPSFt9Z6jotIk9aYw4VGoBO9uWXYH(zfW5z9ukZ6uFHTnZNc1XqpqkvtfbvTwxKhBOiMI8ePgGwIBQABluFUv9CDQEI9)IWVhBHr1Hn(BX)o