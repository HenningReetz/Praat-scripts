#/usr/bin/perl -w

=pod
Search for all *.NSP files and check whether they have Tags or Impluse marks and convert these
to a PRAAT TextGrid file. The .NSP file remains untouched (and is not converted into a .wav file).

Ugly hack from old TAGS.PL...
Haven't tested it with Impulses yet neither to generate Point tiers...
=cut

#use diagnostics;
use strict;

my $version=0;								# 07-jul-07, hr (henning reetz): first implementation
my $revision=0;								# 07-jul-07, hr: 
my $bugfix=0;								# not extensively tested

# pre-set switches to control the behavior of the program

my $trace = 0; 								# trace for NSP-header

my $out_type = 'segment';					# 'position', 'distance'
my $mark_type = 'tag';						# 'tag', 'impulse'
my $sub_directories=1;						# subdirectory handling 

my $buf;									# general purpose buffer
my @out_buf;								# output buffer
my %nr_tag_hash;

my $rate = 0;								# sampling rate
my ($bytes,$samples,$level_a,$level_b);		# important header information
my @tag_buf;								# buffer for tags/impulses
my @name_buf;								# buffer for tags names

my $pos = '';
my $down = '';								# used for subdirectory search
my @file_name;								# filename (with path) and segmentname (without path)

# read switches from the user

while ($#ARGV >= 0) {					# as long as there are command line arguments
	my $command = shift(@ARGV);		# get one
	if ($command =~ /^he/) {				# help?
		print "\n";
		print "csl2praat.pl extracts the tags or impulses of NSP files and makes TextGrid files for PRAAT from it.\n\n";
		print "possible switches:\n\n";
		print "\n";
		print " imp	 	use impulse-marks, not tags\n";
		print "\n";
		print " point	create PRAAT-points, not segments\n";
		print "\n\n";
		print "For example:\n";
		print " csl2praat.pl point\n";
		print "Converts all tags in NSP files to points in TextGrid files in all sub-directories.\n";
		die "\n";
		
	} elsif ($command =~ /^po/) {		# points
		$out_type = 'points';
	} elsif ($command =~ /^im/) {		# use impulse marks (and not tags)
		$mark_type = 'impulse';
	} else {												# unknown switch
		print "Argument \"$command\" ignored.\n";
	}																# if-ten-elsing commands
}																	# analysing command line



print "\ncsl2praat.pl, Vers. $version.$revision.$bugfix\n";

# recursive subroutine to find all files with uppercase or lowercase .NSP in their name

sub SubDir {								# go into subdirectory
	my $curdir = $_[0];						# name of directory
	if ($curdir ne ".") {					# not present one?
		$pos .= "$curdir/";					# make it a full path name
		$down++;							# count the depth
		chdir "$curdir";					# change directory
	}										# test for present directory
	my @content = <*>;						# all file names
	foreach my $file (@content) {			#	go thru each file
		if (-d $file) {						# is it a subdirectory?
			if ($sub_directories==1) {		# and if subdirectory search is on (do not 'and' this with subdirectory test!!)
				&SubDir($file);				# go into subdirectory
			}								# going into subdirectory
		} else {							# otherwise (could be a directory here!!)
			my $help = $pos.$file;			# path with filename
			if (lc($help) =~ /\.nsp$/) {	# filename ends in .nsp?
				push (@file_name,$help);	# put it onto the stack
			}								# name with .nsp at the end?
		}									# file or subdirectory test
	}										# going thru all file of a directory

	if ($down>0) {							# are we in a subdirectory?
		chdir "..";							# go up again 
		$pos =~ s/(.*\/).*\///;				# remove path, but store first part in $1
		$pos = $1;							# restore first part of path
		$down--;							# step up in depth counter
	}										# stepping up

}											# subaroutine for subdirectory handling


sub GetNspHeader {
	my $loc_file = $_[0];
	my $file_length;						# length of file (needed only for trace)
	my $header;								# NSP-header flag (only one allowed)
	my $block;								# NSP-block (MKA, SDA, etc.)
	my ($tot_len,$sum);						# length of data in file
	$#tag_buf = -1;

	if ($trace == 1) {						# trace required
		print "$loc_file\t";					# report filename
		$file_length = -s $loc_file;			# length of file
	}

	if ((open (IN,"<$loc_file")) != 1) {
		print "can't open \"$loc_file\"\n";
		return 0;
	}										# open nsp file (but continue if it fails)
	binmode IN;								# go into bin-mode (i.e., it's not character i/o)
	
# read file header (put it in a subroutine)	
	
	$buf = '';
	read (IN, $buf, 4);						# get first 4 bytes
	$sum += 4;								# count bytes
	if ($buf ne 'FORM') {					# NSP files start with 'FORM'
		print "File $loc_file does not contain CSL/MultiSpeech data header (\"FORM\").\n";
		return 0;
	}

	$buf = '';
	read (IN, $buf, 4);						# get next 4 bytes
	$sum += 4;								# count bytes
	if ($buf ne 'DS16') {					# must be 'DS16'
		print "File $loc_file does not contain CSL/MultiSpeech data header (\"DS16\").\n";
		return 0;
	}
	
	$buf = '';
	read (IN, $buf, 4);						# get next 4 bytes
	$sum += 4;								# count bytes
	$tot_len = unpack('V',$buf);			# data length of file (can be shorter than MSDOS-file length!) 'VMS' format (it's INTEL)
	if ($trace == 1) {						# trace wanted?
		print "File_length: $file_length, Tot_len: $tot_len\n";	
	}
	$tot_len += $sum;						# total length of NSP-data in file

	while  ($tot_len > $sum) {				# still data in file?

# read block code and length of block

		$block = '';
		read (IN, $block, 4);				# read next block header
		$sum += 4;							# 4 bytes read
		if ($trace == 1) {					# trace wanted?
			print "$block, ";
		}
		$buf = '';
		read (IN, $buf, 4);					# length of block
		$sum += 4;							# 4 bytes read
		my $len = unpack('V',$buf);			# length of block in integer
		if ($trace == 1) {					# trace wanted?
			print "$len\n";
		}
		
# check blocks		
		
		if ($block eq 'HEDR') {				# header block
			if ($header != 0) {				# only one header allowed
				print "File $loc_file has more than one CSL/MultiSpeech data headers.\n";
				return 0;
			}
			$header = 1;					# set header-found flag
		
			if ($len != 32) {				# header must be 32 bytes long
				print "File $loc_file has an invalid CSL/MultiSpeech data header (\"HEDR\" is $len).\n";
				return 0;
			}
			$buf = '';
			read (IN, $buf, 20);			# date; format is "Dec 21 12:04:21 2004"
			$buf = '';
			read (IN, $buf, 4);				# next 4 bytes
			$rate = unpack('V',$buf);		# are the sampling rate
			$buf = '';
			read (IN, $buf, 4);				# next 4 bytes
			$bytes = unpack('V',$buf);		# length of data part in samples
			$buf = '';
			read (IN, $buf, 2);				# next 2 bytes
			$level_a = unpack('v',$buf);	# maximal level of left channel
			$buf = '';
			read (IN, $buf, 2);				# next 2 bytes
			$level_b = unpack('v',$buf);	# maximal level of right channel
			if ($trace == 1) {				# trace wanted?
				print "Rate: $rate, Length: $bytes, level_a: $level_a, level_b: $level_b\n";
			}
			$sum += 32;						# add header bytes

		} elsif (($block eq 'SDA_') || ($block eq 'SD_B')) {	# sample block (mono)
			$samples = $len / 2;			# 16-bit samples, i.e. 2 bytes = 1 sample
			seek (IN,$len,1);				# skip data
			$sum += $len;					# add data bytes
		
		} elsif ($block eq 'SDAB') {		# 2-channel sample block
			$samples = $len / 4;			# 2 * 16-bit samples, i.e., 4 bytes = 1 samples
			seek (IN,$len,1);				# skip samples
			$sum += $len;					# add data bytes

		} elsif ($block eq 'NOTE') {		# note-block
			$len = int(($len+1)/2) * 2;		# make it an even number of bytes 1=>2; 2=>2
			$buf = '';
			read (IN, $buf, $len);			# read even number of bytes
			$sum += $len;					# add bytes
		
		} elsif (($block eq 'MKA_') || ($block eq 'MK_B') || ($block eq 'MKAB')) {	# tag
			$len = (int(($len+1)/2) * 2) - 4;	# make length even and subtract 4 byes for position
			$buf = '';
			read (IN, $buf, 4);					# read 4 bytes (position of tag)
			$sum += 4;							# add 4 bytes
			if ($mark_type eq 'tag') {			# if tags are evaluated (and not impulses)
				my $pos = unpack('V',$buf);		# get position of tag (in sample number)
				$pos++;
				push (@tag_buf,$pos);			# store tag
			}
			$buf = '';
			read (IN, $buf, $len);				# read name of tag
			if ($mark_type eq 'tag') {			# if tags are evaluated (and not impulses)
				push (@name_buf,$buf);			# store tag
			}
			$sum += $len;						# add length of tag

		} elsif (($block eq 'PKA_') || ($block eq 'PK_B') || ($block eq 'PKAB')) {	# tag
			if ($mark_type eq 'impulse') {		# if impulsess are evaluated (and not tags)
				for (my $i=0; $i < $len; $i+=4) {
					$buf = '';
					read (IN, $buf, 4);			# read impulses
					my $pos = unpack('V',$buf);	# get position of impulse (in sample number)
					$pos++;
					push (@tag_buf,$pos);		# store impulse
				}
			} else {
				seek (IN,$len,1);				# skip pulses
			}
			$sum += $len;						# add length of data section

		} elsif ($block eq 'CHA_') {		# note-block
#			$len = int(($len+1)/2) * 2;		# make it an even number of bytes 1=>2; 2=>2
			$buf = '';
			read (IN, $buf, $len);			# read even number of bytes
			$sum += $len;					# add bytes
		} else {
			print "File $loc_file has an unrecognized block type (\"$block\") at byte $sum, length: $len.\n";
			$buf = '';
			read (IN, $buf, $len);				# hope that the length was stored in 'len'
			$sum += $len;					# add data bytes
		}
	}											# handling header blocks

	return $rate;								# successful return
}


# here's the main program

&SubDir('.');									# get all .nsp file names (probably with subdirectories)

# treat each NSP-file

foreach my $in_file (@file_name) {				# handle all files

# extract header (including tags and impulses) of file

=pod
	prepare tags for output:
@@@	put 'nr. of tags', 'file/segment name', 'tag data' together into one line, separated by '#' 
	sorting this line will put the files with the least 'nr. of tags' first (if there are less than 10)
	dissembling this line, gives the sorted or unsorted output fro the user
	(in other words, this concatenation with '#' and splitting later is unnecessary if there is no sorting involved.
	but by this procedure, the activity is the same, and only one 'sort' is missed.)
=cut

	$rate = &GetNspHeader($in_file);
	my $nr_tag = $#tag_buf + 1;						# first tag is in position '0'
	$nr_tag_hash{$nr_tag}++;						# increase "how many files have <nr. of tages"
	if ($nr_tag > 0) {								# there are some tags
		@tag_buf = sort({$a <=> $b} @tag_buf);			# sort tags them by position
##@@ sort name_buf as well!!!
# create textgrid file and write header

		my $file = $in_file;	# create file name (with path) for Textgrid
		$file =~ s/nsp$/TextGrid/i;		# create file name (with path) for Textgrid
		open OUT,">$file" or die "Cannot create $file\n";						# create file
		print OUT "File type = \"ooTextFile short\"\n";				# 'short' textfile header
		print OUT "\"TextGrid\"\n\n";					# textgrid header + empty line
		print OUT "0\n";							# start point in seconds
		my $help = $samples/$rate;					# length of file in seconds

		print OUT "$help\n";						# write it out 
		print OUT "<exists>\n";						# textgrid sexists
		print OUT "1\n";							# one tier
		if ($out_type eq 'segment') {				# report distances?
			print OUT "\"IntervalTier\"\n";			# which is an interval tier
		} else {									# otherwise, report points
			print OUT "\"PointTier\"\n";			# which is an point tier
		}
		print OUT "\"tags\"\n";						# name of tier
		print OUT "0\n";							# start point of tier in seconds
		print OUT "$help\n";						# end point of tier in seconds 
		$help = $nr_tag + 1;						# nr. of segments is nr. of tags plus 1
		print OUT "$help\n";						# nr. of segments

# go thru the tags

		my $cnt = 0;								# segment counter		
		my $last = 0;									# last onset @@@
		while (my $pos = shift(@tag_buf)) {				# get next tag
			if ($out_type eq 'segment') {				# report distances?
				print OUT "$last\n";					# write start position in seconds
			}
			$last = $pos / $rate;						# present position in seconds
			print OUT "$last\n";						# write end/present position in seconds
			print OUT "\"$cnt\"\n";						# tag name is its number
			$cnt++;
		}												# going thru all tags
		print OUT "$last\n";						# write end/present position in seconds
		$last = $samples / $rate;						# present position in seconds
		print OUT "$last\n";						# write end/present position in seconds
		print OUT "\"$cnt\"\n";						# tag name is its number
		close OUT;
		print "$nr_tag segments written to $file\n";						# create file		
	}
}														# going thru all files

#@@ nr_tag_hash output!
