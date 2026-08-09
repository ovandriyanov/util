---@alias UserBufferOpenMode "smart"|"split"|"vsplit"|"tab"
---@alias UserBufferScope "all"|"shown"|"hidden"|"protected_hidden"

local M = {}

local api = vim.api
local configured = false

local open_commands = {
    split = "split",
    vsplit = "vsplit",
    tab = "tab split",
}

local picker_scopes = {
    all = {
        prompt_title = "Buffers",
        empty_message = "No buffers",
    },
    shown = {
        prompt_title = "Shown Buffers",
        empty_message = "No shown buffers",
    },
    hidden = {
        prompt_title = "Hidden Buffers",
        empty_message = "No hidden buffers",
    },
    protected_hidden = {
        prompt_title = "Protected Hidden Buffers",
        empty_message = "No hidden modified buffers or running terminals",
    },
}

local function buffer_option(bufnr, name)
    local ok, value = pcall(api.nvim_get_option_value, name, { buf = bufnr })
    if not ok then
        return nil
    end
    return value
end

local function eligible_window(winid, bufnr)
    if not api.nvim_win_is_valid(winid) then
        return false
    end

    local ok_config, config = pcall(api.nvim_win_get_config, winid)
    if not ok_config
        or config.relative ~= ""
        or config.external == true
        or config.focusable == false
        or config.hide == true
    then
        return false
    end

    local ok_buffer, window_buffer = pcall(api.nvim_win_get_buf, winid)
    return ok_buffer and window_buffer == bufnr
end

local function sorted_matching_windows(tabpage, bufnr)
    local ok_windows, windows = pcall(api.nvim_tabpage_list_wins, tabpage)
    if not ok_windows then
        return {}
    end

    local matches = {}
    for _, winid in ipairs(windows) do
        if eligible_window(winid, bufnr) then
            local ok_position, position = pcall(api.nvim_win_get_position, winid)
            if ok_position then
                matches[#matches + 1] = {
                    id = winid,
                    row = position[1],
                    col = position[2],
                }
            end
        end
    end

    table.sort(matches, function(left, right)
        if left.row ~= right.row then
            return left.row < right.row
        end
        if left.col ~= right.col then
            return left.col < right.col
        end
        return left.id < right.id
    end)
    return matches
end

---@param bufnr integer
---@return integer? tabpage
---@return integer? window
function M.find_target_window(bufnr)
    if type(bufnr) ~= "number" or bufnr <= 0 or not api.nvim_buf_is_valid(bufnr) then
        return nil, nil
    end

    for _, tabpage in ipairs(api.nvim_list_tabpages()) do
        local windows = sorted_matching_windows(tabpage, bufnr)
        if windows[1] ~= nil then
            return tabpage, windows[1].id
        end
    end
    return nil, nil
end

local function is_pristine_unnamed_buffer(bufnr)
    local ok_name, name = pcall(api.nvim_buf_get_name, bufnr)
    if not ok_name or name ~= "" or buffer_option(bufnr, "modified") ~= false then
        return false
    end
    if not api.nvim_buf_is_loaded(bufnr) then
        return true
    end

    local ok_count, line_count = pcall(api.nvim_buf_line_count, bufnr)
    if not ok_count or line_count ~= 1 then
        return false
    end
    local ok_lines, lines = pcall(api.nvim_buf_get_lines, bufnr, 0, 1, false)
    return ok_lines and lines[1] == ""
end

---@param bufnr integer
---@param scope UserBufferScope
---@return boolean
function M.should_include_buffer(bufnr, scope)
    if type(bufnr) ~= "number" or bufnr <= 0 or not api.nvim_buf_is_valid(bufnr) then
        return false
    end
    if buffer_option(bufnr, "buflisted") ~= true or is_pristine_unnamed_buffer(bufnr) then
        return false
    end
    if scope == "all" then
        return true
    end

    local hidden = M.find_target_window(bufnr) == nil
    if scope == "shown" then
        return not hidden
    end
    if scope == "hidden" then
        return hidden
    end
    if scope ~= "protected_hidden" or not hidden then
        return false
    end
    if buffer_option(bufnr, "modified") == true then
        return true
    end
    if buffer_option(bufnr, "buftype") ~= "terminal" then
        return false
    end

    local channel = buffer_option(bufnr, "channel")
    if type(channel) ~= "number" or channel <= 0 then
        return false
    end
    local ok_wait, statuses = pcall(vim.fn.jobwait, { channel }, 0)
    return ok_wait and type(statuses) == "table" and statuses[1] == -1
end

local function focus_window(winid)
    if type(winid) ~= "number" or not api.nvim_win_is_valid(winid) then
        return false, "Target window is no longer valid"
    end

    local ok_tabpage, tabpage = pcall(api.nvim_win_get_tabpage, winid)
    if not ok_tabpage or not api.nvim_tabpage_is_valid(tabpage) then
        return false, "Target tab is no longer valid"
    end
    local ok_tab, tab_error = pcall(api.nvim_set_current_tabpage, tabpage)
    if not ok_tab then
        return false, "Could not focus target tab: " .. tostring(tab_error)
    end
    local ok_window, window_error = pcall(api.nvim_set_current_win, winid)
    if not ok_window then
        return false, "Could not focus target window: " .. tostring(window_error)
    end
    return true
end

local function opening_window(original_win)
    if type(original_win) == "number" and api.nvim_win_is_valid(original_win) then
        return original_win
    end

    local ok_current, current_win = pcall(api.nvim_get_current_win)
    if ok_current and api.nvim_win_is_valid(current_win) then
        return current_win
    end
    return nil
end

local function switch_buffer(bufnr)
    local ok, err = pcall(vim.cmd, "buffer " .. bufnr)
    if not ok then
        return false, tostring(err)
    end
    return true
end

local function new_normal_window(existing_windows)
    local current_win = api.nvim_get_current_win()
    local candidates = api.nvim_list_wins()
    table.sort(candidates, function(left, right)
        if left == right then
            return false
        end
        if left == current_win then
            return true
        end
        if right == current_win then
            return false
        end
        return left < right
    end)

    for _, winid in ipairs(candidates) do
        if not existing_windows[winid] and api.nvim_win_is_valid(winid) then
            local ok_config, config = pcall(api.nvim_win_get_config, winid)
            if ok_config and config.relative == "" and config.external ~= true then
                return winid
            end
        end
    end
    return nil
end

---@param bufnr integer
---@param mode UserBufferOpenMode
---@param original_win integer?
---@return boolean success
---@return string? error
function M.open_buffer(bufnr, mode, original_win)
    if type(bufnr) ~= "number" or bufnr <= 0 or not api.nvim_buf_is_valid(bufnr) then
        return false, "Selected buffer is no longer valid"
    end
    if mode ~= "smart" and open_commands[mode] == nil then
        return false, "Unknown buffer open mode: " .. tostring(mode)
    end

    if mode == "smart" then
        local tabpage, winid = M.find_target_window(bufnr)
        if tabpage ~= nil and winid ~= nil then
            local ok_tab, tab_error = pcall(api.nvim_set_current_tabpage, tabpage)
            if not ok_tab then
                return false, "Could not focus target tab: " .. tostring(tab_error)
            end
            local ok_window, window_error = pcall(api.nvim_set_current_win, winid)
            if not ok_window then
                return false, "Could not focus target window: " .. tostring(window_error)
            end
            return true
        end
    end

    local target_win = opening_window(original_win)
    if target_win == nil then
        return false, "No valid window is available for the selected buffer"
    end
    local ok_focus, focus_error = focus_window(target_win)
    if not ok_focus then
        return false, focus_error
    end

    if mode == "smart" then
        return switch_buffer(bufnr)
    end

    local existing_windows = {}
    for _, winid in ipairs(api.nvim_list_wins()) do
        existing_windows[winid] = true
    end
    local ok_container, container_error = pcall(vim.cmd, open_commands[mode])
    if not ok_container then
        return false, "Could not create buffer container: " .. tostring(container_error)
    end
    local new_win = new_normal_window(existing_windows)
    if new_win == nil then
        return false, "The buffer container did not create a new window"
    end
    local ok_new_window, new_window_error = focus_window(new_win)
    if not ok_new_window then
        pcall(api.nvim_win_close, new_win, true)
        return false, new_window_error
    end
    local ok_buffer, buffer_error = switch_buffer(bufnr)
    if not ok_buffer then
        if api.nvim_win_is_valid(new_win) then
            pcall(api.nvim_win_close, new_win, true)
        end
        return false, buffer_error
    end
    return true
end

local function notify(message, level)
    vim.notify(message, level, { title = "Buffer Picker" })
end

---@param opts? { scope?: UserBufferScope }
function M.pick(opts)
    opts = opts or {}
    local scope = opts.scope or "all"
    local scope_config = picker_scopes[scope]
    if scope_config == nil then
        notify("Unknown buffer picker scope: " .. tostring(scope), vim.log.levels.ERROR)
        return
    end
    local ok_builtin, builtin = pcall(require, "telescope.builtin")
    if not ok_builtin then
        notify("Telescope is unavailable: " .. tostring(builtin), vim.log.levels.ERROR)
        return
    end

    -- Telescope copies picker options before computing this dynamic width.
    local has_candidate = false
    local max_bufnr = 1
    for _, bufnr in ipairs(api.nvim_list_bufs()) do
        if buffer_option(bufnr, "buflisted") == true then
            max_bufnr = math.max(max_bufnr, bufnr)
        end
        if M.should_include_buffer(bufnr, scope) then
            has_candidate = true
        end
    end
    if not has_candidate then
        notify(scope_config.empty_message, vim.log.levels.INFO)
        return
    end

    local picker_opts = {
        bufnr_width = #tostring(max_bufnr),
        show_all_buffers = true,
        prompt_title = scope_config.prompt_title,
    }
    local default_entry_maker
    picker_opts.entry_maker = function(entry)
        if type(entry) ~= "table" or not M.should_include_buffer(entry.bufnr, scope) then
            return nil
        end
        default_entry_maker = default_entry_maker
            or require("telescope.make_entry").gen_from_buffer(picker_opts)
        return default_entry_maker(entry)
    end
    picker_opts.attach_mappings = function(prompt_bufnr, map)
        local actions = require("telescope.actions")
        local action_state = require("telescope.actions.state")

        local function select_buffer(mode)
            return function()
                local entry = action_state.get_selected_entry()
                local picker = action_state.get_current_picker(prompt_bufnr)
                local bufnr = entry and entry.bufnr
                local original_win = picker and picker.original_win_id
                if type(bufnr) ~= "number" or bufnr <= 0 or not api.nvim_buf_is_valid(bufnr) then
                    notify("Selected buffer is no longer valid", vim.log.levels.ERROR)
                    return
                end

                actions.close(prompt_bufnr)
                local success, err = M.open_buffer(bufnr, mode, original_win)
                if not success then
                    notify(err or "Could not open selected buffer", vim.log.levels.ERROR)
                end
            end
        end

        map({ "i", "n" }, "<CR>", select_buffer("smart"), { desc = "Select buffer" })
        map({ "i", "n" }, "<C-t>", select_buffer("tab"), { desc = "Open buffer in new tab" })
        map({ "i", "n" }, "<C-x>", select_buffer("split"), { desc = "Open buffer in horizontal split" })
        map({ "i", "n" }, "<C-v>", select_buffer("vsplit"), { desc = "Open buffer in vertical split" })
        map("n", "t", select_buffer("tab"), { desc = "Open buffer in new tab" })
        map("n", "n", select_buffer("split"), { desc = "Open buffer in horizontal split" })
        map("n", "v", select_buffer("vsplit"), { desc = "Open buffer in vertical split" })
        return true
    end

    builtin.buffers(picker_opts)
end

function M.setup()
    if configured then
        return
    end

    api.nvim_create_user_command("PickBuffers", function()
        M.pick({ scope = "all" })
    end, { desc = "Pick any open buffer" })
    api.nvim_create_user_command("PickShownBuffers", function()
        M.pick({ scope = "shown" })
    end, { desc = "Pick a buffer shown in a normal window" })
    api.nvim_create_user_command("PickProtectedHiddenBuffers", function()
        M.pick({ scope = "protected_hidden" })
    end, { desc = "Pick a hidden modified buffer or running terminal" })
    api.nvim_create_user_command("PickHiddenBuffers", function()
        M.pick({ scope = "hidden" })
    end, { desc = "Pick a buffer without a normal window" })
    vim.keymap.set("n", "gba", "<Cmd>PickBuffers<CR>", {
        desc = "Go to buffer (all)",
        silent = true,
    })
    vim.keymap.set("n", "gbb", "<Cmd>PickShownBuffers<CR>", {
        desc = "Go to shown buffer",
        silent = true,
    })
    vim.keymap.set("n", "gbH", "<Cmd>PickProtectedHiddenBuffers<CR>", {
        desc = "Go to protected hidden buffer",
        silent = true,
    })
    vim.keymap.set("n", "gbh", "<Cmd>PickHiddenBuffers<CR>", {
        desc = "Go to hidden buffer",
        silent = true,
    })
    configured = true
end

return M
