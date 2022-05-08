local L = LibStub("AceLocale-3.0"):NewLocale("TidyPlatesThreat", "zhCN", false)
if not L then return end

L["  /tptpdps       Toggles DPS/Healing threat plates"] = "/tptpdps 切换显示 DPS/治疗仇恨系统的血条"
L["  /tptpol        Toggles nameplate overlapping"] = "/tptpol 切换开关血条重叠"
L["  /tptptank      Toggles Tank threat plates"] = "/tptptank 切换显示坦克仇恨值系统的血条"
L["  /tptptoggle    Toggle Role from one to the other"] = "/tptptoggle 切换成另一种角色职责"
L["  /tptpverbose   Toggles addon feedback text"] = "/tptpverbose 切换显示插件回报文字"
L["  <no option>             Displays options dialog"] = "<没有选项> 显示设定选项窗口"
L["  help                    Prints this help message"] = "help 显示此说明信息"
L["  legacy-custom-styles    Adds (legacy) default custom styles for nameplates that are deleted when migrating custom nameplates to the current format"] = "'传统自订样式' 会帮转移自订血条到新格式时所删除的血条加入预设的自订样式。"
--[[Translation missing --]]
L["  profile <name>          Switch the current profile to <name>"] = "  profile <name>          Switch the current profile to <name>"
--[[Translation missing --]]
L["  toggle-scripting        Enable or disable scripting support (for beta testing)"] = "  toggle-scripting        Enable or disable scripting support (for beta testing)"
--[[Translation missing --]]
L[" (Elite)"] = " (Elite)"
--[[Translation missing --]]
L[" (Rare Elite)"] = " (Rare Elite)"
--[[Translation missing --]]
L[" (Rare)"] = " (Rare)"
L[" options by typing: /tptp"] = "选项通过输入：/tptp"
L[" The change will be applied after you leave combat."] = "将会在战斗结束后套用更改。"
L[" to DPS."] = "输出"
L[" to tanking."] = "坦克"
--[[Translation missing --]]
L[ [=[

--

Backupiseasy

(Original author: Suicidal Katt - |cff00ff00Shamtasticle@gmail.com|r)]=] ] = [=[

--

Backupiseasy

(Original author: Suicidal Katt - |cff00ff00Shamtasticle@gmail.com|r)]=]
L[ [=[

Feel free to email me at |cff00ff00threatplates@gmail.com|r

--

Blacksalsify

(Original author: Suicidal Katt - |cff00ff00Shamtasticle@gmail.com|r)]=] ] = [=[

随时可以给我发邮件|cff00ff00threatplates@gmail.com|r

--

Blacksalsify

(最开始的作者: Suicidal Katt - |cff00ff00Shamtasticle@gmail.com|r)]=]
--[[Translation missing --]]
L[ [=[

--

Backupiseasy

(Original author: Suicidal Katt - |cff00ff00Shamtasticle@gmail.com|r)]=] ] = ""
--[[Translation missing --]]
L[ [=[

Feel free to email me at |cff00ff00threatplates@gmail.com|r

--

Blacksalsify

(Original author: Suicidal Katt - |cff00ff00Shamtasticle@gmail.com|r)]=] ] = ""
--[[Translation missing --]]
L["%s already anchored to %s"] = "%s already anchored to %s"
--[[Translation missing --]]
L["%s already anchored to %s."] = "%s already anchored to %s."
L[". You cannot use two custom nameplates with the same trigger. The imported custom nameplate will be disabled."] = "。同一个触发条件无法使用两个自订血条，导入的自订血条将会被停用。"
L["|cff00ff00High Threat|r"] = "|cff00ff00高仇恨|r"
L["|cff00ff00Low Threat|r"] = "|cff00ff00低仇恨|r"
L["|cff00ff00Tank|r"] = "|cff00ff00坦克|r"
L["|cff00ff00tanking|r"] = "|cff00ff00当前坦克|r"
L["|cff0faac8Off-Tank|r"] = "|cff0faac8副坦克|r"
L["|cff89f559 role.|r"] = "|cff89f559 角色.|r"
L["|cff89f559Additional options can be found by typing |r'/tptp'|cff89F559.|r"] = "|cff89f559可以通过输入 |r'/tptp'|cff89f559来找到剩余选项。|r"
L["|cff89f559Threat Plates:|r Welcome back |cff"] = "|cff89f559Threat Plates:|r 欢迎回来 |cff"
L["|cff89F559Threat Plates|r is no longer a theme of |cff89F559TidyPlates|r, but a standalone addon that does no longer require TidyPlates. Please disable one of these, otherwise two overlapping nameplates will be shown for units."] = "|cff89F559Threat Plates|r 已经不再是 |cff89F559TidyPlates|r 的外观主题，而是独立运作的插件，不再需要和TidyPlates一起使用。请载入其中一个血条插件即可，否则会同时显示两个重叠的血条。"
L["|cff89F559Threat Plates|r: DPS switch detected, you are now in your |cffff0000dpsing / healing|r role."] = "|cff89F559Threat Plates|r:检测到DPS, 你现在是|cffff0000输出/治疗|r角色."
--[[Translation missing --]]
L["|cff89F559Threat Plates|r: No profile specified"] = "|cff89F559Threat Plates|r: No profile specified"
L["|cff89F559Threat Plates|r: Role toggle not supported because automatic role detection is enabled."] = "|cff89F559Threat Plates|r:角色切换不支持，因为你启用了角色自动检测。."
L["|cff89F559Threat Plates|r: Tank switch detected, you are now in your |cff00ff00tanking|r role."] = "|cff89F559Threat Plates|r:检测到坦克,你现在是|cff00ff00坦克|r角色."
--[[Translation missing --]]
L["|cff89F559Threat Plates|r: Unknown profile: "] = "|cff89F559Threat Plates|r: Unknown profile: "
L[ [=[|cff89f559Welcome to |r|cff89f559Threat Plates!
This is your first time using Threat Plates and you are a(n):
|r|cff]=] ] = [=[|cff89f559欢迎使用 |r|cff89f559Threat Plates!
这是第一次使用Threat Plates，你是：
|r|cff]=]
--[[Translation missing --]]
L[ [=[|cff89f559Welcome to |r|cff89f559Threat Plates!
This is your first time using Threat Plates and you are a(n):
|r|cff]=] ] = ""
L["|cff89f559You are currently in your "] = "|cff89f559你目前在你的"
--[[Translation missing --]]
L[ [=[|cffFF0000DELETE CUSTOM NAMEPLATE|r
Are you sure you want to delete the selected custom nameplate?]=] ] = [=[|cffFF0000DELETE CUSTOM NAMEPLATE|r
Are you sure you want to delete the selected custom nameplate?]=]
--[[Translation missing --]]
L[ [=[|cffFF0000DELETE CUSTOM NAMEPLATE|r
Are you sure you want to delete the selected custom nameplate?]=] ] = ""
L["|cffff0000DPS/Healing|r"] = "|cffff0000输出/治疗|r"
L["|cffff0000dpsing / healing|r"] = "|cffff0000输出 / 治疗|r"
L["|cffff0000High Threat|r"] = "|cffff0000高仇恨|r"
--[[Translation missing --]]
L["|cffff0000IMPORTANT: Enabling this feature changes console variables (CVars) which will change the appearance of default Blizzard nameplates. Disabling this feature will reset these CVars to the original value they had when you enabled this feature.|r"] = "|cffff0000IMPORTANT: Enabling this feature changes console variables (CVars) which will change the appearance of default Blizzard nameplates. Disabling this feature will reset these CVars to the original value they had when you enabled this feature.|r"
L["|cffff0000Low Threat|r"] = "|cffff0000低仇恨|r"
--[[Translation missing --]]
L["|cffFF0000The Auras widget must be enabled (see Widgets - Auras) to use auras as trigger for custom nameplates.|r"] = "|cffFF0000The Auras widget must be enabled (see Widgets - Auras) to use auras as trigger for custom nameplates.|r"
--[[Translation missing --]]
L["|cffFFD100Current Instance:|r"] = "|cffFFD100Current Instance:|r"
L["|cffffff00Medium Threat|r"] = "|cffffff00中仇恨|r"
L["|cffffffffGeneral Settings|r"] = "|cffffffff主设置|r"
--[[Translation missing --]]
L["|cffffffffLow Threat|r"] = "|cffffffffLow Threat|r"
L["|cffffffffTotem Settings|r"] = "|cffffffff图腾设置|r"
L["-->>|cff00ff00Tank Plates Enabled|r<<--"] = "-->>|cff00ff00坦克姓名版开启|r<<--"
L["-->>|cffff0000DPS Plates Enabled|r<<--"] = "-->>|cff00ff00输出姓名版开启|r<<--"
L["-->>Nameplate Overlapping is now |cff00ff00ON!|r<<--"] = "-->>姓名板重叠现在 |cff00ff00开启！|r<<--"
L["-->>Nameplate Overlapping is now |cffff0000OFF!|r<<--"] = "-->>姓名板重叠现在 |cff00ff00关闭！|r<<--"
L["-->>Threat Plates verbose is now |cff00ff00ON!|r<<--"] = "-->>Threat Plates聊天框反馈信息现在 |cff00ff00开启！|r<<--"
L["-->>Threat Plates verbose is now |cffff0000OFF!|r<<-- shhh!!"] = "-->>Threat Plates聊天框反馈信息现在 |cffff0000关闭！|r<<--嘘！！"
--[[Translation missing --]]
L["A custom nameplate with these triggers already exists: %s. You cannot use two custom nameplates with the same trigger."] = "A custom nameplate with these triggers already exists: %s. You cannot use two custom nameplates with the same trigger."
--[[Translation missing --]]
L["A custom nameplate with these triggers already exists: %s. You cannot use two custom nameplates with the same trigger. The current custom nameplate was therefore disabled."] = "A custom nameplate with these triggers already exists: %s. You cannot use two custom nameplates with the same trigger. The current custom nameplate was therefore disabled."
--[[Translation missing --]]
L["A custom nameplate with this trigger already exists: "] = "A custom nameplate with this trigger already exists: "
--[[Translation missing --]]
L["A script has overwritten the global '%s'. This might affect other scripts ."] = "A script has overwritten the global '%s'. This might affect other scripts ."
L["A to Z"] = "A 到Z"
--[[Translation missing --]]
L["Abbreviation"] = "Abbreviation"
L["About"] = "关于"
L["Absolut Transparency"] = "绝对透明度"
L["Absorbs"] = "吸收盾"
L["Absorbs Text"] = "吸收盾文字"
L["Add black outline."] = "加上黑色外框。"
L["Add thick black outline."] = "加上粗的黑色外框。"
--[[Translation missing --]]
L["Adding legacy custom nameplate for %s ..."] = "Adding legacy custom nameplate for %s ..."
L["Additional Adjustments"] = "额外调节"
--[[Translation missing --]]
L["Additional chat commands:"] = "Additional chat commands:"
L["Additionally color the name based on the target mark if the unit is marked."] = "单位有标记图示时，依据图示类型额外调整名字颜色。"
L["Additionally color the nameplate's healthbar or name based on the target mark if the unit is marked."] = "单位有标记图示时，依据图示类型额外调整血条或名字颜色。"
--[[Translation missing --]]
L["Alignment"] = "Alignment"
L["All"] = "全部"
L["All on NPCs"] = "NPC 全部"
--[[Translation missing --]]
L["Allow"] = "Allow"
L["Alpha"] = "透明度"
--[[Translation missing --]]
L["Alpha multiplier of nameplates for occluded units."] = "Alpha multiplier of nameplates for occluded units."
--[[Translation missing --]]
L["Always"] = "Always"
--[[Translation missing --]]
L["Always Show Nameplates"] = "Always Show Nameplates"
L["Always shows the full amount of absorbs on a unit. In overabsorb situations, the absorbs bar ist shifted to the left."] = "永远显示单位的吸收盾总量。在过度吸收的情况下，吸收条会向左移动。"
--[[Translation missing --]]
L["Amount"] = "Amount"
--[[Translation missing --]]
L["Anchor"] = "Anchor"
L["Anchor Point"] = "锚点"
--[[Translation missing --]]
L["Anchor to"] = "Anchor to"
--[[Translation missing --]]
L["Animacharge"] = "Animacharge"
L["Appearance"] = "外观"
--[[Translation missing --]]
L["Apply these custom settings to a nameplate when a particular spell is cast by the unit. You can add multiple entries separated by a semicolon"] = "Apply these custom settings to a nameplate when a particular spell is cast by the unit. You can add multiple entries separated by a semicolon"
--[[Translation missing --]]
L["Apply these custom settings to the nameplate of a unit with a particular name. You can add multiple entries separated by a semicolon. You can use use * as wildcard character."] = "Apply these custom settings to the nameplate of a unit with a particular name. You can add multiple entries separated by a semicolon. You can use use * as wildcard character."
--[[Translation missing --]]
L["Apply these custom settings to the nameplate when a particular aura is present on the unit. You can add multiple entries separated by a semicolon."] = "Apply these custom settings to the nameplate when a particular aura is present on the unit. You can add multiple entries separated by a semicolon."
--[[Translation missing --]]
L["Arcane Mage"] = "Arcane Mage"
L["Arena"] = "竞技场"
L["Arena 1"] = "竞技场 1"
L["Arena 2"] = "竞技场 2"
L["Arena 3"] = "竞技场 3"
L["Arena 4"] = "竞技场 4"
L["Arena 5"] = "竞技场 5"
--[[Translation missing --]]
L["Arena Number"] = "Arena Number"
--[[Translation missing --]]
L["Arena Orb"] = "Arena Orb"
L["Army of the Dead Ghoul"] = "亡者军团食尸鬼"
--[[Translation missing --]]
L["Arrow"] = "Arrow"
--[[Translation missing --]]
L["Arrow (Legacy)"] = "Arrow (Legacy)"
L["Art Options"] = "艺术设置"
--[[Translation missing --]]
L["Attempt to register script for unknown WoW event \"%s\""] = "Attempt to register script for unknown WoW event \"%s\""
--[[Translation missing --]]
L["Attempt to register script for unknown WoW event '%s'"] = "Attempt to register script for unknown WoW event '%s'"
--[[Translation missing --]]
L["Aura"] = "Aura"
L["Aura Icon"] = "光环图示"
--[[Translation missing --]]
L["Aura: "] = "Aura: "
L["Auras"] = "光环"
--[[Translation missing --]]
L["Auras (Name or ID)"] = "Auras (Name or ID)"
L["Auras, Healthbar"] = "光环，血条"
--[[Translation missing --]]
L["Auto Sizing"] = "Auto Sizing"
--[[Translation missing --]]
L["Auto-Cast"] = "Auto-Cast"
--[[Translation missing --]]
L["Automatic Icon"] = "Automatic Icon"
L["Automation"] = "自动"
L["Background"] = "背景"
L["Background Color"] = "背景颜色"
L["Background Color:"] = "背景颜色:"
L["Background Texture"] = "背景纹理"
L["Background Transparency"] = "背景透明度"
--[[Translation missing --]]
L["Bar Background Color:"] = "Bar Background Color:"
L["Bar Border"] = "边框"
--[[Translation missing --]]
L["Bar Foreground Color"] = "Bar Foreground Color"
L["Bar Height"] = "条的高度"
L["Bar Limit"] = "条的界限"
L["Bar Mode"] = "条的风格"
--[[Translation missing --]]
L["Bar Style"] = "Bar Style"
L["Bar Width"] = "条的宽度"
--[[Translation missing --]]
L["Bars"] = "Bars"
--[[Translation missing --]]
L["Because of side effects with Blizzard nameplates, this function is disabled in instances or when Blizzard nameplates are used for friendly or neutral/enemy units (see General - Visibility)."] = "Because of side effects with Blizzard nameplates, this function is disabled in instances or when Blizzard nameplates are used for friendly or neutral/enemy units (see General - Visibility)."
L["Blizzard"] = "暴雪"
L["Blizzard Settings"] = "暴雪设定"
--[[Translation missing --]]
L["Block"] = "Block"
L["Bone Spike"] = "骨针"
L["Border"] = "边框"
L["Border Color:"] = "边框颜色："
L["Boss"] = "首领"
L["Boss Mods"] = "首领模块"
L["Bosses"] = "首领"
--[[Translation missing --]]
L["Both you and the other player are flagged for PvP."] = "Both you and the other player are flagged for PvP."
L["Bottom"] = "下"
L["Bottom Inset"] = "下方间距"
L["Bottom Left"] = "左下"
L["Bottom Right"] = "右下"
L["Bottom-to-top"] = "从下到上"
--[[Translation missing --]]
L["Boundaries"] = "Boundaries"
--[[Translation missing --]]
L["Bubble"] = "Bubble"
L["Buff Color"] = "增益颜色"
L["Buffs"] = "增益"
--[[Translation missing --]]
L["Button"] = "Button"
L["By Class"] = "职业"
L["By Custom Color"] = "自定义颜色"
--[[Translation missing --]]
L["By default, the threat system works based on a mob's threat table. Some mobs do not have such a threat table even if you are in combat with them. The threat detection heuristic uses other factors to determine if you are in combat with a mob. This works well in instances. In the open world, this can show units in combat with you that are actually just in combat with another player (and not you)."] = "By default, the threat system works based on a mob's threat table. Some mobs do not have such a threat table even if you are in combat with them. The threat detection heuristic uses other factors to determine if you are in combat with a mob. This works well in instances. In the open world, this can show units in combat with you that are actually just in combat with another player (and not you)."
L["By Health"] = "血量"
L["By Reaction"] = "互动关系"
L["Can Apply"] = "可施放"
L["Canal Crab"] = "运河蟹"
--[[Translation missing --]]
L["Cancel"] = "Cancel"
--[[Translation missing --]]
L["Cast"] = "Cast"
--[[Translation missing --]]
L["Cast Target"] = "Cast Target"
--[[Translation missing --]]
L["Cast Time"] = "Cast Time"
--[[Translation missing --]]
L["Cast Time Alignment"] = "Cast Time Alignment"
--[[Translation missing --]]
L["Cast: "] = "Cast: "
L["Castbar"] = "施法条"
--[[Translation missing --]]
L["Castbar, Healthbar"] = "Castbar, Healthbar"
L["Center"] = "居中"
L["Center Auras"] = "光环居中"
L["Change the color depending on the amount of health points the nameplate shows."] = "依据血条所显示的血量区间变换颜色。"
L["Change the color depending on the reaction of the unit (friendly, hostile, neutral)."] = "依据单位的互动关系 (友善、敌对、中立) 变换颜色。"
L["Change the scale of nameplates depending on whether a target unit is selected or not. As default, this scale is added to the unit base scale."] = "依据目标单位是否被选取来变化血条的缩放大小，预设会将这个值和单位基础缩放大小相加或相减。"
L["Change the scale of nameplates in certain situations, overwriting all other settings."] = "依据特定的情况来变化血条的缩放大小，会取代其他所有的设定。"
L["Change the transparency of nameplates depending on whether a target unit is selected or not. As default, this transparency is added to the unit base transparency."] = "依据目标单位是否被选取来变化血条的透明度，预设会将这个值和单位基础透明度相加或相减。"
--[[Translation missing --]]
L["Change the transparency of nameplates for occluded units (e.g., units behind walls)."] = "Change the transparency of nameplates for occluded units (e.g., units behind walls)."
L["Change the transparency of nameplates in certain situations, overwriting all other settings."] = "依据特定的情况来变化血条的透明度，会取代其他所有的设定。"
L["Changes the default settings to the selected design. Some of your custom settings may get overwritten if you switch back and forth.."] = "将预设值更改成所选择的外观设计，切换外观时有些自订的设定可能会被取代。"
L["Changing these options may interfere with other nameplate addons or Blizzard default nameplates as console variables (CVars) are changed."] = "更改这些选项可能会影响其他血条插件或游戏内建的名条，让使用到游戏控制参数 (CVars) 的设定一并变更。"
L["Changing these settings will alter the placement of the nameplates, however the mouseover area does not follow. |cffff0000Use with caution!|r"] = "改变这些选项将改变姓名板的位置，然而鼠标指向区域却不会随之改变。|cffff0000请谨慎使用！|r"
--[[Translation missing --]]
L["Clamp Target Nameplate to Screen"] = "Clamp Target Nameplate to Screen"
--[[Translation missing --]]
L["Clamps the target's nameplate to the edges of the screen, even if the target is off-screen."] = "Clamps the target's nameplate to the edges of the screen, even if the target is off-screen."
--[[Translation missing --]]
L["Class"] = "Class"
--[[Translation missing --]]
L["Class Color for Players"] = "Class Color for Players"
L["Class Icon"] = "职业图标"
L[ [=[Clear and easy to use threat-reactive nameplates.

Current version: ]=] ] = [=[简单好用又清楚，能与仇恨值互动的血条。

当前版本: ]=]
--[[Translation missing --]]
L[ [=[Clear and easy to use threat-reactive nameplates.

Current version: ]=] ] = ""
L["Clickable Area"] = "可点击区域"
L["Color"] = "颜色"
L["Color By Class"] = "职业颜色"
L["Color by Dispel Type"] = "显示类型颜色"
L["Color by Health"] = "血量颜色"
L["Color by Reaction"] = "互动关系颜色"
L["Color by Target Mark"] = "标记图示颜色"
L["Color Healthbar By Enemy Class"] = "血条显示敌方职业颜色"
L["Color Healthbar By Friendly Class"] = "血条显示友方职业颜色"
L["Color Healthbar by Target Marks in Healthbar View"] = "血条检视时，血条显示标记图示颜色。"
L["Color Name by Target Marks in Headline View"] = "名字检视时，名字显示标记图示颜色。"
L["Coloring"] = "颜色"
L["Colors"] = "颜色"
L["Column Limit"] = "列限制"
L["Combat"] = "战斗"
L["Combo Points"] = "连击点"
L["Configuration Mode"] = "设定模式"
L["Controls the rate at which nameplate animates into their target locations [0.0-1.0]."] = "血条移动到最终位置的动画速度 [0.0-1.0]。"
L["Cooldown Spiral"] = "冷却漩涡"
L["Copy"] = "复制"
L["Creation"] = "创建"
--[[Translation missing --]]
L["Crescent"] = "Crescent"
L["Crowd Control"] = "控场"
L["Curse"] = "诅咒"
L["Custom"] = "自定义"
L["Custom Color"] = "自定义颜色"
--[[Translation missing --]]
L["Custom Enemy Status Text"] = "Custom Enemy Status Text"
--[[Translation missing --]]
L["Custom Friendly Status Text"] = "Custom Friendly Status Text"
L["Custom Nameplates"] = "自定义姓名版"
--[[Translation missing --]]
L["Custom status text requires LibDogTag-3.0 to function."] = "Custom status text requires LibDogTag-3.0 to function."
--[[Translation missing --]]
L["Custom status text requires LibDogTag-Unit-3.0 to function."] = "Custom status text requires LibDogTag-Unit-3.0 to function."
--[[Translation missing --]]
L["CVar \"%s\" has an invalid value: \"%s\". The value must be a number. Using the default value for this CVar instead."] = "CVar \"%s\" has an invalid value: \"%s\". The value must be a number. Using the default value for this CVar instead."
--[[Translation missing --]]
L["Cyclic anchoring of aura areas to each other is not possible."] = "Cyclic anchoring of aura areas to each other is not possible."
L["Darnavan"] = "达尔纳文"
--[[Translation missing --]]
L["Death Knigh Rune Cooldown"] = "Death Knigh Rune Cooldown"
--[[Translation missing --]]
L["Death Knight"] = "Death Knight"
L["Debuff Color"] = "减益颜色"
L["Debuffs"] = "减益"
--[[Translation missing --]]
L["Default"] = "Default"
L["Default Settings (All Profiles)"] = "默认设置(所有角色)"
L["Deficit"] = "损失血量"
L["Define a custom color for this nameplate and overwrite any other color settings."] = "设定这个血条的自订颜色，并且取代其他所有的颜色设定。"
L["Define a custom scaling for this nameplate and overwrite any other scaling settings."] = "设定这个血条的自订缩放大小，并且取代其他所有的缩放大小设定。"
--[[Translation missing --]]
L[ [=[Define a custom status text using LibDogTag markup language.

Type /dogtag for tag info.

Remember to press ENTER after filling out this box or it will not save.]=] ] = [=[Define a custom status text using LibDogTag markup language.

Type /dogtag for tag info.

Remember to press ENTER after filling out this box or it will not save.]=]
--[[Translation missing --]]
L[ [=[Define a custom status text using LibDogTag markup language.

Type /dogtag for tag info.

Remember to press ENTER after filling out this box or it will not save.]=] ] = ""
L["Define a custom transparency for this nameplate and overwrite any other transparency settings."] = "自订这个血条的透明度，并且取代其他所有透明度的设定。"
L["Define base alpha settings for various unit types. Only one of these settings is applied to a unit at the same time, i.e., they are mutually exclusive."] = "设定多种单位类型的基础透明度。一次只会套用一种设定到单位，也就是说，它们不会同时套用。"
L["Define base scale settings for various unit types. Only one of these settings is applied to a unit at the same time, i.e., they are mutually exclusive."] = "设定多种单位类型的基础缩放大小。一次只会套用一种设定到单位，也就是说，它们不会同时套用。"
L["Defines the movement/collision model for nameplates."] = "血条的移动/排列方式。"
L["Deformed Fanatic"] = "畸形的狂热者"
--[[Translation missing --]]
L["Delete"] = "Delete"
--[[Translation missing --]]
L["Delta Percentage"] = "Delta Percentage"
--[[Translation missing --]]
L["Delta Threat Value"] = "Delta Threat Value"
--[[Translation missing --]]
L["Detailed Percentage"] = "Detailed Percentage"
L["Determine your role (tank/dps/healing) automatically based on current spec."] = "根据当前天赋自动切换你的角色(坦克/输出/治疗)"
--[[Translation missing --]]
L["Determine your role (tank/dps/healing) automatically based on current stance (Warrior) or form (Druid)."] = "Determine your role (tank/dps/healing) automatically based on current stance (Warrior) or form (Druid)."
--[[Translation missing --]]
L["Disable"] = "Disable"
L["Disable threat scale for target marked, mouseover or casting units."] = "停用被标记图示、鼠标指向或正在施法单位的仇恨值缩放大小变化。"
L["Disable threat transparency for target marked, mouseover or casting units."] = "停用被标记图示、鼠标指向或正在施法单位的仇恨值透明度变化。"
L["Disables nameplates (healthbar and name) for the units of this type and only shows an icon (if enabled)."] = "启用时，停用这种单位类型的名条 (名字和血条)，只显示图示。"
L["Disabling this will turn off all icons for custom nameplates without harming other custom settings per nameplate."] = "停用时，会关闭自订血条的所有图示，但是不会影响每个血条的其他自订设定。"
--[[Translation missing --]]
L["Disconnected"] = "Disconnected"
L["Disconnected Units"] = "离线的单位"
L["Disease"] = "疾病"
L["Dispel Type"] = "驱散类型"
L["Dispellable"] = "可驱散"
L["Display absorbs amount text."] = "显示吸收盾数值文字。"
L["Display absorbs percentage text."] = "显示吸收盾百分比文字。"
L["Display health amount text."] = "显示血量值文字。"
L["Display health percentage text."] = "显示血量百分比文字。"
--[[Translation missing --]]
L["Display health text on units with full health."] = "Display health text on units with full health."
L["Distance"] = "视野距离"
--[[Translation missing --]]
L["Do not show buffs with unlimited duration."] = "Do not show buffs with unlimited duration."
L["Do not sort auras."] = "不要排序光环。"
--[[Translation missing --]]
L["Done"] = "Done"
--[[Translation missing --]]
L["Don't Ask Again"] = "Don't Ask Again"
--[[Translation missing --]]
L["Down Arrow"] = "Down Arrow"
L["DPS/Healing"] = "输出/治疗"
L["Drudge Ghoul"] = "食尸鬼苦工"
L["Druid"] = "德鲁伊"
--[[Translation missing --]]
L["Duplicate"] = "Duplicate"
L["Duration"] = "持续时间"
L["Ebon Gargoyle"] = "黑锋石像鬼"
L["Edge Size"] = "边缘大小"
L["Elite Border"] = "显示精英单位边框"
L["Empowered Adherent"] = "亢奋的追随者"
L["Enable"] = "开启"
L["Enable Arena Widget"] = "启用竞技场套件"
L["Enable Auras Widget"] = "启用光环套件"
L["Enable Boss Mods Widget"] = "启用首领模块套件"
L["Enable Class Icon Widget"] = "启用职业图标套件"
L["Enable Combo Points Widget"] = "启用连击点套件"
L["Enable Custom Color"] = "启用自订颜色"
--[[Translation missing --]]
L["Enable Experience Widget"] = "Enable Experience Widget"
--[[Translation missing --]]
L["Enable Focus Widget"] = "Enable Focus Widget"
L["Enable Friends"] = "启用好友"
L["Enable Guild Members"] = "启用公会成员"
L["Enable Headline View (Text-Only)"] = "启用标题预览(只限文字)"
L["Enable Healer Tracker Widget"] = "启用治疗追踪套件"
L["Enable nameplate clickthrough for enemy units."] = "启用敌方血条的鼠标点击穿透。"
L["Enable nameplate clickthrough for friendly units."] = "启用友方血条的鼠标点击穿透。"
L["Enable Quest Widget"] = "启用任务部件"
L["Enable Resource Widget"] = "启用资源套件"
L["Enable Social Widget"] = "启用社交套件"
L["Enable Stealth Widget"] = "启用隐形套件"
--[[Translation missing --]]
L["Enable Target Widget"] = "Enable Target Widget"
--[[Translation missing --]]
L["Enable Text"] = "Enable Text"
--[[Translation missing --]]
L["Enable this custom nameplate for friendly units."] = "Enable this custom nameplate for friendly units."
--[[Translation missing --]]
L["Enable this custom nameplate for neutral and hostile units."] = "Enable this custom nameplate for neutral and hostile units."
--[[Translation missing --]]
L["Enable this custom nameplate in instances."] = "Enable this custom nameplate in instances."
--[[Translation missing --]]
L["Enable this custom nameplate out of instances (in the wider game world)."] = "Enable this custom nameplate out of instances (in the wider game world)."
--[[Translation missing --]]
L["Enable this if you want to show Blizzards special resources above the target nameplate."] = "Enable this if you want to show Blizzards special resources above the target nameplate."
L["Enable Threat Coloring of Healthbar"] = "启用仇恨值血条颜色"
L["Enable Threat Scale"] = "启用仇恨值缩放"
L["Enable Threat System"] = "启用仇恨系统"
L["Enable Threat Textures"] = "启用仇恨值材质"
L["Enable Threat Transparency"] = "启用仇恨值透明度"
L["Enemy Casting"] = "敌方施法"
L["Enemy Name Color"] = "敌方名字颜色"
L["Enemy NPCs"] = "敌方 NPC"
L["Enemy Players"] = "敌方玩家"
L["Enemy Status Text"] = "敌方状态文字"
L["Enemy Units"] = "敌方单位"
--[[Translation missing --]]
L["Enter an icon's name (with the *.blp ending), a spell ID, a spell name or a full icon path (using '\\' to separate directory folders)."] = "Enter an icon's name (with the *.blp ending), a spell ID, a spell name or a full icon path (using '\\' to separate directory folders)."
--[[Translation missing --]]
L["Error in event script '%s' of custom style '%s': %s"] = "Error in event script '%s' of custom style '%s': %s"
--[[Translation missing --]]
L["Event Name"] = "Event Name"
--[[Translation missing --]]
L["Events with Script"] = "Events with Script"
L["Everything"] = "全部"
--[[Translation missing --]]
L["Exchange"] = "Exchange"
--[[Translation missing --]]
L["Experience"] = "Experience"
--[[Translation missing --]]
L["Experience Text"] = "Experience Text"
--[[Translation missing --]]
L["Export"] = "Export"
--[[Translation missing --]]
L["Export all custom nameplate settings as string."] = "Export all custom nameplate settings as string."
--[[Translation missing --]]
L["Export Custom Nameplates"] = "Export Custom Nameplates"
--[[Translation missing --]]
L["Export profile"] = "Export profile"
--[[Translation missing --]]
L["Export the current profile into a string that can be imported by other players."] = "Export the current profile into a string that can be imported by other players."
--[[Translation missing --]]
L["Extend"] = "Extend"
L["Faction Icon"] = "阵营图示"
L["Fading"] = "淡出"
--[[Translation missing --]]
L["Failed to migrate the imported profile to the current settings format because of an internal error. Please report this issue at the Threat Plates homepage at CurseForge: "] = "Failed to migrate the imported profile to the current settings format because of an internal error. Please report this issue at the Threat Plates homepage at CurseForge: "
L["Fanged Pit Viper"] = "毒牙坑道蛇"
--[[Translation missing --]]
L["Filter"] = "Filter"
L["Filter by Spell"] = "技能过滤"
L["Filtered Auras"] = "过滤光环"
--[[Translation missing --]]
L["Find a suitable icon based on the current trigger. For Name trigger, the preview does not work. For multi-value triggers, the preview always is the icon of the first trigger entered."] = "Find a suitable icon based on the current trigger. For Name trigger, the preview does not work. For multi-value triggers, the preview always is the icon of the first trigger entered."
L["Five"] = "五"
L["Flash Time"] = "闪烁时间"
L["Flash When Expiring"] = "结束时闪烁"
--[[Translation missing --]]
L["Focus Highlight"] = "Focus Highlight"
--[[Translation missing --]]
L["Focus Only"] = "Focus Only"
L["Font"] = "字体"
L["Font Size"] = "字体大小"
--[[Translation missing --]]
L["Forbidden function or table called from script: %s"] = "Forbidden function or table called from script: %s"
L["Force View By Status"] = "依据状态强制使用这种检视模式"
L["Foreground"] = "前景"
L["Foreground Texture"] = "前景纹理"
L["Format"] = "样式"
L["Four"] = "四"
L["Frame Order"] = "框架顺序"
L["Friendly & Neutral Units"] = "友方 & 中立单位"
L["Friendly Casting"] = "友方施法"
L["Friendly Name Color"] = "友方名字颜色"
L["Friendly Names Color"] = "友方名字颜色"
L["Friendly NPCs"] = "友方 NPC"
L["Friendly Players"] = "友方玩家"
--[[Translation missing --]]
L["Friendly PvP On"] = "Friendly PvP On"
L["Friendly Status Text"] = "友方状态文字"
L["Friendly Units"] = "友方单位"
L["Friendly Units in Combat"] = "友方单位战斗中"
L["Friends & Guild Members"] = "好友 & 公会成员"
L["Full Absorbs"] = "完整吸收盾"
L["Full Health"] = "满血"
--[[Translation missing --]]
L["Full Name"] = "Full Name"
--[[Translation missing --]]
L["Function"] = "Function"
L["Gas Cloud"] = "毒气之云"
L["General"] = "通用"
L["General Colors"] = "通用颜色"
L["General Nameplate Settings"] = "通用血条设定"
L["General Settings"] = "主设置"
--[[Translation missing --]]
L["Glow"] = "Glow"
--[[Translation missing --]]
L["Glow Color"] = "Glow Color"
--[[Translation missing --]]
L["Glow Frame"] = "Glow Frame"
--[[Translation missing --]]
L["Glow Type"] = "Glow Type"
L["Guardians"] = "守护者"
L["Headline View"] = "名字检视"
L["Headline View Out of Combat"] = "非战斗中使用名字检视"
L["Headline View X"] = "名字检视的水平位置"
L["Headline View Y"] = "名字检视的垂直位置"
--[[Translation missing --]]
L["Heal Absorbs"] = "Heal Absorbs"
L["Healer Tracker"] = "追踪治疗"
L["Health"] = "生命值"
L["Health Coloring"] = "血量颜色"
L["Health Text"] = "血量文字"
L["Healthbar"] = "血条"
L["Healthbar Mode"] = "血条模式"
L["Healthbar Sync"] = "和血条一致"
L["Healthbar View"] = "血条检视"
L["Healthbar View X"] = "血条检视的水平位置"
L["Healthbar View Y"] = "血条检视的垂直位置"
L["Healthbar, Auras"] = "血条，光环"
--[[Translation missing --]]
L["Healthbar, Castbar"] = "Healthbar, Castbar"
L["Height"] = "高度"
--[[Translation missing --]]
L["Heuristic"] = "Heuristic"
--[[Translation missing --]]
L["Heuristic In Instances"] = "Heuristic In Instances"
L["Hide Buffs"] = "隐藏增益"
L["Hide Friendly Nameplates"] = "隐藏友方姓名版"
L["Hide Healthbars"] = "隐藏血条"
L["Hide in Combat"] = "战斗中隐藏"
L["Hide in Instance"] = "副本中隐藏"
L["Hide Name"] = "隐藏名字"
L["Hide Nameplate"] = "隐藏姓名版"
L["Hide Nameplates"] = "隐藏姓名版"
L["Hide on Attacked Units"] = "受单位攻击时隐藏"
L["Hide the Blizzard default nameplates for friendly units in instances."] = "副本中隐藏暴雪自带的友方姓名版"
L["High Threat"] = "高仇恨"
--[[Translation missing --]]
L["Highlight"] = "Highlight"
L["Highlight Mobs on Off-Tanks"] = "显著标记副坦克的怪"
L["Highlight Texture"] = "显著标示材质"
L["Horizontal Align"] = "水平定位"
L["Horizontal Alignment"] = "水平对齐"
L["Horizontal Offset"] = "水平位置"
L["Horizontal Overlap"] = "水平重叠/间距"
L["Horizontal Spacing"] = "水平间距"
L["Hostile NPCs"] = "敌对npc"
L["Hostile Players"] = "敌对玩家"
--[[Translation missing --]]
L["Hostile PvP On - Self Off"] = "Hostile PvP On - Self Off"
--[[Translation missing --]]
L["Hostile PvP On - Self On"] = "Hostile PvP On - Self On"
L["Hostile Units"] = "敌对单位"
L["Icon"] = "图标"
L["Icon Height"] = "图标高度"
L["Icon Mode"] = "图标风格"
L["Icon Style"] = "图标样式"
L["Icon Width"] = "图标宽度"
--[[Translation missing --]]
L["Icons"] = "Icons"
L["If checked, nameplates of mobs attacking another tank can be shown with different color, scale, and transparency."] = "启动时，正在攻击另一名坦克的怪血条可以显示不同的颜色，缩放大小和透明度"
L["If checked, threat feedback from boss level mobs will be shown."] = "启动时，首领级别的怪会显示仇恨系统的变化"
L["If checked, threat feedback from elite and rare mobs will be shown."] = "启动时，精英和稀有级别的怪会显示仇恨系统的变化"
L["If checked, threat feedback from minor mobs will be shown."] = "启动时，小怪会显示仇恨系统的变化"
L["If checked, threat feedback from neutral mobs will be shown."] = "启动时，中立怪会显示仇恨系统的变化"
L["If checked, threat feedback from normal mobs will be shown."] = "启动时，普通怪会显示仇恨系统的变化"
L["If checked, threat feedback from tapped mobs will be shown regardless of unit type."] = "启动时，灰色血条（无效）的怪会显示仇恨系统的变化"
L["If checked, threat feedback will only be shown in instances (dungeons, raids, arenas, battlegrounds), not in the open world."] = "启动时，只有在副本中 (5人本、团本、竞技场、战场) 才会显示仇恨值系统的变化，在野外不会。"
L["If enabled, the truncated health text will be localized, i.e. local metric unit symbols (like k for thousands) will be used."] = "启动时，简短血量文字会使用中文数字单位 (万 或 亿)。"
L["Ignore Marked Units"] = "忽略被标记的单位"
--[[Translation missing --]]
L["Ignore PvP Status"] = "Ignore PvP Status"
L["Ignore UI Scale"] = "忽略ui缩放"
--[[Translation missing --]]
L["Illegal character used in Name trigger at position: "] = "Illegal character used in Name trigger at position: "
L["Immortal Guardian"] = "不朽守护者"
--[[Translation missing --]]
L["Import a profile from another player from an import string."] = "Import a profile from another player from an import string."
--[[Translation missing --]]
L["Import and export profiles to share them with other players."] = "Import and export profiles to share them with other players."
--[[Translation missing --]]
L["Import custom nameplate settings from a string. The custom namneplates will be added to your current custom nameplates."] = "Import custom nameplate settings from a string. The custom namneplates will be added to your current custom nameplates."
--[[Translation missing --]]
L["Import Custom Nameplates"] = "Import Custom Nameplates"
--[[Translation missing --]]
L["Import profile"] = "Import profile"
--[[Translation missing --]]
L["Import/Export Profile"] = "Import/Export Profile"
L["In Combat"] = "战斗中"
--[[Translation missing --]]
L["In combat, always show all combo points no matter if they are on or off. Off combo points are shown greyed-out."] = "In combat, always show all combo points no matter if they are on or off. Off combo points are shown greyed-out."
L["In combat, use coloring, transparency, and scaling based on threat level as configured in the threat system. Custom settings are only used out of combat."] = "战斗中使用仇恨值系统中的设定，依据仇恨程度变化颜色、透明度和缩放大小。只有在非战斗中才使用自定义的设定。"
--[[Translation missing --]]
L["In delta mode, show the name of the player who is second in the enemy unit's threat table."] = "In delta mode, show the name of the player who is second in the enemy unit's threat table."
--[[Translation missing --]]
L["In Groups"] = "In Groups"
L["In Instances"] = "副本内"
--[[Translation missing --]]
L["Initials"] = "Initials"
--[[Translation missing --]]
L["Insert a new custom nameplate slot after the currently selected slot."] = "Insert a new custom nameplate slot after the currently selected slot."
--[[Translation missing --]]
L["Inset"] = "Inset"
L["Insets"] = "不要超出画面"
L["Inside"] = "内侧"
--[[Translation missing --]]
L["Instance IDs"] = "Instance IDs"
L["Instances"] = "副本"
L["Interrupt Overlay"] = "无法打断条纹材质"
L["Interrupt Shield"] = "无法打断盾牌图标"
L["Interruptable"] = "可打断"
L["Interrupted"] = "已打断"
L["Kinetic Bomb"] = "动力炸弹"
--[[Translation missing --]]
L["Label"] = "Label"
L["Label Text Offset"] = "标签文字偏移"
L["Large Bottom Inset"] = "大型的下方间距"
L["Large Top Inset"] = "大型的上方间距"
--[[Translation missing --]]
L["Last Word"] = "Last Word"
L["Layout"] = "布局"
L["Left"] = "左"
L["Left-to-right"] = "从左到右"
--[[Translation missing --]]
L["Legacy custom nameplate %s already exists. Skipping it."] = "Legacy custom nameplate %s already exists. Skipping it."
--[[Translation missing --]]
L["Less-Than Arrow"] = "Less-Than Arrow"
--[[Translation missing --]]
L["Level "] = "Level "
L["Level"] = "等级"
--[[Translation missing --]]
L["Level ??"] = "Level ??"
L["Level Text"] = "等级文字"
L["Lich King"] = "巫妖王"
L["Living Ember"] = "燃烧的余烬"
L["Living Inferno"] = "燃烧的炼狱火"
--[[Translation missing --]]
L["Localization"] = "Localization"
L["Look and Feel"] = "外观和风格"
L["Low Threat"] = "低仇恨"
L["Magic"] = "魔法"
L["Marked Immortal Guardian"] = "被标记的不朽守护者"
--[[Translation missing --]]
L["Max Alpha"] = "Max Alpha"
--[[Translation missing --]]
L["Max Auras"] = "Max Auras"
L["Max Distance"] = "最远距离"
L["Max Distance Behind Camera"] = "镜头后方的最远距离"
--[[Translation missing --]]
L["Max Health"] = "Max Health"
L["Medium Threat"] = "一般仇恨"
--[[Translation missing --]]
L["Metric Unit Symbols"] = "Metric Unit Symbols"
--[[Translation missing --]]
L["Min Alpha"] = "Min Alpha"
L["Mine"] = "我的"
L["Minions & By Status"] = "小怪 & 状态"
L["Minor"] = "小怪"
--[[Translation missing --]]
L["Minuss"] = "Minors"
L["Mode"] = "风格"
L["Mono"] = "单色"
L["Motion & Overlap"] = "移动 & 重叠"
L["Motion Speed"] = "移动速度"
L["Mouseover"] = "鼠标指向"
--[[Translation missing --]]
L["Move Down"] = "Move Down"
--[[Translation missing --]]
L["Move Up"] = "Move Up"
L["Movement Model"] = "血条排列类型"
L["Muddy Crawfish"] = "沾泥龙虾"
--[[Translation missing --]]
L["Mult for Occluded Units"] = "Mult for Occluded Units"
L["Name"] = "名字"
L["Nameplate Clickthrough"] = "血条穿透点击"
L["Nameplate clickthrough cannot be changed while in combat."] = "战斗中无法更改血条穿透点击。"
L["Nameplate Color"] = "姓名板颜色"
L["Nameplate Mode for Friendly Units in Combat"] = "战斗中友方单位的姓名版模式"
L["Nameplate Style"] = "姓名板风格"
L["Names"] = "名字"
--[[Translation missing --]]
L["Neutral"] = "Neutral"
L["Neutral NPCs"] = "中立 NPC"
L["Neutral Units"] = "中立单位"
--[[Translation missing --]]
L["Neutral Units & Minions"] = "Neutral Units & Minions"
--[[Translation missing --]]
L["Never"] = "Never"
--[[Translation missing --]]
L["New"] = "New"
L["No Outline, Monochrome"] = "无轮廓，单色"
L["No Target"] = "没有目标"
L["No target found."] = "未发现目标。"
L["None"] = "无"
L["Non-Interruptable"] = "无法打断"
L["Non-Target"] = "非当前目标"
L["Normal Units"] = "普通单位"
--[[Translation missing --]]
L["Not Myself"] = "Not Myself"
L["Note"] = "注意"
L["Nothing to paste!"] = "无可粘贴内容！"
L["NPC Role"] = "NPC 角色"
L["NPC Role, Guild"] = "NPC 角色、公会"
L["NPC Role, Guild, or Level"] = "NPC 角色、公会或等级"
--[[Translation missing --]]
L["NPCs"] = "NPCs"
--[[Translation missing --]]
L["Numbers"] = "Numbers"
L["Occluded Units"] = "被挡住的单位"
--[[Translation missing --]]
L["Off Combo Point"] = "Off Combo Point"
L["Offset"] = "偏移"
L["Offset X"] = "X轴偏移"
L["Offset Y"] = "Y轴偏移"
L["Off-Tank"] = "副坦克"
L["OmniCC"] = "OmniCC"
--[[Translation missing --]]
L["On & Off"] = "On & Off"
--[[Translation missing --]]
L["On Bosses & Rares"] = "On Bosses & Rares"
--[[Translation missing --]]
L["On Combo Point"] = "On Combo Point"
L["On Enemy Units You Cannot Attack"] = "无法攻击的敌方单位"
L["On Friendly Units in Combat"] = "战斗中的友方单位"
L["On Target"] = "当前目标"
--[[Translation missing --]]
L["On the left"] = "On the left"
L["One"] = "一"
L["Only Alternate Power"] = "只有首领战特殊能量"
--[[Translation missing --]]
L["Only for Target"] = "Only for Target"
--[[Translation missing --]]
L["Only In Combat"] = "Only In Combat"
--[[Translation missing --]]
L["Only in Groups"] = "Only in Groups"
L["Only in Instances"] = "只在副本内"
--[[Translation missing --]]
L["Only Mine"] = "Only Mine"
L["Onyxian Whelp"] = "奥妮克希亚雏龙"
L["Open Blizzard Settings"] = "打开Blizzard设置"
L["Open Options"] = "开启设定选项"
L["options:"] = "选项："
--[[Translation missing --]]
L["Orbs"] = "Orbs"
L["Out of Combat"] = "战斗外"
--[[Translation missing --]]
L["Out Of Instances"] = "Out Of Instances"
L["Outline"] = "轮廓"
L["Outline, Monochrome"] = "轮廓，单色"
L["Overlapping"] = "重叠"
--[[Translation missing --]]
L["Paladin"] = "Paladin"
L["Paste"] = "粘贴"
--[[Translation missing --]]
L["Paste the Threat Plates profile string into the text field below and then close the window"] = "Paste the Threat Plates profile string into the text field below and then close the window"
L["Percentage"] = "百分比"
--[[Translation missing --]]
L["Percentage - Raw"] = "Percentage - Raw"
--[[Translation missing --]]
L["Percentage - Scaled"] = "Percentage - Scaled"
L["Percentage amount for horizontal overlap of nameplates."] = "血条之间水平重叠距离的百分比。"
L["Percentage amount for vertical overlap of nameplates."] = "血条之间垂直重叠距离的百分比。"
L["Personal Nameplate"] = "个人资源条"
L["Pets"] = "宠物"
--[[Translation missing --]]
L["Pixel"] = "Pixel"
L["Pixel-Perfect UI"] = "完全符合屏幕像素"
L["Placement"] = "位置"
--[[Translation missing --]]
L["Players"] = "Players"
L["Poison"] = "中毒"
L["Position"] = "中毒"
--[[Translation missing --]]
L["Positioning"] = "Positioning"
L["Preview"] = "预览"
L["Preview Elite"] = "预览精英怪"
L["Preview Rare"] = "预览稀有怪"
--[[Translation missing --]]
L["Preview Rare Elite"] = "Preview Rare Elite"
--[[Translation missing --]]
L["PvP Off"] = "PvP Off"
L["Quest"] = "任务"
L["Quest Progress"] = "任务进度"
L["Raging Spirit"] = "暴怒的灵魂"
--[[Translation missing --]]
L["Rank Text"] = "Rank Text"
L["Rares & Bosses"] = "稀有怪 & 首领"
L["Rares & Elites"] = "稀有怪 & 精英"
--[[Translation missing --]]
L["Raw Percentage"] = "Raw Percentage"
--[[Translation missing --]]
L["Reaction"] = "Reaction"
L["Reanimated Adherent"] = "被复活的追随者"
L["Reanimated Fanatic"] = "被复活的狂热者"
L["Render font without antialiasing."] = "文字不要消除锯齿。"
L["Reset"] = "重置"
L["Reset to Defaults"] = "还原默认值"
L["Resource"] = "资源"
L["Resource Bar"] = "资源条"
L["Resource Text"] = "资源文字"
--[[Translation missing --]]
L["Resources on Targets"] = "Resources on Targets"
L["Reverse"] = "反向排序"
L["Reverse the sort order (e.g., \"A to Z\" becomes \"Z to A\")."] = "颠倒排列顺序(例如，\"A 到 Z\" 变成 \"Z 到 A\")。"
L["Right"] = "右"
L["Right-to-left"] = "从右到左"
L["Rogue"] = "潜行者"
--[[Translation missing --]]
L["Roles"] = "Roles"
L["Row Limit"] = "排限制"
L["Same as Background"] = "和背景相同"
--[[Translation missing --]]
L["Same as Bar Foreground"] = "Same as Bar Foreground"
L["Same as Foreground"] = "和前景相同"
L["Same as Name"] = "和名字相同"
L["Scale"] = "缩放"
--[[Translation missing --]]
L["Scaled Percentage"] = "Scaled Percentage"
--[[Translation missing --]]
L["Scaled Percentage Delta"] = "Scaled Percentage Delta"
--[[Translation missing --]]
L["Scriping for custom styles for nameplates is now |cff00ff00enabled!|r."] = "Scriping for custom styles for nameplates is now |cff00ff00enabled!|r."
--[[Translation missing --]]
L["Scriping for custom styles for nameplates is now |cffff0000disabled!|r."] = "Scriping for custom styles for nameplates is now |cffff0000disabled!|r."
--[[Translation missing --]]
L["Script"] = "Script"
--[[Translation missing --]]
L["Scripts"] = "Scripts"
--[[Translation missing --]]
L["Second Player"] = "Second Player"
--[[Translation missing --]]
L["Second Player's Name"] = "Second Player's Name"
L["Set Icon"] = "设置图标"
L["Set scale settings for different threat levels."] = "替不同的仇恨程度设定缩放大小。"
L["Set the roles your specs represent."] = "设置你的角色天赋代表"
L["Set threat textures and their coloring options here."] = "在这里设置仇恨的材质与它们的颜色选项"
L["Set transparency settings for different threat levels."] = "替不同的仇恨程度设定透明度。"
--[[Translation missing --]]
L["Sets your role to DPS."] = "Sets your role to DPS."
--[[Translation missing --]]
L["Sets your role to tanking."] = "Sets your role to tanking."
L["Sets your spec "] = "设置你的天赋"
L["Shadow"] = "阴影"
L["Shadow Fiend"] = "暗影魔"
L["Shadowy Apparition"] = "暗影幻灵"
L["Shambling Horror"] = "蹒跚的血僵尸"
--[[Translation missing --]]
L["Shorten"] = "Shorten"
--[[Translation missing --]]
L["Show"] = "Show"
L["Show a tooltip when hovering above an aura."] = "鼠标指向光环时显示提示说明"
L["Show all buffs on enemy units."] = "显示敌方单位身上全部的增益效果。"
L["Show all buffs on friendly units."] = "显示友方单位身上全部的增益效果。"
L["Show all buffs on NPCs."] = "显示NPC身上全部的增益效果。"
L["Show all crowd control auras on enemy units."] = "显示敌方单位身上全部的控场效果光环。"
L["Show all crowd control auras on friendly units."] = "显示友方单位身上全部的控场效果光环。"
L["Show all debuffs on enemy units."] = "显示敌方单位身上全部的减益效果。"
L["Show all debuffs on friendly units."] = "显示友方单位身上全部的减益效果。"
--[[Translation missing --]]
L["Show All Nameplates (Friendly and Enemy Units) (CTRL-V)"] = "Show All Nameplates (Friendly and Enemy Units) (CTRL-V)"
--[[Translation missing --]]
L["Show Always"] = "Show Always"
L["Show an quest icon at the nameplate for quest mobs."] = "任务怪的血条上方显示任务图标。"
L["Show auras as bars (with optional icons)."] = "显示条上光环(可选图标)。"
L["Show auras as icons in a grid configuration."] = "显示光环图标在团队配置。"
L["Show auras in order created with oldest aura first."] = "以旧光环为第一的顺序显示光环"
L["Show Blizzard Nameplates for Friendly Units"] = "友方单位显示游戏内置的血条"
L["Show Blizzard Nameplates for Neutral and Enemy Units"] = "中立和敌对单位显示游戏默认的姓名版"
L["Show Buffs"] = "显示增益效果"
--[[Translation missing --]]
L["Show buffs of dispell type Magic."] = "Show buffs of dispell type Magic."
L["Show buffs that were applied by you."] = "显示由你施放的增益效果."
L["Show buffs that you can apply."] = "显示你可以施放的增益效果。"
L["Show buffs that you can dispell."] = "显示你可以驱散的增益效果。"
--[[Translation missing --]]
L["Show buffs with unlimited duration in all situations (e.g., in and out of combat)."] = "Show buffs with unlimited duration in all situations (e.g., in and out of combat)."
L["Show By Unit Type"] = "依据单位类型显示"
L["Show Crowd Control"] = "显示控场"
L["Show crowd control auras hat are shown on Blizzard's default nameplates."] = "显示游戏内置血条会显示出的控场效果光环。"
L["Show crowd control auras that are shown on Blizzard's default nameplates."] = "显示游戏内置血条会显示出的控场效果光环。"
L["Show crowd control auras that where applied by bosses."] = "显示首领施放的控场效果光环。"
L["Show crowd control auras that you can dispell."] = "显示你可以驱散的控场效果光环。"
L["Show Debuffs"] = "显示减益效果"
L["Show debuffs that are shown on Blizzard's default nameplates."] = "显示游戏内置血条会显示出的减益效果。"
L["Show debuffs that were applied by you."] = "显示你施放的减益效果。"
L["Show debuffs that where applied by bosses."] = "显示首领施放的减益效果。"
L["Show debuffs that you can dispell."] = "显示你可以驱散的减益效果。"
--[[Translation missing --]]
L["Show Enemy Nameplates (ALT-V)"] = "Show Enemy Nameplates (ALT-V)"
--[[Translation missing --]]
L["Show Enemy Units"] = "Show Enemy Units"
--[[Translation missing --]]
L["Show Focus"] = "Show Focus"
L["Show For"] = "显示"
--[[Translation missing --]]
L["Show Friendly Nameplates (SHIFT-V)"] = "Show Friendly Nameplates (SHIFT-V)"
--[[Translation missing --]]
L["Show Friendly Units"] = "Show Friendly Units"
L["Show Health Text"] = "显示血量文字"
L["Show Icon for Rares & Elites"] = "显示稀有怪 & 精英怪图标"
L["Show Icon to the Left"] = "显示图标在左侧"
L["Show in Headline View"] = "名字检视时要显示"
L["Show in Healthbar View"] = "血条检视时要显示"
L["Show Level Text"] = "显示等级文字"
L["Show Mouseover"] = "显示鼠标指向"
L["Show Name Text"] = "显示名字文字"
L["Show Nameplate"] = "显示姓名版"
--[[Translation missing --]]
L["Show nameplates at all times."] = "Show nameplates at all times."
--[[Translation missing --]]
L["Show Neutral Units"] = "Show Neutral Units"
L["Show Number"] = "显示数字"
--[[Translation missing --]]
L["Show Orb"] = "Show Orb"
L["Show shadow with text."] = "显示文字阴影"
L["Show Skull Icon"] = "显示骷髅图标"
L["Show stack count on auras."] = "显示光环的堆叠次数。"
L["Show Target"] = "显示目标"
--[[Translation missing --]]
L["Show the amount you need to loot or kill"] = "Show the amount you need to loot or kill"
L["Show the mouseover highlight on all units."] = "所有单位都要显示鼠标指向时的显著标示效果。"
--[[Translation missing --]]
L["Show the OmniCC cooldown count instead of the built-in duration text on auras."] = "Show the OmniCC cooldown count instead of the built-in duration text on auras."
--[[Translation missing --]]
L["Show the player's threat percentage (scaled or raw) or threat delta to the second player on the threat table (percentage or threat value) against the enemy unit."] = "Show the player's threat percentage (scaled or raw) or threat delta to the second player on the threat table (percentage or threat value) against the enemy unit."
--[[Translation missing --]]
L["Show the player's threat percentage against the enemy unit relative to the threat of enemy unit's primary target."] = "Show the player's threat percentage against the enemy unit relative to the threat of enemy unit's primary target."
--[[Translation missing --]]
L["Show the player's threat percentage against the enemy unit."] = "Show the player's threat percentage against the enemy unit."
--[[Translation missing --]]
L["Show the player's total threat value on the enemy unit."] = "Show the player's total threat value on the enemy unit."
L["Show threat feedback based on unit type or status or environmental conditions."] = "根据单位类型、状态或环境条件显示仇恨系统的变化。"
L["Show time left on auras that have a duration."] = "有持续时间的光环，显示剩余时间。"
--[[Translation missing --]]
L["Show unlimited buffs in combat."] = "Show unlimited buffs in combat."
--[[Translation missing --]]
L["Show unlimited buffs in instances (e.g., dungeons or raids)."] = "Show unlimited buffs in instances (e.g., dungeons or raids)."
--[[Translation missing --]]
L["Show unlimited buffs on bosses and rares."] = "Show unlimited buffs on bosses and rares."
L["Shows a border around the castbar of nameplates (requires /reload)."] = "在血条的施法条周围显示边框（需要/reload）。"
L["Shows a faction icon next to the nameplate of players."] = "在玩家血条旁显示阵营图标。"
L["Shows a glow based on threat level around the nameplate's healthbar (in combat)."] = "依据仇恨程度在血条周围显示发光效果（战斗中）。"
--[[Translation missing --]]
L["Shows a glow effect on auras that you can steal or purge."] = "Shows a glow effect on auras that you can steal or purge."
--[[Translation missing --]]
L["Shows a glow effect on this custom nameplate."] = "Shows a glow effect on this custom nameplate."
L["Shows an icon for friends and guild members next to the nameplate of players."] = "在玩家血条旁显示好友和公会成员图标。"
L["Shows resource information for bosses and rares."] = "显示首领和希有怪的资源。"
L["Shows resource information only for alternatve power (of bosses or rares, mostly)."] = "显示特殊能量的资源（大多是首领和稀有怪，例如腐化值、威胁值…）。"
L["Situational Scale"] = "不同情况的缩放大小"
L["Situational Transparency"] = "不同情况的透明度"
L["Six"] = "六"
L["Size"] = "大小"
L["Skull"] = "骷髅"
L["Skull Icon"] = "骷髅等级图标"
L["Social"] = "社交"
--[[Translation missing --]]
L["Sort A-Z"] = "Sort A-Z"
L["Sort by overall duration in ascending order."] = "根据持续时间进行升序排序。"
L["Sort by time left in ascending order."] = "根据剩余时间进行升序排序。"
L["Sort in ascending alphabetical order."] = "根据字母排列进行升序排序。"
L["Sort Order"] = "排列顺序"
--[[Translation missing --]]
L["Sort Z-A"] = "Sort Z-A"
L["Spacing"] = "间距"
--[[Translation missing --]]
L["Spark"] = "Spark"
L["Special Effects"] = "特殊效果"
L["Specialization"] = "专精"
L["Spell Color:"] = "法术颜色："
L["Spell Icon"] = "法术图标"
L["Spell Icon Size"] = "法术图标大小"
--[[Translation missing --]]
L["Spell Name"] = "Spell Name"
--[[Translation missing --]]
L["Spell Name Alignment"] = "Spell Name Alignment"
L["Spell Text"] = "法术文字"
L["Spell Text Boundaries"] = "法术文字范围"
--[[Translation missing --]]
L["Spells (Name or ID)"] = "Spells (Name or ID)"
L["Spirit Wolf"] = "幽灵狼"
L["Square"] = "方格"
L["Squares"] = "方格"
L["Stack Count"] = "叠加次数"
L["Stacking"] = "堆叠"
--[[Translation missing --]]
L["Standard"] = "Standard"
--[[Translation missing --]]
L["Status & Environment"] = "Status & Environment"
L["Status Text"] = "状态文字"
--[[Translation missing --]]
L["Steal or Purge Glow"] = "Steal or Purge Glow"
L["Stealth"] = "隐身"
L["Striped Texture"] = "条纹材质"
L["Striped Texture Color"] = "条纹材质颜色"
--[[Translation missing --]]
L["Stripes"] = "Stripes"
L["Style"] = "样式"
L["Supports multiple entries, separated by commas."] = "支持输入多个项目，使用逗号分隔。"
--[[Translation missing --]]
L["Swap Area By Reaction"] = "Swap Area By Reaction"
L["Swap By Reaction"] = "依关系对调"
--[[Translation missing --]]
L["Swap Scale By Reaction"] = "Swap Scale By Reaction"
--[[Translation missing --]]
L["Switch aura areas for buffs and debuffs for friendly units."] = "Switch aura areas for buffs and debuffs for friendly units."
L["Switch scale values for debuffs and buffs for friendly units."] = "友方单位对调增益和减益效果的缩放大小数值"
L["Symbol"] = "符号"
--[[Translation missing --]]
L["Syntax error in event script '%s' of custom style '%s': %s"] = "Syntax error in event script '%s' of custom style '%s': %s"
L["Tank"] = "坦克"
--[[Translation missing --]]
L["Tank Scaled Percentage"] = "Tank Scaled Percentage"
--[[Translation missing --]]
L["Tank Threat Value"] = "Tank Threat Value"
--[[Translation missing --]]
L["Tapped"] = "Tapped"
L["Tapped Units"] = "无效单位"
L["Target"] = "目标"
--[[Translation missing --]]
L["Target Highlight"] = "Target Highlight"
--[[Translation missing --]]
L["Target Hightlight"] = "Target Hightlight"
L["Target Marked"] = "显著标示目标"
L["Target Marked Units"] = "标记图标的单位"
--[[Translation missing --]]
L["Target Marker"] = "Target Marker"
L["Target Markers"] = "标记图标"
L["Target Offset X"] = "当前目标水平偏移"
L["Target Offset Y"] = "当前目标垂直偏移"
L["Target Only"] = "只有目标"
L["Target-based Scale"] = "依据目标的缩放大小"
L["Target-based Transparency"] = "依据目标的透明度"
L["Text Boundaries"] = "文字边框"
L["Text Height"] = "文字高亮"
L["Text Width"] = "文字的宽度"
--[[Translation missing --]]
L["Texts"] = "Texts"
L["Texture"] = "材质"
L["Textures"] = "材质"
--[[Translation missing --]]
L["The (friendly or hostile) player is not flagged for PvP or the player is in a sanctuary."] = "The (friendly or hostile) player is not flagged for PvP or the player is in a sanctuary."
--[[Translation missing --]]
L["The import string contains a profile from an different Threat Plates version. The profile will still be imported (and migrated as far as possible), but some settings from the imported profile might be lost."] = "The import string contains a profile from an different Threat Plates version. The profile will still be imported (and migrated as far as possible), but some settings from the imported profile might be lost."
--[[Translation missing --]]
L["The import string contains custom nameplate settings from a different Threat Plates version. The custom nameplates will still be imported (and migrated as far as possible), but some settings from the imported custom nameplates might be lost."] = "The import string contains custom nameplate settings from a different Threat Plates version. The custom nameplates will still be imported (and migrated as far as possible), but some settings from the imported custom nameplates might be lost."
--[[Translation missing --]]
L["The import string has an invalid format and cannot be imported. Verify that the import string was generated from the same Threat Plates version that you are using currently."] = "The import string has an invalid format and cannot be imported. Verify that the import string was generated from the same Threat Plates version that you are using currently."
--[[Translation missing --]]
L["The import string has an unknown format and cannot be imported. Verify that the import string was generated from the same Threat Plates version that you are using currently."] = "The import string has an unknown format and cannot be imported. Verify that the import string was generated from the same Threat Plates version that you are using currently."
L["The inset from the bottom (in screen percent) that large nameplates are clamped to."] = "大型血条与画面底部的最小间距（屏幕大小百分比）。"
L["The inset from the bottom (in screen percent) that the non-self nameplates are clamped to."] = "非自己的血条与画面底部的最小间距（屏幕大小百分比）。"
L["The inset from the top (in screen percent) that large nameplates are clamped to."] = "大型血条与画面顶端的最小间距（屏幕大小百分比）。"
L["The inset from the top (in screen percent) that the non-self nameplates are clamped to."] = "非自己的血条与画面顶端的最小间距（屏幕大小百分比）。"
L["The max alpha of nameplates."] = "姓名版的最大透明度。"
L["The max distance to show nameplates."] = "可以看见血条的最远距离。"
L["The max distance to show the target nameplate when the target is behind the camera."] = "当目标在镜头后方时，显示目标血条的最远距离。"
L["The minimum alpha of nameplates."] = "姓名版的最小透明度。"
--[[Translation missing --]]
L["The player is friendly to you, and flagged for PvP."] = "The player is friendly to you, and flagged for PvP."
--[[Translation missing --]]
L["The player is hostile, and flagged for PvP, but you are not."] = "The player is hostile, and flagged for PvP, but you are not."
L["The scale of all nameplates if you have no target unit selected."] = "没有选取目标单位时，所有血条的缩放大小。"
L["The scale of non-target nameplates if a target unit is selected."] = "有选取目标单位时，所有非当前目标血条的缩放大小。"
--[[Translation missing --]]
L["The script has overwritten the global '%s', this might affect other scripts ."] = "The script has overwritten the global '%s', this might affect other scripts ."
L["The size of the clickable area is always derived from the current size of the healthbar."] = "鼠标可以点击的范围大小永远符合当前的血条大小。"
L["The target nameplate's scale if a target unit is selected."] = "有选取目标单位时，当前目标血条的缩放大小。"
L["The target nameplate's transparency if a target unit is selected."] = "有选取目标单位时，当前目标血条的透明度。"
L["The transparency of all nameplates if you have no target unit selected."] = "没有选取目标单位时，所有血条的透明度。"
L["The transparency of non-target nameplates if a target unit is selected."] = "有选取目标单位时，所有非当前目标血条的透明度。"
L["These options allow you to control whether target marker icons are hidden or shown on nameplates and whether a nameplate's healthbar (in healthbar view) or name (in headline view) are colored based on target markers."] = "这些选项可以控制是否要在血条上显示标记图标，以及血条（在血条检视时）和名字（在名字检视时）是否要依据标记图标变换颜色。"
L["These options allow you to control whether the castbar is hidden or shown on nameplates."] = "这些选项可以控制是否要在血条上显示施法条。"
L["These options allow you to control which nameplates are visible within the game field while you play."] = "这些选项可以控制要在游戏中看见哪些血条。"
--[[Translation missing --]]
L["These settings will define the space that text can be placed on the nameplate."] = "These settings will define the space that text can be placed on the nameplate."
L["These settings will define the space that text can be placed on the nameplate. Having too large a font and not enough height will cause the text to be not visible."] = "这些选项会设定血条上面摆放文字的空间。文字太大而高度不够时会导致无法显示文字。"
L["Thick"] = "粗"
L["Thick Outline"] = "粗轮廓"
L["Thick Outline, Monochrome"] = "粗轮廓，单色"
--[[Translation missing --]]
L["Thin Square"] = "Thin Square"
--[[Translation missing --]]
L["This lets you select the layout style of the auras area."] = "This lets you select the layout style of the auras area."
L["This lets you select the layout style of the auras widget."] = "选择光环套件的版面配置风格。"
--[[Translation missing --]]
L["This option allows you to control whether a cast's remaining cast time is hidden or shown on castbars."] = "This option allows you to control whether a cast's remaining cast time is hidden or shown on castbars."
L["This option allows you to control whether a spell's icon is hidden or shown on castbars."] = "显示或隐藏施法条上的法术图标。"
L["This option allows you to control whether a spell's name is hidden or shown on castbars."] = "显示或隐藏施法条上的法术名称。"
L["This option allows you to control whether a unit's health is hidden or shown on nameplates."] = "显示或隐藏血条上的血量。"
L["This option allows you to control whether a unit's level is hidden or shown on nameplates."] = "显示或隐藏血条上的等级。"
L["This option allows you to control whether a unit's name is hidden or shown on nameplates."] = "显示或隐藏血条上的名字。"
L["This option allows you to control whether custom settings for nameplate style, color, transparency and scaling should be used for this nameplate."] = "这个选项让你可以控制要如何自定义这个血条的样式、颜色、透明度和缩放大小。"
L["This option allows you to control whether headline view (text-only) is enabled for nameplates."] = "血条是否要使用名字检视（只显示文字）。"
L["This option allows you to control whether nameplates should fade in when displayed."] = "血条出现时是否要显示淡出淡入的效果。"
L["This option allows you to control whether textures are hidden or shown on nameplates for different threat levels. Dps/healing uses regular textures, for tanking textures are swapped."] = "不同的仇恨程度是否要显示或隐藏血条材质。DPS/治疗使用一般材质，坦克的材质会对调。"
L["This option allows you to control whether the custom icon is hidden or shown on this nameplate."] = "显示或隐藏这个血条上的自定义图标。"
L["This option allows you to control whether the icon for rare & elite units is hidden or shown on nameplates."] = "显示或隐藏血条上的稀有怪 & 精英怪图标。"
L["This option allows you to control whether the skull icon for boss units is hidden or shown on nameplates."] = "显示或隐藏首领单位的血条上的骷髅图标。"
L["This option allows you to control whether threat affects the healthbar color of nameplates."] = "是否要依据仇恨值变换血条的颜色。"
L["This option allows you to control whether threat affects the scale of nameplates."] = "是否要依据仇恨值变换血条的大小。"
L["This option allows you to control whether threat affects the transparency of nameplates."] = "这个选项让你可以控制仇恨值是否要影响血条的透明度。"
L["This setting will disable threat scale for target marked, mouseover or casting units and instead use the general scale settings."] = "这个设定会停用被标记目标、鼠标指向或正在施法单位的仇恨值缩放大小变化，改为使用一般的缩放大小设定。"
L["This setting will disable threat transparency for target marked, mouseover or casting units and instead use the general transparency settings."] = "这个设定会停用被标记目标、鼠标指向或正在施法单位的仇恨值透明度变化，改为使用一般的透明度设定。"
--[[Translation missing --]]
L["This widget highlights the nameplate of your current focus target by showing a border around the healthbar and by coloring the nameplate's healtbar and/or name with a custom color."] = "This widget highlights the nameplate of your current focus target by showing a border around the healthbar and by coloring the nameplate's healtbar and/or name with a custom color."
L["This widget highlights the nameplate of your current target by showing a border around the healthbar and by coloring the nameplate's healtbar and/or name with a custom color."] = "这个套件会明显的标示出当前目标，在血条周围显示外框，并且使用自定义颜色来显示血条和名字。"
L["This widget shows a class icon on the nameplates of players."] = "这个套件会在玩家的名条上显示职业图标。"
L["This widget shows a quest icon above unit nameplates or colors the nameplate healthbar of units that are involved with any of your current quests."] = "这个套件会在和当前任务相关的单位血条上方显示任务图标或变换血条颜色。"
L["This widget shows a stealth icon on nameplates of units that can detect stealth."] = "这个套件会在能够侦测到的隐形单位血条上显示隐形图标。"
L["This widget shows a unit's auras (buffs and debuffs) on its nameplate."] = "这个套件会在血条上显示单位的光环（增益和减益效果）。"
--[[Translation missing --]]
L["This widget shows an experience bar for player followers."] = "This widget shows an experience bar for player followers."
L["This widget shows auras from boss mods on your nameplates (since patch 7.2, hostile nameplates only in instances and raids)."] = "这个套件会在血条上显示来自首领模块的光环（从魔兽世界7.2版开始，副本和团队中插件只能作用于敌方血条）。"
L["This widget shows icons for friends, guild members, and faction on nameplates."] = "这个套件会在血条上显示好友、公会成员和阵营图标。"
L["This widget shows information about your target's resource on your target nameplate. The resource bar's color is derived from the type of resource automatically."] = "这个套件会在当前目标血条上显示目标的资源，会依据资源类型自动变换资源条的颜色。"
L["This widget shows players that are healers."] = "这个套件会显示角色为治疗者的玩家。"
L["This widget shows various icons (orbs and numbers) on enemy nameplates in arenas for easier differentiation."] = "这个套件会在竞技场对手的血条上显示各种图标（圆球或数字），以便轻松辨别对手。"
L["This widget shows your combo points on your target nameplate."] = "这个套件会在当前目标血条上显示你的连击点数。"
L["This will allow you to disable threat art on target marked units."] = "停用被标记图标单位的仇恨值美术图案。"
L["This will color the aura based on its type (poison, disease, magic, curse) - for Icon Mode the icon border is colored, for Bar Mode the bar itself."] = "这将根据其类型（中毒，疾病，魔法，诅咒）对图标风格进行边框上色，而对条的风格是在它本身。"
--[[Translation missing --]]
L["This will format text to a simpler format using M or K for millions and thousands. Disabling this will show exact absorbs amounts."] = "This will format text to a simpler format using M or K for millions and thousands. Disabling this will show exact absorbs amounts."
--[[Translation missing --]]
L["This will format text to a simpler format using M or K for millions and thousands. Disabling this will show exact health amounts."] = "This will format text to a simpler format using M or K for millions and thousands. Disabling this will show exact health amounts."
L["This will format text to show both the maximum hp and current hp."] = "这个选项将设置文字格式以同时显示最大血量与当前血量。"
L["This will format text to show hp as a value the target is missing."] = "这个选项将设置文字格式来显示目标损失的血量值。"
L["This will toggle the auras widget to only show for your current target."] = "切换光环套件只显示于当前目标。"
L["This will toggle the auras widget to show the cooldown spiral on auras."] = "切换光环套件在光环上显示旋转倒数动画。"
--[[Translation missing --]]
L["Threat Detection"] = "Threat Detection"
--[[Translation missing --]]
L["Threat Detection Heuristic"] = "Threat Detection Heuristic"
L["Threat Glow"] = "仇恨值发光效果"
--[[Translation missing --]]
L["Threat Plates Script Editor"] = "Threat Plates Script Editor"
L["Threat System"] = "仇恨系统"
--[[Translation missing --]]
L["Threat Table"] = "Threat Table"
--[[Translation missing --]]
L["Threat Value Delta"] = "Threat Value Delta"
L["Three"] = "三"
L["Time Left"] = "剩余时间"
L["Time Text Offset"] = "时间文字偏移"
--[[Translation missing --]]
L["Toggle"] = "Toggle"
--[[Translation missing --]]
L["Toggle Enemy Headline View"] = "Toggle Enemy Headline View"
--[[Translation missing --]]
L["Toggle Friendly Headline View"] = "Toggle Friendly Headline View"
--[[Translation missing --]]
L["Toggle Neutral Headline View"] = "Toggle Neutral Headline View"
L["Toggle on Target"] = "对当前目标开启/关闭测试"
L["Toggling"] = "切换"
L["Tooltips"] = "鼠标提示"
L["Top"] = "上"
L["Top Inset"] = "上方间距"
L["Top Left"] = "左上"
L["Top Right"] = "右上"
L["Top-to-bottom"] = "从上到下"
L["Totem Scale"] = "图腾缩放"
L["Totem Transparency"] = "图腾透明度"
L["Totems"] = "图腾"
--[[Translation missing --]]
L["Transliterate Cyrillic Letters"] = "Transliterate Cyrillic Letters"
L["Transparency"] = "透明"
L["Transparency & Scaling"] = "透明度 & 缩放大小"
L["Treant"] = "树人"
--[[Translation missing --]]
L["Trigger"] = "Trigger"
L["Two"] = "二"
--[[Translation missing --]]
L["Type"] = "Type"
L["Typeface"] = "字体"
L["UI Scale"] = "界面缩放"
L["Unable to change a setting while in combat."] = "战斗中无法变更设定。"
L["Unable to change the following console variable while in combat: "] = "战斗中无法修改如下的设置:"
L["Unable to change transparency for occluded units while in combat."] = "战斗中无法修改被挡住单位的透明度"
L["Undetermined"] = "未确定"
--[[Translation missing --]]
L["Unfriendly"] = "Unfriendly"
L["Uniform Color"] = "单一颜色"
L["Unit Base Scale"] = "单位基础缩放大小"
L["Unit Base Transparency"] = "使用基础透明度"
L["Unknown option: "] = "未知设置： "
--[[Translation missing --]]
L["Unlimited Duration"] = "Unlimited Duration"
L["Usage: /tptp [options]"] = "输入: /tptp [options]"
L["Use a custom color for healthbar (in healthbar view) or name (in headline view) of friends and/or guild members."] = "好友/公会成员的血条（在血条检视时）或名字（在名字检视时）使用自定义颜色。"
--[[Translation missing --]]
L["Use a custom color for the background."] = "Use a custom color for the background."
--[[Translation missing --]]
L["Use a custom color for the bar background."] = "Use a custom color for the bar background."
--[[Translation missing --]]
L["Use a custom color for the bar's border."] = "Use a custom color for the bar's border."
L["Use a custom color for the castbar's background."] = "施法条背景使用自定义颜色。"
L["Use a custom color for the healtbar's background."] = "在血条背景上使用自定义颜色。"
L["Use a custom color for the healtbar's border."] = "血条边框使用自定义颜色。"
L["Use a custom color for the healthbar of quest mobs."] = "任务怪的血条使用自定义颜色。"
--[[Translation missing --]]
L["Use a custom color for the healthbar of your current focus target."] = "Use a custom color for the healthbar of your current focus target."
L["Use a custom color for the healthbar of your current target."] = "当前目标的血条使用自定义颜色。"
--[[Translation missing --]]
L["Use a custom color for the name of your current focus target (in healthbar view and in headline view)."] = "Use a custom color for the name of your current focus target (in healthbar view and in headline view)."
L["Use a custom color for the name of your current target (in healthbar view and in headline view)."] = "当前目标的名字使用自定义颜色（在血条检视和名字检视时）。"
--[[Translation missing --]]
L["Use a heuristic instead of a mob's threat table to detect if you are in combat with a mob (see Threat System - General Settings for a more detailed explanation)."] = "Use a heuristic instead of a mob's threat table to detect if you are in combat with a mob (see Threat System - General Settings for a more detailed explanation)."
--[[Translation missing --]]
L["Use a heuristic to detect if a mob is in combat with you, but only in instances (like dungeons or raids)."] = "Use a heuristic to detect if a mob is in combat with you, but only in instances (like dungeons or raids)."
L["Use a striped texture for the absorbs overlay. Always enabled if full absorbs are shown."] = "使用条纹材质来显示吸收盾，吸收盾完整时一定会显示。"
L["Use Blizzard default nameplates for friendly nameplates and disable ThreatPlates for these units."] = "友方玩家使用游戏内置的血条，不要使用ThreatPlates。"
L["Use Blizzard default nameplates for neutral and enemy nameplates and disable ThreatPlates for these units."] = "中立和敌对单位使用游戏默认的姓名版，而不使用TPTP。"
L["Use scale settings of Healthbar View also for Headline View."] = "血条检视的缩放大小设定也要套用到名字检视。"
L["Use target-based scale as absolute scale and ignore unit base scale."] = "完全使用依据目标变化的缩放大小，忽略单位基础缩放大小。"
L["Use target-based transparency as absolute transparency and ignore unit base transparency."] = "只使用是否有选取目标的相关透明度设定，当作绝对透明度，忽略单位基础透明度。"
L["Use Target's Name"] = "使用目标名字"
--[[Translation missing --]]
L["Use the background color also for the border."] = "Use the background color also for the border."
--[[Translation missing --]]
L["Use the bar foreground color also for the background."] = "Use the bar foreground color also for the background."
--[[Translation missing --]]
L["Use the bar foreground color also for the bar background."] = "Use the bar foreground color also for the bar background."
--[[Translation missing --]]
L["Use the bar foreground color also for the border."] = "Use the bar foreground color also for the border."
L["Use the castbar's foreground color also for the background."] = "施法条的前景颜色也要套用到背景。"
L["Use the healthbar's background color also for the border."] = "边框使用和血条背景相同的颜色。"
L["Use the healthbar's foreground color also for the background."] = "将血条前景颜色作为背景。"
L["Use the healthbar's foreground color also for the border."] = "边框使用和血条前景相同的颜色。"
L["Use the same color for all combo points shown."] = "连击点都显示为相同的颜色"
--[[Translation missing --]]
L["Use Threat Color"] = "Use Threat Color"
L["Use threat scale as additive scale and add or substract it from the general scale settings."] = "将仇恨值缩放大小变化视为附加的值，会和一般缩放大小的设定值相加或相减。"
L["Use threat transparency as additive transparency and add or substract it from the general transparency settings."] = "将仇恨值透明度变化视为附加的值，会和一般透明度的设定值相加或相减。"
L["Use transparency settings of Healthbar View also for Headline View."] = "血条检视的透明度设定也要套用到名字检视。"
L["Uses the target-based transparency as absolute transparency and ignore unit base transparency."] = "只使用是否有选取目标的相关透明度设定，当作绝对透明度，忽略单位基础透明度。"
L["Val'kyr Shadowguard"] = "瓦格里暗影戒卫者"
--[[Translation missing --]]
L["Value"] = "Value"
--[[Translation missing --]]
L["Value Format"] = "Value Format"
--[[Translation missing --]]
L["Value Type"] = "Value Type"
L["Venomous Snake"] = "剧毒蛇"
L["Vertical Align"] = "垂直定位"
L["Vertical Alignment"] = "垂直对齐"
L["Vertical Offset"] = "垂直位置"
L["Vertical Overlap"] = "垂直重叠/间距"
L["Vertical Spacing"] = "垂直间距"
L["Viper"] = "毒蛇"
L["Visibility"] = "可见性"
L["Volatile Ooze"] = "不稳定的软泥怪"
L["Warlock"] = "术士"
L["Warning Glow for Threat"] = "仇恨值发光警告"
L["Water Elemental"] = "水元素"
L["Web Wrap"] = "缠网"
L["We're unable to change this while in combat"] = "战斗中无法更改"
L["Wide"] = "宽大"
L["Widgets"] = "组件"
L["Width"] = "宽度"
L["Windwalker Monk"] = "踏风武僧"
--[[Translation missing --]]
L["With Pet"] = "With Pet"
--[[Translation missing --]]
L["Word Wrap"] = "Word Wrap"
--[[Translation missing --]]
L["World Boss"] = "World Boss"
L["X"] = "X轴"
L["Y"] = "Y轴"
L["You can access the "] = "你可以进入"
--[[Translation missing --]]
L["You cannot delete General Settings, only custom nameplates entries."] = "You cannot delete General Settings, only custom nameplates entries."
L["You currently have two nameplate addons enabled: |cff89F559Threat Plates|r and |cff89F559%s|r. Please disable one of these, otherwise two overlapping nameplates will be shown for units."] = "目前启用了两个血条插件: |cff89F559Threat Plates|r和|cff89F559%s|r。请停用其中一个血条插件，否则会重复出现两个叠在一起的血条。"
L["Your own quests that you have to complete."] = "必须由你来完成任务。"
--[[Translation missing --]]
L["Your version of LibDogTag-Unit-3.0 does not support nameplates. You need to install at least v90000.3 of LibDogTag-Unit-3.0."] = "Your version of LibDogTag-Unit-3.0 does not support nameplates. You need to install at least v90000.3 of LibDogTag-Unit-3.0."
