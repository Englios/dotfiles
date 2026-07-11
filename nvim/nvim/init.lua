-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")
vim.opt.clipboard = "unnamedplus"

if vim.fn.executable("wl-copy") == 0
    and vim.fn.executable("xclip") == 0
    and vim.fn.executable("xsel") == 0
    and vim.fn.executable("pbcopy") == 0 then
  local osc52 = require("vim.ui.clipboard.osc52")
  vim.g.clipboard = {
    name = "OSC 52",
    copy = {
      ["+"] = osc52.copy("+"),
      ["*"] = osc52.copy("*"),
    },
    paste = {
      ["+"] = osc52.paste("+"),
      ["*"] = osc52.paste("*"),
    },
  }
end
