local config = require("videre.config").config

local M = {}

local state = {
    parent = nil,
    hint_win = nil,
    input_win = nil,
    hint_buf = nil,
    input_buf = nil,
    callback = nil,
}

-- Local close function
local function close_all()
    vim.cmd("stopinsert")

    local wins = { state.hint_win, state.input_win, state.parent }
    for _, win in ipairs(wins) do
        if win and vim.api.nvim_win_is_valid(win) then
            vim.api.nvim_win_close(win, true)
        end
    end

    local bufs = { state.hint_buf, state.input_buf }
    for _, buf in ipairs(bufs) do
        if buf and vim.api.nvim_buf_is_valid(buf) then
            vim.api.nvim_buf_delete(buf, { force = true })
        end
    end

    state.parent = nil
    state.hint_win = nil
    state.input_win = nil
    state.hint_buf = nil
    state.input_buf = nil
    state.callback = nil
end

M.Close = close_all

---@param opts {hint:string[]|nil, default:string|nil, on_submit:fun(val: string)|nil, ft:string|nil}
function M.MakeEditFloat(opts)
    opts = opts or {}
    state.callback = opts.on_submit or function(_) end

    local hint_text = vim.deepcopy(opts.hint or { "Enter value:", })
    hint_text[# hint_text + 1] = string.rep("─", config.editor_window_width)

    local width = config.editor_window_width
    local height = #hint_text + 1

    -- Parent window (anchored to cursor)
    local parent_buf = vim.api.nvim_create_buf(false, true)
    state.parent = vim.api.nvim_open_win(parent_buf, false, {
        relative = "cursor",
        style = "minimal",
        border = "rounded",
        width = width,
        height = height,
        row = 1, -- below cursor
        col = 0, -- same column as cursor
        focusable = false,
    })

    -- Hint window
    state.hint_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(state.hint_buf, 0, -1, false, hint_text)
    vim.bo[state.hint_buf].modifiable = false

    vim.bo[state.hint_buf].filetype = opts.ft or ""
    vim.bo[state.hint_buf].syntax = opts.ft or ""

    state.hint_win = vim.api.nvim_open_win(state.hint_buf, false, {
        relative = "win",
        win = state.parent,
        row = 0,
        col = 1,
        width = width - 2,
        height = #hint_text,
        style = "minimal",
        border = "none",
        focusable = false,
    })

    -- Input window
    state.input_buf = vim.api.nvim_create_buf(false, true)
    vim.bo[state.input_buf].filetype = opts.ft or ""
    vim.bo[state.input_buf].syntax = opts.ft or ""
    vim.api.nvim_buf_set_lines(state.input_buf, 0, -1, false, { opts.default or "" })

    state.input_win = vim.api.nvim_open_win(state.input_buf, true, {
        relative = "win",
        win = state.parent,
        row = #hint_text,
        col = 1,
        width = width - 2,
        height = 1,
        style = "minimal",
        border = "none",
        focusable = false,
    })

    vim.wo[state.input_win].winhighlight = "jsonNoQuotesError:NONE"

    -- Keymaps
    vim.keymap.set("i", "<CR>", function()
        local line = vim.api.nvim_buf_get_lines(state.input_buf, 0, 1, false)[1] or ""
        line = line:gsub("^%s+", ""):gsub("%s+$", "")

        if #line > 0 then
            state.callback(line)
        end

        close_all()
    end, { buffer = state.input_buf, noremap = true })

    vim.keymap.set("i", "<Esc>", function()
        close_all()
    end, { buffer = state.input_buf, noremap = true })

    -- Prevent leaving the window
    vim.api.nvim_create_autocmd("WinLeave", {
        buffer = state.input_buf,
        callback = function()
            vim.schedule(function()
                if state.input_win and vim.api.nvim_win_is_valid(state.input_win) then
                    vim.api.nvim_set_current_win(state.input_win)
                end
            end)
        end,
    })

    vim.cmd("normal! $")
    vim.cmd("startinsert")
end

return M
