##
#	This script removes tabs and spaces at the end of lines in praat scripts
#
#  	Vers. 0.0.0, Henning Reetz, 21-apr-2019
#  	Vers. 0.1.0, Henning Reetz, 28-oct-2020	actually no revision, just added comments
#
#	Tested with Praat 6.1.12
##

version = 1
revision = 1
bugfix = 0

clearinfo

# extension of the script files
ext$ = ".praat"

# create list of .praat files
praat_list_obj = Create Strings as file list:  "file_list", "*'ext$'"
nr_praat_files = Get number of strings

##
#  Go thru all files
##

# total number of files processed
total = 0

for i_file to nr_praat_files
	selectObject: praat_list_obj
	script_name$ = Get string: i_file

# read Praat script
	script_obj = Read Strings from raw text file: script_name$
	nr_lines = Get number of strings

# flag to mark whether any change in a file has happened
# (to avoid unnecessary writing the file back)
	any_change_at_all = 0

# go thru all lines of one Praat script
	for i_line to nr_lines
		line$ = Get string: i_line
# get original length of line
		length = length(line$)

# indicate whether line has changed to skip re-writing of line
# start with -1 since it is always incremented
# (if no change happened, 'change' will have the value '0', which means 'false')
		change = -1

# repeat removing <tab> and <space> from end of line until
# the length of the line does not change by the removing
		repeat
# get length of line before removing attempt (length was measured after reading line)
			last_length = length
# replace tab$ and <space> at end of line
# (indicated by the $ before the " in the regular expression) with nothing (i.e. "")
			line$ = replace_regex$ (line$,"'tab$'$","",0)
			line$ = replace_regex$ (line$," $","",0)
# get length after this operation
			length = length(line$)
# if the length of the line changed, the difference between the length before and after
# this operation will indicate the number of replacements
			diff = last_length - length
# count the total number of replacements
			total += diff
# count the number of changes
			change += 1
# leave this repeat-loop if no change has occurred
# (i.e. all <tab> and <space> at the end of line have been removed)
		until (diff = 0)

# write line back if a change has occurred (i.e. 'change' is not 0 which means 'true')
# and mark that any change has occurred for write back
		if (change)
			Set string: i_line, line$
			any_change_at_all += 1
		endif

# going thru all lines of a Praat script
	endfor

# write back file if any change has happened (i.e., any_change_at_all is not 0 which means 'true')
	if (any_change_at_all)
		Save as raw text file: script_name$
	endif
# remove Praat script from the object list
	removeObject: script_obj

# going thru all Praat scripts in a directory
endfor

# clean up - remove the list of Praat scripts
removeObject: praat_list_obj

# Informa user
printline Done. 'total' <tabs> and <spaces> removed from 'nr_praat_files' PRAAT scripts.
