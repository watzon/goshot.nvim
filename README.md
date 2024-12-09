# goshot.nvim

A Neovim plugin for creating beautiful code screenshots using [goshot](https://github.com/watzon/goshot).

<div align="center">
    <img src="./.github/example.png">
</div>

## Installation

You should be able to install this plugin using your favorite package manager. For copy to clipboard to work, you may need to install `xclip`, `wl-clipboard`, or `pbcopy` on your system.

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
    "watzon/goshot.nvim",
    cmd = "Goshot",
}
```

Using [packer.nvim](https://github.com/wbthomason/packer.nvim):

```lua
use({
    "watzon/goshot.nvim",
    cmd = "Goshot",
})
```

## Usage

The plugin provides the following command:

- `:Goshot [options]` - Create a screenshot of the current buffer or visual selection. Since it uses the `goshot` binary, any options supplied in your config file will be used, leading to more reproducible screenshots. See the [goshot wiki](https://github.com/watzon/goshot/wiki/Configuration) for more details.

### Examples

```vim
" Create a screenshot of the entire buffer
:Goshot

" Create a screenshot with a specific theme
:Goshot -t dracula

" Create a screenshot with custom styling
:Goshot -t dracula --corner-radius 8 --background "#282a36"

" Create a screenshot of selected lines (in visual mode)
:'<,'>Goshot
```

### Visual Mode

You can use the `:Goshot` command in visual mode to capture only the selected lines. Simply:
1. Enter visual mode (`v`, `V`, or `<C-v>`)
2. Select the lines you want to capture
3. Type `:Goshot` (it will automatically add the `'<,'>` range)

The plugin will automatically pass the correct line range to goshot.
