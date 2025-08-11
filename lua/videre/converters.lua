local utils = require("videre.utils")

local M = {}

---Converts object to its string representation
---@param val any
---@param no_quotes boolean | nil
---@param lang_spec LangSpec
---@return string | nil
M.GetValAsString = function(val, no_quotes, lang_spec)
    if val == vim.NIL then
        return lang_spec.symbols.null or "null"
    elseif val == vim.empty_dict() then
        return lang_spec.symbols.tbl or "{}"
    elseif type(val) == "string" then
        if no_quotes then
            return utils.escape_string(val)
        else
            return '"' .. utils.escape_string(val) .. '"'
        end
    elseif type(val) == "number" then
        return tostring(val)
    elseif type(val) == "boolean" then
        return tostring(val)
    elseif type(val) == "table" then
        if vim.islist(val) then
            return lang_spec.symbols.lst or "[]"
        else
            return lang_spec.symbols.tbl or "{}"
        end
    end
end

---Gets the length of the string representation of a value.
---@param val any,
---@param lang_spec LangSpec
---@return integer | nil
M.GetLenOfValue = function(val, lang_spec)
    if val == vim.NIL then
        if lang_spec.symbols.null then
            return string.len(lang_spec.symbols.null)
        else
            return 4
        end
    elseif type(val) == "string" then
        return utils.utf8len(utils.escape_string(val)) + 2
    elseif type(val) == "number" then
        return #tostring(val)
    elseif type(val) == "boolean" then
        if val then
            return 4
        else
            return 5
        end
    elseif val == vim.empty_dict() then
        if lang_spec.symbols.tbl then
            return string.len(lang_spec.symbols.lst)
        else
            return 2
        end
    elseif type(val) == "table" then
        if vim.islist(val) then
            if lang_spec.symbols.tbl then
                return string.len(lang_spec.symbols.lst)
            else
                return 2
            end
        else
            if lang_spec.symbols.tbl then
                return string.len(lang_spec.symbols.lst)
            else
                return 2
            end
        end
    end
end

return M
