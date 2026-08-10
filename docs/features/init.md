# Init and Scaffolds

`dew init` bootstraps `.project/dew.yaml`, module directories, and optional
user scaffold files.

## Command surface

```text
dew init [--path <dir>] [--[no-]gitkeep]
         [--scaffold <name-or-path> ...]
         [--scaffold-merge <name-or-path> ...]
         [--scaffold-strict <name-or-path> ...]
```

- `--scaffold`: base scaffold layer(s), applied in flag order.
- `--scaffold-merge`: merge layer(s), applied after base layers.
- `--scaffold-strict`: strict layer(s), applied last; any target-path collision
  with prior scaffold outputs fails init.

If no `--scaffold` flag is supplied, Dew automatically uses scaffold
`_default`.

## Scaffold discovery

Scaffold names resolve under:

- `${XDG_CONFIG_HOME}/dew/scaffolds` if `XDG_CONFIG_HOME` is set
- otherwise `~/.config/dew/scaffolds`

Input resolution order for each `name-or-path`:

1. Local/absolute path lookup first.
2. If not found and value is a simple name, lookup by name under scaffold root.
3. If still not found, init fails.

## File conventions

Within each scaffold directory:

- `filename`: static file copied as-is.
- `filename.liquid`: rendered Liquid template that becomes the base content for
  `filename`.
- `filename.part.liquid`: rendered fragment merged into `filename`.

When both `filename` and `filename.liquid` exist, `.liquid` is the canonical
base for that scaffold layer.

## Region metadata blocks for parts

Part files may include leading metadata comments:

```text
# dew-part: editorconfig
# id: dart-core
# mode: merge
```

Dew wraps part output in region markers and preserves metadata comments using
the target file's comment syntax.

For `#` comment targets (for example `.editorconfig`):

```text
#region dart-core
# dew-part: editorconfig
# id: dart-core
...
#endregion dart-core
```

## Current merge behavior

- `.editorconfig` supports structured merges:
  - section-aware merge
  - key-level replacement for matching keys in a section
  - existing target `.editorconfig` is merged (not rejected)
  - reruns are idempotent for region blocks with the same `id`
- Other files currently use full-file replace (base/template) and append-style
  part handling.

## Completion helper

Use scaffold discovery output for shell completion integration:

```bash
dew completion scaffolds
dew completion scaffolds --prefix da
```

Optional override:

```bash
dew completion scaffolds --root /custom/scaffold/root
```
