-- The colourscheme follows the desktop theme: theme-apply writes the name to
-- ~/.config/theme-active/nvim-colorscheme. Falls back to catppuccin-mocha.
local theme_dir = vim.fn.expand("~/.config/theme-active")
local theme_file = theme_dir .. "/nvim-colorscheme"

local function read_name()
  local f = io.open(theme_file)
  if not f then
    return "catppuccin-mocha"
  end
  local name = f:read("*l")
  f:close()
  return (name and name ~= "") and name or "catppuccin-mocha"
end

local function apply()
  local name = read_name()
  if vim.g.colors_name ~= name then
    pcall(vim.cmd.colorscheme, name)
  end
end

-- Re-apply in already-open nvims when theme-apply rewrites the file.
local watcher
local function watch()
  if watcher or vim.fn.isdirectory(theme_dir) == 0 then
    return
  end
  watcher = vim.uv.new_fs_event()
  watcher:start(theme_dir, {}, function(_, filename)
    if filename == "nvim-colorscheme" then
      vim.schedule(apply)
    end
  end)
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
      -- LazyVim calls this function and ignores its return value, so it has
      -- to load the colourscheme itself.
      colorscheme = function()
        apply()
        watch()
      end,
    },
  },
}
