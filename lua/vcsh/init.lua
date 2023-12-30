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

M.setup = function(userOpts)
	globalOpts = vim.tbl_deep_extend("force", defaultOpts, userOpts)
end

--- @param repo string A vcsh repository name
M.vcshEnter = function(repo)
	local repoPath = globalOpts.vcsh_repo_d .. "/" .. repo
	if vim.fn.filereadable(repoPath) then
		if #savedGitDir == 0 and vim.env.GIT_DIR ~= nil then
			table.insert(savedGitDir, vim.env.GIT_DIR)
		end
		vim.env.GIT_DIR = repoPath
	else
		vim.notify("No vcsh repo at" .. repoPath, vim.log.levels.ERROR, { title = "vcsh-enter" })
	end
end

M.vcshExit = function()
	-- set $GIT_DIR to the saved value, or to nil
	-- (unset it) if no saved value exists
	vim.env.GIT_DIR = table.remove(savedGitDir)
end

local getRepos = function()
	local repos = {}
	local fs = vim.uv.fs_scandir(globalOpts.vcsh_repo_d)
	if not fs then
		vim.notify("Unable to open vcsh_repo_d: " .. globalOpts.vcsh_repo_d)
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
	vim.ui.select(getRepos(), { prompt = "Choose a vcsh repo" }, M.vcshEnter)
end

vim.api.nvim_create_user_command("VcshEnter", M.vcshEnterSelect, { desc = "Enter a vcsh repo" })
vim.api.nvim_create_user_command("VcshExit", M.vcshExit, { desc = "Exit a vcsh repo" })

return M
