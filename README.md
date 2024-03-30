# `sh-git-nubs`

Bits of reusable Git and GitHub shell functions.

## Usage

Source the `lib/git-nubs.sh` library, then call its functions from your scripts.

E.g.,

  ```shell
  $ . path/to/sh-git-nubs/lib/git-nubs.sh

  $ git_branch_exists "branch-name" || >&2 echo "No such branch"
  No such branch

  $ git_branch_name
  some-branch

  $ git_remote_exists "remote-name" || >&2 echo "No such remote"
  No such remote

  $ git_remote_branch_exists "some-remote" "some-branch" && echo "It does exist!"
  It does exist!

  $ git_insist_git_repo || >&2 echo "This is not a repo!"

  $ git_insist_pristine || >&2 echo "Your working directory has WORK!"

  $ git_versions_tagged_for_commit_object $(git rev-parse HEAD)
  0.0.1

  $ git_last_version_tag_describe
  0.0.1

  $ git_since_git_init_commit_epoch_ts
  1450540432

  $ git_since_latest_version_tag_epoch_ts
  1547432645

  $ git_since_most_recent_commit_epoch_ts
  1687439645
  ```

