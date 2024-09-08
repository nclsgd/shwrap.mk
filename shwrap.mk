# vim: set ft=make noet ts=4 sw=4 ai tw=79:
# Copyright 2019-2024 Nicolas Godinho <nicolas@godinho.me>
# SPDX-License-Identifier: MIT

# Get the relative path to the directory of this present file (using our own
# reserved Make variable name "dot"):
override .thisdir := $(patsubst %/,%,$(dir $(lastword $(MAKEFILE_LIST))))
override .shwrap.path := $(.thisdir)

# ---

# Preliminary check: check GNU Make version and parse .FEATURES to make sure we
# are on a recent GNU Make supporting all the required features:
ifeq (3,$(firstword $(subst ., ,$(MAKE_VERSION))))
$(error makefile library `shwrap.mk' requires at least GNU Make 4.0)
endif
ifneq (3,$(words $(filter oneshell target-specific undefine,$(.FEATURES))))
$(error this version of GNU Make $(MAKE_VERSION) does not seem to support \
some required features for makefile library `shwrap.mk')
endif

# Warn when undefined variables are used:
GNUMAKEFLAGS += --warn-undefined-variables

# Prevent Make from displaying messages of directory change as these messages
# can make the output unncessarily noisy:
ifndef .shwrap.make_print_directory
GNUMAKEFLAGS += --no-print-directory
endif

# Ensure MAKEFLAGS is consistent with GNUMAKEFLAGS:
MAKEFLAGS += $(GNUMAKEFLAGS)

# Do not echo back the content of the target recipes:
ifndef .shwrap.no_make_silent
.SILENT:
endif

# This setting is the core setting that make this Bash wrapper work.  Use one
# shell session for the whole recipe script:
.ONESHELL:

# Save the original SHELL environment variable value as we are going to
# override it to env below for our little hack.
override .shwrap.original_shell := $(SHELL)

# Override and undefine any .shwrap.* variables that may be inherited
# from the environment or the Make command line variables or even earlier in
# the Makefile inclusion list:
$(foreach _,preload preload_always variables,$(eval override undefine \
$(_:%=.shwrap.%))$(eval $(_:%=.shwrap.%):=))

# Never inherit from environment or commandline the SHWRAP_* variables:
$(foreach _,$(filter SHWRAP_%,$(.VARIABLES)),$(eval override undefine $_))

# It is important that the SHELL and .SHELLFLAGS variables must not be
# inherited from the environment. Override them and set them as requested:
#
# Note: using /usr/bin/env as a trampoline to evade the Make shell detection
# that strips some whitespaces and indentation from recipes.
override SHELL := /usr/bin/env
override .SHELLFLAGS = /bin/sh $(.shwrap.path)/wrapper.sh \
    $(eval export SHWRAP_TARGET:=$$@) \
    $(eval export SHWRAP_ORIGINAL_SHELL:=$$(.shwrap.original_shell)) \
    $(eval export SHWRAP_PRELOAD:=$$(foreach _,$$(.shwrap.preload),$$(dir $$_)$$(notdir $$_))) \
    $(eval export SHWRAP_PRELOAD_ALWAYS:=$$(foreach _,$$(.shwrap.preload_always),$$(dir $$_)$$(notdir $$_))) \
    $(eval export SHWRAP_VARIABLES:=$$(.shwrap.variables)) \
    $(foreach _,$(.shwrap.variables),$(eval export SHWRAP_VARIABLE_$$_:=$$($$_))) \
    $(eval export SHWRAP_SHELL:=$$(.shwrap.shell)) \
    $(eval export SHWRAP_SHELLFLAGS:=$$(.shwrap.shellflags)) \
    $(eval export SHWRAP_DISABLE:=$$(.shwrap.disable)) \
    $(eval export SHWRAP_ECHO:=$$(.shwrap.echo)) \
    $(eval export SHWRAP_PRINTCMD:=$$(.shwrap.print_command)) \
    $(eval export SHWRAP_PRINTSCRIPT:=$$(.shwrap.print_script))

# Explicitly do *NOT* export SHELL as it may break some scripts or third-party
# programs used in Make recipes
unexport SHELL

# Defaults:
.shwrap.shell := /bin/sh
.shwrap.shellflags := -euc

# ---

# This variable controls the list of recipes/targets to hide from the automatic
# help messsage.  Target names can be appended to it by other makefiles.
.shwrap.help_hide_targets := .shwrap.noop_target .shwrap.help .shwrap.list_targets

# Default to this target
.DEFAULT_GOAL := .shwrap.help

ifndef .shwrap.no_help_target
override .shwrap.help_target_defined := 1
.PHONY: help
help:: | .shwrap.help
else
override .shwrap.help_target_defined := 0
endif

# A dummy "no operation" target:
.PHONY: .shwrap.noop_target
.shwrap.noop_target::

# header and footer for help must come from the makefiles:
override undefine .shwrap.help_header
override undefine .shwrap.help_footer

.PHONY: .shwrap.help
.shwrap.help:: override .shwrap.shell := /bin/sh
.shwrap.help:: override .shwrap.shellflags := -euc
.shwrap.help:: override .shwrap.preload :=# nothing
.shwrap.help:: override .shwrap.preload_always :=# nothing
.shwrap.help:: override awk_makedbparser  := $(.shwrap.path)/makedbparser.awk
.shwrap.help:: override awk_helpformatter := $(.shwrap.path)/helpformatter.awk
.shwrap.help:: override hide_targets = $(.shwrap.help_hide_targets)
.shwrap.help:: override header = $(.shwrap.help_header)
.shwrap.help:: override footer = $(.shwrap.help_footer)
.shwrap.help:: override help_defined = $(.shwrap.help_target_defined)
.shwrap.help:: override makefile = $(firstword $(MAKEFILE_LIST))
.shwrap.help:: override .shwrap.variables := awk_makedbparser \
awk_helpformatter header footer hide_targets help_defined makefile
.shwrap.help::
	color=; if [ -t 1 ] && [ -z "$${NO_COLOR:-}" ]; then color=1; fi; \
	set +e; { LC_ALL=C $(MAKE) -npq -f "$$makefile" .shwrap.noop_target; printf '%s\n' "$$?"; } \
	  | awk -f "$$awk_makedbparser" | LC_COLLATE=C sort -u \
	  | header="$$header" footer="$$footer" hide_targets="$$hide_targets" \
	    color="$$color" help_defined="$$help_defined" \
	    awk -f "$$awk_helpformatter"

.PHONY: .shwrap.list_targets
.shwrap.list_targets:: override .shwrap.shell := /bin/sh
.shwrap.list_targets:: override .shwrap.shellflags := -euc
.shwrap.list_targets:: override .shwrap.preload :=# nothing
.shwrap.list_targets:: override .shwrap.preload_always :=# nothing
.shwrap.list_targets:: override awk_makedbparser := $(.shwrap.path)/makedbparser.awk
.shwrap.list_targets:: override makefile = $(firstword $(MAKEFILE_LIST))
.shwrap.list_targets:: override .shwrap.variables := awk_makedbparser makefile
.shwrap.list_targets::
	color=; if [ -t 1 ] && [ -z "$${NO_COLOR:-}" ]; then color=1; fi; \
	set +e; { LC_ALL=C $(MAKE) -npq -f "$$makefile" .shwrap.noop_target; printf '%s\n' "$$?"; } \
	  | awk -f "$$awk_makedbparser" \
	  | awk 'BEGIN{FS="\t"}($$1=="file"||$$1=="phony"){print $$1"\t"$$3}' \
	  | LC_COLLATE=C sort -u

# ---

# Defining handy Make variables .blank and .newline"
override .blank :=# No character between `:=` and this comment hash sign
# Make quirk: two lines are needed below to set only one newline in the .newline variable:
override define .newline


endef

# ---

# Handy macro to safely escape make variables within shell scripts. This is
# meant to be used in the recipes.
# Example of usage below:
#
#   my_shell_variable=$(call .shquote,$(my_make_variable))
#
override .shquote = '$(subst ','\'',$1)'

# ---

# Make stanza to be invoked via $(eval $(call ...)) to check and ensure that a
# given make variable is a human-readable boolean (i.e. either "yes"/"no",
# "true"/"false", "y"/"n", "1"/"0" and so on.) and transform the make variable
# into either "true" or "false".
# Example of invocation:
#
#   $(eval $(call .boolean,<variable-name>,<default-value>))
#
override define .boolean
$(if $(filter 1,$(words $1)),,$(error only one variable processed at a time: $1))
$(if $(filter 1,$(words $2)),$(if $(filter true false,$2),,\
$(error only true/false default value for boolean variable '$1' are allowed, \
invalid default value specified: "$2")),
$(error misspecified default value for boolean variable '$1'))
ifeq (,$$(filter commandline file,$$(subst d l,dl,$$(origin $1))))
override $1:=$2
else
ifeq (1,$$(words $$($1)))
ifneq (,$$(filter 1 yes true y Y True YES on ON,$$($1)))
override $1:=true
else ifneq (,$$(filter 0 no false n N False NO off OFF,$$($1)))
override $1:=false
else
$$(error expecting boolean for make variable '$1': unknown boolean "$$(strip $$($1))")
endif # compare common bool values
else
$$(error expecting boolean for make variable '$1': found "$$($1)")
endif # 1 word in variable
endif # identify origin of variable
endef

# ---

# EXTRA: Some opinionated Bash common functions and its prologue snippet:
ifndef .shwrap.no_extra_bash_commons

# The utilities and common functions expected in all targets using this
.shwrap.preload_always += $(.shwrap.path)/extras/functions.sh \
                          $(.shwrap.path)/extras/prologue.sh
override .shwrap.shell := bash
override .shwrap.shellflags := -eu -o pipefail -c

# These variables below need to be exported for the preloaded scripts just
# above:
.shwrap.variables += trace trace_fd
$(eval $(call .boolean,trace,false))

endif  # ifndef .shwrap.no_extra_bash_commons
