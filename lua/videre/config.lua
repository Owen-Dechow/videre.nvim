---@alias LineStyle "sharp"|"rounded"|"bold"|"double"
---@alias ColumnAlignment "top"|"center"|"bottom"
---@alias RowAlignment "left"|"center"|"right"

local M = {
    ---@type VidereConfig|nil
    og = nil
}

---@class VidereConfig
M.config = {
    ---@comment Character used between cells
    ---@type string
    outside_space = " ",

    ---@comment Character to pad the key column
    ---@type string
    key_space = " ",

    ---@comment Character to pad the value column
    ---@type string
    value_space = "·",

    ---@comment Alignment of cell columns
    ---@type ColumnAlignment
    column_alignment = "center",

    ---@comment Alignment of the keys within the cell
    ---@type RowAlignment
    key_alignment = "right",

    ---@comment Alignment of the values within the cell
    ---@type RowAlignment
    value_alignment = "right",

    ---@comment Space between connective lines (int: [0,99])
    ---@type integer
    connection_spacing = 2,

    ---@comment Space between cells (int: [0,99])
    ---@type integer
    cell_spacing = 1,

    ---@comment Number of lines shown by default in cell (int: [0,999])
    ---@type integer
    max_cell_lines = 5,

    ---@comment Character used to indicate call values beyond `max_cell_lines`
    ---@type string
    collapse_indication_character = ".",

    ---@comment Style of the connective lines
    ---@type LineStyle
    box_style = "rounded",

    ---@comment Style of the cells
    ---@type LineStyle
    line_style = "rounded",

    ---@comment Width of the editing character (int: [6, 999])
    ---@type integer
    editor_window_width = 60,

    ---@comment Number of spaces each tab character expands to (int: [1,16])
    ---@type integer
    tab_width = 4,

    ---@comment Toggle expansion of \t character
    ---@type boolean
    expand_tabs = false,

    ---@comment Toggle expansion of \n and \r\n characters
    ---@type boolean
    expand_newlines = false,

    ---@comment Max display width of string values in characters; 0 disables wrapping (int: [0,9999])
    ---@type integer
    max_line_width = 30,

    keymaps = {
        ---@comment Expand lines beyond `max_cell_lines`
        ---@type string
        expand = "E",

        ---@comment Collapse lines beyond `max_cell_lines`
        ---@type string
        collapse = "E",

        ---@comment Move cursor to linked cell
        ---@type string
        jump_forward = "L",

        ---@comment Move cursor to parent cell
        ---@type string
        jump_back = "H",

        ---@comment Move cursor to cell above in cell column
        ---@type string
        jump_down = "J",

        ---@comment Move cursor to cell below in cell column
        ---@type string
        jump_up = "K",

        ---@comment Set cell as root cell
        ---@type string
        set_as_root = "R",

        ---@comment Return to the true root cell
        ---@type string
        return_to_parent_table = "H",

        ---@comment Change the key of a value
        ---@type string
        change_key = "C",

        ---@comment Change a value
        ---@type string
        change_value = "V",

        ---@comment Delete a value
        ---@type string
        delete_value = "D",

        ---@comment Add a value
        ---@type string
        add_value = "A",

        ---@comment Toggle type of cell between array-like and object-like
        ---@type string
        change_type = "T",

        ---@comment Undo a change 
        ---@type string
        undo = "u",

        ---@comment Redo a change i.e. undo an undo
        ---@type string
        redo = "<C-r>",

        ---@comment Open help menu
        ---@type string
        help = "g?",

        ---@comment Exit
        ---@type string
        close_window = "q",
    },

    ---@comment Type of window Videre will open in
    ---@type "split"|"floating"
    editor_type = "split",

    ---@comment Styles of floating window
    floating_editor_style = {
        ---@comment Space around floating window
        ---@type integer
        margin = 2,

        ---@comment Floating window border type
        ---@type "rounded"|"double"|"shadow"|"none"
        border = "rounded",

        ---@comment Floating window z-index
        ---@type integer
        zindex = 10
    },

    ---@comment Styles of v-split window
    split_editor_style = {
        ---@comment Where to open Videre
        ---@type "left"|"right"|"default"
        side = "right",

        ---@comment What percentage of window Videre covers (num: [0.1, 0.9])
        ---@type number
        fill_percentage = 0.7,
    },

    ---@comment Side scrolloff for Videre window (int: [0, 999])
    ---@type integer
    sidescrolloff = 20,

    ---@comment Scrolloff for Videre window (int: [0, 999])
    ---@type integer
    scrolloff = 10,

    ---@comment Set the indexing base i.e. 0, 1 or whatever else you want
    ---@type integer
    index_base = 0,
}

---@param field string
---@return any
local function get_field(field)
    local tbl = M.config
    local spec = vim.split(field, "%.")

    for _, key in ipairs(spec) do
        tbl = tbl[key]
    end

    return tbl
end

---@param field string
local function reset_field(field)
    local spec = vim.split(field, "%.")
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
---@param level number|nil
local function print_error(err, level)
    vim.notify("Videre Settings Error: " .. err, level or vim.log.levels.ERROR)
end

---@param field string
local function confirm_is_single_char(field)
    local val = get_field(field)

    if type(val) ~= "string" or require("videre.utils").StringWidth(val) ~= 1 then
        print_error(field .. " must be a single character string. Resetting to default value.")
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

    print_error(field .. " must be of the enum [" .. table.concat(enum, ", ") .. "]. Resetting to default value.")
    reset_field(field)
end

---@param field string
---@param min integer
---@param max integer
local function confirm_is_integer_in_range(field, min, max)
    local val = get_field(field)

    if type(val) ~= "number" or val % 1 ~= 0 or val < min or val > max then
        print_error(field .. " must be an integer in range [" .. min .. ", " .. max .. "]. Resetting to default value.")
        reset_field(field)
    end
end

---@param field string
---@param min number
---@param max number
local function confirm_is_number_in_range(field, min, max)
    local val = get_field(field)

    if type(val) ~= "number" or val < min or val > max then
        print_error(field .. " must be an float in range [" .. min .. ", " .. max .. "]. Resetting to default value.")
        reset_field(field)
    end
end

---@param field string
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

    print_error(field .. " must be a valid keymap. Resetting to default value.")
    reset_field(field)
end

---@param field string
local function confirm_is_boolean(field)
    local val = get_field(field)

    if type(val) ~= "boolean" then
        print_error(field .. " must be a valid keymap. Resetting to default value.")
        reset_field(field)
    end
end

local function validate_opts(opts, default, prefix)
    prefix = prefix or ""

    for key, value in pairs(opts) do
        local def = default[key]

        if def == nil then
            local msg =
                table.concat({ "Invalid option passed to Videre setup: %s%s.",
                    "This may be a result of using deprecated options in setup.",
                    "Please run `:help videre-options` for more information." }, "\n")
                :format(prefix, key)
            print_error(msg, vim.log.levels.WARN)
            opts[key] = nil
        end

        if type(value) == "table" and type(def) == "table" then
            validate_opts(value, def, prefix .. key .. ".")
        end
    end
end


---@param config  VidereConfig
function M.Setup(config)
    M.og = M.config
    M.config = vim.tbl_deep_extend("force", M.config, config)

    validate_opts(M.config, M.og)

    confirm_is_single_char("key_space")
    confirm_is_single_char("collapse_indication_character")
    confirm_is_single_char("value_space")
    confirm_is_single_char("outside_space")

    confirm_is_enum("column_alignment", { "top", "center", "bottom" })
    confirm_is_enum("key_alignment", { "left", "center", "right" })
    confirm_is_enum("value_alignment", { "left", "center", "right" })

    confirm_is_integer_in_range("connection_spacing", 0, 99)
    confirm_is_integer_in_range("cell_spacing", 0, 99)
    confirm_is_integer_in_range("max_cell_lines", 1, 999)

    confirm_is_enum("box_style", { "sharp", "rounded", "bold", "double" })
    confirm_is_enum("line_style", { "sharp", "rounded", "bold", "double" })

    confirm_is_integer_in_range("editor_window_width", 6, 999)
    confirm_is_integer_in_range("tab_width", 1, 16)
    confirm_is_integer_in_range("max_line_width", 0, 9999)

    confirm_is_enum("editor_type", { "split", "floating" })

    confirm_is_integer_in_range("floating_editor_style.margin", 0, 99)
    confirm_is_enum("floating_editor_style.border", { "rounded", "double", "shadow", "none" })
    confirm_is_integer_in_range("floating_editor_style.zindex", 0, 99)

    confirm_is_enum("split_editor_style.side", { "left", "default", "right" })
    confirm_is_number_in_range("split_editor_style.fill_percentage", 0.1, 0.9)

    confirm_is_integer_in_range("sidescrolloff", 0, 999)
    confirm_is_integer_in_range("scrolloff", 0, 999)

    confirm_is_valid_keymap("keymaps.expand")
    confirm_is_valid_keymap("keymaps.collapse")
    confirm_is_valid_keymap("keymaps.jump_forward")
    confirm_is_valid_keymap("keymaps.jump_back")
    confirm_is_valid_keymap("keymaps.jump_down")
    confirm_is_valid_keymap("keymaps.jump_up")
    confirm_is_valid_keymap("keymaps.set_as_root")
    confirm_is_valid_keymap("keymaps.return_to_parent_table")
    confirm_is_valid_keymap("keymaps.change_key")
    confirm_is_valid_keymap("keymaps.change_value")
    confirm_is_valid_keymap("keymaps.delete_value")
    confirm_is_valid_keymap("keymaps.add_value")
    confirm_is_valid_keymap("keymaps.change_type")
    confirm_is_valid_keymap("keymaps.help")
    confirm_is_valid_keymap("keymaps.close_window")
    confirm_is_valid_keymap("keymaps.undo")
    confirm_is_valid_keymap("keymaps.redo")

    confirm_is_integer_in_range("index_base", -999, 999)

    confirm_is_boolean("expand_tabs")
    confirm_is_boolean("expand_newlines")
end

return M
