`ezmk`: Turn makefiles into handy and featureful script wrappers with GNU Make
==============================================================================

This project is a portable and drop-in makefile library to turn GNU Make and
associated makefiles into handy and featureful command or script wrappers.

It has the convenience of not requiring any third-party program or any special
toolchain to be installed on target systems, except of course for GNU Make and
Bash (and some other fairly common tools like sed or Awk) which should all be
easily available (or even already installed) on most "Unixy" systems.

<!--[THIS COMMENT IS WHAT REPLACES THIS WHOLE README FILE IN VENDOR COPIES]
This is a vendor copy of `ezmk', a portable and drop-in makefile library to turn GNU Make and associated makefiles into handy and featureful command or script wrappers.
More information on: https://github.com/nclsgd/ezmk
-->

Integrated and "vendored" in larger and more purposeful projects, this can
serve as a handy way to wrap complex commands and still allowing to take
advantage of the makefile targets auto-completion features (via the use of
common makefile completion helpers, such as the _bash-completion_ functions).
The `make` command also allows the user to chain recipe invocations (provided
that these do not repeat in the same command, see _known caveats_ below).
These recipes can then be seen as handy scripts or commands that provide
features of the overall project.


Features
--------

🚧 ___Documentation in progress...___ 🚧

<details><summary><em>To-do list for this section</em></summary>

- Portable in modern UNIX/Linux
- Mac users still need to install GNU Make 4+ and Bash as the versions
  provided by Apple are too old or missing mainly due to licensing issues.
- Automatic generated help message with phony targets human description
- This is done by parsing the GNU Make database and does not try to parse
  makefiles
- Provides a set of Bash functions and a common prologue that bring features to
  recipes

</details>


How to use this makefile library
--------------------------------

### Integration in a series of makefiles

🚧 ___Documentation in progress...___ 🚧

Load parent `lib.mk` file from a repository:

```make
# Snippet to load current repository make library files. DO NOT EDIT.
override .=$(if $(wildcard $2$1),$2$1,$(if $(filter 1/,$(words $(abspath $2))$(firstword $(abspath $2))),\
$(error could not find "$1" in current dir or in any parent dir up to root),$(call .,$1,../$2)))
include $(call .,lib.mk,)
```


### Tweaking and enhancing the library features

🚧 ___Documentation in progress...___ 🚧


Project status
--------------

This is a hobby project and still a work-in-progress.  It may be prone to
significant code evolutions.  But I use this code really frequently within some
other projects (most of them not public) to wrap complex scripts and it has
shown up to now enough stability to be made public.

To this day, this project still lacks some detailed documentation on how it
works and how to use it but the code has been commented here and there as best
as I could and should be self-explanatory for most developers and hackers
familiar with GNU Make.


Known caveats
-------------

🚧 ___Documentation in progress...___ 🚧


License
-------

This is licensed under the MIT license.
