vim.api.nvim_set_hl(0, 'CompilationGreen',  { fg = '#73d936', bg = nil } )
vim.api.nvim_set_hl(0, 'CompilationRed',    { fg = '#f43841', bg = nil} )
vim.api.nvim_set_hl(0, 'CompilationYellow', { fg = '#ffdd33', bg = nil} )
vim.api.nvim_set_hl(0, 'CompilationBrown',  { fg = '#cc8c3c', bg = nil} )
vim.api.nvim_set_hl(0, 'CompilationBlue',   { fg = '#96a6c8', bg = nil} )
vim.api.nvim_set_hl(0, 'Underline', { underline = true, fg = nil } )

vim.api.nvim_create_augroup("CompileMode", { clear = true })
vim.g.compile_mode_ins = nil

vim.api.nvim_create_user_command('CompileMode', 
    function(opt)
        vim.ui.input( { prompt = 'Compile cmd: ', default = vim.g.compile_mode_last_cmd, completion = "shellcmd" },
            function(input)
                if not input then return end
                local Compile = require('compile')
                local cm = Compile:new()
                if cm ~= nil then
                    cm:call_cmd(input)
                    vim.g.compile_mode_last_cmd = input
                    cm.win = vim.api.nvim_open_win(cm.buf, true, Compile.CM_WIN_OPTS) 
                end
            end)
    end, {})
