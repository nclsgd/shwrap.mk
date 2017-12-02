# vim: set ft=make noet ts=4 sw=4 ai tw=79:
# Copyright 2019-2024 Nicolas Godinho <nicolas@godinho.me>
# SPDX-License-Identifier: MIT

# Get the relative path to the directory of this present file (using our own
# reserved Make variable name "dot"):
override .thisdir := $(patsubst %/,%,$(dir $(lastword $(MAKEFILE_LIST))))
override .ezmk.path := $(.thisdir)

# ---

# Preliminary check: check GNU Make version and parse .FEATURES to make sure we
# are on a recent GNU Make supporting all the required features:
ifeq (3,$(firstword $(subst ., ,$(MAKE_VERSION))))
$(error makefile library `ezmk' requires at least GNU Make 4.0)
endif
ifneq (3,$(words $(filter oneshell target-specific undefine,$(.FEATURES))))
$(error this version of GNU Make $(MAKE_VERSION) does not seem to support \
some required features for makefile library `ezmk')
endif

# Warn when undefined variables are used:
GNUMAKEFLAGS += --warn-undefined-variables

# Prevent Make from displaying messages of directory change as these messages
# can make the output unncessarily noisy:
ifndef .ezmk.make_print_directory
GNUMAKEFLAGS += --no-print-directory
endif

# Ensure MAKEFLAGS is consistent with GNUMAKEFLAGS:
MAKEFLAGS += $(GNUMAKEFLAGS)

# Do not echo back the content of the target recipes:
ifndef .ezmk.no_make_silent
.SILENT:
endif

# This setting is the core setting that make this Bash wrapper work.  Use one
# shell session for the whole recipe script:
.ONESHELL:

# Save the original SHELL environment variable value as we are going to
# override it to env below for our little hack.
override .ezmk.original_shell := $(SHELL)

# Override and undefine any .ezmk.wrapper_* variables that may be inherited
# from the environment or the Make command line variables or even earlier in
# the Makefile inclusion list:
$(foreach _,preload preload_always variables,$(eval override undefine \
$(_:%=.ezmk.wrapper_%))$(eval $(_:%=.ezmk.wrapper_%):=))

# Never inherit from environment or commandline the EZMKWRAPPER_* variables:
$(foreach _,$(filter EZMKWRAPPER_%,$(.VARIABLES)),$(eval override undefine $_))

# It is important that the SHELL and .SHELLFLAGS variables must not be
# inherited from the environment. Override them and set them as requested:
#
# Note: using /usr/bin/env as a trampoline to evade the Make shell detection
# that strips some whitespaces and indentation from recipes.
override SHELL := /usr/bin/env
override .SHELLFLAGS = /bin/sh $(.ezmk.path)/wrapper.sh \
    $(eval export EZMKWRAPPER_TARGET:=$$@) \
    $(eval export EZMKWRAPPER_ORIGINAL_SHELL:=$$(.ezmk.wrapper_original_shell)) \
    $(eval export EZMKWRAPPER_PRELOAD:=$$(foreach _,$$(.ezmk.wrapper_preload),$$(dir $$_)$$(notdir $$_))) \
    $(eval export EZMKWRAPPER_PRELOAD_ALWAYS:=$$(foreach _,$$(.ezmk.wrapper_preload_always),$$(dir $$_)$$(notdir $$_))) \
    $(eval export EZMKWRAPPER_VARIABLES:=$$(.ezmk.wrapper_variables)) \
    $(foreach _,$(.ezmk.wrapper_variables),$(eval export EZMKWRAPPER_VARIABLE_$$_:=$$($$_))) \
    $(eval export EZMKWRAPPER_SHELL:=$$(.ezmk.wrapper_shell)) \
    $(eval export EZMKWRAPPER_SHELLFLAGS:=$$(.ezmk.wrapper_shellflags)) \
    $(eval export EZMKWRAPPER_DISABLE:=$$(.ezmk.wrapper_disable)) \
    $(eval export EZMKWRAPPER_ECHO:=$$(.ezmk.wrapper_echo)) \
    $(eval export EZMKWRAPPER_PRINTCMD:=$$(.ezmk.print_command)) \
    $(eval export EZMKWRAPPER_PRINTSCRIPT:=$$(.ezmk.print_script))

# Explicitly do *NOT* export SHELL as it may break some scripts or third-party
# programs used in Make recipes
unexport SHELL

# Defaults:
.ezmk.wrapper_shell := /bin/sh
.ezmk.wrapper_shellflags := -euc

# ---

# This variable controls the list of recipes/targets to hide from the automatic
# help messsage.  Target names can be appended to it by other makefiles.
.ezmk.help_hide_targets := .ezmk.noop_target .ezmk.help .ezmk.list_targets

# Default to this target
.DEFAULT_GOAL := .ezmk.help

ifndef .ezmk.no_help_target
override .ezmk.help_target_defined := 1
.PHONY: help
help:: | .ezmk.help
else
override .ezmk.help_target_defined := 0
endif

# A dummy "no operation" target:
.PHONY: .ezmk.noop_target
.ezmk.noop_target::

# header and footer for help must come from the makefiles:
override undefine .ezmk.help_header
override undefine .ezmk.help_footer

.PHONY: .ezmk.help
.ezmk.help:: override .ezmk.wrapper_shell := /bin/sh
.ezmk.help:: override .ezmk.wrapper_shellflags := -euc
.ezmk.help:: override .ezmk.wrapper_preload :=# nothing
.ezmk.help:: override .ezmk.wrapper_preload_always :=# nothing
.ezmk.help:: override awk_makedbparser  := $(.ezmk.path)/makedbparser.awk
.ezmk.help:: override awk_helpformatter := $(.ezmk.path)/helpformatter.awk
.ezmk.help:: override hide_targets := $(.ezmk.help_hide_targets)
.ezmk.help:: override header = $(.ezmk.help_header)
.ezmk.help:: override footer = $(.ezmk.help_footer)
.ezmk.help:: override help_defined = $(.ezmk.help_target_defined)
.ezmk.help:: override makefile = $(firstword $(MAKEFILE_LIST))
.ezmk.help:: override .ezmk.wrapper_variables := awk_makedbparser \
awk_helpformatter header footer hide_targets help_defined makefile
.ezmk.help::
	color=; if [ -t 1 ] && [ -z "$${NO_COLOR:-}" ]; then color=1; fi; \
	set +e; { LC_ALL=C $(MAKE) -npq -f "$$makefile" .ezmk.noop_target; printf '%s\n' "$$?"; } \
	  | awk -f "$$awk_makedbparser" | LC_COLLATE=C sort -u \
	  | header="$$header" footer="$$footer" hide_targets="$$hide_targets" \
	    color="$$color" help_defined="$$help_defined" \
	    awk -f "$$awk_helpformatter"

.PHONY: .ezmk.list_targets
.ezmk.list_targets:: override .ezmk.wrapper_shell := /bin/sh
.ezmk.list_targets:: override .ezmk.wrapper_shellflags := -euc
.ezmk.list_targets:: override .ezmk.wrapper_preload :=# nothing
.ezmk.list_targets:: override .ezmk.wrapper_preload_always :=# nothing
.ezmk.list_targets:: override awk_makedbparser := $(.ezmk.path)/makedbparser.awk
.ezmk.list_targets:: override makefile = $(firstword $(MAKEFILE_LIST))
.ezmk.list_targets:: override .ezmk.wrapper_variables := awk_makedbparser makefile
.ezmk.list_targets::
	color=; if [ -t 1 ] && [ -z "$${NO_COLOR:-}" ]; then color=1; fi; \
	set +e; { LC_ALL=C $(MAKE) -npq -f "$$makefile" .ezmk.noop_target; printf '%s\n' "$$?"; } \
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

# Bash common functions and its prologue snippet:
ifndef .ezmk.no_bash_commons

# The utilities and common functions expected in all targets using this
.ezmk.wrapper_preload_always += $(.ezmk.path)/bashfunctions.sh \
                                $(.ezmk.path)/bashprologue.sh
override .ezmk.wrapper_shell := bash
override .ezmk.wrapper_shellflags := -eu -o pipefail -c

# These variables below need to be exported for the preloaded scripts just
# above:
.ezmk.wrapper_variables += trace trace_fd
$(eval $(call .boolean,trace,false))

endif  # ifndef .ezmk.no_bash_commons
