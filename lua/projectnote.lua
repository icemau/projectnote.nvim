local M = {}

--- @class ProjectNoteState
--- @field buf integer The buffer holding the notes
--- @field win integer The current window

--- @class ProjectNoteSettings
--- @field data_path string
--- @field file_name string
--- @field close_write boolean

--- @class Note
--- @field state ProjectNoteState
--- @field settings ProjectNoteSettings
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
  note:read()

  return note
end

--- Initializes the state buffer
function Note:init_buffer()
  assert(self.state.buf)
  self:buf_set_option("filetype", "markdown")
  self:buf_set_option("buflisted", false)
  self:buf_set_option("buftype", "acwrite")
  vim.api.nvim_buf_set_name(self.state.buf, "PROJECTNOTE")

  self:buf_set_autocmds()

  vim.keymap.set("n", "q", function() self:close() end, { buffer = self.state.buf })
  vim.keymap.set("n", "<Esc>", function() self:close() end, { buffer = self.state.buf })
end

--- Reads the content of the note file and puts it into the buffer.
function Note:read()
  local file_path = self.settings.data_path .. '/' .. self.settings.file_name
  local file = io.open(file_path, 'r')
  local lines = {}
  if file then
    lines = vim.split(file:read("all"), "\n")
    file:close()
  end

  vim.api.nvim_buf_set_lines(self.state.buf, 0, -1, false, lines)
  self:buf_set_option("modified", false)
end

--- Writes the content of the buffer into the note file.
function Note:write()
  local content = vim.api.nvim_buf_get_text(self.state.buf, 0, 0, -1, -1, {})
  local file = assert(io.open(self.settings.data_path .. '/' .. self.settings.file_name, "w"))
  for _, line in ipairs(content) do
    file:write(line .. "\n")
  end
  file:close()

  self:buf_set_option("modified", false)
end

--- Sets option for the current state buffer.
--- @param name string
--- @param value string | boolean
function Note:buf_set_option(name, value)
  if vim.api.nvim_buf_is_valid(self.state.buf) then
    vim.api.nvim_set_option_value(name, value, { buf = self.state.buf })
  end
end

--- Applies all autocmds to the state buffer
function Note:buf_set_autocmds()
  if not vim.api.nvim_buf_is_valid(self.state.buf) then
    return
  end

  local augroup = vim.api.nvim_create_augroup("ProjectNote", {})

  vim.api.nvim_create_autocmd("BufWriteCmd", {
    buffer = self.state.buf,
    group = augroup,
    callback = function()
      self:write()

      if self.settings.close_write then
        self:close()
      end
    end
  })

  vim.api.nvim_create_autocmd("BufLeave", {
    buffer = self.state.buf,
    group = augroup,
    callback = function()
      self:close()
    end,
  })
end

--- Opens/Closes the current note
function Note:toggle()
  if self:is_open() then
    self:close()
  else
    self:open()
  end
end

--- @return boolean is_open true if there is a window displaying the buffer
function Note:is_open()
  return self.state.win ~= -1 and vim.api.nvim_win_is_valid(self.state.win)
end

--- Opens the current state window if it is open.
function Note:open()
  if vim.api.nvim_win_is_valid(self.state.win) then
    -- Window is open ,do nothing.
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

--- Closes the current state window if it is open.
function Note:close()
  if not vim.api.nvim_win_is_valid(self.state.win) then
    -- Window is closed, do nothing.
    return
  end

  vim.api.nvim_win_hide(self.state.win)
  self.state.win = -1
end

--- @class ProjectNoteOpts
--- @field data_path string? Path to directory storing the notes.
--- @field close_write boolean? If `true` the note window will be closed after a write.

--- @param opts ProjectNoteOpts
function M.setup(opts)
  opts = opts or {}

  local project_key = ""
  if vim.fn.isdirectory(".git") then
    -- Get the first commit id and use it as project key.
    -- This should assure getting the same note even when moving the project.
    project_key = vim.trim(vim.fn.system("git rev-list --max-parents=0 HEAD"))
  else
    -- Else hash the current working directory and use it as project key.
    project_key = vim.fn.sha256(vim.fn.getcwd())
  end

  --- @type ProjectNoteSettings
  local settings = {
    data_path = opts.data_path or string.format("%s/projectnote", vim.fn.stdpath("data")),
    file_name = project_key .. ".md",
    close_write = opts.close_write or false,
  }

  if not vim.fn.isdirectory(settings.data_path) then
    vim.uv.fs_mkdir(settings.data_path, 488)
  end

  local note = Note:new(settings)

  vim.api.nvim_create_user_command("ProjectNoteToggle",
    function()
      note:toggle()
    end,
    {})
end

return M
