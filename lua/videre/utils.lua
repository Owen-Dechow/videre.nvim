local config = require("videre.config").config

local M = {}

---@alias DataObjectTypeName
---| "array"
---| "object"

---@param value DataValue
---@return DataObjectTypeName
function M.DataType(value)
    if vim.isarray(value) then
        return "array"
    else
        return "object"
    end
end

---@alias VidereValueTypeName
---| "array"
---| "object"
---| "string"
---| "number"
---| "null"
---| "bool"

---@param value VidereValue
---@return VidereValueTypeName
function M.ValueType(value)
    if value == vim.NIL then
        return "null"
    end

    local type = type(value)

    if type == "table" then
        return value.type
    end

    return ({
        number = "number",
        boolean = "bool",
        string = "string",
    })[type]
end

---@param str string
---@return string
function M.EscapeString(str)
    str = str:gsub("\\", "\\\\")
    str = str:gsub("\"", "\\\"")
    str = str:gsub("\b", "\\b")
    str = str:gsub("\f", "\\f")
    str = str:gsub("\n", "\\n")
    str = str:gsub("\r", "\\r")
    str = str:gsub("\t", "\\t")

    return str
end

---@param val string
---@return integer
function M.StringWidth(val)
    return vim.str_utfindex(val, "utf-16")
end

---@param val integer
---@return integer
function M.NumberWidth(val)
    return #tostring(val)
end

---@param str string
---@param width integer
---@param align RowAlignment
---@param space string
---@return integer, string, integer
function M.PadLine(str, width, align, space)
    local current_width = M.StringWidth(str)
    local pad = math.max(0, width - current_width)

    if align == "left" then
        return 0, str .. string.rep(space, pad), pad
    elseif align == "right" then
        return pad, string.rep(space, pad) .. str, 0
    else
        local left = math.floor(pad / 2)
        local right = pad - left
        return left, string.rep(space, left) .. str .. string.rep(space, right), right
    end
end

---@param str string
---@return string[]
function M.DisplayLines(str)
    local tab_width = config.tab_width
    local expand_tabs = config.expand_tabs
    local expand_newlines = config.expand_newlines

    local split_lines = {}
    local current_line = {}
    local str_idx = 1
    while str_idx <= #str do
        local c = str:sub(str_idx, str_idx)
        if c == [[\]] then
            local next = str:sub(str_idx + 1, str_idx + 1)
            if next == [[\]] then
                current_line[#current_line + 1] = [[\\]]
                str_idx = str_idx + 2
            elseif next == "n" and expand_newlines then
                split_lines[#split_lines + 1] = table.concat(current_line)
                current_line = {}
                str_idx = str_idx + 2
            elseif next == "r" and expand_newlines then
                if str:sub(str_idx + 2, str_idx + 3) == [[\n]] then
                    split_lines[#split_lines + 1] = table.concat(current_line)
                    current_line = {}
                    str_idx = str_idx + 4
                else
                    current_line[#current_line + 1] = c .. next
                    str_idx = str_idx + 2
                end
            elseif next == "t" and expand_tabs then
                current_line[#current_line + 1] = string.rep(" ", tab_width)
                str_idx = str_idx + 2
            else
                current_line[#current_line + 1] = c .. next
                str_idx = str_idx + 2
            end
        else
            current_line[#current_line + 1] = c
            str_idx = str_idx + 1
        end
    end

    split_lines[#split_lines + 1] = table.concat(current_line)

    if config.max_line_width == 0 then
        return split_lines
    end

    local lines = {}
    for _, line in ipairs(split_lines) do
        if M.StringWidth(line) > config.max_line_width then
            while #line > 0 do
                lines[#lines + 1] = vim.fn.strcharpart(line, 0, config.max_line_width)
                line = vim.fn.strcharpart(line, config.max_line_width)
            end
        else
            lines[#lines + 1] = line
        end
    end

    return lines
end

---@param tbl VidereTable
---@param val VidereValue
---@param width integer
---@param align RowAlignment
---@param space string
---@param is_key boolean
---@return integer, string, integer
function M.ValueAsString(tbl, val, width, align, space, is_key)
    local t = M.ValueType(val)
    local str = tbl.lang_spec.ValueAsString(val, t, is_key)
    if is_key then
        return M.PadLine(str, width, align, space)
    end

    local first_line = M.DisplayLines(str)[1]
    return M.PadLine(first_line, width, align, space)
end

---@param statusline_offset integer
---@return integer, integer
function M.GetMousePos(statusline_offset)
    local mouse_pos = vim.api.nvim_win_get_cursor(0)
    local line_text = vim.api.nvim_get_current_line()

    -- Substring from start up to the byte column, then count UTF-8 characters
    local line_prefix = string.sub(line_text, 1, mouse_pos[2])
    local mouse_col = M.StringWidth(line_prefix)

    return mouse_pos[1] - statusline_offset, mouse_col + 1
end

---@param tbl VidereTable
---@return integer|nil, integer|nil, integer|nil|"expand"
function M.GetHoveredCell(tbl)
    local mrow, mcol = M.GetMousePos(0)

    local layer_in, cell_in;
    for i, layer in ipairs(tbl.layers) do
        if layer.left_render_col <= mcol and mcol < layer.left_render_col + layer.width then
            layer_in = i
            break
        end
    end

    if not layer_in then
        return nil, nil, nil
    end

    local layer = tbl.layers[layer_in]

    for j, cell in ipairs(layer.cells) do
        if not cell.is_hidden then
            if cell.top_render_line <= mrow and mrow < cell.top_render_line + cell.height then
                cell_in = j
                break
            end
        end
    end

    if not cell_in then
        return layer_in, nil, nil
    end

    local cell = layer.cells[cell_in]

    ---@type integer|nil|"expand"
    local raw_offset = mrow - cell.top_render_line
    local value_on

    if raw_offset == 0 then
        value_on = nil
    else
        local found = nil
        for j, entry in ipairs(cell.values) do
            if entry.row_offset then
                local next_offset = (cell.values[j + 1] and cell.values[j + 1].row_offset)
                    or ((cell.total_display_rows or #cell.values) + 1)
                if raw_offset >= entry.row_offset and raw_offset < next_offset then
                    found = j
                    break
                end
            else
                -- fallback: original single-row-per-value assumption
                if raw_offset == j then
                    found = j
                    break
                end
            end
        end

        if found then
            value_on = found
        elseif raw_offset == (cell.total_display_rows or #cell.values) + 1 and #cell.hidden_values > 0 then
            value_on = "expand"
        else
            value_on = nil
        end
    end

    return layer_in, cell_in, value_on
end

---@return integer
function M.UniqueGroup()
    return vim.api.nvim_create_augroup("VidereTableGroup " .. vim.loop.hrtime(), {})
end

return M
