local M = {}

local api = vim.api
local configured = false
local pending = {}

local function is_terminal(bufnr)
    if not api.nvim_buf_is_valid(bufnr) then
        return false
    end
    local ok, buftype = pcall(api.nvim_get_option_value, "buftype", { buf = bufnr })
    return ok and buftype == "terminal"
end

local function desired_mode(bufnr)
    local ok, mode = pcall(api.nvim_buf_get_var, bufnr, "desired_mode")
    return ok and mode or nil
end

local function set_buffer_desired_mode(bufnr, mode)
    if not is_terminal(bufnr) then
        return false
    end
    local ok = pcall(api.nvim_buf_set_var, bufnr, "desired_mode", mode)
    return ok
end

---@param mode "n"|"t"
---@return boolean
function M.set_desired_mode(mode)
    if mode ~= "n" and mode ~= "t" then
        return false
    end

    local winid = api.nvim_get_current_win()
    pending[winid] = nil
    return set_buffer_desired_mode(api.nvim_get_current_buf(), mode)
end

function M.restore_later()
    local winid = api.nvim_get_current_win()
    local bufnr = api.nvim_get_current_buf()
    if not is_terminal(bufnr) or desired_mode(bufnr) ~= "t" then
        return
    end

    local token = {}
    pending[winid] = token
    vim.schedule(function()
        if pending[winid] ~= token then
            return
        end
        pending[winid] = nil

        if not api.nvim_win_is_valid(winid)
            or not api.nvim_buf_is_valid(bufnr)
            or api.nvim_get_current_win() ~= winid
            or api.nvim_get_current_buf() ~= bufnr
            or not is_terminal(bufnr)
            or desired_mode(bufnr) ~= "t"
        then
            return
        end

        if api.nvim_get_mode().mode ~= "t" then
            pcall(vim.cmd, "startinsert")
        end
    end)
end

function M.setup()
    if configured then
        return
    end

    local group = api.nvim_create_augroup("UserTerminalMode", { clear = true })
    api.nvim_create_autocmd({ "TermOpen", "TermEnter" }, {
        group = group,
        callback = function(args)
            set_buffer_desired_mode(args.buf, "t")
        end,
    })
    api.nvim_create_autocmd({ "WinEnter", "BufEnter", "CmdlineLeave" }, {
        group = group,
        callback = M.restore_later,
    })

    for _, bufnr in ipairs(api.nvim_list_bufs()) do
        if is_terminal(bufnr) and desired_mode(bufnr) == nil then
            set_buffer_desired_mode(bufnr, "t")
        end
    end
    configured = true
end

return M
