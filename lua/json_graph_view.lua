vim.notify(
    "[DEPRECATION]\n"
    .. [[`require("json_graph_view")` is deprecated. Use `require("videre")` instead.]],
    "WARN"
)

return require "videre"
