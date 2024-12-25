local M = {}

--- @param dir string
local function ensure_path(dir)
  if vim.fn.isdirectory(dir) ~= 1 then
    vim.loop.fs_mkdir(dir, 488)
  end
end

--- @class ProjectNotesState
--- @field win integer
--- @field buf integer
local state = {
  win = -1,
  buf = -1,
}

--- @param data_dir string
--- @param file_name string
--- @return integer
local function create_buffer(data_dir, file_name)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_option_value("filetype", "markdown", { buf = buf })
  vim.api.nvim_set_option_value("buflisted", false, { buf = buf })
  vim.api.nvim_set_option_value("buftype", "acwrite", { buf = buf })
  vim.api.nvim_buf_set_name(buf, "PROJECTNOTE")

  local r_file = assert(io.open(data_dir .. '/' .. file_name, "r"))
  local r_content = r_file:read("all")
  r_file:close()

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(r_content, "\n", {}))
  vim.api.nvim_set_option_value("modified", false, { buf = buf })

  vim.api.nvim_create_autocmd("BufWriteCmd", {
    buffer = buf,
    callback = function()
      local content = vim.api.nvim_buf_get_text(buf, 0, 0, -1, -1, {})
      local file = assert(io.open(data_dir .. '/' .. file_name, "w"))
      for _, v in pairs(content) do
        file:write(v .. "\n")
      end
      file:close()

      if vim.api.nvim_win_is_valid(state.win) then
        vim.api.nvim_win_hide(state.win)
        state.win = -1
      end
    end
  })

  vim.api.nvim_create_autocmd("BufLeave", {
    buffer = buf,
    callback = function()
      if vim.api.nvim_win_is_valid(state.win) then
        vim.api.nvim_win_hide(state.win)
        state.win = -1
      end
    end,
  })
  return buf
end

--- @param data_dir string
--- @param file_name string
local function toggle_project_notes(data_dir, file_name)
  -- toggle
  if vim.api.nvim_win_is_valid(state.win) then
    vim.api.nvim_win_hide(state.win)
    state.win = -1
    return
  end

  if not vim.api.nvim_buf_is_valid(state.buf) then
    state.buf = create_buffer(data_dir, file_name)
  end

  local width = math.floor(vim.o.columns * 0.8)
  local height = math.floor(vim.o.lines * 0.8)

  local col = math.floor((vim.o.columns - width) / 2)
  local row = math.floor((vim.o.lines - height) / 2)

  local win_config = {
    relative = "editor",
    width = width,
    title = "Project Notes",
    height = height,
    col = col,
    row = row,
    style = "minimal", -- No borders or extra UI elements
    border = "rounded",
  }

  state.win = vim.api.nvim_open_win(state.buf, true, win_config)

  return {}
end

--- @class ProjectNotesOpts
---
--- @param opt ProjectNotesOpts
function M.setup(opt)
  opt = opt or {}
  local data_path = string.format("%s/projectnotes", vim.fn.stdpath("data"))
  ensure_path(data_path)
  local s = vim.split(vim.fn.getcwd(), "/")
  local project_name = s[#s]
  local file_name = vim.fn.sha256(project_name) .. ".md"

  vim.api.nvim_create_user_command("ProjectNotesToggle", function() toggle_project_notes(data_path, file_name) end,
    {})
end

return M
