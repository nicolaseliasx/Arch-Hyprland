return {
  {
    "nvim-lualine/lualine.nvim",
    event = "VeryLazy",
    opts = function(_, opts)
      opts.sections = opts.sections or {}
      opts.sections.lualine_x = opts.sections.lualine_x or {}

      table.insert(opts.sections.lualine_x, 1, {
        function()
          return "HLP"
        end,
        color = function()
          return { fg = Snacks.util.color("Special"), gui = "bold" }
        end,
        on_click = function()
          require("config.hlp").toggle()
        end,
        padding = { left = 1, right = 1 },
      })
    end,
  },
}
