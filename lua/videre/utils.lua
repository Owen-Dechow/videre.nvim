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
    local first_line = vim.split(str, "\\n", { plain = true })[1]
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
    local mrow, mcol = M.GetMousePos(1)

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
    local value_on = mrow - cell.top_render_line

    if value_on == #cell.values + 1 and #cell.hidden_values > 0 then
        value_on = "expand"
    elseif value_on > #cell.values or value_on == 0 then
        value_on = nil
    end

    return layer_in, cell_in, value_on
end

---@return integer
function M.UniqueGroup()
    return vim.api.nvim_create_augroup("VidereTableGroup " .. vim.loop.hrtime(), {})
end

return M
