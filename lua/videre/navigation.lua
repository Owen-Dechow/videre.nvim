local consts = require("videre.consts")
local utils = require("videre.utils")
local cfg = utils.cfg

local M = {}

local function get_breadcrumbs(box)
    return " (" .. table.concat(box.key_set, " ➧ ", 2) .. ")"
end

local function full_statusline(callback_keys, enter_map, box, editor_buf)
    local eq = cfg().keymap_desc_deliminator

    local statusline_text
    if require("videre").has_edits[editor_buf] then
        statusline_text = "+"
    else
        statusline_text = ""
    end

    statusline_text = statusline_text .. consts.plugin_name
        .. " [" .. cfg().keymaps.close_window .. eq .. "Close Window]"
        .. " [" .. cfg().keymaps.help .. eq .. "Open Help]"

    if enter_map then
        statusline_text = statusline_text .. " [" .. cfg().keymaps.quick_action .. eq .. enter_map[1] .. "]"
    end

    for k, h in pairs(callback_keys) do
        statusline_text = statusline_text .. " [" .. k .. eq .. h[2] .. "]"
    end

    if cfg().breadcrumbs and box and #box.key_set > 1 then
        statusline_text = statusline_text .. get_breadcrumbs(box)
    end

    return statusline_text
end

local function simple_statusline(enter_map, box, editor_buf)
    local eq = cfg().keymap_desc_deliminator

    local statusline_text
    if require("videre").has_edits[editor_buf] then
        statusline_text = "+"
    else
        statusline_text = ""
    end

    statusline_text = statusline_text .. consts.plugin_name .. " [" .. cfg().keymaps.help

    if enter_map then
        statusline_text =
            statusline_text .. " " .. cfg().keymaps.quick_action .. eq .. enter_map[1]
    end

    statusline_text = statusline_text .. "]"

    if cfg().breadcrumbs and box and #box.key_set > 1 then
        statusline_text = statusline_text .. get_breadcrumbs(box)
    end

    return statusline_text
end

local function update_statusline(set_text, callback_keys, enter_map, box, editor_buf)
    table.sort(callback_keys, function(a, b) return a[3] >= b[3] end)

    if cfg().simple_statusline then
        set_text(simple_statusline(enter_map, box, editor_buf))
    else
        set_text(full_statusline(callback_keys, enter_map, box, editor_buf))
    end
end

---Cursor moved autocommand
---@param editor_buf integer
---@param obj table
---@param file string
---@param file_buf integer
---@param set_statusline_text function
M.CursorMoved = function(editor_buf, obj, file, file_buf, set_statusline_text)
    local pos = vim.api.nvim_win_get_cursor(0)
    if pos[1] == 1 then
        vim.api.nvim_win_set_cursor(0, { 2, pos[2] })
        pos[1] = 2
    end

    local ignored_remaps = { [cfg().keymaps.close_window] = true, [cfg().keymaps.help] = true }
    for _, k in pairs(cfg().keymaps) do
        if not ignored_remaps[k] then
            utils.keymap(k, function()
                vim.notify(k .. " is not valid at this location", "WARN")
            end)
        end
    end

    local callback_keys = {}
    local enter_map
    local render_info = require("videre").render_info
    local call_opts = {
        editor_buf = editor_buf,
        obj = obj,
        file = file,
        file_buf = file_buf,
        render_info = render_info[editor_buf],
    }

    local row_col_info = render_info[editor_buf].row_unit_breaks[pos[1] - 1]
    local box
    vim.api.nvim_buf_clear_namespace(0, -1, 0, -1)
    for col_idx, col in pairs(row_col_info) do
        if not col.empty then
            if pos[2] >= col.start and pos[2] < col.start + col.width then
                box = col.box
                for row_idx = col.box.top_line, col.box.top_line + #col.box.text_lines - 1 do
                    row_col_info = render_info[editor_buf].row_unit_breaks[row_idx][col_idx]

                    if
                        row_idx == col.box.top_line
                        or row_idx == col.box.top_line + #col.box.text_lines - 1
                    then
                        vim.api.nvim_buf_add_highlight(0, -1, "VidereUnitHighlight", row_idx, row_col_info.start,
                            row_col_info.start + row_col_info.width)
                    else
                        vim.api.nvim_buf_add_highlight(0, -1, "VidereUnitHighlight", row_idx, row_col_info.start,
                            row_col_info.start + 1)

                        vim.api.nvim_buf_add_highlight(0, -1, "VidereUnitHighlight", row_idx,
                            row_col_info.start + row_col_info.width - 3,
                            row_col_info.start + row_col_info.width)
                    end
                end

                vim.api.nvim_buf_add_highlight(0, -1, "CursorLine", pos[1] - 1, col.start, col.start + col.width)
            end
        end
    end

    for start, callback_set in pairs(render_info[editor_buf].line_callbacks[pos[1] - 1]) do
        if pos[2] >= start then
            for _, callback in pairs(callback_set) do
                if pos[2] < start + callback.limit then
                    if callback.predicate == nil or callback.predicate(call_opts) then
                        if enter_map == nil or enter_map[4] < callback[4] then
                            enter_map = callback
                        end

                        local fn = function()
                            callback[2](call_opts)
                            if callback.modifying then
                                require("videre").has_edits[editor_buf] = true
                                M.CursorMoved(editor_buf, obj, file, file_buf, set_statusline_text)
                            end
                        end

                        callback_keys[callback[1]] = { fn, callback[3], callback[4] }
                        utils.keymap(callback[1], fn)
                    end
                end
            end
        end
    end

    if enter_map then
        utils.keymap(cfg().keymaps.quick_action, function()
            enter_map[2](call_opts)
        end)
    else
        utils.keymap(cfg().keymaps.quick_action, function()
            vim.notify(cfg().keymaps.quick_action .. " is not valid at this location", "WARN")
        end)
    end

    update_statusline(set_statusline_text, callback_keys, enter_map, box, editor_buf)
end

return M
