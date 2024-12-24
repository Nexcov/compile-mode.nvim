local Compile = {}
Compile.__index = Compile

local REG_GROUPS = '^(.*):(%d+):(%d+):?'
local REG_FORMAT = '^.*:%d+:%d+:?'

Compile.CM_WIN_OPTS = { split = 'below'}
--TODO: Get errors list in a quickfix and get that list in the compilation buffer

local function handle_previous_running_instance(cm)
    vim.ui.input({ prompt = "CMD is running, kill it? [Y]es, [N]o : ", default = "Y" },
        function(input)
            if not input then return end
            input = input:lower()
            if input == 'y' then
                cm:kill_cmd(9) --SIGKILL
                vim.api.nvim_buf_delete(cm.buf, { force = true })
                vim.cmd('CompileMode')
            elseif input == 'n' then
                print("Not killed")
            else
                print("Invalid input expected Y or N")
            end
        end)
end

function Compile:new()
    local cm = setmetatable({}, self)
    if vim.g.compile_mode_ins ~= nil then
        if vim.g.compile_mode_ins.cmd_running then
            handle_previous_running_instance(vim.g.compile_mode_ins)
            return nil
        else
            vim.api.nvim_buf_delete(vim.g.compile_mode_ins.buf, { force = true })
        end
    end
    -- 1 index :(
    cm.cur_error = 1
    cm.errors = {}
    cm.cmd_running = false
    cm.cur_line = 0

    -- WIN from cm was called
    cm.mw = vim.api.nvim_get_current_win()
    cm.ns = vim.api.nvim_create_namespace("CompileNS")

    -- [[ BUFFER ]]
    cm.buf = vim.api.nvim_create_buf(true, true)
    vim.api.nvim_set_option_value("swapfile", false, { buf = cm.buf })
    vim.api.nvim_set_option_value("buftype", "nofile", { buf = cm.buf })
    vim.api.nvim_set_option_value("buflisted", true, { buf = cm.buf })
    cm:set_keymaps()
    cm:set_autocmds()
    vim.g.compile_mode_ins = cm
    return cm
end

function Compile:set_keymaps()
    vim.keymap.set('n', '<Esc>', function() vim.api.nvim_command('bd!') end, { buffer = self.buf, silent = true})
    vim.keymap.set('n', 'q', function() vim.api.nvim_command('bd!') end, { buffer = self.buf, silent = true })

    vim.keymap.set('n', '<CR>', function()
        local l = vim.api.nvim_win_get_cursor(self.win)[1];
        self:open_file(l)
    end,  { buffer = self.buf , silent = true})

    vim.keymap.set('n', '<C-v>', function()
        local l = vim.api.nvim_win_get_cursor(self.win)[1];
        self:open_file(l, 'vsplit')
    end,  { buffer = self.buf , silent = true})

    vim.keymap.set('n', '<leader>ne', function()
        self:next_error()
    end, { buffer = self.buf, silent = true })

    vim.keymap.set('n', '<leader>pe', function()
        self:prev_error()
    end, { buffer = self.buf, silent = true })

    vim.keymap.set({ 'n', 'i' }, '<C-c>', function() 
        self:kill_cmd(2)
    end, { buffer = self.buf, silent = true })
end

function Compile:set_autocmds()
    vim.api.nvim_create_autocmd({ "BufDelete" }, {
        group = "CompileMode",
        buffer = self.buf,
        callback = function()
            if self.cmd_running then
                vim.ui.input({ prompt = "CMD is running, kill it? [Y]es, [N]o : ", default = "Y" },
                    function(input) 
                        if not input then return end
                        input = input:lower()
                        if input == 'y' then
                            self:kill_cmd(9) --SIGKILL
                        elseif input == 'n' then
                            print("Not killed")
                        else
                            print("Invalid input expected Y or N")
                        end
                    end)
            end
        end
    })
end

function Compile:set_hl_marks(str, line, hl)
    local file, row, col = str:match(REG_GROUPS)
    vim.api.nvim_buf_set_extmark(self.buf, self.ns, line, 0, {
        end_col = #file,
        hl_group = hl,
    })
    -- file   :
    vim.api.nvim_buf_set_extmark(self.buf, self.ns, line, #file + 1, {
        end_col = #file + 1 + #row,
        hl_group = "CompilationYellow",
    })
    -- file   :   row    :
    vim.api.nvim_buf_set_extmark(self.buf, self.ns, line, #file + 1 + #row + 1, {
        end_col = #file + 1 + #row + 1 +  #col,
        hl_group = "CompilationGreen",
    })

    vim.api.nvim_buf_set_extmark(self.buf, self.ns, line, 0, {
        end_col = #file + 1 + #row + 1 +  #col,
        hl_group = "Underline"
    })
end

function Compile:handle_line(data)
        -- Cant use '\n' symbol in buf_set_lines
        local lines = vim.split(data, '\n')
        for _, v in ipairs(lines) do
            if v ~= '' then
                vim.api.nvim_buf_set_lines(self.buf, -1, -1, false, { v })
                self.cur_line = self.cur_line + 1

                -- Search for file:row:col format
                local fmt = v:match(REG_FORMAT)
                if fmt then
                    table.insert(self.errors, self.cur_line + 1)
                    local hl = "CompilationRed"
                    local low = v:lower()

                    if low:match("warning") then
                        hl = "CompilationBrown"
                    elseif low:match("note") then
                        hl = "CopilationGreen"
                    end

                    self:set_hl_marks(fmt, self.cur_line, hl)
                end
            end
        end
end

function Compile:open_file(line, mode)
    -- Dont know why is that weird
    local str_l = vim.api.nvim_buf_get_lines(self.buf, line - 1, line, false)
    local format = str_l[1]:match(REG_FORMAT)
    if format then
        local file, row, col = format:match(REG_GROUPS)
        -- Dont know if this is slow
        file = file:gsub("^[^%w/]+", ""):gsub("$[^%w]+", "")
        if mode then
            vim.api.nvim_command(mode..'| e '..file)
        else
            if (vim.api.nvim_win_is_valid(self.mw)) then
                vim.api.nvim_set_current_win(self.mw)
                vim.api.nvim_command('e '..file)
            else
                vim.api.nvim_command('vsplit | e'..file)
            end
        end
        vim.fn.cursor(row, col)
    end
end

function Compile:next_error()
    if self.cur_error + 1 < #self.errors + 1 then
        self.cur_error = self.cur_error + 1
    else
        self.cur_error = 1
    end
    local row =  self.errors[self.cur_error]
    vim.fn.cursor(row, 0)
    self:open_file(row)
end

function Compile:prev_error()
    if self.cur_error - 1 < 1 then
        self.cur_error = #self.errors
    else
        self.cur_error = self.cur_error - 1
    end
    local row =  self.errors[self.cur_error]
    vim.fn.cursor(row, 0)
    self:open_file(row)
end

function Compile:handle_exit_code(code)
    if not code or not vim.api.nvim_buf_is_valid(self.buf) then return end
    local comp = "Compilation"
    local fin = " finished"
    local l = vim.api.nvim_buf_line_count(self.buf) + 1
    if code ~= 0 then
        local ab = " abnormaly "
        vim.api.nvim_buf_set_lines(self.buf, -1, -1, false, { 
            "",
            comp..fin..ab..'with code '..code..' at '..os.date()
        })
        vim.api.nvim_buf_set_extmark(self.buf, self.ns, l, #comp + #fin, {
            end_col = #comp + #fin + #ab,
            hl_group = "CompilationRed",
        })
        vim.api.nvim_buf_set_extmark(self.buf, self.ns, l, #comp + #fin + #ab + 10, {
            end_col = #comp + #fin + #ab + 10 +  #tostring(code),
            hl_group = "CompilationRed",
        })

        vim.notify("Compilation exit with code: "..code, vim.log.levels.ERROR)
    else
        vim.api.nvim_buf_set_lines(self.buf, -1, -1, false, { 
            "",
            comp..fin..' at '..os.date()
        })
        vim.api.nvim_buf_set_extmark(self.buf, self.ns, l, #comp, {
            end_col = #comp + #fin,
            hl_group = "CompilationGreen",
        })

        vim.notify("Compilation exit with code: "..code, vim.log.levels.INFO)
    end
end

function Compile:call_cmd(cmd)
    self.cmd_running = true
    vim.api.nvim_buf_set_name(self.buf, "*compilation* '"..cmd.."'")
    self.stdout = vim.uv.new_pipe()
    self.stderr = vim.uv.new_pipe()
    self.handle, self.pid = vim.uv.spawn('sh', {
        args = { '-c', cmd },
        cwd = vim.uv.cwd(),
        stdio = { nil, self.stdout, self.stderr },
    },
        function(code, signal)
            -- ON cmd exit
            vim.schedule(function()
                self.stdout:close()
                self.stderr:close()
                self:handle_exit_code(code)
                self.cmd_running = false
            end)
        end)

    self.stdout:read_start(function(err, data)
        assert(not err, err)
        if data then
            vim.schedule(function() self:handle_line(data) end)
        end
    end)

    self.stderr:read_start(function(err, data)
        assert(not err, err)
        if data then
            vim.schedule(function() self:handle_line(data) end)
        end
    end)
end

function Compile:kill_cmd(signal)
    if not self.handle or not self.pid then return end
    if self.cmd_running then
        self.handle:kill(signal)
    else
        vim.notify("Process is not running", vim.log.levels.ERROR)
    end
end

return Compile
