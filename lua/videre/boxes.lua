local config = require("videre.config").config

local M = {}

local chars = {
    sharp = {
        vert = "│",
        horiz = "─",
        tl_root = "┌",
        tl_non_root = "┬",
        tr = "┐",
        bl = "└",
        br = "┘",
        col_top = "┬",
        col_bottom = "┴",
        collapse = "╪",
        link = {
            sharp = "├",
            rounded = "├",
            bold = "┝",
            double = "╞",
        },
    },

    rounded = {
        vert = "│",
        horiz = "─",
        tl_root = "╭",
        tl_non_root = "┬",
        tr = "╮",
        bl = "╰",
        br = "╯",
        col_top = "┬",
        col_bottom = "┴",
        collapse = "╪",
        link = {
            sharp = "├",
            rounded = "├",
            bold = "┝",
            double = "╞",
        }
    },

    bold = {
        vert = "┃",
        horiz = "━",
        tl_root = "┏",
        tl_non_root = "┳",
        tr = "┓",
        bl = "┗",
        br = "┛",
        col_top = "┳",
        col_bottom = "┻",
        collapse = "╋",
        link = {
            sharp = "┠",
            rounded = "┠",
            bold = "┣",
            double = "┣",
        }
    },

    double = {
        vert = "║",
        horiz = "═",
        tl_root = "╔",
        tl_non_root = "╦",
        tr = "╗",
        bl = "╚",
        br = "╝",
        col_top = "╦",
        col_bottom = "╩",
        collapse = "╬",
        link = {
            sharp = "╟",
            rounded = "╟",
            bold = "╠",
            double = "╠",
        }
    },
}


---@param is_root boolean
---@return string
function M.TopLeft(is_root)
    local c = chars[config.box_style]
    return is_root and c.tl_root or c.tl_non_root
end

---@return string
function M.TopRight()
    return chars[config.box_style].tr
end

---@return string
function M.BottomLeft()
    return chars[config.box_style].bl
end

---@return string
function M.BottomRight()
    return chars[config.box_style].br
end

---@return string
function M.VerticalBox()
    return chars[config.box_style].vert
end

---@return string
function M.BoxConnect()
    return chars[config.box_style].link[config.line_style]
end

---@return string
function M.BoxCollapse()
    return chars[config.box_style].collapse
end

---@return string
function M.HorizontalBox()
    return chars[config.box_style].horiz
end

---@return string
function M.ColumnTopBreak()
    return chars[config.box_style].col_top
end

---@return string
function M.ColumnBottomBreak()
    return chars[config.box_style].col_bottom
end

---@return string
function M.FromUpTurnRight()
    return chars[config.line_style].tl_root
end

---@return string
function M.FromDownTurnRight()
    return chars[config.line_style].bl
end

---@return string
function M.FromRightTurnUp()
    return chars[config.line_style].br
end

---@return string
function M.FromRightTurnDown()
    return chars[config.line_style].tr
end

---@return string
function M.VerticalLine()
    return chars[config.line_style].vert
end

---@return string
function M.HorizontalLine()
    return chars[config.line_style].horiz
end

return M
