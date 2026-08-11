local vimrc = vim.fn.stdpath("config") .. "/vimrc.vim"
vim.cmd.source(vimrc)
dofile(vim.fn.stdpath("config") .. "/tabline.lua")
require("user.telescope_buffers").setup()
require("user.terminal_mode").setup()

local function truncate_display_width(text, width, initial_column)
    if width <= 0 then
        return ""
    end
    if vim.fn.strdisplaywidth(text, initial_column) <= width then
        return text
    end

    local result = ""
    for length = 1, vim.fn.strchars(text) do
        local prefix = vim.fn.strcharpart(text, 0, length)
        if vim.fn.strdisplaywidth(prefix, initial_column) > width then
            break
        end
        result = prefix
    end
    return result
end

local function drop_display_width(text, width, initial_column)
    if width <= 0 then
        return text
    end

    for length = 1, vim.fn.strchars(text) do
        local prefix = vim.fn.strcharpart(text, 0, length)
        if vim.fn.strdisplaywidth(prefix, initial_column) >= width then
            return vim.fn.strcharpart(text, length)
        end
    end
    return ""
end

local function strip_opencode_scrollbar(text, start_column, content_width)
    text = text:gsub("%s+$", "")
    local length = vim.fn.strchars(text)
    if length == 0 then
        return text
    end

    local end_column = start_column + vim.fn.strdisplaywidth(text, start_column - 1) - 1
    local last_character = vim.fn.strcharpart(text, length - 1, 1)
    local codepoint = vim.fn.char2nr(last_character)
    if end_column == content_width - 2 and codepoint >= 0x2580 and codepoint <= 0x259f then
        return vim.fn.strcharpart(text, 0, length - 1):gsub("%s+$", "")
    end
    return text
end

local function yank_opencode_quote()
    local visual_mode = vim.fn.mode()
    local anchor = vim.fn.getpos("v")
    local cursor = vim.fn.getpos(".")
    local anchor_column = vim.fn.virtcol("v")
    local cursor_column = vim.fn.virtcol(".")

    local first_column = cursor_column
    if anchor[2] < cursor[2] or (anchor[2] == cursor[2] and anchor[3] <= cursor[3]) then
        first_column = anchor_column
    end

    vim.cmd.normal({ args = { "y" }, bang = true })
    if vim.bo.buftype ~= "terminal" then
        return
    end

    local window_info = vim.fn.getwininfo(vim.api.nvim_get_current_win())[1]
    local terminal_width = vim.api.nvim_win_get_width(0) - window_info.textoff
    local content_width = terminal_width
    if terminal_width > 120 then
        content_width = terminal_width - 42
    end

    local lines = vim.fn.getreg('"', 1, 1)
    local register_type = vim.fn.getregtype('"')
    local block_mode = string.char(22)
    for index, line in ipairs(lines) do
        local start_column = 1
        if visual_mode == "v" and index == 1 then
            start_column = first_column
        elseif visual_mode == block_mode then
            start_column = math.min(anchor_column, cursor_column)
        end

        local available_width = content_width - start_column + 1
        line = truncate_display_width(line, available_width, start_column - 1)
        line = strip_opencode_scrollbar(line, start_column, content_width)
        line = drop_display_width(line, math.max(0, 6 - start_column), start_column - 1)
        line = line:gsub("%s+$", "")
        lines[index] = line == "" and ">" or "> " .. line
    end

    vim.fn.setreg("0", lines, register_type)
    vim.fn.setreg('"', lines, register_type)
end

vim.keymap.set("x", "Y", yank_opencode_quote, {
    desc = "Yank an OpenCode quote",
    silent = true,
})

vim.cmd("highlight clear DiagnosticUnderlineError")
vim.cmd("highlight DiagnosticUnderlineError guibg=#a00000")
vim.cmd("highlight clear DiagnosticUnderlineWarn")
vim.cmd("highlight DiagnosticUnderlineWarn guibg=#707000")

-- gitsigns.nvim
local ok, gitsigns = pcall(require, "gitsigns")
if ok then
    vim.keymap.set("n", "]c", function() gitsigns.nav_hunk('next') end)
    vim.keymap.set("n", "[c", function() gitsigns.nav_hunk('prev') end)
end

vim.api.nvim_set_hl(0, "UserCodeDiffLineInsert", {
    bg = "#294329",
    ctermbg = 22,
})
vim.api.nvim_set_hl(0, "UserCodeDiffCharInsert", {
    bg = "#355535",
    ctermbg = 22,
})
vim.api.nvim_set_hl(0, "UserCodeDiffLineDelete", {
    bg = "#4a2b32",
    ctermbg = 52,
})
vim.api.nvim_set_hl(0, "UserCodeDiffCharDelete", {
    bg = "#603740",
    ctermbg = 52,
})

require("codediff").setup({
    highlights = {
        line_insert = "UserCodeDiffLineInsert",
        char_insert = "UserCodeDiffCharInsert",
        line_delete = "UserCodeDiffLineDelete",
        char_delete = "UserCodeDiffCharDelete",
    },
})

require("arcanum_review").setup()
