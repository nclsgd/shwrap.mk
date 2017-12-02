# shellcheck shell=bash
# vim: set ft=sh ts=4 sw=4 noet ai tw=79:
# Copyright 2017-2024 Nicolas Godinho <nicolas@godinho.me>
# SPDX-License-Identifier: MIT

# This file provides my own little set of common library functions written in
# pure Bash (relying the less possible on external POSIX programs). These
# function set is intended to provide easy ways to print colorful messages on
# the terminal (provided that stderr is a TTY), to show more thorough debugging
# traces via the Bash xtrace option, to safely parse boolean values (as shell
# scripts lack such kind of data type), etc.

# Bash >= 4.3 is required
if [ -z "${BASH_VERSINFO:+ok}" ] || [[ "${BASH_VERSINFO[0]:-}" -lt 4 ]] ||
   [[ "${BASH_VERSINFO[0]:-}" -eq 4 && "${BASH_VERSINFO[1]:-}" -lt 3 ]]
then
	echo >&2 "Fatal error: Bash 4.3 at least is required for this script."
	exit 2
fi

# ---

linebreak() { echo >&2; }; readonly -f linebreak

# ---

interrupt_xtrace() {
	local __xtrace_on_hold_during_this_function__="${-//[^x]}"; set +x
	local ret=0; "$@" && ret="$?" || ret="$?"
	if [[ "${__xtrace_on_hold_during_this_function__}" ]]; then set -x; fi
	return "$ret"
}
readonly -f interrupt_xtrace

# ---

misuse() {
	local __xtrace_on_hold_during_this_function__="${-//[^x]}"; set +x
	printf >&2 '%s\n' "${FUNCNAME[1]:-<global-scope>}:$(printf ' %s' "${@:-misuse}")"
	# shellcheck disable=SC2015  # hack to prevent function from returning !0
	[[ "${__xtrace_on_hold_during_this_function__}" ]] && set -x || :
}
readonly -f misuse

# ---

quote() { interrupt_xtrace _quote "$@"; }; readonly -f quote
_quote() {
	[[ "$#" -ge 1 ]] || return 0
	local s; printf -v s '%s ' "${@@Q}"; printf '%s\n' "${s% }"
}
readonly -f _quote

# ---

msgprefix_set() { interrupt_xtrace _msgprefix_set "$@"; }; readonly -f msgprefix_set
msgprefix_unset() { interrupt_xtrace _msgprefix_unset "$@"; }; readonly -f msgprefix_unset

_msgprefix_set() {
	[[ "$#" -eq 1 ]] || { misuse "usage: <prefix>"; return 1; }
	[[ "${1:-}" ]] || { misuse "prefix cannot be empty or null"; return 1; }
	declare -g +x ___msgprefix___="$1"
}
readonly -f _msgprefix_set

_msgprefix_unset() {
	[[ "$#" -eq 0 ]] || { misuse "too many argyments given"; return 1; }
	declare -g +x ___msgprefix___=''
}
readonly -f _msgprefix_unset

# ---

_msgfmt() {
	[[ "$#" -ge 2 ]] || { misuse "usage: <msgkind> <text>..."; return 1; }
	local msgkind="${1:?missing message kind}"; shift;
	_msgfmt- "$msgkind" <<< "$(printf -v s '%s ' "$@"; printf '%s\n' "${s% }")"
}
readonly -f _msgfmt

_msgfmt-() {
	[[ "$#" -eq 1 ]] || { misuse "usage: <msgkind>  ; msg text is read from stdin"; return 1; }
	local msgkind="${1:?missing message kind}"; shift;
	local color=''; if [[ -t 2 && -z "${NO_COLOR:-}" ]]; then color=1; fi
	local prefix="${___msgprefix___:-}"
	[[ "$color" && "$prefix" ]] && prefix=$'\e[0;3m'"$prefix"$'\e[0m'
	prefix="${prefix}${prefix:+|}"
	local firstline=1 line='' c='' b='' r='';
	if [[ "$color" ]]; then c=$'\e[0;1m' b=$'\e[0;1m' r=$'\e[0m'; fi
	case "$msgkind" in
	message)
		if [[ "$color" ]]; then c=$'\e[0;1;34m'; fi
		while IFS='' read -r line; do
			if [[ "$firstline" ]]; then
				printf >&2 "%s ${c}**${r} %s\n" "$prefix" "$line"
			else
				printf >&2 "%s ${c}  ${r} %s\n" "$prefix" "$line"
			fi; firstline='';
		done ;;
	info)
		if [[ "$color" ]]; then c=$'\e[0;1;34m'; fi
		while IFS='' read -r line; do
			if [[ "$firstline" ]]; then
				printf >&2 "%s${c}INFO:${r} ${b}%s${r}\n" "$prefix" "$line"
			else
				printf >&2 "%s${c}    |${r} ${b}%s${r}\n" "$prefix" "$line"
			fi; firstline='';
		done ;;
	ok)
		if [[ "$color" ]]; then c=$'\e[0;1;32m'; fi
		while IFS='' read -r line; do
			if [[ "$firstline" ]]; then
				printf >&2 "%s${c}OK:${r} ${b}%s${r}\n" "$prefix" "$line"
			else
				printf >&2 "%s${c}  |${r} ${b}%s${r}\n" "$prefix" "$line"
			fi; firstline='';
		done ;;
	success)
		if [[ "$color" ]]; then c=$'\e[0;1;32m'; fi
		while IFS='' read -r line; do
			if [[ "$firstline" ]]; then
				printf >&2 "%s${c}SUCCESS:${r} ${b}%s${r}\n" "$prefix" "$line"
			else
				printf >&2 "%s${c}       |${r} ${b}%s${r}\n" "$prefix" "$line"
			fi; firstline='';
		done ;;
	warning)
		if [[ "$color" ]]; then c=$'\e[0;1;33m'; fi
		while IFS='' read -r line; do
			if [[ "$firstline" ]]; then
				printf >&2 "%s${c}WARNING:${r} ${b}%s${r}\n" "$prefix" "$line"
			else
				printf >&2 "%s${c}       |${r} ${b}%s${r}\n" "$prefix" "$line"
			fi; firstline='';
		done ;;
	error)
		if [[ "$color" ]]; then c=$'\e[0;1;31m'; fi
		while IFS='' read -r line; do
			if [[ "$firstline" ]]; then
				printf >&2 "%s${c}ERROR:${r} ${b}%s${r}\n" "$prefix" "$line"
			else
				printf >&2 "%s${c}     |${r} ${b}%s${r}\n" "$prefix" "$line"
			fi; firstline='';
		done ;;
	failure)
		if [[ "$color" ]]; then c=$'\e[0;1;31m'; fi
		while IFS='' read -r line; do
			if [[ "$firstline" ]]; then
				printf >&2 "%s${c}FAILURE:${r} ${b}%s${r}\n" "$prefix" "$line"
			else
				printf >&2 "%s${c}       |${r} ${b}%s${r}\n" "$prefix" "$line"
			fi; firstline='';
		done ;;
	prompt)
		# No newline at the end of the message but just a whitespace:
		if [[ "$color" ]]; then c=$'\e[0;1;36m'; fi
		while IFS='' read -r line; do
			if [[ "$firstline" ]]; then
				printf >&2   "%s ${c}>>${r} ${b}%s${r}" "$prefix" "$line"
			else
				printf >&2 "\n%s ${c}  ${r} ${b}%s${r}" "$prefix" "$line"
			fi; firstline='';
		done; printf >&2 ' ' ;;
	*)
		misuse "unknown message kind: $msgkind"; return 1 ;;
	esac
}
readonly -f _msgfmt-

msg() { interrupt_xtrace _msgfmt message "$@"; }; readonly -f msg
msg-() { interrupt_xtrace _msgfmt- message "$@"; }; readonly -f msg-

msginfo() { interrupt_xtrace _msgfmt info "$@"; }; readonly -f msginfo
msginfo-() { interrupt_xtrace _msgfmt- info "$@"; }; readonly -f msginfo-

msgok() { interrupt_xtrace _msgfmt ok "$@"; }; readonly -f msgok
msgok-() { interrupt_xtrace _msgfmt- ok "$@"; }; readonly -f msgok-

msgsuccess() { interrupt_xtrace _msgfmt success "$@"; }; readonly -f msgsuccess
msgsuccess-() { interrupt_xtrace _msgfmt- success "$@"; }; readonly -f msgsuccess-

msgwarn() { interrupt_xtrace _msgfmt warning "$@"; }; readonly -f msgwarn
msgwarn-() { interrupt_xtrace _msgfmt- warning "$@"; }; readonly -f msgwarn-

msgerr() { interrupt_xtrace _msgfmt error "$@"; }; readonly -f msgerr
msgerr-() { interrupt_xtrace _msgfmt- error "$@"; }; readonly -f msgerr-

msgfail() { interrupt_xtrace _msgfmt failure "$@"; }; readonly -f msgfail
msgfail-() { interrupt_xtrace _msgfmt- failure "$@"; }; readonly -f msgfail-

# This function formats an prompt invite as a string to be given to the `read'
# builtin prompt option (-p).  Example of proper usage below:
#
#   prompt="$(msgprompt "Do you want to proceed? [Y|n]")"
#   read [-r] [-e] [-t TIMEOUT] -p "$prompt" answer && : "${answer:=y}" ||
#       { answer="default answer if read fails"; linebreak; false; }
#
# Remember: Failure to read can occur upon timeout or bad prompt FD.
msgprompt() { interrupt_xtrace _msgfmt prompt "$@"; }; readonly -f msgprompt
msgprompt-() { interrupt_xtrace _msgfmt- prompt "$@"; }; readonly -f msgprompt-

# ---

# Shortcut functions to raise an error message and exit the whole script:
die() { interrupt_xtrace _die2 1 "$@"; }; readonly -f die
die-() { interrupt_xtrace _die2- 1 "$@"; }; readonly -f die-
die2() { interrupt_xtrace _die2 "$@"; }; readonly -f die2
die2-() { interrupt_xtrace _die2- "$@"; }; readonly -f die2-

_die2() {
	local exitcode="${1:?exit code required as first argument}"; shift
	if [[ "$#" -eq 0 ]]; then set -- "an error has occurred"; fi
	_die2- "$exitcode" <<< "$(printf -v s '%s ' "$@"; printf '%s\n' "${s% }")"
}
readonly -f _die2

_die2-() {
	local exitcode="${1:?exit code required as first argument}"; shift
	if [[ "$exitcode" -eq 0 ]]; then
		misuse 'exit code should not be zero as this function announces an error'
		exitcode=10
	fi
	msgerr- "$@"
	exit "$exitcode"
}
readonly -f _die2-

# ---

# Fancy xtrace features initialization
_set_fancy_xtrace_prompt_indicator() {
	local xtrace_fd="${1:-}"
	declare -g +x BASH_XTRACEFD  # global but not exported
	[[ -n "${xtrace_fd:-}" ]] && BASH_XTRACEFD="${xtrace_fd}"
	if [[ -t "${xtrace_fd:-2}" && -z "${NO_COLOR:-}" ]]; then
		PS4=$'+${BASH_SOURCE[0]:+\e[0;36m${BASH_SOURCE[0]}\e[0m${LINENO:+:\e[0;35m${LINENO}\e[0m}:}${FUNCNAME[0]:+\e[0;1;34m${FUNCNAME[0]}()\e[0m:} '
	else
		PS4='+${BASH_SOURCE[0]:+${BASH_SOURCE[0]}${LINENO:+:${LINENO}}:}${FUNCNAME[0]:+${FUNCNAME[0]}():} '
	fi
}
readonly -f _set_fancy_xtrace_prompt_indicator

set_fancy_xtrace_prompt_indicator() { interrupt_xtrace _set_fancy_xtrace_prompt_indicator "$@"; }
readonly -f set_fancy_xtrace_prompt_indicator

# ---

# Inspired from the OpenRC "yesno" Bash function (but without the part where it
# dereferences the value if that one is not understandable as a
# human-comprehensive boolean value):
booleval() { interrupt_xtrace _booleval "$@"; }; readonly -f booleval
_booleval() {
	[[ "$#" -eq 0 ]] && { misuse "missing boolean value argument"; exit 10; }
	[[ "$#" -gt 1 ]] && { misuse "too many arguments"; exit 10; }
	case "${1,,}" in
		y|yes|true|on|1)   return 0 ;;
		n|no|false|off|0)  return 1 ;;
		'')	misuse "empty string cannot be evaluated as a boolean" \
			       "(must be either: y(es)/n(o), true/false, on/off, 1/0)," \
			       "exiting shell process."
			exit 10 ;;
		*)	misuse "\"$1\" is not a boolean (must be either: y(es)/n(o)," \
			       "true/false, on/off, 1/0), exiting shell process."
			exit 10 ;;
	esac
}
readonly -f _booleval

boolassert() { interrupt_xtrace _boolassert "$@"; }; readonly -f boolassert
_boolassert() {
	[[ "$#" -eq 0 ]] && { misuse "missing boolean value argument"; return 10; }
	[[ "$#" -gt 1 ]] && { misuse "too many arguments"; return 10; }
	case "${1,,}" in
		y|yes|true|on|1|n|no|false|off|0)  return 0 ;;
		'')	misuse "empty string cannot be evaluated as a boolean (must be" \
			       "either: y(es)/n(o), true/false, on/off, 1/0)"
			return 1 ;;
		*)	misuse "\"$1\" is not a boolean (must be either: y(es)/n(o)," \
			       "true/false, on/off, 1/0)"
			return 1 ;;
	esac
}
readonly -f _boolassert


# ---

# Simple function to check if a given item (first argument of the function
# call) is contained in a list of items (i.e. an unfolded array) passed as next
# arguments.
contains() { interrupt_xtrace _contains "$@"; }; readonly -f contains
_contains() {
	local elt="${1:?element to be searched required as first arg}"; shift
	local x; for x in "$@"; do if [[ "$x" = "$elt" ]]; then return 0; fi; done
	return 1
}
readonly -f _contains

# ---

# Function hacking around timeout option of the `read' builting to create a
# pure-Bash sleep function that does not fork (which may be useful in some
# sketchy scenarios where signal management is important).
sleepnf() { interrupt_xtrace _sleepnf "$@"; }; readonly -f sleepnf
_sleepnf() {
	if [[ "$#" -ne 1 ]]; then
		misuse "bad number of arguments"
		return 1
	elif [[ "${1,,}" == 'inf' ]]; then
		read -r _ <> <(:) || :
	elif [[ -n "$1" && "$1" =~ ^[0-9]*(\.[0-9]+)?$ ]]; then
		read -r -t "$1" _ <> <(:) || :
	else
		misuse "argument is neither a number nor \"inf\""
		return 1
	fi
}
readonly -f _sleepnf

# ---

# Set of functions to manage a stack of callbacks to be executed on exit of the
# main program. This set of functions relies on the Bash EXIT trap. Therefore
# the EXIT trap should not be fiddled with when the program relies on those
# functions.
__atexit_trap__() {
	declare -g +x __atexit_callbacks__
	for __atexit_callback_item__ in "${__atexit_callbacks__[@]}"; do
		if ! eval "${__atexit_callback_item__:-}"; then
			misuse 'An atexit trap callback returned with failure. Proceeding...'
			continue
		fi
	done
}
readonly -f __atexit_trap__

atexit_push() { interrupt_xtrace _atexit_push "$@"; }; readonly -f atexit_push
_atexit_push() {
	trap __atexit_trap__ EXIT  # Ensure the trap is always set for exit
	[[ "$#" -eq 1 && -n "${1:-}" ]] || { misuse 'usage: <callback>'; return 1; }
	declare -g +x __atexit_callbacks__
	__atexit_callbacks__=("$1" "${__atexit_callbacks__[@]}")
}
readonly -f _atexit_push

atexit_pop() { interrupt_xtrace _atexit_pop "$@"; }; readonly -f atexit_pop
_atexit_pop() {
	trap __atexit_trap__ EXIT  # Ensure the trap is always set for exit
	[[ "$#" -eq 0 ]] || { misuse 'usage: too many arguments'; return 1; }
	declare -g +x __atexit_callbacks__
	if [[ "${#__atexit_callbacks__[@]}" -le 1 ]]; then
		__atexit_callbacks__=()
	else
		__atexit_callbacks__=("${__atexit_callbacks__[@]:1}")
	fi
}
readonly -f _atexit_pop
