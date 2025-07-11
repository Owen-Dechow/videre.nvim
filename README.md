# nvim_json_graph_view

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

## Setup

[lazy.nvim](https://github.com/folke/lazy.nvim) (suggested setup)
```lua
return {
    "Owen-Dechow/nvim_json_graph_view",
    opts = {
        round_units = false
    }
}
```

[lazy.nvim](https://github.com/folke/lazy.nvim) (all options shown)
```lua
return {
    "Owen-Dechow/nvim_json_graph_view",
    opts = {
        -- editor_type = "split", -- split, floating
        -- -- set the window editor type

        -- floating_editor_style = {
        --     margin = 2,
        --     border = "double",
        --     zindex = 10
        -- },
        -- -- configure the floating window style

        -- accept_all_files = false,
        -- -- Allow opening non .json files

        -- max_lines = 5,
        -- -- Number of lines before collapsing

        -- round_units = true,
        -- -- Set the unit style to round

        -- round_connections = true,
        -- -- Set the connection style to round

        -- disable_line_wrap = true,
        -- -- Disable line wrapping for the graph buffer

        -- keymap_priorities = {
            -- expand = 4,
            -- collapse = 2,
            -- link_forward = 3,
            -- link_backward = 3,
            -- set_as_root = 1,
        -- },
        -- -- Set the priority of keymaps for the quick
        -- --   action keymap.

        -- keymaps = {
            -- expand = "E",
            -- -- Expanding collapsed areas

            -- collapse = "E",
            -- -- Collapse expanded areas

            -- link_forward = "L",
            -- -- Jump to linked unit

            -- link_backward = "B",
            -- -- Jump back to unit parent

            -- set_as_root = "R",
            -- -- Set current unit as root

            -- quick_action = "<CR>",
            -- -- Aliased to first priority available keymap

            -- close_window = "q"
            -- -- Close the window
        -- }
    }
}
```

## Running

To open a graph view, go to a json file and run `:JsonGraphView`.
The JsonGraphView window will open in a plit window to the right.
