local args = {...}
local config, targetFile, dest
local fTypes = {}
local c = term.setTextColor
local run = false
local list = false
local branchDir = ""

--[[ 
    git-it => GitHub Repository Downloader by Felipe-Caldeira

    This program allows you to download files and directories from a GitHub repo,
    keeping the file structure intact. The files will be saved at the given destination
    path (defaults to current directory). A whole branch can be downloaded by requesting '/'
    as the file. Individual files can also be run immediately using the [-run] flag.
    Use the [-config] flag to set the default user, repo, and branch, to avoid
    having to set the corresponding flags each call.

    Usage: 
        git-it [-u USER] [-r REPO] [-b BRANCH] FILE [DEST]   -- Download a FILE or directory from a GitHub repo, save to [DEST].
        git-it -run [-u USER] [-r REPO] [-b BRANCH] FILE     -- Run a FILE directly from a GitHub repo.
        git-it -list [-u USER] [-r REPO] [-b BRANCH] [DIR]   -- List all the contents of a GitHub repo. Specify an optional [DIR] path to only view its contents.
        git-it -config                                       -- Set default configurations for GitHub user, repo, and branch.
        git-it -help                                         -- Display this information

    @version: 1.3
]]

function main()
    config, targetFile, dest = processArgs()

    local repo, err = http.get(("https://api.github.com/repos/%s/%s/git/trees/%s?recursive=1"):format(config.user, config.repo, config.branch))
    if not repo then error(err) end

    local repoTree = textutils.unserialiseJSON(repo.readAll()).tree

    fTypes = {}
    for _, file in ipairs(repoTree) do
        fTypes[file.path] = file.type
    end
    fTypes[branchDir] = "tree"

    if list then listContents(targetFile, fTypes) return end

    git_it(targetFile, dest)
end

function git_it(file, destination)
    -- Segment the path to get the file name
    local pathSegments = file:split('/')
    local fileName = pathSegments[#pathSegments]
    local destPath = destination..'/'..fileName

    
    -- File not present
    if fTypes[file] == nil then error("File "..file.." could not be found in remote repository.")
    
    -- Download or run file
    elseif fTypes[file] == "blob" then
        if fs.exists(destPath) then 
            c(colors.yellow) write("Updating ") c(colors.green)  write(destPath..'\n') c(colors.white)
            fs.delete(destPath) 
        else
            c(colors.yellow) write(run and "Running " or "Downloading ") c(colors.green) write(destPath..'\n') c(colors.white)
        end
        -- if not run then local dummyWindow = window.create(term.current(), 1, 1, 0, 0, false) local currWindow = term.redirect(dummyWindow) end
        shell.run("wget", run and "run" or "", ("https://raw.githubusercontent.com/%s/%s/%s/%s"):format(config.user, config.repo, config.branch, file), destPath)
        -- if not run then term.redirect(currWindow) 
        if run then error("", 0) end
      
    -- Download folder
    elseif fTypes[file] == "tree" then
        -- Find all subfiles of the folder
        local dirFiles = getDirFiles(file, fTypes)

        -- Recursively download folder subfiles
        for _, subFile in ipairs(dirFiles) do git_it(subFile, destPath) end
    else
        error("Unknown type: "..fTypes[file])
    end
end



function processArgs()
    -- Show git-it usage
    if #args == 0 or args[1] == '-help' then 
        printUsage()
        error("", 0)
    end

    -- Setting default configs
    if args[1] == "-config" then 
        setConfig() 
        error("", 0)
    end

    -- Get config from saved file if present
    local config = {}
    
    local config_file = fs.open(".git-it.config", "r")
    if config_file ~= nil then 
        config = textutils.unserialise(config_file.readAll()) 
        config_file.close()
    end
    
    -- Process flags
    local usedArgs = {}
    local restArgs = {}
    for i, arg in ipairs(args) do
        if i == 1 and arg == "-run" then 
            run = true
            table.insert(usedArgs, 1)
        end

        if i == 1 and arg == "-list" then
            list = true
            table.insert(usedArgs, 1)
        end

        if arg == "-u" then 
            config.user = args[i+1] 
            table.insert(usedArgs, i)
            table.insert(usedArgs, i+1)
        end
        if arg == "-r" then 
            config.repo = args[i+1] 
            table.insert(usedArgs, i)
            table.insert(usedArgs, i+1)
        end
        if arg == "-b" then 
            config.branch = args[i+1] 
            table.insert(usedArgs, i)
            table.insert(usedArgs, i+1)
        end

        -- Ensure all config parameters are set
        assert(config.user, "GitHub user not specified. Use proper flags or run [git-it config].")
        assert(config.repo, "GitHub repo not specified. Use proper flags or run [git-it config].")
        assert(config.branch, "GitHub branch not specified. Use proper flags or run [git-it config].")

        -- Store the rest of the non-flag parameters in a separate table
        if not table.includes(usedArgs, i) then table.insert(restArgs, arg) end
    end

    -- Get File and Destination
    local file, destination = table.unpack(restArgs)
    file, destination = cleanPath(file), cleanPath(destination)

    -- Set file or destination if they weren't given
    branchDir = "branch-"..config.branch
    file = (file ~= "") and file or branchDir
    destination = destination or shell.dir()
    return config, cleanPath(file), cleanPath(destination)
end


function listContents(dirPath, fTypes)
    local dirFiles = getDirFiles(dirPath, fTypes)
    local message = table.concat(dirFiles, "\n")
    local _, y = term.getCursorPos()
    textutils.pagedPrint(message, y - 2)
end

function setConfig()
    local config = {}
    
    c(colors.yellow) print("Set git-it defaults:")
    c(colors.green) write("User: ") c(colors.white) config.user = read()
    c(colors.green) write("Repo: ") c(colors.white) config.repo = read()
    c(colors.green) write("Branch: ") c(colors.white) config.branch = read()

    local config_file = fs.open(".git-it.config", "w")
    config_file.write(textutils.serialise(config))
    config_file.close()
    c(colors.yellow) print("Saved config file.")
end

function printUsage()
    c(colors.yellow) print("===== git-it usage =====")

    c(colors.green) write("git-it ") c(colors.blue) write("[-u user] [-r repo] [-b branch] ") c(colors.green) write("FILE ") c(colors.blue) write("[DEST]\n")
    c(colors.red) print("-- Download a file or directory from a GitHub repository")
    c(colors.blue) write("  user: ") c(colors.yellow) write("GitHub username\n") 
    c(colors.blue) write("  repo: ") c(colors.yellow) write("GitHub repository\n") 
    c(colors.blue) write("  branch: ") c(colors.yellow) write("GitHub branch\n")
    c(colors.green) write("  FILE: ") c(colors.yellow) write("Path of file or directory to download\n")
    c(colors.blue) write("  DEST: ") c(colors.yellow) write("Path of directory to save files to\n\n")

    -- c(colors.green) write("git-it run") c(colors.blue) write("[-u user] [-r repo] [-b branch] ") c(colors.green) write("FILE\n")
    -- c(colors.red) print("-- Execute a Lua program from a GitHub repository")

    -- c(colors.blue) write("  user: ") c(colors.yellow) write("GitHub username\n") 
    -- c(colors.blue) write("  repo: ") c(colors.yellow) write("GitHub repository\n") 
    -- c(colors.blue) write("  branch: ") c(colors.yellow) write("GitHub branch\n")
    -- c(colors.green) write("  FILE: ") c(colors.yellow) write("Path of file or directory to download\n")

    c(colors.green) write("git-it -config\n")
    c(colors.red) print("-- Set-up default configs to easily download from a common GitHub branch")
end



function cleanPath(path)
    if not path then return "" end
    if path:sub(#path) == '/' then return path:sub(1, #path - 1) else return path end
end

function getDirFiles(dirPath, fTypes)
    local dirFiles = {}
    for filePath, _ in pairs(fTypes) do
        if dirPath == branchDir then 
            local idx, _ = filePath:find('/')
            if filePath ~= dirPath and not idx then table.insert(dirFiles, filePath) end
        else
            local idx, _ = filePath:find(dirPath)
            if filePath ~= dirPath and idx == 1 then table.insert(dirFiles, filePath) end
        end
    end
    return dirFiles
end

function string:split(sep)
    local t = {}
    for str in string.gmatch(self, "([^"..sep.."]+)") do
        table.insert(t, str)
    end
    return t
end

table.includes = function(t, val)
    for _, value in ipairs(t) do
        if value == val then return true end
    end
    return false
end

main()
