local M = {}

M.ROUND_EDGE = {
    TOP_LEFT = "┬",
    TOP_LEFT_ROOT = "╭",
    TOP_RIGHT = "╮",
    BOTTOM_LEFT = "╰",
    BOTTOM_RIGHT = "╯",
    TOP_AND_BOTTOM = "─",
    LEFT_AND_RIGHT = "│",
    TOP_SPLITTER = "┬",
    BOTTOM_SPLITTER = "┴",
    CONNECTION = "├"
}

M.HARD_EDGE = {
    TOP_LEFT = "┬",
    TOP_LEFT_ROOT = "┌",
    TOP_RIGHT = "┐",
    BOTTOM_LEFT = "└",
    BOTTOM_RIGHT = "┘",
    TOP_AND_BOTTOM = "─",
    LEFT_AND_RIGHT = "│",
    TOP_SPLITTER = "┬",
    BOTTOM_SPLITTER = "┴",
    CONNECTION = "├"
}

M.edge = M.ROUND_EDGE

M.ROUND_LINE = {
    TURN_SIDE_FU = "╭",
    TURN_DOWN = "╮",
    TURN_SIDE_FD = "╰",
    TURN_UP = "╯",
    SIDE = "─",
    UP_DOWN = "│",
}

M.HARD_LINE = {
    TURN_SIDE_FU = "┌",
    TURN_DOWN = "┐",
    TURN_SIDE_FD = "└",
    TURN_UP = "┘",
    SIDE = "─",
    UP_DOWN = "│",
}

M.line = M.ROUND_LINE

return M
