#!/bin/sh
# vim:tw=0:ts=2:sw=2:et:norl:ft=sh
# Project: https://github.com/landonb/sh-git-nubs#🌰
# License: MIT

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

git_branch_exists () {
  local branch_name="$1"
  git show-ref --verify --quiet refs/heads/${branch_name}
}

git_branch_name () {
  local project_root="$(git rev-parse --show-toplevel)"
  # Note that $(git rev-parse HEAD) returns the hash, not the name,
  # so we add the option, --abbrev-ref.
  # - But first! check there's actually a branch, i.e., if `git init`
  #   but no `git commit`, rev-parse prints error.
  # - Note that `test ""` returns false; `test "foo"` returns true.
  if [ ! "$(command ls -A "${project_root}/.git/refs/heads")" ]; then
    echo "<?!>"

    return
  fi
  # 2020-09-21: (lb): Adding `=loose`:
  # - For whatever reason, I'm seeing this behavior:
  #   - On Linux, `git rev-parse --abbrev-ref` returns simply, e.g., "my_branch".
  #   - But on macOS, rev-parse returns a more qualified name, "heads/my_branch".
  # - I think that's because, on macOS (for whatever reason), there are two
  #   remote refs: .git/refs/remotes/release/HEAD
  #           and: .git/refs/remotes/release/release
  # - Use `loose` option to remove the "heads/" prefix, e.g.,
  #      $ git rev-parse --abbrev-ref=loose   # Prints, e.g., "my_branch"
  #      $ git rev-parse --abbrev-ref=strict  # Prints, e.g., "heads/my_branch"
  # - See also:
  #      $ git symbolic-ref --short HEAD
  local branch_name=$(git rev-parse --abbrev-ref=loose HEAD)

  printf %s "${branch_name}"
}

git_HEAD_commit_sha () {
  git rev-parse HEAD
}

git_remote_exists () {
  local remote="$1"

  git remote get-url ${remote} &> /dev/null
}

git_remote_branch_exists () {
  local remote="$1"
  local branch="$2"

  git show-branch remotes/${remote}/${branch} &> /dev/null
}

git_tracking_branch () {
  git rev-parse --abbrev-ref --symbolic-full-name @{u} 2> /dev/null
}

git_tracking_branch_safe () {
  # Because errexit, fallback on empty string.
  git_tracking_branch || echo ''
}

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

# Check that the current directory exists in a Git repo.
git_insist_git_repo () {
  # A naive approach is to check for the .git/ directory.
  # Another approach is to check --show-toplevel, e.g.,
  #   git rev-parse --show-toplevel &> /dev/null
  # Except both those approaches are truthy before `git init`.
  # A better naive approach might check if there are any refs:
  #   command ls -A ".git/refs/heads"
  # And the better porcelain command checks for HEAD.
  git rev-parse --abbrev-ref HEAD &> /dev/null && return 0

  local projpath="${1:-$(pwd)}"

  local errmsg
  if git rev-parse --show-toplevel &> /dev/null; then
    errmsg="Specified Git project has no commits"
  else
    errmsg="Specified directory not a Git project"
  fi

  >&2 echo "ERROR: ${errmsg}: ${projpath}"

  return 1
}

git_insist_pristine () {
  ! test -n "$(git status --porcelain)" && return 0

  local projpath="${1:-$(pwd)}"

  >&2 echo
  >&2 echo "ERROR: Project working directory not tidy! Try:"
  >&2 echo
  >&2 echo "   cd ${projpath} && git status"
  >&2 echo

  return 1
}

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

git_versions_tagged_for_commit () {
  local hash="$1"
  if [ -z "${hash}" ]; then
    hash="$(git_HEAD_commit_sha)"
  fi

  # Without -d/--dereference, hash shown is tag object, not commit.
  # With -d, prints 2 lines per tag, e.g., suppose 2 tags on one commit:
  #   $ git show-ref --tags -d
  #   af6ec9a9ae01592d36d06917e47b8ee9822178a7 refs/tags/v1.2.3
  #   7ca83ee766d31181b34e6aafb340f537e2cc0d6f refs/tags/v1.2.3^{}
  #   2aadd869b4ff4acc945b073a70be7e6573341ebc refs/tags/v1.2.3a3
  #   7ca83ee766d31181b34e6aafb340f537e2cc0d6f refs/tags/v1.2.3a3^{}
  # Where:
  #   $ git cat-file -t af6ec9a9ae01592d36d06917e47b8ee9822178a7
  #   tag
  #   $ git cat-file -t 7ca83ee766d31181b34e6aafb340f537e2cc0d6f
  #   commit
  # So search on the known commit hash, which returns refs/tags/<tag>^{},
  # then isolate just the tag -- and match only tags with a leading digit
  # (assuming that indicates a version tag, to exclude non-version tags).
  git show-ref --tags -d \
    | grep "^${hash}.* refs/tags/v\?[0-9]" \
    | command sed \
      -e 's#.* refs/tags/v\?##' \
      -e 's/\^{}//'
}

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

# FIXME/2020-12-13 23:44: See git-bump-version-tag's GITSMART_RE_VERSION_TAG
# - Because glob, this could match similar-looking tags, e.g., date-prefixed,
#   such as 2020-12-13-some-tag.
#
# This is matches anything starting with two numbers,
# of v and a number, or v and a period, so not really
# what's probably intended:
#   GITSMART_RE_VERSION_TAG='[v0-9][0-9.]*'
GITSMART_RE_VERSION_TAG='[v0-9]*'

# FIXME/2020-12-13 23:43: Would you want `latest_version_basetag` here instead?
# - The two functions might be doing same thing, and latest_version_basetag is
#   more hardened, I think... although it might also find tags in whole project,
#   and not just current branch like this function does?
#
git_last_version_tag_describe () {
  # By default, git-describe returns a commit-ish object representing the same
  # commit as the referenced commit (which defaults to HEAD). The described name
  # is the tag name, followed by the number of commits between it and the commit
  # referenced, and finally suffixed with a 'g' and part of the referenced SHA.
  # E.g., `git describe --tags --long --match '[v0-9][0-9.]*'` might return:
  #       "0.12.0-828-g0266e06".
  # So specify an --abbrev=0 to "suppress long format, only showing the closest tag."
  # And note that I don't see a difference with --long or not. Not sure why I added.
  # But it cannot be used with --abbrev=0. So easy to decide what to do. Not use it.
  git describe --tags --abbrev=0 --match "${GITSMART_RE_VERSION_TAG}" 2> /dev/null
}

# The git-tag pattern is a simple glob, so use extra grep to really filter.
GITSMART_RE_GREPFILTER='^[0-9]\+\.[0-9.]\+$'

# Match groups: \1: major * \2: minor * \4: patch * \5: seppa * \6: alpha.
GITSMART_RE_VERSPARTS='^v?([0-9]+)\.([0-9]+)(\.([0-9]+)([^0-9]*)(.*))?'

latest_version_basetag () {
  git tag -l "${GITSMART_RE_VERSION_TAG}" |
    grep -e "${GITSMART_RE_GREPFILTER}" |
    /usr/bin/env sed -E "s/${GITSMART_RE_VERSPARTS}/\1.\2.\4/" |
    sort -r --version-sort |
    head -n1
}

# ***

git_last_version_tag_describe_safe () {
  git_last_version_tag_describe || printf '0.0.0-✗-g0000000'
}

# Unused...
if false; then
  GITSMART_RE_LONG_TAG_PARTS='([^-]+)-([^-]+)-(.*)'

  git_last_version_name () {
    local described="$(git_last_version_tag_describe_safe)"
    printf "${described}" | /bin/sed -E "s/${GITSMART_RE_LONG_TAG_PARTS}/\1/g"
  }

  git_last_version_dist () {
    local described="$(git_last_version_tag_describe_safe)"
    printf "${described}" | /bin/sed -E "s/${GITSMART_RE_LONG_TAG_PARTS}/\2/g"
  }

  git_last_version_absent () {
    local distance="$(git_last_version_dist)"
    [ "${distance}" = '✗' ]
  }
fi

git_since_most_recent_commit_epoch_ts () {
  git --no-pager log -1 --format=%at HEAD 2> /dev/null
}

git_since_latest_version_tag_epoch_ts () {
  # Note that the "described" tag output (e.g., 0.12.0-828-g0266e06) is a
  # valid revision (per `man 7 gitrevisions`), which can be fed to git-log.
  # - And to compute a time delta from then to now, get seconds since epoch:
  #   git help log:
  #     %at: author date, UNIX timestamp
  git --no-pager \
    log -1 \
    --format=%at \
    "$(git_last_version_tag_describe_safe)" \
    2> /dev/null
}

git_since_git_init_commit_epoch_ts () {
  # Note that the "described" tag output (e.g., 0.12.0-828-g0266e06) is a
  # valid revision (per `man 7 gitrevisions`), which can be fed to git-log.
  # - And to compute a time delta from then to now, get seconds since epoch:
  #   git help log:
  #     %at: author date, UNIX timestamp
  # NOTE: rev-list outputs in reverse chronological order, so oldest commit
  #       is last; use tail to grab it.
  git --no-pager \
    log -1 \
    --format=%at \
    "$(git rev-list --max-parents=0 HEAD | tail -1)" \
    2> /dev/null
}

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

github_purge_release_and_tags_of_same_name () {
  # (lb): I pulled this function from landonb/release-ghub-pypi,
  #       but its environs still assumed:
  # Mandatory:
  #   R2G2P_REMOTE
  #   RELEASE_VERSION
  #   R2G2P_COMMIT
  # Optional:
  #   R2G2P_GHUB_CLOBBER_CERTIFIED    defaults false
  #   SKIP_PROMPTS                    defaults false
  #
  # Side-effects:
  #   R2G2P_DO_PUSH_TAG               set to false|true.

  # Reentrant support: If previously tagged and released, remove the
  # GitHub release if user wants, and remove tag from remote if points
  # to different commit and user approves.

  # See also, for a list of all tags on a remote, e.g., the one named 'release':
  #   git ls-remote --tags release
  # Note that we can restrict to tags with a fuller path, or with an --option.
  #   git ls-remote ${R2G2P_REMOTE} refs/tags/${RELEASE_VERSION}
  #   git ls-remote ${R2G2P_REMOTE} --tags ${RELEASE_VERSION}
  #   git ls-remote ${R2G2P_REMOTE} --tags refs/tags/${RELEASE_VERSION}
  # NOTE: This call takes a moment. (lb): Must be contacting the remote?
  # NOTE: Use default `cut` delimiter, TAB.
  local remote_tag_hash
  remote_tag_hash="$(git ls-remote --tags ${R2G2P_REMOTE} ${RELEASE_VERSION} | cut -f1)"

  printf '%s' \
    "Send remote request: ‘git ls-remote --tags ${R2G2P_REMOTE} ${RELEASE_VERSION}’..."
  printf '%s\n' " ${remote_tag_hash}"

  local tag_commit_hash
  R2G2P_DO_PUSH_TAG=false
  if [ -z "${remote_tag_hash}" ]; then
    R2G2P_DO_PUSH_TAG=true
  else
    tag_commit_hash="$(git rev-list -n 1 ${remote_tag_hash})"
    if [ "${tag_commit_hash}" = "${R2G2P_COMMIT}" ]; then
      # The remote tag has the same commit hash as the current release.
      # No need to send tag again, unless clobbering GitHub release,
      # in which case remove the tag, which removes the lightweight (non-annotated)
      # release from https://github.com/user/repo/releases that's automatically
      # generated according to tags ((lb): or whatever; I'm not quite sure how
      # it works, just that deleting the tag clears the entry).
      ${R2G2P_GHUB_CLOBBER_CERTIFIED:-false} && R2G2P_DO_PUSH_TAG=true
    else
      echo
      echo "🚨 ATTENTION 🚨: The tag on ‘${R2G2P_REMOTE}’ refers to a different commit."
      echo
      echo "    release tag ref.  ${R2G2P_COMMIT}"
      echo "    remote tag ref..  ${tag_commit_hash}"
      echo

      printf %s "Would you like to delete the old remote tag? [y/N] "

      ${SKIP_PROMPTS:-false} && the_choice='n' || read -e the_choice

      if [ "${the_choice}" = "y" ] || [ "${the_choice}" = "Y" ]; then
        R2G2P_DO_PUSH_TAG=true
      else
        >&2 echo
        >&2 echo "ERROR: Tag ‘${RELEASE_VERSION}’ mismatch on ‘${R2G2P_REMOTE}’."
        >&2 echo

        return 1
      fi
    fi
  fi

  if ${R2G2P_DO_PUSH_TAG} && [ -n "${tag_commit_hash}" ]; then
    # (lb): I realize there's a less obtuse syntax to delete tags, e.g.,
    #           git push --delete ${R2G2P_REMOTE} ${RELEASE_VERSION}
    #       But that syntax might also delete a branch of the same name.
    #       So be :obtuse, and be specific about what's being deleted.
    local gpr_args="${R2G2P_REMOTE} :refs/tags/${RELEASE_VERSION}"

    echo "Deleting Remote Tag: ‘${gpr_args}’"

    # Uncomment to debug:
    #   set -x  # xtrace_beg
    git push ${gpr_args}
    #   set +x  # xtrace_end
  fi
}

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

