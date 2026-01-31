local utils = require("videre.utils")
local edges = require("videre.edges")
local consts = require("videre.consts")
local langs = require("videre.langs")

local M = {
    has_edits = {},
    expanded = {},
    config = {
        ---@type string
        editor_type = "split", -- split, floating

        ---@type table
        floating_editor_style = {
            margin = 2,
            border = "double",
            zindex = 10
        },

        ---@type integer
        max_lines = 5,

        ---@type boolean
        round_units = true,

        ---@type boolean
        round_connections = true,

        ---@type number
        connection_spacing = 2,

        ---@type boolean
        disable_line_wrap = true,

        ---@type string
        keymap_desc_deliminator = "=",

        ---@type string
        space_char = "·",

        ---@type integer | nil
        side_scrolloff = 20,

        ---@type boolean
        simple_statusline = true,

        ---@type boolean
        breadcrumbs = true,

        ---@type table
        keymap_priorities = {
            ---@type integer
            expand = 5,

            ---@type integer
            link_forward = 4,

            ---@type integer
            link_backward = 3,

            ---@type integer
            link_down = 1,

            ---@type integer
            link_up = 1,

            ---@type integer
            collapse = 2,

            ---@type integer
            set_as_root = 1,
        },

        ---@type table
        keymaps = {
            ---@type string
            expand = "E",

            ---@type string
            collapse = "E",

            ---@type string
            link_forward = "L",

            ---@type string
            link_backward = "H",

            ---@type string
            link_down = "J",

            ---@type string
            link_up = "K",

            ---@type string
            set_as_root = "R",

            ---@type string
            quick_action = "<CR>",

            ---@type string
            close_window = "q",

            ---@type string
            help = "g?",

            ---@type string
            change_key = "C",

            ---@type string
            change_value = "V",

            ---@type string
            delete_field = "D",

            ---@type string
            add_field = "A"
        }
    },
    render_info = {},
}

---@alias Vec2 { [1]: integer, [2]: integer }
---@alias Callback {[1]: string, [2]: function}
---@alias TextLine { [1]: string, [2]: string, [3]: string, [4]: Callback[]}

---@alias RenderInfo {
---line_callbacks:table,
---shown_obj: table,
---shown_key_set: table,
---row_unit_breaks: table,
---text_output_table: table}

---@alias LangSpec {
---name: string,
---highlight: function|nil,
---encode: function,
---decode: function,
---symbols: {null: string|nil, lst: string|nil, tbl: string|nil}}

---Opens the Videre on the specified buffer
---@param bufn integer
---@param filetype string
M.OpenVidereOnBuf = function(bufn, filetype)
    local lang = langs.get(filetype)

    if lang ~= nil then
        local lines = vim.api.nvim_buf_get_lines(bufn, 0, -1, false)
        local text = table.concat(lines, "\n")
        local is_valid, lua_table = pcall(lang.decode, text)

        if not is_valid then
            vim.notify("Error parsing " .. filetype .. " text:\n" .. lua_table)
            return
        end

        require("videre.window").ShowVidereWindow(bufn, lua_table, vim.api.nvim_buf_get_name(0), lang)
    end
end

---Opens the Videre Window on the current buffer
M.OpenVidere = function()
    local bufn = vim.api.nvim_buf_get_number(0)
    M.OpenVidereOnBuf(bufn, vim.bo.filetype)
end

vim.api.nvim_create_user_command(consts.plugin_name, M.OpenVidere, {})

---Set up the plugin
---@param opts table
M.setup = function(opts)
    utils.update_table(opts, M.config)

    if M.config.round_connections then
        edges.line = edges.ROUND_LINE
    else
        edges.line = edges.HARD_LINE
    end

    if M.config.round_units then
        edges.edge = edges.ROUND_EDGE
    else
        edges.edge = edges.HARD_EDGE
    end
end

return M
