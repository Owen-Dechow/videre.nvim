local utils = require("json_graph_view.utils")
local edges = require("json_graph_view.edges")
local consts = require("json_graph_view.consts")
local langs = require("json_graph_view.langs")

local M = {
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

        ---@type boolean
        disable_line_wrap = true,

        ---@type table
        keymap_priorities = {
            ---@type integer
            expand = 4,

            ---@type integer
            link_forward = 3,

            ---@type integer
            link_backward = 3,

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
            link_backward = "B",

            ---@type string
            set_as_root = "R",

            ---@type string
            quick_action = "<CR>",

            ---@type string
            close_window = "q"
        }
    },
    render_info = {},
}

---@alias Vec2 { [1]: integer, [2]: integer }
---@alias Callback {[1]: string, [2]: function}
---@alias TextLine { [1]: string, [2]: string, [3]: string, [4]: Callback[]}

---@alias LangSpec {
---highlight: function|nil,
---encode: function,
---decode: function,
---symbols: {null: string|nil, lst: string|nil, tbl: string|nil}}

---Converts object to its string representation
---@param val any
---@param no_quotes boolean | nil
---@param lang_spec LangSpec
---@return string | nil
M.GetValAsString = function(val, no_quotes, lang_spec)
    if val == vim.NIL then
        return lang_spec.symbols.null or "null"
    elseif val == vim.empty_dict() then
        return lang_spec.symbols.tbl or "{}"
    elseif type(val) == "string" then
        if no_quotes then
            return utils.escape_string(val)
        else
            return '"' .. utils.escape_string(val) .. '"'
        end
    elseif type(val) == "number" then
        return tostring(val)
    elseif type(val) == "boolean" then
        return tostring(val)
    elseif type(val) == "table" then
        if vim.islist(val) then
            return lang_spec.symbols.lst or "[]"
        else
            return lang_spec.symbols.tbl or "{}"
        end
    end
end

---Gets the length of the string representation of a value.
---@param val any,
---@param lang_spec LangSpec
---@return integer | nil
M.GetLenOfValue = function(val, lang_spec)
    if val == vim.NIL then
        if lang_spec.symbols.null then
            return string.len(lang_spec.symbols.null)
        else
            return 4
        end
    elseif type(val) == "string" then
        return utils.utf8len(utils.escape_string(val)) + 2
    elseif type(val) == "number" then
        return #tostring(val)
    elseif type(val) == "boolean" then
        if val then
            return 4
        else
            return 5
        end
    elseif val == vim.empty_dict() then
        if lang_spec.symbols.tbl then
            return string.len(lang_spec.symbols.lst)
        else
            return 2
        end
    elseif type(val) == "table" then
        if vim.islist(val) then
            if lang_spec.symbols.tbl then
                return string.len(lang_spec.symbols.lst)
            else
                return 2
            end
        else
            if lang_spec.symbols.tbl then
                return string.len(lang_spec.symbols.lst)
            else
                return 2
            end
        end
    end
end

---Builds the top or bottom of a graph unit.
---@param top boolean
---@param max_len_left integer
---@param first boolean | nil
---@param origin Vec2 | nil
---@param obj table | nil
---@param key_set any[] | nil
---@return TextLine
---@param lang_spec LangSpec
M.BuildBoxCap = function(top, max_len_left, first, origin, obj, key_set, lang_spec)
    local left
    local right
    local splitter
    local callbacks

    if top then
        if first then
            left = edges.edge.TOP_LEFT_ROOT
            callbacks = { {
                M.config.keymaps.link_backward,
                function(opts)
                    M.RenderGraph(opts.obj, opts.editor_buf, { opts.editor_buf }, lang_spec)
                    M.CursorToRoot()
                end,
                "View full graph",
                M.config.keymap_priorities.link_backward,
            } }
        else
            left = edges.edge.TOP_LEFT
            callbacks = {
                {
                    M.config.keymaps.link_backward,
                    function(opts)
                        ---@diagnostic disable-next-line: need-check-nil
                        M.JumpToLink(origin[1], origin[2], opts.render_info, true)
                    end,
                    "Jump to parent unit",
                    M.config.keymap_priorities.link_backward,
                },
                {
                    M.config.keymaps.set_as_root,
                    function(opts)
                        ---@diagnostic disable-next-line: param-type-mismatch
                        M.RenderGraph(obj, opts.editor_buf, key_set, lang_spec)
                        M.CursorToRoot()
                    end,
                    "Set unit as root",
                    M.config.keymap_priorities.set_as_root,
                }
            }
        end

        right = edges.edge.TOP_RIGHT
        splitter = edges.edge.TOP_SPLITTER
    else
        left = edges.edge.BOTTOM_LEFT
        right = edges.edge.BOTTOM_RIGHT
        splitter = edges.edge.BOTTOM_SPLITTER
    end

    return {
        left .. string.rep(edges.edge.TOP_AND_BOTTOM, max_len_left) .. splitter,
        edges.edge.TOP_AND_BOTTOM,
        right,
        callbacks
    }
end

---Determines if the unit specified by the key_set
---is expanded or not.
---@param key_set any[]
---@param dict table | nil
---@return boolean | nil
M.IsExpanded = function(key_set, dict)
    if dict == nil then
        dict = M.expanded
    end

    for idx, key in pairs(key_set) do
        if dict[key] == nil then
            return nil
        end

        dict = dict[key]

        if idx == #key_set then
            return dict[0]
        end
    end

    return false
end

---Register the unit specified by the key_set as expanded true
---or expanded false.
---@param key_set any[]
---@param val boolean
---@param dict table | nil
M.SetExpanded = function(key_set, val, dict)
    if dict == nil then
        dict = M.expanded
    end

    for idx, key in pairs(key_set) do
        if dict[key] == nil then
            dict[key] = {}
        end

        dict = dict[key]

        if idx == #key_set then
            dict[0] = val
        end
    end
end

---Jumps the cursor to a graph location.
---@param layer integer
---@param row integer
---@param render_info table
---@param jump_to_word boolean
M.JumpToLink = function(layer, row, render_info, jump_to_word)
    local col = render_info.row_unit_breaks[row][layer]
    vim.api.nvim_win_set_cursor(0, { row + 1, col.start })

    if jump_to_word then
        vim.cmd("call search('\\S')")
    end
end

---Creates a text table representation of an object
---with callbacks and returns the top line number.
---OUTPUT WILL BE SENT TO OUT TABLE
---@param obj table
---@param out_table table
---@param layer_idx integer
---@param key_set any[]
---@param from_row integer | nil
---@return integer
---@param lang_spec LangSpec
M.TableObject = function(obj, out_table, layer_idx, key_set, from_row, lang_spec)
    if out_table[layer_idx] == nil then
        out_table[layer_idx] = { lines = 0, width = 0, boxes = {} }
    end

    local layer = out_table[layer_idx]

    local max_len_left = 0
    local max_len_right = 2
    local text_lines = {}
    local connections = {}

    for key, val in pairs(obj) do
        max_len_left = math.max(max_len_left, M.GetLenOfValue(key, lang_spec))
        max_len_right = math.max(max_len_right, M.GetLenOfValue(val, lang_spec))
    end

    layer.width = math.max(layer.width, max_len_left + max_len_right + 3)
    text_lines[#text_lines + 1] = M.BuildBoxCap(
        true,
        max_len_left,
        layer_idx == 1,
        { layer_idx - 1, from_row },
        obj,
        key_set,
        lang_spec
    )

    local line = 1
    for key, val in pairs(obj) do
        local left_edge = edges.edge.LEFT_AND_RIGHT
        if line == M.config.max_lines + 1 then
            left_edge = "╪"
        end

        if line > M.config.max_lines and (not M.IsExpanded(key_set)) then
            text_lines[#text_lines + 1] = {
                left_edge,
                ".",
                edges.edge.LEFT_AND_RIGHT,
                {
                    {
                        M.config.keymaps.expand,
                        function(opts)
                            M.SetExpanded(key_set, true)
                            M.RenderGraph(opts.render_info.shown_obj, opts.editor_buf, opts.render_info.shown_key_set,
                                lang_spec)
                        end,
                        "Expand unit",
                        M.config.keymap_priorities.expand,
                    }
                }
            }
            break
        else
            line = line + 1

            local collapse_callback
            if line > M.config.max_lines + 1 then
                collapse_callback = {
                    M.config.keymaps.collapse,
                    function(opts)
                        M.SetExpanded(key_set, false)
                        M.RenderGraph(opts.render_info.shown_obj, opts.editor_buf, opts.render_info.shown_key_set,
                            lang_spec)
                    end,
                    "Collapse unit",
                    M.config.keymap_priorities.collapse,
                }
            end

            local string_key = M.GetValAsString(key, true, lang_spec)
            local left = left_edge ..
                string.rep(" ", max_len_left - #string_key) .. string_key .. edges.edge.LEFT_AND_RIGHT
            local right = M.GetValAsString(val, false, lang_spec)

            if right == "{}" or right == "[]" then
                local from = layer.lines + #text_lines + 1
                local to = M.TableObject(val, out_table, layer_idx + 1, utils.appended_table(key_set, key), from,
                    lang_spec)
                text_lines[#text_lines + 1] = {
                    left, "·", right .. edges.edge.CONNECTION,
                    {
                        {
                            M.config.keymaps.link_forward,
                            function(opts)
                                M.JumpToLink(layer_idx + 1, to, opts.render_info, false)
                            end,
                            "Jump to linked unit",
                            M.config.keymap_priorities.link_forward,
                        },
                        collapse_callback
                    }
                }

                connections[#connections + 1] = {
                    from = from,
                    to = to
                }
            else
                text_lines[#text_lines + 1] = { left, "·", right .. edges.edge.LEFT_AND_RIGHT, { collapse_callback } }
            end
        end
    end

    text_lines[#text_lines + 1] = M.BuildBoxCap(false, max_len_left, nil, nil, nil, nil, lang_spec)

    layer.boxes[#layer.boxes + 1] = { connections = connections, text_lines = text_lines, top_line = layer.lines + 1 }
    layer.lines = layer.lines + #text_lines
    return layer.boxes[#layer.boxes].top_line
end

---Apply highlighting to current buffer
---@param lang_spec LangSpec
M.ApplyHighlighting = function(lang_spec)
    vim.cmd([[highlight GraphViewOperator guifg=#009900]])
    vim.api.nvim_set_hl(0, "JsonViewStatusline", { bg = "#1e1e2e", fg = "#ffffff", bold = true })
    vim.api.nvim_set_hl(0, "JsonViewUnitHighlight", { link = "GraphViewOperator" })

    vim.cmd([[syntax match Special /\\[\\\"'abfnrtv]/ containedin=String]])
    vim.cmd([[syntax region String start=+"+ skip=+\\\\\\|\\"+ end=+"+ contains=StringEscape,@Spell]])

    vim.cmd([[syn match Identifier /│\s*\zs\w\+\ze\s*│/ contains=@Spell]])
    vim.cmd([[syn match Identifier /╪\s*\zs\w\+\ze\s*│/ contains=@Spell]])
    vim.cmd("syn keyword Keyword null")
    vim.cmd("syn match GraphViewOperator \"[{}\\[\\]]\"")
    vim.cmd("syn match GraphViewOperator \"\\.\"")
    vim.cmd([[syn match Comment "·"]])
    vim.cmd("syn keyword Boolean true false")
    vim.cmd("syn match Number \"[-+]\\=\\%(0\\|[1-9]\\d*\\)\\%(\\.\\d*\\)\\=\\%([eE][-+]\\=\\d\\+\\)\\=\"")
    vim.cmd("syn match Number \"[-+]\\=\\%(\\.\\d\\+\\)\\%([eE][-+]\\=\\d\\+\\)\\=\"")
    vim.cmd("syn match Number \"[-+]\\=0[xX]\\x*\"")
    vim.cmd("syn match Number \"[-+]\\=Infinity\\|NaN\"")

    if lang_spec.highlight then
        lang_spec.highlight()
    end
end

---Build connections for the given layer
---@param connections {from: integer, to:integer}[]
---@param grid_height integer
---@return TextLine[]
M.BuildConnectionsForLayer = function(connections, grid_height)
    local grid = {}
    local grid_cols = 0

    local function add_col_to_grid()
        grid_cols = grid_cols + 1
        for i = 1, grid_height do
            if grid[i] == nil then
                grid[i] = {}
            end

            grid[i][grid_cols] = " "
        end
    end

    local up_cons = {}
    local down_cons = {}
    local flat_cons = {}
    for _, con in pairs(connections) do
        if con.from < con.to then
            down_cons[#down_cons + 1] = con
        elseif con.from > con.to then
            up_cons[#up_cons + 1] = con
        else
            flat_cons[#flat_cons + 1] = con
        end
    end

    for _ = 1, math.max(#up_cons, #down_cons) + 2 do
        add_col_to_grid()
    end

    for _, con in pairs(flat_cons) do
        local col = 1
        while col <= grid_cols do
            grid[con.from][col] = edges.line.SIDE
            col = col + 1
        end
    end

    for i = #down_cons, 1, -1 do
        local con = down_cons[i]
        local row = con.from
        local col = 1
        local target = con.to

        local last_was_right = true
        while row ~= target or col ~= grid_cols + 1 do
            local new_is_right
            local new_row
            local new_col

            if row < target
                and grid[row + 1][col] == " "
            then
                new_row = row + 1
                new_col = col
                new_is_right = false
            else
                new_col = col + 1
                new_row = row
                new_is_right = true
            end

            local char
            if last_was_right and new_is_right then
                if grid[row][col] == edges.line.UP_DOWN then
                    char = edges.line.CROSS
                else
                    char = edges.line.SIDE
                end
            elseif last_was_right and (not new_is_right) then
                char = edges.line.TURN_DOWN
            elseif (not last_was_right) and new_is_right then
                char = edges.line.TURN_SIDE_FD
            else
                if grid[row][col] == edges.line.SIDE then
                    char = edges.line.CROSS
                else
                    char = edges.line.UP_DOWN
                end
            end

            grid[row][col] = char
            last_was_right = new_is_right
            row = new_row
            col = new_col
        end
    end

    for i = 1, #up_cons do
        local con = up_cons[i]
        local row = con.from
        local col = 1
        local target = con.to

        local last_was_right = true
        while row ~= target or col ~= grid_cols + 1 do
            local new_is_right
            local new_row
            local new_col


            if row > target
                and grid[row - 1][col] == " "
            then
                new_row = row - 1
                new_col = col
                new_is_right = false
            else
                new_col = col + 1
                new_row = row
                new_is_right = true
            end

            local char
            if last_was_right and new_is_right then
                if grid[row][col] == edges.line.UP_DOWN then
                    char = edges.line.CROSS
                else
                    char = edges.line.SIDE
                end
            elseif last_was_right and (not new_is_right) then
                char = edges.line.TURN_UP
            elseif (not last_was_right) and new_is_right then
                char = edges.line.TURN_SIDE_FU
            else
                if grid[row][col] == edges.line.SIDE then
                    char = edges.line.CROSS
                else
                    char = edges.line.UP_DOWN
                end
            end


            grid[row][col] = char
            last_was_right = new_is_right
            row = new_row
            col = new_col
        end
    end

    return grid
end

---Builds the connections for a text graph
---@param output_table table
---@return table
M.BuildConnections = function(output_table)
    local connections = {}

    local layer_grid_height = 0
    for _, layer in pairs(output_table) do
        layer_grid_height = math.max(layer_grid_height, layer.lines)
    end

    for layer_id, layer in pairs(output_table) do
        local layer_connections = {}
        for _, box in pairs(layer.boxes) do
            for _, connection in pairs(box.connections) do
                layer_connections[#layer_connections + 1] = connection
            end
        end

        connections[layer_id] = M.BuildConnectionsForLayer(layer_connections, layer_grid_height)
    end

    return connections
end

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
        row_unit_breaks = {}
    }

    M.TableObject(obj, text_output_table, 1, key_set, nil, lang_spec)
    local connections = M.BuildConnections(text_output_table)

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
    M.ApplyHighlighting(lang_spec)

    vim.api.nvim_buf_set_option(editor_buf, 'modifiable', false)

    M.render_info[editor_buf] = render_info
end

---Creates a window split. Returns the buffer for the window
---and a callback to update the status line.
---@return integer
---@return function
M.SplitView = function()
    local win = vim.api.nvim_get_current_win()
    local total_width = vim.api.nvim_win_get_width(win)
    local editor_buf = vim.api.nvim_create_buf(false, true)
    local new_win
    local target_width

    if M.config.editor_type == "split" then
        -- Save and override splitright
        local original_splitright = vim.opt.splitright
        vim.opt.splitright = true
        vim.cmd('vsplit')
        vim.opt.splitright = original_splitright

        new_win = vim.api.nvim_get_current_win()
        target_width = total_width - 20
        vim.api.nvim_win_set_width(new_win, target_width)
    else
        local sub = 2
        if M.config.floating_editor_style.border == "shadow" then
            sub = 1
        end

        if M.config.floating_editor_style.border == nil then
            sub = 0
        end

        local target_height =
            vim.api.nvim_win_get_height(win)
            - M.config.floating_editor_style.margin * 2
            - sub

        target_width = total_width
            - M.config.floating_editor_style.margin * 2
            - sub

        new_win = vim.api.nvim_open_win(editor_buf, false, {
            relative = "win",
            row = M.config.floating_editor_style.margin,
            col = M.config.floating_editor_style.margin / 2,
            width = target_width,
            height = target_height,
            anchor = "NW",
            border = M.config.floating_editor_style.border,
            zindex = M.config.floating_editor_style.zindex,
        })

        vim.api.nvim_set_current_win(new_win)
    end

    vim.api.nvim_win_set_buf(new_win, editor_buf)
    vim.api.nvim_win_set_option(new_win, 'number', false)
    vim.api.nvim_win_set_option(new_win, 'relativenumber', false)
    vim.api.nvim_buf_set_option(editor_buf, "filetype", consts.plugin_name)
    vim.api.nvim_buf_set_option(editor_buf, "cursorline", false)

    if M.config.disable_line_wrap then
        vim.api.nvim_buf_set_option(editor_buf, "wrap", false)
    end

    -- Floating statusline setup
    local status_buf = vim.api.nvim_create_buf(false, true)
    local function update_statusline(text)
        vim.api.nvim_buf_set_lines(status_buf, 0, -1, false, { text })
    end
    update_statusline("[JSON VIEW]")

    local status_win = vim.api.nvim_open_win(status_buf, false, {
        relative = "win",
        win = new_win,
        row = 0,
        col = 0,
        width = target_width,
        height = 1,
        anchor = "NW",
        style = "minimal",
        focusable = false,
        noautocmd = true,
        zindex = 50,
    })
    vim.api.nvim_win_set_option(status_win, "winhl", "Normal:JsonViewStatusline")

    -- Cleanup autocommands
    local augroup = vim.api.nvim_create_augroup("JsonViewStatus", { clear = false })

    vim.api.nvim_create_autocmd({ "WinClosed" }, {
        group = augroup,
        callback = function(args)
            local closed_win = tonumber(args.match)
            if closed_win == new_win and vim.api.nvim_win_is_valid(status_win) then
                vim.api.nvim_win_close(status_win, true)
            end
        end
    })

    vim.api.nvim_create_autocmd({ "BufWipeout", "BufHidden" }, {
        group = augroup,
        buffer = editor_buf,
        callback = function()
            if vim.api.nvim_win_is_valid(status_win) then
                vim.api.nvim_win_close(status_win, true)
            end
        end
    })

    vim.keymap.set(
        "n",
        M.config.keymaps.close_window,
        "<CMD>q<CR>",
        { buffer = true, noremap = true, silent = true }
    )


    return editor_buf, update_statusline
end

---Cursor moved autocommand
---@param editor_buf integer
---@param obj table
---@param file string
---@param file_buf integer
---@param update_statusline function
M.CursorMoved = function(editor_buf, obj, file, file_buf, update_statusline)
    local pos = vim.api.nvim_win_get_cursor(0)
    if pos[1] == 1 then
        vim.api.nvim_win_set_cursor(0, { 2, pos[2] })
        pos[1] = 2
    end

    for _, k in pairs(M.config.keymaps) do
        if k ~= M.config.keymaps.close_window then
            vim.keymap.set("n", k, function()
                vim.notify(k .. " is not valid at this location", "WARN")
            end, { buffer = true })
        end
    end

    local callback_keys = {}
    local enter_map
    local call_opts = {
        editor_buf = editor_buf,
        obj = obj,
        file = file,
        file_buf = file_buf,
        render_info = M.render_info[editor_buf],
    }

    local row_col_info = M.render_info[editor_buf].row_unit_breaks[pos[1] - 1]
    vim.api.nvim_buf_clear_namespace(0, -1, 0, -1)
    for col_idx, col in pairs(row_col_info) do
        if not col.empty then
            if pos[2] >= col.start and pos[2] < col.start + col.width then
                for row_idx = col.box.top_line, col.box.top_line + #col.box.text_lines - 1 do
                    row_col_info = M.render_info[editor_buf].row_unit_breaks[row_idx][col_idx]
                    if
                        row_idx == col.box.top_line
                        or row_idx == col.box.top_line + #col.box.text_lines - 1
                    then
                        vim.api.nvim_buf_add_highlight(0, -1, "JsonViewUnitHighlight", row_idx, row_col_info.start,
                            row_col_info.start + row_col_info.width)
                    else
                        vim.api.nvim_buf_add_highlight(0, -1, "JsonViewUnitHighlight", row_idx, row_col_info.start,
                            row_col_info.start + 1)

                        vim.api.nvim_buf_add_highlight(0, -1, "JsonViewUnitHighlight", row_idx,
                            row_col_info.start + row_col_info.width - 3,
                            row_col_info.start + row_col_info.width)
                    end
                end

                vim.api.nvim_buf_add_highlight(0, -1, "CursorLine", pos[1] - 1, col.start, col.start + col.width)
            end
        end
    end

    for start, callback_set in pairs(M.render_info[editor_buf].line_callbacks[pos[1] - 1]) do
        if pos[2] >= start then
            for _, callback in pairs(callback_set) do
                if pos[2] < start + callback.limit then
                    if enter_map == nil or enter_map[4] < callback[4] then
                        enter_map = callback
                    end

                    local fn = function()
                        callback[2](call_opts)
                    end

                    callback_keys[callback[1]] = { fn, callback[3], callback[4] }
                    vim.keymap.set("n", callback[1], fn, { buffer = true })
                end
            end
        end
    end

    table.sort(callback_keys, function(a, b) return a[3] >= b[3] end)

    local statusline_text = consts.plugin_name .. " (" .. M.config.keymaps.close_window .. "=Close Window)"

    if enter_map then
        vim.keymap.set("n", M.config.keymaps.quick_action, function()
            enter_map[2](call_opts)
        end, { buffer = true })
        statusline_text = statusline_text .. " (" .. M.config.keymaps.quick_action .. "=" .. enter_map[1] .. ")"
    else
        vim.keymap.set("n", M.config.keymaps.quick_action, function()
            vim.notify(M.config.keymaps.quick_action .. " is not valid at this location", "WARN")
        end, { buffer = true })
    end

    for k, h in pairs(callback_keys) do
        statusline_text = statusline_text .. " (" .. k .. "=" .. h[2] .. ")"
    end

    update_statusline(statusline_text)
end

---Moves the cursor to the first unit
M.CursorToRoot = function()
    vim.api.nvim_win_set_cursor(0, { 3, 3 })
end

---Shows the JsonGraphView window
---@param file_buf integer
---@param obj table
---@param file string
---@param lang_spec LangSpec
M.ShowJsonWindow = function(file_buf, obj, file, lang_spec)
    local editor_buf, update_statusline = M.SplitView();
    vim.api.nvim_win_set_buf(0, editor_buf)
    M.RenderGraph(obj, editor_buf, { editor_buf }, lang_spec)
    M.CursorToRoot()

    vim.api.nvim_create_autocmd({ "CursorMoved" }, {
        buffer = editor_buf,
        callback = function() M.CursorMoved(editor_buf, obj, file, file_buf, update_statusline) end,
    })
end

---Opens the JsonGraphView on the specified buffer
---@param bufn integer
---@param filetype string
M.OpenJsonViewOnBuf = function(bufn, filetype)
    local lang = langs.get(filetype)

    vim.print(lang)
    if lang ~= nil then
        local lines = vim.api.nvim_buf_get_lines(bufn, 0, -1, false)
        local text = table.concat(lines, "\n")
        local is_valid, lua_table = pcall(lang.decode, text)

        if not is_valid then
            vim.notify("Error parsing " .. filetype .. " text:\n" .. lua_table)
            return
        end

        M.ShowJsonWindow(bufn, lua_table, vim.api.nvim_buf_get_name(0), lang)
    end
end

---Opens the JsonGraphView on the current buffer
M.OpenJsonView = function()
    local bufn = vim.api.nvim_buf_get_number(0)
    M.OpenJsonViewOnBuf(bufn, vim.bo.filetype)
end

vim.api.nvim_create_user_command(consts.plugin_name, M.OpenJsonView, {})

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
