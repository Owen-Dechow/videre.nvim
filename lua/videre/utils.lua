local M = {}

---Returns the config
---@return table
function M.cfg()
    return require("videre").config
end

---Gets the number of chars in the string. Length
---of string in chars not bytes
---@param str any
---@return integer
function M.utf8len(str)
    local _, count = string.gsub(str, "[^\128-\191]", "")
    return count
end

---Transforms special characters into their escape
---sequences: [new line] -> "\n"
---@param str string
---@return string
function M.escape_string(str)
    local new = (
        str
        :gsub("\\", "\\\\")
        :gsub("\n", "\\n")
        :gsub("\t", "\\t")
        :gsub("\r", "\\r")
        :gsub("\"", "\\\"")
    )

    return new
end

---Takes an array and a second value and adds the
---second value to the array and returns the new
---array. The old array will not be affected.
---@param tbl any[]
---@param add any
---@return any[]
function M.appended_table(tbl, add)
    local new = {}

    for k, v in pairs(tbl) do
        new[k] = v
    end

    new[#new + 1] = add

    return new
end

---Takes a config table and recursively updates it with
---new values. No old values will be lost unless
---overwritten by new values.
---@param with any
---@param to any
function M.update_table(with, to)
    for k, v in pairs(with) do
        if type(v) == "table" then
            if type(to[k]) == "table" then
                M.update_table(v, to[k])
            else
                to[k] = v
            end
        else
            to[k] = v
        end
    end
end

---Set a keymap for the buffer
---@param keymap string
---@param fn string | function
function M.keymap(keymap, fn)
    vim.keymap.set(
        "n",
        keymap,
        fn,
        { buffer = true, noremap = true, silent = true, nowait = true }
    )
end

return M
