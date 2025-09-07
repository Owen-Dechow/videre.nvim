local edges = require("videre.edges")
local utils = require("videre.utils")
local cfg = utils.cfg

local M = {}

local function get_back_callback(first, lang_spec, origin)
    if first then
        return {
            cfg().keymaps.link_backward,
            function(opts)
                require("videre.rendering").RenderGraph(opts.obj, opts.editor_buf, { opts.editor_buf }, lang_spec)
                require("videre.link_jumping").CursorToRoot()
            end,
            "View full graph",
            cfg().keymap_priorities.link_backward,
        }
    else
        return {
            cfg().keymaps.link_backward,
            function(opts)
                ---@diagnostic disable-next-line: need-check-nil
                require("videre.link_jumping").JumpToLink(origin[1], origin[2], opts.render_info, true)
            end,
            "Jump to parent unit",
            cfg().keymap_priorities.link_backward,
        }
    end
end

local function get_collapsed_line(left_edge, key_set, lang_spec)
    return {
        left_edge,
        ".",
        edges.edge.LEFT_AND_RIGHT,
        {
            {
                cfg().keymaps.expand,
                function(opts)
                    require("videre.expanding").SetExpanded(key_set, true)
                    require("videre.rendering").RenderGraph(opts.render_info.shown_obj, opts.editor_buf,
                        opts.render_info.shown_key_set,
                        lang_spec)
                end,
                "Expand unit",
                cfg().keymap_priorities.expand,
            }
        }
    }
end

local function get_vertical_jump_callbacks(layer_idx, box_idx)
    local link_jumping = require("videre.link_jumping")
    return {
        cfg().keymaps.link_down,
        function(opts)
            link_jumping.JumpVertical(layer_idx, box_idx + 1, opts.render_info)
        end,
        "Jump down one unit",
        cfg().keymap_priorities.link_down,
        predicate = link_jumping.GetJumpVerticalPredicate(layer_idx, box_idx + 1)
    }, {
        cfg().keymaps.link_up,
        function(opts)
            link_jumping.JumpVertical(layer_idx, box_idx - 1, opts.render_info)
        end,
        "Jump up one unit",
        cfg().keymap_priorities.link_up,
        predicate = link_jumping.GetJumpVerticalPredicate(layer_idx, box_idx - 1)
    }
end

local function get_collapse_callback(line, key_set, lang_spec)
    if line < cfg().max_lines then
        return nil
    end

    return {
        cfg().keymaps.collapse,
        function(opts)
            require("videre.expanding").SetExpanded(key_set, false)
            require("videre.rendering").RenderGraph(opts.render_info.shown_obj, opts.editor_buf,
                opts.render_info.shown_key_set,
                lang_spec)
        end,
        "Collapse unit",
        cfg().keymap_priorities.collapse,
    }
end

local function get_change_val_callback(key_set, key, val, lang_spec)
    return {
        cfg().keymaps.change_value,
        function(opts)
            if not lang_spec.encode then
                vim.notify(lang_spec.name .. " is not available for editing.", "WARN")
                return
            end

            local initial

            if type(val) == "string" then
                initial = '"' .. val .. '"'
            elseif val == vim.NIL then
                initial = "null"
            else
                initial = val
            end

            local new
            if initial == nil then
                new = vim.fn.input("Value str/num or [null/true/false/[]/{}]: ")
            else
                new = vim.fn.input("Enter new value str/num or [null/true/false/[]/{}]: ", initial)
            end

            if not new or new == "" then
                return
            end

            if new:sub(1, 1) == '"' and new:sub(-1) == '"' then
                new = new:sub(2, -2)
            elseif new == "true" then
                new = true
            elseif new == "false" then
                new = false
            elseif new == "null" then
                new = vim.NIL
            elseif new == "{}" then
                new = vim.empty_dict()
            elseif new == "[]" then
                new = {}
            else
                local num = tonumber(new)

                if not num then
                    vim.notify(
                        "`" ..
                        new ..
                        "` is not a valid value. " ..
                        "Try wrapping in \" for strings or entering null/true/false/{}/[]. " ..
                        "You may also enter any valid number." ..
                        "WARN")
                    return
                end

                new = num
            end

            local tbl = opts.render_info.shown_obj
            local first = true

            for _, k in pairs(key_set) do
                if first then
                    first = false
                else
                    tbl = tbl[k]
                end
            end

            tbl[key] = new

            require("videre.rendering").RenderGraph(
                opts.render_info.shown_obj,
                opts.editor_buf,
                opts.render_info.shown_key_set,
                lang_spec
            )

            return true
        end,
        "Change value of field",
        0,
        modifying = true
    }
end

local function get_add_callback(key_set, key, lang_spec)
    return {
        cfg().keymaps.add_field,
        function(opts)
            if not lang_spec.encode then
                vim.notify(lang_spec.name .. " is not available for editing.", "WARN")
                return
            end

            if type(key) == "number" then
                key = key + 1
            else
                key = vim.fn.input("Enter key: ")
            end

            local val = vim.NIL

            local tbl = opts.render_info.shown_obj
            local first = true

            for _, k in pairs(key_set) do
                if first then
                    first = false
                else
                    tbl = tbl[k]
                end
            end

            if type(key) == "number" then
                table.insert(tbl, key, val)
            else
                if tbl[key] then
                    vim.notify("This unit already has the key `" .. key .. "`.", "WARN")
                    return
                end

                tbl[key] = val
            end


            local success = get_change_val_callback(key_set, key, nil, lang_spec)[2](opts)
            if not success then
                tbl[key] = nil
            end
        end,
        "Add field",
        0,
        modifying = true
    }
end

local function get_delete_callback(key_set, key, lang_spec)
    return {
        cfg().keymaps.delete_field,
        function(opts)
            if not lang_spec.encode then
                vim.notify(lang_spec.name .. " is not available for editing.", "WARN")
                return
            end

            local new = vim.fn.input("Are you sure you want to delete `" .. key .. "` [y/n]: ")

            if new ~= "y" and new ~= "yes" then
                return
            end

            local tbl = opts.render_info.shown_obj
            local first = true

            for _, k in pairs(key_set) do
                if first then
                    first = false
                else
                    tbl = tbl[k]
                end
            end

            if type(key) == "number" then
                table.remove(tbl, key)
            else
                tbl[key] = nil
            end

            require("videre.rendering").RenderGraph(
                opts.render_info.shown_obj,
                opts.editor_buf,
                opts.render_info.shown_key_set,
                lang_spec
            )
        end,
        "Delete field",
        0,
        modifying = true
    }
end


local function get_change_key_callback(key_set, key, lang_spec)
    if type(key) == "number" then
        return
    end

    return {
        cfg().keymaps.change_key,
        function(opts)
            if not lang_spec.encode then
                vim.notify(lang_spec.name .. " is not available for editing.", "WARN")
                return
            end

            local new = vim.fn.input("Enter new key: ", key)

            if not new or new == "" then
                return
            end

            local tbl = opts.render_info.shown_obj
            local first = true

            for _, k in pairs(key_set) do
                if first then
                    first = false
                else
                    tbl = tbl[k]
                end
            end

            if tbl[new] then
                vim.notify("This unit already has the key `" .. new .. "`.", "WARN")
                return
            end

            tbl[new] = tbl[key]
            tbl[key] = nil

            require("videre.rendering").RenderGraph(
                opts.render_info.shown_obj,
                opts.editor_buf,
                opts.render_info.shown_key_set,
                lang_spec
            )
        end,
        "Change key of field",
        0,
        modifying = true,
    }
end

local function set_connectable_text_line(
    line,
    key_set,
    lang_spec,
    key,
    left_edge,
    max_len_left,
    val,
    text_lines,
    layer,
    out_table,
    layer_idx,
    connections,
    origin,
    first,
    box_idx
)
    local collapse_callback = get_collapse_callback(line, key_set, lang_spec)
    local back_callback = get_back_callback(first, lang_spec, origin)
    local jump_down_callback, jump_up_callback = get_vertical_jump_callbacks(layer_idx, box_idx)
    local change_key_callback = get_change_key_callback(key_set, key, lang_spec)
    local change_val_callback = get_change_val_callback(key_set, key, val, lang_spec)
    local delete_callback = get_delete_callback(key_set, key, lang_spec)
    local add_callback = get_add_callback(key_set, key, lang_spec)

    local string_key = require("videre.converters").GetValAsString(key, true, lang_spec)
    local left = left_edge
        .. string.rep(" ", max_len_left - #string_key)
        .. string_key
        .. edges.edge.LEFT_AND_RIGHT

    local right = require("videre.converters").GetValAsString(val, false, lang_spec)

    if right == "{}" or right == "[]" then
        local from = layer.lines + #text_lines + 1
        local to = M.TableObject(val, out_table, layer_idx + 1, utils.appended_table(key_set, key), from,
            lang_spec)
        text_lines[#text_lines + 1] = {
            left, cfg().space_char, right .. edges.edge.CONNECTION,
            {
                {
                    cfg().keymaps.link_forward,
                    function(opts)
                        require("videre.link_jumping").JumpToLink(layer_idx + 1, to, opts.render_info, false)
                    end,
                    "Jump to linked unit",
                    cfg().keymap_priorities.link_forward,
                },
                collapse_callback,
                back_callback,
                jump_down_callback,
                jump_up_callback,
                change_key_callback,
                delete_callback,
                add_callback,
            }
        }

        connections[#connections + 1] = {
            from = from,
            to = to
        }
    else
        text_lines[#text_lines + 1] = {
            left,
            cfg().space_char, right .. edges.edge.LEFT_AND_RIGHT,
            {
                collapse_callback,
                back_callback,
                jump_down_callback,
                jump_up_callback,
                change_key_callback,
                change_val_callback,
                delete_callback,
                add_callback,
            }
        }
    end
end

local function get_max_len(obj, lang_spec)
    local max_len_left = 0
    local max_len_right = 2

    for key, val in pairs(obj) do
        max_len_left = math.max(max_len_left, require("videre.converters").GetLenOfValue(key, lang_spec))
        max_len_right = math.max(max_len_right, require("videre.converters").GetLenOfValue(val, lang_spec))
    end

    return max_len_left, max_len_right
end

---Builds the top or bottom of a graph unit.
---@param top boolean
---@param max_len_left integer
---@param first boolean | nil
---@param origin Vec2 | nil
---@param obj table | nil
---@param key_set any[] | nil
---@param lang_spec LangSpec
---@param layer_idx integer
---@param unit_idx integer
---@return TextLine
local function build_cap(top, max_len_left, first, origin, obj, key_set, lang_spec, layer_idx, unit_idx)
    local left
    local right
    local splitter
    local callbacks

    local jump_down_callback, jump_up_callback = get_vertical_jump_callbacks(
        layer_idx, unit_idx)

    local key
    if vim.islist(obj) then
        if top then
            key = 0
        else
            key = #obj
        end
    else
        key = ""
    end

    local add_callback = get_add_callback(key_set, key, lang_spec)

    if top then
        if first then
            left = edges.edge.TOP_LEFT_ROOT
            callbacks = {
                get_back_callback(first, lang_spec, origin),
                jump_down_callback,
                jump_up_callback,
                add_callback,
            }
        else
            left = edges.edge.TOP_LEFT
            callbacks = {
                get_back_callback(first, lang_spec, origin),
                {
                    cfg().keymaps.set_as_root,
                    function(opts)
                        ---@diagnostic disable-next-line: param-type-mismatch
                        require("videre.rendering").RenderGraph(obj, opts.editor_buf, key_set, lang_spec)
                        require("videre.link_jumping").CursorToRoot()
                    end,
                    "Set unit as root",
                    cfg().keymap_priorities.set_as_root,
                },
                jump_down_callback,
                jump_up_callback,
                add_callback,
            }
        end

        right = edges.edge.TOP_RIGHT
        splitter = edges.edge.TOP_SPLITTER
    else
        left = edges.edge.BOTTOM_LEFT
        right = edges.edge.BOTTOM_RIGHT
        splitter = edges.edge.BOTTOM_SPLITTER
        callbacks = {
            get_back_callback(first, lang_spec, origin),
            jump_down_callback,
            jump_up_callback,
            add_callback,
        }
    end

    return {
        left .. string.rep(edges.edge.TOP_AND_BOTTOM, max_len_left) .. splitter,
        edges.edge.TOP_AND_BOTTOM,
        right,
        callbacks
    }
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
    local box_idx = #layer.boxes + 1

    local max_len_left, max_len_right = get_max_len(obj, lang_spec)
    local text_lines = {}
    local connections = {}

    layer.width = math.max(layer.width, max_len_left + max_len_right + 3)

    text_lines[#text_lines + 1] = build_cap(
        true,
        max_len_left,
        layer_idx == 1,
        { layer_idx - 1, from_row },
        obj,
        key_set,
        lang_spec,
        layer_idx,
        box_idx
    )

    local line = 1
    for key, val in pairs(obj) do
        local left_edge = edges.edge.LEFT_AND_RIGHT
        if line == cfg().max_lines + 1 then
            left_edge = "╪"
        end

        if line > cfg().max_lines and (not require("videre.expanding").IsExpanded(key_set)) then
            text_lines[#text_lines + 1] = get_collapsed_line(left_edge, key_set, lang_spec)
            break
        else
            line = line + 1
            set_connectable_text_line(
                line,
                key_set,
                lang_spec,
                key,
                left_edge,
                max_len_left,
                val,
                text_lines,
                layer,
                out_table,
                layer_idx,
                connections,
                { layer_idx - 1, from_row },
                layer_idx == 1,
                box_idx
            )
        end
    end

    text_lines[#text_lines + 1] = build_cap(
        false,
        max_len_left,
        layer_idx == 1,
        { layer_idx - 1, from_row },
        obj,
        key_set,
        lang_spec,
        layer_idx,
        box_idx
    )

    layer.boxes[#layer.boxes + 1] = {
        connections = connections,
        text_lines = text_lines,
        top_line = layer.lines + 1,
        key_set = key_set
    }

    layer.lines = layer.lines + #text_lines
    return layer.boxes[#layer.boxes].top_line
end

return M
