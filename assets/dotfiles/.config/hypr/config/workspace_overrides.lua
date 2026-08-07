hl.workspace_rule({ workspace = "special:special", gaps_in = 8, gaps_out = 15 })
hl.on("hyprland.start", function() hl.exec_cmd("hyprctl dispatch workspace 1") end)
