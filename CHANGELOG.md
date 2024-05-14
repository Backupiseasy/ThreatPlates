# @project-version@ (@build-time@)

* Fixed a bug with the calculation of the clickable area of Threat Plates. Now, the clickable area of Threat Plates and Blizzard nameplates is the same if their healthbar size is the same. This also ensures that the stacking and overlapping behavior is the same for Threat Plates and Blizzard nameplates [GH-465, GH-495].
* Fixed a bug with target highlight that occurred when the highlight style was changed with no active target, resulting in the highlight texture not being updated [GH-515].
* Fixed a Lua error that occurred when switching active specialization on a Deathknight [GH-518]. 
* Updated localizations.
