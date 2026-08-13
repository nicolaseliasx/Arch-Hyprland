hl.workspace_rule({ workspace = "special:special", gaps_in = 0, gaps_out = 0 })
hl.on("hyprland.start", function() hl.exec_cmd("hyprctl dispatch workspace 1") end)
