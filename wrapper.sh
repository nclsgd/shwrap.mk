#!/bin/sh
# vim: set ft=sh ts=4 sw=4 noet ai tw=79:
# Copyright 2017-2024 Nicolas Godinho <nicolas@godinho.me>
# SPDX-License-Identifier: MIT

set -eu

if [ "${EZMKWRAPPER_DISABLE:-0}" != 0 ]; then exit 0; fi

say() { if [ "$#" -ne 0 ]; then (IFS=' ';echo >&2 "${0##*/}: $*"); fi; }
die() { (IFS=' ';echo >&2 "${0##*/}: ${*:-an error has occurred}"); exit 1; }
quote() {
	[ "${1+x}" ] || return 0; printf '%s' "$1|" | sed -e "s/'/'\\\\''/g" \
	-e "1s/^/'/" -e "\$s/|\$/'/"; shift; while [ "${1+x}" ]; do printf '%s' \
	"$1|" | sed -e "s/'/'\\\\''/g" -e "1s/^/ '/" -e "\$s/|\$/'/"; shift; done
}
rtrim() { printf '%s' "${1%"${1##*[![:space:]]}"}"; }

if [ "$#" -eq 0 ]; then die "missing script";
elif [ "$#" -gt 1 ]; then die "too many arguments given"; fi

script="$1"
shell="${EZMKWRAPPER_SHELL:-${SHELL:-/bin/sh}}"
shellflags="${EZMKWRAPPER_SHELLFLAGS:--ec}"
export SHELL="${EZMKWRAPPER_ORIGINAL_SHELL:-$shell}"

# No glob (aka pathname expansion) is desired for all the word splits below:
set -f

# Ensure no command injection is possible via EZMKWRAPPER_VARIABLES:
if awk <&- 'BEGIN { split(ENVIRON["EZMKWRAPPER_VARIABLES"], a); for (i in a) {
if (!match(a[i], /^[A-Za-z_][A-Za-z0-9_]*$/)) exit 0; }; exit 1; }'; then
	die "invalid variable name in EZMKWRAPPER_VARIABLES: $EZMKWRAPPER_VARIABLES"
fi

# Retrieve the name of the Make target:
target="${EZMKWRAPPER_TARGET:-}"

# Save these aside as all EZMKWRAPPER_* environment variables will be stripped:
echoscript="${EZMKWRAPPER_ECHO:-}"
printcmd="${EZMKWRAPPER_PRINTCMD:-}"
printscript="${EZMKWRAPPER_PRINTSCRIPT:-}"

# Separator of shell statements:
sep='; '; if [ "${printscript:-0}" != 0 ]; then sep='
'; fi

# Variable definition statements:
vars=''
for v in ${EZMKWRAPPER_VARIABLES:-}; do
	vars="${vars}${sep}${v}=$(eval "quote \"\${EZMKWRAPPER_VARIABLE_${v}:-}\"")"
done; unset v
vars="${vars#"$sep"}"  # strip prepending separator (semicolon or newline)

# Companion script preloads source statements:
sources=''
for f in ${EZMKWRAPPER_PRELOAD_ALWAYS:-}; do
	sources="${sources}${sep}. $(quote "$f")"
done
if [ -n "$target" ]; then
	for f in ${EZMKWRAPPER_PRELOAD:-}; do
		sources="${sources}${sep}. $(quote "$f")"
	done
fi
unset f
sources="${sources#"$sep"}"  # strip prepending separator (semicolon or newline)

# Stripping EZMKWRAPPER_* variable from environment:
# shellcheck disable=SC2046  # word splitting is wamted here for unset
unset $(env | sed -n -e 's/=.*$//' -e '/^EZMKWRAPPER_[A-Za-z0-9_]*$/p')

# If script output is required:
if [ "${printscript:-0}" != 0 ]; then
	fd=1; if [ -z "$target" ]; then fd=2; fi
	# Strip the -c shell flag from the shellflags:
	set_shellflags_script="$(case "$shellflags" in
		-c)     echo '' ;;
		-*-c)   echo "set $(rtrim "${shellflags%-c}")" ;;
		-*c)    echo "set ${shellflags%c}" ;;
	esac)"
	cat >&"$fd" <<EOF
#!/usr/bin/env $shell
${set_shellflags_script:+"$set_shellflags_script$sep"}
${vars:+"$vars$sep$sep"}${sources:+"$sources$sep$sep"}$script
EOF
	exit 0
fi

# Building the script line:
scriptline="$vars${vars:+"$sep"}$sources${sources:+"$sep"}$script"

if [ "${echoscript:-0}" != 0 ] || [ "${printcmd:-0}" != 0 ]; then
	fd=1; if [ -z "$target" ]; then fd=2; fi
	printf >&"$fd" '%s\n' "$shell $shellflags $(quote "$scriptline")"
	if [ "${printcmd:-0}" != 0 ]; then exit 0; fi
fi

# shellcheck disable=SC2086  # word splitting is wanted here for shellflags
exec "$shell" $shellflags "$scriptline"
