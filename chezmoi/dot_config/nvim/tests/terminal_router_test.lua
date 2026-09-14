local original_arcadia_root = vim.env.ARCADIA_ROOT
local original_remote_arcadia_root = vim.env.REMOTE_ARCADIA_ROOT
local original_remote_terminal = vim.env.NVIM_TERMINAL_VIA_QSSH

vim.env.ARCADIA_ROOT = "/home/test/local/example"
vim.env.REMOTE_ARCADIA_ROOT = "/home/test/remote/example"
vim.env.NVIM_TERMINAL_VIA_QSSH = "1"

local terminal_router = require("user.terminal_router")
terminal_router.setup()

assert(terminal_router.is_remote(), "qanvim terminal mode should default to remote")
assert(vim.deep_equal(terminal_router.command("/home/test/local/example/project"), {
    "qssh",
    "--cwd",
    "/home/test/remote/example/project",
}), "remote terminal command")
assert(vim.fn.exists(":WorkstationTerminal") == 2, "terminal routing command")
assert(vim.fn.exists(":TerminalModeToggle") == 2, "terminal toggle command")

terminal_router.toggle()
assert(not terminal_router.is_remote(), "toggle should select local terminals")
assert(terminal_router.command() == nil, "local terminal should use the built-in shell")

terminal_router.toggle()
assert(terminal_router.is_remote(), "second toggle should restore remote terminals")

local ok = pcall(terminal_router.command, "/tmp")
assert(not ok, "remote terminal should reject cwd outside Arcadia")

terminal_router.setup()

vim.env.ARCADIA_ROOT = original_arcadia_root
vim.env.REMOTE_ARCADIA_ROOT = original_remote_arcadia_root
vim.env.NVIM_TERMINAL_VIA_QSSH = original_remote_terminal
print("terminal_router: tests passed")
