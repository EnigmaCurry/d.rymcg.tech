# 📦 GitHub → Forgejo Repository Mirroring Tool

This tool automatically **mirrors all your GitHub repositories** (public, private, forks, archived) into your **Forgejo** instance.  
It is **safe to re-run** and **idempotent** — it will only migrate
missing repositories.

Supports:
- Dry-run mode (default)
- Safe mirroring with retries and rate limit handling
- Full mirroring (all refs, branches, tags)

---

# ✨ Features

- Mirrors **all** GitHub repositories
- Skips existing Forgejo repositories
- Safe `--yes` flag to perform real migration
- Handles GitHub rate limits automatically
- Retries on network or server errors
- Loads config easily via `.env` file
- `just` integration for simple commands

---

# 🛠 Requirements

- Python 3.7+
- [`just`](https://github.com/casey/just) installed
- Python dependencies (only `requests`, standard library otherwise):
  ```bash
  pip install requests
  ```

---

# ⚙️ Quickstart

1. Create a `.env` file with your credentials (copy from [.env-dist](.env-dist)).

2. Perform a **dry run** (no changes yet):
   ```bash
   just mirror-dry-run
   ```

3. If everything looks good, **mirror the repositories**:
   ```bash
   just mirror-repos
   ```

---

# 🧪 `.env` Example

Create a `.env` file in the project root with the following content:

```env
# GitHub credentials
GITHUB_TOKEN=ghp_your_github_token
GITHUB_USERNAME=your_github_username

# Forgejo credentials
FORGEJO_URL=https://your-forgejo.example.com
FORGEJO_TOKEN=your_forgejo_token
FORGEJO_OWNER=your_forgejo_username_or_organization

# Optional: how often Forgejo should pull from GitHub
MIRROR_INTERVAL=8h0m0s
```

> ⚡ The script automatically loads this `.env` file if you have it.

---

# 🔐 How to Get Your GitHub Token

1. Go to [GitHub Settings → Developer Settings → Personal Access Tokens → Fine-grained tokens](https://github.com/settings/tokens).
2. Click **Generate new token**.
3. Set a **meaningful name**, **no expiration** or a long expiration.
4. **Repository permissions**:
   - `Contents: Read-only`
   - `Metadata: Read-only`
5. **Account permissions**:
   - Optional, but you may add:
     - `Repository Administration: Read-only`
6. Generate and copy the token.

⚠️ Make sure to **copy** the token now — GitHub will not show it again.

---

# 🔐 How to Get Your Forgejo Token

1. Log in to your Forgejo instance.
2. Go to **Settings → Applications → Manage Access Tokens**.
3. Click **Generate New Token**.
4. Set a **name** like `Mirror Importer`.
5. **Scope**:
   - At minimum: `repo` (full control of repositories).
6. Generate and copy the token.

⚠️ Make sure to **copy** the token now — Forgejo will not show it again.

---

# 📋 Available Commands

| Command | What it does |
|:---|:---|
| `just mirror-dry-run` | Dry-run mode: shows which repos would be mirrored |
| `just mirror-repos` | Actually mirrors missing repositories (requires `--yes`) |
| `just check-env` | Checks if all required environment variables are set |

---

# 🔥 Important Notes

- **Dry-run is the default.**  
  It will not create anything unless you use `--yes` or `just mirror-repos`.
  
- **Idempotent:**  
  You can re-run the script as many times as you want. It skips already-mirrored repositories.

- **Rate Limits:**  
  If GitHub API rate limits are hit, the script will **automatically wait** and resume after reset.

- **Retries:**  
  Temporary network errors (e.g., 5xx responses) are automatically retried with exponential backoff.

---

# 📈 Example Output

```bash
$ just mirror-dry-run

[INFO] Found 154 repositories on GitHub.
[SKIP] repo1 already exists on Forgejo.
[SKIP] repo2 already exists on Forgejo.

[DRY-RUN] Repositories to mirror:
 - new-repo-1
 - new-repo-2

[INFO] Dry-run complete. Re-run with --yes to perform migration.
```

Then:

```bash
$ just mirror-repos

[EXECUTING] Creating mirrors...
[MIRROR] Creating mirror for new-repo-1
[MIRROR] Creating mirror for new-repo-2

[DONE] All eligible repositories processed.
```

---

# 🛡 Troubleshooting

- **403 Forbidden when accessing GitHub API?**
  - Check that your GitHub token has `repo` and `metadata` read permissions.
  
- **Forgejo repo creation fails?**
  - Make sure your Forgejo token has full `repo` scope access.

- **Python errors about missing modules?**
  - Install `requests`:
    ```bash
    pip install requests
    ```

- **Network flakiness?**
  - The script automatically retries transient errors. No action needed unless persistent.

---

# 🎯 Future Improvements (Optional)

- Parallel repo migration
- Automatically detect Forgejo `uid`
- Slack/email notification after migration
- Fine-grained repo filtering (only starred, language-based, etc.)

---

# 🚀 That's it!

This tool makes it easy to keep your Forgejo instance **up to date** with GitHub, with full automation and safety.

---

Would you also like me to show a bonus `.env.example` you can commit to the repo (so `.env` can stay in your `.gitignore`)?  
It’s a nice touch for onboarding or documentation! 🚀  
(Only contains placeholder values, safe for public repos.)
