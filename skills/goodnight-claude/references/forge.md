# Forge recipes

Detect the forge from the remote URL. `labs.deepthought-solutions.net` is Gitea/Forgejo (API under `/api/v1`). GitHub remotes use `gh`.

## Gitea / Forgejo

Use `fj` (forgejo-cli) first. It reads its token from `~/.local/share/forgejo-cli/keys.json`, so no `.env` is needed. Run it from inside the repo, or pass `-r owner/repo`. Pass `--style minimal` when you parse the output.

| Action | Call |
| --- | --- |
| Check the login | `fj whoami` |
| Open issues | `fj issue search --all` (add `-m <milestone>` to filter) |
| One issue | `fj issue view <N>` |
| Milestones (often the EPICs) | `fj milestone search` |
| Comment | `fj issue comment <N> "<body>"` |
| Open PRs | `fj pr search` |
| Create a PR | `fj pr create --base <base> --head <branch> --body "<body>" "<title>"` |
| CI and mergeability | `fj pr status <N>` |

Check each subcommand's `--help` once before first use, since `fj` options change between versions. When `fj` lacks something (labels, paging, raw JSON), use the API with the same token:

```bash
TOKEN=$(jq -r '.hosts["labs.deepthought-solutions.net"].token' ~/.local/share/forgejo-cli/keys.json)
API=https://labs.deepthought-solutions.net/api/v1
H=(-H "Authorization: token $TOKEN" -H "Content-Type: application/json")
R=UnxWares/Provisioning           # owner/repo
```

If the brief names a `.env` instead, load it with `set -a; . <path>; set +a` and use its token variable. Never echo a token.

| Action | Call |
| --- | --- |
| Check the token | `curl -sf "${H[@]}" "$API/user" \| jq .login` |
| Open issues, paged | `curl -sf "${H[@]}" "$API/repos/$R/issues?state=open&type=issues&limit=50&page=1"` |
| Milestones (often the EPICs) | `curl -sf "${H[@]}" "$API/repos/$R/milestones?state=open"` |
| Labels | `curl -sf "${H[@]}" "$API/repos/$R/labels"` |
| One issue and its comments | `.../issues/$N` and `.../issues/$N/comments` |
| Comment | `curl -sf "${H[@]}" -X POST "$API/repos/$R/issues/$N/comments" -d "$(jq -n --arg b "$BODY" '{body:$b}')"` |
| Open PRs | `curl -sf "${H[@]}" "$API/repos/$R/pulls?state=open"` |
| Create a PR | `curl -sf "${H[@]}" -X POST "$API/repos/$R/pulls" -d "$(jq -n --arg t "$TITLE" --arg b "$BODY" --arg h "$BRANCH" --arg base "$BASE" '{title:$t,body:$b,head:$h,base:$base}')"` |
| CI status of a commit | `curl -sf "${H[@]}" "$API/repos/$R/commits/$SHA/status"` |

EPICs may also be issues with an `epic` label, or issues whose body lists children as task items. Check all three at triage and record which convention the repo uses.

Pass bodies through `jq --arg` so quotes and newlines survive. Page until a page returns fewer items than `limit`.

## GitHub

Use `gh issue list`, `gh issue comment`, `gh pr create --fill-first --base <base>`, `gh pr checks`.

## Comment style

Comments go out as the user's identity. Write them as a colleague would, in plain prose: what changed, where (PR link), what is left, and the question if any.
