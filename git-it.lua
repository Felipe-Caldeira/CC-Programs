local args = {...}
local config, targetFile, dest
local fTypes = {}

local c = term.setTextColor
local pprint = require("cc.pretty").pretty_print

--[[ 
    git-it GitHub downloader by Felipe-Caldeira

    This program allows you to download files and directories from a GitHub repo,
    keeping the file structure intact. The files will be saved at the given destination
    path (defaults to current directory). A whole branch can be downloaded by requesting '/'
    as the file. Use the [config] command to set the default user, repo, and branch, to avoid
    having to set the corresponding flags each call.

    Usage: 
        git-it [-u user] [-r repo] [-b branch] FILE [DEST]
        git-it config
        git-it -h

    @version: 1.0
]]

function main()
    config, targetFile, dest = processArgs()

    local repo, err = http.get(("https://api.github.com/repos/%s/%s/git/trees/%s?recursive=1"):format(config.user, config.repo, config.branch))
    if not repo then error(err) end

    local repoTree = textutils.unserialiseJSON(repo.readAll()).tree

    fTypes = {}
    for _, file in ipairs(repoTree) do
        fTypes[file.path] = file.type
        print(file.path, file.type)
    end

    c(colors.yellow) write("Starting download of ") c(colors.green) write(targetFile) c(colors.yellow) write(" to ") c(colors.green) write(dest..'/\n') c(colors.yellow)
    download(targetFile, dest)
end

function download(file, destination)
    -- Segment the path to get the file name
    local pathSegments = file:split('/')
    local fileName = pathSegments[#pathSegments]
    
    -- File not present
    if fTypes[file] == nil then error("File could not be found in remote repository.")
    
    -- Download file
    elseif fTypes[file] == "blob" then
        local destPath = destination..'/'..fileName
        if fs.exists(destPath) then 
            print("Updating", destPath)
            fs.delete(destPath) 
        else
            print("Downloading", destPath)
        end
        shell.run("wget", ("https://raw.githubusercontent.com/%s/%s/%s/%s"):format(config.user, config.repo, config.branch, file), destPath)
      
    -- Download folder
    elseif fTypes[file] == "tree" then
        -- Find all subfiles of the folder
        local dirFiles = {}
        for filePath, _ in pairs(fTypes) do
            local idx, _ = filePath:find(file)
            if idx == 1 and filePath ~= file then table.insert(dirFiles, filePath) end
        end

        -- Extract the folder name from its path
        pprint(dirFiles)
        

        -- Recursively download folder subfiles
        for _, subFile in ipairs(dirFiles) do download(subFile, destination..'/'..fileName) end

    else
        error("Unknown type: "..fTypes[file])
    end
end

function processArgs()
    -- Show git-it usage
    if #args == 0 or args[1] == '-h' then printUsage() return end

    -- Setting default configs
    if args[1] == "config" then setConfig() return end
    
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
    file = (file ~= "") and file or "branch: "..config.branch
    destination = destination or shell.dir()
    return config, cleanPath(file), cleanPath(destination)
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

    c(colors.green) write("git-it config\n")
    c(colors.red) print("-- Set-up default configs to easily download from a common GitHub branch")
end

function cleanPath(path)
    if not path then return end
    if path:sub(#path) == '/' then return path:sub(1, #path - 1) else return path end
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
