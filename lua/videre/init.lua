local config = require "videre.config"

vim.api.nvim_create_user_command("Videre", function()
    local buffer = require "videre.buffer"
    local window = require "videre.window"
    local langs = require "videre.langs"

    local data_buffer = vim.api.nvim_get_current_buf()

    local data_type = vim.bo[data_buffer].filetype
    local lang_spec = langs[data_type]

    if lang_spec == nil then
        vim.notify(data_type .. " is not a valid Videre data type.")
        return
    end

    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    local data_str = table.concat(lines, "\n")

    local success, data = pcall(lang_spec.Decode, data_str)

    if not success then
        vim.notify("Error: invalid " .. lang_spec.name .. ".")
        return
    end

    local buf = buffer.CreateVidereBuffer(data, data_buffer, lang_spec)
    window.OpenWindowWithBuffer(buf)
end, {})

return {
    ---@param opts VidereConfig
    setup = function(opts)
        config.Setup(opts)
    end
}
