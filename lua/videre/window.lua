local consts = require("videre.consts")
local utils = require("videre.utils")
local cfg = utils.cfg

local M = {}

---Creates a window split. Returns the buffer for the window
---and a callback to update the status line.
---@return integer
---@return function
local function split_view()
    local win = vim.api.nvim_get_current_win()
    local total_width = vim.api.nvim_win_get_width(win)
    local editor_buf = vim.api.nvim_create_buf(false, true)
    local new_win
    local target_width

    if cfg().editor_type == "split" then
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
        if cfg().floating_editor_style.border == "shadow" then
            sub = 1
        end

        if cfg().floating_editor_style.border == nil then
            sub = 0
        end

        local target_height =
            vim.api.nvim_win_get_height(win)
            - cfg().floating_editor_style.margin * 2
            - sub

        target_width = total_width
            - cfg().floating_editor_style.margin * 2
            - sub

        new_win = vim.api.nvim_open_win(editor_buf, false, {
            relative = "win",
            row = cfg().floating_editor_style.margin,
            col = cfg().floating_editor_style.margin / 2,
            width = target_width,
            height = target_height,
            anchor = "NW",
            border = cfg().floating_editor_style.border,
            zindex = cfg().floating_editor_style.zindex,
        })

        vim.api.nvim_set_current_win(new_win)
    end

    vim.api.nvim_win_set_buf(new_win, editor_buf)
    vim.api.nvim_buf_set_option(editor_buf, 'sidescrolloff', cfg().side_scrolloff)
    vim.api.nvim_win_set_option(new_win, 'number', false)
    vim.api.nvim_win_set_option(new_win, 'relativenumber', false)
    vim.api.nvim_win_set_option(new_win, "colorcolumn", "")
    vim.api.nvim_buf_set_option(editor_buf, "filetype", consts.plugin_name)
    vim.api.nvim_buf_set_option(editor_buf, "cursorline", false)

    if cfg().disable_line_wrap then
        vim.api.nvim_buf_set_option(editor_buf, "wrap", false)
    end

    -- Floating statusline setup
    local function update_statusline(text)
        vim.api.nvim_buf_set_option(editor_buf, 'modifiable', true)
        vim.api.nvim_buf_set_lines(editor_buf, 0, 1, false, { text })
        vim.api.nvim_buf_set_option(editor_buf, 'modifiable', false)
    end
    update_statusline("[JSON VIEW]")

    utils.keymap(cfg().keymaps.close_window, "<CMD>q<CR>")
    utils.keymap(cfg().keymaps.help, require("videre.help").HelpMenu)

    return editor_buf, update_statusline
end

local function format_buf(file_bufnr, editor_buf)
    vim.api.nvim_set_current_buf(file_bufnr)
    pcall(function() vim.lsp.buf.format({ bufnr = file_bufnr }) end)
    vim.api.nvim_set_current_buf(editor_buf)
end

---Shows the Videre window
---@param file_buf integer
---@param obj table
---@param file string
---@param lang_spec LangSpec
M.ShowVidereWindow = function(file_buf, obj, file, lang_spec)
    local editor_buf, update_statusline = split_view();
    vim.api.nvim_win_set_buf(0, editor_buf)
    require("videre.rendering").RenderGraph(obj, editor_buf, { editor_buf }, lang_spec)
    require("videre.link_jumping").CursorToRoot()

    vim.api.nvim_create_autocmd({ "CursorMoved" }, {
        buffer = editor_buf,
        callback = function() require("videre.navigation").CursorMoved(editor_buf, obj, file, file_buf, update_statusline) end,
    })

    vim.api.nvim_buf_create_user_command(editor_buf, "VidereCommit", function()
        if lang_spec.encode then
            local text = lang_spec.encode(obj)
            vim.api.nvim_buf_set_lines(file_buf, 0, -1, false, { text })
            format_buf(file_buf, editor_buf)

            require("videre").has_edits[editor_buf] = false
        else
            vim.notify(lang_spec.name .. " is not a valid language for Videre editing.", "WARN")
        end

        vim.cmd([[doautocmd CursorMoved]])
    end, {})
end
return M
