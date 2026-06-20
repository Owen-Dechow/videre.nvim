local utils = require "videre.utils"
local boxes = require "videre.boxes"
local config = require("videre.config").config

local M = {}

---@param s string|integer
---@return (string|integer)[]
local function natural_sort_key(s)
    local parts = {}

    if type(s) == "number" then
        return { s }
    end

    for text, num in s:gmatch("(%a*)(%d*)") do
        if text ~= "" then table.insert(parts, text) end
        if num ~= "" then table.insert(parts, tonumber(num)) end
    end
    return parts
end

---@param a string|integer
---@param b string|integer
---@return boolean
local function natural_less(a, b)
    local pa = natural_sort_key(a)
    local pb = natural_sort_key(b)
    for i = 1, math.max(#pa, #pb) do
        local ca = pa[i]
        local cb = pb[i]
        if ca == nil then return true end
        if cb == nil then return false end
        if type(ca) ~= type(cb) then
            -- number chunks sort before string chunks
            return type(ca) == "number"
        end
        if ca ~= cb then return ca < cb end
    end
    return false
end

---@param data DataObj
---@param cell_title string|nil
---@param tbl VidereTable
---@param layer_number integer
---@param is_hidden boolean
---@param linking_cell CellValRef|nil
---@param data_ref DataObjectRef
---@return VidereConnection
local function add_data_cell_to_table_layer(data, cell_title, tbl, layer_number, is_hidden, linking_cell, data_ref)
    if #tbl.layers < layer_number then
        tbl.layers[layer_number] = { cells = {} }
    end

    ---@type VidereCell
    local cell = {
        title = cell_title,
        type = utils.DataType(data),
        values = {},
        hidden_values = {},
        is_hidden = is_hidden,
        linking_cell = linking_cell,
        data = data,
        data_ref = data_ref,
    }


    local i = 1

    local keys = vim.tbl_keys(data)
    table.sort(keys, natural_less)

    for _, key in ipairs(keys) do
        local value = data[key]

        if i > config.max_cell_lines then
            if type(value) == "table" then
                local linking_cell_ref = { layer_number, #tbl.layers[layer_number].cells + 1, i }

                local new_data_ref = vim.deepcopy(data_ref)
                new_data_ref[#new_data_ref + 1] = key

                local conn = add_data_cell_to_table_layer(value, nil, tbl, layer_number + 1, true, linking_cell_ref,
                    new_data_ref)
                cell.hidden_values[i] = { key, conn }
            else
                cell.hidden_values[i] = { key, value }
            end
        else
            if type(value) == "table" then
                local linking_cell_ref = { layer_number, #tbl.layers[layer_number].cells + 1, i }

                local new_data_ref = vim.deepcopy(data_ref)
                new_data_ref[#new_data_ref + 1] = key

                local conn = add_data_cell_to_table_layer(value, nil, tbl, layer_number + 1, false, linking_cell_ref,
                    new_data_ref)
                cell.values[i] = { key, conn }
            else
                cell.values[i] = { key, value }
            end
        end

        i = i + 1
    end

    local cell_number = #tbl.layers[layer_number].cells + 1
    tbl.layers[layer_number].cells[cell_number] = cell

    ---@type VidereConnection
    local conn = {
        cell = cell_number,
        layer = layer_number,
        type = cell.type,
    }

    return conn
end

---@param data DataObj
---@param from_buffer integer
---@param is_saved boolean
---@param lang_spec LangSpec
---@return VidereTable
function M.DataToVidereTable(data, from_buffer, is_saved, lang_spec)
    ---@type VidereTable
    local tbl = {
        layers = {},
        parent_table = nil,
        grp = utils.UniqueGroup(),
        data = data,
        from_buffer = from_buffer,
        is_saved = is_saved,
        available_maps = {},
        lang_spec = lang_spec
    }

    add_data_cell_to_table_layer(data, nil, tbl, 1, false, nil, {})

    return tbl
end

---@param val VidereValue
---@param tbl VidereTable
---@param is_key boolean
---@return integer
local function get_value_width(val, tbl, is_key)
    return utils.StringWidth(tbl.lang_spec.ValueAsString(val, utils.ValueType(val), is_key));
end

---@param cell VidereCell
---@param tbl VidereTable
---@return integer
local function get_cell_key_col_width(cell, tbl)
    local min_width = 0
    for _, entry in ipairs(cell.values) do
        local value_width = get_value_width(entry[1], tbl, true)
        if min_width < value_width then
            min_width = value_width
        end
    end

    return min_width
end

---@param cell VidereCell
---@param tbl VidereTable
---@return integer
local function get_cell_min_width(cell, tbl)
    local key_col_width = get_cell_key_col_width(cell, tbl)

    cell.key_col_width = key_col_width

    local max_value_width = 0
    for _, entry in pairs(cell.values) do
        local value_width = get_value_width(entry[2], tbl, false)
        if max_value_width < value_width then
            max_value_width = value_width
        end
    end

    return key_col_width + max_value_width + 3
end


---@param layer VidereLayer
---@param tbl VidereTable
---@return integer
local function get_layer_min_width(layer, tbl)
    local min_width = 0
    for _, cell in pairs(layer.cells) do
        if not cell.is_hidden then
            local cell_width = get_cell_min_width(cell, tbl)
            if min_width < cell_width then
                min_width = cell_width
            end
        end
    end

    layer.width = min_width

    return min_width
end

---@param layer VidereLayer
---@return integer
local function get_layer_min_height(layer)
    local layer_height = 0
    for _, cell in pairs(layer.cells) do
        local cell_height = 0
        if not cell.is_hidden then
            for _ in ipairs(cell.values) do
                cell_height = cell_height + 1
            end

            cell_height = cell_height + 2

            if #cell.hidden_values > 0 then
                cell_height = cell_height + 1
            end

            layer_height = layer_height + config.cell_spacing
        end
        cell.height = cell_height
        layer_height = layer_height + cell_height
    end

    layer.height = layer_height

    return layer_height - config.cell_spacing
end

---@param tbl VidereTable
---@return integer
local function get_table_min_height(tbl)
    local min_height = 0
    for _, layer in pairs(tbl.layers) do
        local layer_height = get_layer_min_height(layer)
        if min_height < layer_height then
            min_height = layer_height
        end
    end

    return min_height
end

---@param cell VidereCell
---@param tbl VidereTable
---@param width integer
---@param is_root boolean
---@return string[]
local function render_cell_at_width(cell, tbl, width, is_root)
    local key_col_width = get_cell_key_col_width(cell, tbl)

    local rows = { boxes.TopLeft(is_root) ..
    string.rep(boxes.HorizontalBox(), key_col_width) ..
    boxes.ColumnTopBreak() ..
    string.rep(boxes.HorizontalBox(), width - key_col_width - 3) ..
    boxes.TopRight() }

    for i, entry in ipairs(cell.values) do
        local key, val = entry[1], entry[2]
        local val_type = utils.ValueType(val)

        local vert;
        if val_type == "object" or val_type == "array" then
            vert = boxes.BoxConnect()
        else
            vert = boxes.VerticalBox()
        end

        if type(key) == "number" then
            key = key - 1 + config.index_base
        end

        local left = i == config.max_cell_lines + 1 and boxes.BoxCollapse() or boxes.VerticalBox()

        local key_left_pad, key_string, key_right_pad = utils.ValueAsString(tbl, key, key_col_width, config
            .key_alignment, config.key_space, true)

        local val_left_pad, value_string, val_right_pad = utils.ValueAsString(tbl, val, width - key_col_width - 3,
            config.value_alignment, config.value_space, false)

        entry.val_left_pad, entry.val_right_pad = val_left_pad, val_right_pad
        entry.key_left_pad, entry.key_right_pad = key_left_pad, key_right_pad

        rows[#rows + 1] = left .. key_string ..
            boxes.VerticalBox() ..
            value_string .. vert
    end

    if #cell.hidden_values > 0 then
        rows[#rows + 1] = boxes.BoxCollapse() ..
            string.rep(config.collapse_indication_character, width - 2) ..
            boxes.VerticalBox()
    end

    rows[#rows + 1] = boxes.BottomLeft() ..
        string.rep(boxes.HorizontalBox(), key_col_width) ..
        boxes.ColumnBottomBreak() ..
        string.rep(boxes.HorizontalBox(), width - key_col_width - 3) ..
        boxes.BottomRight()

    return rows
end

---@param layer VidereLayer
---@param height integer
---@param is_root boolean
---@param tbl VidereTable
---@return string[]
local function render_layer_to_string(layer, height, is_root, tbl)
    local width = get_layer_min_width(layer, tbl)

    local add_rows = ({
        top = 0,
        bottom = height - layer.height,
        center = math.floor((height - layer.height) / 2)
    })[config.column_alignment]

    local rows = {}
    for _ = 1, add_rows do
        rows[#rows + 1] = string.rep(config.outside_space, width)
    end

    for _, cell in ipairs(layer.cells) do
        if not cell.is_hidden then
            local cell_rows = render_cell_at_width(cell, tbl, width, is_root)
            cell.top_render_line = #rows + 1
            cell.render_width = layer.width

            for _, row in pairs(cell_rows) do
                rows[#rows + 1] = row
            end

            for _ = 1, config.cell_spacing do
                rows[#rows + 1] = string.rep(config.outside_space, width)
            end
        end
    end

    while #rows < height do
        rows[#rows + 1] = string.rep(config.outside_space, width)
    end

    return rows
end

---@param map string[][]
---@param conn VidereConnection
local function resolve_connection(map, conn)
    local row, target, col = conn.from_render_line, conn.to_render_line, 1
    local last_was_horizontal = true
    local is_increasing = row > target

    while row ~= target or col ~= #map[row] + 1 do
        local new_row, new_col, new_is_horizontal = row, col, false;
        if row > target and map[row - 1][col] == config.outside_space then
            new_row = row - 1
        elseif row < target and map[row + 1][col] == config.outside_space then
            new_row = row + 1
        else
            new_col, new_is_horizontal = col + 1, true
        end

        if last_was_horizontal and new_is_horizontal then
            map[row][col] = boxes.HorizontalLine()
        elseif not last_was_horizontal and not new_is_horizontal then
            map[row][col] = boxes.VerticalLine()
        elseif not last_was_horizontal and new_is_horizontal and is_increasing then
            map[row][col] = boxes.FromUpTurnRight()
        elseif not last_was_horizontal and new_is_horizontal and not is_increasing then
            map[row][col] = boxes.FromDownTurnRight()
        elseif last_was_horizontal and not new_is_horizontal then
            for _ = 1, config.connection_spacing do
                map[row][col] = boxes.HorizontalLine()
                col = col + 1
            end

            new_col = col

            if is_increasing then
                map[row][col] = boxes.FromRightTurnUp()
            else
                map[row][col] = boxes.FromRightTurnDown()
            end
        end

        row, col, last_was_horizontal = new_row, new_col, new_is_horizontal
    end
end

---@param layer VidereLayer
---@param tbl VidereTable
---@return VidereConnection[], VidereConnection[], integer
local function aggregate_connection_objects_for_layer(layer, tbl)
    ---@type VidereConnection[]
    local connections_up = {}

    ---@type VidereConnection[]
    local connections_down = {}

    local current_run = 0
    local width = 1
    local current_type_is_up = nil

    for _, cell in ipairs(layer.cells) do
        if not cell.is_hidden then
            local line_offset = 0
            for _, entry in ipairs(cell.values) do
                local val = entry[2]
                line_offset = line_offset + 1
                local value_type = utils.ValueType(val)
                if value_type == "array" or value_type == "object" then
                    val.from_render_line = cell.top_render_line + line_offset
                    val.to_render_line = tbl.layers[val.layer].cells[val.cell].top_render_line

                    ---@type boolean|nil
                    local is_up = val.from_render_line > val.to_render_line

                    if val.from_render_line == val.to_render_line then
                        is_up = nil
                    end

                    if is_up then
                        ---@diagnostic disable-next-line: assign-type-mismatch
                        connections_up[# connections_up + 1] = val
                    else
                        ---@diagnostic disable-next-line: assign-type-mismatch
                        connections_down[# connections_down + 1] = val
                    end

                    if is_up == current_type_is_up and is_up ~= nil then
                        current_run = current_run + 1
                        width = math.max(width, current_run)
                    else
                        current_run = 1
                        current_type_is_up = is_up
                    end
                end
            end
        end
    end

    width = width * (config.connection_spacing + 1) + config.connection_spacing

    return connections_up, connections_down, width
end

---@param tbl VidereTable
---@param layer VidereLayer
---@param height integer
---@return string[]
local function create_connections_for_layer(tbl, layer, height)
    local connections_up, connections_down, width = aggregate_connection_objects_for_layer(layer, tbl)

    local map = {}
    for r = 1, height do
        local row = {}
        for c = 1, width do
            row[c] = config.outside_space
        end

        map[r] = row
    end

    for _, conn in ipairs(connections_up) do
        resolve_connection(map, conn)
    end

    for i = #connections_down, 1, -1 do
        resolve_connection(map, connections_down[i])
    end

    for i, row in pairs(map) do
        map[i] = table.concat(row)
    end

    return map
end

---@param tbl VidereTable
---@param height integer
---@return string[][]
local function create_connections(tbl, height)
    local connection_layers = {}

    for i, layer in ipairs(tbl.layers) do
        connection_layers[i] = create_connections_for_layer(tbl, layer, height)
    end

    return connection_layers
end

---@param tbl VidereTable
---@return string[]
function M.RenderTableToString(tbl)
    ---@type string[][]
    local layer_strings = {}

    local height = get_table_min_height(tbl)

    for i, layer in ipairs(tbl.layers) do
        layer_strings[#layer_strings + 1] = render_layer_to_string(layer, height, i == 1, tbl)
    end

    local connection_strings = create_connections(tbl, height)

    local rows = {}
    for row_number = 1, height do
        local row = ""
        for layer_num, layer in ipairs(layer_strings) do
            tbl.layers[layer_num].left_render_col = utils.StringWidth(row) + 1
            row = row .. layer[row_number] .. connection_strings[layer_num][row_number]
        end
        rows[#rows + 1] = row
    end

    return rows
end

---@param tbl VidereTable
---@param cell VidereCell
---@param hidden boolean
local function set_cells_hidden_from_root(tbl, cell, hidden)
    cell.is_hidden = hidden

    for _, entry in pairs(cell.values) do
        local value = entry[2]
        local value_type = utils.ValueType(value)

        if value_type == "array" or value_type == "object" then
            set_cells_hidden_from_root(tbl, tbl.layers[value.layer].cells[value.cell], hidden)
        end
    end

    for _, entry in pairs(cell.hidden_values) do
        local value = entry[2]
        local value_type = utils.ValueType(value)

        if value_type == "array" or value_type == "object" then
            set_cells_hidden_from_root(tbl, tbl.layers[value.layer].cells[value.cell], true)
        end
    end
end

---@param tbl VidereTable
---@param layer_num integer
---@param cell_num integer
---@param val integer|nil|"expand"
function M.JumpToCellAndValue(tbl, layer_num, cell_num, val)
    local layer = tbl.layers[layer_num]
    local col = layer.left_render_col
    local cell = layer.cells[cell_num]
    local row = cell.top_render_line

    local jump = true
    if val == "expand" then
        row = row + config.max_cell_lines + 2
    elseif val ~= nil and val > #cell.values then
        row = row + #cell.values + 2
        jump = false
    elseif val ~= nil then
        row = row + val + 1
    else
        row = row + 2
    end

    local line_text = vim.api.nvim_buf_get_lines(0, row - 1, row, false)[1] or ""
    local sub_str = vim.fn.strcharpart(line_text, 0, col - 1)
    local byte_col = #sub_str

    vim.api.nvim_win_set_cursor(0, { row, byte_col })

    if jump then
        vim.cmd [[normal! w]]
    end

    local win_height = vim.api.nvim_win_get_height(0)
    local win_width = vim.api.nvim_win_get_width(0)

    local topline
    if cell.height <= win_height then
        topline = math.max(1, cell.top_render_line - math.floor((win_height - cell.height) / 2))
    else
        topline = cell.top_render_line
    end

    local leftcol
    if layer.width <= win_width then
        leftcol = math.max(0, (col - 1) - math.floor((win_width - layer.width) / 2))
    else
        leftcol = col - 1
    end

    vim.fn.winrestview({ topline = topline, leftcol = leftcol })
end

---@param tbl VidereTable
---@param data_ref DataObjectRef
---@param val integer
---@return CellValRef
function M.DataRefToTableRef(tbl, data_ref, val)
    local layer_n = #data_ref + 1

    if tbl.parent_table then
        layer_n = layer_n - (#tbl.parent_table.layers - #tbl.layers)
    end

    local cell_n;
    for i, cell in ipairs(tbl.layers[layer_n].cells) do
        if vim.deep_equal(data_ref, cell.data_ref) then
            cell_n = i;
            break
        end
    end

    return { layer_n, cell_n, val }
end

---@param new_tbl VidereTable
---@param new_layer integer
---@param old_tbl VidereTable
---@param old_layer integer
---@param old_cell integer
---@param linking_cell CellValRef|nil
---@return integer, integer
local function add_cell_to_sub_table(new_tbl, new_layer, old_tbl, old_layer, old_cell, linking_cell)
    local cell = old_tbl.layers[old_layer].cells[old_cell]

    cell.parent_linking_cell = cell.linking_cell
    cell.linking_cell = linking_cell

    if #new_tbl.layers < new_layer then
        new_tbl.layers[new_layer] = { cells = {} }
    end

    local layer = new_tbl.layers[new_layer]

    layer.cells[#layer.cells + 1] = cell

    local cell_num = #layer.cells

    local i = 0
    for _, entry in ipairs(cell.values) do
        i = i + 1
        local val = entry[2]
        local val_type = utils.ValueType(val)

        if val_type == "array" or val_type == "object" then
            if not val.parent_reference then
                val.parent_reference = { val.layer, val.cell }
            end

            val.layer, val.cell = add_cell_to_sub_table(new_tbl, new_layer + 1, old_tbl, val.layer, val.cell,
                { new_layer, cell_num, i })
        end
    end

    for _, entry in pairs(cell.hidden_values) do
        i = i + 1
        local val = entry[2]
        local val_type = utils.ValueType(val)

        if val_type == "array" or val_type == "object" then
            if not val.parent_reference then
                val.parent_reference = { val.layer, val.cell }
            end

            val.layer, val.cell = add_cell_to_sub_table(new_tbl, new_layer + 1, old_tbl, val.layer, val.cell,
                { new_layer, cell_num, i })
        end
    end

    return new_layer, cell_num
end

---@param tbl VidereTable
---@param layer_num integer
---@param cell_num integer
---@return VidereTable
function M.MakeSubTable(tbl, layer_num, cell_num)
    ---@type VidereTable
    local new_tbl = {
        layers = {},
        parent_table = tbl.parent_table or tbl,
        grp = utils.UniqueGroup(),
        data = tbl.data,
        from_buffer = tbl.from_buffer,
        is_saved = tbl.is_saved,
        available_maps = {},
        lang_spec = tbl.lang_spec
    }

    add_cell_to_sub_table(new_tbl, 1, tbl, layer_num, cell_num, nil)

    return new_tbl
end

---@param tbl VidereTable
function M.UnbindSubTable(tbl)
    for _, layer in pairs(tbl.parent_table.layers) do
        for _, cell in pairs(layer.cells) do
            cell.linking_cell = cell.parent_linking_cell

            for _, entry in pairs(cell.values) do
                local val = entry[2]
                if val.parent_reference then
                    local val_type = utils.ValueType(val)

                    if val_type == "array" or val_type == "object" then
                        val.layer, val.cell = val.parent_reference[1], val.parent_reference[2]
                    end
                end
            end

            for _, entry in pairs(cell.hidden_values) do
                local val = entry[2]
                if val.parent_reference then
                    local val_type = utils.ValueType(val)

                    if val_type == "array" or val_type == "object" then
                        val.layer, val.cell = val.parent_reference[1], val.parent_reference[2]
                    end
                end
            end
        end
    end
end

---@param tbl VidereTable
---@return DataObjectRef[]
function M.FindAllExpandedTables(tbl)
    ---@type DataObjectRef[]
    local expanded = {}

    for _, layer in pairs(tbl.layers) do
        for _, cell in pairs(layer.cells) do
            if #cell.values > config.max_cell_lines then
                expanded[#expanded + 1] = cell.data_ref
            end
        end
    end

    return expanded
end

---@param tbl VidereTable
---@param cell VidereCell
function M.ExpandCell(tbl, cell)
    for key, value in pairs(cell.hidden_values) do
        cell.values[key] = value
        cell.hidden_values[key] = nil
    end

    set_cells_hidden_from_root(tbl, cell, false)
end

---@param tbl VidereTable
---@param cell VidereCell
function M.CollapseCell(tbl, cell)
    for key, value in ipairs(cell.values) do
        if key > config.max_cell_lines then
            cell.hidden_values[key] = value
            cell.values[key] = nil
        end
    end

    set_cells_hidden_from_root(tbl, cell, false)
end

---@param tbl VidereTable
---@param cells DataObjectRef[]
function M.ExpandCellPack(tbl, cells)
    for _, cell in pairs(cells) do
        local cell_ref = M.DataRefToTableRef(tbl, cell, 0)
        M.ExpandCell(tbl, tbl.layers[cell_ref[1]].cells[cell_ref[1]])
    end
end

return M
