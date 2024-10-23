`shwrap.mk`: Yet another way to turn makefiles into shell script wrappers
=========================================================================

<!--[THIS COMMENT IS WHAT REPLACES THIS WHOLE README FILE IN VENDOR COPIES]
This is a vendor copy of `shwrap.mk', a portable and drop-in GNU Make library to turn makefiles into featureful shell script wrappers.
More information on: https://github.com/nclsgd/shwrap.mk
-->

This project is yet another glorified shell script wrapper built around [GNU
Make](https://www.gnu.org/software/make/) _makefiles_.

Unlike other projects, this one though is a fairly portable library that can be
used as a drop-in assuming that the system uses and provides:
  - **GNU Make** 4.0+
  - **Bash** 4.3+  (even though this can be made optional, see below)
  - **common POSIX utilities** (such as sed, awk, `env`, _etc._)

This makefile library has the advantage of not requiring any exotic third-party
program or any development toolchain to be installed on target systems.  
The requirements (see above) are all common on most contemporary Linux and free
Unix environments and should even be already provided on most systems used for
software development or system administration.

When integrated and "vendored" into large projects, this library can serve as a
handy way to wrap complex commands and still allowing to take advantage of the
features built around the `make` utility and convenience of makefiles, such as:
  - Makefile targets auto-completion features (via the use interactive shell
    completion helpers, such as the _bash-completion_ framework or the
    completions features included in _zsh_)
  - Recipe chaining such as `make recipe1 recipe2 recipe3` (provided that these
    do not repeat in the same command, see _known caveats_ below)
  - Self-documentation via the automatically provided `help` recipe


How to use this makefile library
--------------------------------

### Integrate this library in a series of makefiles (e.g. in a source code repository)

1.  Create a top-level file named `lib.mk` in a base directory (e.g. in the
    base directory of a source code repository).

2.  Within this `lib.mk` file, invoke this library with the following line:

    ```make
    # Get the relative path to the directory of this present file:
    override .thisdir := $(patsubst %/,%,$(dir $(lastword $(MAKEFILE_LIST))))
    include $(.thisdir)/.shwrap/shwrap.mk
    ```

    Additionally, you can also add in this `lib.mk` file global definitions of
    makefile variables or recipes that you want populated in other makefiles
    that include it.

3.  Sitting next to this `lib.mk` file, include a copy of this library by
    creating the expected dedicated directory named `.shwrap` (as seen in the
    snippet above) and invoke the `update-shwrapmk.sh` script to vendor a copy
    of this project library:

    ```sh
    mkdir .shwrap
    cd .shwrap
    curl -LO https://github.com/nclsgd/shwrap.mk/raw/refs/heads/main/update-shwrapmk.sh
    chmod +x update-shwrapmk.sh
    # As a security measure, please review the file before invoking it:
    ./update-shwrapmk.sh
    # Answer "yes" to replace the whole content of this .shwrap directory with
    # a vendor copy of the latest release of this project
    ```

4.  In the other makefiles of the project (i.e. makefiles sitting in the same
    directory as the `lib.mk` file or in the descendant directories), insert
    the following code snippet at the top of these files to automatically
    include the top-level `lib.mk` file created above, hence loading the
    `shwrap.mk` library:

    ```make
    # Snippet to load current repository make library files. DO NOT EDIT.
    override .=$(if $(wildcard $2$1),$2$1,$(if $(filter 1/,$(words $(abspath $2))$(firstword $(abspath $2))),\
    $(error could not find "$1" in current dir or in any parent dir up to root),$(call .,$1,../$2)))
    include $(call .,lib.mk,)
    ```


### Extending the shell recipes by adding new shell functions

🚧 ___TODO: Work in progress...___ 🚧


Detailed features and known caveats
-----------------------------------

🚧 ___TODO: Work in progress...___ 🚧


Project status
--------------

This is a hobby project and may still be prone to code changes. However since I
personally use this project quite often within other projects and source code
repositories (most of them are private though) and since it has shown enough
stability to this day I have decided to release this project publicly.

Nevertheless it still lacks some detailed documentation on how it works and how
to use it in details. Despite this, the code has been commented here and there
as best as I could and therefore should be self-explanatory for most developers
and hackers familiar with GNU Make and advanced shell and Bash scripting.


License
-------

This is licensed under the MIT license.
