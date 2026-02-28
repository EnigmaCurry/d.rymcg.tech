## Backup and restore .env files

The `.env` files contain secrets and are excluded from git via
`.gitignore`. Use `export-env` and `restore-env` to back up and
restore your configurations.

### Export

Export all env files for the current context as flat env vars:

```bash
## Export to a file:
d export-env > backup.env

## Choose which env files to export:
d export-env --choose > backup.env

## Export from a specific context:
d export-env --context myserver > backup.env
```

### Encrypted export

Encrypt the export with [SOPS](https://github.com/getsops/sops) and
[age](https://github.com/FiloSottile/age):

```bash
## Generate an age key on a separate secure machine (not your everyday workstation):
mkdir -p ~/.config/sops/age
age-keygen -o ~/.config/sops/age/keys.txt

## Export encrypted (will prompt for the age public key if not already set):
d export-env --encrypt > backup.sops.env
```

### Base64 export

Encode the output as a single gzipped base64 string (useful for
storing in environment variables or passing through systems that
don't handle multiline values):

```bash
d export-env --base64

## Combine with encryption:
d export-env --encrypt --base64
```

### Restore

Restore env files from a previous export. SOPS encryption and base64
encoding are automatically detected:

```bash
## Restore from a file:
d restore-env backup.env

## Restore from an encrypted file:
d restore-env backup.sops.env

## Restore via pipe:
d export-env --context old | d restore-env

## Interactively select which files to restore:
d restore-env --choose backup.env

## Encrypted round-trip via pipe:
d export-env --encrypt | d restore-env
```

### SOPS key discovery

When decrypting, SOPS finds your age private key automatically via:

- `SOPS_AGE_KEY` environment variable
- `SOPS_AGE_KEY_FILE` environment variable
- `~/.config/sops/age/keys.txt` (default location)
