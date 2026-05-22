# my-cli

a small zig cli built by following [this guide](https://rebuild-x.github.io/docs/#/./zig/terminal/cli?id=step-6-testing-your-cli).

## build

```
zig build
```

## commands

```
./zig-out/bin/cli help                          # list everything
./zig-out/bin/cli hello -g hola -n andrew       # colored greeting (greeting required, name optional)
./zig-out/bin/cli user:create -u alice
./zig-out/bin/cli user:list
./zig-out/bin/cli config:set -k port -v 8080
./zig-out/bin/cli config:get -k port
./zig-out/bin/cli process                       # ~5s spinner demo
./zig-out/bin/cli interactive                   # arrow-key menu (macOS/Linux TTY)
./zig-out/bin/cli completion bash               # emit shell completion script
```

short and long flags both work (`-g` / `--greeting`). missing a required option fails with `MissingRequiredOption`. the `hello` greeting prints in green / cyan / yellow via ansi escape codes.

`interactive` drops you into a TUI: ↑/↓ to move, Enter to pick, Esc / Ctrl+C to cancel. It reuses the same handlers as the flag-driven commands, prompting you for each input.

## shell completion

`cli completion <shell>` prints a completion script for `bash`, `zsh`, or `fish` to stdout. Install it for your shell:

```bash
# bash (Linux)
./zig-out/bin/cli completion bash > ~/.local/share/bash-completion/completions/cli

# bash (macOS, via Homebrew bash-completion)
./zig-out/bin/cli completion bash > "$(brew --prefix)/etc/bash_completion.d/cli"

# zsh — drop into a directory on $fpath
./zig-out/bin/cli completion zsh > "${fpath[1]}/_cli"
# then restart your shell, or: autoload -U compinit && compinit

# fish
./zig-out/bin/cli completion fish > ~/.config/fish/completions/cli.fish
```

After installing, `cli <TAB>` completes command names, `cli hello -<TAB>` completes flags, and `cli completion <TAB>` suggests the shell names.
