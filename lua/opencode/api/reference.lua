local M = {}

---The opencode TUI running in a Neovim terminal, if any.
---@return integer?
local function tui_buffer()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buftype == "terminal" then
      local command = vim.api.nvim_buf_get_name(buf):match("//%d+:(.+)$")
      if command and command:match("^opencode") then
        return buf
      end
    end
  end
end

---Whether `buf` resolves to real files, as opposed to literal text.
---@param buf integer
---@return boolean
local function file_backed(buf)
  if vim.bo[buf].filetype == "oil" then
    return true
  end
  local name = vim.api.nvim_buf_get_name(buf)
  local stat = name ~= "" and vim.uv.fs_stat(name) or nil
  return stat ~= nil and stat.type == "file"
end

---Type a rendered reference into the opencode TUI's prompt input.
---
---Sends keystrokes to the TUI's terminal, so it requires the TUI to be running
---in a Neovim terminal (e.g. `:vsplit term://opencode`).
---
---@param text string
---@param context opencode.context.Context
---@return Promise<any>
function M.reference(text, context)
  local Promise = require("opencode.promise")
  return (
    text:match("%.%.%.$") and require("opencode.ui.ask").ask(text:gsub("%.%.%.$", ""), context)
    or Promise.resolve(text)
  )
    :next(function(_text)
      local plaintext = context:render(_text).output:plaintext()
      if _text:find("@", 1, true) and file_backed(context.buf) then
        plaintext = "@" .. plaintext:gsub(", ", ", @")
      end

      local buf = tui_buffer()
      if not buf then
        return Promise.reject("No opencode TUI terminal found. Open one with `:vsplit term://opencode`.")
      end

      local channel = vim.bo[buf].channel
      if not channel or channel == 0 then
        return Promise.reject("The opencode TUI terminal has no channel.")
      end

      vim.fn.chansend(channel, plaintext .. " ")
    end)
    :next(function()
      context:clear()
    end)
    :catch(function(err)
      context:resume()
      return Promise.reject(err)
    end)
end

return M
