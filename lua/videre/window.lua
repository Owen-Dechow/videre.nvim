local config = require("videre.config").config

local M = {}

local function close_window_when_buffer_closes(buf, win)
    vim.api.nvim_create_autocmd("BufWipeout", {
        buffer = buf,
        callback = function()
            if vim.api.nvim_win_is_valid(win) then
                vim.api.nvim_win_close(win, true)
            end
        end,
    })
end

function M.OpenWindowWithBuffer(buf)
    local win

    if config.editor_type == "floating" then
        local style = config.floating_editor_style

        local width = vim.o.columns - 2 - style.margin * 2
        local height = vim.o.lines - 3 - style.margin * 2

        local opts = {
            relative = "editor",
            width = width,
            height = height,
            col = style.margin,
            row = style.margin,
            style = "minimal",
            border = style.border,
            zindex = style.zindex,
        }

        win = vim.api.nvim_open_win(buf, true, opts)
    else
        local style = config.split_editor_style

        if style.side == "right" then
            vim.cmd("rightbelow vsplit")
        elseif style.side == "left" then
            vim.cmd("leftabove vsplit")
        else
            vim.cmd("vsplit")
        end

        win = vim.api.nvim_get_current_win()

        local width = math.floor(vim.o.columns * style.fill_percentage)
        vim.api.nvim_win_set_width(win, width)
        vim.api.nvim_win_set_buf(win, buf)
    end

    vim.wo[win].winfixbuf = true
    vim.wo[win].cursorline = false
    close_window_when_buffer_closes(buf, win)

    vim.api.nvim_set_option_value("number", false, { win = win })
    vim.api.nvim_set_option_value("relativenumber", false, { win = win })
    vim.api.nvim_set_option_value("signcolumn", "no", { win = win })
    vim.api.nvim_set_option_value("statuscolumn", "", { win = win })
    vim.api.nvim_set_option_value("scrolloff", config.scrolloff, { win = win })
    vim.api.nvim_set_option_value("sidescrolloff", config.sidescrolloff, { win = win })
    vim.api.nvim_set_option_value("wrap", false, { win = win })

    return win
end

return M
