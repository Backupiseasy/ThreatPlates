> ***Scripting is still under heavy development and therefore the API for it is not stable and will be changed
> frequently. Any scripts you write, must be updated regularly to stay functional.***

> ***Version 1: Working, but restricted in functionality as no changes to core code of Threat Plates were yet made.***

Scripting is a new feature of Threat Plates that will be introduced in one of the upcoming versions of Threat Plates. 
It allows you to extend the functionality with custom Lua scripts. Once finished, you should be able to change all 
aspects of nameplates. Currently, functionality is still restricted to a high degree as internal functions of 
Threat Plates (like, e.g., scaling) are not easily accessible to scripts. So overwriting or changing them to, e.g., 
implement custom scaling is not that easy or may even be impossible right now. 

***Note that the Scripting API as is is not fully secure.*** Critical WoW functions should be blocked (like, e.g. GuildDisband,
thanks to WeakAuras and Plater for this information), but there might be holes. So, be especially careful when you import
scripted custom styles from other users.

### Download

[Threat Plates v. 10.1.0-Alpha1](https://drive.google.com/file/d/1ohIEZEhhhsMKpPNi9Z5wHe7_LSRcDCnR/view?usp=sharing)

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
          local color = Style.color
          healthbar:SetStatusBarColor(color.r, color.g, color.b)
        end
      end)
    end

If you change this code, you need to reload the UI to take effect as the hooked script cannot be removed otherwise.

**Import String**

> 9v1wVPTsq4)l8eivCbstZjvTpqtHeFucKYssvFX4f7byv2SgT7AU8I)TFMzSnbO9ezj7z35(Tph1nAAK4zW6uzMir3obDd60UVE9kz3iXn5oF2Rc)En4q5gXcpWiNRbI6jJYpbKjEsx88ObpnDs)7J(EKy4KWbJ(X9)MOVBSyA49dqsFKyCUF8IqJZlnjOrr2JGnGnAEKi0CY91hc)H7n3MYcI3iqJHMZTkBByc6EubrIvT2Zcpm3ugvIBSG0drIP7xJVfOftL2u0CBadQpkqwkNm1cUOs1MBvPlb)Sfw5RqRI)TiUiwNLi1fXRaP2VAU0we)TI4JL7l3c(hLw00nBfSr5YL6G3KMTXQSSxCqsUfip18a3pue3qa((A9nz6mRRbEXHyPY)1pvXrow)vPCqCWmNebKabvs93mqPwSbMDBa1oVJVPzPoTkIZWCSZ7O7RYD)P6pi3DQf6(xTW6e)rXoX4JhB2tu50tQfvA)vm6c61Pi2VcmNPXBokHkOSRgy2OSzMxXYtapwhuY7p08T6j2tWPgFU77sl3zAYQeqnSsQLhOMFwFcmv1DKazHVXHxx9KS482B72fXtaFU1GTEP2bLvpJsJEWNveNQCKQC6we745DKfeSma)SLQbXkSSGBf5ACWyozbJEFrmTKUHpH0y4cwVuH0jAPZDYW9ATCpyNvYGQzoqdj(M9qpqT4BignBukwJwvHUTkSptBu9g)Q)KjHJN0Om)5T2ChWLsARvrBVIWrpp7bLlz2pZbhvtEqAFjyUEnIY4G(5imK0RsQx1X7MUIwyVvNTLGeeioao8LQvg4zfW3n1QwUeHwOLBPZtFdnRZ5T((U(wRCpEhhqvOdCbfrKWn53t6(5w57XVYo))s4pkdkley4kjqxcJvmyXcSIZazC(rjalfdbpQtW1xgnQxnXfeXf4XprCrtpKqIWSiZCa37r1oqxJNx7rooKA0duXghiXcBgIfBvPa)hakQ4AHyWoeXIqhXohV3CSScCUbiztQcsXConwIbwKWgn8tx2RBVp35F607IRU(QR7fTO9LxWO3SMKSeoo5kC(Xd8FkONO)l

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

> vE16Yjksu43f)LU1gwXRXP25hgdgjRrDesMA2z8shOv6kaTvdmzs2A5zFpNgAfiMu1wuj2095Y35k9zT(A71wpqfrmE4Al9MA6AnVyO)bpI(ARrjrX8aR4x8PraDZKeBesE0NIRUpKfVKsCIrEH3NzCV9YHtxF1ARXlnnMD90VHRNm3Y2CQbSmET18K457mdJIjHoGqHJNr)jvS(X1wMHL2x9I51rNuRRKqyhlqyG4I84pB6aQhyWYrWoeljECsygQS(k)Rg)KgcKA)YbkqeitxIWfey22JMF3vdT3mD(nBmEWyM9M7Nn2CQTXsJRHd5UslDEyUvBTlxY1BKEB620TgH)Kj4HbGS0mNbST8(f2BSwymDQv62pNU9FYOdF(UE)E9wLTgoP7VNU9Ils3(xmNNs3wFjFFcTbC2)p6prDl92dorDVCQhXtcJH47bQVpW1DK9LyQx3UToXuNCMwKeeqrY)kriyCrro0B3zG(Qky6idMGZaGyyIZtqst6wZyAqfJAqVo9xvbLwzWBkxAA7O(Esu3idc(W2LfsRbD60wje9MN3wh5Ne74LULVlD7yUGgX27fxwoD63T1Lk50oxm3XcDboeu6RuqmxtjXEOn9w272FWGovz)Rs2T8OebWTLhjGewMTb6x2SLITwkxaq4J(SW9PBxMe59XkEqVwTpgeurTL0htEcr8cIpXLvvPThCz3QSy9uc6QUIKPqrcdTCQG4xH5(Dpf0ubDlUpAIxrjbNy(kq3qvBLyUE3(xI4TqiF(HyMdbvUpjk(9c066963S7QYG(G01oHi9ZXcM0OVJhwL32T60CWQpirZHheiLIlnGh(UzB6D63UxRvLIYQCnpoI9jQ01ICDz7(DFdxHrjbaCH6qMJmghGfmNN)(9B2Vm)3L86R(03rHT0B1tVI9oIGM7yvb17wpP3)YwDQ4M9yuF3SYNhyI4ezQLGhtbGF2umiNSxVULr8qOn7EWpDsENspLC(VP3sdH(XJeq6EXoSpZC3tJ3StqcuTSaGJzmYTsZsg3CJwgNJXnRxt(tnq5HmF4)LfsoqZeMCVpzrJh67VGZcJJoNkZOAcZLQA5xKint0RksoepodtFwHUBpPOCuZCWiTIGpLHAB6VIte06zOT28hmwoD43Q14e3iBikTyVsR3g7w0UvJQhkXF9AlnVzInA8svGcCQXy5gxiBs2Srr2GVDwVOvQzQqOeQV1cIzfnXClympmglcd3FgJaZaUorqWaA6w0yZeikje33c3WGT7Lj1RnYa)6zTgN98hEVZHMMU8NNVBxenUUU0oplfJ4(CrDPli)VQ0HMbK9a)p6h)aU(YF)f7nB0SThJEp9os76E7PMZmQIb0QYKVUs(vO4ucg6ylD4BIb2kFS0zF7zsxZUNt9AZdV)GleaKXBvrte1Fh8o1NCiI6wQ8eFWJ1mYo8OME7MxCucLzpppWHZ9bNAwUIdL5x)TI43WVld6)pWFllLtgQY9vxjXgLPKT7CO7pbpm4F8OHLPwzGLQwvpqpMSnGfnuTC(O7(D0LQPPvOCSqPaCxYGdOZgVjj8RhO2rW3YOc4LiEIWHEZ9MxF8Lzz1KzVm2NSp64Bljmx1oU0O4C(WL5CHllsrroKx4jtr4kLEW1woEGRvgOgXdEKepLV)gA8OeHaaT8oWMH741l3G1PWfP24ES(9ZijF0nE)EosGpAaFQP5QI5VySu6Pa5acQMKJnhLqT0TYVe)oQUC0U83baPTWhkeIU6f0V9DLdC1jgqLNt9BZB2vU1TM9czZCTSg9rAzfCvB1FMu6QfwN3wodJM5TXvFnaIqYlQOEp3T2OXzyw1d50(hPPyoFwkVCOPKiQSFfo0e2qcMOA2dBUJf5S5ljGVda5DeXtAp6FagYlIombMceWUJAslypBpS5)n(8NXjYqimHsCHRVsFGrL7zly7Hp8JJpHff4VMHhsa9V2Ay0qHG8cSNeq5JMjDZWaHGr9rupeCKF055Y59PiUGfK5ia4sWzEXrCTm2TJ6KnhP0(qdqsLCc4zn1g0D9SwQfTXfTHx7GNcIwMDawbpKQSSfSFr9vJtR0OehWTZ4pJoByYwWXYHrHfqxe5a4iQK(cllMpfUtnu7jHMmckNkVipwqjbf5jsUaTeNCyBjKVUx()hZXjo6mk(dyPJC4C8z9)9d