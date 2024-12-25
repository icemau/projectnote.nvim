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

local function close_window()
  if vim.api.nvim_win_is_valid(state.win) then
    vim.api.nvim_win_hide(state.win)
    state.win = -1
  end
end

--- @param name string
--- @param value string | boolean
local function buf_set_option(name, value)
  if vim.api.nvim_buf_is_valid(state.buf) then
    vim.api.nvim_set_option_value(name, value, { buf = state.buf })
  end
end

local augroup = vim.api.nvim_create_augroup("ProjectNotes", {})

--- @param data_dir string
--- @param file_name string
local function buf_set_autocmds(data_dir, file_name)
  if not vim.api.nvim_buf_is_valid(state.buf) then
    return
  end

  vim.api.nvim_create_autocmd("BufWriteCmd", {
    buffer = state.buf,
    group = augroup,
    callback = function()
      local content = vim.api.nvim_buf_get_text(state.buf, 0, 0, -1, -1, {})
      local file = assert(io.open(data_dir .. '/' .. file_name, "w"))
      for _, line in pairs(content) do
        file:write(line .. "\n")
      end
      file:close()

      vim.api.nvim_set_option_value("modified", false, { buf = state.buf })

      close_window()
    end
  })

  vim.api.nvim_create_autocmd("BufLeave", {
    buffer = state.buf,
    group = augroup,
    callback = function()
      close_window()
    end,
  })
end

--- @param data_dir string
--- @param file_name string
local function init_buffer(data_dir, file_name)
  if vim.api.nvim_buf_is_valid(state.buf) then
    return
  end

  state.buf = vim.api.nvim_create_buf(false, true)

  buf_set_option("filetype", "markdown")
  buf_set_option("buflisted", false)
  buf_set_option("buftype", "acwrite")
  vim.api.nvim_buf_set_name(state.buf, "PROJECTNOTE")

  local file = io.open(data_dir .. '/' .. file_name, "r")
  local lines = {}
  if file then
    lines = vim.split(file:read("all"), "\n")
    file:close()
  end

  vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
  vim.api.nvim_set_option_value("modified", false, { buf = state.buf })

  buf_set_autocmds(data_dir, file_name)
end

--- @param data_dir string
--- @param file_name string
local function toggle_project_notes(data_dir, file_name)
  if vim.api.nvim_win_is_valid(state.win) then
    close_window()
    return
  end

  init_buffer(data_dir, file_name)

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
end

--- @class ProjectNotesOpts

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
