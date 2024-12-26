# projectnote.nvim

Quickly take notes for your projects in Neovim without worrying about where to put them. 

## Installation

Using [lazy](https://github.com/LazyVim/LazyVim)
```lua
{
  'icemau/projectnote.nvim',
  config = function()
    require('projectnote').setup {}
  end 
}
```

## Usage

After installing this plugin you get access to the `ProjectNoteToggle` command.
This allows you to open/close a floating window in which you can take your notes.

Add the following keymap to your configuration to get quick access to your notes.
```lua
vim.keymap.set("n", "<leader>tp", vim.cmd.ProjectNoteToggle)
```
