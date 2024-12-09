---@meta

---@class vim
---@field api table
---@field fn table
---@field bo table
---@field notify function
---@field log table
---@field list_extend function
---@field tbl_filter function
---@field tbl_deep_extend function
---@field deepcopy function
---@field json table
---@field loop table
---@field inspect function
---@field tbl_map function
vim = {}

---@class vim.log
---@field levels table
vim.log = {
    levels = {
        ERROR = 1,
        WARN = 2,
        INFO = 3,
        DEBUG = 4,
        TRACE = 5
    }
}

---@class vim.bo
---@field filetype string
vim.bo = {}
