local tbl = require "videre.table"
local utils = require "videre.utils"
local editing = require "videre.editing"
local config = require("videre.config").config
local help = require "videre.help"

local M = {}

---@param videre_tbl VidereTable
---@param map string
local function add_available_map(videre_tbl, map)
    videre_tbl.available_maps[# videre_tbl.available_maps + 1] = map
end

---@param videre_tbl VidereTable
---@param focus DataObjectRef
---@param value integer
local function add_change(videre_tbl, focus, value)
    videre_tbl.state_idx = videre_tbl.state_idx + 1
    videre_tbl.states[videre_tbl.state_idx] = {
        data = vim.deepcopy(videre_tbl.data),
        root = videre_tbl.layers[1].cells[1].data_ref,
        focus = focus,
        value = value,
    }

    while #videre_tbl.states > videre_tbl.state_idx do
        videre_tbl.states[#videre_tbl.states] = nil
    end
end

---@param buf integer
---@param videre_tbl VidereTable
function M.ClearAllMappings(buf, videre_tbl)
    videre_tbl.available_maps = {}

    for _, mapping in pairs(config.keymaps) do
        vim.keymap.set("n", mapping, function()
        end, { buffer = buf })
    end
end

---@param buf integer
---@param videre_tbl VidereTable
---@param cell VidereCell
function M.MakeExpandMapping(buf, videre_tbl, cell)
    add_available_map(videre_tbl, config.keymaps.expand)

    vim.keymap.set("n", config.keymaps.expand, function()
        local layer_num, cell_num, val = utils.GetHoveredCell(videre_tbl)

        tbl.ExpandCell(videre_tbl, cell)

        require("videre.buffer").Redraw(buf, videre_tbl)

        ---@diagnostic disable-next-line: param-type-mismatch
        tbl.JumpToCellAndValue(videre_tbl, layer_num, cell_num, val)
    end, { buffer = buf })
end

---@param buf integer
---@param videre_tbl VidereTable
---@param cell VidereCell
function M.MakeCollapseMapping(buf, videre_tbl, cell)
    add_available_map(videre_tbl, config.keymaps.collapse)

    vim.keymap.set("n", config.keymaps.collapse, function()
        local layer_num, cell_num, val = utils.GetHoveredCell(videre_tbl)

        tbl.CollapseCell(videre_tbl, cell)

        require("videre.buffer").Redraw(buf, videre_tbl)

        ---@diagnostic disable-next-line: param-type-mismatch
        tbl.JumpToCellAndValue(videre_tbl, layer_num, cell_num, val)
    end, { buffer = buf })
end

---@param buf integer
---@param videre_tbl VidereTable
---@param conn VidereConnection
function M.MakeJumpMapping(buf, videre_tbl, conn)
    add_available_map(videre_tbl, config.keymaps.jump_forward)

    vim.keymap.set("n", config.keymaps.jump_forward, function()
        tbl.JumpToCellAndValue(videre_tbl, conn.layer, conn.cell, 1)
    end, { buffer = buf })
end

---@param buf integer
---@param videre_tbl VidereTable
---@param cell VidereCell
function M.MakeJumpBackMapping(buf, videre_tbl, cell)
    add_available_map(videre_tbl, config.keymaps.jump_back)

    vim.keymap.set("n", config.keymaps.jump_back, function()
        tbl.JumpToCellAndValue(videre_tbl, cell.linking_cell[1], cell.linking_cell[2], cell.linking_cell[3])
    end, { buffer = buf })
end

---@param buf integer
---@param videre_tbl VidereTable
---@param layer integer
---@param cell integer
function M.MakeJumpUpMapping(buf, videre_tbl, layer, cell)
    add_available_map(videre_tbl, config.keymaps.jump_up)

    vim.keymap.set("n", config.keymaps.jump_up, function()
        tbl.JumpToCellAndValue(videre_tbl, layer, cell, 1)
    end, { buffer = buf })
end

---@param buf integer
---@param videre_tbl VidereTable
---@param layer integer
---@param cell integer
function M.MakeJumpDownMapping(buf, videre_tbl, layer, cell)
    add_available_map(videre_tbl, config.keymaps.jump_down)

    vim.keymap.set("n", config.keymaps.jump_down, function()
        tbl.JumpToCellAndValue(videre_tbl, layer, cell, 1)
    end, { buffer = buf })
end

---@param buf integer
---@param videre_tbl VidereTable
---@param layer integer
---@param cell integer
function M.MakeSetRootMapping(buf, videre_tbl, layer, cell)
    add_available_map(videre_tbl, config.keymaps.set_as_root)

    vim.keymap.set("n", config.keymaps.set_as_root, function()
        local new_table = tbl.MakeSubTable(videre_tbl, layer, cell)
        require("videre.buffer").JoinTableToBuffer(buf, new_table)
        tbl.JumpToCellAndValue(new_table, 1, 1, 1)
    end, { buffer = buf })
end

---@param buf integer
---@param videre_tbl VidereTable
function M.MakeReturnToParentTableMapping(buf, videre_tbl)
    add_available_map(videre_tbl, config.keymaps.return_to_parent_table)

    vim.keymap.set("n", config.keymaps.return_to_parent_table, function()
        local main_table = videre_tbl.parent_table
        if main_table then
            tbl.UnbindSubTable(videre_tbl)
            require("videre.buffer").JoinTableToBuffer(buf, main_table)
            tbl.JumpToCellAndValue(main_table, 1, 1, 1)
        end
    end, { buffer = buf })
end

---@param buf integer
---@param videre_tbl VidereTable
---@param layer_n integer
---@param cell_n integer
---@param val_n integer
function M.MakeChangeKeyMapping(buf, videre_tbl, layer_n, cell_n, val_n)
    add_available_map(videre_tbl, config.keymaps.change_key)

    vim.keymap.set("n", config.keymaps.change_key, function()
        local cell = videre_tbl.layers[layer_n].cells[cell_n]
        local old_key = cell.values[val_n][1]

        editing.MakeEditFloat({
            hint = videre_tbl.lang_spec.key_exe,
            ft = videre_tbl.lang_spec.ft,
            on_submit = function(key)
                local ok, res = pcall(videre_tbl.lang_spec.ParseKey, key)

                if not ok then
                    vim.notify("Videre Editing Error: " .. tostring(res):gsub("^.-:%d+: ", ""), vim.log.levels.ERROR)
                    return
                end


                local old_val = cell.data[old_key]
                cell.data[res] = old_val
                cell.data[old_key] = nil

                local focus = videre_tbl.layers[layer_n].cells[cell_n].data_ref
                local root = videre_tbl.layers[1].cells[1].data_ref

                local expanded = tbl.FindAllExpandedTables(videre_tbl.parent_table or videre_tbl)

                add_change(videre_tbl, focus, val_n)
                require("videre.buffer").JoinDataToBuffer(buf, videre_tbl, root, focus, val_n,
                    expanded)
            end
        })
    end, { buffer = buf })
end

---@param buf integer
---@param videre_tbl VidereTable
---@param layer_n integer
---@param cell_n integer
---@param val_n integer
function M.MakeChangeValueMapping(buf, videre_tbl, layer_n, cell_n, val_n)
    add_available_map(videre_tbl, config.keymaps.change_value)

    vim.keymap.set("n", config.keymaps.change_value, function()
        local cell = videre_tbl.layers[layer_n].cells[cell_n]
        local key = cell.values[val_n][1]

        editing.MakeEditFloat({
            hint = videre_tbl.lang_spec.val_exe,
            ft = videre_tbl.lang_spec.ft,
            on_submit = function(val)
                local ok, res = pcall(videre_tbl.lang_spec.ParseVal, val)

                if not ok then
                    vim.notify("Videre Editing Error: " .. tostring(res):gsub("^.-:%d+: ", ""), vim.log.levels.ERROR)
                    return
                end

                cell.data[key] = res

                local focus = videre_tbl.layers[layer_n].cells[cell_n].data_ref
                local root = videre_tbl.layers[1].cells[1].data_ref
                local expanded = tbl.FindAllExpandedTables(videre_tbl.parent_table or videre_tbl)

                add_change(videre_tbl, focus, val_n)
                require("videre.buffer").JoinDataToBuffer(buf, videre_tbl, root, focus, val_n, expanded)
            end
        })
    end, { buffer = buf })
end

---@param buf integer
---@param videre_tbl VidereTable
---@param layer_n integer
---@param cell_n integer
---@param val_n integer
function M.MakeDeleteValueMapping(buf, videre_tbl, layer_n, cell_n, val_n)
    add_available_map(videre_tbl, config.keymaps.delete_value)

    vim.keymap.set("n", config.keymaps.delete_value, function()
        local cell = videre_tbl.layers[layer_n].cells[cell_n]
        local key = cell.values[val_n][1]

        if cell.type == "object" then
            cell.data[key] = nil

            if next(cell.data) == nil then
                if layer_n == 1 then
                    videre_tbl.data = vim.empty_dict()
                else
                    local l, c, v = cell.linking_cell[1], cell.linking_cell[2], cell.linking_cell[3]
                    local parent = videre_tbl.layers[l].cells[c]
                    parent.data[parent.values[v][1]] = vim.empty_dict()
                end
            end
        else
            table.remove(cell.data, val_n)
        end

        local focus = videre_tbl.layers[layer_n].cells[cell_n].data_ref
        local root = videre_tbl.layers[1].cells[1].data_ref
        local expanded = tbl.FindAllExpandedTables(videre_tbl.parent_table or videre_tbl)

        add_change(videre_tbl, focus, val_n - 1)
        require("videre.buffer").JoinDataToBuffer(buf, videre_tbl, root, focus, val_n - 1, expanded)
    end, { buffer = buf })
end

---@param buf integer
---@param videre_tbl VidereTable
---@param layer_n integer
---@param cell_n integer
---@param val_n integer
function M.MakeAddValueMapping(buf, videre_tbl, layer_n, cell_n, val_n)
    add_available_map(videre_tbl, config.keymaps.add_value)

    vim.keymap.set("n", config.keymaps.add_value, function()
        local cell = videre_tbl.layers[layer_n].cells[cell_n]

        if cell.type == "object" then
            editing.MakeEditFloat({
                hint = videre_tbl.lang_spec.key_val_exe,
                ft = videre_tbl.lang_spec.ft,
                on_submit = function(input)
                    local ok, res = pcall(videre_tbl.lang_spec.ParseKeyVal, input)

                    if not ok then
                        vim.notify("Videre Editing Error: " .. tostring(res):gsub("^.-:%d+: ", ""), vim.log.levels.ERROR)
                        return
                    end

                    cell.data[res[1]] = res[2]

                    local focus = cell.data_ref
                    local root = videre_tbl.layers[1].cells[1].data_ref
                    local expanded = tbl.FindAllExpandedTables(videre_tbl.parent_table or videre_tbl)

                    add_change(videre_tbl, focus, val_n)
                    require("videre.buffer").JoinDataToBuffer(
                        buf, videre_tbl, root, focus, val_n + 1, expanded
                    )
                end
            })
        else
            -- Add array value
            editing.MakeEditFloat({
                hint = videre_tbl.lang_spec.val_exe,
                ft = videre_tbl.lang_spec.ft,

                on_submit = function(val)
                    local ok, res = pcall(videre_tbl.lang_spec.ParseVal, val)
                    if not ok then
                        vim.notify("Videre Editing Error: " .. tostring(res):gsub("^.-:%d+: ", ""), vim.log.levels.ERROR)
                        return
                    end

                    table.insert(cell.data, val_n + 1, res)

                    local focus = cell.data_ref
                    local root = videre_tbl.layers[1].cells[1].data_ref
                    local expanded = tbl.FindAllExpandedTables(videre_tbl.parent_table or videre_tbl)

                    add_change(videre_tbl, focus, val_n)
                    require("videre.buffer").JoinDataToBuffer(
                        buf, videre_tbl, root, focus, val_n + 1, expanded
                    )
                end
            })
        end
    end, { buffer = buf })
end

---@param buf integer
---@param videre_tbl VidereTable
---@param layer_n integer
---@param cell_n integer
function M.MakeChangeTypeMapping(buf, videre_tbl, layer_n, cell_n)
    add_available_map(videre_tbl, config.keymaps.change_type)

    vim.keymap.set("n", config.keymaps.change_type, function()
        local cell = videre_tbl.layers[layer_n].cells[cell_n]
        local old_type = cell.type

        cell.values = vim.tbl_extend("error", cell.values, cell.hidden_values)

        if old_type == "object" then
            cell.type = "array"

            for i, v in ipairs(cell.values) do
                local key, val = v[1], v[2]
                local val_type = utils.ValueType(val)

                cell.data[key] = nil
                if val_type == "array" or val_type == "object" then
                    cell.data[i] = videre_tbl.layers[val.layer].cells[val.cell].data
                else
                    ---@diagnostic disable-next-line: assign-type-mismatch
                    cell.data[i] = val
                end
            end
        elseif old_type == "array" then
            cell.type = "object"

            for _, v in ipairs(cell.values) do
                local key, val = v[1], v[2]
                local val_type = utils.ValueType(val)

                local new_key = "i_" .. tostring(key - 1 + config.index_base)

                cell.data[key] = nil
                if val_type == "array" or val_type == "object" then
                    cell.data[new_key] = videre_tbl.layers[val.layer].cells[val.cell].data
                else
                    ---@diagnostic disable-next-line: assign-type-mismatch
                    cell.data[new_key] = val
                end
            end
        end

        if next(cell.data) == nil then
            if layer_n == 1 then
                videre_tbl.data = old_type == "array" and vim.empty_dict() or {}
            else
                local l, c, v = cell.linking_cell[1], cell.linking_cell[2], cell.linking_cell[3]
                local parent = videre_tbl.layers[l].cells[c]
                parent.data[parent.values[v][1]] = old_type == "array" and vim.empty_dict() or {}
            end
        end

        -- Redraw buffer with correct focus + expanded state
        local focus = cell.data_ref
        local root = videre_tbl.layers[1].cells[1].data_ref
        local expanded = tbl.FindAllExpandedTables(videre_tbl.parent_table or videre_tbl)

        add_change(videre_tbl, focus, 1)
        require("videre.buffer").JoinDataToBuffer(
            buf,
            videre_tbl,
            root,
            focus,
            1,
            expanded
        )
    end, { buffer = buf })
end

---@param buf integer
---@param videre_table VidereTable
function M.MakeCloseWindowMapping(buf, videre_table)
    vim.keymap.set("n", config.keymaps.close_window, function()
        if videre_table.is_saved then
            vim.api.nvim_buf_delete(buf, {})
        else
            editing.MakeEditFloat({
                hint = { "Close without saving?", "Enter y/yes to exit without saving.", "Exit and run `:VidereCommit` to save." },
                on_submit = function(val)
                    val = string.lower(val)
                    if val == "y" or val == "yes" then
                        vim.api.nvim_buf_delete(buf, {})
                    end
                end
            })
        end
    end, { buffer = buf, nowait = true })
end

---@param buf integer
---@param videre_table VidereTable
function M.MakeUndoMapping(buf, videre_table)
    vim.keymap.set("n", config.keymaps.undo, function()
        videre_table.state_idx = videre_table.state_idx - 1
        local state = videre_table.states[videre_table.state_idx]
        videre_table.data = vim.deepcopy(state.data)

        local expanded = tbl.FindAllExpandedTables(videre_table.parent_table or videre_table)
        require("videre.buffer").JoinDataToBuffer(buf, videre_table, state.root, state.focus, state.value, expanded)
    end, { buffer = buf })

    add_available_map(videre_table, config.keymaps.undo)
end

---@param buf integer
---@param videre_table VidereTable
function M.MakeRedoMapping(buf, videre_table)
    vim.keymap.set("n", config.keymaps.redo, function()
        videre_table.state_idx = videre_table.state_idx + 1
        local state = videre_table.states[videre_table.state_idx]
        videre_table.data = vim.deepcopy(state.data)

        local expanded = tbl.FindAllExpandedTables(videre_table.parent_table or videre_table)
        require("videre.buffer").JoinDataToBuffer(buf, videre_table, state.root, state.focus, state.value, expanded)
    end, { buffer = buf })

    add_available_map(videre_table, config.keymaps.redo)
end

---@param buf integer
function M.MakeOpenHelpMenuMapping(buf)
    vim.keymap.set("n", config.keymaps.help, function()
        help.OpenHelpMenu()
    end, { buffer = buf })
end

return M
