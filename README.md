# 📊 videre.nvim

Many editors have the option to view JSON & YAML files as a graph. Neovim, with a
terminal interface, does not have this luxury. While one can't create an
interface like JSON Crack, it is possible to build a similar JSON explorer
using Neovim's terminal interface.

[Videre Preview](https://github.com/user-attachments/assets/1b50ce8a-96c9-4d81-a06e-d5a266c1083b)

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

> [!NOTE]
> This plugin is still under development. Breaking changes will be avoided
> unless deemed necessary.

## 🛠️ Features

* Algorithmic Graph Rendering
* Collapsible Units
* Jumping Between Linked Units
* Set Any Unit as Root
* Customizable Styles
* Support for Different Filetypes

## ⚙️ Setup

[lazy.nvim](https://github.com/folke/lazy.nvim) (Suggested Setup)
```lua
return {
    "Owen-Dechow/nvim_json_graph_view",
    dependencies = {
        "Owen-Dechow/graph_view_yaml_parser", -- Optional: add YAML support
        "Owen-Dechow/graph_view_toml_parser", -- Optional: add TOML support
        "a-usr/xml2lua.nvim", -- Optional | Experimental: add XML support
    },
    opts = {
        round_units = false
    }
}
```

## 🧩 Options
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

    -- Set the priority of keymaps for the quick
    --   action keymap.
    keymap_priorities = {
        expand = 4,
        collapse = 2,
        link_forward = 3,
        link_backward = 3,
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
        link_backward = "B",

        -- Set current unit as root
        set_as_root = "R",

        -- Aliased to first priority available keymap
        quick_action = "<CR>",

        -- Close the window
        close_window = "q"
    }
}
```

## 🚀 Running

To open a graph view, go to a json file and run `:Videre`.
The Videre window will open in a plit window to the right.
The Videre buffer will have a filetype of `Videre`.

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

## 🎯 Future Goals
> [!NOTE]
> These goals are long term and will only be started after this
> plugin is deemed stable and there is enough support.

### 📚 Multiple Filetype Support

Add support for different filetypes such as YAML and TOML.

(Issue: [Multiple Filetype Support *#4*](https://github.com/Owen-Dechow/nvim_json_graph_view/issues/4))

### ✏️ File Editing

Add support for file editing directly form Videre.

(Issue: [File Editing *#5*](https://github.com/Owen-Dechow/nvim_json_graph_view/issues/5))

## 📄 License

This software is licensed under the MIT Standard License
[(Copyright (c) 2025 Owen Dechow)](https://github.com/Owen-Dechow/nvim_json_graph_view/blob/main/LICENSE).

## 🤝 Contributions

Contributions to this software are greatly appreciated.
Please read [CONTRIBUTING.md](https://github.com/Owen-Dechow/nvim_json_graph_view/blob/main/CONTRIBUTING.md)
for further guidelines.
