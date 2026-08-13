# @project-version@ (@build-time@)

* Fix Lua error when displaying auras on nameplates caused by restrictions on secret values [GH-723].
* Rebuilt the Auras widget on top of Patch 12.1.0's new AuraContainer API, since the old aura-scanning method no longer works reliably. Currently only rudimentary aura features are available as a result.