# 📊 videre.nvim

Many editors have the option to view JSON, TOML, & YAML files as a graph. Neovim, with a
terminal interface, does not have this luxury. While one can't create an
interface like JSON Crack, it is possible to build a similar JSON explorer
using Neovim's terminal interface.

```
╭──────────────────┬──╮ ╭──┬──┬──────────────────────────────────╮ ╭──┬──────┬───────────╮
│            Videre│[]├─╯  │ 1│··········"This is a great plugin"│ │  │  user│·"will try"│
│           Example│{}├─╮  │ 2│·············"Look at this number"│ │  │isTrue│"100% True"│
╰──────────────────┴──╯ │  │ 3│······························3467│ │  ╰──────┴───────────╯
                        │  │ 4│······························null│ │
                        │  │ 5│···"The Next lines will be hidden"│ │
                        │  ╪.....................................│ │
                        │  ╰──┴──────────────────────────────────╯ │
                        │                                          │
                        ╰──┬────────────┬────────────────────────╮ │
                           │ empty_array│······················[]│ │
                           │ empty_table│······················{}│ │
                           │        test│"This is some test data"├─╯
                           ╰────────────┴────────────────────────╯
```

https://github.com/user-attachments/assets/e2e6d49a-4ab8-4718-a2a2-7839ca1ba4e2

## 🛠️ Features

* Algorithmic Graph Rendering
* Collapsible Units
* Jumping Between Linked Units
* Set Any Unit as Root
* Customizable Styles
* Support for Different Filetypes

## ⚙️ Setup

<details>
  <summary>lazy.nvim (Suggested Setup): https://github.com/folke/lazy.nvim</summary>
  
  ```lua
  return {
      "Owen-Dechow/videre.nvim",
      cmd = "Videre",
      dependencies = {
          "Owen-Dechow/graph_view_yaml_parser", -- Optional: add YAML support
          "Owen-Dechow/graph_view_toml_parser", -- Optional: add TOML support
          "a-usr/xml2lua.nvim", -- Optional | Experimental: add XML support
      },
      opts = {
          box_style = "sharp",
      }
  }
  ```
</details>

<details>
  <summary>vim.pack: https://neovim.io/doc/user/pack.html#_plugin-manager</summary>

  ```lua
  vim.pack.add {
      "https://github.com/Owen-Dechow/videre.nvim",
      "https://github.com/Owen-Dechow/graph_view_yaml_parser", -- Optional: add YAML support
      "https://github.com/Owen-Dechow/graph_view_toml_parser", -- Optional: add TOML support
      "https://github.com/a-usr/xml2lua.nvim", -- Optional | Experimental: add XML support
  }
  
  require("videre").setup {
      box_style = "sharp",
  }
  ```
</details>

## 🧩 Options
```lua
---@alias LineStyle "sharp"|"rounded"|"bold"|"double"
---@alias ColumnAlignment "top"|"center"|"bottom"
---@alias RowAlignment "left"|"center"|"right"

{
    ---@comment Character used between cells
    ---@type string
    outside_space = " ",

    ---@comment Character to pad the key column
    ---@type string
    key_space = " ",

    ---@comment Character to pad the value column
    ---@type string
    value_space = "·",

    ---@comment Alignment of cell columns
    ---@type ColumnAlignment
    column_alignment = "center",

    ---@comment Alignment of the keys within the cell
    ---@type RowAlignment
    key_alignment = "right",

    ---@comment Alignment of the values within the cell
    ---@type RowAlignment
    value_alignment = "right",

    ---@comment Space between connective lines (int: [0,99])
    ---@type integer
    connection_spacing = 2,

    ---@comment Space between cells (int: [0,99])
    ---@type integer
    cell_spacing = 1,

    ---@comment Number of lines shown by default in cell (int: [0,999])
    ---@type integer
    max_cell_lines = 5,

    ---@comment Character used to indicate call values beyond `max_cell_lines`
    ---@type string
    collapse_indication_character = ".",

    ---@comment Style of the connective lines
    ---@type LineStyle
    box_style = "rounded",

    ---@comment Style of the cells
    ---@type LineStyle
    line_style = "rounded",

    ---@comment Width of the editing character (int: [6, 999])
    ---@type integer
    editor_window_width = 60,

    ---@comment Number of spaces each tab character expands to (int: [1,16])
    ---@type integer
    tab_width = 4,

    ---@comment Toggle expansion of \t character
    ---@type boolean
    expand_tabs = false,

    ---@comment Toggle expansion of \n and \r\n characters
    ---@type boolean
    expand_newlines = false,

    ---@comment Max display width of string values in characters; 0 disables wrapping (int: [0, 9999])
    ---@type integer
    max_line_width = 0,
    keymaps = {
        ---@comment Expand lines beyond `max_cell_lines`
        ---@type string
        expand = "E",

        ---@comment Collapse lines beyond `max_cell_lines`
        ---@type string
        collapse = "E",

        ---@comment Move cursor to linked cell
        ---@type string
        jump_forward = "L",

        ---@comment Move cursor to parent cell
        ---@type string
        jump_back = "H",

        ---@comment Move cursor to cell above in cell column
        ---@type string
        jump_down = "J",

        ---@comment Move cursor to cell below in cell column
        ---@type string
        jump_up = "K",

        ---@comment Set cell as root cell
        ---@type string
        set_as_root = "R",

        ---@comment Return to the true root cell
        ---@type string
        return_to_parent_table = "H",

        ---@comment Change the key of a value
        ---@type string
        change_key = "C",

        ---@comment Change a value
        ---@type string
        change_value = "V",

        ---@comment Delete a value
        ---@type string
        delete_value = "D",

        ---@comment Add a value
        ---@type string
        add_value = "A",

        ---@comment Toggle type of cell between array-like and object-like
        ---@type string
        change_type = "T",

        ---@comment Undo a change 
        ---@type string
        undo = "u",

        ---@comment Redo a change i.e. undo an undo
        ---@type string
        redo = "<C-r>",

        ---@comment Open help menu
        ---@type string
        help = "g?",

        ---@comment Exit
        ---@type string
        close_window = "q",
    },

    ---@comment Type of window Videre will open in
    ---@type "split"|"floating"
    editor_type = "split",

    ---@comment Styles of floating window
    floating_editor_style = {
        ---@comment Space around floating window
        ---@type integer
        margin = 2,

        ---@comment Floating window border type
        ---@type "rounded"|"double"|"shadow"|"none"
        border = "rounded",

        ---@comment Floating window z-index
        ---@type integer
        zindex = 10
    },

    ---@comment Styles of v-split window
    split_editor_style = {
        ---@comment Where to open Videre
        ---@type "left"|"right"|"default"
        side = "right",

        ---@comment What percentage of window Videre covers (num: [0.1, 0.9])
        ---@type number
        fill_percentage = 0.7,
    },

    ---@comment Side scrolloff for Videre window (int: [0, 999])
    ---@type integer
    sidescrolloff = 20,

    ---@comment Scrolloff for Videre window (int: [0, 999])
    ---@type integer
    scrolloff = 10,

    ---@comment Set the indexing base i.e. 0, 1 or whatever else you want
    ---@type integer
    index_base = 0,
}
```

## 🚀 Running

To open a graph view, go to a json file and run `:Videre`.
The Videre window will open in a plit window to the right.
The Videre buffer will have a filetype of `Videre`.

## ✏️ Editing
The following actions are allowed for editing:
* Adding fields
* Deleting fields
* Changing key of field
* Changing value fo field
* Toggling type of cell between array and object

## 🗂️ Different File Types

To enable different filetypes just add the correct parser plugin.
Videre will automatically detect the installed plugin and
allow you to explore that filetype.

Here are a list of supported parsers:
* JSON: ***builtin***
* YAML: [graph_view_yaml_parser](https://github.com/Owen-Dechow/graph_view_yaml_parser)
* TOML: [graph_view_toml_parser](https://github.com/Owen-Dechow/graph_view_toml_parser)
* XML **(Experimental)**: [xml2lua.nvim](https://github.com/a-usr/xml2lua.nvim)

If you would like to add a parser please open an issue or contribute a PR.

## 📄 License

This software is licensed under the MIT Standard License
[(Copyright (c) 2026 Owen Dechow)](https://github.com/Owen-Dechow/videre.nvim/blob/main/LICENSE).

## 🤝 Contributions

Contributions to this software are greatly appreciated.
Please read [CONTRIBUTING.md](https://github.com/Owen-Dechow/videre.nvim/blob/main/CONTRIBUTING.md)
for further guidelines.
