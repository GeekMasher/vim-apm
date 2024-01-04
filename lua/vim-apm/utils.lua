local M = {}

M.vim_apm_group_id = vim.api.nvim_create_augroup("VimApm", {})

function M.now()
    return vim.loop.now()
end

function M.on_close(buf_id, cb)
    vim.api.nvim_create_autocmd('BufUnload', {
        group = M.vim_apm_group_id,
        buffer = buf_id,
        callback = function()
            cb()
        end
    })
end

function M.split(inputstr, sep)
    if sep == nil then
        sep = "%s"
    end
    local t={}
    for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
        table.insert(t, str)
    end
    return t
end

function M.stringify(item)
    if type(item) == "table" then
        item = vim.inspect(item)
    else
        item = tostring(item)
    end

    local items = M.split(item, "\n")
    return table.concat(items, " ")
end

function M.lineify(item)
    if type(item) == "table" then
        item = vim.inspect(item)
    else
        item = tostring(item)
    end

    return M.split(item, "\n")
end

return M
