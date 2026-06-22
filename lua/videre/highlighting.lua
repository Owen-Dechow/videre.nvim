local utils = require "videre.utils"
local config = require("videre.config").config

M = {}

local videre_special = "Special"
local ns = vim.api.nvim_create_namespace("VidereBase")
local ns_s = vim.api.nvim_create_namespace("VidereStatus")

---@param pos [integer, integer]
---@param buf integer
---@return [integer, integer]
local function convert_col_to_bytes(pos, buf)
    local line = vim.api.nvim_buf_get_lines(buf, pos[1], pos[1] + 1, true)[1]
    local loc = { pos[1], vim.fn.byteidx(line, pos[2] - 1) }
    return loc
end

---@param buf integer
---@param cell VidereCell
---@param left integer
function M.HighlightFocusedCell(buf, cell, left)
    ---@param pos [integer, integer]
    ---@return [integer, integer]
    local B = function(pos)
        return convert_col_to_bytes(pos, buf)
    end

    vim.hl.range(buf, ns_s, videre_special, B { cell.top_render_line, left },
        B { cell.top_render_line, left + cell.render_width })

    local total_rows = cell.total_display_rows or #cell.values
    for row = 1, total_rows do
        local line = cell.top_render_line + row

        vim.hl.range(buf, ns_s, videre_special, B { line, left },
            B { line, left + 1 })

        vim.hl.range(buf, ns_s, videre_special, B { line, left + cell.key_col_width + 1 },
            B { line, left + cell.key_col_width + 2 })

        vim.hl.range(buf, ns_s, videre_special, B { line, left + cell.render_width - 1 },
            B { line, left + cell.render_width })
    end

    vim.hl.range(buf, ns_s, videre_special, B { cell.top_render_line + total_rows + 1, left },
        B { cell.top_render_line + total_rows + 1, left + cell.render_width })

    if #cell.hidden_values > 0 then
        vim.hl.range(buf, ns_s, videre_special,
            B { cell.top_render_line + total_rows + 2, left },
            B { cell.top_render_line + total_rows + 2, left + cell.render_width })
    end

    local mouse_row = vim.api.nvim_win_get_cursor(0)[1] - 1
    vim.hl.range(buf, ns_s, "CursorLine", B { mouse_row, left },
        B { mouse_row, left + cell.render_width })
end

---@param bufnr integer
---@param line integer
---@param text string
---@param string_start integer
local function highlight_escapes(bufnr, line, text, string_start)
    string_start = string_start or 0


    local start = 1
    while true do
        local s, e = text:find("\\.", start)
        if not s then break end

        vim.hl.range(
            bufnr,
            ns,
            "SpecialChar",
            { line, string_start + (s - 1) },
            { line, string_start + e }
        )

        start = e + 1
    end
end

---@param buf integer
local function highlight_statusline(buf)
    local text = vim.api.nvim_buf_get_lines(buf, 0, 1, true)[1]

    local s, e = text:find("^%s*(%+?Videre)")
    if s then
        vim.hl.range(buf, ns_s, "Keyword", { 0, s - 1 }, { 0, e })
    end

    for bs, be in text:gmatch("()%[.-%]()") do
        vim.hl.range(buf, ns_s, "Special", { 0, bs - 1 }, { 0, be })
    end

    for ps, pe in text:gmatch("()%b()()") do
        vim.hl.range(buf, ns_s, "Identifier", { 0, ps - 1 }, { 0, pe })
    end
end

---@param buf integer
---@param tbl VidereTable
---@param cell VidereCell
---@param left integer
local function highlight_cell_values(buf, tbl, cell, left)
    ---@param pos [integer, integer]
    ---@return [integer, integer]
    local B = function(pos)
        return convert_col_to_bytes(pos, buf)
    end


    for i, entry in pairs(cell.values) do
        local line = cell.top_render_line + (entry.row_offset or i)

        vim.hl.range(buf, ns, "Comment",
            B { line, left + 1 },
            B { line, left + cell.key_col_width + 1 })

        vim.hl.range(buf, ns, cell.type == "array" and "Number" or "Identifier",
            B { line, left + entry.key_left_pad + 1 },
            B { line, left + cell.key_col_width - entry.key_right_pad + 1 })

        local type = ({
            array = videre_special,
            object = videre_special,
            string = "String",
            number = "Number",
            null = "Keyword",
            bool = "Boolean",
        })[utils.ValueType(entry[2])]

        vim.hl.range(buf, ns, "Comment", B { line, left + cell.key_col_width + 2 },
            B { line, left + cell.render_width - 1 })

        vim.hl.range(buf, ns, type, B { line, left + cell.key_col_width + entry.val_left_pad + 2 },
            B { line, left + cell.render_width - entry.val_right_pad - 1 })

        if type == "String" then
            local val_display = tbl.lang_spec.ValueAsString(entry[2], "string", false)
            local val_lines = utils.DisplayLines(val_display, config.tab_width)
            local start = B({ line, left + cell.key_col_width + entry.val_left_pad + 2 })[2]
            highlight_escapes(buf, line, val_lines[1], start)

            local val_col_width = cell.render_width - cell.key_col_width - 3
            for li = 2, #val_lines do
                local cont_line = line + (li - 1)
                local cont_left_pad, _, cont_right_pad = utils.PadLine(val_lines[li], val_col_width,
                    config.value_alignment, config.value_space)

                vim.hl.range(buf, ns, "Comment",
                    B { cont_line, left + 1 },
                    B { cont_line, left + cell.key_col_width + 1 })

                vim.hl.range(buf, ns, "Comment",
                    B { cont_line, left + cell.key_col_width + 2 },
                    B { cont_line, left + cell.render_width - 1 })

                vim.hl.range(buf, ns, "String",
                    B { cont_line, left + cell.key_col_width + cont_left_pad + 2 },
                    B { cont_line, left + cell.render_width - cont_right_pad - 1 })

                local cont_start = B({ cont_line, left + cell.key_col_width + cont_left_pad + 2 })[2]
                highlight_escapes(buf, cont_line, val_lines[li], cont_start)
            end
        end
    end
end

---@param buf integer
---@param tbl VidereTable
---@param statusline_only boolean
function M.HighlightBuffer(buf, tbl, statusline_only)
    if not statusline_only then
        for _, layer in pairs(tbl.layers) do
            for _, cell in pairs(layer.cells) do
                if not cell.is_hidden then
                    highlight_cell_values(buf, tbl, cell, layer.left_render_col)
                end
            end
        end
    end

    highlight_statusline(buf)
end

---@param buf integer
---@param statusline_only boolean
function M.Clear(buf, statusline_only)
    if not statusline_only then
        vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
    end

    vim.api.nvim_buf_clear_namespace(buf, ns_s, 0, -1)
end

return M
