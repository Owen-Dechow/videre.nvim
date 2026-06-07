local utils = require "videre.utils"
local config = require("videre.config").config
local M = {}

function M.OpenHelpMenu()
    local buf = vim.api.nvim_create_buf(false, true)
    local width = math.floor(vim.o.columns * 0.6)
    local height = math.floor(vim.o.lines * 0.5)
    local row = math.floor((vim.o.lines - height) / 2)
    local col = math.floor((vim.o.columns - width) / 2)

    local opts = {
        style = "minimal",
        relative = "editor",
        width = width,
        height = height,
        row = row,
        col = col,
        border = "rounded",
    }

    local win = vim.api.nvim_open_win(buf, true, opts)
    vim.wo.scrolloff = 0;

    local function C(text)
        local text_width = utils.StringWidth(text)
        local diff = width - text_width
        local pad = math.max(0, math.floor(diff / 2))
        return string.rep(" ", pad) .. text
    end

    local function CC(texta, textb)
        local target_width = 50
        local listing = '"' .. texta .. '" ' .. textb
        local listing_len = utils.StringWidth(listing)
        if listing_len < target_width then
            local diff = target_width - listing_len
            listing = '"' .. texta .. '" ' .. string.rep(config.value_space, diff) .. textb
        end

        return C(listing)
    end

    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
        "",
        C "Videre Nvim | Help",
        C('Press "<ESC>", "'
            .. config.keymaps.close_window
            .. '", or "'
            .. config.keymaps.help
            .. '" to close.'),
        "",
        CC(config.keymaps.close_window, "Close the Videre window."),
        CC(config.keymaps.help, "Open the help window."),
        -- CC(cfg().keymaps.quick_action, "Fire the highest priority action available."),
        CC(config.keymaps.collapse, "Collapse a cell."),
        CC(config.keymaps.expand, "Expand a cell."),
        CC(config.keymaps.jump_forward, "Jump to connected cell."),
        CC(config.keymaps.jump_back, "Jump to parent cell."),
        CC(config.keymaps.jump_up, "Jump up one cell."),
        CC(config.keymaps.jump_down, "Jump down one cell."),
        CC(config.keymaps.set_as_root, "Set cell as root cell."),
        CC(config.keymaps.add_value, "Add a field to the cell."),
        CC(config.keymaps.delete_value, "Delete the current field."),
        CC(config.keymaps.change_key, "Change the key of the current field."),
        CC(config.keymaps.change_value, "Change the value of the current field."),
        CC(config.keymaps.change_type, "Toggle type of cell between array and object."),
        "",
        C "Data explorer using Neovim's terminal interface.",
        C "Created by Owen Dechow with help from many amazing",
        C "contributors.",

    })

    local function close_win()
        if vim.api.nvim_win_is_valid(win) then
            vim.api.nvim_win_close(win, true)
        end
    end

    vim.keymap.set("n", config.keymaps.close_window, close_win)
    vim.keymap.set("n", config.keymaps.help, close_win)
    vim.keymap.set("n", "<ESC>", close_win)

    vim.wo[win].winfixbuf = true

    vim.api.nvim_create_autocmd("WinLeave", {
        callback = function()
            vim.api.nvim_win_close(win, true)
        end,
        buffer = buf,
    })
end

return M
