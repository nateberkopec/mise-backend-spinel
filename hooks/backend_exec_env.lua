function PLUGIN:BackendExecEnv(ctx)
    local file = require("file")
    local options = ctx.options
    local name = ctx.tool:match("/([^/]+)$")
    local recipe = require("json").encode({
        ctx.tool, ctx.version, options.entrypoint or "main.rb", options.bin or name,
        options.source_ref or "", options.source_ref and "" or (options.tag_prefix or ""),
        options.spinel_ref or "", options.spinel_ref and "" or (options.spinel or "spinel"),
    })
    local manifest = file.join_path(ctx.install_path, ".spinel-recipe")
    if not file.exists(manifest) or file.read(manifest) ~= recipe then
        error("Spinel build options differ from the installed recipe; use a new version label and run mise install")
    end
    return {
        env_vars = {
            { key = "PATH", value = file.join_path(ctx.install_path, "bin") },
        },
    }
end
