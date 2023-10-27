#!/bin/sh
# vim:tw=0:ts=2:sw=2:et:norl:ft=sh
# Project: https://github.com/landonb/sh-git-nubs#🌰
# License: MIT

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

git_branch_exists () {
  local branch_name="$1"

  # Hrmm, you'd think this would not print:
  #   git rev-parse --verify --quiet HEAD
  # This works, but technically we should use rev-parse:
  #  git show-ref --verify --quiet refs/heads/${branch_name}
  git rev-parse --verify refs/heads/${branch_name} > /dev/null 2>&1
}

git_branch_name () {
  local project_root
  project_root="$(git_project_root)"
  [ $? -eq 0 ] || return

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

git_branch_name_full () {
  git rev-parse --symbolic-full-name HEAD
}

git_branch_name_check_format () {
  local branch_name="$1"

  # Use --branch, which is stricter than the more basic:
  #   git check-ref-format "refs/heads/${branch_name}"
  # - It's not documented, but echoes valid branch name
  #   (unlike without --branch, then nothing output).
  git check-ref-format --branch "${branch_name}" > /dev/null 2>&1
}

# ***

# SAVVY/2020-07-01: Two ways to print "{remote}/{branch}":
#   git rev-parse --abbrev-ref --symbolic-full-name @{u}
# and
#   git for-each-ref --format='%(upstream:short)' "$(git symbolic-ref -q HEAD)"
# CXREF: *Find out which remote branch a local branch is tracking*
#   https://stackoverflow.com/questions/171550/

# Prints the tracking aka upstream branch.
git_tracking_branch () {
  git rev-parse --abbrev-ref --symbolic-full-name @{u} 2> /dev/null
}

git_upstream () {
  git_tracking_branch
}

git_tracking_branch_safe () {
  # Because errexit, fallback on empty string.
  git_tracking_branch || echo ''
}

# ***

# BWARE: If the arg. is a valid SHA format, git-rev-parse echoes
#        it without checking if object actually exists.
#        - See git_is_commit for checking if commit object.
git_commit_object_name () {
  local gitref="${1:-HEAD}"
  local opts="$2"

  git rev-parse ${opts} "${gitref}"
}

git_is_same_commit () {
  local lhs="$1"
  local rhs="$2"

  [ "$(git_commit_object_name "${lhs}")" = "$(git_commit_object_name "${rhs}")" ]
}

# There are a few ways to find the object name (SHA) for a tag:
#
#   git rev-parse refs/tags/sometag
#   git rev-parse --tags=*some/tag
#   git show-ref --tags
#
# Per `man git-rev-parse` --tags appends "/*" if search doesn't include glob
# character (*?[), making it a prefix match -- and also making it *not* match
# what you're trying to search, which seems like a weird interface choice.
# - E.g., searching for some/tag:
#     git rev-parse --tags=some/tag
#   won't actually match some/tag. It will match some/tag/name.
#   - To match some/tag, you have to glob it explicitly, e.g.,
#       git rev-parse --tags=*some/tag
#       git rev-parse --tags=some/tag*
#       git rev-parse --tags=[s]ome/tag
#   - But there's no way to make an exact tag name match using --tags.
#     - Which I guess is Git nudging you to use refs/tags/.
# Note the UX differences between using refs/tags/ vs. --tags:
# - If not found, refs/tags reprints argument, "ambiguous argument" message,
#   and exits nonzero. --tags prints nothing and exits zero.
#   - Here we mimic --tags.
git_tag_object_name () {
  local gitref="$1"
  local opts="$2"

  [ -n "${gitref}" ] || return 0

  local says_git=""
  says_git="$(git rev-parse ${opts} refs/tags/${gitref} 2> /dev/null)"
  [ $? -ne 0 ] || echo "${says_git}"
}

git_tag_commit_object () {
  local gitref="$1"
  local opts="$2"

  git_tag_object_name "${gitref}^{commit}" "${opts}"
}

git_tag_exists () {
  local tag_name="$1"

  git rev-parse --verify refs/tags/${tag_name} > /dev/null 2>&1
}

git_tag_name_check_format () {
  local tag_name="$1"

  git check-ref-format "refs/tags/${tag_name}"
}

# ***

git_HEAD_commit_sha () {
  git rev-parse HEAD
}

# Use --first-parent to stick to commits in the branch you're on, and
# not to consider a feature branch you merged that maybe (a rare case)
# derived from a parentless commit, in which case rev-list would output
# more than one commit object. (Oddly, my landonb/homefries.git project
# has such a case early in its history.)
git_first_commit_sha () {  # aka git_root_commit_sha, perhaps
  git rev-list --max-parents=0 --first-parent HEAD
}

git_first_commit_message () {
  git --no-pager log --format=%s --max-parents=0 --first-parent HEAD
}

git_latest_commit_message () {
  git --no-pager log --format=%s -1 "${1:-HEAD}"
}

git_child_of () {
  git --no-pager log --reverse --ancestry-path --format='%H' ${1}..HEAD \
    | head -1
}

# Some obvious and non-obvious ways to get the parent to a commit:
#   git rev-parse $1^
#   git --no-pager log --pretty=%P -n 1 $1
#   git cat-file -p $1 | grep -e "^parent " | awk '{ print $2 }'
# - If given first commit (or first-commit^):
#   - git-rev-parse echos query and prints message to stderr.
#   - git-log prints nothing.
#   - git-cat-file prints commit meta without parent line,
#     so awk prints nothing.
#   Note that git-rev-parse is the least best choice, if you want to
#   just not print anything if no parent -- it not only prints a long
#   error message, but it echoes the query back to stdout, so you'd have
#   to store the query, test $?, then print the query if not an error.
#   - Of the other two, git-log's error message when the commit object is
#     unknown is 3 lines long and super not helpful: it spends 2 lines
#     telling you to use '--' to separate paths, and the first line leads
#     with the confusing "fatal: ambiguous argument". Or at least it's
#     confusing to me, like, "What's 'ambiguous'? Oh, it's the object ref.
#     that's not a real object." Which is why I like cat-file's error the
#     best: "fatal: Not a valid object name 'foo'".
git_parent_of () {
  git cat-file -p $1 | grep -e "^parent " | awk '{ print $2 }'
}

# See also git-extra's git-count, which counts to HEAD, and with --all
# print counts per author.
git_number_of_commits () {
  local gitref="${1:-HEAD}"
  [ -z "$1" ] || shift

  git rev-list --count "${gitref}" "$@"
}

# ***

git_remote_exists () {
  local remote="$1"

  git remote get-url ${remote} &> /dev/null
}

git_remote_branch_exists () {
  local remote_branch="$(_git_print_remote_branch_unambiguous "${1}" "${2}")"

  # SHOWS: [branchname] <most recent commit message>
  git show-branch "${remote_branch}" &> /dev/null
}

git_remote_branch_object_name () {
  local remote_branch="$(_git_print_remote_branch_unambiguous "${1}" "${2}")"

  # Prints SHA1.
  git rev-parse "${remote_branch}" 2> /dev/null
}

# Prints refs/remotes/<remote>/<branch>.
_git_print_remote_branch_unambiguous () {
  local remote="$1"
  local branch="$2"

  local remote_branch=""

  if [ -z "${branch}" ]; then
    # Assume caller passed in remote/branch.
    remote_branch="${remote}"
  else
    remote_branch="${remote}/${branch}"
  fi

  printf "refs/remotes/$(echo "${remote_branch}" | sed 's#^refs/remotes/##')"
}

git_remote_default_branch () {
  local remote="$1"

  [ -n "${remote}" ] || return 1

  git remote show ${remote} | grep 'HEAD branch' | cut -d' ' -f5
}

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

# MEH/2022-12-16: This seems like a problem that's likely been solved
# many times before: Given a remote branch name, how to parse out the
# remote name and parse out the branch name. But I don't know of any
# solutions, and a quick search didn't enlighten me, so I baked my own.

# Think of this as `dirname` of remote branch ref. (aka `rootname`).
git_upstream_parse_remote_name () {
  local remote_branch="$1"

  [ -n "${remote_branch}" ] || remote_branch="$(git_tracking_branch)"

  # echo "$1" | sed 's/\/.*$//'
  # echo "$1" | sed -E 's#^(refs/remotes/)?([^/]+)/.*$#\2#'
  # echo "$1" | sed 's#^refs/remotes/##' | sed 's/\/.*$//'
  git_upstream_parse_names true false "${remote_branch}"
}

# Think of this as `basename` of remote branch ref. (aka `rootless`).
git_upstream_parse_branch_name () {
  local remote_branch="$1"

  [ -n "${remote_branch}" ] || remote_branch="$(git_tracking_branch)"

  # echo "$1" | sed 's/^[^\/]*\///'
  # echo "$1" | sed -E 's#^(refs/remotes/)?[^/]+/##'
  # echo "$1" | sed 's#^refs/remotes/##' | sed 's/^[^\/]*\///'
  git_upstream_parse_names false true "${remote_branch}"
}

git_upstream_parse_names () {
  local print_remote="${1:-false}"
  local print_branch="${2:-false}"
  local upstream_ref="$3"

  local deprefixed="$(echo "${upstream_ref}" | command sed 's#^refs/remotes/##')"
  local remote_name="$(_git_parse_path_rootname "${deprefixed}")"
  local branch_name="$(_git_parse_path_rootless "${deprefixed}")"

  # ***

  if [ "${remote_name}" = "refs" ]; then
    >&2 echo "ERROR: Cannot parse non-remotes refs/ upstream reference: ${upstream_ref}"

    return 1
  fi

  # If one, then both, so say we all.
  # - These tests cover inputs like "foo" and "bar/".
  if false\
    || [ -z "${remote_name}" ] \
    || [ -z "${branch_name}" ] \
    || [ "${remote_name}" = "${deprefixed}" ] \
    || [ "${branch_name}" = "${deprefixed}" ]; \
  then
    return 0
  fi

  # ***

  ! ${print_remote} || printf "${remote_name}"
  ! ${print_branch} || printf "${branch_name}"
}

# The other opposite of `dirname`, `rootname`.
_git_parse_path_rootname () {
  echo "$1" | command sed 's#/.*$##'
}

# The other opposite of `basename`, something progenitor? `progname`?
_git_parse_path_rootless () {
  echo "$1" | command sed 's#^[^/]*/##'
}

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

# Note that Git resolves symlinks, e.g., what cd'ing to project root
# and running `realpath .`, `readlink -f .`, or `pwd -P` would show.
git_project_root () {
  git_project_root_absolute
}

git_project_root_absolute () {
  # Same output as git-extras's `git root`.
  git rev-parse --show-toplevel
}

git_project_root_relative () {
  (cd "./$(git rev-parse --show-cdup)" && pwd -L)
}

# Print empty string if at project root;
# print '../'-concatenated path to project root;
# or git prints to stderr if not a Git project.
print_parent_path_to_project_root () {
  local depth_path="$(git root -r)"
  # SPIKE/2022-12-11: Confirm this is what I see:
  # - ✓ `git root -r` returns empty string @linux.
  # - ? On @macOS, does it return '.'?
  ( [ "${depth_path}" = "." ] || [ "${depth_path}" = "" ] ) \
    && return 0 || true

  printf "${depth_path}" | command sed 's#\([^/]\+\)#..#g'
}

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
  ! test -n "$(git status --porcelain=v1)" && return 0

  local projpath="${1:-$(pwd)}"

  ${GIT_NUBS_SURROUND_ERROR:-true} && >&2 echo
  >&2 echo "ERROR: Working directory not tidy."
  >&2 echo "- HINT: Try:"
  >&2 echo
  >&2 echo "   cd \"${projpath}\" && git status"
  ${GIT_NUBS_SURROUND_ERROR:-true} && >&2 echo

  return 1
}

# I use the term 'tidy' a lot (as opposed to 'clean' (and 'dirty')),
# so might as well make the alias function.
git_insist_tidy () {
  git_insist_pristine "$@"
}

git_nothing_staged () {
  local filepath="$1"

  if [ -z "${filepath}" ]; then
    git diff --cached --quiet
  else
    git diff --cached --quiet -- "${filepath}"
  fi
}

git_insist_nothing_staged () {
  ! git_nothing_staged || return 0

  local projpath="${1:-$(pwd)}"

  ${GIT_NUBS_SURROUND_ERROR:-true} && >&2 echo
  >&2 echo "ERROR: Working directory has staged changes."
  >&2 echo "- HINT: Try:"
  >&2 echo
  >&2 echo "   cd \"${projpath}\" && git status"
  ${GIT_NUBS_SURROUND_ERROR:-true} && >&2 echo

  return 1
}

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

# A few ideas to check for valid SHA1 object:
#
# - cat-file:
#
#   - At its most basic, cat-file tells us the type of object,
#     so we could do a simple string comparison:
#
#       test "$(git cat-file -t "${gitref}")" == commit
#
#   - Getting a little more tricky, we can use the recursive deference
#     syntax ^{commit} combined with the -e option, so cat-file only
#     prints on error, e.g.,
#       fatal: Not a valid object name {}
#     Or, on success, if {gitref} exists and is a value commit, outputs
#     nothing and returns zero:
#
#       git cat-file -e "${gitref}^{commit}" > /dev/null
#
#     - REFER: See `man gitrevisions` for deference syntax.
#
# - rev-parse
#
#   - Prints SHA1 to stdout on success. Otherwise prints an error, e.g.,
#       error: acbd1234^{commit}: expected commit type, but the object dereferences to tree type
#     And despite whatever you think `--quiet` means, still prints to
#     stdout on success, so you might test for nonzero length stdout:
#
#       [ -n "$(git rev-parse --verify --quiet "${gitref}^{commit}" 2> /dev/null)" ]
#
#     Or you could suppress both outputs and just pass along the exit code:
#
#       git rev-parse --verify --quiet "${gitref}^{commit} > /dev/null 2>&1
#
# - show-ref
#
#   - Cannot be used with SHA1, but works if you have a name, e.g.,
#
#       git show-ref --verify --quiet refs/heads/${ref_name}
#       git show-ref --verify --quiet refs/remotes/${ref_name}
#       git show-ref --verify --quiet refs/tags/${ref_name}
#
# - REFER:
#
#     https://stackoverflow.com/questions/18515488/
#       how-to-check-if-the-commit-exists-in-a-git-repository-by-its-sha-1
#
# - CHOSE:
#
#   - Considering previous discussion, `cat-file -e` seems like the most clear
#     (and concise) approach.
#     - From its man: "Provide content or type and size information for repository objects"
#       Which is what we're looking for: *type* information.
#     - `man git-rev-parse` has a more broad scope, "Pick out and massage parameters."

# ***

# git_is_commit tests whether specified ref exists and is a valid commit object.
# - See also git_commit_object_name, which uses git-rev-parse to resolve a name
#   to an object ID. But if you pass rev-parse an object ID, it just echoes that
#   ID back without validating it.
#   - So you might want to call git_is_commit afterwards to verify a SHA.
# - Note that cat-file also works with branch names, so user could skip
#   git_commit_object_name if you just want to verify something is a commit but
#   don't need the SHA.

git_is_commit () {
  local gitref="$1"

  git cat-file -e "${gitref}^{commit}" 2> /dev/null
}

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

# LATER/2023-05-28: Leaving __THE_HARD_WAY variant: I want to add
# tests, and I want to verify the 2 approaches produce same results.

# Show versions tagged on specified object, or HEAD.
# - Strips leading 'v' prefix from tag names.
git_versions_tagged_for_commit_object__THE_HARD_WAY () {
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
  # (Note that the pattern matches looser than semantic versioning spec,
  #  e.g., "v1.2.3a3" is not valid SemVer, but "1.2.3-a3" is.)
  # Where:
  #   $ git cat-file -t af6ec9a9ae01592d36d06917e47b8ee9822178a7
  #   tag
  #   $ git cat-file -t 7ca83ee766d31181b34e6aafb340f537e2cc0d6f
  #   commit
  # So search on the known commit hash, which returns refs/tags/<tag>^{},
  # then isolate just the tag -- and match only tags with a leading digit
  # (assuming that indicates a version tag, to exclude non-version tags).
  git show-ref --tags -d \
    | grep -E -e "^${hash}.* refs/tags/${GITSMART_RE_VERSPARTS__INCLUSIVE}" \
    | command sed \
      -e 's#.* refs/tags/v\?##' \
      -e 's/\^{}//'
}

# Show versions tagged on specified object, or HEAD.
# - Strips leading 'v' prefix from tag names.
git_versions_tagged_for_commit_object () {
  local object="$1"

  git tag --list --points-at ${object} \
    | grep -E -e "${GITSMART_RE_VERSPARTS}" \
    | command sed -e 's/^v//'
}

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

# Semantic Versioning 2.0.0 and version-ish tag name regex.

# Match groups: \1: 'v'       (optional)
#               \2: major     (required)
#               \3: minor     (required)
#               \4: \5\6\7    (optional)
#               \5: patch
#               \6: pre-release (up to any final digits)
#               \7: pre-release (any final digits)
# Note that this is not strictly Semantic Versioning compliant:
# - It allows a leading 'v', which some devs/projects use.
# - It allows for a pre-release/build part that includes characters
#   that SemVer does not allow, which is limited to [-a-zA-Z0-9].
#   - SemVer also insists on a '-' or '+' between the patch and the
#     pre-release version, whereas this regex allows any non-digit,
#     e.g., this regex allows non-SemVer such as "1.0.0a1".
#   - But this fine. This regex is meant to be more inclusive, so that
#     it finds with more version tags, or what look like version tags.
#   - This regex is very useful when used in tandem with the SemVer
#     regex, defined after. E.g., you could verify a version tag is
#     valid with the SemVer regex; then you could use our regex to pull
#     apart the components so you can bump any part, including the
#     pre-release (assuming the pre-release part ends in a number).
#   - Note the ".*?" usage, which is Perl for less greedy. But grep and
#     sed see it as ".*" (zero-or-more chars) and "?" (optional), which
#     is redundant. So you can use this regex for matching with any
#     command, but you'll want to use Perl for splitting or substitution.
# - Remember to use Perl for substitution, e.g.,
#     $ perl -pe "s/${GITSMART_RE_VERSPARTS}/NubsVer: \1 \2 \3 \5 \6 \7/" <<<"v1.2.3-1alpha1"
#     NubsVer: v 1 2 3 -1alpha 1
#   But sed will be too greedy (and what should be \7 will be gobbled by \6):
#     $ echo "v1.2.3-1alpha1" | sed -E "s/${GITSMART_RE_VERSPARTS}/NubsVer: \1 \2 \3 \5 \6 \7/"
#     NubsVer: v 1 2 3 -1alpha1

GITSMART_RE_VERSPARTS__INCLUSIVE='(v)?([0-9]+)\.([0-9]+)(\.([0-9]+)([^0-9].*?)?([0-9]+)?)?'
GITSMART_RE_VERSPARTS="^${GITSMART_RE_VERSPARTS__INCLUSIVE}$"

# CXREF: SemVer Perl regex, from the source, unaltered.
#   https://semver.org/
#   https://regex101.com/r/Ly7O1x/3/
# - You could try, e.g.,
#     $ perl -pe "s/${GITSMART_RE_SEMVERSPARTS}/SemVer: \1 \2 \3 \4 \5/" <<<"1.0.0+alpha-a.b-c.1.d"
#     SemVer: 1 0 0  alpha-a.b-c.1.d
#     $ perl -pe "s/${GITSMART_RE_SEMVERSPARTS}/SemVer: \1 \2 \3 \4 \5/" <<<"1.0.0-alpha+a.b-c.1.d"
#     SemVer: 1 0 0 alpha a.b-c.1.d
#   Or
#     $ echo "1.2.3-a.4" | perl -ne "print if s/${GITSMART_RE_SEMVERSPARTS}/\1 \2 \3 \4 \5/"
#     1 2 3 a.4
#   Or
#     $ echo "1.2.3-a.4" | perl -ne "print if /${GITSMART_RE_SEMVERSPARTS}/"
#     1.2.3-a.4
#     $ echo "v1.2.3" | perl -ne "print if /${GITSMART_RE_SEMVERSPARTS}/"
#     # OUTPUT: None. Not a valid SemVer.

GITSMART_RE_SEMVERSPARTS='^(?P<major>0|[1-9]\d*)\.(?P<minor>0|[1-9]\d*)\.(?P<patch>0|[1-9]\d*)(?:-(?P<prerelease>(?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*)(?:\.(?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*))*))?(?:\+(?P<buildmetadata>[0-9a-zA-Z-]+(?:\.[0-9a-zA-Z-]+)*))?$'

# ***

# Return the latest version tag (per Semantic Versioning rules).

# Note that git-tag only accepts a glob(7), and not a regular expression,
# so we'll filter with grep to pick out the latest version tag. (Meaning,
# the glob is unnecessary, because grep does all the work, but whatever.)

# This glob selects tags that start with an optional 'v', followed by 0-9.
# - We use it as a git-tag prefilter, but it's really the grep after it
#   truly filters the version tags.
# - CPYST: Copy-paste test snippet:
#     git --no-pager tag -l ${GITSMART_VERSION_TAG_PATTERNS}
GITSMART_VERSION_TAG_PATTERNS="v[0-9]* [0-9]*"

# Get the latest non-pre-release version tag, e.g., 1.2.3.

git_latest_version_basetag () {
  # Any args are passed to git-tag.

  git tag -l "$@" ${GITSMART_VERSION_TAG_PATTERNS} |
    command grep -E -e "${GITSMART_RE_VERSPARTS}" |
    command sed -E "s/${GITSMART_RE_VERSPARTS}/\2.\3.\5/" |
    command sort -r --version-sort |
    command head -n1
}

# Get the latest pre-release version tag for a given non-pre-release version.
# - E.g., pass it "1.0.0" and it prints "1.0.0-rc.1" (per the example below).
#
# - We use our version regex to sort first by lexicographical order,
#   then by trailing number... which should be SemVer-compatible-enough
#   for our usage, as we explain.
#
#   Here's the SemVer procedure:  https://semver.org/#spec-item-11
#
#     1.) Identifiers consisting of only digits are compared numerically.
#
#     2.) Identifiers with letters or hyphens are compared lexically in ASCII sort order.
#
#     3.) Numeric identifiers always have lower precedence than non-numeric identifiers.
#
#     4.) A larger set of pre-release fields has a higher precedence than a smaller set,
#         if all of the preceding identifiers are equal.
#
#     Example: 1.0.0-alpha
#            < 1.0.0-alpha.1
#            < 1.0.0-alpha.beta
#            < 1.0.0-beta
#            < 1.0.0-beta.2
#            < 1.0.0-beta.11
#            < 1.0.0-rc.1
#            < 1.0.0
#
#   - The `sort -k1,1 -k2,2n` we use below does alright:
#              1.0.0-alpha
#              1.0.0-alpha.1
#              1.0.0-alpha.beta
#              1.0.0-beta
#              1.0.0-beta.2
#              1.0.0-beta.11
#              1.0.0-rc.1
#     So long as you keep the pipeline to a single basevers (e.g., 1.2.3),
#     and that you don't call it if the basevers itself is a version tag
#     (because the basevers gets sorted lowest).
#     - BWARE: Note we haven't tested further than this. You'll be fine
#       if you stick to a format similar to the example tags above, but
#       if you stray too far, this pipeline will likely sort differently
#       than SemVer specifies.

# This call assumes there are pre-releases for ${basevers},
# and not an exact ${basevers} version.
# - That is to say, this function returns the largest pre-release
#   tag for a given basevers (or the basevers itself if there are
#   no pre-release tags; or nothing if there's no basevers tag).
latest_version_fulltag () {
  local basevers="$1"
  # Any additional args are passed to git-tag.

  # Use Perl, not sed, because of ".*?" non-greedy (so \7 works).
  git tag -l "$@" "${basevers}*" "v${basevers}*" |
    command grep -E -e "${GITSMART_RE_VERSPARTS}" |
    command perl -ne "print if s/${GITSMART_RE_VERSPARTS}/\6, \7, \1\2.\3.\5\6\7/" |
    command sort -k1,1 -k2,2n |
    command tail -n1 |
    command sed -E "s/^[^,]*, [^,]*, //"
}

# Note that git-tag has a few options which seems like they could be
# useful to help sort tags by latest:
#   git tag --list --sort=taggerdate
#   git tag --list --sort=-version:refname
#   git tag --list --sort=-committerdate
# but we really only care about the *largest* version tag ever used,
# because the use case we're after is *bumping* the version. So the
# user should never want to use the latest version to bump, they want
# to use the largest version to bump.
# - Also I didn't dig deep enough to understand, e.g., how the two
#   options, --sort=taggerdate and --sort=-committerdate, work (like,
#   what's "taggerdate", never heard of it). Nor did I did into how
#   --sort=-version:refname works or compares to SemVer sorting rules.

# SAVVY: This returns the largest version ever tagged on a repo,
# in any branch — so if you'd only like the largest version
# applied in a *specific* branch, one could pass additional
# arguments to constrain the results, e.g.,
#   git_largest_version_tag --contains $(git first-commit)
# would return the largest verstion tag from the current branch.

git_largest_version_tag () {
  # Any args are passed to git-tag.

  local basevers="$(git_latest_version_basetag "$@")"

  # See if the basevers tag is an actual tag (e.g., 1.2.3), otherwise
  # git_latest_version_basetag only found pre-release versions.
  # - A basevers version is higher than any pre-release with the same basevers.
  if git show-ref --tags -- "${basevers}" > /dev/null; then
    fullvers="${basevers}"
  else
    # Latest version is a prerelease tag. Determine which pre-release
    # from that basevers is the largest.
    fullvers="$(latest_version_fulltag "${basevers}" "$@")"
  fi

  [ -z "${fullvers}" ] || echo "${fullvers}"
}

# ***

git_latest_version_basetag_safe () {
  git_latest_version_basetag || printf '0.0.0'
}

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
    "$(git_latest_version_basetag_safe)" \
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
    "$(git_first_commit_sha)" \
    2> /dev/null
}

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

# Verifies named tag exists at specified commit on indicated remote.
# - If tag exists and points at commit, returns GNUBS_TAG_PRESENT (0).
# - If tag absent from remote, returns GNUBS_TAG_ABSENT (1).
# - If tag exists but points at other commit, returns GNUBS_TAG_CONFLICT (2),
#   and assigns the offending commit ID to GNUBS_TAG_COMMIT_OBJECT global.
#
# - SAVVY: If the remote is GitHub, and if the tag is a version tag,
#   GitHub will remove any lightweight release associated with that tag.
#
# - WRKLG: Use git-ls-remote to examine existing remote tags.
#   - At its simplest, use --tags to view all tags for a remote, e.g.,
#       git ls-remote --tags origin
#   - To find the tag object ID for a specific tag, specify the tag, e.g.,
#       git ls-remote ${remote_name} refs/tags/${tag_name}
#       git ls-remote --tags ${remote_name} ${tag_name}
#       git ls-remote --tags ${remote_name} refs/tags/${tag_name}#
#   - You can also reverse two args:
#       git ls-remote ${remote_name} --tags ${tag_name}
#       git ls-remote ${remote_name} --tags refs/tags/${tag_name}#
#     But the same doesn't work without a tag argument, e.g.,
#       git ls-remote ${remote_name} --tags  # NO_OP: Prints nothing!
#     - Note the manual shows --tags before <repository>.
#   - The output is very simple, e.g.,
#       $ git ls-remote --tags origin 1.0.3
#       882561bc420497d0791b7dcfeb81c1a3684f65bd	refs/tags/1.0.3
git_tag_remote_verify_commit () {
  local tag_name="$1"
  local remote_name="$2"
  local tag_commit="$3"
  local skip_prompt="$4"

  local retcode
  # retcode: -1: failed
  # retcode:  0: verified remote tag, caller doesn't need to push
  # retcode:  1: missing/deleted tag, caller should push
  # retcode:  2: remote tag exists but does not ref tag_commit
  # NOTE: Not using 'local', so caller can (<ahem>) use (which is
  #       a terrible abuse of scoping, I admit).
  GNUBS_FAILED=-1
  GNUBS_TAG_PRESENT=0
  GNUBS_TAG_ABSENT=1
  GNUBS_TAG_CONFLICT=2

  # GLOBAL return value, used on GNUBS_TAG_CONFLICT.
  GNUBS_TAG_COMMIT_OBJECT=""

  # The ls-remote command prints a tag object ID, which we need to resolve
  # to the commit object.
  local remote_tag_hash

  local git_cmd="git ls-remote --tags ${remote_name} ${tag_name}"

  printf '%s' "Sending remote request: ‘${git_cmd}’... "
  #
  # UWAIT: This is a network call and takes a moment.
  remote_tag_hash_and_path="$(${git_cmd})"
  #
  if [ $? -ne 0 ]; then
    printf '!\n'

    retcode=${GNUBS_FAILED}

    return ${retcode}
  fi
  #
  # SAVVY: The default `cut` delimiter is <Tab>.
  remote_tag_hash="$(echo "${remote_tag_hash_and_path}" | cut -f1)"
  #
  printf '%s\n' " ${remote_tag_hash}"

  if [ -z "${remote_tag_hash}" ]; then
    retcode=${GNUBS_TAG_ABSENT}
  else
    local tag_commit_hash
    tag_commit_hash="$(git rev-list -n 1 ${remote_tag_hash})"

    if [ "${tag_commit_hash}" = "${tag_commit}" ]; then
      # The remote tag has the same commit hash as the current release.
      retcode=${GNUBS_TAG_PRESENT}
    else
      retcode=${GNUBS_TAG_CONFLICT}

      GNUBS_TAG_COMMIT_OBJECT="${tag_commit_hash}"
    fi
  fi

  return ${retcode}
}

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

