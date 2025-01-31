#!/usr/bin/awk -f
# vim: set ft=awk ts=4 sw=4 noet ai tw=79:
# Copyright 2019-2024 Nicolas Godinho <nicolas@godinho.me>
# SPDX-License-Identifier: MIT

# This Awk script formats the output (after proper sort processing) of the
# other Awk script that is dedicated to parse the GNU Make database dump.

# String trimming functions:
function ltrim(s) { sub(/^[ \t\r\n]+/, "", s); return s; }
function rtrim(s) { sub(/[ \t\r\n]+$/, "", s); return s; }
function trim(s) { return rtrim(ltrim(s)); }

# Function to break line on last space within a certain width:
function snip_within_width(input, width,                       i, n, walk, p) {
	n = 0; walk = input; p = 0;
	if (length(input) < width) return 0;
	while (1) {
		i = index(walk, " "); n += i;
		if (i == 0 || n > width) break;
		p = n; walk = substr(walk, i+1);
	}
	return p;
}

function wrap_indent(input, width, indent,     res, snip, remain, next_space) {
	if (width == "") width = 80;
	res = ""; remain = input;
	while (1) {
		snip = snip_within_width(remain, width);
		if (snip == 0) {
			next_space = index(remain, " ");
			if (!next_space || length(remain) <= width) {
				res = res ((res == "") ? "" : "\n" indent) rtrim(remain); break;
			} else {
				res = res ((res == "") ? "" : "\n" indent) rtrim(substr(remain, 0, next_space));
				remain = ltrim(substr(remain, next_space+1)); continue;
			}
		}
		res = res ((res == "") ? "" : "\n" indent) rtrim(substr(remain, 0, snip));
		remain = ltrim(substr(remain, snip+1));
	}
	return res;
}

# Function to apply fancy formatting to output:
function color_formatted_recipes(recipes_fmt) {
	gsub(/(^ *|,( |\n *))/, "&" bold, recipes_fmt);
	gsub(/( *$|,( |\n *))/, reset "&", recipes_fmt);
	return recipes_fmt;
}
function color_formatted_section(section_fmt) {
	gsub(/(^ *|\n *)/, "&" underline, section_fmt);
	gsub(/( *$| *\n)/, reset "&", section_fmt);
	return section_fmt;
}

# Function to compute all the global variables used to format the output:
function compute_formatting_global_vars(margin_width) {
	term_width = 80;
	recipes_minwidth = 27 - margin_width;
	desc_width = term_width - recipes_minwidth - margin_width - 2;
	indent_width = recipes_minwidth + margin_width + 2;
	indent = sprintf("%-"indent_width"s", "");
	margin = sprintf("%-"margin_width"s", "");
}

# Initialization:
BEGIN {
	FS="\t"; err = 0;
	header = trim(ENVIRON["header"]); footer = trim(ENVIRON["footer"]);
	nb_targets_to_hide = split(trim(ENVIRON["hide_targets"]), hide_targets, " ");
	help_defined = ENVIRON["help_defined"]; color = ENVIRON["color"];
	undocumented = ""; sectdesc = ""; has_named_sections = 0;
	for (i in arr) delete arr[i];
	for (i in sections_order) delete sections_order[i];
	for (i in sections_arr) delete sections_arr[i];
	for (i in sectdesc_order) delete sectdesc_order[i];
	for (i in sectdesc_arr) delete sectdesc_arr[i];
	sections_len = 0;
	sectdesc_len = 0;
	bold = "\033[1m"; underline = "\033[4m"; reset = "\033[0m";
	if (color == "" || color == "0") color = 0; else color = 1;
	if (ENVIRON["NO_COLOR"] != "") color = 0;
}

# On each line:
{
	if ($1 == "return") {
		if (int($2)) {
			print "Error while dumping or parsing the GNU Make database to get the available targets." > "/dev/stderr";
			err=1; exit 1;
		}
	} else if ($1 == "phony") {
		section=$2; recipe=$3; desc=$4; skip=0;
		for (i in hide_targets) if (recipe == hide_targets[i]) { skip=1; break; };
		if (skip) next;
		if (recipe == "help" && help_defined) desc = "Display this help message";
		if (section == "" && desc == "") {
			undocumented = undocumented ((undocumented == "") ? "" : ", ") recipe;
		} else {
			if (!(section in sections_arr)) sections_order[sections_len++] = section;
			sectdesc = section"\t"desc;
			if (!(sectdesc in sectdesc_arr)) sectdesc_order[sectdesc_len++] = sectdesc;
			sectdesc_arr[sectdesc] = sectdesc_arr[sectdesc] ((sectdesc_arr[sectdesc] == "") ? "" : ", ") recipe;
			sections_arr[section] = sectdesc_arr[sectdesc];
			if (section != "") has_named_sections = 1;
		}
	}
}

# Formatting output:
END {
	if (err) { exit 1; }

	compute_formatting_global_vars(2);
	first_section = 1;
	has_targets = (sectdesc_len > 0);
	has_undocumented_targets = (undocumented != "");

	if (header != "") {
		print header;
		print "";
	}
	if (has_targets) {
		targets_title = "Available phony targets:";
		if (color) targets_title = underline targets_title reset;
		print targets_title;
		for (i = 0; i < sections_len; i++) {
			compute_formatting_global_vars(2);
			if (!first_section) print ""; first_section = 0;
			if (sections_order[i] != "") {
				section_fmt = margin wrap_indent(sections_order[i]":", term_width - margin_width, margin);
				if (color) section_fmt = color_formatted_section(section_fmt);
				print section_fmt;
				compute_formatting_global_vars(4);
			}
			for (j = 0; j < sectdesc_len; j++) {
				sectdesc = sectdesc_order[j];
				split(sectdesc, arr, "\t"); section=arr[1]; desc=arr[2];
				if (section != sections_order[i]) continue;
				recipes = sectdesc_arr[sectdesc];
				recipes_fmt = wrap_indent(recipes, term_width - margin_width, margin);
				if (length(recipes_fmt) <= recipes_minwidth) {
					recipes_fmt = sprintf("%-"recipes_minwidth"s  ", recipes_fmt);
					if (color) recipes_fmt = color_formatted_recipes(recipes_fmt);
				} else {
					if (color) recipes_fmt = color_formatted_recipes(recipes_fmt);
					recipes_fmt = recipes_fmt "\n" indent;
				}
				print margin recipes_fmt wrap_indent(desc, desc_width, indent);
			}
		}
	}
	if (has_targets && has_undocumented_targets) print "";
	if (has_undocumented_targets) {
		compute_formatting_global_vars(2);
		undocumented_title = "Undocumented phony targets:";
		if (color) undocumented_title = underline undocumented_title reset;
		print undocumented_title;
		recipes_fmt = margin wrap_indent(undocumented, term_width - margin_width, margin);
		if (color) recipes_fmt = color_formatted_recipes(recipes_fmt);
		print recipes_fmt;
	}
	if (!has_targets && !has_undocumented_targets) {
		no_target_msg = "No phony targets available.";
		if (color) no_target_msg = underline no_target_msg reset;
		print no_target_msg;
	}
	if (footer != "") {
		print "";
		footer_title_msg = "Additional notes:";
		if (color) footer_title_msg = underline footer_title_msg reset;
		print footer_title_msg;
		print footer;
	}
}
