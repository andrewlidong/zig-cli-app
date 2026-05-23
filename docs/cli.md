# cli

A small Zig CLI demo with subcommands, persistent config, and shell completion.

## Synopsis

```
cli <command> [options]
```

## Commands

### `hello`

Greet someone.

**Required options:**

- `-g, --greeting <value>` — Greeting word

**Optional options:**

- `-n, --name <value>` — Name to greet

### `help`

Show this help message.

### `user:create`

Create a user.

**Required options:**

- `-u, --username <value>` — Username

### `user:list`

List users.

### `config:set`

Set a config value.

**Required options:**

- `-k, --key <value>` — Config key
- `-v, --value <value>` — Config value

### `config:get`

Get a config value.

**Required options:**

- `-k, --key <value>` — Config key

### `config:list`

List all config values.

### `config:delete`

Delete a config value.

**Required options:**

- `-k, --key <value>` — Config key

### `process`

Run a ~5s spinner demo.

### `interactive`

Launch arrow-key driven menu.

## Built-in subcommands

### `completion`

Generate a shell completion script.

```
cli completion <bash|zsh|fish>
```

### `docs`

Generate usage documentation in the `docs/` directory.

```
cli docs <markdown|man|text|all>
```

## All options

| Short | Long | Description |
|-------|------|-------------|
| `-n` | `--name` | Name to greet |
| `-g` | `--greeting` | Greeting word |
| `-u` | `--username` | Username |
| `-k` | `--key` | Config key |
| `-v` | `--value` | Config value |
