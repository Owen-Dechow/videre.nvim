local edges = require("videre.edges")
local utils = require("videre.utils")

local M = {}

---Build connections for the given layer
---@param connections {from: integer, to:integer}[]
---@param grid_height integer
---@return TextLine[]
local function build_connections_for_layer(connections, grid_height)
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

    local n_cols = math.max(#up_cons, #down_cons) * utils.cfg().connection_spacing
    for _ = 1, n_cols do
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
                char = edges.line.SIDE
            elseif last_was_right and (not new_is_right) then
                char = edges.line.TURN_DOWN
            elseif (not last_was_right) and new_is_right then
                char = edges.line.TURN_SIDE_FD
            else
                char = edges.line.UP_DOWN
            end

            grid[row][col] = char
            last_was_right = new_is_right
            row = new_row
            col = new_col

            if last_was_right then
                for _ = 1, utils.cfg().connection_spacing - 1 do
                    grid[row][col] = edges.line.SIDE
                    col = col + 1;
                end
            end
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
                char = edges.line.SIDE
            elseif last_was_right and (not new_is_right) then
                char = edges.line.TURN_UP
            elseif (not last_was_right) and new_is_right then
                char = edges.line.TURN_SIDE_FU
            else
                char = edges.line.UP_DOWN
            end

            grid[row][col] = char
            last_was_right = new_is_right
            row = new_row
            col = new_col

            if last_was_right then
                for _ = 1, utils.cfg().connection_spacing - 1 do
                    grid[row][col] = edges.line.SIDE
                    col = col + 1;
                end
            end
        end
    end

    for col = grid_cols, 1, -1 do
        local unnecessary = true

        for _, row in pairs(grid) do
            if row[col] ~= " " and row[col] ~= edges.line.SIDE then
                unnecessary = false
                break
            end
        end

        if unnecessary then
            for _, row in pairs(grid) do
                row[col] = nil
            end
        else
            break
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

        connections[layer_id] = build_connections_for_layer(layer_connections, layer_grid_height)
    end

    return connections
end

return M
