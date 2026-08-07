hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
hl.gesture({ fingers = 4, direction = "up", action = function() hl.exec_cmd("$HOME/.config/hypr/scripts/Zoom.sh in 1.5") end })
hl.gesture({ fingers = 4, direction = "down", action = function() hl.exec_cmd("$HOME/.config/hypr/scripts/Zoom.sh out 1.5") end })
hl.gesture({ fingers = 3, direction = "up", action = function() hl.exec_cmd("$HOME/.config/hypr/scripts/OverviewToggle.sh") end })
hl.device({
  name = "asue1209:00-04f3:319f-touchpad",
  enabled = true,
})
