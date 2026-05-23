# babyline

a small zig CLI demo with subcommands, persistent config, shell completion, and auto-generated docs. originally built by following [this guide](https://rebuild-x.github.io/docs/#/./zig/terminal/cli?id=step-6-testing-your-cli) and extended from there.

## build

```
zig build
```

The binary lands at `./zig-out/bin/babyline`.

## commands

```
./zig-out/bin/babyline help                          # list everything
./zig-out/bin/babyline hello -g hola -n andrew       # colored greeting (greeting required, name optional)
./zig-out/bin/babyline user:create -u alice
./zig-out/bin/babyline user:list
./zig-out/bin/babyline config:set -k port -v 8080    # writes ~/.config/babyline/config
./zig-out/bin/babyline config:get -k port
./zig-out/bin/babyline config:list
./zig-out/bin/babyline config:delete -k port
./zig-out/bin/babyline process                       # ~5s spinner demo
./zig-out/bin/babyline interactive                   # arrow-key menu (macOS/Linux TTY)
./zig-out/bin/babyline completion bash               # emit shell completion script
./zig-out/bin/babyline docs all                      # regenerate docs/babyline.{md,1,txt}
```

short and long flags both work (`-g` / `--greeting`). missing a required option fails with `MissingRequiredOption`. the `hello` greeting prints in green / cyan / yellow via ansi escape codes.

`interactive` drops you into a TUI: ↑/↓ to move, Enter to pick, Esc / Ctrl+C to cancel. It reuses the same handlers as the flag-driven commands, prompting you for each input.

## shell completion

`babyline completion <shell>` prints a completion script for `bash`, `zsh`, or `fish` to stdout. Install it for your shell:

```bash
# bash (Linux)
./zig-out/bin/babyline completion bash > ~/.local/share/bash-completion/completions/babyline

# bash (macOS, via Homebrew bash-completion)
./zig-out/bin/babyline completion bash > "$(brew --prefix)/etc/bash_completion.d/babyline"

# zsh — drop into a directory on $fpath
./zig-out/bin/babyline completion zsh > "${fpath[1]}/_babyline"
# then restart your shell, or: autoload -U compinit && compinit

# fish
./zig-out/bin/babyline completion fish > ~/.config/fish/completions/babyline.fish
```

After installing, `babyline <TAB>` completes command names, `babyline hello -<TAB>` completes flags, `babyline completion <TAB>` suggests the shell names, and `babyline docs <TAB>` suggests doc formats.

## documentation

`babyline docs <format>` regenerates usage documentation in `docs/`:

```bash
./zig-out/bin/babyline docs markdown   # -> docs/babyline.md
./zig-out/bin/babyline docs man        # -> docs/babyline.1
./zig-out/bin/babyline docs text       # -> docs/babyline.txt
./zig-out/bin/babyline docs all        # all three
```

or via the build step:

```bash
zig build docs
```

[docs/babyline.md](docs/babyline.md) is the easiest to skim — GitHub renders it.

## tests

```
zig build test --summary all
```

42 unit tests across `cli.zig` (arg parsing, color codes), `config.zig` (key parsing, INI roundtrip), `completion.zig` (per-shell script fragments), `commands.zig` (pure handlers), and `docs.zig` (per-format snapshots).
