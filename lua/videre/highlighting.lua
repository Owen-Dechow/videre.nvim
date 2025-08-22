local M = {}

---Apply highlighting to current buffer
---@param lang_spec LangSpec
---@param disable_dot boolean | nil
M.ApplyHighlighting = function(lang_spec, disable_dot)
    vim.cmd([[highlight GraphViewOperator guifg=#009900]])
    vim.api.nvim_set_hl(0, "VidereStatusline", { bg = "#1e1e2e", fg = "#ffffff", bold = true })
    vim.api.nvim_set_hl(0, "VidereUnitHighlight", { link = "GraphViewOperator" })

    vim.cmd([[syntax match Special /\\[\\\"'abfnrtv]/ containedin=String]])
    vim.cmd([[syntax region String start=+"+ skip=+\\\\\\|\\"+ end=+"+ contains=StringEscape,@Spell]])

    vim.cmd([[syn match Identifier /│\s*\zs\w\+\ze\s*│/ contains=@Spell]])
    vim.cmd([[syn match Identifier /╪\s*\zs\w\+\ze\s*│/ contains=@Spell]])
    vim.cmd("syn keyword Keyword null")
    vim.cmd("syn match GraphViewOperator \"[{}\\[\\]]\"")

    if not disable_dot then
        vim.cmd("syn match GraphViewOperator \"\\.\"")
    end

    vim.cmd([[syn match Comment "]] .. require("videre.utils").cfg().space_char .. [["]])
    vim.cmd("syn keyword Boolean true false")
    vim.cmd("syn match Number \"[-+]\\=\\%(0\\|[1-9]\\d*\\)\\%(\\.\\d*\\)\\=\\%([eE][-+]\\=\\d\\+\\)\\=\"")
    vim.cmd("syn match Number \"[-+]\\=\\%(\\.\\d\\+\\)\\%([eE][-+]\\=\\d\\+\\)\\=\"")
    vim.cmd("syn match Number \"[-+]\\=0[xX]\\x*\"")
    vim.cmd("syn match Number \"[-+]\\=Infinity\\|NaN\"")

    if lang_spec.highlight then
        lang_spec.highlight()
    end
end

M.ApplyStatuslineHighlighting = function()
    vim.cmd([[syntax match Keyword /\<Videre\>/]])
    vim.cmd('syntax match Special "\\v\\[[^\\]]+\\]"')
    vim.cmd([[syntax match Identifier /\v\([^)]*\)/]])
end

return M
