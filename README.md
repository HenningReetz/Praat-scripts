## Praat scripts

This repository contains several Praat scripts. Many are rather complex and allow different types of computations (not all can be selected in the form window, because it would become too long; but the associated manuals point out what can be easily changed in the scripts). I always hope to update everything to a more coherent ‘standard’, but as always, it will take time.
Any error reports or suggestions for improvements to <reetz.phonetics@gmail.com>

BEGINNERS:
Praat_in_a_Nutshell_17-12-2015.pdf
Very basic guide to use Praat - not scripting!

Praat errors.pdf
Very few tips on common errors when using Praat (scripts).

Praat_scripts_structure.pdf
Still in German! How I structure my Praat scripts.

Praat_Tips_German.pdf
Still in German! Some tips to make your Praat script faster.


BASIC TOOLS
Remove_spaces
Removes trailing tabs and spaces in Praat scripts.
Solves one of the annoying problems with them.

Pre_Process
Resample, monorize and scale all files in a directory.
Useful as a first step prior to (e.g. formant) analyses.

Inspect
Inspect a sequence of sound (and TextGrid) files (jumps to intervals in the files).
Helpful to inspect e.g. Pitch, Formant, or Spectrum results.

Extract_Intervals
Generates separate wav-files from labeled intervals.

Label
Interactive supply of text labels for segmenting (labels are supplied from a text file for each interval or point).

Hillenbrand2TextGrid
Convert Hillenbrand et al.'s vowels timimg info into TextGrids

TIMIT2praat
Convert TIMIT's WAV, phoneme, word and sentece files to Praat's .wav and TextGrids

DURATION
Duration
Computes durations of all files or (selected) intervals of all files in a directory or reports times of point tiers.


INTENSITY
Intensity
Computes intensities of all files or of (selected) intervals of all files in a directory, and can report mean, standard deviation, median, quantiles of intervals/files and intensity values at equidistant time points (incl. only at center and/or edges) of intervals/files (e.g. to plot contours with a spreadsheet program of the result data)

PITCH
Pitch
Computes F0 of all files or of (selected) intervals of all files in a directory,, and can report mean, standard deviation, median, quantiles of intervals/files and pitch values at equidistant time points (incl. only at center and/or edges) of intervals/files (e.g. to plot contours with a spreadsheet program of the result data)


FORMANTS
Formants
Computes formants (optional with bandwidth and amplitude, F0 and intensity) of all files or for (selected) intervals of all files in a directory,
at the center or edges of intervals, and can compute mean, st.dev., median, quantiles.

Formant_Contour
Computes formant contours of all files or for (selected) intervals of all files in a directory.

Add_LPC_Spectrum
Display LPC spectra (as a menu option).

SPECTRUM
Spectrum
Computes spectral mean, st.dev., skewness and kurtosis of selected intervals in all files of a directory.

CSL PERL
csl2praat.pl
Convert CSL-Tags/Impulses to PRAAT-TextGrids.
(Written for UNIX/Mac - DOS needs backslashes in the path!)

tags.pl
Compute distances/frequencies from CSL-tags/impulses.
(Works with samples/ms/Hz)
