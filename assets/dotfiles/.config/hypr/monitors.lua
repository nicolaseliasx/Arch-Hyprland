-- Portable fallback: preferred resolution, automatic placement and no scaling.
-- Machine-specific rules can be added before this fallback when required.
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })
