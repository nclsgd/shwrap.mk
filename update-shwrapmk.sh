#!/bin/sh
# vim: set ft=sh ts=4 sw=4 noet ai tw=79:
# Copyright 2017-2024 Nicolas Godinho <nicolas@godinho.me>
# SPDX-License-Identifier: MIT

set -eu

say() { if [ "$#" -ne 0 ]; then (IFS=' ';echo >&2 "${0##*/}: $*"); fi; }
die() { (IFS=' ';echo >&2 "${0##*/}: ${*:-an error has occurred}"); exit 1; }
quote() {
	while [ "${1+x}" ]; do printf '|%s|' "$1" | sed -e "s/'/'\\\\''/g" -e \
	"1s/^|/'/" -e "\$s/|\$/'/"; printf "${2+ }"; shift; done
}

# Check that program dependencies are there:
DEPENDENCIES='readlink head curl mktemp unzip sed'
is_installed() { command -v >/dev/null "${1:?}"; }
for d in $DEPENDENCIES; do is_installed "$d" || die "Missing \`$d' program"; done
unset d

# Always work in the context directory of this current script:
if [ ! -f "${0:?could not retrieve this script path}" ] || [ "$(head -n 1 "$0")" != '#!/bin/sh' ]; then
	die "\$0 is not a real script file. Bailing out."
fi
case "$0" in */*) SELFDIR="${0%/*}";; *)
	if command -v "$0" >/dev/null 2>&1; then
		die "Ambiguous state: \"$0\" is found via PATH lookup. This may lead in"\
		    "an incorrect discovery of this script's own directory. Bailing out."
	fi
	SELFDIR=".";;
esac
[ -d "$SELFDIR" ] || die "Could not get this script's own directory, got a non-directory: $SELFDIR"
[ -w "$SELFDIR" ] || die "Could not write in this script's own directory: $SELFDIR"
cd "$SELFDIR" || die "Could not change directory to this script's own directory: $SELFDIR"

# Safety checks:
# Note: The Markdown README.md file serves also as a self-update preventing canary file.
[ -f README.md ] && [ "${1:-}" != '--force' ] &&\
  die "This script's own directory seems to be an exact clone of the upstream"\
      "repository and not a vendor copy. Bailing out."
# Notice to the user that this script will "rm -rf" its own directory content:
if [ "$SELFDIR" = . ]; then
	say "This script is about to replace the whole content of the current working directory."
else
	say "This script is about to replace the whole contents of its own directory: $SELFDIR"
fi
printf >&2 '%s' "${0##*/}: Are you sure you want to continue? [y|N]: "
answer=''; read -r answer; case "$answer" in
	y|Y|yes|YES);; ''|n|N|no|NO) say "Aborting on user request."; exit 0;;
	*) die "Unsupported reply: please reply with yes or no.";;
esac; unset answer

# ---

GITHUB_REPOSITORY='https://github.com/nclsgd/shwrap.mk'
GITHUB_GIT_BRANCH='main'
GITHUB_ZIP_ARCHIVE_URL="${GITHUB_REPOSITORY:?}/archive/refs/heads/${GITHUB_GIT_BRANCH:?}.zip"

MYTMPDIR="$(mktemp -d ".update-shwrapmk.XXXXXXX")"
# shellcheck disable=SC2064
trap "rm -rf -- $(quote "$MYTMPDIR") ||:; say 'An error has occurred.'" EXIT

# Only consider HTTPS URLs:
url="$GITHUB_ZIP_ARCHIVE_URL"
[ "${url#https://}" = "$url" ] && die "Not an HTTPS URL: $url"
unset url

say "Fetching latest archive of shwrap.mk..."
(
cd "$MYTMPDIR"
curl --tlsv1.2 --no-insecure --retry 2 --location --output "shwrap.mk-main.zip" \
     "$GITHUB_ZIP_ARCHIVE_URL"
unzip >&2 "shwrap.mk-main.zip"
cd shwrap.mk-main
sed -n -e '/^<!--/,/^-->$/p' README.md | sed -e '1d' -e '$d' > README
rm README.md
rm -rf -- .git* tests TODO
)

say "Replacing contents..."
rm -rf -- *
for f in .* ; do
	if [ "$f" = . ] || [ "$f" = .. ] || [ "$f" = "$MYTMPDIR" ]; then continue; fi
	rm -rf -- "$f"
done

cp -a "$MYTMPDIR"/shwrap.mk-main/* ./
rm -rf -- "$MYTMPDIR"
trap - EXIT

say "Done."
