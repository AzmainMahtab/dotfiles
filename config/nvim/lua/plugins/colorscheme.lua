-- The colourscheme follows the desktop theme (theme-apply writes the name to
-- ~/.config/theme-active/nvim-colorscheme); falls back to catppuccin-mocha.
local function desktop_colorscheme()
  local f = io.open(vim.fn.expand("~/.config/theme-active/nvim-colorscheme"))
  if not f then
    return "catppuccin-mocha"
  end
  local name = f:read("*l")
  f:close()
  return (name and name ~= "") and name or "catppuccin-mocha"
end

return {
  {
    "catppuccin/catppuccin",
    name = "catppuccin",
    priority = 1000,
    opts = {
      flavour = "mocha",
    },
  },
  { "ellisonleao/gruvbox.nvim", priority = 1000 },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = desktop_colorscheme,
    },
  },
}
