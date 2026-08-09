local ok, tabby = pcall(require, "tabby")
if not ok then
    return
end

local tab_name = require("tabby.feature.tab_name")

local MIN_CONTENT_WIDTH = 15
local MAX_CONTENT_WIDTH = 23
local TAB_WEDGE_WIDTH = 2
local PROCESS_CACHE_MILLISECONDS = 1500
local ELLIPSIS = "…"

local highlights = {
    fill = "UserTablineFill",
    meta = "UserTablineMeta",
    active = {
        tab = "UserTablineActive",
        ordinal = "UserTablineActiveOrdinal",
        terminal = "UserTablineActiveTerminal",
        opencode = "UserTablineActiveOpenCode",
        modified = "UserTablineActiveModified",
    },
    inactive = {
        tab = "UserTablineInactive",
        ordinal = "UserTablineInactiveOrdinal",
        terminal = "UserTablineInactiveTerminal",
        opencode = "UserTablineInactiveOpenCode",
        modified = "UserTablineInactiveModified",
    },
}

local ignored_filetypes = {
    help = true,
    nerdtree = true,
    qf = true,
}

local known_roots_cache
local process_cache = {}
local terminal_timer
local terminal_timer_running = false
local configured = false
local STATE_KEY = "_user_workspace_tabline_state"

local function display_width(text)
    return vim.fn.strdisplaywidth(text)
end

local function clean_text(text)
    return tostring(text or ""):gsub("%c", "")
end

local function fit_text(text, width)
    if width <= 0 then
        return ""
    end

    text = clean_text(text)
    if display_width(text) <= width then
        return text .. string.rep(" ", width - display_width(text))
    end

    local ellipsis_width = display_width(ELLIPSIS)
    if width <= ellipsis_width then
        return ELLIPSIS
    end

    local result = ""
    local available = width - ellipsis_width
    for length = 1, vim.fn.strchars(text) do
        local prefix = vim.fn.strcharpart(text, 0, length)
        if display_width(prefix) > available then
            break
        end
        result = prefix
    end
    result = result .. ELLIPSIS
    return result .. string.rep(" ", width - display_width(result))
end

local function escape_tabline(text)
    return text:gsub("%%", "%%%%")
end

local function normalize_path(path)
    if type(path) ~= "string" or path == "" then
        return nil
    end

    local ok_expand, expanded = pcall(vim.fn.expand, path)
    if not ok_expand or expanded == "" then
        return nil
    end

    local ok_normalize, normalized = pcall(vim.fs.normalize, expanded)
    if not ok_normalize or normalized == "" then
        return nil
    end
    return normalized
end

local function load_known_roots()
    if known_roots_cache ~= nil
        and type(vim.g.olan_root_dirs) == "table"
        and type(vim.g.olan_path_aliases) == "table"
    then
        return known_roots_cache
    end

    if vim.fn.exists("*LoadPathAliases") == 1 then
        pcall(vim.fn.LoadPathAliases)
    end

    local root_dirs = vim.g.olan_root_dirs
    local aliases = vim.g.olan_path_aliases
    if type(root_dirs) ~= "table" then
        root_dirs = {}
    end
    if type(aliases) ~= "table" then
        aliases = {}
    end

    local names_by_path = {}
    for _, alias in pairs(aliases) do
        if type(alias) == "table" then
            local path = normalize_path(alias.path)
            if path ~= nil and type(alias.name) == "string" and alias.name ~= "" then
                names_by_path[path] = alias.name
            end
        end
    end

    local roots = {}
    local seen = {}
    for _, root_dir in ipairs(root_dirs) do
        local path = normalize_path(root_dir)
        if path ~= nil and not seen[path] then
            seen[path] = true
            roots[#roots + 1] = {
                path = path,
                name = names_by_path[path] or vim.fs.basename(path),
            }
        end
    end
    table.sort(roots, function(left, right)
        return #left.path > #right.path
    end)

    known_roots_cache = roots
    return roots
end

local function path_is_within(path, root)
    if path == root then
        return true
    end
    if root == "/" then
        return path:sub(1, 1) == "/"
    end
    return path:sub(1, #root + 1) == root .. "/"
end

local function known_project_name(path)
    path = normalize_path(path)
    if path == nil then
        return nil
    end

    for _, root in ipairs(load_known_roots()) do
        if path_is_within(path, root.path) then
            return root.name, #root.path
        end
    end
    return nil
end

local function best_known_project_name(paths)
    local best_name
    local best_root_length = -1
    for _, path in ipairs(paths) do
        local name, root_length = known_project_name(path)
        if name ~= nil and root_length > best_root_length then
            best_name = name
            best_root_length = root_length
        end
    end
    return best_name
end

local function path_basename(path)
    path = normalize_path(path)
    if path == nil then
        return nil
    end
    local basename = vim.fs.basename(path)
    return basename ~= "" and basename or path
end

local function buffer_option(bufnr, option, fallback)
    local ok_option, value = pcall(vim.api.nvim_get_option_value, option, { buf = bufnr })
    if ok_option then
        return value
    end
    return fallback
end

local function window_cwd(winid)
    local ok_position, position = pcall(vim.fn.win_id2tabwin, winid)
    if not ok_position or type(position) ~= "table" or position[1] == 0 or position[2] == 0 then
        return nil
    end

    local ok_cwd, cwd = pcall(vim.fn.getcwd, position[2], position[1])
    if ok_cwd then
        return normalize_path(cwd)
    end
    return nil
end

local function tab_window_records(tabid)
    local ok_windows, windows = pcall(vim.api.nvim_tabpage_list_wins, tabid)
    if not ok_windows then
        return {}
    end

    local ok_current, current_win = pcall(vim.api.nvim_tabpage_get_win, tabid)
    if not ok_current then
        current_win = nil
    end
    table.sort(windows, function(left, right)
        if left == current_win then
            return true
        end
        if right == current_win then
            return false
        end
        return left < right
    end)

    local records = {}
    for _, winid in ipairs(windows) do
        local ok_config, config = pcall(vim.api.nvim_win_get_config, winid)
        local ok_buffer, bufnr = pcall(vim.api.nvim_win_get_buf, winid)
        if ok_config and config.relative == "" and ok_buffer and vim.api.nvim_buf_is_valid(bufnr) then
            local ok_name, name = pcall(vim.api.nvim_buf_get_name, bufnr)
            records[#records + 1] = {
                id = winid,
                buffer = bufnr,
                buftype = buffer_option(bufnr, "buftype", ""),
                filetype = buffer_option(bufnr, "filetype", ""),
                name = ok_name and name or "",
                cwd = window_cwd(winid),
            }
        end
    end
    return records
end

local function has_displayed_terminal_buffer()
    for _, winid in ipairs(vim.api.nvim_list_wins()) do
        local ok_config, config = pcall(vim.api.nvim_win_get_config, winid)
        local ok_buffer, bufnr = pcall(vim.api.nvim_win_get_buf, winid)
        if ok_config
            and config.relative == ""
            and ok_buffer
            and vim.api.nvim_buf_is_valid(bufnr)
            and buffer_option(bufnr, "buftype", "") == "terminal"
        then
            return true
        end
    end
    return false
end

local function add_candidate(candidates, seen, path)
    path = normalize_path(path)
    if path ~= nil and not seen[path] then
        seen[path] = true
        candidates[#candidates + 1] = path
    end
end

local function regular_file_path(record)
    if record.buftype ~= "" or ignored_filetypes[record.filetype] or record.name == "" then
        return nil
    end
    if record.name:match("^term://") then
        return nil
    end

    return normalize_path(record.name)
end

local function automatic_project_name(records)
    local nerdtree_roots = {}
    for _, record in ipairs(records) do
        if record.filetype == "nerdtree" and record.cwd ~= nil then
            nerdtree_roots[#nerdtree_roots + 1] = record.cwd
        end
    end
    local nerdtree_name = best_known_project_name(nerdtree_roots)
    if nerdtree_name ~= nil then
        return nerdtree_name
    end
    if #nerdtree_roots > 0 then
        return path_basename(nerdtree_roots[1]) or "Untitled"
    end

    local candidates = {}
    local seen_candidates = {}
    local fallback_paths = {}
    local seen_fallback_paths = {}
    local function add_path(path)
        add_candidate(candidates, seen_candidates, path)
        add_candidate(fallback_paths, seen_fallback_paths, path)
    end
    local function add_file(record)
        local path = regular_file_path(record)
        add_candidate(candidates, seen_candidates, path)
        if path ~= nil then
            add_candidate(fallback_paths, seen_fallback_paths, vim.fs.dirname(path))
        end
    end

    local current = records[1]
    if current ~= nil then
        add_path(current.cwd)
        add_file(current)
    end
    for index = 2, #records do
        local record = records[index]
        if record.buftype == "" and not ignored_filetypes[record.filetype] then
            add_path(record.cwd)
        end
    end
    for index = 2, #records do
        add_file(records[index])
    end
    for _, record in ipairs(records) do
        if record.buftype == "terminal" then
            add_path(record.cwd)
        end
    end

    local known_name = best_known_project_name(candidates)
    if known_name ~= nil then
        return known_name
    end
    for _, candidate in ipairs(fallback_paths) do
        local name = path_basename(candidate)
        if name ~= nil and name ~= "" then
            return name
        end
    end
    return "Untitled"
end

local function terminal_channel(bufnr)
    local ok_channel, channel = pcall(function()
        return vim.bo[bufnr].channel
    end)
    if ok_channel and type(channel) == "number" then
        return channel
    end
    return 0
end

local function terminal_is_running(bufnr)
    local channel = terminal_channel(bufnr)
    if channel <= 0 then
        return false
    end

    local ok_wait, statuses = pcall(vim.fn.jobwait, { channel }, 0)
    return ok_wait and type(statuses) == "table" and statuses[1] == -1
end

local function title_identifies_opencode(bufnr)
    local ok_title, title = pcall(vim.api.nvim_buf_get_var, bufnr, "term_title")
    if not ok_title or type(title) ~= "string" then
        return false
    end
    return title:match("^OC%s*|") ~= nil or title:lower():find("opencode", 1, true) ~= nil
end

local function process_identifies_opencode(pid, depth, seen)
    if depth > 16 or seen[pid] then
        return false
    end
    seen[pid] = true

    local ok_process, process = pcall(vim.api.nvim_get_proc, pid)
    if ok_process and type(process) == "table" then
        local process_name = vim.fs.basename(process.name or ""):lower()
        if process_name == "opencode" or process_name == "coding-agent" then
            return true
        end
    end

    local ok_children, children = pcall(vim.api.nvim_get_proc_children, pid)
    if not ok_children or type(children) ~= "table" then
        return false
    end
    for _, child_pid in ipairs(children) do
        if process_identifies_opencode(child_pid, depth + 1, seen) then
            return true
        end
    end
    return false
end

local function terminal_is_opencode(bufnr)
    if title_identifies_opencode(bufnr) then
        return true
    end

    local now = vim.uv.hrtime() / 1000000
    local cached = process_cache[bufnr]
    if cached ~= nil and now - cached.checked_at < PROCESS_CACHE_MILLISECONDS then
        return cached.result
    end

    local result = false
    local channel = terminal_channel(bufnr)
    if channel > 0 then
        local ok_pid, pid = pcall(vim.fn.jobpid, channel)
        if ok_pid and type(pid) == "number" and pid > 0 then
            result = process_identifies_opencode(pid, 0, {})
        end
    end
    process_cache[bufnr] = {
        checked_at = now,
        result = result,
    }
    return result
end

local function build_tab_context(tabid, number, current_tab)
    local records = tab_window_records(tabid)
    local automatic_name = automatic_project_name(records)
    local display_name = tab_name.get(tabid, {
        name_fallback = function()
            return automatic_name
        end,
    })
    display_name = clean_text(display_name)
    if display_name == "" then
        display_name = automatic_name
    end

    local windows = {}
    local buffers = {}
    local seen_buffers = {}
    local has_terminal = false
    local has_opencode = false
    local has_modified = false
    local has_displayed_terminal = false
    for _, record in ipairs(records) do
        windows[#windows + 1] = record.id
        if not seen_buffers[record.buffer] then
            seen_buffers[record.buffer] = true
            buffers[#buffers + 1] = record.buffer
            if record.buftype == "terminal" then
                has_displayed_terminal = true
                if terminal_is_running(record.buffer) then
                    has_terminal = true
                    if terminal_is_opencode(record.buffer) then
                        has_opencode = true
                    end
                end
            elseif buffer_option(record.buffer, "modified", false) then
                has_modified = true
            end
        end
    end

    return {
        id = tabid,
        number = number,
        current = tabid == current_tab,
        windows = windows,
        buffers = buffers,
        automatic_name = automatic_name,
        display_name = display_name,
        has_terminal = has_terminal,
        has_opencode = has_opencode,
        has_modified = has_modified,
    }, has_displayed_terminal
end

local function build_contexts()
    local tabpages = vim.api.nvim_list_tabpages()
    local current_tab = vim.api.nvim_get_current_tabpage()
    local contexts = {}
    local has_displayed_terminal = false
    for number, tabid in ipairs(tabpages) do
        local context, tab_has_terminal = build_tab_context(tabid, number, current_tab)
        contexts[#contexts + 1] = context
        has_displayed_terminal = has_displayed_terminal or tab_has_terminal
    end
    return contexts, has_displayed_terminal
end

local function clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

local function centered_range(current, count, total)
    local start_index = current - math.floor((count - 1) / 2)
    start_index = clamp(start_index, 1, total - count + 1)
    return start_index, start_index + count - 1
end

local function overflow_marker(hidden, left, compact)
    if hidden == 0 then
        return ""
    end
    if compact then
        return tostring(hidden)
    end
    return left and ("‹" .. hidden) or (hidden .. "›")
end

local function overflow_marker_width(hidden, left, compact)
    return display_width(overflow_marker(hidden, left, compact))
end

local function choose_visible_tabs(contexts, available_columns, compact_markers)
    local total = #contexts
    if total == 0 then
        return {}, MIN_CONTENT_WIDTH, 0, 0
    end

    if total * (MIN_CONTENT_WIDTH + TAB_WEDGE_WIDTH) <= available_columns then
        local width = math.floor(available_columns / total - TAB_WEDGE_WIDTH)
        return contexts, clamp(width, MIN_CONTENT_WIDTH, MAX_CONTENT_WIDTH), 0, 0
    end

    local current = 1
    for index, context in ipairs(contexts) do
        if context.current then
            current = index
            break
        end
    end

    local chosen_start = current
    local chosen_end = current
    local range_fits = false
    local max_visible = math.max(
        1,
        math.min(total - 1, math.floor(available_columns / (MIN_CONTENT_WIDTH + TAB_WEDGE_WIDTH)))
    )
    for count = max_visible, 1, -1 do
        local start_index, end_index = centered_range(current, count, total)
        local left_hidden = start_index - 1
        local right_hidden = total - end_index
        local required = count * (MIN_CONTENT_WIDTH + TAB_WEDGE_WIDTH)
            + overflow_marker_width(left_hidden, true, compact_markers)
            + overflow_marker_width(right_hidden, false, compact_markers)
        if required <= available_columns then
            chosen_start = start_index
            chosen_end = end_index
            range_fits = true
            break
        end
    end

    local left_hidden = chosen_start - 1
    local right_hidden = total - chosen_end
    local marker_width = overflow_marker_width(left_hidden, true, compact_markers)
        + overflow_marker_width(right_hidden, false, compact_markers)
    local count = chosen_end - chosen_start + 1
    local width = math.floor((available_columns - marker_width) / count - TAB_WEDGE_WIDTH)
    local minimum_width = range_fits and MIN_CONTENT_WIDTH or 0
    width = clamp(width, minimum_width, MAX_CONTENT_WIDTH)

    local visible = {}
    for index = chosen_start, chosen_end do
        visible[#visible + 1] = contexts[index]
    end
    return visible, width, left_hidden, right_hidden
end

local function tab_node(line, context, content_width, ordinal_width)
    local variant = context.current and highlights.active or highlights.inactive
    local number = tostring(context.number)
    local ordinal_padding = string.rep(" ", ordinal_width - display_width(number))
    local status = " "
    local status_highlight = variant.tab
    if context.has_opencode then
        status = "󰚩"
        status_highlight = variant.opencode
    elseif context.has_terminal then
        status = ""
        status_highlight = variant.terminal
    end
    local modified = context.has_modified and "●" or " "
    local modified_highlight = context.has_modified and variant.modified or variant.tab

    if content_width < ordinal_width + 7 then
        local compact_number = content_width >= ordinal_width and (ordinal_padding .. number)
            or fit_text(number, content_width)
        local remaining = content_width - display_width(compact_number)
        local compact = {
            line.sep("", variant.tab, highlights.fill),
            hl = variant.ordinal,
            click = { "to_tab", context.id },
        }
        if compact_number ~= "" then
            compact[#compact + 1] = compact_number
        end
        if remaining >= 3 then
            local compact_name_width = remaining - 3
            if compact_name_width > 0 then
                compact[#compact + 1] = {
                    escape_tabline(fit_text(context.display_name, compact_name_width)),
                    hl = variant.tab,
                }
            end
            compact[#compact + 1] = { " ", hl = variant.tab }
            compact[#compact + 1] = { status, hl = status_highlight }
            compact[#compact + 1] = { modified, hl = modified_highlight }
        elseif remaining == 2 then
            compact[#compact + 1] = { " ", hl = variant.tab }
            if context.has_terminal then
                compact[#compact + 1] = { status, hl = status_highlight }
            else
                compact[#compact + 1] = { modified, hl = modified_highlight }
            end
        elseif remaining == 1 then
            compact[#compact + 1] = { modified, hl = modified_highlight }
        end
        compact[#compact + 1] = line.sep("", variant.tab, highlights.fill)
        return compact
    end

    local name_width = content_width - ordinal_width - 7

    return {
        line.sep("", variant.tab, highlights.fill),
        " ",
        { ordinal_padding .. number .. " ", hl = variant.ordinal },
        { escape_tabline(fit_text(context.display_name, name_width)), hl = variant.tab },
        { " ", hl = variant.tab },
        { status, hl = status_highlight },
        { " ", hl = variant.tab },
        { modified, hl = modified_highlight },
        { " ", hl = variant.tab },
        line.sep("", variant.tab, highlights.fill),
        hl = variant.tab,
        click = { "to_tab", context.id },
    }
end

local function request_redraw()
    pcall(vim.cmd, "redrawtabline")
end

local function update_terminal_timer(has_displayed_terminal)
    if terminal_timer == nil then
        return
    end
    if has_displayed_terminal and not terminal_timer_running then
        terminal_timer:start(
            PROCESS_CACHE_MILLISECONDS,
            PROCESS_CACHE_MILLISECONDS,
            vim.schedule_wrap(request_redraw)
        )
        terminal_timer_running = true
    elseif not has_displayed_terminal and terminal_timer_running then
        terminal_timer:stop()
        terminal_timer_running = false
    end
end

local function apply_highlights()
    vim.api.nvim_set_hl(0, highlights.fill, { fg = "#333333", bg = "#333333" })
    vim.api.nvim_set_hl(0, highlights.inactive.tab, { fg = "#d0d0d0", bg = "#505050" })
    vim.api.nvim_set_hl(0, highlights.active.tab, { fg = "#333333", bg = "#f0e68c", bold = true })
    vim.api.nvim_set_hl(0, highlights.inactive.ordinal, { fg = "#a8a8a8", bg = "#505050" })
    vim.api.nvim_set_hl(0, highlights.active.ordinal, { fg = "#5f5f00", bg = "#f0e68c", bold = true })
    vim.api.nvim_set_hl(0, highlights.inactive.terminal, { fg = "#5fd7ff", bg = "#505050" })
    vim.api.nvim_set_hl(0, highlights.active.terminal, { fg = "#005f87", bg = "#f0e68c", bold = true })
    vim.api.nvim_set_hl(0, highlights.inactive.opencode, { fg = "#d787ff", bg = "#505050", bold = true })
    vim.api.nvim_set_hl(0, highlights.active.opencode, { fg = "#870087", bg = "#f0e68c", bold = true })
    vim.api.nvim_set_hl(0, highlights.inactive.modified, { fg = "#ff5f5f", bg = "#505050", bold = true })
    vim.api.nvim_set_hl(0, highlights.active.modified, { fg = "#af0000", bg = "#f0e68c", bold = true })
    vim.api.nvim_set_hl(0, highlights.meta, { fg = "#bcbcbc", bg = "#333333" })
end

local function render_line(line)
    local contexts, has_displayed_terminal = build_contexts()
    update_terminal_timer(has_displayed_terminal)

    local current = 1
    for _, context in ipairs(contexts) do
        if context.current then
            current = context.number
            break
        end
    end
    local total = #contexts
    local counter = string.format(" %d/%d ", current, total)
    local overflow_required = total * (MIN_CONTENT_WIDTH + TAB_WEDGE_WIDTH)
        > vim.o.columns - display_width(counter)
    if overflow_required then
        local left_hidden = current - 1
        local right_hidden = total - current
        local minimum_required = display_width(counter)
            + overflow_marker_width(left_hidden, true, false)
            + overflow_marker_width(right_hidden, false, false)
            + TAB_WEDGE_WIDTH
            + display_width(tostring(current))
        if minimum_required > vim.o.columns then
            counter = string.format("%d/%d", current, total)
        end
    end
    local compact_markers = (
        display_width(counter)
            + overflow_marker_width(current - 1, true, false)
            + overflow_marker_width(total - current, false, false)
            + TAB_WEDGE_WIDTH
    ) > vim.o.columns
    local available_columns = math.max(0, vim.o.columns - display_width(counter))
    local visible, content_width, left_hidden, right_hidden = choose_visible_tabs(
        contexts,
        available_columns,
        compact_markers
    )
    local ordinal_width = display_width(tostring(#contexts))

    local nodes = {}
    if left_hidden > 0 then
        nodes[#nodes + 1] = { overflow_marker(left_hidden, true, compact_markers), hl = highlights.meta }
    end
    for _, context in ipairs(visible) do
        nodes[#nodes + 1] = tab_node(line, context, content_width, ordinal_width)
    end
    if right_hidden > 0 then
        nodes[#nodes + 1] = { overflow_marker(right_hidden, false, compact_markers), hl = highlights.meta }
    end
    nodes[#nodes + 1] = line.spacer()
    nodes[#nodes + 1] = { counter, hl = highlights.meta }
    nodes.hl = highlights.fill
    return nodes
end

local M = {}

function M.setup()
    if configured then
        return
    end
    configured = true

    vim.opt.showtabline = 2
    vim.opt.termguicolors = true
    vim.opt.sessionoptions:append("globals")

    local previous_state = rawget(vim, STATE_KEY)
    if type(previous_state) == "table" and previous_state.timer ~= nil then
        pcall(previous_state.timer.stop, previous_state.timer)
        pcall(previous_state.timer.close, previous_state.timer)
    end
    terminal_timer = vim.uv.new_timer()
    rawset(vim, STATE_KEY, { timer = terminal_timer })
    apply_highlights()

    local group = vim.api.nvim_create_augroup("UserWorkspaceTabline", { clear = true })
    vim.api.nvim_create_autocmd("ColorScheme", {
        group = group,
        callback = apply_highlights,
    })
    vim.api.nvim_create_autocmd({
        "BufModifiedSet",
        "BufWinEnter",
        "BufWipeout",
        "DirChanged",
        "TabEnter",
        "TabNew",
        "TabClosed",
        "TermOpen",
        "TermClose",
        "WinClosed",
    }, {
        group = group,
        callback = function(args)
            if args.event == "TermClose" or args.event == "BufWipeout" then
                process_cache[args.buf] = nil
            end
            if args.event == "BufWinEnter"
                or args.event == "BufWipeout"
                or args.event == "TabNew"
                or args.event == "TabClosed"
                or args.event == "TermOpen"
                or args.event == "TermClose"
                or args.event == "WinClosed"
            then
                update_terminal_timer(has_displayed_terminal_buffer())
            end
            request_redraw()
        end,
    })
    vim.api.nvim_create_autocmd("User", {
        group = group,
        pattern = { "NERDTreeInit", "NERDTreeNewRoot" },
        callback = request_redraw,
    })
    vim.api.nvim_create_autocmd("BufWritePost", {
        group = group,
        pattern = vim.fn.expand("~/.vim/path_aliases"),
        callback = function()
            known_roots_cache = nil
            request_redraw()
        end,
    })
    vim.api.nvim_create_autocmd("VimLeavePre", {
        group = group,
        callback = function()
            local timer = terminal_timer
            if timer ~= nil then
                timer:stop()
                timer:close()
                terminal_timer = nil
                terminal_timer_running = false
            end
            local state = rawget(vim, STATE_KEY)
            if type(state) == "table" and state.timer == timer then
                rawset(vim, STATE_KEY, nil)
            end
        end,
    })

    vim.api.nvim_create_user_command("TabNameClear", function()
        tab_name.set(0, "")
        vim.cmd.redrawtabline()
    end, { force = true })

    pcall(vim.api.nvim_del_user_command, "Tabby")
    tabby.setup({
        line = render_line,
        option = {
            tab_name = {
                name_fallback = function(tabid)
                    return automatic_project_name(tab_window_records(tabid))
                end,
            },
        },
    })
    update_terminal_timer(has_displayed_terminal_buffer())
end

M.setup()

return M
