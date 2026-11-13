-- This line is rewritten by `scripts/theme.sh`: "dark" or "light", which is
-- also the 'background' that picks gruvbox's palette.
local flavour = "dark"

-- `scripts/theme.sh` sends every running nvim SIGUSR1 after a switch. Re-read
-- the flavour line above from disk, so open editors follow along live.
local function reload_flavour()
  local path = vim.fn.stdpath("config") .. "/lua/plugins/theme.lua"
  for _, line in ipairs(vim.fn.readfile(path)) do
    local f = line:match('^local flavour = "(%a+)"')
    if f then
      vim.o.background = f
      vim.cmd.colorscheme("gruvbox")
      return
    end
  end
end

return {
  {
    "ellisonleao/gruvbox.nvim",
    priority = 1000,
    opts = {},
    init = function()
      vim.o.background = flavour

      vim.api.nvim_create_autocmd("Signal", {
        pattern = "SIGUSR1",
        desc = "Reload the gruvbox flavour written by scripts/theme.sh",
        callback = function()
          vim.schedule(reload_flavour)
        end,
      })
    end,
  },

  -- LazyVim defaults to tokyonight; without this the gruvbox spec above is
  -- installed but never actually loaded.
  {
    "LazyVim/LazyVim",
    opts = { colorscheme = "gruvbox" },
  },
}
