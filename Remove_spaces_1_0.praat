##
#	This script removes tabs and spaces at the end of lines in praat scripts
#
#  	Version 0.0, Henning Reetz, 21-apr-2019
#
#	Tested with Praat 6.1.12
##

clearinfo

# extension of the script files
ext$ = ".praat"

# create list of .praat files
praat_list_obj = Create Strings as file list:  "file_list", "*'ext$'"
nr_praat_files = Get number of strings

##
#  Go thru all files
##

total = 0

for i_file to nr_praat_files
	selectObject: praat_list_obj
	script_name$ = Get string: i_file
	script_obj = Read Strings from raw text file: script_name$
	nr_lines = Get number of strings

# go thru all lines
	for i_line to nr_lines
		line$ = Get string: i_line
		length = length(line$)
		change = -1
		repeat
			last_length = length
			line$ = replace_regex$ (line$,"'tab$'$","",0)
			line$ = replace_regex$ (line$," $","",0)
			length = length(line$)
			diff = last_length - length
			total += diff
			change += 1
		until (diff = 0)

		if (change)
			Set string: i_line, line$
		endif
	endfor

	Save as raw text file: script_name$
	removeObject: script_obj
endfor
removeObject: praat_list_obj

printline Done. 'total' <tabs> and <spaces> removed from 'nr_praat_files' PRAAT scripts.
