return {
  {
    "mason-org/mason.nvim",
    opts = {
      ensure_installed = {
        "vtsls",
        "eslint-lsp",
        "prettier",
        "clangd",
      },
    },
  },
}
