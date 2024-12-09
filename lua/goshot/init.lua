---@diagnostic disable: undefined-global
---@meta

local M = {}

-- Default configuration
local default_config = {
  binary = "goshot", -- Default to looking in PATH
  auto_install = false, -- Whether to automatically install goshot if not found
}

local config = vim.deepcopy(default_config)

-- Function to find goshot binary
local function find_goshot()
  if vim.fn.executable(config.binary) == 1 then
    return config.binary
  end
  return nil
end

-- Function to get latest goshot release info from GitHub
local function get_latest_release()
  local handle = io.popen("curl -s https://api.github.com/repos/watzon/goshot/releases/latest")
  if not handle then return nil end
  
  local result = handle:read("*a")
  handle:close()
  
  if not result then return nil end
  
  -- Parse JSON response
  local success, release = pcall(vim.json.decode, result)
  if not success then return nil end
  
  return release
end

-- Function to install goshot
local function install_goshot()
  -- Get system info
  local system = vim.loop.os_uname()
  local os_name = system.sysname -- Keep original case
  local arch = system.machine:lower()
  
  -- Map arch names
  local arch_map = {
    x86_64 = "x86_64",
    aarch64 = "arm64",
  }
  arch = arch_map[arch] or arch
  
  -- Get latest release
  local release = get_latest_release()
  if not release then
    vim.notify("Failed to get latest goshot release info", vim.log.levels.ERROR)
    return false
  end
  
  -- Find the right asset
  local asset_pattern = string.format("goshot_Linux_%s.tar.gz", arch)
  local download_url
  for _, asset in ipairs(release.assets) do
    if asset.name:match(asset_pattern) then
      download_url = asset.browser_download_url
      break
    end
  end
  
  if not download_url then
    vim.notify(string.format("No compatible goshot binary found for your system (%s). Available assets: %s", 
      asset_pattern, 
      vim.inspect(vim.tbl_map(function(a) return a.name end, release.assets))), 
      vim.log.levels.ERROR)
    return false
  end
  
  -- Create temporary directory for download
  local temp_dir = vim.fn.stdpath("cache") .. "/goshot-install"
  vim.fn.mkdir(temp_dir, "p")
  
  -- Download the tarball
  local tarball = temp_dir .. "/goshot.tar.gz"
  local curl_cmd = string.format("curl -sL %s -o %s", download_url, tarball)
  
  if os.execute(curl_cmd) ~= 0 then
    vim.notify("Failed to download goshot", vim.log.levels.ERROR)
    return false
  end
  
  -- Extract the binary
  local tar_cmd = string.format("tar xzf %s -C %s", tarball, temp_dir)
  
  if os.execute(tar_cmd) ~= 0 then
    vim.notify("Failed to extract goshot", vim.log.levels.ERROR)
    return false
  end
  
  -- Create ~/.local/bin if it doesn't exist
  local install_dir = vim.fn.expand("~/.local/bin")
  vim.fn.mkdir(install_dir, "p")
  
  -- Move binary to ~/.local/bin
  local install_path = install_dir .. "/goshot"
  local mv_cmd = string.format("mv %s/goshot %s", temp_dir, install_path)
  
  if os.execute(mv_cmd) ~= 0 then
    vim.notify("Failed to install goshot to " .. install_dir, vim.log.levels.ERROR)
    return false
  end
  
  -- Clean up
  vim.fn.delete(temp_dir, "rf")
  
  -- Make binary executable
  if os.execute("chmod +x " .. install_path) ~= 0 then
    vim.notify("Failed to make goshot executable", vim.log.levels.ERROR)
    return false
  end
  
  -- Update config to use installed binary
  config.binary = install_path
  vim.notify(string.format("Successfully installed goshot to %s\nMake sure %s is in your PATH", install_path, install_dir), vim.log.levels.INFO)
  return true
end

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
  local goshot_bin = find_goshot()
  if not goshot_bin then
    if config.auto_install then
      vim.notify("goshot not found, attempting to install...", vim.log.levels.INFO)
      if not install_goshot() then
        return
      end
      goshot_bin = config.binary
    else
      vim.notify("goshot binary not found. Please install goshot or set the correct binary path", vim.log.levels.ERROR)
      return
    end
  end

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
  local cmd = string.format("%s %s -c --language %s %s", goshot_bin, file_path, lang, line_range)
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
  -- Merge user config with defaults
  config = vim.tbl_deep_extend("force", default_config, opts or {})

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

  -- Create the GoshotInstall command
  vim.api.nvim_create_user_command("GoshotInstall", function()
    install_goshot()
  end, {
    desc = "Install or update the goshot binary",
  })
end

return M
