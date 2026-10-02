function PLUGIN:BackendExecEnv(ctx)
    return {
        env_vars = {
            { key = "PATH", value = require("file").join_path(ctx.install_path, "bin") },
        },
    }
end
