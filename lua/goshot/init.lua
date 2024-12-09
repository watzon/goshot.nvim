---@diagnostic disable: undefined-global
---@meta

local M = {}

-- Function to get visual selection
local function get_visual_selection()
  local start_pos = vim.fn.getpos("'<")
  local end_pos = vim.fn.getpos("'>")
  if start_pos[2] == 0 and end_pos[2] == 0 then
    return nil
  end
  return {
    start_line = start_pos[2],  -- Keep as 1-based for goshot
    end_line = end_pos[2],      -- Keep as 1-based for goshot
  }
end

-- Function to get file path or create temporary file if needed
local function get_file_path()
  local bufname = vim.api.nvim_buf_get_name(0)
  
  -- If buffer has a file, use it directly
  if bufname and bufname ~= "" then
    return bufname, "", false
  end

  -- Otherwise, create a temporary file
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local tmp_file = os.tmpname()
  local file = io.open(tmp_file, "w")
  if file then
    file:write(table.concat(lines, "\n"))
    file:close()
    return tmp_file, "", true
  end
  return nil, "Failed to create temporary file", true
end

-- Function to get the current buffer's language
local function get_buffer_language()
  local ft = vim.bo.filetype
  -- Map Neovim filetypes to goshot language names if needed
  local lang_map = {
    ["javascript"] = "js",
    ["typescript"] = "ts",
    ["markdown"] = "md",
  }
  return lang_map[ft] or ft
end

-- Function to run goshot command
function M.create_screenshot(args)
  local file_path, error_msg, is_tmp = get_file_path()
  if not file_path then
    vim.notify(error_msg, vim.log.levels.ERROR)
    return
  end

  local selection = get_visual_selection()
  local line_range = ""
  if selection then
    line_range = string.format("--line-range %d..%d", selection.start_line, selection.end_line)
  end

  local lang = get_buffer_language()
  -- Build the command with base options and any additional args
  local cmd = string.format("goshot %s -c --language %s %s", file_path, lang, line_range)
  if args and args ~= "" then
    cmd = cmd .. " " .. args
  end

  -- Store command output
  local output = {}
  local stderr = {}

  vim.fn.jobstart(cmd, {
    on_stdout = function(_, data)
      if data then
        vim.list_extend(output, data)
      end
    end,
    on_stderr = function(_, data)
      if data then
        vim.list_extend(stderr, data)
      end
    end,
    on_exit = function(_, exit_code)
      -- Clean up temporary file if we created one
      if is_tmp then
        os.remove(file_path)
      end
      
      if exit_code == 0 then
        vim.notify("Screenshot created and copied to clipboard", vim.log.levels.INFO)
      else
        -- Show detailed error information
        local error_msg = table.concat(stderr, "\n")
        if error_msg == "" then
          error_msg = table.concat(output, "\n")
        end
        if error_msg == "" then
          error_msg = "Unknown error"
        end
        
        vim.notify(string.format(
          "Failed to create screenshot (exit code %d)\nCommand: %s\nError: %s",
          exit_code, cmd, error_msg
        ), vim.log.levels.ERROR)
      end
    end
  })
end

-- Setup function for the plugin
function M.setup(opts)
  -- Create the Goshot command with optional arguments
  vim.api.nvim_create_user_command("Goshot", function(cmd_opts)
    M.create_screenshot(cmd_opts.args)
  end, {
    nargs = "*",  -- Accept any number of arguments
    desc = "Create a screenshot of current buffer or selection. Example: Goshot -t dracula --corner-radius 8",
    range = true, -- Allow command to work with visual selections
    complete = function(arglead, cmdline, cursorpos)
      -- Basic completion for common goshot flags
      local flags = {
        "--theme", "-t",
        "--corner-style", "-C",
        "--background", "-b",
        "--corner-radius",
        "--highlight-lines",
        "--line-range",
        "--font-family",
        "--font-size",
        "--highlight-lines"
      }
      return vim.tbl_filter(function(flag)
        return flag:find(arglead, 1, true) == 1
      end, flags)
    end,
  })
end

return M
