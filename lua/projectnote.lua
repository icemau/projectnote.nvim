local M = {}

--- Ensures that the given path exists.
--- @param dir string
local function ensure_path(dir)
  if vim.fn.isdirectory(dir) ~= 1 then
    vim.uv.fs_mkdir(dir, 488)
  end
end

--- @class ProjectNoteState
--- @field win integer The current window
--- @field buf integer The buffer holding the notes
local state = {
  win = -1,
  buf = -1,
}

--- Closes the current state window if it is open.
local function close_window()
  if vim.api.nvim_win_is_valid(state.win) then
    vim.api.nvim_win_hide(state.win)
    state.win = -1
  end
end

--- Sets an option for the current state buffer.
--- @param name string
--- @param value string | boolean
local function buf_set_option(name, value)
  if vim.api.nvim_buf_is_valid(state.buf) then
    vim.api.nvim_set_option_value(name, value, { buf = state.buf })
  end
end

local augroup = vim.api.nvim_create_augroup("ProjectNote", {})

--- Applies all autocmds to the state buffer
--- @param settings Settings
local function buf_set_autocmds(settings)
  if not vim.api.nvim_buf_is_valid(state.buf) then
    return
  end

  vim.api.nvim_create_autocmd("BufWriteCmd", {
    buffer = state.buf,
    group = augroup,
    callback = function()
      local content = vim.api.nvim_buf_get_text(state.buf, 0, 0, -1, -1, {})
      local file = assert(io.open(settings.data_path .. '/' .. settings.file_name, "w"))
      for _, line in pairs(content) do
        file:write(line .. "\n")
      end
      file:close()

      vim.api.nvim_set_option_value("modified", false, { buf = state.buf })

      if settings.close_write then
        close_window()
      end
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

--- Initializes the state buffer
--- @param settings Settings
local function init_buffer(settings)
  if vim.api.nvim_buf_is_valid(state.buf) then
    return
  end

  state.buf = vim.api.nvim_create_buf(false, true)

  buf_set_option("filetype", "markdown")
  buf_set_option("buflisted", false)
  buf_set_option("buftype", "acwrite")
  vim.api.nvim_buf_set_name(state.buf, "PROJECTNOTE")

  local file_path = settings.data_path .. '/' .. settings.file_name
  local file = io.open(file_path, 'r')
  local lines = {}
  if file then
    lines = vim.split(file:read("all"), "\n")
    file:close()
  end

  vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
  vim.api.nvim_set_option_value("modified", false, { buf = state.buf })

  buf_set_autocmds(settings)

  vim.keymap.set("n", "q", close_window, { buffer = state.buf })
  vim.keymap.set("n", "<Esc>", close_window, { buffer = state.buf })
end

--- Opens/Closes the current projectnote
--- @param settings Settings
local function toggle_project_notes(settings)
  if vim.api.nvim_win_is_valid(state.win) then
    close_window()
    return
  end

  init_buffer(settings)

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

--- @class ProjectNoteOpts
--- @field data_path string? Path to directory storing the notes.
--- @field close_write boolean? If `true` the note window will be closed after a write.
---
--- @class Settings
--- @field data_path string
--- @field file_name string
--- @field close_write boolean

--- @param opts ProjectNoteOpts
function M.setup(opts)
  opts = opts or {}

  local s = vim.split(vim.fn.getcwd(), "/")
  local project_name = s[#s]

  --- @type Settings
  local settings = {
    data_path = opts.data_path or string.format("%s/projectnote", vim.fn.stdpath("data")),
    file_name = vim.fn.sha256(project_name) .. ".md",
    close_write = opts.close_write or false,
  }

  ensure_path(settings.data_path)

  vim.api.nvim_create_user_command("ProjectNoteToggle",
    function()
      toggle_project_notes(settings)
    end,
    {})
end

return M
