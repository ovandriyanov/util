local M = {}

local api = vim.api
local configured = false
local remote = vim.env.NVIM_TERMINAL_VIA_QSSH == "1"

local function normalize(path)
    return vim.fs.normalize(vim.fn.fnamemodify(path, ":p"))
end

local function remote_cwd(cwd)
    local local_root = vim.env.ARCADIA_ROOT
    local remote_root = vim.env.REMOTE_ARCADIA_ROOT
    if not local_root or local_root == "" or not remote_root or remote_root == "" then
        error("remote terminal requires ARCADIA_ROOT and REMOTE_ARCADIA_ROOT")
    end

    cwd = normalize(cwd or vim.fn.getcwd(0))
    local_root = normalize(local_root)
    remote_root = normalize(remote_root)
    if cwd == local_root then
        return remote_root
    end
    if cwd:sub(1, #local_root + 1) ~= local_root .. "/" then
        error("terminal cwd is outside ARCADIA_ROOT: " .. cwd)
    end
    return remote_root .. cwd:sub(#local_root + 1)
end

function M.command(cwd)
    if not remote then
        return nil
    end
    return { "qssh", "--cwd", remote_cwd(cwd) }
end

function M.open(cwd)
    local command = M.command(cwd)
    if command then
        vim.cmd.terminal({ args = command })
    else
        vim.cmd.terminal()
    end
end

function M.is_remote()
    return remote
end

function M.toggle()
    remote = not remote
    vim.notify("Terminal mode: " .. (remote and "remote QYP" or "local"))
    return remote
end

function M.setup()
    if configured then
        return
    end

    api.nvim_create_user_command("WorkstationTerminal", function(args)
        M.open(args.args ~= "" and args.args or nil)
    end, { nargs = "?", complete = "dir" })
    api.nvim_create_user_command("TerminalModeToggle", M.toggle, {})
    vim.cmd([[
        cnoreabbrev <expr> terminal
            \ getcmdtype() ==# ':' && getcmdline() ==# 'terminal'
            \ ? 'WorkstationTerminal' : 'terminal'
    ]])
    configured = true
end

return M
