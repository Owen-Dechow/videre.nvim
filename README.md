# 📊 nvim_json_graph_view

Many editors have the option to view JSON files as a graph. Neovim, with a
terminal interface, does not have this luxury. While one can't create an
interface like JSON Crack, it is possible to build a similar JSON explorer
using Neovim's terminal interface.

[Json Graph View Preview](https://github.com/user-attachments/assets/1b50ce8a-96c9-4d81-a06e-d5a266c1083b)

```
╭──────────────────┬──╮╭──┬──┬──────────────────────────────────╮╭──┬──────┬───────────╮
│     JsonGraphView│[]├╯  │ 1│··········"This is a great plugin"││  │  user│·"will try"│
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

## ⚙️ Setup

[lazy.nvim](https://github.com/folke/lazy.nvim) (suggested setup)
```lua
return {
    "Owen-Dechow/nvim_json_graph_view",
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

    -- Allow opening non .json files
    accept_all_files = false,

    -- Number of lines before collapsing
    max_lines = 5,

    -- Set the unit style to round
    round_units = true,

    -- Set the connection style to round
    round_connections = true,

    -- Disable line wrapping for the graph buffer
    disable_line_wrap = true,

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

To open a graph view, go to a json file and run `:JsonGraphView`.
The JsonGraphView window will open in a plit window to the right.
The JsonGraphView buffer will have a filetype of `JsonGraphView`.


## 🎯 Future Goals
> [!NOTE]
> These goals are long term and will only be started after this
> plugin is deemed stable and there is enough support. They
> will be developed in separate branches.

### 📚 Multiple Filetype Support

Add support for different filetypes such as TAML and TOML.

(Issue: [YAML Support *#4*](https://github.com/Owen-Dechow/nvim_json_graph_view/issues/4))

### ✏️ File Editing

Add support for file editing directly form JsonGraphView.

(Issue: [File Editing *#5*](https://github.com/Owen-Dechow/nvim_json_graph_view/issues/5))

## 📄 License

This software is licensed under the MIT Standard License
[(Copyright (c) 2025 Owen Dechow)](https://github.com/Owen-Dechow/nvim_json_graph_view/blob/main/LICENSE).

## 🤝 Contributions

Contributions to this software are greatly appreciated.
Please read [CONTRIBUTING.md](https://github.com/Owen-Dechow/nvim_json_graph_view/blob/main/CONTRIBUTING.md)
for further guidelines.
