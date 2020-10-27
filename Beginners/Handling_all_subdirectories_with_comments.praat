##
# Get a list of all directories and subdirectories
# 	This is a bit tricky since PRAAT does support full recursiveness with local variables.
#	And since I don't know how to add lines beyond the end of a list of Strings, I programmed the following:
#	1) Get a list of directories starting at the present directory (= 'dir_list')
#	2) set a pointer to the beginning (= 'now_dir_pnt') of this list and another to the end of the list (= 'nr_dir_list')
#	3) while the 'now_dir_pnt' has not gone beyond 'nr_dir_list', do the following
#		3a) get all directories in the directory to which 'now_dir_pnt' points
#		3b) append this list to 'dir_list' and increase the end_pointer (= 'nr_dir_list')
#		3c) increase 'now_dir_pnt'
#	(The actual implementation with 'now_dir_pnt' and 'nr_dir_list' is a bit different, but does the same;
#	furthermore, 'appending' het lists is a bit tricky, since 'Append' creates a new list, so that
#	the actual action is appending, deleting the old lists, and renaming the new 'appended' list
#	to the old name.)
#
#	Note, that the directory names in the list do nopt end with slash "/" - this has to be added later! 
#
#	HR, 31-01-09
##

# clear the info window
clearinfo

# point to the starting directory; here: the present directory
dir_name$ = ""

# total number of directories already found
nr_dir_list = 0

# pointer to the directory in the list of all directories
now_dir_pnt = 0

# initiate procedure by creating a list of all directories in the present directory
# This 'dir_list' becomes an object in PRAAT; '
#	'now_dir_pnt' points into this list to the directory which will be searched for sub-directories;
#	if there are sub-directories, they will be added to the end of this list. Eventually, 
#	'now_dir_pnt' will point to the first, second, third... of these sub-directories, which themselves 
#	will be investigated for sub-directories. By this procedure, the search will go deeper and deeper
#	into the tree of (sub-)directories.
Create Strings as directory list...  dir_list 'dir_name$'*

# find out, how many strings (i.e. names of directories) are in the list.
nr_dir_list = Get number of strings

# Continue as long as 'now_dir_pnt' has not reached 'nr_dir_list'
#	Note, that at the beginning, 'now_dir_pnt' points to '0', i.e. below the beginning of the list.
#	If there are no directories in the beginning then 'nr_dir_list' will also be '0' and the while-loop
#	will not be entered (because there are no directories to be investigated).
#	If there are any directory in the list, 'now_dir_pnt' will be incremented inside the loop; e.g.
#	if 'nr_dir_list' is '1', the while-loop will be entered (because 'now_dir_pnt' is '0') and 'now_dir_pnt'
#	will be incremented to '1', pointing to the one directory to be investigated (which might contain 
#	hundreds of sub-directories, which all will be investigated, because any newly found 
#	sub-directories will increase 'nr_dir_list' and the next time the while-loop will compare this with
#	'now_dir_pnt' (still at '1') and the loop will be entered again.
while now_dir_pnt < nr_dir_list

# Point to the next directory in the list to be investigated (at the beginning, this is '1',
# i.e. the first directory in the list. The test of the while-loop makes sure, that we cannot
# go beyond 'nr_dir_list'.).
	now_dir_pnt += 1

# Make sure that we point to the main list (= 'dir_list')
	select Strings dir_list

# Get the line to which 'now_dir_pnt' points
	dir_name$ = Get string... 'now_dir_pnt'

# Append a slash to this name, because it is adirectory name
# and we want to investigate whether there are directories inside this directory 
# (i.e. look for sub-directories).
	dir_name$ = dir_name$+"/"

# Now create a new list of all sub-directories of the directory to which 'now_dir_pnt' points
	Create Strings as directory list...  new_dir_list 'dir_name$'*

# get the number of sub-directories ('new_dir_list' is automatically selected by the previous command)
	nr_new_dir_list = Get number of strings
	
# In case there are new sub-directories, we have to add them to the list
# (otherwise, we do essentially nothing other than a bit of cleaning up, see 'else' below).
	if nr_new_dir_list != 0

# The command "Create Strings as directory list..." started from the directory to which
# 'now_dir_pnt' pointed. We will need the full path-name and insert for that reason the name
# of the 'now_dir_pnt' directory in front of the newly found names inside 'new_dir_list'.
# To do so, we go thru all 'nr_new_dir_list' names in 'new_dir_list'
		for i from 1 to 'nr_new_dir_list'

# (Btw., 'new_dir_list' is and remains selected, so we don't have to sre-select it here!)		
# Get the 'i'th name from the new list
			new_dir_name$ = Get string... 'i'

# add the 'now_dir_pnt' name (which is in 'dir_name$') in front of it.
# Remember, that 'dir_name$' ends already with a slash ("/") to mark the end of a directory name!
# Note further, that 'dir_name$' might be a sub-sub-sub-directory already (i.e., there might be several
#	slashes in it), i.e., we construct here the full directory path.
			new_dir_name$ = dir_name$+new_dir_name$

# Now overwrite the 'i'th name in the new list with the full path name.
			Set string... 'i' 'new_dir_name$'

# looping t hru all names in the 'new_dir_list'
		endfor

# We 'append' now the old list (= 'dir_list') with the new sub-directory list (= 'new_dir_list).
# We select 'dir_list'...
		select Strings dir_list
		
# ...and add the 'new_dir_list' to it (like dragging the cursor over both names with the shift-key pressed)...
		plus Strings new_dir_list
		
# ...and append both lists. This actually creates a new list with the name 'appended' (see below).
		Append

# We clean up, since the list 'appended' contains all directory names 
#	and we do not need 'dir_list' and 'new_dir_list' anymore
# We select 'dir_list' again, since 'appended' is selected by the previous command,...
		select Strings dir_list

# ... add 'new_dir_list' again...
		plus Strings new_dir_list

# ... and remove both lists
		Remove
		
# Now we rename the list 'appended' to the old name 'dir_list', so that the game can start all
# 	over again (but since 'now_dir_pnt' will be incremented, with the next directory in the list).
# We select the list 'appended'
		select Strings appended

# ... and rename it to 'dir_list'
		Rename... dir_list

# We have appended 'new_dir_list' to the 'dir_list', so we have to add the number of directories
#	to 'nr_dir_list'. (We could do this also with a 'Get number of strings command', but this is faster.)
		nr_dir_list += nr_new_dir_list

# The 'else' part of the 'if' statement will be entered in case there are no sub-directories found
# 	in the directory to which 'now_dir_pnt' points. We still have to remove the (empty) list that
#	has been created by the "Create Strings as directory list..." command
	else
	
# We select the (empty) 'new_dir_list'...
		select Strings new_dir_list
		
# ... and remove it.
		Remove

# Okay, this is the end of the test, whether there are (or are not) sub-directories in the 
#	directory under investigation
	endif

# Okay, we have done everything for the present 'now_dir_pnt' directory. The "while" on top
# 	will check whether there are any more directories in 'dir_list_ to be investigated.
endwhile

# The algorithm above will investigate first all directories in the 'starting' directory,
# then it goes down one sub-directory level thru all these directories, then it will investigate
# the next level for all sub-directories, etc.
# But you might want to go from one directory first into all its sub-(sub-..)directories and after 
# that to the next directory (and all its sub-directories). To do so, we sort the 'dir_list' which 
# will bring related names closer together.
# Select 'dir_list' first...
select Strings dir_list

# ... and sort it.
Sort

# Report to the user:
printline 'nr_dir_list' directories found.

# Note, that at this point
#	1) the directory names in 'dir_list' do not end with a slash 
#		(which you have to add when you want to access a file in it)
#	2) the list does not contain the name of the directory, where you started
#		(i.e., if you want to treat files in it, you have to go thru this directory separately)


##
#
#	Here comes now an example who to use the directory list:
#	The following skript goes thru all sub-directories we have found
#			(but not the present directory itself!)
#	and looks for all related '.wav' and '.TextGrid' files. 
#
##

nr_completed = 0
nr_x = 0

for i_dir from 1 to nr_dir_list
	select Strings dir_list
	dir_name$ = Get string... 'i_dir'
	dir_name$ = dir_name$+"/"

# create a list of all files in this sub-directory that end in ".TextGrid"
	Create Strings as file list...  textgrid_list 'dir_name$'*.TextGrid
	nr_of_textgrids = Get number of strings
	nr_x += nr_of_textgrids

	printline Handling 'dir_name$' with 'nr_of_textgrids' TextGrids.
	
	for i_file from 1 to 'nr_of_textgrids'
		select Strings textgrid_list
		textgrid_file_name$ = Get string... 'i_file'
		textgrid_file_name$ = dir_name$+textgrid_file_name$

		Read from file... 'textgrid_file_name$'
		base_name$ = selected$ ("TextGrid")
## If you handling only a few hundred or very long files, you might want to uncomment the next line
#		print Handling 'base_name$'
		
# try to open a .wav file for this TextGrid

		ext$ = ".wav"
		sound_file_name$ = dir_name$+base_name$+ext$
		if fileReadable (sound_file_name$) 

## here is the real action
			Read from file... 'sound_file_name$'
# --> Do whatever you want to do here <--
#			printline finished. 
			select Sound 'base_name$'
			Remove

			select TextGrid 'base_name$'
			Remove
			nr_completed += 1
		else
			printline failed! No sound file 'sub_directory$''base_name$''ext$' found. <***
			Remove
		endif
	endfor
	
	select Strings textgrid_list
	Remove
endfor

# clean up and go home

select Strings dir_list
Remove

if nr_completed != nr_total
	printline Done. 'nr_completed' of 'nr_total' TextGrid files processed.
else
	printline Done. 'nr_completed' TextGrid files processed.
endif






