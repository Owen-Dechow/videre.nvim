# 📊 videre.nvim

Many editors have the option to view JSON & YAML files as a graph. Neovim, with a
terminal interface, does not have this luxury. While one can't create an
interface like JSON Crack, it is possible to build a similar JSON explorer
using Neovim's terminal interface.

```
╭──────────────────┬──╮╭──┬──┬──────────────────────────────────╮╭──┬──────┬───────────╮
│            Videre│[]├╯  │ 1│··········"This is a great plugin"││  │  user│·"will try"│
│           Example│{}├╮  │ 2│·············"Look at this number"││  │isTrue│"100% True"│
╰──────────────────┴──╯│  │ 3│······························3467││  ╰──────┴───────────╯
                       │  │ 4│······························null││
                       │  │ 5│···"The Next lines will be hidden"││
                       │  ╪.....................................││
                       │  ╰──┴──────────────────────────────────╯│
                       ╰──┬────────────┬────────────────────────╮│
                          │ empty_array│······················[]││
                          │ empty_table│······················{}││
                          │        test│"This is some test data"├╯
                          ╰────────────┴────────────────────────╯
```

[Videre Preview](https://github.com/user-attachments/assets/a8177730-2301-4767-88fe-f21cbc2de6a0)

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
          round_units = false,
          simple_statusline = true, -- If you are just starting out with Videre,
                                    --   setting this to `false` will give you
                                    --   descriptions of available keymaps.
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
  
  require('videre').setup {
      round_units = false,
      simple_statusline = true, -- If you are just starting out with Videre,
                                --   setting this to `false` will give you
                                --   descriptions of available keymaps.
  }
  ```
</details>

## 🧩 Options
<details>
  <summary>Show Defaults</summary>
  
  ```lua
  {
      -- set the window editor type
      editor_type = "split", -- split, floating
  
      -- configure the floating window style
      floating_editor_style = {
          margin = 2,
          border = "double",
          zindex = 10
      },
  
      -- Number of lines before collapsing
      max_lines = 5,
  
      -- Set the unit style to round
      round_units = true,
  
      -- Set the connection style to round
      round_connections = true,
  
      -- Disable line wrapping for the graph buffer
      disable_line_wrap = true,
  
      -- Set side scroll off for graph buffer
      side_scrolloff = 20,
  
      -- Change the string between the keymap and
      --   description of callback within the statusline
      -- FOR FONTS WITH LIGATURES TRY USING "꞊" INSTEAD OF "=". 
      -- Other great options include "->", ": ", "=>", & " ".
      keymap_desc_deliminator = "=",
  
      -- Character used to represent empty space
      space_char = "·",
  
      -- Use simple statusline instead of providing
      --   descriptions of keymaps.
      simple_statusline = true,   
  
      -- Show breadcrumbs to show where you are in
      --   a Videre graph.
      breadcrumbs = true,
  
      -- Set the priority of keymaps for the quick
      --   action keymap.
      keymap_priorities = {
              expand = 5,
              link_forward = 4,
              link_backward = 3,
              link_down = 1,
              link_up = 1,
              collapse = 2,
              set_as_root = 1,
      },
  
      -- Set the keys actions will be mapped to
      keymaps = {
          -- Expanding collapsed areas
          expand = "E",
  
          -- Collapse expanded areas
          collapse = "E",
  
          -- Jump to linked unit
          link_forward = "L",
  
          -- Jump back to unit parent
          link_backward = "H",
  
          -- Jump down a unit
          link_down = "J",
  
          -- Jump up a unit
          link_up = "K",
  
          -- Set current unit as root
          set_as_root = "R",
  
          -- Aliased to first priority available keymap
          quick_action = "<CR>",
  
          -- Close the window
          close_window = "q",
  
          -- Open the help menu
          help = "g?",
  
          -- Change the key of the current field
          change_key = "C",
  
          -- Change the value of the current field
          change_value = "V",
  
          -- Delete the current field
          delete_field = "D",
  
          -- Add a field to the unit 
          add_field = "A",
      }
  }
  ```
</details>

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

When entering a new value of a field the following rules must be followed:
* Strings must be wrapped in double quotes (exe. `"Hello World"`).
* `null`, `true` & `false` are the only valid keywords.
* `{}` will be interpreted as a new table.
* `[]` will be interpreted as a new list.
* Any other values will be parsed as numbers or return an error (exe: `14.53`).

## 🗂️ Different File Types

To enable different filetypes just add the correct parser plugin.
JsonGraphView will automatically detect the installed plugin and
allow you to explore that filetype.

Here are a list of supported parsers:
* JSON: ***builtin***
* YAML: [graph_view_yaml_parser](https://github.com/Owen-Dechow/graph_view_yaml_parser)
* TOML: [graph_view_toml_parser](https://github.com/Owen-Dechow/graph_view_toml_parser)
* XML **(Experimental)**: [xml2lua.nvim](https://github.com/a-usr/xml2lua.nvim)

If you would like to add a parser please open an issue or contribute a PR.

## 📄 License

This software is licensed under the MIT Standard License
[(Copyright (c) 2025 Owen Dechow)](https://github.com/Owen-Dechow/nvim_json_graph_view/blob/main/LICENSE).

## 🤝 Contributions

Contributions to this software are greatly appreciated.
Please read [CONTRIBUTING.md](https://github.com/Owen-Dechow/nvim_json_graph_view/blob/main/CONTRIBUTING.md)
for further guidelines.
