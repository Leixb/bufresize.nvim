local vim_size = {}
local win_size = {}
local winlayout = {}
local can_register = true
local register = function()
	if can_register == false then
		return
	end
	local ui = vim.api.nvim_list_uis()[1]
	vim_size.width = ui.width
	vim_size.height = ui.height
	win_size = {}
	winlayout = {}
	local tabinfo = vim.fn.gettabinfo()
	for _, tab in pairs(tabinfo) do
		win_size[tab.tabnr] = {}
		for _, winid in pairs(tab.windows) do
			win_size[tab.tabnr][winid] = {
				width = vim.api.nvim_win_get_width(winid),
				height = vim.api.nvim_win_get_height(winid),
			}
		end
		winlayout[tab.tabnr] = vim.fn.winlayout(tab.tabnr)
	end
end
local gototab = function(num)
	vim.cmd([[execute "normal! ]] .. tostring(num) .. [[gt"]])
end
local function recurse(layout, old_width, old_height, new_width, new_height, tabnr)
	if layout == nil then
		return
	end
	local name, sublayout = layout[1], layout[2]
	if name == "leaf" then
		local winid = sublayout
		local win_dim = win_size[tabnr][winid]
		if win_dim ~= nil then
			local width_percent = win_dim.width / old_width
			-- minus one for the status line
			local height_percent = win_dim.height / (old_height - 1)
			-- +0.5 for rounding
			pcall(function()
				vim.api.nvim_win_set_width(winid, math.floor(width_percent * new_width + 0.5))
			end)
			pcall(function()
				vim.api.nvim_win_set_height(winid, math.floor(height_percent * (new_height - 1) + 0.5))
			end)
		end
	else
		if name == "row" then
			old_width = old_width - #sublayout + 1
			new_width = new_width - #sublayout + 1
		else
			old_height = old_height - #sublayout + 1
			new_height = new_height - #sublayout + 1
		end
		for _, elem in pairs(sublayout) do
			recurse(elem, old_width, old_height, new_width, new_height, tabnr)
		end
	end
end
local apply = function()
	can_register = false
	local curtabnr = vim.fn.tabpagenr()
	if winlayout[curtabnr] == nil then
		vim.cmd("wincmd =")
	else
		local ui = vim.api.nvim_list_uis()[1]
		for tabnr, layout in pairs(winlayout) do
			gototab(tabnr)
			recurse(
				layout,
				vim_size.width,
				vim_size.height - vim.o.cmdheight,
				ui.width,
				ui.height - vim.o.cmdheight,
				tabnr
			)
		end
		gototab(curtabnr)
	end
	can_register = true
end
local resize = function()
	if vim.fn.mode() == "t" then
		-- have to use this workaround until normal! is supported
		local command = [[<C-\><C-n><cmd>lua require('bufresize').resize()<cr>i]]
		vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(command, true, true, true), "n", true)
	else
		apply()
		register()
	end
end

local function create_augroup(name, events, func)
	vim.cmd("augroup " .. name)
	vim.cmd("autocmd!")
	vim.cmd("autocmd " .. table.concat(events, ",") .. " * " .. func)
	vim.cmd("augroup END")
end

local function create_keymap(mode, from, to, func, opts)
	vim.api.nvim_set_keymap(mode, from, to .. func, opts)
end

local setup = function(cfg)
	local opts = { noremap = true, silent = true }
	cfg = cfg or {}
	cfg.register = cfg.register or {}
	cfg.register.trigger_events = cfg.register.trigger_events or { "WinEnter", "BufWinEnter" }
	cfg.register.keys = cfg.register.keys
		or {
			{ "n", "<C-w><", "<C-w><", opts },
			{ "n", "<C-w>>", "<C-w>>", opts },
			{ "n", "<C-w>+", "<C-w>+", opts },
			{ "n", "<C-w>-", "<C-w>-", opts },
			{ "n", "<C-w>_", "<C-w>_", opts },
			{ "n", "<C-w>=", "<C-w>=", opts },
			{ "n", "<C-w>|", "<C-w>|", opts },
			{ "", "<LeftRelease>", "<LeftRelease>", opts },
			{ "i", "<LeftRelease>", "<LeftRelease><C-o>", opts },
		}
	cfg.resize = cfg.resize or {}
	cfg.resize.trigger_events = cfg.resize.trigger_events or { "VimResized" }
	cfg.resize.keys = cfg.resize.keys or {}
	if #cfg.register.trigger_events > 0 then
		create_augroup("Register", cfg.register.trigger_events, "lua require('bufresize').register()")
	end
	if #cfg.resize.trigger_events > 0 then
		create_augroup("Resize", cfg.resize.trigger_events, "lua require('bufresize').resize()")
	end
	for _, key in pairs(cfg.register.keys) do
		create_keymap(key[1], key[2], key[3], "<cmd>lua require('bufresize').register()<cr>", key[4])
	end
	for _, key in pairs(cfg.resize.keys) do
		create_keymap(key[1], key[2], key[3], "<cmd>lua require('bufresize').resize()<cr>", key[4])
	end
end

return {
	register = register,
	resize = resize,
	setup = setup,
}
