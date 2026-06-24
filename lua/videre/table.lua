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
        local is_entry_hidden = i > config.max_cell_lines

        if type(value) == "table" then
            local linking_cell_ref = { layer_number, #tbl.layers[layer_number].cells + 1, i }

            local new_data_ref = vim.deepcopy(data_ref)
            new_data_ref[#new_data_ref + 1] = key

            local entry_value
            if utils.DataType(value) == "array" and next(value) ~= nil and utils.AllObjectValues(value)
                and #vim.tbl_keys(value) <= config.max_cell_lines then
                -- Array of objects: skip intermediate array cell, branch directly to element cells.
                -- TODO: the skipped array has no cell for its own data_ref; DataRefToTableRef falls
                -- back to root when called with that ref (only affects undo focus in rare cases).
                local elem_keys = vim.tbl_keys(value)
                table.sort(elem_keys, natural_less)
                local targets = {}
                for _, elem_key in ipairs(elem_keys) do
                    local elem_data_ref = vim.deepcopy(new_data_ref)
                    elem_data_ref[#elem_data_ref + 1] = elem_key
                    local conn = add_data_cell_to_table_layer(value[elem_key], nil, tbl, layer_number + 1,
                        is_entry_hidden, linking_cell_ref, elem_data_ref)
                    targets[#targets + 1] = conn
                end
                ---@type VidereBranchConnection
                entry_value = { targets = targets, type = "array" }
            else
                entry_value = add_data_cell_to_table_layer(value, nil, tbl, layer_number + 1,
                    is_entry_hidden, linking_cell_ref, new_data_ref)
            end

            if is_entry_hidden then
                cell.hidden_values[i] = { key, entry_value }
            else
                cell.values[i] = { key, entry_value }
            end
        else
            if is_entry_hidden then
                cell.hidden_values[i] = { key, value }
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
---@param states State[]
---@param state_idx integer
---@return VidereTable
function M.DataToVidereTable(data, from_buffer, is_saved, lang_spec, states, state_idx)
    ---@type VidereTable
    local tbl = {
        layers = {},
        parent_table = nil,
        grp = utils.UniqueGroup(),
        data = data,
        from_buffer = from_buffer,
        is_saved = is_saved,
        available_maps = {},
        lang_spec = lang_spec,
        state_idx = state_idx,
        states = states,
    }

    add_data_cell_to_table_layer(data, nil, tbl, 1, false, nil, {})

    return tbl
end

---@param val VidereValue
---@param tbl VidereTable
---@param is_key boolean
---@return integer
local function get_value_width(val, tbl, is_key)
    local val_type = utils.ValueType(val)
    local str = tbl.lang_spec.ValueAsString(val, val_type, is_key)
    if is_key or val_type ~= "string" then
        return utils.StringWidth(str)
    end
    local max_w = 0
    for _, line in ipairs(utils.DisplayLines(str)) do
        local w = utils.StringWidth(line)
        if w > max_w then max_w = w end
    end
    return max_w
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
---@param tbl VidereTable
---@return integer
local function get_layer_min_height(layer, tbl)
    local layer_height = 0
    for _, cell in pairs(layer.cells) do
        local cell_height = 0
        if not cell.is_hidden then
            for _, entry in ipairs(cell.values) do
                local val = entry[2]
                local val_type = utils.ValueType(val)
                if val_type == "string" then
                    local str = tbl.lang_spec.ValueAsString(val, val_type, false)
                    cell_height = cell_height + #utils.DisplayLines(str)
                else
                    cell_height = cell_height + 1
                end
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
        local layer_height = get_layer_min_height(layer, tbl)
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

        local val_col_width = width - key_col_width - 3
        local val_display = tbl.lang_spec.ValueAsString(val, val_type, false)
        local val_lines = val_type == "string" and utils.DisplayLines(val_display)
            or { val_display }

        local val_left_pad, value_string, val_right_pad = utils.PadLine(val_lines[1], val_col_width,
            config.value_alignment, config.value_space)

        entry.val_left_pad, entry.val_right_pad = val_left_pad, val_right_pad
        entry.key_left_pad, entry.key_right_pad = key_left_pad, key_right_pad
        entry.row_offset = #rows

        rows[#rows + 1] = left .. key_string ..
            boxes.VerticalBox() ..
            value_string .. vert

        local blank_key = string.rep(config.key_space, key_col_width)
        for li = 2, #val_lines do
            local _, cont_string, _ = utils.PadLine(val_lines[li], val_col_width,
                config.value_alignment, config.value_space)
            rows[#rows + 1] = boxes.VerticalBox() .. blank_key .. boxes.VerticalBox() .. cont_string .. vert
        end
    end
    cell.total_display_rows = #rows - 1

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
---@param branch VidereBranchConnection
local function resolve_branch_connection(map, branch)
    local from_row = branch.from_render_line

    local target_rows = {}
    for _, target in ipairs(branch.targets) do
        if target.to_render_line then
            target_rows[#target_rows + 1] = target.to_render_line
        end
    end
    table.sort(target_rows)

    if #target_rows == 0 then return end

    local min_target = target_rows[1]
    local max_target = target_rows[#target_rows]
    local spine_top = math.min(from_row, min_target)
    local spine_bottom = math.max(from_row, max_target)

    -- Find the first column that is free for the entire spine range so that
    -- the branch spine does not overlap other connection routing at that column.
    local step = config.connection_spacing + 1
    local spine_col = step
    while spine_col <= #map[spine_top] do
        local clear = true
        for row = spine_top, spine_bottom do
            if map[row][spine_col] ~= config.outside_space then
                clear = false
                break
            end
        end
        if clear then break end
        spine_col = spine_col + step
    end

    -- Normalize all map rows to at least spine_col width before drawing.
    -- Previous branch exits may have extended only some rows; rows that were
    -- not target rows stay shorter, which breaks left_render_col/hover math.
    -- Extend with horizontal-line when the row already ends in one (continuing
    -- an exit); otherwise use outside_space.
    local horiz = boxes.HorizontalLine()
    -- Characters that imply a rightward exit: only these rows should be padded
    -- with horizontal lines. Vertical-spine and source-turn-only characters (│, ╯, ╮)
    -- do not continue rightward and must not get horizontal tails.
    local rightward = {
        [horiz] = true,
        [boxes.FromDownTurnRight()] = true,
        [boxes.FromUpTurnRight()] = true,
        [boxes.BranchFromSpine()] = true,
        [boxes.BranchTeeDown()] = true,
        [boxes.BranchTeeUp()] = true,
        [boxes.BranchCross()] = true,
    }
    for i = 1, #map do
        local r = map[i]
        local n = #r
        if n < spine_col then
            local fill = (n > 0 and rightward[r[n]]) and horiz or config.outside_space
            for j = n + 1, spine_col do
                r[j] = fill
            end
        end
    end

    local is_target = {}
    for _, r in ipairs(target_rows) do
        is_target[r] = true
    end

    -- Draw horizontal trunk from source row to spine column
    for col = 1, spine_col - 1 do
        map[from_row][col] = boxes.HorizontalLine()
    end

    -- Set junction character at (from_row, spine_col)
    local has_up = from_row > spine_top
    local has_down = from_row < spine_bottom
    if is_target[from_row] then
        if has_up and has_down then
            map[from_row][spine_col] = boxes.BranchCross()
        elseif has_down then
            map[from_row][spine_col] = boxes.BranchTeeDown()
        elseif has_up then
            map[from_row][spine_col] = boxes.BranchTeeUp()
        else
            map[from_row][spine_col] = boxes.HorizontalLine()
        end
    else
        if has_up and has_down then
            map[from_row][spine_col] = boxes.BranchTeeLeft()
        elseif has_down then
            map[from_row][spine_col] = boxes.FromRightTurnDown()
        elseif has_up then
            map[from_row][spine_col] = boxes.FromRightTurnUp()
        else
            map[from_row][spine_col] = boxes.HorizontalLine()
        end
    end

    -- Draw spine and branch exits for each row in range
    for row = spine_top, spine_bottom do
        if row ~= from_row then
            local row_has_up = row > spine_top
            local row_has_down = row < spine_bottom

            if is_target[row] then
                if row_has_up and row_has_down then
                    map[row][spine_col] = boxes.BranchFromSpine()
                elseif row_has_down then
                    map[row][spine_col] = boxes.FromUpTurnRight()
                else
                    map[row][spine_col] = boxes.FromDownTurnRight()
                end
            else
                map[row][spine_col] = boxes.VerticalLine()
            end
        end

        -- Horizontal exit to right edge for target rows (including from_row if it's a target)
        if is_target[row] then
            for col = spine_col + 1, #map[row] do
                map[row][col] = boxes.HorizontalLine()
            end
        end
    end
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
---@return VidereConnection[], VidereConnection[], VidereBranchConnection[], integer
local function aggregate_connection_objects_for_layer(layer, tbl)
    ---@type VidereConnection[]
    local connections_up = {}

    ---@type VidereConnection[]
    local connections_down = {}

    ---@type VidereBranchConnection[]
    local branch_connections = {}

    local current_run = 0
    local width = 1
    local current_type_is_up = nil
    local branch_count = 0

    for _, cell in ipairs(layer.cells) do
        if not cell.is_hidden then
            for i, entry in ipairs(cell.values) do
                local val = entry[2]
                local value_type = utils.ValueType(val)
                if value_type == "array" or value_type == "object" then
                    if val.targets then
                        -- VidereBranchConnection: set from_render_line and each target's to_render_line
                        val.from_render_line = cell.top_render_line + (entry.row_offset or i)
                        for _, target in ipairs(val.targets) do
                            local target_cell = tbl.layers[target.layer].cells[target.cell]
                            target.to_render_line = not target_cell.is_hidden and target_cell.top_render_line or nil
                        end
                        ---@diagnostic disable-next-line: assign-type-mismatch
                        branch_connections[#branch_connections + 1] = val
                        -- Each branch may need its own column slot to avoid overlapping other routing
                        branch_count = branch_count + 1
                        current_run = 1
                        current_type_is_up = nil
                        width = math.max(width, current_run)
                    else
                        val.from_render_line = cell.top_render_line + (entry.row_offset or i)
                        val.to_render_line = tbl.layers[val.layer].cells[val.cell].top_render_line

                        ---@type boolean|nil
                        local is_up = val.from_render_line > val.to_render_line

                        if val.from_render_line == val.to_render_line then
                            is_up = nil
                        end

                        if is_up then
                            ---@diagnostic disable-next-line: assign-type-mismatch
                            connections_up[#connections_up + 1] = val
                        else
                            ---@diagnostic disable-next-line: assign-type-mismatch
                            connections_down[#connections_down + 1] = val
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
    end

    width = (width + branch_count) * (config.connection_spacing + 1) + config.connection_spacing

    return connections_up, connections_down, branch_connections, width
end

---@param tbl VidereTable
---@param layer VidereLayer
---@param height integer
---@return string[]
local function create_connections_for_layer(tbl, layer, height)
    local connections_up, connections_down, branch_connections, width = aggregate_connection_objects_for_layer(layer, tbl)

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

    -- TODO: branch connections are drawn after normal connections and write cells
    -- unconditionally, so a branch trunk/exit can overwrite a vertical or turn
    -- segment placed by a normal connection. Fix: draw branch connections first,
    -- or add an occupancy guard in resolve_branch_connection.
    for _, branch in ipairs(branch_connections) do
        resolve_branch_connection(map, branch)
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
            if value.targets then
                for _, target in ipairs(value.targets) do
                    set_cells_hidden_from_root(tbl, tbl.layers[target.layer].cells[target.cell], hidden)
                end
            else
                set_cells_hidden_from_root(tbl, tbl.layers[value.layer].cells[value.cell], hidden)
            end
        end
    end

    for _, entry in pairs(cell.hidden_values) do
        local value = entry[2]
        local value_type = utils.ValueType(value)

        if value_type == "array" or value_type == "object" then
            if value.targets then
                for _, target in ipairs(value.targets) do
                    set_cells_hidden_from_root(tbl, tbl.layers[target.layer].cells[target.cell], true)
                end
            else
                set_cells_hidden_from_root(tbl, tbl.layers[value.layer].cells[value.cell], true)
            end
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

    if not cell or not cell.top_render_line then
        return
    end

    local row = cell.top_render_line

    local total_display_rows = cell.total_display_rows or #cell.values
    local jump = true

    if val == "expand" then
        val = #cell.values
    end

    if val ~= nil and val > #cell.values then
        row = row + total_display_rows + 2
        jump = false
    elseif val ~= nil then
        local entry = cell.values[val]
        row = row + (entry and entry.row_offset or val) + 1
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

    local layer = tbl.layers[layer_n]

    if layer then
        for i, cell in ipairs(layer.cells) do
            if vim.deep_equal(data_ref, cell.data_ref) then
                return { layer_n, i, val }
            end
        end
    end

    -- Branch-skipped cells have a data_ref one level deeper than their actual layer;
    -- fall back to a full-table search.
    for ln, l in ipairs(tbl.layers) do
        for ci, cell in ipairs(l.cells) do
            if vim.deep_equal(data_ref, cell.data_ref) then
                return { ln, ci, val }
            end
        end
    end

    return { 1, 1, 1 }
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
            if val.targets then
                for _, target in ipairs(val.targets) do
                    if not target.parent_reference then
                        target.parent_reference = { target.layer, target.cell }
                    end
                    target.layer, target.cell = add_cell_to_sub_table(new_tbl, new_layer + 1, old_tbl,
                        target.layer, target.cell, { new_layer, cell_num, i })
                end
            else
                if not val.parent_reference then
                    val.parent_reference = { val.layer, val.cell }
                end
                val.layer, val.cell = add_cell_to_sub_table(new_tbl, new_layer + 1, old_tbl, val.layer, val.cell,
                    { new_layer, cell_num, i })
            end
        end
    end

    for _, entry in pairs(cell.hidden_values) do
        i = i + 1
        local val = entry[2]
        local val_type = utils.ValueType(val)

        if val_type == "array" or val_type == "object" then
            if val.targets then
                for _, target in ipairs(val.targets) do
                    if not target.parent_reference then
                        target.parent_reference = { target.layer, target.cell }
                    end
                    target.layer, target.cell = add_cell_to_sub_table(new_tbl, new_layer + 1, old_tbl,
                        target.layer, target.cell, { new_layer, cell_num, i })
                end
            else
                if not val.parent_reference then
                    val.parent_reference = { val.layer, val.cell }
                end
                val.layer, val.cell = add_cell_to_sub_table(new_tbl, new_layer + 1, old_tbl, val.layer, val.cell,
                    { new_layer, cell_num, i })
            end
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
        lang_spec = tbl.lang_spec,
        states = tbl.states,
        state_idx = tbl.state_idx,
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
                local val_type = utils.ValueType(val)

                if val_type == "array" or val_type == "object" then
                    if val.targets then
                        for _, target in ipairs(val.targets) do
                            if target.parent_reference then
                                target.layer, target.cell = target.parent_reference[1], target.parent_reference[2]
                            end
                        end
                    elseif val.parent_reference then
                        val.layer, val.cell = val.parent_reference[1], val.parent_reference[2]
                    end
                end
            end

            for _, entry in pairs(cell.hidden_values) do
                local val = entry[2]
                local val_type = utils.ValueType(val)

                if val_type == "array" or val_type == "object" then
                    if val.targets then
                        for _, target in ipairs(val.targets) do
                            if target.parent_reference then
                                target.layer, target.cell = target.parent_reference[1], target.parent_reference[2]
                            end
                        end
                    elseif val.parent_reference then
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
        M.ExpandCell(tbl, tbl.layers[cell_ref[1]].cells[cell_ref[2]])
    end
end

return M
