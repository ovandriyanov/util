local api = vim.api
local terminal_mode = require("user.terminal_mode")

local original_hidden = vim.o.hidden
vim.o.hidden = true
terminal_mode.setup()

local tests = {}
local channels = {}

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

local function leave_terminal_mode()
    if api.nvim_get_mode().mode == "t" then
        api.nvim_feedkeys(api.nvim_replace_termcodes("<C-\\><C-N>", true, false, true), "nx", false)
        vim.wait(100, function()
            return api.nvim_get_mode().mode ~= "t"
        end)
    end
end

local function reset_editor()
    leave_terminal_mode()
    for _, channel in ipairs(channels) do
        pcall(vim.fn.jobstop, channel)
    end
    channels = {}

    local keep = api.nvim_create_buf(true, false)
    api.nvim_win_set_buf(0, keep)
    for _, bufnr in ipairs(api.nvim_list_bufs()) do
        if bufnr ~= keep and api.nvim_buf_is_valid(bufnr) then
            pcall(api.nvim_buf_delete, bufnr, { force = true })
        end
    end
end

local function create_terminal()
    local bufnr = api.nvim_create_buf(true, false)
    api.nvim_win_set_buf(0, bufnr)
    local channel = vim.fn.jobstart({ "/bin/sh", "-c", "sleep 30" }, { term = true })
    expect(channel > 0, "terminal job should start")
    channels[#channels + 1] = channel
    return bufnr
end

local function intercept_startinsert(callback)
    local original_cmd = vim.cmd
    local calls = 0
    vim.cmd = function(command)
        if command == "startinsert" then
            calls = calls + 1
            return
        end
        return original_cmd(command)
    end

    local ok, err = xpcall(function()
        callback(function()
            return calls
        end)
    end, debug.traceback)
    vim.cmd = original_cmd
    if not ok then
        error(err, 0)
    end
    return calls
end

test("TermOpen records terminal mode intent", function()
    local bufnr = create_terminal()
    expect_equal(vim.b[bufnr].desired_mode, "t", "desired terminal mode")
end)

test("desired mode can be changed explicitly", function()
    local bufnr = create_terminal()
    expect(terminal_mode.set_desired_mode("n"), "normal intent should be accepted")
    expect_equal(vim.b[bufnr].desired_mode, "n", "desired normal mode")
    expect(terminal_mode.set_desired_mode("t"), "terminal intent should be accepted")
    expect_equal(vim.b[bufnr].desired_mode, "t", "desired terminal mode")
end)

test("restoration enters terminal mode when the terminal remains current", function()
    create_terminal()
    leave_terminal_mode()
    terminal_mode.set_desired_mode("t")
    local calls = intercept_startinsert(function(call_count)
        terminal_mode.restore_later()
        expect(vim.wait(100, function()
            return call_count() > 0
        end), "terminal mode restoration should be requested")
    end)
    expect_equal(calls, 1, "startinsert calls")
end)

test("restoration does not leak into a replacement buffer", function()
    create_terminal()
    leave_terminal_mode()
    terminal_mode.set_desired_mode("t")
    local target
    local calls = intercept_startinsert(function()
        terminal_mode.restore_later()
        target = api.nvim_create_buf(true, false)
        api.nvim_buf_set_name(target, "test://terminal-mode/replacement")
        api.nvim_win_set_buf(0, target)
        vim.wait(100, function()
            return false
        end)
    end)

    expect_equal(api.nvim_get_current_buf(), target, "replacement buffer")
    expect_equal(calls, 0, "startinsert calls")
end)

test("entering a terminal buffer restores its remembered mode", function()
    local terminal = create_terminal()
    leave_terminal_mode()
    terminal_mode.set_desired_mode("t")

    local target = api.nvim_create_buf(true, false)
    api.nvim_buf_set_name(target, "test://terminal-mode/focus-target")
    api.nvim_win_set_buf(0, target)
    local calls = intercept_startinsert(function(call_count)
        api.nvim_win_set_buf(0, terminal)
        expect(vim.wait(100, function()
            return call_count() > 0
        end), "focus regain should request terminal mode")
    end)
    expect_equal(calls, 1, "startinsert calls")
end)

test("normal mode intent suppresses restoration", function()
    local terminal = create_terminal()
    leave_terminal_mode()
    terminal_mode.set_desired_mode("n")

    local target = api.nvim_create_buf(true, false)
    api.nvim_buf_set_name(target, "test://terminal-mode/normal-target")
    api.nvim_win_set_buf(0, target)
    local calls = intercept_startinsert(function()
        api.nvim_win_set_buf(0, terminal)
        vim.wait(100, function()
            return false
        end)
    end)
    expect_equal(calls, 0, "startinsert calls")
end)

test("setup is idempotent", function()
    terminal_mode.setup()
    terminal_mode.setup()
    expect(true)
end)

local completed = 0
for _, scenario in ipairs(tests) do
    reset_editor()
    local ok, err = xpcall(scenario.callback, debug.traceback)
    local cleanup_ok, cleanup_error = pcall(reset_editor)
    if not ok then
        vim.o.hidden = original_hidden
        error(string.format("FAILED: %s\n%s", scenario.name, err), 0)
    end
    if not cleanup_ok then
        vim.o.hidden = original_hidden
        error(string.format("CLEANUP FAILED: %s\n%s", scenario.name, cleanup_error), 0)
    end
    completed = completed + 1
end

vim.o.hidden = original_hidden
print(string.format("terminal_mode: %d tests passed", completed))
