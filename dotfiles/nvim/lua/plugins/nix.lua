return {
  -- Disable mason — LSPs/formatters are installed via Nix
  { "mason-org/mason.nvim", enabled = false },
  { "mason-org/mason-lspconfig.nvim", enabled = false },

  -- Treesitter parsers are Nix-built, don't auto-install
  {
    "nvim-treesitter/nvim-treesitter",
    opts = { ensure_installed = {} },
  },
}
