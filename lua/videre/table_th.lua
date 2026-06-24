---@class VidereTable
---@field layers VidereLayer[]
---@field parent_table VidereTable|nil
---@field grp integer
---@field data DataObj
---@field from_buffer integer
---@field is_saved boolean
---@field available_maps string[]
---@field lang_spec LangSpec
---@field states State[] 
---@field state_idx integer

---@class State
---@field data DataObj
---@field root DataObjectRef
---@field focus DataObjectRef
---@field value integer

---@class VidereLayer
---@field cells VidereCell[]
---@field width integer|nil
---@field height integer|nil
---@field left_render_col integer|nil

---@class VidereCell
---@field title string|nil
---@field type DataObjectTypeName
---@field values VidereEntry[]
---@field hidden_values VidereEntry[]
---@field top_render_line integer|nil
---@field render_width integer|nil
---@field is_hidden boolean
---@field height integer|nil
---@field linking_cell CellValRef|nil
---@field parent_linking_cell CellValRef|nil
---@field data DataObj
---@field data_ref DataObjectRef
---@field key_col_width integer|nil
---@field total_display_rows integer|nil

---@class VidereEntry
---@field [1] integer|string
---@field [2] VidereValue
---@field val_left_pad integer|nil
---@field key_left_pad integer|nil
---@field val_right_pad integer|nil
---@field key_right_pad integer|nil
---@field row_offset integer|nil

---@alias CellValRef [integer, integer, integer]

---@alias Null userdata

---@alias VidereValue
---| number
---| string
---| Null
---| boolean
---| VidereConnection
---| VidereBranchConnection

---@class VidereConnection
---@field layer integer
---@field cell integer
---@field parent_reference [integer, integer]|nil
---@field type DataObjectTypeName
---@field from_render_line integer|nil
---@field to_render_line integer|nil

---@class VidereBranchConnection
---@field targets VidereConnection[]
---@field type "array"
---@field from_render_line integer|nil
