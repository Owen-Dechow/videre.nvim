local utils = require("videre.utils")

local M = {}

---Renders the obj to the editor buf
---@param obj table
---@param editor_buf integer
---@param key_set any[]
---@param lang_spec LangSpec
M.RenderGraph = function(obj, editor_buf, key_set, lang_spec)
    local text_output_table = {}
    local render_info = {
        line_callbacks = {},
        shown_obj = obj,
        shown_key_set = key_set,
        row_unit_breaks = {},
        text_output_table = text_output_table,
    }

    require("videre.table_objs").TableObject(obj, text_output_table, 1, key_set, nil, lang_spec)
    local connections = require("videre.connections").BuildConnections(text_output_table)

    local output_lines = {}
    local line = 1
    local any = true

    while any do
        local lines = {}
        any = false
        local line_idx = #output_lines + 1
        local row_col_info = {}
        render_info.row_unit_breaks[line_idx] = row_col_info
        for col_idx, col in pairs(text_output_table) do
            local text_line
            if line > col.lines then
                text_line = { string.rep(" ", col.width), {} }
                row_col_info[col_idx] = { empty = true }
            else
                any = true
                local b_line = line
                for _, box in pairs(col.boxes) do
                    if b_line - #box.text_lines <= 0 then
                        text_line = box.text_lines[b_line]

                        local left, fill, right = text_line[1], text_line[2], text_line[3]

                        local conjoined = left .. right
                        local utf8len_ = utils.utf8len(conjoined)

                        if text_line[4] then
                            local len = string.len(conjoined)
                            text_line[4].limit = len + (col.width - utf8len_) * string.len(fill)
                        end

                        text_line = {
                            left
                            .. string.rep(fill, col.width - utf8len_)
                            .. right, text_line[4]
                        }

                        row_col_info[col_idx] = { empty = false, width = string.len(text_line[1]), box = box }

                        break
                    end

                    b_line = b_line - #box.text_lines
                end
            end

            local col_connections = connections[col_idx]
            if col_connections ~= nil then
                local section_connection = col_connections[line]
                if section_connection ~= nil then
                    text_line[1] = text_line[1] .. table.concat(section_connection)
                    any = true
                end
            end

            lines[#lines + 1] = text_line
        end

        local current_line_callbacks = {}
        local text_line = ""
        for col_idx, section in pairs(lines) do
            local start = string.len(text_line)
            if current_line_callbacks[start] == nil then
                current_line_callbacks[start] = {}
            end

            row_col_info[col_idx].start = start

            if section[2] then
                local limit = section[2].limit
                for key, callback in pairs(section[2]) do
                    if key ~= "limit" then
                        callback.limit = limit
                        current_line_callbacks[start][#current_line_callbacks[start] + 1] = callback
                    end
                end
            end

            text_line = text_line .. section[1]
        end

        output_lines[line] = text_line
        render_info.line_callbacks[line] = current_line_callbacks
        line = line + 1
    end

    vim.api.nvim_buf_set_option(editor_buf, 'modifiable', true)
    vim.api.nvim_buf_set_lines(editor_buf, 1, -1, false, output_lines)
    require("videre.highlighting").ApplyHighlighting(lang_spec)

    vim.api.nvim_buf_set_option(editor_buf, 'modifiable', false)

    require("videre").render_info[editor_buf] = render_info
end

return M
