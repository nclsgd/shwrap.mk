#!/usr/bin/awk -f
# vim: set ft=awk ts=4 sw=4 noet ai tw=79:
# Copyright 2019-2024 Nicolas Godinho <nicolas@godinho.me>
# SPDX-License-Identifier: MIT

# This Awk script extracts the targets from a GNU Makefile database (only in
# the C locale!) and outputs the list of targets followed by the description
# (i.e. the "header" comment in the target recipe) properly escaped for Bash.
# To get the GNU Makefile database (the returned error code can be ignored):
#   LC_ALL=C make -npq <EXPECTED_NO_OP_TARGET>

# String trimming functions:
function ltrim(s) { sub(/^[ \t\r\n]+/, "", s); return s; }
function rtrim(s) { sub(/[ \t\r\n]+$/, "", s); return s; }
function trim(s) { return rtrim(ltrim(s)); }

# Initialization:
BEGIN {
	begin_block=1; in_define_ctx=0; in_targets_part=0;
	in_target_block=0; target=""; desc=""; in_desc=0; in_recipe=0;
	makeretval=0; x=""; section="";
	for (k in targets) delete targets[k]; for (k in arr) delete arr[k];
}

# Anything can happen in a define..endef block, ditch those lines:
( ! in_targets_part && /^define [^:=]/) { in_define_ctx=1; next; }
( in_define_ctx ) { if ($0 == "endef") { in_define_ctx=0; } next; }
# When does the targets enumeration part begin in the Make database?
( begin_block && ! in_targets_part && /^# (Directories|Files)$/) { in_targets_part=1; next; }
( ! in_targets_part ) { next; }

# Detect the beginning of a code block (they are separated with blank lines):
($0 == "") {
	if (target != "") {
		section=""; desc=trim(desc);
		if (match(desc, /^\[[^]]+\]/)) {
			x=substr(desc, RSTART, RLENGTH);
			section=trim(substr(x, 2, length(x)-2));
			desc=trim(substr(desc, RSTART+RLENGTH));
		}
		if (targets[target] == "") {
			targets[target] = "file\t"section"\t"target"\t"desc;
		} else {
			split(targets[target], arr, "\t");
			targets[target] = arr[1]"\t"section"\t"target"\t"desc;
		}
	}
	target=""; desc=""; in_desc=0; in_recipe=0;
	begin_block=1; in_target_block=0;
	next;
}

# Sometimes target definitions can be found after some comments:
(begin_block) { if ($0 !~ /^# Not a target/) { in_target_block=1; } begin_block=0; }
(!in_target_block) { next; }

# Extract the target name if we are in a target block and line looks like it:
( in_target_block && target=="" && /^[^#\t][^:]*:/) {
	if ($0 ~ /^\.PHONY:/) {
		sub(/^\.PHONY:/, ""); split($0, arr);
		for (t in arr) {
			if (arr[t] == "|") continue;
			if (targets[arr[t]] == "") {
				targets[arr[t]] = "phony\t\t"arr[t]"\t"
			} else {
				x = targets[arr[t]]; sub(/^[a-z_-]+\t/, "", x);
				targets[arr[t]] = "phony\t"x
			}
		}
	} else {
		sub(/:.*$/, ""); target=$0; desc="";
	}
}

# Extract the description lines (header comment) of the target (if any set):
( in_target_block && target != "" && /^\t/ ) {
	if ((! in_recipe && ! in_desc && match($0, /^\t[\-\+@]*# ?/)) \
		 || ( in_desc && match($0, /^\t+# ?/))) {
		in_desc=1; sub(/^\t#/, ""); sub(/\t/, " "); sub(/[[:cntrl:]]/, "");
		desc_line=trim($0);
		if (desc != "" && desc_line == "") { in_desc=0; }
		desc=desc" "desc_line;
	} else { in_desc=0; }
	in_recipe=1;
}

# Format output and report the exit code from GNU Make database dumping:
END {
	# Make return value
	if ($0 ~ /^[0-9]*$/) makeretval=$0;
	for (k in targets) print targets[k];
	if (makeretval != "") print "return\t"makeretval;
}
