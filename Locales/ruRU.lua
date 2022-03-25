local L = LibStub("AceLocale-3.0"):NewLocale("TidyPlatesThreat", "ruRU", false)
if not L then return end

L["  /tptpdps       Toggles DPS/Healing threat plates"] = "/tptpdps переключение Урон/Лечение таблички с угрозами"
L["  /tptpol        Toggles nameplate overlapping"] = "/tptpol переключить nameplates наложением"
--[[Translation missing --]]
L["  /tptptank      Toggles Tank threat plates"] = "  /tptptank      Toggles Tank threat plates"
--[[Translation missing --]]
L["  /tptptoggle    Toggle Role from one to the other"] = "  /tptptoggle    Toggle Role from one to the other"
--[[Translation missing --]]
L["  /tptpverbose   Toggles addon feedback text"] = "  /tptpverbose   Toggles addon feedback text"
--[[Translation missing --]]
L["  <no option>             Displays options dialog"] = "  <no option>             Displays options dialog"
--[[Translation missing --]]
L["  help                    Prints this help message"] = "  help                    Prints this help message"
--[[Translation missing --]]
L["  legacy-custom-styles    Adds (legacy) default custom styles for nameplates that are deleted when migrating custom nameplates to the current format"] = "  legacy-custom-styles    Adds (legacy) default custom styles for nameplates that are deleted when migrating custom nameplates to the current format"
L["  profile <name>          Switch the current profile to <name>"] = "profile <name> Переключить текущий профиль на <name>"
L["  toggle-scripting        Enable or disable scripting support (for beta testing)"] = "toggle-scripting Включение или отключение поддержки сценариев (для бета-тестирования)"
--[[Translation missing --]]
L[" (Elite)"] = " (Elite)"
--[[Translation missing --]]
L[" (Rare Elite)"] = " (Rare Elite)"
--[[Translation missing --]]
L[" (Rare)"] = " (Rare)"
L[" options by typing: /tptp"] = "Для настроек введите: /tptp"
L[" The change will be applied after you leave combat."] = "Это изменение будет применено после того, как вы выйдете из боя."
L[" to DPS."] = "для нанесения урона."
L[" to tanking."] = "для танкования."
L[ [=[

--

Backupiseasy

(Original author: Suicidal Katt - |cff00ff00Shamtasticle@gmail.com|r)]=] ] = "-- Резервное копирование (Автор оригинала: SuicidalKatt - |cff00ff00Shamtasticle@gmail.com/r)"
L[ [=[

Feel free to email me at |cff00ff00threatplates@gmail.com|r

--

Blacksalsify

(Original author: Suicidal Katt - |cff00ff00Shamtasticle@gmail.com|r)]=] ] = [=[

Не стесняйтесь, пишите мне на |cff00ff00threatplates@gmail.com|r

--

Blacksalsify

(Автор оригинала: Suicidal Katt - |cff00ff00Shamtasticle@gmail.com|r)]=]
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
L[". You cannot use two custom nameplates with the same trigger. The imported custom nameplate will be disabled."] = ". Вы не можете использовать две пользовательские таблички с одним и тем же триггером. Импортированный персонализированный неймплейт будет отключен."
L["|cff00ff00High Threat|r"] = "|cff00ff00Большая угроза|r"
L["|cff00ff00Low Threat|r"] = "|cff00ff00Слабая угроза|r"
L["|cff00ff00Tank|r"] = "|cff00ff00Танк|r"
L["|cff00ff00tanking|r"] = "|cff00ff00танкующий|r"
L["|cff0faac8Off-Tank|r"] = "|cff0faac8Офф-Танк|r"
L["|cff89f559 role.|r"] = "|cff89f559 роль.|r"
L["|cff89f559Additional options can be found by typing |r'/tptp'|cff89F559.|r"] = "|cff89f559Дополнительные опции можно найти, введя |r'/tptp'|cff89F559.|r"
L["|cff89f559Threat Plates:|r Welcome back |cff"] = "|cff89f559Threat Plates:|r Добро пожаловать|cff"
L["|cff89F559Threat Plates|r is no longer a theme of |cff89F559TidyPlates|r, but a standalone addon that does no longer require TidyPlates. Please disable one of these, otherwise two overlapping nameplates will be shown for units."] = "Threat Plates больше не является темой для TidyPlates, теперь это самостоятельный аддон, которому не требуется TidyPlates. Пожалуйста отключите один из этих аддонов иначе они будут друг на друга накладываться."
L["|cff89F559Threat Plates|r: DPS switch detected, you are now in your |cffff0000dpsing / healing|r role."] = "|cff89F559Threat Plates|r: Обнаружена смена роли бойца, теперь Вы в роли |cffff0000Бойца / Лекаря|r."
L["|cff89F559Threat Plates|r: No profile specified"] = "|cff89F559Threat Plates|r: Профиль не указан"
L["|cff89F559Threat Plates|r: Role toggle not supported because automatic role detection is enabled."] = "|cff89F559Threat Plates|r: Переключение роли не поддерживается, потому что включено автоматическое определение роли."
L["|cff89F559Threat Plates|r: Tank switch detected, you are now in your |cff00ff00tanking|r role."] = "|cff89F559Threat Plates|r: Обнаружена смена роли танка, теперь Ваша роль |cff00ff00tanking|r ."
L["|cff89F559Threat Plates|r: Unknown profile: "] = "|cff89F559Threat Plates|r: Неизвестный профиль"
L[ [=[|cff89f559Welcome to |r|cff89f559Threat Plates!
This is your first time using Threat Plates and you are a(n):
|r|cff]=] ] = [=[|cff89f559Добро пожаловать в |r|cff89f559Threat Plates!
Это ваш первый запуск Threat Plates! и вы(n):
|r|cff
]=]
--[[Translation missing --]]
L[ [=[|cff89f559Welcome to |r|cff89f559Threat Plates!
This is your first time using Threat Plates and you are a(n):
|r|cff]=] ] = ""
L["|cff89f559You are currently in your "] = "|cff89f559Вы в настоящее время в Вашем"
L[ [=[|cffFF0000DELETE CUSTOM NAMEPLATE|r
Are you sure you want to delete the selected custom nameplate?]=] ] = "|cffFF0000УДАЛИТЬ ПЕРСОНАЛИЗИРОВАННЫЙ НЕЙМПЛЕЙТ|r Вы действительно хотите удалить выбранный персонализированный неймплейт?"
--[[Translation missing --]]
L[ [=[|cffFF0000DELETE CUSTOM NAMEPLATE|r
Are you sure you want to delete the selected custom nameplate?]=] ] = ""
L["|cffff0000DPS/Healing|r"] = "|cffff0000Боец/Лекарь|r"
L["|cffff0000dpsing / healing|r"] = "|cffff0000боец / лекарь|r"
L["|cffff0000High Threat|r"] = "Высокая Угроза"
--[[Translation missing --]]
L["|cffff0000IMPORTANT: Enabling this feature changes console variables (CVars) which will change the appearance of default Blizzard nameplates. Disabling this feature will reset these CVars to the original value they had when you enabled this feature.|r"] = "|cffff0000IMPORTANT: Enabling this feature changes console variables (CVars) which will change the appearance of default Blizzard nameplates. Disabling this feature will reset these CVars to the original value they had when you enabled this feature.|r"
L["|cffff0000Low Threat|r"] = "Низкая Угроза"
--[[Translation missing --]]
L["|cffFF0000The Auras widget must be enabled (see Widgets - Auras) to use auras as trigger for custom nameplates.|r"] = "|cffFF0000The Auras widget must be enabled (see Widgets - Auras) to use auras as trigger for custom nameplates.|r"
--[[Translation missing --]]
L["|cffFFD100Current Instance:|r"] = "|cffFFD100Current Instance:|r"
L["|cffffff00Medium Threat|r"] = "Срденяя Угроза"
L["|cffffffffGeneral Settings|r"] = "|cffffffffОбщие настройки|r"
L["|cffffffffLow Threat|r"] = "|cffffffffНизкая угроза|r"
L["|cffffffffTotem Settings|r"] = "|cffffffffНастройки тотема(ов)|r"
L["-->>|cff00ff00Tank Plates Enabled|r<<--"] = "-->>|cff00ff00Полосы для танка включены|r<<--"
L["-->>|cffff0000DPS Plates Enabled|r<<--"] = "-->>|cffff0000Полосы для бойца включены|r<<--"
L["-->>Nameplate Overlapping is now |cff00ff00ON!|r<<--"] = "-->>Дублирование таблички с именем сейчас |cff00ff00Включено!|r<<--"
L["-->>Nameplate Overlapping is now |cffff0000OFF!|r<<--"] = "-->>Дублирование таблички с именем сейчас |cffff0000Выключено!|r<<--"
L["-->>Threat Plates verbose is now |cff00ff00ON!|r<<--"] = "-->>Подробный Threat Plates сейчас |cff00ff00Включен!|r<<--"
L["-->>Threat Plates verbose is now |cffff0000OFF!|r<<-- shhh!!"] = "-->>Подробный Threat Plates сейчас |cffff0000Выключен!|r<<-- ш-ш-ш!!"
--[[Translation missing --]]
L["A custom nameplate with these triggers already exists: %s. You cannot use two custom nameplates with the same trigger."] = "A custom nameplate with these triggers already exists: %s. You cannot use two custom nameplates with the same trigger."
--[[Translation missing --]]
L["A custom nameplate with these triggers already exists: %s. You cannot use two custom nameplates with the same trigger. The current custom nameplate was therefore disabled."] = "A custom nameplate with these triggers already exists: %s. You cannot use two custom nameplates with the same trigger. The current custom nameplate was therefore disabled."
--[[Translation missing --]]
L["A custom nameplate with this trigger already exists: "] = "A custom nameplate with this trigger already exists: "
--[[Translation missing --]]
L["A script has overwritten the global '%s'. This might affect other scripts ."] = "A script has overwritten the global '%s'. This might affect other scripts ."
L["A to Z"] = "А до Я"
--[[Translation missing --]]
L["Abbreviation"] = "Abbreviation"
L["About"] = "О программе"
L["Absolut Transparency"] = "Полная прозрачность"
L["Absorbs"] = "Поглощение"
--[[Translation missing --]]
L["Absorbs Text"] = "Absorbs Text"
L["Add black outline."] = "Добавить чёрный контур."
L["Add thick black outline."] = "Добавить тонкий чёрный контур."
--[[Translation missing --]]
L["Adding legacy custom nameplate for %s ..."] = "Adding legacy custom nameplate for %s ..."
L["Additional Adjustments"] = "Дополнительные корректировки"
--[[Translation missing --]]
L["Additional chat commands:"] = "Additional chat commands:"
L["Additionally color the name based on the target mark if the unit is marked."] = "Цвет имени цели соответствует цвету метки на цели."
--[[Translation missing --]]
L["Additionally color the nameplate's healthbar or name based on the target mark if the unit is marked."] = "Additionally color the nameplate's healthbar or name based on the target mark if the unit is marked."
--[[Translation missing --]]
L["Alignment"] = "Alignment"
L["All"] = "Все"
L["All on NPCs"] = "Всё на NPCs"
L["Allow"] = "Разрешить"
L["Alpha"] = "Прозрачность"
--[[Translation missing --]]
L["Alpha multiplier of nameplates for occluded units."] = "Alpha multiplier of nameplates for occluded units."
L["Always Show Nameplates"] = "Всегда показывать Nameplates"
L["Always shows the full amount of absorbs on a unit. In overabsorb situations, the absorbs bar ist shifted to the left."] = "Всегда показывать полные данные поглощения на цели. В ситуациях с избыточным поглощением, шкала поглощения будет смещаться влево."
L["Amount"] = "Количество"
L["Anchor"] = "Якорь"
L["Anchor Point"] = "Место привязки"
--[[Translation missing --]]
L["Anchor to"] = "Anchor to"
--[[Translation missing --]]
L["Animacharge"] = "Animacharge"
L["Appearance"] = "Отображение"
--[[Translation missing --]]
L["Apply these custom settings to a nameplate when a particular spell is cast by the unit. You can add multiple entries separated by a semicolon"] = "Apply these custom settings to a nameplate when a particular spell is cast by the unit. You can add multiple entries separated by a semicolon"
--[[Translation missing --]]
L["Apply these custom settings to the nameplate of a unit with a particular name. You can add multiple entries separated by a semicolon. You can use use * as wildcard character."] = "Apply these custom settings to the nameplate of a unit with a particular name. You can add multiple entries separated by a semicolon. You can use use * as wildcard character."
--[[Translation missing --]]
L["Apply these custom settings to the nameplate when a particular aura is present on the unit. You can add multiple entries separated by a semicolon."] = "Apply these custom settings to the nameplate when a particular aura is present on the unit. You can add multiple entries separated by a semicolon."
L["Arcane Mage"] = "Тайная магия"
L["Arena"] = "Арена"
L["Arena 1"] = "Арена 1"
L["Arena 2"] = [=[Арена 2
]=]
L["Arena 3"] = "Арена 3"
L["Arena 4"] = "Арена 4"
L["Arena 5"] = "Арена 5"
L["Arena Number"] = "Номер арены"
L["Arena Orb"] = "Сфера арены"
L["Army of the Dead Ghoul"] = "Войско мёртвых"
L["Arrow"] = "Стрелка"
--[[Translation missing --]]
L["Arrow (Legacy)"] = "Arrow (Legacy)"
L["Art Options"] = "Настройки артефакта"
--[[Translation missing --]]
L["Attempt to register script for unknown WoW event \"%s\""] = "Attempt to register script for unknown WoW event \"%s\""
--[[Translation missing --]]
L["Attempt to register script for unknown WoW event '%s'"] = "Attempt to register script for unknown WoW event '%s'"
L["Aura"] = "Аура"
L["Aura Icon"] = "Значок ауры"
L["Aura: "] = "Аура:"
L["Auras"] = "Ауры"
L["Auras (Name or ID)"] = "Ауры (Имя или ИД)"
L["Auras, Healthbar"] = "Ауры, Плашка здоровья"
--[[Translation missing --]]
L["Auto Sizing"] = "Auto Sizing"
--[[Translation missing --]]
L["Auto-Cast"] = "Auto-Cast"
--[[Translation missing --]]
L["Automatic Icon"] = "Automatic Icon"
L["Automation"] = "Автоматизация"
L["Background"] = "Фон"
L["Background Color"] = "Цвет фона"
L["Background Color:"] = "Цвет фона"
L["Background Texture"] = "Текстура фона"
L["Background Transparency"] = "Прозрачность фона"
--[[Translation missing --]]
L["Bar Background Color:"] = "Bar Background Color:"
L["Bar Border"] = "Текстура рамки"
--[[Translation missing --]]
L["Bar Foreground Color"] = "Bar Foreground Color"
L["Bar Height"] = "Высота рамки"
L["Bar Limit"] = "Предел рамки"
L["Bar Mode"] = "Режим рамки"
--[[Translation missing --]]
L["Bar Style"] = "Bar Style"
L["Bar Width"] = "Ширина рамки"
--[[Translation missing --]]
L["Bars"] = "Bars"
--[[Translation missing --]]
L["Because of side effects with Blizzard nameplates, this function is disabled in instances or when Blizzard nameplates are used for friendly or neutral/enemy units (see General - Visibility)."] = "Because of side effects with Blizzard nameplates, this function is disabled in instances or when Blizzard nameplates are used for friendly or neutral/enemy units (see General - Visibility)."
L["Blizzard"] = "Blizzard"
L["Blizzard Settings"] = "Настройки Blizzard"
L["Block"] = "Блок"
L["Bone Spike"] = "Костянной шип"
L["Border"] = "Граница"
L["Border Color:"] = "Цвет границы:"
L["Boss"] = "Босс"
L["Boss Mods"] = "Настройки Босса"
L["Bosses"] = "Боссы"
--[[Translation missing --]]
L["Both you and the other player are flagged for PvP."] = "Both you and the other player are flagged for PvP."
L["Bottom"] = "Низ"
L["Bottom Inset"] = "Нижняя вставка"
L["Bottom Left"] = "Снизу-слева"
L["Bottom Right"] = "Снизу-справа"
L["Bottom-to-top"] = "Снизу-вверх"
--[[Translation missing --]]
L["Boundaries"] = "Boundaries"
--[[Translation missing --]]
L["Bubble"] = "Bubble"
L["Buff Color"] = "Цвет баффа"
L["Buffs"] = "Баффы"
L["Button"] = "Кнопка"
L["By Class"] = "По классу"
L["By Custom Color"] = "Свой цвет"
--[[Translation missing --]]
L["By default, the threat system works based on a mob's threat table. Some mobs do not have such a threat table even if you are in combat with them. The threat detection heuristic uses other factors to determine if you are in combat with a mob. This works well in instances. In the open world, this can show units in combat with you that are actually just in combat with another player (and not you)."] = "By default, the threat system works based on a mob's threat table. Some mobs do not have such a threat table even if you are in combat with them. The threat detection heuristic uses other factors to determine if you are in combat with a mob. This works well in instances. In the open world, this can show units in combat with you that are actually just in combat with another player (and not you)."
L["By Health"] = "По уровню здоровья"
L["By Reaction"] = "По реакции"
L["Can Apply"] = "Можно применить"
L["Canal Crab"] = "Canal Crab"
L["Cancel"] = "Отмена"
L["Cast"] = "Каст"
--[[Translation missing --]]
L["Cast Target"] = "Cast Target"
L["Cast Time"] = "Время заклинания"
--[[Translation missing --]]
L["Cast Time Alignment"] = "Cast Time Alignment"
L["Cast: "] = "Каст:"
L["Castbar"] = "Полоса заклинания"
L["Castbar, Healthbar"] = "Полоса заклинания, Полоса здоровья"
L["Center"] = "Центр"
L["Center Auras"] = "Центровать ауры"
L["Change the color depending on the amount of health points the nameplate shows."] = "Изменить цвет в зависимости от количества здоровья"
L["Change the color depending on the reaction of the unit (friendly, hostile, neutral)."] = "Изменить цвет в зависимости от отношения цели (дружественная, враждебная, нейтральная)"
L["Change the scale of nameplates depending on whether a target unit is selected or not. As default, this scale is added to the unit base scale."] = "Изменить масштаб рамки в зависимости от выбрана цель или нет. По умолчанию, этот масштаб добавляется к базовому масштабу цели."
L["Change the scale of nameplates in certain situations, overwriting all other settings."] = "Изменить масштаб рамки в определённых ситуациях. (Переназначит все остальные настройки)"
L["Change the transparency of nameplates depending on whether a target unit is selected or not. As default, this transparency is added to the unit base transparency."] = "Изменить прозрачность рамки в зависимости от выбрана цель или нет. По умолчанию, эта прозрачность добавляется к базовой прозрачности цели."
--[[Translation missing --]]
L["Change the transparency of nameplates for occluded units (e.g., units behind walls)."] = "Change the transparency of nameplates for occluded units (e.g., units behind walls)."
L["Change the transparency of nameplates in certain situations, overwriting all other settings."] = "Изменить прозрачность рамки в определённых ситуациях. (Переназначит все остальные настройки)"
L["Changes the default settings to the selected design. Some of your custom settings may get overwritten if you switch back and forth.."] = "Изменить стандартные настройки выбранного дизайна. Некоторые ваши настройки могут быть автоматически переназначены, если вы переключаетесь вперёд-назад."
L["Changing these options may interfere with other nameplate addons or Blizzard default nameplates as console variables (CVars) are changed."] = "Изменение этих опций может привести к конфликту со стандартными рамками Blizzard поскольку переменные  консольные данные будут изменены."
L["Changing these settings will alter the placement of the nameplates, however the mouseover area does not follow. |cffff0000Use with caution!|r"] = "Изменение этих параметров повлечёт за собой смену положения рамок, но область нажатия указателем мыши останется прежней. |cffff0000Используйте с осторожностью!|r"
--[[Translation missing --]]
L["Clamp Target Nameplate to Screen"] = "Clamp Target Nameplate to Screen"
--[[Translation missing --]]
L["Clamps the target's nameplate to the edges of the screen, even if the target is off-screen."] = "Clamps the target's nameplate to the edges of the screen, even if the target is off-screen."
L["Class"] = "Класс"
--[[Translation missing --]]
L["Class Color for Players"] = "Class Color for Players"
L["Class Icon"] = "Значок класса"
--[[Translation missing --]]
L[ [=[Clear and easy to use threat-reactive nameplates.

Current version: ]=] ] = [=[Clear and easy to use threat-reactive nameplates.

Current version: ]=]
--[[Translation missing --]]
L[ [=[Clear and easy to use threat-reactive nameplates.

Current version: ]=] ] = ""
L["Clickable Area"] = "Область нажатия"
L["Color"] = "Цвет"
L["Color By Class"] = "Цвет по классу"
L["Color by Dispel Type"] = "Цвет по типу рассеивания"
L["Color by Health"] = "Цвет по уровню здоровья"
L["Color by Reaction"] = "Цвет по реакции на вас"
L["Color by Target Mark"] = "Цвет по метке на цели"
L["Color Healthbar By Enemy Class"] = "Цвет полосы здоровья по классу врага"
L["Color Healthbar By Friendly Class"] = "Цвет полосы здоровья по классу союзника"
L["Color Healthbar by Target Marks in Healthbar View"] = "Цвет полосы здоровья по метке на цели при отображении полос здоровья"
L["Color Name by Target Marks in Headline View"] = "Цвет имени по метке на цели при отображении только имени"
L["Coloring"] = "Раскрасить"
L["Colors"] = "Цвета"
L["Column Limit"] = "Размер столбца"
L["Combat"] = "Бой"
L["Combo Points"] = "Серия приёмов"
L["Configuration Mode"] = "Режим настройки"
--[[Translation missing --]]
L["Controls the rate at which nameplate animates into their target locations [0.0-1.0]."] = "Controls the rate at which nameplate animates into their target locations [0.0-1.0]."
L["Cooldown Spiral"] = "Спиралевидное отображение времени восстановления"
L["Copy"] = "Копировать"
L["Creation"] = "Создание"
--[[Translation missing --]]
L["Crescent"] = "Crescent"
L["Crowd Control"] = "Групповой контроль"
L["Curse"] = "Проклятие"
L["Custom"] = "Настроить"
L["Custom Color"] = "Настроить цвет"
L["Custom Enemy Status Text"] = "Настроить статус текста врага"
L["Custom Friendly Status Text"] = "Настроить дружественный статус текста"
L["Custom Nameplates"] = "Настройка Nameplates"
--[[Translation missing --]]
L["Custom status text requires LibDogTag-3.0 to function."] = "Custom status text requires LibDogTag-3.0 to function."
--[[Translation missing --]]
L["Custom status text requires LibDogTag-Unit-3.0 to function."] = "Custom status text requires LibDogTag-Unit-3.0 to function."
--[[Translation missing --]]
L["Cyclic anchoring of aura areas to each other is not possible."] = "Cyclic anchoring of aura areas to each other is not possible."
L["Darnavan"] = "Darnavan"
L["Death Knigh Rune Cooldown"] = "Рыцарь смерти перезарядка рун"
L["Death Knight"] = "Рыцарь смерти"
L["Debuff Color"] = "Цвет Дебаффа"
L["Debuffs"] = "Дебаффы"
L["Default"] = "По умолчанию"
L["Default Settings (All Profiles)"] = "Стандартные настройки (Все профили)"
--[[Translation missing --]]
L["Deficit"] = "Deficit"
--[[Translation missing --]]
L["Define a custom color for this nameplate and overwrite any other color settings."] = "Define a custom color for this nameplate and overwrite any other color settings."
--[[Translation missing --]]
L["Define a custom scaling for this nameplate and overwrite any other scaling settings."] = "Define a custom scaling for this nameplate and overwrite any other scaling settings."
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
--[[Translation missing --]]
L["Define a custom transparency for this nameplate and overwrite any other transparency settings."] = "Define a custom transparency for this nameplate and overwrite any other transparency settings."
--[[Translation missing --]]
L["Define base alpha settings for various unit types. Only one of these settings is applied to a unit at the same time, i.e., they are mutually exclusive."] = "Define base alpha settings for various unit types. Only one of these settings is applied to a unit at the same time, i.e., they are mutually exclusive."
--[[Translation missing --]]
L["Define base scale settings for various unit types. Only one of these settings is applied to a unit at the same time, i.e., they are mutually exclusive."] = "Define base scale settings for various unit types. Only one of these settings is applied to a unit at the same time, i.e., they are mutually exclusive."
--[[Translation missing --]]
L["Defines the movement/collision model for nameplates."] = "Defines the movement/collision model for nameplates."
L["Deformed Fanatic"] = "Неправильно изменённый"
L["Delete"] = "Удалить"
--[[Translation missing --]]
L["Delta Percentage"] = "Delta Percentage"
--[[Translation missing --]]
L["Delta Threat Value"] = "Delta Threat Value"
--[[Translation missing --]]
L["Detailed Percentage"] = "Detailed Percentage"
L["Determine your role (tank/dps/healing) automatically based on current spec."] = "Определить свою роль (танк / боец / лекарь) автоматически на основе текущей специализации."
--[[Translation missing --]]
L["Determine your role (tank/dps/healing) automatically based on current stance (Warrior) or form (Druid)."] = "Determine your role (tank/dps/healing) automatically based on current stance (Warrior) or form (Druid)."
L["Disable"] = "Отключить"
--[[Translation missing --]]
L["Disable threat scale for target marked, mouseover or casting units."] = "Disable threat scale for target marked, mouseover or casting units."
--[[Translation missing --]]
L["Disable threat transparency for target marked, mouseover or casting units."] = "Disable threat transparency for target marked, mouseover or casting units."
--[[Translation missing --]]
L["Disables nameplates (healthbar and name) for the units of this type and only shows an icon (if enabled)."] = "Disables nameplates (healthbar and name) for the units of this type and only shows an icon (if enabled)."
--[[Translation missing --]]
L["Disabling this will turn off all icons for custom nameplates without harming other custom settings per nameplate."] = "Disabling this will turn off all icons for custom nameplates without harming other custom settings per nameplate."
--[[Translation missing --]]
L["Disconnected"] = "Disconnected"
--[[Translation missing --]]
L["Disconnected Units"] = "Disconnected Units"
--[[Translation missing --]]
L["Disease"] = "Disease"
--[[Translation missing --]]
L["Dispel Type"] = "Dispel Type"
--[[Translation missing --]]
L["Dispellable"] = "Dispellable"
--[[Translation missing --]]
L["Display absorbs amount text."] = "Display absorbs amount text."
--[[Translation missing --]]
L["Display absorbs percentage text."] = "Display absorbs percentage text."
L["Display health amount text."] = "Отображать здоровье в виде текста"
L["Display health percentage text."] = "Отображать здоровье в процентах."
--[[Translation missing --]]
L["Display health text on units with full health."] = "Display health text on units with full health."
L["Distance"] = "Дистанция"
--[[Translation missing --]]
L["Do not show buffs with unlimited duration."] = "Do not show buffs with unlimited duration."
L["Do not sort auras."] = "Не сортировать ауры."
L["Done"] = "Готово"
--[[Translation missing --]]
L["Don't Ask Again"] = "Don't Ask Again"
--[[Translation missing --]]
L["Down Arrow"] = "Down Arrow"
L["DPS/Healing"] = "Боец/Лекарь"
L["Drudge Ghoul"] = "Вурдалак работник"
L["Druid"] = "Друид"
L["Duplicate"] = "Копия"
--[[Translation missing --]]
L["Duration"] = "Duration"
L["Ebon Gargoyle"] = "Ebon Gargoyle"
--[[Translation missing --]]
L["Edge Size"] = "Edge Size"
L["Elite Border"] = "Граница элиты"
L["Empowered Adherent"] = "Empowered Adherent"
L["Enable"] = "Включить"
--[[Translation missing --]]
L["Enable Arena Widget"] = "Enable Arena Widget"
--[[Translation missing --]]
L["Enable Auras Widget"] = "Enable Auras Widget"
--[[Translation missing --]]
L["Enable Boss Mods Widget"] = "Enable Boss Mods Widget"
--[[Translation missing --]]
L["Enable Class Icon Widget"] = "Enable Class Icon Widget"
--[[Translation missing --]]
L["Enable Combo Points Widget"] = "Enable Combo Points Widget"
--[[Translation missing --]]
L["Enable Custom Color"] = "Enable Custom Color"
--[[Translation missing --]]
L["Enable Experience Widget"] = "Enable Experience Widget"
--[[Translation missing --]]
L["Enable Focus Widget"] = "Enable Focus Widget"
L["Enable Friends"] = "Друзья"
L["Enable Guild Members"] = "Члены гильдии"
L["Enable Headline View (Text-Only)"] = "Включить режим Только Заголовки (только текст)"
L["Enable Healer Tracker Widget"] = "Виджет отслеживания лекарей"
L["Enable nameplate clickthrough for enemy units."] = "Клик насквозь для рамок врагов."
L["Enable nameplate clickthrough for friendly units."] = "Некликабельность плашки имени для дружественных целей"
L["Enable Quest Widget"] = "Виджет Квестов"
L["Enable Resource Widget"] = "Виджет Ресурса"
L["Enable Social Widget"] = "Виджет Общения"
L["Enable Stealth Widget"] = "Виджет Незаметности"
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
L["Enable Threat Coloring of Healthbar"] = "Включить раскраску рамки от угрозы"
L["Enable Threat Scale"] = "Включить Масштаб Угрозы"
L["Enable Threat System"] = "Включить систему угрозы"
L["Enable Threat Textures"] = "Текстура Угрозы"
L["Enable Threat Transparency"] = "Прозрачность Угрозы"
L["Enemy Casting"] = "Враг произносящий заклинание"
L["Enemy Name Color"] = "Цвет имени врага"
L["Enemy NPCs"] = "Вражеские NPCs"
L["Enemy Players"] = "Вражеский Игрок"
L["Enemy Status Text"] = "Статус текст врага"
L["Enemy Units"] = "Вражеская цель"
--[[Translation missing --]]
L["Enter an icon's name (with the *.blp ending), a spell ID, a spell name or a full icon path (using '\\' to separate directory folders)."] = "Enter an icon's name (with the *.blp ending), a spell ID, a spell name or a full icon path (using '\\' to separate directory folders)."
--[[Translation missing --]]
L["Error in event script '%s' of custom style '%s': %s"] = "Error in event script '%s' of custom style '%s': %s"
--[[Translation missing --]]
L["Event Name"] = "Event Name"
--[[Translation missing --]]
L["Events with Script"] = "Events with Script"
L["Everything"] = "Всё"
--[[Translation missing --]]
L["Exchange"] = "Exchange"
--[[Translation missing --]]
L["Experience"] = "Experience"
--[[Translation missing --]]
L["Experience Text"] = "Experience Text"
L["Export"] = "Экспорт"
--[[Translation missing --]]
L["Export all custom nameplate settings as string."] = "Export all custom nameplate settings as string."
--[[Translation missing --]]
L["Export Custom Nameplates"] = "Export Custom Nameplates"
L["Export profile"] = "Экспорт профиля"
--[[Translation missing --]]
L["Export the current profile into a string that can be imported by other players."] = "Export the current profile into a string that can be imported by other players."
--[[Translation missing --]]
L["Extend"] = "Extend"
L["Faction Icon"] = "Значок фракции"
L["Fading"] = "Затухание"
--[[Translation missing --]]
L["Failed to migrate the imported profile to the current settings format because of an internal error. Please report this issue at the Threat Plates homepage at CurseForge: "] = "Failed to migrate the imported profile to the current settings format because of an internal error. Please report this issue at the Threat Plates homepage at CurseForge: "
L["Fanged Pit Viper"] = "Fanged Pit Viper"
--[[Translation missing --]]
L["Filter"] = "Filter"
L["Filter by Spell"] = "Фильтр по заклинанию"
L["Filtered Auras"] = "Сортированные ауры"
--[[Translation missing --]]
L["Find a suitable icon based on the current trigger. For Name trigger, the preview does not work. For multi-value triggers, the preview always is the icon of the first trigger entered."] = "Find a suitable icon based on the current trigger. For Name trigger, the preview does not work. For multi-value triggers, the preview always is the icon of the first trigger entered."
L["Five"] = "Пять"
L["Flash Time"] = "Время вспышки"
L["Flash When Expiring"] = "Вспышка после окончания"
--[[Translation missing --]]
L["Focus Highlight"] = "Focus Highlight"
--[[Translation missing --]]
L["Focus Only"] = "Focus Only"
L["Font"] = "Шрифт"
L["Font Size"] = "Размер шрифта"
--[[Translation missing --]]
L["Forbidden function or table called from script: %s"] = "Forbidden function or table called from script: %s"
L["Force View By Status"] = "Отображать по статусу"
L["Foreground"] = "Передний план"
L["Foreground Texture"] = "Текстура переднего плана"
L["Format"] = "Формат"
L["Four"] = "Четыри"
L["Frame Order"] = "Порядок рамки"
L["Friendly & Neutral Units"] = "Дружественные и нейтральные цели"
L["Friendly Casting"] = "Дружественный каст"
L["Friendly Name Color"] = "Дружественный цвет имени"
L["Friendly Names Color"] = "Дружественные цвета имен"
L["Friendly NPCs"] = "Дружественные NPCs"
L["Friendly Players"] = "Дружественные игроки"
--[[Translation missing --]]
L["Friendly PvP On"] = "Friendly PvP On"
L["Friendly Status Text"] = "Дружественные текстовый статус"
L["Friendly Units"] = "Дружественная цель."
L["Friendly Units in Combat"] = "Дружественные цели в бою."
L["Friends & Guild Members"] = "Друзья & Гильдейские участники"
L["Full Absorbs"] = "Полное поглощение"
L["Full Health"] = "Полное здоровье"
--[[Translation missing --]]
L["Full Name"] = "Full Name"
L["Function"] = "Функция"
L["Gas Cloud"] = "Облако газа"
L["General"] = "Общие"
L["General Colors"] = "Общие цвета"
L["General Nameplate Settings"] = "Общие настройки Nameplate"
L["General Settings"] = "Общие настройки"
L["Glow"] = "Свечение"
L["Glow Color"] = "Свечения цвета"
L["Glow Frame"] = "Свечение рамок"
L["Glow Type"] = "Свечение шрифта"
L["Guardians"] = "Стражники"
L["Headline View"] = "Показать Только Текст"
L["Headline View Out of Combat"] = "Показать только текст вне боя."
--[[Translation missing --]]
L["Headline View X"] = "Headline View X"
--[[Translation missing --]]
L["Headline View Y"] = "Headline View Y"
--[[Translation missing --]]
L["Heal Absorbs"] = "Heal Absorbs"
L["Healer Tracker"] = "Отслеживание здоровья"
L["Health"] = "Здоровье"
L["Health Coloring"] = "Раскраска здоровья"
L["Health Text"] = "Текст здоровья"
L["Healthbar"] = "Рамка здоровья"
--[[Translation missing --]]
L["Healthbar Mode"] = "Healthbar Mode"
L["Healthbar Sync"] = "Синхронизация рамки здоровья"
L["Healthbar View"] = "Показ полосы здоровья"
--[[Translation missing --]]
L["Healthbar View X"] = "Healthbar View X"
--[[Translation missing --]]
L["Healthbar View Y"] = "Healthbar View Y"
--[[Translation missing --]]
L["Healthbar, Auras"] = "Healthbar, Auras"
--[[Translation missing --]]
L["Healthbar, Castbar"] = "Healthbar, Castbar"
L["Height"] = "Высота"
--[[Translation missing --]]
L["Heuristic"] = "Heuristic"
--[[Translation missing --]]
L["Heuristic In Instances"] = "Heuristic In Instances"
L["Hide Buffs"] = "Скрыть Бафы"
L["Hide Friendly Nameplates"] = "Скрыть рамки дружественных целей"
L["Hide Healthbars"] = "Спрятать полосу здоровья"
L["Hide in Combat"] = "Скрыть в бою"
L["Hide in Instance"] = "Скрыть в подземелье"
L["Hide Name"] = "Скрыть имя"
L["Hide Nameplate"] = "Скрыть рамку"
L["Hide Nameplates"] = "Скрыть рамку"
L["Hide on Attacked Units"] = "Скрыть на атакованной цели"
--[[Translation missing --]]
L["Hide the Blizzard default nameplates for friendly units in instances."] = "Hide the Blizzard default nameplates for friendly units in instances."
L["High Threat"] = "Высокая угроза"
--[[Translation missing --]]
L["Highlight"] = "Highlight"
--[[Translation missing --]]
L["Highlight Mobs on Off-Tanks"] = "Highlight Mobs on Off-Tanks"
--[[Translation missing --]]
L["Highlight Texture"] = "Highlight Texture"
L["Horizontal Align"] = "Горизонтальное выравнивание"
--[[Translation missing --]]
L["Horizontal Alignment"] = "Horizontal Alignment"
--[[Translation missing --]]
L["Horizontal Offset"] = "Horizontal Offset"
--[[Translation missing --]]
L["Horizontal Overlap"] = "Horizontal Overlap"
--[[Translation missing --]]
L["Horizontal Spacing"] = "Horizontal Spacing"
L["Hostile NPCs"] = "Враждебные NPCs"
--[[Translation missing --]]
L["Hostile Players"] = "Hostile Players"
--[[Translation missing --]]
L["Hostile PvP On - Self Off"] = "Hostile PvP On - Self Off"
--[[Translation missing --]]
L["Hostile PvP On - Self On"] = "Hostile PvP On - Self On"
--[[Translation missing --]]
L["Hostile Units"] = "Hostile Units"
L["Icon"] = "Значок"
--[[Translation missing --]]
L["Icon Height"] = "Icon Height"
--[[Translation missing --]]
L["Icon Mode"] = "Icon Mode"
--[[Translation missing --]]
L["Icon Style"] = "Icon Style"
--[[Translation missing --]]
L["Icon Width"] = "Icon Width"
--[[Translation missing --]]
L["Icons"] = "Icons"
--[[Translation missing --]]
L["If checked, nameplates of mobs attacking another tank can be shown with different color, scale, and transparency."] = "If checked, nameplates of mobs attacking another tank can be shown with different color, scale, and transparency."
--[[Translation missing --]]
L["If checked, threat feedback from boss level mobs will be shown."] = "If checked, threat feedback from boss level mobs will be shown."
--[[Translation missing --]]
L["If checked, threat feedback from elite and rare mobs will be shown."] = "If checked, threat feedback from elite and rare mobs will be shown."
--[[Translation missing --]]
L["If checked, threat feedback from minor mobs will be shown."] = "If checked, threat feedback from minor mobs will be shown."
--[[Translation missing --]]
L["If checked, threat feedback from neutral mobs will be shown."] = "If checked, threat feedback from neutral mobs will be shown."
--[[Translation missing --]]
L["If checked, threat feedback from normal mobs will be shown."] = "If checked, threat feedback from normal mobs will be shown."
--[[Translation missing --]]
L["If checked, threat feedback from tapped mobs will be shown regardless of unit type."] = "If checked, threat feedback from tapped mobs will be shown regardless of unit type."
--[[Translation missing --]]
L["If checked, threat feedback will only be shown in instances (dungeons, raids, arenas, battlegrounds), not in the open world."] = "If checked, threat feedback will only be shown in instances (dungeons, raids, arenas, battlegrounds), not in the open world."
--[[Translation missing --]]
L["If enabled, the truncated health text will be localized, i.e. local metric unit symbols (like k for thousands) will be used."] = "If enabled, the truncated health text will be localized, i.e. local metric unit symbols (like k for thousands) will be used."
--[[Translation missing --]]
L["Ignore Marked Units"] = "Ignore Marked Units"
--[[Translation missing --]]
L["Ignore PvP Status"] = "Ignore PvP Status"
--[[Translation missing --]]
L["Ignore UI Scale"] = "Ignore UI Scale"
--[[Translation missing --]]
L["Illegal character used in Name trigger at position: "] = "Illegal character used in Name trigger at position: "
L["Immortal Guardian"] = "Immortal Guardian"
--[[Translation missing --]]
L["Import a profile from another player from an import string."] = "Import a profile from another player from an import string."
--[[Translation missing --]]
L["Import and export profiles to share them with other players."] = "Import and export profiles to share them with other players."
--[[Translation missing --]]
L["Import custom nameplate settings from a string. The custom namneplates will be added to your current custom nameplates."] = "Import custom nameplate settings from a string. The custom namneplates will be added to your current custom nameplates."
--[[Translation missing --]]
L["Import Custom Nameplates"] = "Import Custom Nameplates"
L["Import profile"] = "Импорт профиля"
L["Import/Export Profile"] = "Импорт/экспорт профиля"
L["In Combat"] = "В бою"
--[[Translation missing --]]
L["In combat, always show all combo points no matter if they are on or off. Off combo points are shown greyed-out."] = "In combat, always show all combo points no matter if they are on or off. Off combo points are shown greyed-out."
--[[Translation missing --]]
L["In combat, use coloring, transparency, and scaling based on threat level as configured in the threat system. Custom settings are only used out of combat."] = "In combat, use coloring, transparency, and scaling based on threat level as configured in the threat system. Custom settings are only used out of combat."
--[[Translation missing --]]
L["In delta mode, show the name of the player who is second in the enemy unit's threat table."] = "In delta mode, show the name of the player who is second in the enemy unit's threat table."
--[[Translation missing --]]
L["In Instances"] = "In Instances"
--[[Translation missing --]]
L["Initials"] = "Initials"
--[[Translation missing --]]
L["Insert a new custom nameplate slot after the currently selected slot."] = "Insert a new custom nameplate slot after the currently selected slot."
--[[Translation missing --]]
L["Inset"] = "Inset"
--[[Translation missing --]]
L["Insets"] = "Insets"
--[[Translation missing --]]
L["Inside"] = "Inside"
--[[Translation missing --]]
L["Instance IDs"] = "Instance IDs"
--[[Translation missing --]]
L["Instances"] = "Instances"
--[[Translation missing --]]
L["Interrupt Overlay"] = "Interrupt Overlay"
--[[Translation missing --]]
L["Interrupt Shield"] = "Interrupt Shield"
--[[Translation missing --]]
L["Interruptable"] = "Interruptable"
--[[Translation missing --]]
L["Interrupted"] = "Interrupted"
L["Kinetic Bomb"] = "Kinetic Bomb"
--[[Translation missing --]]
L["Label"] = "Label"
--[[Translation missing --]]
L["Label Text Offset"] = "Label Text Offset"
--[[Translation missing --]]
L["Large Bottom Inset"] = "Large Bottom Inset"
--[[Translation missing --]]
L["Large Top Inset"] = "Large Top Inset"
--[[Translation missing --]]
L["Last Word"] = "Last Word"
L["Layout"] = "Расположение"
L["Left"] = "Слева"
L["Left-to-right"] = "Слева-Направо"
--[[Translation missing --]]
L["Legacy custom nameplate %s already exists. Skipping it."] = "Legacy custom nameplate %s already exists. Skipping it."
--[[Translation missing --]]
L["Less-Than Arrow"] = "Less-Than Arrow"
--[[Translation missing --]]
L["Level "] = "Level "
L["Level"] = "Уровень"
--[[Translation missing --]]
L["Level ??"] = "Level ??"
L["Level Text"] = "Текст уровня"
L["Lich King"] = "Lich King"
L["Living Ember"] = "Living Ember"
L["Living Inferno"] = "Living Inferno"
L["Localization"] = "Локализация"
--[[Translation missing --]]
L["Look and Feel"] = "Look and Feel"
L["Low Threat"] = "Низкая угроза"
L["Magic"] = "Магия"
L["Marked Immortal Guardian"] = "Marked Immortal Guardian"
--[[Translation missing --]]
L["Max Alpha"] = "Max Alpha"
--[[Translation missing --]]
L["Max Auras"] = "Max Auras"
--[[Translation missing --]]
L["Max Distance"] = "Max Distance"
--[[Translation missing --]]
L["Max Distance Behind Camera"] = "Max Distance Behind Camera"
--[[Translation missing --]]
L["Max Health"] = "Max Health"
L["Medium Threat"] = "Средняя угроза"
--[[Translation missing --]]
L["Metric Unit Symbols"] = "Metric Unit Symbols"
--[[Translation missing --]]
L["Min Alpha"] = "Min Alpha"
--[[Translation missing --]]
L["Mine"] = "Mine"
--[[Translation missing --]]
L["Minions & By Status"] = "Minions & By Status"
L["Minor"] = "Незначительный"
--[[Translation missing --]]
L["Minuss"] = "Minors"
L["Mode"] = "Режим"
--[[Translation missing --]]
L["Mono"] = "Mono"
--[[Translation missing --]]
L["Motion & Overlap"] = "Motion & Overlap"
--[[Translation missing --]]
L["Motion Speed"] = "Motion Speed"
L["Mouseover"] = "Наведение мышкой"
--[[Translation missing --]]
L["Move Down"] = "Move Down"
--[[Translation missing --]]
L["Move Up"] = "Move Up"
--[[Translation missing --]]
L["Movement Model"] = "Movement Model"
L["Muddy Crawfish"] = "Muddy Crawfish"
--[[Translation missing --]]
L["Mult for Occluded Units"] = "Mult for Occluded Units"
L["Name"] = "Имя"
L["Nameplate Clickthrough"] = "Некликабельная плашка имени."
L["Nameplate clickthrough cannot be changed while in combat."] = "Настройки \"клик-насквозь\" не могут быть изменены в бою."
--[[Translation missing --]]
L["Nameplate Color"] = "Nameplate Color"
--[[Translation missing --]]
L["Nameplate Mode for Friendly Units in Combat"] = "Nameplate Mode for Friendly Units in Combat"
L["Nameplate Style"] = "Стиль Nameplates"
L["Names"] = "Имена"
L["Neutral"] = "Нейтральный"
L["Neutral NPCs"] = "Нейтральные NPCs"
L["Neutral Units"] = "Нейтральные юниты"
L["Neutral Units & Minions"] = "Нейтральные юниты & Миньоны"
L["Never"] = "Никогда"
L["New"] = "Новый"
L["No Outline, Monochrome"] = "Нет контура, монохромный"
L["No Target"] = "Нет цели"
L["No target found."] = "Цель не найдена."
L["None"] = "нет"
L["Non-Interruptable"] = "Не прерываемое"
--[[Translation missing --]]
L["Non-Target"] = "Non-Target"
L["Normal Units"] = "Обычная часть"
--[[Translation missing --]]
L["Not Myself"] = "Not Myself"
L["Note"] = "Заметка"
L["Nothing to paste!"] = "Нечего вставить!"
L["NPC Role"] = "NPC Роли"
L["NPC Role, Guild"] = "NPC Роли, Гильдия"
L["NPC Role, Guild, or Level"] = "NPC Роли, Гильдия и Уровень"
L["NPCs"] = "NPCs"
--[[Translation missing --]]
L["Numbers"] = "Numbers"
--[[Translation missing --]]
L["Occluded Units"] = "Occluded Units"
--[[Translation missing --]]
L["Off Combo Point"] = "Off Combo Point"
L["Offset"] = "Смещение"
L["Offset X"] = "Смещение X"
L["Offset Y"] = "Смещение Y"
L["Off-Tank"] = "Второй танк"
--[[Translation missing --]]
L["OmniCC"] = "OmniCC"
L["On & Off"] = "Включить & Выключить"
--[[Translation missing --]]
L["On Bosses & Rares"] = "On Bosses & Rares"
--[[Translation missing --]]
L["On Combo Point"] = "On Combo Point"
--[[Translation missing --]]
L["On Enemy Units You Cannot Attack"] = "On Enemy Units You Cannot Attack"
--[[Translation missing --]]
L["On Friendly Units in Combat"] = "On Friendly Units in Combat"
--[[Translation missing --]]
L["On Target"] = "On Target"
--[[Translation missing --]]
L["On the left"] = "On the left"
L["One"] = "Один"
L["Only Alternate Power"] = "Только альтернативная энергия"
--[[Translation missing --]]
L["Only for Target"] = "Only for Target"
--[[Translation missing --]]
L["Only In Combat"] = "Only In Combat"
--[[Translation missing --]]
L["Only in Groups"] = "Only in Groups"
--[[Translation missing --]]
L["Only in Instances"] = "Only in Instances"
--[[Translation missing --]]
L["Only Mine"] = "Only Mine"
L["Onyxian Whelp"] = "Onyxian Whelp"
L["Open Blizzard Settings"] = "Открыть настройки Blizzard "
L["Open Options"] = "Открыть параметры"
L["options:"] = "Настройки"
L["Orbs"] = "Сфера"
L["Out of Combat"] = "Выйти из боя"
--[[Translation missing --]]
L["Out Of Instances"] = "Out Of Instances"
L["Outline"] = "Контур"
L["Outline, Monochrome"] = "Контур, монохромный"
L["Overlapping"] = "Наложение"
L["Paladin"] = "Паладин"
L["Paste"] = "Вставить"
--[[Translation missing --]]
L["Paste the Threat Plates profile string into the text field below and then close the window"] = "Paste the Threat Plates profile string into the text field below and then close the window"
--[[Translation missing --]]
L["Percentage"] = "Percentage"
--[[Translation missing --]]
L["Percentage - Raw"] = "Percentage - Raw"
--[[Translation missing --]]
L["Percentage - Scaled"] = "Percentage - Scaled"
--[[Translation missing --]]
L["Percentage amount for horizontal overlap of nameplates."] = "Percentage amount for horizontal overlap of nameplates."
--[[Translation missing --]]
L["Percentage amount for vertical overlap of nameplates."] = "Percentage amount for vertical overlap of nameplates."
--[[Translation missing --]]
L["Personal Nameplate"] = "Personal Nameplate"
L["Pets"] = "Питомцы"
--[[Translation missing --]]
L["Pixel"] = "Pixel"
L["Pixel-Perfect UI"] = "Интерфейс идеальной подгонки пикселей"
L["Placement"] = "Размещение"
L["Players"] = "Игроки"
L["Poison"] = "Яд"
L["Position"] = "Позиция"
--[[Translation missing --]]
L["Positioning"] = "Positioning"
L["Preview"] = "Предпросмотр"
--[[Translation missing --]]
L["Preview Elite"] = "Preview Elite"
--[[Translation missing --]]
L["Preview Rare"] = "Preview Rare"
--[[Translation missing --]]
L["Preview Rare Elite"] = "Preview Rare Elite"
--[[Translation missing --]]
L["PvP Off"] = "PvP Off"
L["Quest"] = "Задание"
L["Quest Progress"] = "Прогресс задания"
L["Raging Spirit"] = "Яростный дух"
--[[Translation missing --]]
L["Rank Text"] = "Rank Text"
L["Rares & Bosses"] = "Редкие и боссы"
L["Rares & Elites"] = "Редкие и элитные"
--[[Translation missing --]]
L["Raw Percentage"] = "Raw Percentage"
L["Reaction"] = "Реакция"
L["Reanimated Adherent"] = "Reanimated Adherent"
L["Reanimated Fanatic"] = "Reanimated Fanatic"
--[[Translation missing --]]
L["Render font without antialiasing."] = "Render font without antialiasing."
L["Reset"] = "Сброс"
L["Reset to Defaults"] = "Сбросить на стандартные"
L["Resource"] = "Ресурс"
L["Resource Bar"] = "Полоса ресурса"
L["Resource Text"] = "Текст ресурса"
--[[Translation missing --]]
L["Resources on Targets"] = "Resources on Targets"
L["Reverse"] = "бьратный"
--[[Translation missing --]]
L["Reverse the sort order (e.g., \"A to Z\" becomes \"Z to A\")."] = "Reverse the sort order (e.g., \"A to Z\" becomes \"Z to A\")."
L["Right"] = "Права"
L["Right-to-left"] = "Справа налево"
L["Rogue"] = "Рога"
L["Roles"] = "Роли"
L["Row Limit"] = "Ограничение ряда"
L["Same as Background"] = "Также как на заднем плане"
--[[Translation missing --]]
L["Same as Bar Foreground"] = "Same as Bar Foreground"
L["Same as Foreground"] = "Также как на переднем плане"
--[[Translation missing --]]
L["Same as Name"] = "Same as Name"
L["Scale"] = "Масштаб"
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
L["Set Icon"] = "Выбрать значок"
L["Set scale settings for different threat levels."] = "Установить масштаб на основе разных уровней угрозы."
L["Set the roles your specs represent."] = "Установить роль на основе вашей специализации."
L["Set threat textures and their coloring options here."] = "Выбрать текстуру и расцветку угрозы."
--[[Translation missing --]]
L["Set transparency settings for different threat levels."] = "Set transparency settings for different threat levels."
--[[Translation missing --]]
L["Sets your role to DPS."] = "Sets your role to DPS."
--[[Translation missing --]]
L["Sets your role to tanking."] = "Sets your role to tanking."
L["Sets your spec "] = "Выбрать вашу специализацию"
--[[Translation missing --]]
L["Shadow"] = "Shadow"
L["Shadow Fiend"] = "Shadow Fiend"
L["Shadowy Apparition"] = "Теневой призрак"
L["Shambling Horror"] = "Ужас"
--[[Translation missing --]]
L["Shorten"] = "Shorten"
L["Show"] = "Показывать"
--[[Translation missing --]]
L["Show a tooltip when hovering above an aura."] = "Show a tooltip when hovering above an aura."
L["Show all buffs on enemy units."] = "Показывать все баффы вражеских юнитов."
L["Show all buffs on friendly units."] = "Показывать все баффы дружественных юнитов."
L["Show all buffs on NPCs."] = "Показать все баффы на NPCs."
--[[Translation missing --]]
L["Show all crowd control auras on enemy units."] = "Show all crowd control auras on enemy units."
--[[Translation missing --]]
L["Show all crowd control auras on friendly units."] = "Show all crowd control auras on friendly units."
L["Show all debuffs on enemy units."] = "Показывать все дебаффы на вражеских юнитах."
L["Show all debuffs on friendly units."] = "Показывать все дебаффы на дружественных юнитах."
L["Show All Nameplates (Friendly and Enemy Units) (CTRL-V)"] = "Показывать все Nameplates (Дружественных и Вражеских юнитов) (CTRL-V)"
L["Show Always"] = "Показывать всегда"
--[[Translation missing --]]
L["Show an quest icon at the nameplate for quest mobs."] = "Show an quest icon at the nameplate for quest mobs."
--[[Translation missing --]]
L["Show auras as bars (with optional icons)."] = "Show auras as bars (with optional icons)."
--[[Translation missing --]]
L["Show auras as icons in a grid configuration."] = "Show auras as icons in a grid configuration."
--[[Translation missing --]]
L["Show auras in order created with oldest aura first."] = "Show auras in order created with oldest aura first."
L["Show Blizzard Nameplates for Friendly Units"] = "Показывать Blizzard Nameplates для дружественных юнитах."
L["Show Blizzard Nameplates for Neutral and Enemy Units"] = "Показывать Blizzard Nameplates для дружественных юнитах и вражеских юнитов"
L["Show Buffs"] = "Показывать баффы"
--[[Translation missing --]]
L["Show buffs of dispell type Magic."] = "Show buffs of dispell type Magic."
--[[Translation missing --]]
L["Show buffs that were applied by you."] = "Show buffs that were applied by you."
--[[Translation missing --]]
L["Show buffs that you can apply."] = "Show buffs that you can apply."
--[[Translation missing --]]
L["Show buffs that you can dispell."] = "Show buffs that you can dispell."
--[[Translation missing --]]
L["Show buffs with unlimited duration in all situations (e.g., in and out of combat)."] = "Show buffs with unlimited duration in all situations (e.g., in and out of combat)."
L["Show By Unit Type"] = "Показывать типы целей"
--[[Translation missing --]]
L["Show Crowd Control"] = "Show Crowd Control"
--[[Translation missing --]]
L["Show crowd control auras hat are shown on Blizzard's default nameplates."] = "Show crowd control auras hat are shown on Blizzard's default nameplates."
--[[Translation missing --]]
L["Show crowd control auras that are shown on Blizzard's default nameplates."] = "Show crowd control auras that are shown on Blizzard's default nameplates."
--[[Translation missing --]]
L["Show crowd control auras that where applied by bosses."] = "Show crowd control auras that where applied by bosses."
--[[Translation missing --]]
L["Show crowd control auras that you can dispell."] = "Show crowd control auras that you can dispell."
L["Show Debuffs"] = "Показывать дебаффы"
--[[Translation missing --]]
L["Show debuffs that are shown on Blizzard's default nameplates."] = "Show debuffs that are shown on Blizzard's default nameplates."
--[[Translation missing --]]
L["Show debuffs that were applied by you."] = "Show debuffs that were applied by you."
--[[Translation missing --]]
L["Show debuffs that where applied by bosses."] = "Show debuffs that where applied by bosses."
--[[Translation missing --]]
L["Show debuffs that you can dispell."] = "Show debuffs that you can dispell."
--[[Translation missing --]]
L["Show Enemy Nameplates (ALT-V)"] = "Show Enemy Nameplates (ALT-V)"
L["Show Enemy Units"] = "Показывать вражеские юниты"
--[[Translation missing --]]
L["Show Focus"] = "Show Focus"
L["Show For"] = "Показать для"
L["Show Friendly Nameplates (SHIFT-V)"] = "Показывать дружественные Nameplates (SHIFT-V)"
L["Show Friendly Units"] = "Показывать дружественные цели"
L["Show Health Text"] = "Показывать текст здоровья"
L["Show Icon for Rares & Elites"] = "Показывать иконки для Рарников и Элиток"
L["Show Icon to the Left"] = "Отображать значок слева"
--[[Translation missing --]]
L["Show in Headline View"] = "Show in Headline View"
--[[Translation missing --]]
L["Show in Healthbar View"] = "Show in Healthbar View"
L["Show Level Text"] = "Отображать уровень"
--[[Translation missing --]]
L["Show Mouseover"] = "Show Mouseover"
L["Show Name Text"] = "Отображать текст имени"
L["Show Nameplate"] = "Отображать плашки"
L["Show nameplates at all times."] = "Показывать Nameplates все время."
L["Show Neutral Units"] = "Показывать нейтральные юниты"
L["Show Number"] = "Показывать номер"
L["Show Orb"] = "Показывать сферу"
--[[Translation missing --]]
L["Show shadow with text."] = "Show shadow with text."
L["Show Skull Icon"] = "Показывать иконку черепа"
--[[Translation missing --]]
L["Show stack count on auras."] = "Show stack count on auras."
L["Show Target"] = "Показывать цель"
--[[Translation missing --]]
L["Show the amount you need to loot or kill"] = "Show the amount you need to loot or kill"
--[[Translation missing --]]
L["Show the mouseover highlight on all units."] = "Show the mouseover highlight on all units."
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
--[[Translation missing --]]
L["Show threat feedback based on unit type or status or environmental conditions."] = "Show threat feedback based on unit type or status or environmental conditions."
--[[Translation missing --]]
L["Show time left on auras that have a duration."] = "Show time left on auras that have a duration."
--[[Translation missing --]]
L["Show unlimited buffs in combat."] = "Show unlimited buffs in combat."
--[[Translation missing --]]
L["Show unlimited buffs in instances (e.g., dungeons or raids)."] = "Show unlimited buffs in instances (e.g., dungeons or raids)."
--[[Translation missing --]]
L["Show unlimited buffs on bosses and rares."] = "Show unlimited buffs on bosses and rares."
L["Shows a border around the castbar of nameplates (requires /reload)."] = "Отображать границу вокруг полосы применения заклинание (требуется перезагрузка командой /rl)"
L["Shows a faction icon next to the nameplate of players."] = "Отображать значок фракции рядом с плашкой имени игроков."
L["Shows a glow based on threat level around the nameplate's healthbar (in combat)."] = "Отображать свечение плашки здоровья на основе уровня угрозы от цели (в бою)"
--[[Translation missing --]]
L["Shows a glow effect on auras that you can steal or purge."] = "Shows a glow effect on auras that you can steal or purge."
--[[Translation missing --]]
L["Shows a glow effect on this custom nameplate."] = "Shows a glow effect on this custom nameplate."
L["Shows an icon for friends and guild members next to the nameplate of players."] = "Отображать значок друзей и членов гильдии рядом с плашкой игроков."
L["Shows resource information for bosses and rares."] = "Отображать запас ресурса для боссов и редких существ."
L["Shows resource information only for alternatve power (of bosses or rares, mostly)."] = "Отображать запас альтернативного ресурса (для боссов и редкий существ в основном)"
--[[Translation missing --]]
L["Situational Scale"] = "Situational Scale"
--[[Translation missing --]]
L["Situational Transparency"] = "Situational Transparency"
L["Six"] = "Шесть"
L["Size"] = "Размер"
L["Skull"] = "Череп"
L["Skull Icon"] = "Значок черепа"
L["Social"] = "Общественный"
L["Sort A-Z"] = "Сортировать А-Я"
L["Sort by overall duration in ascending order."] = "Сортировать по общему времени действия."
L["Sort by time left in ascending order."] = "Сортировать по оставшемуся времени."
L["Sort in ascending alphabetical order."] = "Сортировать в алфавитном порядке."
L["Sort Order"] = "Прядок"
L["Sort Z-A"] = "Сортировать Я-А"
--[[Translation missing --]]
L["Spacing"] = "Spacing"
--[[Translation missing --]]
L["Spark"] = "Spark"
L["Special Effects"] = "Специальный эффект"
L["Specialization"] = "Специализация"
L["Spell Color:"] = "Цвет заклинания:"
L["Spell Icon"] = "Значок заклинания"
L["Spell Icon Size"] = "Размер значка заклинания"
L["Spell Name"] = "Название заклинания"
--[[Translation missing --]]
L["Spell Name Alignment"] = "Spell Name Alignment"
L["Spell Text"] = "Текст заклинания"
--[[Translation missing --]]
L["Spell Text Boundaries"] = "Spell Text Boundaries"
L["Spells (Name or ID)"] = "Заклинания (Имя или ИД)"
L["Spirit Wolf"] = "Дух волка"
L["Square"] = "Квадрат"
--[[Translation missing --]]
L["Squares"] = "Squares"
--[[Translation missing --]]
L["Stack Count"] = "Stack Count"
--[[Translation missing --]]
L["Stacking"] = "Stacking"
--[[Translation missing --]]
L["Standard"] = "Standard"
--[[Translation missing --]]
L["Status & Environment"] = "Status & Environment"
--[[Translation missing --]]
L["Status Text"] = "Status Text"
--[[Translation missing --]]
L["Steal or Purge Glow"] = "Steal or Purge Glow"
L["Stealth"] = "Незаметность"
--[[Translation missing --]]
L["Striped Texture"] = "Striped Texture"
--[[Translation missing --]]
L["Striped Texture Color"] = "Striped Texture Color"
--[[Translation missing --]]
L["Stripes"] = "Stripes"
L["Style"] = "Стиль"
--[[Translation missing --]]
L["Supports multiple entries, separated by commas."] = "Supports multiple entries, separated by commas."
--[[Translation missing --]]
L["Swap Area By Reaction"] = "Swap Area By Reaction"
--[[Translation missing --]]
L["Swap By Reaction"] = "Swap By Reaction"
--[[Translation missing --]]
L["Swap Scale By Reaction"] = "Swap Scale By Reaction"
--[[Translation missing --]]
L["Switch aura areas for buffs and debuffs for friendly units."] = "Switch aura areas for buffs and debuffs for friendly units."
--[[Translation missing --]]
L["Switch scale values for debuffs and buffs for friendly units."] = "Switch scale values for debuffs and buffs for friendly units."
L["Symbol"] = "Символ"
--[[Translation missing --]]
L["Syntax error in event script '%s' of custom style '%s': %s"] = "Syntax error in event script '%s' of custom style '%s': %s"
L["Tank"] = "Танк"
--[[Translation missing --]]
L["Tank Scaled Percentage"] = "Tank Scaled Percentage"
--[[Translation missing --]]
L["Tank Threat Value"] = "Tank Threat Value"
--[[Translation missing --]]
L["Tapped"] = "Tapped"
L["Tapped Units"] = "Выбранная цель"
L["Target"] = "Цель"
--[[Translation missing --]]
L["Target Highlight"] = "Target Highlight"
--[[Translation missing --]]
L["Target Hightlight"] = "Target Hightlight"
--[[Translation missing --]]
L["Target Marked"] = "Target Marked"
--[[Translation missing --]]
L["Target Marked Units"] = "Target Marked Units"
--[[Translation missing --]]
L["Target Marker"] = "Target Marker"
L["Target Markers"] = "Метки цели"
--[[Translation missing --]]
L["Target Offset X"] = "Target Offset X"
--[[Translation missing --]]
L["Target Offset Y"] = "Target Offset Y"
L["Target Only"] = "Только цель"
--[[Translation missing --]]
L["Target-based Scale"] = "Target-based Scale"
--[[Translation missing --]]
L["Target-based Transparency"] = "Target-based Transparency"
L["Text Boundaries"] = "Границы текста"
L["Text Height"] = "Высота текста"
L["Text Width"] = "Ширина текста"
--[[Translation missing --]]
L["Texts"] = "Texts"
L["Texture"] = "Текстура"
L["Textures"] = "Текстуры"
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
--[[Translation missing --]]
L["The inset from the bottom (in screen percent) that large nameplates are clamped to."] = "The inset from the bottom (in screen percent) that large nameplates are clamped to."
--[[Translation missing --]]
L["The inset from the bottom (in screen percent) that the non-self nameplates are clamped to."] = "The inset from the bottom (in screen percent) that the non-self nameplates are clamped to."
--[[Translation missing --]]
L["The inset from the top (in screen percent) that large nameplates are clamped to."] = "The inset from the top (in screen percent) that large nameplates are clamped to."
--[[Translation missing --]]
L["The inset from the top (in screen percent) that the non-self nameplates are clamped to."] = "The inset from the top (in screen percent) that the non-self nameplates are clamped to."
--[[Translation missing --]]
L["The max alpha of nameplates."] = "The max alpha of nameplates."
--[[Translation missing --]]
L["The max distance to show nameplates."] = "The max distance to show nameplates."
--[[Translation missing --]]
L["The max distance to show the target nameplate when the target is behind the camera."] = "The max distance to show the target nameplate when the target is behind the camera."
--[[Translation missing --]]
L["The minimum alpha of nameplates."] = "The minimum alpha of nameplates."
--[[Translation missing --]]
L["The player is friendly to you, and flagged for PvP."] = "The player is friendly to you, and flagged for PvP."
--[[Translation missing --]]
L["The player is hostile, and flagged for PvP, but you are not."] = "The player is hostile, and flagged for PvP, but you are not."
--[[Translation missing --]]
L["The scale of all nameplates if you have no target unit selected."] = "The scale of all nameplates if you have no target unit selected."
--[[Translation missing --]]
L["The scale of non-target nameplates if a target unit is selected."] = "The scale of non-target nameplates if a target unit is selected."
--[[Translation missing --]]
L["The script has overwritten the global '%s', this might affect other scripts ."] = "The script has overwritten the global '%s', this might affect other scripts ."
--[[Translation missing --]]
L["The size of the clickable area is always derived from the current size of the healthbar."] = "The size of the clickable area is always derived from the current size of the healthbar."
--[[Translation missing --]]
L["The target nameplate's scale if a target unit is selected."] = "The target nameplate's scale if a target unit is selected."
--[[Translation missing --]]
L["The target nameplate's transparency if a target unit is selected."] = "The target nameplate's transparency if a target unit is selected."
--[[Translation missing --]]
L["The transparency of all nameplates if you have no target unit selected."] = "The transparency of all nameplates if you have no target unit selected."
--[[Translation missing --]]
L["The transparency of non-target nameplates if a target unit is selected."] = "The transparency of non-target nameplates if a target unit is selected."
--[[Translation missing --]]
L["These options allow you to control whether target marker icons are hidden or shown on nameplates and whether a nameplate's healthbar (in healthbar view) or name (in headline view) are colored based on target markers."] = "These options allow you to control whether target marker icons are hidden or shown on nameplates and whether a nameplate's healthbar (in healthbar view) or name (in headline view) are colored based on target markers."
--[[Translation missing --]]
L["These options allow you to control whether the castbar is hidden or shown on nameplates."] = "These options allow you to control whether the castbar is hidden or shown on nameplates."
--[[Translation missing --]]
L["These options allow you to control which nameplates are visible within the game field while you play."] = "These options allow you to control which nameplates are visible within the game field while you play."
--[[Translation missing --]]
L["These settings will define the space that text can be placed on the nameplate."] = "These settings will define the space that text can be placed on the nameplate."
--[[Translation missing --]]
L["These settings will define the space that text can be placed on the nameplate. Having too large a font and not enough height will cause the text to be not visible."] = "These settings will define the space that text can be placed on the nameplate. Having too large a font and not enough height will cause the text to be not visible."
--[[Translation missing --]]
L["Thick"] = "Thick"
L["Thick Outline"] = "Толстый контур"
L["Thick Outline, Monochrome"] = "Толстый контур, монохромный"
--[[Translation missing --]]
L["Thin Square"] = "Thin Square"
--[[Translation missing --]]
L["This lets you select the layout style of the auras area."] = "This lets you select the layout style of the auras area."
--[[Translation missing --]]
L["This lets you select the layout style of the auras widget."] = "This lets you select the layout style of the auras widget."
--[[Translation missing --]]
L["This option allows you to control whether a cast's remaining cast time is hidden or shown on castbars."] = "This option allows you to control whether a cast's remaining cast time is hidden or shown on castbars."
--[[Translation missing --]]
L["This option allows you to control whether a spell's icon is hidden or shown on castbars."] = "This option allows you to control whether a spell's icon is hidden or shown on castbars."
--[[Translation missing --]]
L["This option allows you to control whether a spell's name is hidden or shown on castbars."] = "This option allows you to control whether a spell's name is hidden or shown on castbars."
--[[Translation missing --]]
L["This option allows you to control whether a unit's health is hidden or shown on nameplates."] = "This option allows you to control whether a unit's health is hidden or shown on nameplates."
--[[Translation missing --]]
L["This option allows you to control whether a unit's level is hidden or shown on nameplates."] = "This option allows you to control whether a unit's level is hidden or shown on nameplates."
--[[Translation missing --]]
L["This option allows you to control whether a unit's name is hidden or shown on nameplates."] = "This option allows you to control whether a unit's name is hidden or shown on nameplates."
--[[Translation missing --]]
L["This option allows you to control whether custom settings for nameplate style, color, transparency and scaling should be used for this nameplate."] = "This option allows you to control whether custom settings for nameplate style, color, transparency and scaling should be used for this nameplate."
--[[Translation missing --]]
L["This option allows you to control whether headline view (text-only) is enabled for nameplates."] = "This option allows you to control whether headline view (text-only) is enabled for nameplates."
--[[Translation missing --]]
L["This option allows you to control whether nameplates should fade in when displayed."] = "This option allows you to control whether nameplates should fade in when displayed."
--[[Translation missing --]]
L["This option allows you to control whether textures are hidden or shown on nameplates for different threat levels. Dps/healing uses regular textures, for tanking textures are swapped."] = "This option allows you to control whether textures are hidden or shown on nameplates for different threat levels. Dps/healing uses regular textures, for tanking textures are swapped."
--[[Translation missing --]]
L["This option allows you to control whether the custom icon is hidden or shown on this nameplate."] = "This option allows you to control whether the custom icon is hidden or shown on this nameplate."
--[[Translation missing --]]
L["This option allows you to control whether the icon for rare & elite units is hidden or shown on nameplates."] = "This option allows you to control whether the icon for rare & elite units is hidden or shown on nameplates."
--[[Translation missing --]]
L["This option allows you to control whether the skull icon for boss units is hidden or shown on nameplates."] = "This option allows you to control whether the skull icon for boss units is hidden or shown on nameplates."
--[[Translation missing --]]
L["This option allows you to control whether threat affects the healthbar color of nameplates."] = "This option allows you to control whether threat affects the healthbar color of nameplates."
--[[Translation missing --]]
L["This option allows you to control whether threat affects the scale of nameplates."] = "This option allows you to control whether threat affects the scale of nameplates."
--[[Translation missing --]]
L["This option allows you to control whether threat affects the transparency of nameplates."] = "This option allows you to control whether threat affects the transparency of nameplates."
--[[Translation missing --]]
L["This setting will disable threat scale for target marked, mouseover or casting units and instead use the general scale settings."] = "This setting will disable threat scale for target marked, mouseover or casting units and instead use the general scale settings."
--[[Translation missing --]]
L["This setting will disable threat transparency for target marked, mouseover or casting units and instead use the general transparency settings."] = "This setting will disable threat transparency for target marked, mouseover or casting units and instead use the general transparency settings."
--[[Translation missing --]]
L["This widget highlights the nameplate of your current focus target by showing a border around the healthbar and by coloring the nameplate's healtbar and/or name with a custom color."] = "This widget highlights the nameplate of your current focus target by showing a border around the healthbar and by coloring the nameplate's healtbar and/or name with a custom color."
--[[Translation missing --]]
L["This widget highlights the nameplate of your current target by showing a border around the healthbar and by coloring the nameplate's healtbar and/or name with a custom color."] = "This widget highlights the nameplate of your current target by showing a border around the healthbar and by coloring the nameplate's healtbar and/or name with a custom color."
--[[Translation missing --]]
L["This widget shows a class icon on the nameplates of players."] = "This widget shows a class icon on the nameplates of players."
--[[Translation missing --]]
L["This widget shows a quest icon above unit nameplates or colors the nameplate healthbar of units that are involved with any of your current quests."] = "This widget shows a quest icon above unit nameplates or colors the nameplate healthbar of units that are involved with any of your current quests."
--[[Translation missing --]]
L["This widget shows a stealth icon on nameplates of units that can detect stealth."] = "This widget shows a stealth icon on nameplates of units that can detect stealth."
--[[Translation missing --]]
L["This widget shows a unit's auras (buffs and debuffs) on its nameplate."] = "This widget shows a unit's auras (buffs and debuffs) on its nameplate."
--[[Translation missing --]]
L["This widget shows an experience bar for player followers."] = "This widget shows an experience bar for player followers."
--[[Translation missing --]]
L["This widget shows auras from boss mods on your nameplates (since patch 7.2, hostile nameplates only in instances and raids)."] = "This widget shows auras from boss mods on your nameplates (since patch 7.2, hostile nameplates only in instances and raids)."
--[[Translation missing --]]
L["This widget shows icons for friends, guild members, and faction on nameplates."] = "This widget shows icons for friends, guild members, and faction on nameplates."
--[[Translation missing --]]
L["This widget shows information about your target's resource on your target nameplate. The resource bar's color is derived from the type of resource automatically."] = "This widget shows information about your target's resource on your target nameplate. The resource bar's color is derived from the type of resource automatically."
--[[Translation missing --]]
L["This widget shows players that are healers."] = "This widget shows players that are healers."
--[[Translation missing --]]
L["This widget shows various icons (orbs and numbers) on enemy nameplates in arenas for easier differentiation."] = "This widget shows various icons (orbs and numbers) on enemy nameplates in arenas for easier differentiation."
--[[Translation missing --]]
L["This widget shows your combo points on your target nameplate."] = "This widget shows your combo points on your target nameplate."
--[[Translation missing --]]
L["This will allow you to disable threat art on target marked units."] = "This will allow you to disable threat art on target marked units."
--[[Translation missing --]]
L["This will color the aura based on its type (poison, disease, magic, curse) - for Icon Mode the icon border is colored, for Bar Mode the bar itself."] = "This will color the aura based on its type (poison, disease, magic, curse) - for Icon Mode the icon border is colored, for Bar Mode the bar itself."
--[[Translation missing --]]
L["This will format text to a simpler format using M or K for millions and thousands. Disabling this will show exact absorbs amounts."] = "This will format text to a simpler format using M or K for millions and thousands. Disabling this will show exact absorbs amounts."
--[[Translation missing --]]
L["This will format text to a simpler format using M or K for millions and thousands. Disabling this will show exact health amounts."] = "This will format text to a simpler format using M or K for millions and thousands. Disabling this will show exact health amounts."
L["This will format text to show both the maximum hp and current hp."] = "This will format text to show both the maximum hp and current hp."
L["This will format text to show hp as a value the target is missing."] = "This will format text to show hp as a value the target is missing."
--[[Translation missing --]]
L["This will toggle the auras widget to only show for your current target."] = "This will toggle the auras widget to only show for your current target."
--[[Translation missing --]]
L["This will toggle the auras widget to show the cooldown spiral on auras."] = "This will toggle the auras widget to show the cooldown spiral on auras."
--[[Translation missing --]]
L["Threat Detection"] = "Threat Detection"
--[[Translation missing --]]
L["Threat Detection Heuristic"] = "Threat Detection Heuristic"
L["Threat Glow"] = "Свечение угрозы"
--[[Translation missing --]]
L["Threat Plates Script Editor"] = "Threat Plates Script Editor"
L["Threat System"] = "Система угрозы"
L["Threat Table"] = "Таблица угроз"
--[[Translation missing --]]
L["Threat Value Delta"] = "Threat Value Delta"
L["Three"] = "Три"
--[[Translation missing --]]
L["Time Left"] = "Time Left"
--[[Translation missing --]]
L["Time Text Offset"] = "Time Text Offset"
--[[Translation missing --]]
L["Toggle"] = "Toggle"
--[[Translation missing --]]
L["Toggle Enemy Headline View"] = "Toggle Enemy Headline View"
--[[Translation missing --]]
L["Toggle Friendly Headline View"] = "Toggle Friendly Headline View"
--[[Translation missing --]]
L["Toggle Neutral Headline View"] = "Toggle Neutral Headline View"
--[[Translation missing --]]
L["Toggle on Target"] = "Toggle on Target"
L["Toggling"] = "Переключение"
L["Tooltips"] = "Подсказки"
L["Top"] = "Вверх"
L["Top Inset"] = "Верхняя вставка"
L["Top Left"] = "Вверх слева"
L["Top Right"] = "Вверх справа"
L["Top-to-bottom"] = "Сверху вниз"
L["Totem Scale"] = "Масштаб тотема"
L["Totem Transparency"] = "Прозрачность тотема"
L["Totems"] = "Тотемы"
--[[Translation missing --]]
L["Transliterate Cyrillic Letters"] = "Transliterate Cyrillic Letters"
L["Transparency"] = "Прозрачность"
L["Transparency & Scaling"] = "Прозрачность & Масштабирование "
L["Treant"] = "Treant"
--[[Translation missing --]]
L["Trigger"] = "Trigger"
L["Two"] = "Два"
L["Type"] = "Шрифт"
--[[Translation missing --]]
L["Typeface"] = "Typeface"
--[[Translation missing --]]
L["UI Scale"] = "UI Scale"
--[[Translation missing --]]
L["Unable to change a setting while in combat."] = "Unable to change a setting while in combat."
--[[Translation missing --]]
L["Unable to change the following console variable while in combat: "] = "Unable to change the following console variable while in combat: "
--[[Translation missing --]]
L["Unable to change transparency for occluded units while in combat."] = "Unable to change transparency for occluded units while in combat."
L["Undetermined"] = "Неопределенный"
--[[Translation missing --]]
L["Unfriendly"] = "Unfriendly"
--[[Translation missing --]]
L["Uniform Color"] = "Uniform Color"
--[[Translation missing --]]
L["Unit Base Scale"] = "Unit Base Scale"
--[[Translation missing --]]
L["Unit Base Transparency"] = "Unit Base Transparency"
--[[Translation missing --]]
L["Unknown option: "] = "Unknown option: "
--[[Translation missing --]]
L["Unlimited Duration"] = "Unlimited Duration"
--[[Translation missing --]]
L["Usage: /tptp [options]"] = "Usage: /tptp [options]"
--[[Translation missing --]]
L["Use a custom color for healthbar (in healthbar view) or name (in headline view) of friends and/or guild members."] = "Use a custom color for healthbar (in healthbar view) or name (in headline view) of friends and/or guild members."
--[[Translation missing --]]
L["Use a custom color for the background."] = "Use a custom color for the background."
--[[Translation missing --]]
L["Use a custom color for the bar background."] = "Use a custom color for the bar background."
--[[Translation missing --]]
L["Use a custom color for the bar's border."] = "Use a custom color for the bar's border."
--[[Translation missing --]]
L["Use a custom color for the castbar's background."] = "Use a custom color for the castbar's background."
--[[Translation missing --]]
L["Use a custom color for the healtbar's background."] = "Use a custom color for the healtbar's background."
--[[Translation missing --]]
L["Use a custom color for the healtbar's border."] = "Use a custom color for the healtbar's border."
--[[Translation missing --]]
L["Use a custom color for the healthbar of quest mobs."] = "Use a custom color for the healthbar of quest mobs."
--[[Translation missing --]]
L["Use a custom color for the healthbar of your current focus target."] = "Use a custom color for the healthbar of your current focus target."
--[[Translation missing --]]
L["Use a custom color for the healthbar of your current target."] = "Use a custom color for the healthbar of your current target."
--[[Translation missing --]]
L["Use a custom color for the name of your current focus target (in healthbar view and in headline view)."] = "Use a custom color for the name of your current focus target (in healthbar view and in headline view)."
--[[Translation missing --]]
L["Use a custom color for the name of your current target (in healthbar view and in headline view)."] = "Use a custom color for the name of your current target (in healthbar view and in headline view)."
--[[Translation missing --]]
L["Use a heuristic instead of a mob's threat table to detect if you are in combat with a mob (see Threat System - General Settings for a more detailed explanation)."] = "Use a heuristic instead of a mob's threat table to detect if you are in combat with a mob (see Threat System - General Settings for a more detailed explanation)."
--[[Translation missing --]]
L["Use a heuristic to detect if a mob is in combat with you, but only in instances (like dungeons or raids)."] = "Use a heuristic to detect if a mob is in combat with you, but only in instances (like dungeons or raids)."
--[[Translation missing --]]
L["Use a striped texture for the absorbs overlay. Always enabled if full absorbs are shown."] = "Use a striped texture for the absorbs overlay. Always enabled if full absorbs are shown."
--[[Translation missing --]]
L["Use Blizzard default nameplates for friendly nameplates and disable ThreatPlates for these units."] = "Use Blizzard default nameplates for friendly nameplates and disable ThreatPlates for these units."
--[[Translation missing --]]
L["Use Blizzard default nameplates for neutral and enemy nameplates and disable ThreatPlates for these units."] = "Use Blizzard default nameplates for neutral and enemy nameplates and disable ThreatPlates for these units."
--[[Translation missing --]]
L["Use scale settings of Healthbar View also for Headline View."] = "Use scale settings of Healthbar View also for Headline View."
--[[Translation missing --]]
L["Use target-based scale as absolute scale and ignore unit base scale."] = "Use target-based scale as absolute scale and ignore unit base scale."
--[[Translation missing --]]
L["Use target-based transparency as absolute transparency and ignore unit base transparency."] = "Use target-based transparency as absolute transparency and ignore unit base transparency."
L["Use Target's Name"] = "Используйте имя целей"
--[[Translation missing --]]
L["Use the background color also for the border."] = "Use the background color also for the border."
--[[Translation missing --]]
L["Use the bar foreground color also for the background."] = "Use the bar foreground color also for the background."
--[[Translation missing --]]
L["Use the bar foreground color also for the bar background."] = "Use the bar foreground color also for the bar background."
--[[Translation missing --]]
L["Use the bar foreground color also for the border."] = "Use the bar foreground color also for the border."
--[[Translation missing --]]
L["Use the castbar's foreground color also for the background."] = "Use the castbar's foreground color also for the background."
--[[Translation missing --]]
L["Use the healthbar's background color also for the border."] = "Use the healthbar's background color also for the border."
--[[Translation missing --]]
L["Use the healthbar's foreground color also for the background."] = "Use the healthbar's foreground color also for the background."
--[[Translation missing --]]
L["Use the healthbar's foreground color also for the border."] = "Use the healthbar's foreground color also for the border."
--[[Translation missing --]]
L["Use the same color for all combo points shown."] = "Use the same color for all combo points shown."
--[[Translation missing --]]
L["Use Threat Color"] = "Use Threat Color"
--[[Translation missing --]]
L["Use threat scale as additive scale and add or substract it from the general scale settings."] = "Use threat scale as additive scale and add or substract it from the general scale settings."
--[[Translation missing --]]
L["Use threat transparency as additive transparency and add or substract it from the general transparency settings."] = "Use threat transparency as additive transparency and add or substract it from the general transparency settings."
--[[Translation missing --]]
L["Use transparency settings of Healthbar View also for Headline View."] = "Use transparency settings of Healthbar View also for Headline View."
--[[Translation missing --]]
L["Uses the target-based transparency as absolute transparency and ignore unit base transparency."] = "Uses the target-based transparency as absolute transparency and ignore unit base transparency."
L["Val'kyr Shadowguard"] = "Val'kyr Shadowguard"
--[[Translation missing --]]
L["Value"] = "Value"
--[[Translation missing --]]
L["Value Type"] = "Value Type"
L["Venomous Snake"] = "Venomous Snake"
L["Vertical Align"] = "Вертикальное выравнивание"
L["Vertical Alignment"] = "Вертикальное выравнивание"
L["Vertical Offset"] = "Вертикальное смещение"
L["Vertical Overlap"] = "Вертикальное перекрытие"
L["Vertical Spacing"] = "Вертикальное расстояние"
L["Viper"] = "Змея"
L["Visibility"] = "Отображение"
L["Volatile Ooze"] = "Volatile Ooze"
L["Warlock"] = "Варлок"
L["Warning Glow for Threat"] = "Предупреждающее свечение для угроз"
L["Water Elemental"] = "Водный элементаль"
L["Web Wrap"] = "Кокон"
L["We're unable to change this while in combat"] = "Вы не можете изменить это во время боя"
L["Wide"] = "Ширина"
L["Widgets"] = "Виджеты"
L["Width"] = "Ширина"
L["Windwalker Monk"] = "Танцующий с ветром монах "
--[[Translation missing --]]
L["Word Wrap"] = "Word Wrap"
--[[Translation missing --]]
L["World Boss"] = "World Boss"
L["X"] = "X"
L["Y"] = "Y"
L["You can access the "] = "Вы можете получить доступ к"
L["You cannot delete General Settings, only custom nameplates entries."] = "Ты не можешь удалить базовые настройки, только пользовательские nameplates записи."
L["You currently have two nameplate addons enabled: |cff89F559Threat Plates|r and |cff89F559%s|r. Please disable one of these, otherwise two overlapping nameplates will be shown for units."] = "В настоящее время у вас включены 2 аддона на nameplates: |cff89F559Threat Plates|r и |cff89F559%s|r. Пожалуйста, отключите один из них, в противном случае два наложения nameplates будет показано для юнитов."
L["Your own quests that you have to complete."] = "Ваши собственные задания, которые вы должны выполнить."
L["Your version of LibDogTag-Unit-3.0 does not support nameplates. You need to install at least v90000.3 of LibDogTag-Unit-3.0."] = "Ваша версия LibDogTag-Unit-3.0 не поддерживает таблички с именами. Вам необходимо установить не менее v90000.3 LibDogTag-Unit-3.0."
