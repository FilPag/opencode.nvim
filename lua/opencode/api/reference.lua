local M = {}

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

      return context.server:resolve_session():next(function(session)
        return context.server:synthetic(session.id, plaintext)
      end)
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
