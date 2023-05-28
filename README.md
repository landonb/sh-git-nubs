# `sh-git-nubs`

Bits of reusable Git and GitHub shell functions.

## Usage

Source the `bin/git-nubs.sh` library, then call its functions from your scripts.

E.g.,

  ```shell
  $ . git-nubs.sh

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

## Installation

The author recommends cloning the repository and wiring its `bin/` to `PATH`.

You can also create a symlink to the library (`git-nubs.sh`) from a location
already on `PATH`, such as `~/.local/bin`.

Or you could clone the project and load the library to evaluate it first,
before deciding how you want to wire it.

Alternatively, you might find that using a shell package manager, such as
[`bkpg`](https://github.com/bpkg/bpkg),
is more appropriate for your needs, e.g.,
`bpkg install -g landonb/sh-git-nubs`.

### Makefile install

The included `Makefile` can also be used to help install.

- E.g., you could clone this project somewhere and
  then run a `sudo make install` to install it globally:

  ```shell
  git clone https://github.com/landonb/sh-git-nubs.git
  cd sh-git-nubs
  # Install to /usr/local/bin
  sudo make install
  ```

- Specify a `PREFIX` to install anywhere else, such as locally, e.g.,

  ```shell
  # Install to $USER/.local/bin
  PREFIX=~/.local/bin make install
  ```

  And then ensure that the target directory is on the user's `PATH` variable.

  You could, for example, add the following to `~/.bashrc`:

  ```shell
  export PATH=$PATH:$HOME/.local/bin
  ```

### Manual install

If you clone the project and want the library functions to be
loaded in your shell, remember to ensure that it can be found
on `PATH`, and then source the library file, e.g.,

  ```shell
  git clone https://github.com/landonb/sh-git-nubs.git
  export PATH=$PATH:/path/to/sh-git-nubs/bin
  . git-nubs.sh
  ```

Enjoy!

