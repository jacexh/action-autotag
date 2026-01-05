# Action AutoTag

A GitHub Action that automatically increments the version and tags the repository based on the source branch name of a merged pull request.

## How it works

When a pull request is merged into your default branch (e.g., `main` or `master`), this action parses the merge commit message to determine the source branch name. Based on the source branch prefix, it calculates the next semantic version number and pushes a new tag.

### Branch Name Conventions

- `fix/*`, `hotfix/*`, `bugfix/*` or others: Triggers a **patch** increment (e.g., v1.0.0 -> v1.0.1)
- `feat/*`, `feature/*`, `release/*`: Triggers a **minor** increment (e.g., v1.0.0 -> v1.1.0)
- `breaking/*`, `major/*`: Triggers a **major** increment (e.g., v1.0.0 -> v2.0.0)

If the branch name does not match `feat`, `feature`, `release`, `breaking`, or `major`, it typically defaults to `patch` (or the value of `default_bump`).

## Usage

Add this action to your workflow file (e.g., `.github/workflows/tag.yml`). It should run after the checkout step.

### Recommended: Trigger on Pull Request Merge

This is the most reliable way to detect the source branch.

```yaml
on:
  pull_request:
    branches:
      - main
      - master
    types: [closed]

jobs:
  tag:
    runs-on: ubuntu-latest
    if: github.event.pull_request.merged == true
    steps:
      - name: Checkout
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Auto Tag
        id: autotag
        uses: ./ # Or your-username/action-autotag@v1
        with:
          github_token: ${{ secrets.GITHUB_TOKEN }}
```

### Alternative: Trigger on Push

This works for direct pushes or merges where you want to parse the commit message.

```yaml
on:
  push:
    branches:
      - main
      - master
```

## Inputs

| Input | Description | Required | Default |
| --- | --- | --- | --- |
| `github_token` | The GitHub token used to push the new tag. Use `${{ secrets.GITHUB_TOKEN }}`. | **Yes** | N/A |
| `default_bump` | The default increment type if the branch name format is not recognized. Options: `patch`, `minor`, `major`, `none`. | No | `patch` |

## Outputs

| Output | Description |
| --- | --- |
| `new_tag` | The newly created tag (e.g., `v1.0.1`). |
| `old_tag` | The previous tag before incrementing (e.g., `v1.0.0`). |

### Using Outputs

You can use the outputs in subsequent steps by referencing the `id` of the Auto Tag step:

```yaml
    steps:
      - name: Auto Tag
        id: autotag
        uses: jacexh/action-autotag@v1
        with:
          github_token: ${{ secrets.GITHUB_TOKEN }}

      - name: Create Release
        uses: softprops/action-gh-release@v1
        with:
          tag_name: ${{ steps.autotag.outputs.new_tag }}
          body: |
            Release ${{ steps.autotag.outputs.new_tag }}
            Previous version: ${{ steps.autotag.outputs.old_tag }}
```

## Local Development

You can run the script locally if you have git configured.

```bash
./autotag.sh [patch|minor|major]
```

If no argument is provided, it attempts to detect the version from the last commit message.
