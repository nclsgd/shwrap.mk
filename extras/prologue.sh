# shellcheck shell=bash
# vim: set ft=sh ts=4 sw=4 noet ai tw=79:
# Copyright 2017-2024 Nicolas Godinho <nicolas@godinho.me>
# SPDX-License-Identifier: MIT

# Bash "strict mode"
set -euo pipefail

# Sets the messages prefix if any:
[[ "${MSGPREFIX:-}" ]] && msgprefix_set "$MSGPREFIX"

# trace is a global unexported variable
declare -g trace
# Sanity checks on global variables (and default value setting if unset/empty):
boolassert "${trace:=no}" || die "Not a boolean variable: trace"
if ! [[ "${trace_fd:=}" =~ ^(|0|[1-9][0-9]*)$ ]]; then
	die "Variable \"trace_fd\" must be an integer indicating a valid writable file descriptor."
elif [[ -n "$trace_fd" ]] && ! { true >&"$trace_fd"; } 2>/dev/null; then
	die "Trace output file descriptor (trace_fd=$trace_fd) seems invalid."
fi
# And handle trace mode:
set_fancy_xtrace_prompt_indicator "$trace_fd"
if booleval "$trace"; then set -x; fi
