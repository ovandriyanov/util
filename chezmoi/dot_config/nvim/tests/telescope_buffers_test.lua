local api = vim.api
local telescope_buffers = require("user.telescope_buffers")

local original_hidden = vim.o.hidden
local original_switchbuf = vim.o.switchbuf
vim.o.hidden = true

local tests = {}

local function test(name, callback)
    tests[#tests + 1] = { name = name, callback = callback }
end

local function expect(condition, message)
    if not condition then
        error(message or "expectation failed", 2)
    end
end

local function expect_equal(actual, expected, message)
    if actual ~= expected then
        error(string.format("%s: expected %s, got %s", message, vim.inspect(expected), vim.inspect(actual)), 2)
    end
end

local function create_buffer(name, lines, modified)
    local bufnr = api.nvim_create_buf(true, false)
    if name ~= nil then
        api.nvim_buf_set_name(bufnr, name)
    end
    if lines ~= nil then
        api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    end
    if modified ~= nil then
        api.nvim_set_option_value("modified", modified, { buf = bufnr })
    end
    return bufnr
end

local function reset_editor()
    local keep = api.nvim_create_buf(true, false)
    api.nvim_win_set_buf(0, keep)
    vim.cmd("silent! tabonly!")
    vim.cmd("silent! only!")

    local current_win = api.nvim_get_current_win()
    for _, winid in ipairs(api.nvim_list_wins()) do
        if winid ~= current_win and api.nvim_win_is_valid(winid) then
            pcall(api.nvim_win_close, winid, true)
        end
    end
    for _, bufnr in ipairs(api.nvim_list_bufs()) do
        if bufnr ~= keep and api.nvim_buf_is_valid(bufnr) then
            pcall(api.nvim_buf_delete, bufnr, { force = true })
        end
    end
    vim.o.hidden = true
    vim.o.switchbuf = original_switchbuf
end

local function unload_buffer(bufnr)
    vim.cmd("silent bunload " .. bufnr)
    expect(api.nvim_buf_is_valid(bufnr), "unloaded buffer should remain valid")
    expect(not api.nvim_buf_is_loaded(bufnr), "buffer should be unloaded")
end

local function create_hidden_terminal(command)
    local bufnr = api.nvim_create_buf(true, false)
    api.nvim_win_set_buf(0, bufnr)
    local channel = vim.fn.jobstart(command, { term = true })
    expect(channel > 0, "terminal job should start")
    api.nvim_win_set_buf(0, api.nvim_create_buf(true, false))
    return bufnr, channel
end

local function normal_window_count(tabpage)
    local count = 0
    for _, winid in ipairs(api.nvim_tabpage_list_wins(tabpage or 0)) do
        local config = api.nvim_win_get_config(winid)
        if config.relative == "" and config.external ~= true and config.hide ~= true then
            count = count + 1
        end
    end
    return count
end

local function listed_buffer_count()
    local count = 0
    for _, bufnr in ipairs(api.nvim_list_bufs()) do
        if api.nvim_buf_is_valid(bufnr) and vim.fn.buflisted(bufnr) == 1 then
            count = count + 1
        end
    end
    return count
end

local function layout_signature()
    local signature = {
        current_tab = api.nvim_get_current_tabpage(),
        current_win = api.nvim_get_current_win(),
        tabs = {},
    }
    for _, tabpage in ipairs(api.nvim_list_tabpages()) do
        local tab = { id = tabpage, windows = {} }
        for _, winid in ipairs(api.nvim_tabpage_list_wins(tabpage)) do
            local config = api.nvim_win_get_config(winid)
            if config.relative == "" then
                tab.windows[#tab.windows + 1] = {
                    id = winid,
                    buffer = api.nvim_win_get_buf(winid),
                }
            end
        end
        signature.tabs[#signature.tabs + 1] = tab
    end
    return vim.inspect(signature)
end

test("pristine unnamed buffer is excluded", function()
    local bufnr = create_buffer(nil, nil, false)
    expect(not telescope_buffers.should_include_buffer(bufnr, "all"))
end)

test("unloaded unnamed listed buffer is excluded", function()
    local bufnr = create_buffer(nil, nil, false)
    unload_buffer(bufnr)
    expect(not telescope_buffers.should_include_buffer(bufnr, "all"))
end)

test("named empty buffer is included", function()
    local bufnr = create_buffer("test://telescope-buffers/named-empty", nil, false)
    expect(telescope_buffers.should_include_buffer(bufnr, "all"))
end)

test("unnamed modified buffer is included", function()
    local bufnr = create_buffer(nil, { "modified" }, true)
    expect(telescope_buffers.should_include_buffer(bufnr, "all"))
    expect(telescope_buffers.should_include_buffer(bufnr, "protected_hidden"))
end)

test("unnamed non-empty unmodified buffer is included", function()
    local bufnr = create_buffer(nil, { "content" }, false)
    expect(telescope_buffers.should_include_buffer(bufnr, "all"))
end)

test("unloaded named buffer is included", function()
    local bufnr = create_buffer("test://telescope-buffers/unloaded", nil, false)
    unload_buffer(bufnr)
    expect(telescope_buffers.should_include_buffer(bufnr, "all"))
    expect(telescope_buffers.should_include_buffer(bufnr, "hidden"))
end)

test("normally displayed buffer is not hidden", function()
    local bufnr = create_buffer("test://telescope-buffers/displayed", nil, false)
    api.nvim_win_set_buf(0, bufnr)
    expect(not telescope_buffers.should_include_buffer(bufnr, "hidden"))
    expect(telescope_buffers.should_include_buffer(bufnr, "shown"))
end)

test("loaded buffer without a normal window is hidden", function()
    local bufnr = create_buffer("test://telescope-buffers/hidden", { "hidden" }, false)
    expect(telescope_buffers.should_include_buffer(bufnr, "hidden"))
    expect(not telescope_buffers.should_include_buffer(bufnr, "shown"))
end)

test("buffer displayed only in a floating window is hidden", function()
    local bufnr = create_buffer("test://telescope-buffers/floating", { "floating" }, false)
    api.nvim_open_win(bufnr, false, {
        relative = "editor",
        width = 20,
        height = 1,
        row = 1,
        col = 1,
        style = "minimal",
        focusable = true,
    })
    expect(telescope_buffers.should_include_buffer(bufnr, "hidden"))
    expect(not telescope_buffers.should_include_buffer(bufnr, "shown"))
end)

test("buffer displayed only in a non-focusable window is hidden", function()
    local bufnr = create_buffer("test://telescope-buffers/non-focusable", { "hidden" }, false)
    api.nvim_open_win(bufnr, false, {
        split = "below",
        win = 0,
        focusable = false,
    })
    expect(telescope_buffers.should_include_buffer(bufnr, "hidden"))
    expect(not telescope_buffers.should_include_buffer(bufnr, "shown"))
end)

test("buffer displayed only in an API-hidden window is hidden", function()
    local bufnr = create_buffer("test://telescope-buffers/api-hidden", { "hidden" }, false)
    api.nvim_open_win(bufnr, false, {
        split = "below",
        win = 0,
        hide = true,
    })
    expect(telescope_buffers.should_include_buffer(bufnr, "hidden"))
    expect(not telescope_buffers.should_include_buffer(bufnr, "shown"))
end)

test("shown scope includes windows in another tab", function()
    local bufnr = create_buffer("test://telescope-buffers/shown-other-tab", { "shown" }, false)
    api.nvim_win_set_buf(0, bufnr)
    vim.cmd.tabnew()
    expect(telescope_buffers.should_include_buffer(bufnr, "shown"))
end)

test("protected hidden scope excludes clean buffers", function()
    local bufnr = create_buffer("test://telescope-buffers/clean-hidden", { "clean" }, false)
    expect(telescope_buffers.should_include_buffer(bufnr, "hidden"))
    expect(not telescope_buffers.should_include_buffer(bufnr, "protected_hidden"))
end)

test("protected hidden scope includes modified buffers", function()
    local bufnr = create_buffer("test://telescope-buffers/modified-hidden", { "modified" }, true)
    expect(telescope_buffers.should_include_buffer(bufnr, "protected_hidden"))
end)

test("protected hidden scope excludes shown modified buffers", function()
    local bufnr = create_buffer("test://telescope-buffers/modified-shown", { "modified" }, true)
    api.nvim_win_set_buf(0, bufnr)
    expect(not telescope_buffers.should_include_buffer(bufnr, "protected_hidden"))
end)

test("protected hidden scope includes running terminals", function()
    local bufnr, channel = create_hidden_terminal({ "/bin/sh", "-c", "sleep 30" })
    expect(telescope_buffers.should_include_buffer(bufnr, "protected_hidden"))
    vim.fn.jobstop(channel)
    vim.fn.jobwait({ channel }, 1000)
end)

test("protected hidden scope excludes exited terminals", function()
    local bufnr, channel = create_hidden_terminal({ "/bin/sh", "-c", "exit 0" })
    vim.fn.jobwait({ channel }, 1000)
    expect(telescope_buffers.should_include_buffer(bufnr, "hidden"))
    expect(not telescope_buffers.should_include_buffer(bufnr, "protected_hidden"))
end)

test("target window comes from the leftmost tab", function()
    local bufnr = create_buffer("test://telescope-buffers/leftmost", { "target" }, false)
    local left_tab = api.nvim_get_current_tabpage()
    local left_win = api.nvim_get_current_win()
    api.nvim_win_set_buf(left_win, bufnr)

    vim.cmd.tabnew()
    api.nvim_win_set_buf(0, bufnr)

    local tabpage, winid = telescope_buffers.find_target_window(bufnr)
    expect_equal(tabpage, left_tab, "target tab")
    expect_equal(winid, left_win, "target window")
end)

test("target window is the upper-leftmost duplicate view", function()
    local bufnr = create_buffer("test://telescope-buffers/position", { "target" }, false)
    api.nvim_win_set_buf(0, bufnr)
    vim.cmd.vsplit()
    vim.cmd.split()

    local expected = {}
    for _, winid in ipairs(api.nvim_tabpage_list_wins(0)) do
        if api.nvim_win_get_buf(winid) == bufnr then
            local position = api.nvim_win_get_position(winid)
            expected[#expected + 1] = { id = winid, row = position[1], col = position[2] }
        end
    end
    table.sort(expected, function(left, right)
        if left.row ~= right.row then
            return left.row < right.row
        end
        if left.col ~= right.col then
            return left.col < right.col
        end
        return left.id < right.id
    end)

    local _, winid = telescope_buffers.find_target_window(bufnr)
    expect_equal(winid, expected[1].id, "position-sorted target window")
end)

test("tabmove changes the target tab", function()
    local bufnr = create_buffer("test://telescope-buffers/reordered", { "target" }, false)
    local first_tab = api.nvim_get_current_tabpage()
    api.nvim_win_set_buf(0, bufnr)

    vim.cmd.tabnew()
    local moved_tab = api.nvim_get_current_tabpage()
    api.nvim_win_set_buf(0, bufnr)

    local initial_target = telescope_buffers.find_target_window(bufnr)
    expect_equal(initial_target, first_tab, "initial target tab")

    vim.cmd("tabmove 0")
    expect_equal(api.nvim_list_tabpages()[1], moved_tab, "reordered first tab")
    local reordered_target = telescope_buffers.find_target_window(bufnr)
    expect_equal(reordered_target, moved_tab, "reordered target tab")
end)

test("smart opening focuses an existing view", function()
    local target = create_buffer("test://telescope-buffers/smart-visible", { "target" }, false)
    local target_tab = api.nvim_get_current_tabpage()
    local target_win = api.nvim_get_current_win()
    api.nvim_win_set_buf(target_win, target)

    vim.cmd.tabnew()
    local launcher = create_buffer("test://telescope-buffers/smart-launcher", { "launcher" }, false)
    local launcher_win = api.nvim_get_current_win()
    api.nvim_win_set_buf(launcher_win, launcher)
    local layout_before = layout_signature()

    local success, err = telescope_buffers.open_buffer(target, "smart", launcher_win)
    expect(success, err)
    expect_equal(api.nvim_get_current_tabpage(), target_tab, "focused target tab")
    expect_equal(api.nvim_get_current_win(), target_win, "focused target window")
    expect_equal(api.nvim_win_get_buf(launcher_win), launcher, "launcher buffer")
    expect_equal(layout_signature():gsub("current_tab = %d+", "current_tab = 0"):gsub("current_win = %d+", "current_win = 0"),
        layout_before:gsub("current_tab = %d+", "current_tab = 0"):gsub("current_win = %d+", "current_win = 0"),
        "smart-open layout")
end)

test("smart opening uses the launching window for a hidden buffer", function()
    local launcher = create_buffer("test://telescope-buffers/hidden-launcher", { "launcher" }, false)
    local launcher_win = api.nvim_get_current_win()
    api.nvim_win_set_buf(launcher_win, launcher)
    local target = create_buffer("test://telescope-buffers/smart-hidden", { "target" }, false)

    local success, err = telescope_buffers.open_buffer(target, "smart", launcher_win)
    expect(success, err)
    expect_equal(api.nvim_get_current_win(), launcher_win, "launching window")
    expect_equal(api.nvim_win_get_buf(launcher_win), target, "selected buffer")
end)

test("smart opening falls back when the launching window is invalid", function()
    local target = create_buffer("test://telescope-buffers/invalid-launcher-target", { "target" }, false)
    vim.cmd.split()
    local invalid_launcher = api.nvim_get_current_win()
    api.nvim_win_close(invalid_launcher, true)
    local fallback_win = api.nvim_get_current_win()

    local success, err = telescope_buffers.open_buffer(target, "smart", invalid_launcher)
    expect(success, err)
    expect_equal(api.nvim_get_current_win(), fallback_win, "fallback window")
    expect_equal(api.nvim_get_current_buf(), target, "fallback buffer")
end)

test("horizontal opening creates one window", function()
    local target = create_buffer("test://telescope-buffers/split", { "target" }, false)
    local launcher_win = api.nvim_get_current_win()
    local tabpage = api.nvim_get_current_tabpage()
    local windows_before = normal_window_count(tabpage)

    local success, err = telescope_buffers.open_buffer(target, "split", launcher_win)
    expect(success, err)
    expect_equal(normal_window_count(tabpage), windows_before + 1, "normal-window count")
    expect_equal(api.nvim_get_current_buf(), target, "split buffer")
end)

test("vertical opening creates one window", function()
    local target = create_buffer("test://telescope-buffers/vsplit", { "target" }, false)
    local launcher_win = api.nvim_get_current_win()
    local tabpage = api.nvim_get_current_tabpage()
    local windows_before = normal_window_count(tabpage)

    local success, err = telescope_buffers.open_buffer(target, "vsplit", launcher_win)
    expect(success, err)
    expect_equal(normal_window_count(tabpage), windows_before + 1, "normal-window count")
    expect_equal(api.nvim_get_current_buf(), target, "vertical split buffer")
end)

test("tab opening creates one tab", function()
    local target = create_buffer("test://telescope-buffers/tab", { "target" }, false)
    local launcher_win = api.nvim_get_current_win()
    local tabs_before = #api.nvim_list_tabpages()

    local success, err = telescope_buffers.open_buffer(target, "tab", launcher_win)
    expect(success, err)
    expect_equal(#api.nvim_list_tabpages(), tabs_before + 1, "tab count")
    expect_equal(api.nvim_get_current_buf(), target, "tab buffer")
end)

test("forced actions ignore switchbuf reuse", function()
    vim.o.switchbuf = "useopen,usetab"
    local target = create_buffer("test://telescope-buffers/forced-visible", { "target" }, false)
    api.nvim_win_set_buf(0, target)

    vim.cmd.tabnew()
    local launcher = create_buffer("test://telescope-buffers/forced-launcher", { "launcher" }, false)
    local launcher_tab = api.nvim_get_current_tabpage()
    local launcher_win = api.nvim_get_current_win()
    api.nvim_win_set_buf(launcher_win, launcher)

    for _, mode in ipairs({ "split", "vsplit" }) do
        local windows_before = normal_window_count(launcher_tab)
        local success, err = telescope_buffers.open_buffer(target, mode, launcher_win)
        expect(success, err)
        expect_equal(api.nvim_get_current_tabpage(), launcher_tab, mode .. " tab")
        expect_equal(normal_window_count(launcher_tab), windows_before + 1, mode .. " window count")
        api.nvim_win_close(api.nvim_get_current_win(), true)
    end

    local tabs_before = #api.nvim_list_tabpages()
    local success, err = telescope_buffers.open_buffer(target, "tab", launcher_win)
    expect(success, err)
    expect_equal(#api.nvim_list_tabpages(), tabs_before + 1, "forced tab count")
end)

test("forced actions do not create listed buffers", function()
    local target = create_buffer("test://telescope-buffers/no-spare", { "target" }, false)
    local launcher_win = api.nvim_get_current_win()
    local listed_before = listed_buffer_count()

    for _, mode in ipairs({ "split", "vsplit", "tab" }) do
        local success, err = telescope_buffers.open_buffer(target, mode, launcher_win)
        expect(success, err)
        expect_equal(listed_buffer_count(), listed_before, mode .. " listed-buffer count")
        api.nvim_win_close(api.nvim_get_current_win(), true)
        expect(api.nvim_win_is_valid(launcher_win), "launcher should remain valid")
    end
end)

test("invalid buffers and failed switches preserve layout", function()
    local deleted = create_buffer("test://telescope-buffers/deleted", { "target" }, false)
    api.nvim_buf_delete(deleted, { force = true })
    local before_invalid = layout_signature()
    local success = telescope_buffers.open_buffer(deleted, "split", api.nvim_get_current_win())
    expect(not success, "deleted buffer should fail")
    expect_equal(layout_signature(), before_invalid, "invalid-buffer layout")

    local target = create_buffer("test://telescope-buffers/rollback", { "target" }, false)
    local before_rollback = layout_signature()
    local group = api.nvim_create_augroup("TelescopeBuffersRollbackTest", { clear = true })
    api.nvim_create_autocmd("WinNew", {
        group = group,
        once = true,
        callback = function()
            if api.nvim_buf_is_valid(target) then
                api.nvim_buf_delete(target, { force = true })
            end
        end,
    })
    local rollback_success = telescope_buffers.open_buffer(target, "split", api.nvim_get_current_win())
    api.nvim_del_augroup_by_id(group)
    expect(not rollback_success, "buffer deletion during split should fail")
    expect_equal(layout_signature(), before_rollback, "rollback layout")
end)

test("setup is idempotent without loading Telescope", function()
    telescope_buffers.setup()
    telescope_buffers.setup()
    expect_equal(vim.fn.exists(":PickBuffers"), 2, "PickBuffers command")
    expect_equal(vim.fn.exists(":PickShownBuffers"), 2, "PickShownBuffers command")
    expect_equal(vim.fn.exists(":PickProtectedHiddenBuffers"), 2, "PickProtectedHiddenBuffers command")
    expect_equal(vim.fn.exists(":PickHiddenBuffers"), 2, "PickHiddenBuffers command")
    expect_equal(vim.fn.maparg("gba", "n"), "<Cmd>PickBuffers<CR>", "all-buffers mapping")
    expect_equal(vim.fn.maparg("gbb", "n"), "<Cmd>PickShownBuffers<CR>", "shown-buffers mapping")
    expect_equal(vim.fn.maparg("gbH", "n"), "<Cmd>PickProtectedHiddenBuffers<CR>", "protected mapping")
    expect_equal(vim.fn.maparg("gbh", "n"), "<Cmd>PickHiddenBuffers<CR>", "hidden-buffers mapping")
    expect(vim.fn.maparg("<M-g>ba", "t"):find("PickBuffers", 1, true) ~= nil, "terminal all-buffers mapping")
    expect(vim.fn.maparg("<M-g>bb", "t"):find("PickShownBuffers", 1, true) ~= nil, "terminal shown mapping")
    expect(vim.fn.maparg("<M-g>bH", "t"):find("PickProtectedHiddenBuffers", 1, true) ~= nil,
        "terminal protected mapping")
    expect(vim.fn.maparg("<M-g>bh", "t"):find("PickHiddenBuffers", 1, true) ~= nil,
        "terminal hidden-buffers mapping")
end)

local completed = 0
for _, scenario in ipairs(tests) do
    reset_editor()
    local ok, err = xpcall(scenario.callback, debug.traceback)
    local cleanup_ok, cleanup_error = pcall(reset_editor)
    if not ok then
        vim.o.hidden = original_hidden
        vim.o.switchbuf = original_switchbuf
        error(string.format("FAILED: %s\n%s", scenario.name, err), 0)
    end
    if not cleanup_ok then
        vim.o.hidden = original_hidden
        vim.o.switchbuf = original_switchbuf
        error(string.format("CLEANUP FAILED: %s\n%s", scenario.name, cleanup_error), 0)
    end
    completed = completed + 1
end

vim.o.hidden = original_hidden
vim.o.switchbuf = original_switchbuf
print(string.format("telescope_buffers: %d tests passed", completed))
