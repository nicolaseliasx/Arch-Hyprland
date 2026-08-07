return {
  {
    "folke/tokyonight.nvim",
    priority = 1000,
    opts = {
      style = "night",
      transparent = false,
      styles = {
        sidebars = "dark",
        floats = "dark",
      },
      on_colors = function(colors)
        colors.bg = "#1e1e1e"
        colors.bg_dark = "#181818"
        colors.bg_float = "#252526"
        colors.bg_highlight = "#2a2d2e"
        colors.bg_popup = "#252526"
        colors.bg_search = "#264f78"
        colors.bg_sidebar = "#252526"
        colors.border = "#3c3c3c"
        colors.comment = "#6a9955"
        colors.fg = "#d4d4d4"
        colors.fg_dark = "#cccccc"
        colors.fg_float = "#d4d4d4"
        colors.blue = "#569cd6"
        colors.cyan = "#4ec9b0"
        colors.green = "#6a9955"
        colors.magenta = "#c586c0"
        colors.orange = "#ce9178"
        colors.purple = "#c586c0"
        colors.red = "#f44747"
        colors.yellow = "#dcdcaa"
      end,
      on_highlights = function(hl, colors)
        hl.Normal = { fg = colors.fg, bg = colors.bg }
        hl.NormalFloat = { fg = colors.fg_float, bg = colors.bg_float }
        hl.FloatBorder = { fg = colors.border, bg = colors.bg_float }
        hl.CursorLine = { bg = colors.bg_highlight }
        hl.LineNr = { fg = "#858585" }
        hl.CursorLineNr = { fg = "#c6c6c6", bold = true }
        hl.SignColumn = { bg = colors.bg }
        hl.StatusLine = { fg = colors.fg, bg = "#007acc" }
        hl.StatusLineNC = { fg = "#858585", bg = "#181818" }
        hl.WinSeparator = { fg = colors.border }
        hl.VertSplit = { fg = colors.border }
        hl.Pmenu = { fg = colors.fg, bg = colors.bg_popup }
        hl.PmenuSel = { fg = "#ffffff", bg = "#04395e" }
        hl.Visual = { bg = "#264f78" }
        hl.Search = { fg = "#ffffff", bg = colors.bg_search }
        hl.IncSearch = { fg = "#000000", bg = "#ffcc00" }
      end,
    },
  },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "tokyonight",
    },
  },
}
