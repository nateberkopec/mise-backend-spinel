function PLUGIN:BackendListVersions(ctx)
    local repo = ctx.tool
    if not repo:match("^[%w_.-]+/[%w_.-]+$") or repo:find("%.%.") then
        error("expected spinel:owner/repo")
    end

    local response = require("http").get({
        url = "https://api.github.com/repos/" .. repo .. "/tags?per_page=100",
        headers = { ["User-Agent"] = "mise-backend-spinel", ["Accept"] = "application/vnd.github+json" },
    })
    if response.status_code ~= 200 then
        error("GitHub tag listing failed (HTTP " .. response.status_code .. ") for " .. repo)
    end

    local tags = require("json").decode(response.body)
    local versions = {}
    local prefix = ctx.options.tag_prefix or ""
    for i = #tags, 1, -1 do
        local tag = tags[i].name
        if type(tag) == "string" and tag:sub(1, #prefix) == prefix then
            table.insert(versions, tag:sub(#prefix + 1))
        end
    end
    return { versions = versions }
end
