local M = {}

local xdg_config_home = vim.env.XDG_CONFIG_HOME or vim.env.HOME .. "/.config"
local vcsh_repo_d = vim.env.VCSH_REPO_D or xdg_config_home .. "/vcsh/repo.d"

--- @class (exact) optsObj
--- @field xdg_config_home string Plugin's working value for $XDG_CONFIG_HOME
--- @field vcsh_repo_d string Plugin's working value for $VCSH_REPO_D

--- @type optsObj
local defaultOpts = {
	xdg_config_home = xdg_config_home,
	vcsh_repo_d = vcsh_repo_d,
}

local globalOpts = defaultOpts

-- INFO Functions as a "one-element stack". Either it's empty or it
-- contains one saved GIT_DIR entry
local savedGitDir = {}

local getShortRepoName = function(path)
	local basename = vim.fs.basename(path)
	if not basename then
		return nil
	end
	local repo = string.gsub(basename, "%.git$", "")
	return repo
end

M.setup = function(userOpts)
	globalOpts = vim.tbl_deep_extend("force", defaultOpts, userOpts)
end

--- @param repo string A vcsh repository name
M.vcshEnter = function(repo)
	if not repo then
		return
	end
	local repoPath = globalOpts.vcsh_repo_d .. "/" .. repo
	if vim.fn.filereadable(repoPath) then
		if #savedGitDir == 0 and vim.env.GIT_DIR ~= nil then
			table.insert(savedGitDir, vim.env.GIT_DIR)
		end
		vim.env.GIT_DIR = repoPath
		vim.notify("Entered vcsh repo " .. getShortRepoName(repo))
	else
		vim.notify("No vcsh repo at" .. repoPath, vim.log.levels.ERROR, { title = "vcsh-enter" })
	end
end

M.vcshExit = function()
	-- set $GIT_DIR to the saved value, or to nil
	-- (unset it) if no saved value exists
	vim.env.GIT_DIR = table.remove(savedGitDir)
	vim.notify("Left vcsh repo")
end

M.vcshShow = function()
	local result = vim.env.GIT_DIR and getShortRepoName(vim.env.GIT_DIR)
	vim.print(result or "Not in a vcsh repo")
end

local getRepos = function()
	local repos = {}
	local fs = vim.uv.fs_scandir(globalOpts.vcsh_repo_d)
	if not fs then
		vim.notify("Unable to open vcsh_repo_d: " .. globalOpts.vcsh_repo_d)
		return nil
	end

	while true do
		local name, type = vim.uv.fs_scandir_next(fs)
		if name == nil then
			break
		end
		if type == "directory" then
			table.insert(repos, name)
		end
	end

	return repos
end

M.vcshEnterSelect = function()
	local repos = getRepos()
	if not repos then
		return
	end
	vim.ui.select(repos, {
		prompt = "Choose a vcsh repo",
		format_item = function(item)
			return getShortRepoName(item)
		end,
	}, M.vcshEnter)
end

vim.api.nvim_create_user_command("VcshEnter", M.vcshEnterSelect, { desc = "Enter a vcsh repo" })
vim.api.nvim_create_user_command("VcshExit", M.vcshExit, { desc = "Exit a vcsh repo" })
vim.api.nvim_create_user_command("VcshShow", M.vcshShow, { desc = "Show the current repo" })

return M
