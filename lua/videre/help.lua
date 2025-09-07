local utils = require("videre.utils")
local cfg = utils.cfg

local M = {}

M.HelpMenu = function()
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

    local function C(text)
        local text_width = utils.utf8len(text)
        local diff = width - text_width
        local pad = math.max(0, math.floor(diff / 2))
        return string.rep(" ", pad) .. text
    end

    local function CC(texta, textb)
        local target_width = 50
        local listing = texta .. ": " .. textb
        local listing_len = utils.utf8len(listing)
        if listing_len < target_width then
            local diff = target_width - listing_len
            listing = texta .. ": " .. string.rep(cfg().space_char, diff) .. textb
        end

        return C(listing)
    end

    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
        "",
        C "Videre Nvim | Help",
        C("Press <ESC>, "
            .. cfg().keymaps.close_window
            .. ", or "
            .. cfg().keymaps.help
            .. " to close."),
        "",
        CC(cfg().keymaps.close_window, "Close the Videre window."),
        CC(cfg().keymaps.help, "Open the help window."),
        CC(cfg().keymaps.quick_action, "Fire the highest priority action available."),
        CC(cfg().keymaps.collapse, "Collapse a unit."),
        CC(cfg().keymaps.expand, "Expand a unit."),
        CC(cfg().keymaps.link_forward, "Jump to connected unit."),
        CC(cfg().keymaps.link_backward, "Jump to parent unit."),
        CC(cfg().keymaps.set_as_root, "Set unit as root unit."),
        CC(cfg().keymaps.add_field, "Add a field to the unit."),
        CC(cfg().keymaps.delete_field, "Delete the current field."),
        CC(cfg().keymaps.change_key, "Change the key of the current field."),
        CC(cfg().keymaps.change_value, "Change the value of the current field."),
        "",
        C "Data explorer using Neovim's terminal interface.",
        C "Created by Owen Dechow with help from many amazing",
        C "contributors.",

    })
    require("videre.highlighting").ApplyHighlighting({}, true)

    local function close_win()
        if vim.api.nvim_win_is_valid(win) then
            vim.api.nvim_win_close(win, true)
        end
    end

    utils.keymap(cfg().keymaps.close_window, close_win)
    utils.keymap(cfg().keymaps.help, close_win)
    utils.keymap("<ESC>", close_win)
end


return M
