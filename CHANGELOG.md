# @project-version@ (@build-time@)

* Fixed a Lua error when a numeric CVar has an invalid, i.e., non-numeric, value. In this case, the default value of the CVar will now be used to prevent the Lua error.
