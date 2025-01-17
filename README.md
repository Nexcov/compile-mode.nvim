Small implementation of compile-mode from emacs in neovim.


Set **CompileMode** command to any keybind:
``` lua
{
    "nexcov/compile-mode.nvim",
    config = function()
        vim.keymap.set('n', '<leader>cm', function() vim.cmd('CompileMode') end)
    end
},
```
