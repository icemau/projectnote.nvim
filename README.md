# projectnotes.nvim

Quickly take notes for your projects without the concern where to put them.

## Installation

Using [lazy](https://github.com/LazyVim/LazyVim)
```lua
{
  'icemau/projectnotes.nvim'
  config = function()
    local projectnotes = require('projectnotes')
    projectnotes.setup {}
  end 
}
```

## Usage

After installing this plugin you get access to the `ProjectNotesToggle` command.
This allows you to open/close a floating window in which you can take your notes.

Add the following keymap to your configuration to get quick access to your notes.
```lua
vim.keymap.set("n", "<leader>tp", vim.cmd.ProjectNotesToggle)
```
