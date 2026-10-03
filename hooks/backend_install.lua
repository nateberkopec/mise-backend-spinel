local function github_repo(repo)
    if type(repo) ~= "string" or not repo:match("^[%w_.-]+/[%w_.-]+$") or repo:find("%.%.") then
        error("expected spinel:owner/repo")
    end
    return "https://github.com/" .. repo .. ".git"
end

local function source_path(path)
    if type(path) ~= "string" or path == "" or path:sub(1, 1) == "/" or path:find("\\", 1, true)
        or path:find("//", 1, true) or path:match("^%-") or path:match("^%./")
        or path:match("/%.%./") or path:match("^%.%./") or path:match("/%.%.$") then
        error("entrypoint must be a relative path inside the repository")
    end
    return path
end

local function commit(sha, option)
    if type(sha) ~= "string" or #sha ~= 40 or sha:find("[^0-9a-fA-F]") then
        error(option .. " must be a full 40-character commit SHA")
    end
    return sha
end

function PLUGIN:BackendInstall(ctx)
    if RUNTIME.osType ~= "darwin" and RUNTIME.osType ~= "linux" then
        error("Spinel currently requires macOS or Linux")
    end
    local cmd = require("cmd")
    local file = require("file")
    local options = ctx.options
    local name = ctx.tool:match("/([^/]+)$")
    local binary = options.bin or name
    if type(binary) ~= "string" or not binary:match("^[%w_.-]+$") or binary == "." or binary == ".." then
        error("bin must be a filename")
    end
    local entrypoint = source_path(options.entrypoint or "main.rb")
    local source_ref = options.source_ref
    if source_ref then
        source_ref = commit(source_ref, "source_ref")
    else
        local tag = (options.tag_prefix or "") .. ctx.version
        cmd.exec('git check-ref-format "$SPINEL_TAG_REF"', {
            env = { SPINEL_TAG_REF = "refs/tags/" .. tag },
        })
        source_ref = "refs/tags/" .. tag
    end

    local work = ctx.download_path
    local source = file.join_path(work, "source")
    local bin_dir = file.join_path(ctx.install_path, "bin")
    cmd.exec('mkdir -p "$SPINEL_WORK/source" "$SPINEL_INSTALL_BIN"', {
        env = { SPINEL_WORK = work, SPINEL_INSTALL_BIN = bin_dir },
    })
    cmd.exec('git init -q "$SPINEL_SOURCE" && (git -C "$SPINEL_SOURCE" remote set-url origin "$SPINEL_REPO" 2>/dev/null || git -C "$SPINEL_SOURCE" remote add origin "$SPINEL_REPO") && git -C "$SPINEL_SOURCE" fetch -q --depth 1 origin "$SPINEL_REF" && git -C "$SPINEL_SOURCE" checkout -q --detach FETCH_HEAD', {
        env = { SPINEL_SOURCE = source, SPINEL_REPO = github_repo(ctx.tool), SPINEL_REF = source_ref },
    })

    local compiler = options.spinel
    if options.spinel_ref then
        local spinel_ref = commit(options.spinel_ref, "spinel_ref")
        local spinel_dir = file.join_path(work, "spinel")
        cmd.exec('git init -q "$SPINEL_SOURCE" && (git -C "$SPINEL_SOURCE" remote set-url origin https://github.com/matz/spinel.git 2>/dev/null || git -C "$SPINEL_SOURCE" remote add origin https://github.com/matz/spinel.git) && git -C "$SPINEL_SOURCE" fetch -q --depth 1 origin "$SPINEL_REF" && git -C "$SPINEL_SOURCE" checkout -q --detach FETCH_HEAD', {
            env = { SPINEL_SOURCE = spinel_dir, SPINEL_REF = spinel_ref },
        })
        cmd.exec("make deps && make -j2", { cwd = spinel_dir })
        compiler = file.join_path(spinel_dir, "bin", "spinel")
    elseif not compiler then
        compiler = "spinel"
    end
    if type(compiler) ~= "string" or compiler == "" then
        error("spinel must be an executable path or name")
    end
    cmd.exec('"$SPINEL_COMPILER" "$SPINEL_ENTRYPOINT" -o "$SPINEL_OUTPUT" && test -x "$SPINEL_OUTPUT"', {
        cwd = source,
        env = {
            SPINEL_COMPILER = compiler,
            SPINEL_ENTRYPOINT = entrypoint,
            SPINEL_OUTPUT = file.join_path(bin_dir, binary),
        },
    })
    local recipe = require("json").encode({
        ctx.tool, ctx.version, entrypoint, binary,
        options.source_ref or "", options.source_ref and "" or (options.tag_prefix or ""),
        options.spinel_ref or "", options.spinel_ref and "" or (options.spinel or "spinel"),
    })
    cmd.exec('printf %s "$SPINEL_RECIPE" > "$SPINEL_MANIFEST"', {
        env = { SPINEL_RECIPE = recipe, SPINEL_MANIFEST = file.join_path(ctx.install_path, ".spinel-recipe") },
    })
    return {}
end
