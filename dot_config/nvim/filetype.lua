-- Custom filetype detection for .conf and other ambiguous files
vim.filetype.add({
    extension = {
        conf = function(path, bufnr)
            -- Check specific config file patterns first
            local filename = vim.fn.fnamemodify(path, ":t")
            local parent = vim.fn.fnamemodify(path, ":h:t")

            -- Known application-specific configs
            local known_configs = {
                ["nginx.conf"] = "nginx",
                ["mime.types"] = "nginx",
                ["fastcgi.conf"] = "nginx",
                ["uwsgi.conf"] = "nginx",
                ["tmux.conf"] = "tmux",
                [".tmux.conf"] = "tmux",
                ["resolv.conf"] = "resolv",
                ["krb5.conf"] = "dosini",
                ["mkinitcpio.conf"] = "bash",
                ["makepkg.conf"] = "bash",
                ["pacman.conf"] = "confini",
                ["yum.conf"] = "dosini",
                ["dnf.conf"] = "dosini",
                ["pip.conf"] = "dosini",
                ["paru.conf"] = "confini",
                ["yay.conf"] = "confini",
            }

            if known_configs[filename] then
                return known_configs[filename]
            end

            -- Directory-based detection
            if parent == "nginx" or path:match("/nginx/") then
                return "nginx"
            end
            if parent == "systemd" or path:match("/systemd/") then
                return "systemd"
            end
            if path:match("/apache2?/") or path:match("/httpd/") then
                return "apache"
            end
            if path:match("/ssh/") or path:match("sshd") then
                return "sshdconfig"
            end
            if path:match("/modprobe%.d/") then
                return "modconf"
            end

            -- Content-based detection: read first few lines
            local lines = vim.api.nvim_buf_get_lines(bufnr, 0, 10, false)
            local content = table.concat(lines, "\n")

            -- Detect by content patterns
            if content:match("^%s*%[") then
                -- Has INI-style sections
                return "confini"
            end
            if content:match("server%s*{") or content:match("location%s*[~/]") then
                return "nginx"
            end
            if content:match("^%s*#.*\n.-=%s*") or content:match("^[A-Z_]+=") then
                -- Shell-style variable assignments
                return "bash"
            end

            -- Default fallback: confini handles most key=value formats well
            return "confini"
        end,
    },
    filename = {
        [".tmux.conf"] = "tmux",
        ["tmux.conf"] = "tmux",
        [".envrc"] = "bash",
        [".env"] = "bash",
        [".env.local"] = "bash",
        [".env.example"] = "bash",
    },
    pattern = {
        [".*%.conf%.d/.*"] = "confini",
        [".*/etc/conf%.d/.*"] = "bash",
        [".*/systemd/.*%.conf"] = "systemd",
        [".*nginx.*%.conf"] = "nginx",
        [".*/sites%-available/.*"] = "nginx",
        [".*/sites%-enabled/.*"] = "nginx",
    },
})
