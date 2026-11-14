local config = require("videre.config").config

local M = {}

---@param opts {hint:string[]|nil, default:string|nil, on_submit:fun(val: string)|nil, ft:string|nil}
function M.MakeEditFloat(opts)
    opts = opts or {}
    local on_submit = opts.on_submit or function(_) end

    local prev_win = vim.api.nvim_get_current_win()

    local hint_text = vim.deepcopy(opts.hint or { "Enter value:" })
    hint_text[#hint_text + 1] = string.rep("─", config.editor_window_width)

    local width = config.editor_window_width
    local height = #hint_text + 1

    -- Parent window (anchored to cursor)
    local parent_buf = vim.api.nvim_create_buf(false, true)
    local parent_win = vim.api.nvim_open_win(parent_buf, false, {
        relative = "cursor",
        style = "minimal",
        border = "rounded",
        width = width,
        height = height,
        row = 1,
        col = 0,
        focusable = false,
    })

    -- Hint window
    local hint_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(hint_buf, 0, -1, false, hint_text)
    vim.bo[hint_buf].modifiable = false
    vim.bo[hint_buf].filetype = opts.ft or ""
    vim.bo[hint_buf].syntax = opts.ft or ""

    local hint_win = vim.api.nvim_open_win(hint_buf, false, {
        relative = "win",
        win = parent_win,
        row = 0,
        col = 1,
        width = width - 2,
        height = #hint_text,
        style = "minimal",
        border = "none",
        focusable = false,
    })

    -- Input window
    local input_buf = vim.api.nvim_create_buf(false, true)
    vim.bo[input_buf].filetype = opts.ft or ""
    vim.bo[input_buf].syntax = opts.ft or ""
    vim.api.nvim_buf_set_lines(input_buf, 0, -1, false, { opts.default or "" })

    local input_win = vim.api.nvim_open_win(input_buf, true, {
        relative = "win",
        win = parent_win,
        row = #hint_text,
        col = 1,
        width = width - 2,
        height = 1,
        style = "minimal",
        border = "none",
        focusable = false,
    })

    vim.wo[input_win].winhighlight = "jsonNoQuotesError:NONE"

    -- Per-instance teardown
    local closed = false
    local group = vim.api.nvim_create_augroup("VidereEditFloat" .. input_buf, { clear = true })

    local function close()
        if closed then return end
        closed = true

        vim.api.nvim_del_augroup_by_id(group)
        vim.cmd("stopinsert")

        for _, win in ipairs({ hint_win, input_win, parent_win }) do
            if vim.api.nvim_win_is_valid(win) then
                vim.api.nvim_win_close(win, true)
            end
        end

        for _, buf in ipairs({ hint_buf, input_buf, parent_buf }) do
            if vim.api.nvim_buf_is_valid(buf) then
                vim.api.nvim_buf_delete(buf, { force = true })
            end
        end

        -- Hand focus back to where the user was
        if vim.api.nvim_win_is_valid(prev_win) then
            vim.api.nvim_set_current_win(prev_win)
        end
    end

    local function submit()
        local line = vim.trim(vim.api.nvim_buf_get_lines(input_buf, 0, 1, false)[1] or "")
        -- Tear down first so the callback runs with the float gone
        close()
        if #line > 0 then
            on_submit(line)
        end
    end

    -- Keymaps (normal mode too, so the user can't get stuck after e.g. <C-o>)
    for _, mode in ipairs({ "i", "n" }) do
        vim.keymap.set(mode, "<CR>", submit, { buffer = input_buf, nowait = true })
        vim.keymap.set(mode, "<Esc>", close, { buffer = input_buf, nowait = true })
    end
    vim.keymap.set({ "i", "n" }, "<C-c>", close, { buffer = input_buf, nowait = true })

    -- Make the float modal: any attempt to leave bounces focus back
    vim.api.nvim_create_autocmd({ "WinLeave", "WinEnter" }, {
        group = group,
        callback = function()
            if closed then return end
            vim.schedule(function()
                if not closed and vim.api.nvim_win_is_valid(input_win)
                    and vim.api.nvim_get_current_win() ~= input_win
                then
                    vim.api.nvim_set_current_win(input_win)
                    vim.cmd("startinsert!")
                end
            end)
        end,
    })

    vim.cmd("normal! $")
    vim.cmd("startinsert")

    return close
end

return M
