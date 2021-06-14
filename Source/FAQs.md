The first thing I recommend you to do if you have any troubles with Threat Plates is to enable WoW to show Lua errors.
Sometimes there's a bug in Threat Plates that results is such an error. But by default WoW suppresses these error
messages which results in Threat Plates not being active, i.e., no nameplates showing or only the Blizzard default ones.
You can use this script to turn them on and off:

    /run if GetCVar("ScriptErrors")=="1" then SetCVar("ScriptErrors","0");print("Show LUA Errors: Off");else SetCVar("ScriptErrors","1");print("Show LUA Errors: On");end

(
from [https://eu.battle.net/forums/en/wow/topic/17612801204#post-8](https://eu.battle.net/forums/en/wow/topic/17612801204#post-8))

# WoW Retail

* ### How do I hide nameplates of units that are behind walls or on another level of a building (e.g., in Tol Dagor)?

  There is an option under General - Transparency to adjust the transparency of the nameplates of occluded units (e.g.,
  units behind walls) or even hide them (by setting the transparency to 100%). As there is no direct way for an addon to
  determine if a unit is visible or not, it uses the CVar nameplateOccludedAlphaMult. So, please be aware that this might
  have side effects with other addons if they use and change this CVar.

* ### When I target a unit, its nameplate moves slightly upwards or downwards.

  The positioning of nameplates is controlled by WoW itself and Threat Plates nameplates are anchored to the (invisible)
  Blizzard nameplates. So, if there's a CVar setting that would change the position of the Blizzard nameplate, Threat
  Plates nameplates will also move. Here are two CVars that do that: nameplateSelectedScale, nameplateMinScale. If you
  change them to their default values (1), the nameplates will stop moving when you target units.

* ### Since 8.6.0, units have double nameplates, one looking like Threat Plates and the others looking like some other theme of Tidy Plates, e.g., Neon.

  Since Version 8.6.0, TPTP is a standalone addon that no longer requires TidyPlates. Please enable only one of these two
  nameplate addons, otherwise two overlapping nameplates will be shown for units.

  Tidy Plates is no longer actively developed and more and more bugs stay unfixed. Some I could work around, but it got
  more difficult every time. So I decided to make TPTP a standalone addon by integrating all necessary Tidy Plate code.

  When you start 8.6.0 the first time you should get a popup dialog that tells you what I wrote above.

* ### I want my (target) nameplate to stick at the top (or bottom) of the screen and not to disapear outside of the screen, especially for huge bosses.

  This behaviour is controlled by certain CVars from WoW which are not accessible using the default Interfaces options.
  Right now, there are also no options in ThreatPlates to make this changes directly.

  The CVars you have to to change are: nameplateOtherTopInset and nameplateOtherBottomInset (and/or nameplateLargeTopInset
  and nameplateLargeBottomInset, if you are using large nameplates).

  To keep the nameplates from moving outside of the screen, you have to change them to something like .1 or .05. The value
  defines the width (in percentage of screen size) of the area around the screen border into which nameplates will not
  move. The bigger the percentage, the farther the nameplates stay away from the border of the screen. Setting the CVar to
  -1 will allow nameplates to move outside of the screen again.

  I recommend using the addon AdvancedInterfaceOptions to change the CVars. But you can also change them in-game using the
  /run command, e.g., "/run SetCVar("nameplateOtherTopInset ", 0.05)" or the /console command, e.g., "/console
  nameplateOtherTopInset 0.05".

* ### After installing 8.4.0 (and clicking "Switch" on the dialog that popped up), my Threat Plates look all different. Any way to get the classic look and feel back?

  Open the options dialog with /tptp, then go to "Nameplate Settings - Healthbar View - Default Settings" and change Look
  and Feel back to "Classic".

* ### In instances (dungeons or raids and also the Garrison), friendly namplates look differently (like the default Blizzard nameplates).

  Since release 7.2, the ability for addons to modify the appearance of friendly nameplates while inside dungeon and raid
  instances is disabled. You can read the orignal post by Blizzard here. You have to live with the standard Blizzard
  namplates in that situations. Nothing we can do about that.

* ### Interface options of TidyPlates say "It appears that you're not using a Hub-compatible Theme." when ThreatPlates is selected as theme.

  This is totally ok and no problem at all. It just means that ThreatPlates does not support TidyPlates' way of
  configuration a thema (with /hub and the options show there). ThreatPlates has it's own options dialog opened with
  /tptp. Internally, this also means that ThreatPlates is not using the additional functionality of TidyPlatesHub, e.g.,
  for threat coloring or certain widgets, but uses its own implementation for this stuff.

* ### Only target namplate is shown, nothing else!

  By default, nameplates are only shown in combat or on the current target. Blizzard introduced this feature with Legion (
  7.0.3). You have to enable "Show all nameplates" in the options (Interface - Names) to enable nameplates out of combat.

* ### Namplates are only shown in combat and disapear out ouf combat.

  By default, nameplates are only shown in combat or on the current target. Blizzard introduced this feature with Legion (
  7.0.3). You have to enable "Show all nameplates" in the options (Interface - Names) to enable nameplates out of combat.

* ### Nameplates for friendly NPCs (and only them) are not shown.

  With release 7.1.0, Blizzard introduced a new CVar nameplateShowFriendlyNPCs which is disabled by default. You can
  enable it and enable nameplates for friendly targets with the following command:

        /run SetCVar("nameplateShowFriendlyNPCs",1)

  With ThreatPlates 8.3.0 (currently in Beta), there is an option (tab Nameplate Settings - General Settings - Blizzard
  Settings) to enable friendly NPC nameplates.

# WoW Classic

* ### Every time I try to increase the max distance up to which nameplates are shown, it reverts back down to 20

  In Classic, 20 is the hardcapped maximum value for max distance. There is no way to increase it beyond that.

* ### Quest icons are shown on all nameplates, not only on quest mobs.

  In the Classic version of Threat Plates, the Quest widget is disabled (in the sourcecode) and the ! icon was not shown
  by ThreatPlates in all reported cases, but by some other addons like Questie, Azeroth Auto Pilot or ClassicCodex, as
  they added their icon to the Threat Plates frame. Version 1.1.4 fixes this issue.

* ### Durations off buffs and debuffs on nameplates are missing or not correct.

  In WoW Classic, the game does not provide information about the (maximum and current) duration of buffs and debuffs. The
  library LibClassicDurations helps with that by providing an internal database of aura durations and monitoring the
  environment for newly applied auras. For long-running buffs and debuffs this does not work as they are applied outside
  of the range of LibClassicDurations so that their reminaing duration is unknown. For this reason, auras with a runtime
  with more than 30min are always shown without duration.
