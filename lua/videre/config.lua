---@alias LineStyle "sharp"|"rounded"|"bold"|"double"
---@alias ColumnAlignment "top"|"center"|"bottom"
---@alias RowAlignment "left"|"center"|"right"

local M = {
    ---@type VidereConfig|nil
    og = nil
}

---@class VidereConfig
M.config = {
    ---@type string
    outside_space = " ",

    ---@type string
    key_space = " ",

    ---@type string
    value_space = "·",

    ---@type ColumnAlignment
    column_alignment = "center",

    ---@type RowAlignment
    key_alignment = "right",

    ---@type RowAlignment
    value_alignment = "right",

    ---@type integer
    connection_spacing = 2,

    ---@type integer
    cell_spacing = 1,

    ---@type integer
    max_cell_lines = 5,

    ---@type string
    collapse_indication_character = ".",

    ---@type LineStyle
    box_style = "rounded",

    ---@type LineStyle
    line_style = "rounded",

    ---@type integer
    editor_window_width = 60,

    keymaps = {
        ---@type string
        expand = "E",

        ---@type string
        collapse = "E",

        ---@type string
        jump_forward = "L",

        ---@type string
        jump_back = "H",

        ---@type string
        jump_down = "J",

        ---@type string
        jump_up = "K",

        ---@type string
        set_as_root = "R",

        ---@type string
        return_to_parent_table = "H",

        ---@type string
        change_key = "C",

        ---@type string
        change_value = "V",

        ---@type string
        delete_value = "D",

        ---@type string
        add_value = "A",

        ---@type string
        change_type = "T",

        ---@type string
        help = "g?",

        ---@type string
        close_window = "q",
    },

    ---@type "split"|"floating"
    editor_type = "split",

    floating_editor_style = {
        ---@type integer
        margin = 2,

        ---@type "rounded"|"double"|"shadow"|"none"
        border = "rounded",

        ---@type integer
        zindex = 10
    },

    split_editor_style = {
        ---@type "left"|"right"|"default"
        side = "right",

        ---@type number
        fill_percentage = 0.7,
    },

    ---@type integer
    sidescrolloff = 20,

    ---@type integer
    scrolloff = 10,
}

---@alias FieldSpec string[]

---@param spec FieldSpec
---@return any
local function get_field(spec)
    local tbl = M.config

    for _, key in ipairs(spec) do
        tbl = tbl[key]
    end

    return tbl
end

---@param spec FieldSpec
local function reset_field(spec)
    local tbl = M.config
    local og = M.og

    for i = 1, #spec - 1 do
        tbl = tbl[spec[i]]

        ---@diagnostic disable-next-line: need-check-nil
        og = og[spec[i]]
    end

    tbl[spec[#spec]] = og[spec[#spec]]
end

---@param err string
local function print_error(err)
    vim.notify("Videre Settings Error: " .. err, vim.log.levels.ERROR)
end

---@param field FieldSpec
local function confirm_is_single_char(field)
    local val = get_field(field)

    if type(val) ~= "string" or require("videre.utils").StringWidth(val) ~= 1 then
        print_error(
            table.concat(field, ".") .. " must be a single character string. Resetting to default value."
        )
        reset_field(field)
    end
end

---@param enum string[]
local function confirm_is_enum(field, enum)
    local val = get_field(field)

    for _, en in pairs(enum) do
        if val == en then
            return
        end
    end

    print_error(
        table.concat(field, ".") ..
        " must be of the enum [" .. table.concat(enum, ", ") .. "]. Resetting to default value."
    )

    reset_field(field)
end

---@param field FieldSpec
---@param min integer
---@param max integer
local function confirm_is_integer_in_range(field, min, max)
    local val = get_field(field)

    if type(val) ~= "number" or val % 1 ~= 0 or val < min or val > max then
        print_error(
            table.concat(field, ".") ..
            " must be an integer in range [" .. min .. ", " .. max .. "]. Resetting to default value."
        )

        reset_field(field)
    end
end

---@param field FieldSpec
---@param min number
---@param max number
local function confirm_is_number_in_range(field, min, max)
    local val = get_field(field)

    if type(val) ~= "number" or val < min or val > max then
        print_error(
            table.concat(field, ".") ..
            " must be an float in range [" .. min .. ", " .. max .. "]. Resetting to default value."
        )

        reset_field(field)
    end
end

---@param field FieldSpec
local function confirm_is_valid_keymap(field)
    local val = get_field(field)

    if type(val) == "string" then
        local success, _ = pcall(function()
            return vim.api.nvim_replace_termcodes(val, true, true, true)
        end)

        if success then
            return
        end
    end

    print_error(
        table.concat(field, ".") ..
        " must be a valid keymap. Resetting to default value."
    )

    reset_field(field)
end

---@param config  VidereConfig
function M.Setup(config)
    M.og = M.config
    M.config = vim.tbl_deep_extend("force", M.config, config)

    confirm_is_single_char({ "key_space" })
    confirm_is_single_char({ "collapse_indication_character" })
    confirm_is_single_char({ "value_space" })
    confirm_is_single_char({ "outside_space" })

    confirm_is_enum({ "column_alignment" }, { "top", "center", "bottom" })
    confirm_is_enum({ "key_alignment" }, { "left", "center", "right" })
    confirm_is_enum({ "value_alignment" }, { "left", "center", "right" })

    confirm_is_integer_in_range({ "connection_spacing" }, 0, 99)
    confirm_is_integer_in_range({ "cell_spacing" }, 0, 99)
    confirm_is_integer_in_range({ "max_cell_lines" }, 1, 999)

    confirm_is_enum({ "box_style" }, { "sharp", "rounded", "bold", "double" })
    confirm_is_enum({ "line_style" }, { "sharp", "rounded", "bold", "double" })

    confirm_is_integer_in_range({ "editor_window_width" }, 6, 999)

    confirm_is_enum({ "editor_type" }, { "split", "floating" })

    confirm_is_integer_in_range({ "floating_editor_style", "margin" }, 0, 99)
    confirm_is_enum({ "floating_editor_style", "border" }, { "rounded", "double", "shadow", "none" })
    confirm_is_integer_in_range({ "floating_editor_style", "zindex" }, 0, 99)

    confirm_is_enum({ "split_editor_style", "side" }, { "left", "default", "right" })
    confirm_is_number_in_range({ "split_editor_style", "fill_percentage" }, 0.1, 0.9)

    confirm_is_integer_in_range({ "sidescrolloff" }, 0, 999)
    confirm_is_integer_in_range({ "scrolloff" }, 0, 999)

    confirm_is_valid_keymap({ "keymaps", "expand" })
    confirm_is_valid_keymap({ "keymaps", "collapse" })
    confirm_is_valid_keymap({ "keymaps", "jump_forward" })
    confirm_is_valid_keymap({ "keymaps", "jump_back" })
    confirm_is_valid_keymap({ "keymaps", "jump_down" })
    confirm_is_valid_keymap({ "keymaps", "jump_up" })
    confirm_is_valid_keymap({ "keymaps", "set_as_root" })
    confirm_is_valid_keymap({ "keymaps", "return_to_parent_table" })
    confirm_is_valid_keymap({ "keymaps", "change_key" })
    confirm_is_valid_keymap({ "keymaps", "change_value" })
    confirm_is_valid_keymap({ "keymaps", "delete_value" })
    confirm_is_valid_keymap({ "keymaps", "add_value" })
    confirm_is_valid_keymap({ "keymaps", "change_type" })
    confirm_is_valid_keymap({ "keymaps", "help" })
    confirm_is_valid_keymap({ "keymaps", "close_window" })
end

return M
