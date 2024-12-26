local M = {}

--- @class Note
--- @field settings ProjectNoteSettings
--- @field state ProjectNoteState
local Note = {}
Note.__index = Note

--- @param settings ProjectNoteSettings
--- @return Note
function Note:new(settings)
  local note = setmetatable({
    state = {
      buf = vim.api.nvim_create_buf(false, true),
      win = -1,
    },
    settings = settings,
  }, self)

  note:init_buffer()

  return note
end

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

--- Closes the current state window if it is open.
function Note:close_window()
  if vim.api.nvim_win_is_valid(self.state.win) then
    vim.api.nvim_win_hide(self.state.win)
    self.state.win = -1
  end
end

--- Sets an option for the current state buffer.
--- @param name string
--- @param value string | boolean
function Note:buf_set_option(name, value)
  if vim.api.nvim_buf_is_valid(self.state.buf) then
    vim.api.nvim_set_option_value(name, value, { buf = self.state.buf })
  end
end

local augroup = vim.api.nvim_create_augroup("ProjectNote", {})

--- Applies all autocmds to the state buffer
function Note:buf_set_autocmds()
  if not vim.api.nvim_buf_is_valid(self.state.buf) then
    return
  end

  vim.api.nvim_create_autocmd("BufWriteCmd", {
    buffer = self.state.buf,
    group = augroup,
    callback = function()
      local content = vim.api.nvim_buf_get_text(self.state.buf, 0, 0, -1, -1, {})
      local file = assert(io.open(self.settings.data_path .. '/' .. self.settings.file_name, "w"))
      for _, line in pairs(content) do
        file:write(line .. "\n")
      end
      file:close()

      vim.api.nvim_set_option_value("modified", false, { buf = self.state.buf })

      if self.settings.close_write then
        self:close_window()
      end
    end
  })

  vim.api.nvim_create_autocmd("BufLeave", {
    buffer = self.state.buf,
    group = augroup,
    callback = function()
      self:close_window()
    end,
  })
end

--- Initializes the state buffer
function Note:init_buffer()
  assert(self.state.buf)
  self:buf_set_option("filetype", "markdown")
  self:buf_set_option("buflisted", false)
  self:buf_set_option("buftype", "acwrite")
  vim.api.nvim_buf_set_name(self.state.buf, "PROJECTNOTE")

  local file_path = self.settings.data_path .. '/' .. self.settings.file_name
  local file = io.open(file_path, 'r')
  local lines = {}
  if file then
    lines = vim.split(file:read("all"), "\n")
    file:close()
  end

  vim.api.nvim_buf_set_lines(self.state.buf, 0, -1, false, lines)
  self:buf_set_option("modified", false)

  self:buf_set_autocmds()

  vim.keymap.set("n", "q", function () self:close_window() end, { buffer = self.state.buf })
  vim.keymap.set("n", "<Esc>", function () self:close_window() end, { buffer = self.state.buf })
end

--- Opens/Closes the current note
function Note:toggle()
  if vim.api.nvim_win_is_valid(self.state.win) then
    self:close_window()
    return
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

  self.state.win = vim.api.nvim_open_win(self.state.buf, true, win_config)
end


--- @class ProjectNoteOpts
--- @field data_path string? Path to directory storing the notes.
--- @field close_write boolean? If `true` the note window will be closed after a write.

--- @class ProjectNoteSettings
--- @field data_path string
--- @field file_name string
--- @field close_write boolean

--- @param opts ProjectNoteOpts
function M.setup(opts)
  opts = opts or {}

  local s = vim.split(vim.fn.getcwd(), "/")
  local project_name = s[#s]

  --- @type ProjectNoteSettings
  local settings = {
    data_path = opts.data_path or string.format("%s/projectnote", vim.fn.stdpath("data")),
    file_name = vim.fn.sha256(project_name) .. ".md",
    close_write = opts.close_write or false,
  }

  ensure_path(settings.data_path)

  local note = Note:new(settings)

  vim.api.nvim_create_user_command("ProjectNoteToggle",
    function()
      note:toggle()
    end,
    {})
end

return M