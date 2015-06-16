#!/usr/bin/perl
# Joseph Harriott  http://momentary.eu/ 2014

# This script does various transformations on jpegs in the directory that it's in.
# The original jpegs are moved out to a folder (which is cleared first if it's not empty).
# Uses PerlMagick API.

# Prerequisites:  a system with Perl on, and a folder of jpegs (without spaces in the names).

# Drop this file into the parent folder that you want to work on, open a Terminal there,
# enter the name of this file, hit return, and watch the progress!

use strict;  use warnings;
use File::Basename;
use File::Copy 'move';
use File::Path qw(make_path remove_tree);
use Image::Magick;
use POSIX;
use Scalar::Util qw(looks_like_number);

# First, create a time check:
END { print "\nThis Perl program ran for ", time() - $^T, " seconds.  All changes reported.\n"}

# And a response hash for the conversions:
my $imgdone;
my $label;
my %resph = (
	'b' => '$image->Border(width=>\'9\', height=>\'9\', bordercolor=>\'goldenrod4\'); $imgdone = $image->[0]',
	'c' => '$image->Composite(image=>$label, gravity=>\'southeast\'); $imgdone = $image->[0]',
	'g' => '$image->Resize(geometry => \'1000x800\'); $imgdone = $image->[0]',
#	- preserves ratio, never exceeding either of these dimensions.
#	- badly degrades pencil sketches...
	'h' => '$image->Charcoal($param); $imgdone = $image->[0]',
	'k' => '$image->Sketch(0); $imgdone = $image->[0]',
	'l' => '$image->Resize(geometry => \'314\'); $imgdone = $image->[0]',
	'n' => '$image->Negate(); $imgdone = $image->[0]',
	'o' => '$image->OilPaint($param); $imgdone = $image->[0]',
#   'p' => '$imgdone = $image->Preview(\'Charcoal\')',
    'p' => '$imgdone = $image->Preview(\'OilPaint\')',
	's' => '$image->Resize(geometry => \'1150\'); $imgdone = $image->[0]',
	't' => '$image->Resize(geometry => \'90\'); $imgdone = $image->[0]',
	'v' => '$image->Level(levels=>\'0,50%,7.0\'); $imgdone = $image->[0]',
#                                 = black and white points, then gamma
	'v' => '$image->Level(levels=>\'0,100%,\'.$param); $imgdone = $image->[0]',
#                                 - using a range, defined below.
);

# Next, request input for conversions:
my ($scrbn,$dir,$ext) = fileparse($0, qr/\.[^.]*/);
my $ors = "./$scrbn"."_originals";
print "You are about to move all jpegs in the current folder to $ors !!\n";
print "hit Enter to quit, or go ahead with one of these ImageMagick conversion choices:\n";
foreach my $key (sort keys %resph){print "  Enter $key for $resph{$key}\n";}
my $resp = <STDIN>;
chomp $resp; # Get rid of newline character at the end
my @params = (-1);  # - this array prep'd with a negative number for later.
unless ($resph{$resp}) {print "Quit!  "; exit 0;}  # - if there's no response hash value chosen
# in special case requiring a parameter list, fill out more values:
if ($resp eq 'h' || $resp eq 'o' || $resp eq 'v') {
	if ($resp eq 'h') {@params = (0, 90)}
	elsif ($resp eq 'o') {@params = (0, 0.5, 1, 1.5, 2, 3, 5)}
	elsif ($resp eq 'v') {@params = (3.3, 3.4)}
	print "Enter to go ahead with these factor values: @params\n",
		"  or Enter your own space-separated list of factor value(s):\n";
	my @fresp = split(/\s+/, <>);  # - get the response into an array (even a null array)
	if (@fresp) {  # - user's fed in a factor list of some sort, so check & possibly tidy it:
		my @userf =();
		foreach my $entry (@fresp) {
			if (looks_like_number($entry)) {
				if ($resp eq 'h') {$entry = int($entry)}
				if ($entry >= 0 && $entry <= 99){push @userf, $entry}
			}
		}
		@params = @userf
	}
} elsif ($resp eq 'c') { # load in the label:
	if (-e "label.png") {
		$label = Image::Magick->new;
		$label->Read("label.png")}
	else {
		print "No label.png here!"; exit 0}
}
print "Okay, working.  ";

# Create an image object:
my $image = Image::Magick->new;

# Empty or create the directory to move the originals into:
remove_tree($ors,{keep_root=>1});
mkdir $ors;  # - made it anyway if it weren't there...
print "Originals will be moved to $ors\n";

# Now work through the directory collecting jpeg file names:
opendir(DIR, '.');
my @jpegs = grep { /\.jpg$/i && -f "./$_" } readdir(DIR);
closedir(DIR);

# Finally, work through the list of jpegs, applying the relevant conversion:
print "  $resph{$resp}";
local $| = 1;  # - turns off line buffering on STDOUT
my $jpgname;
my $prmstr;
my $jpgA = "jpgMagickinputASCII.jpg"; # - an unambiguous temporary ASCII name
# (a precaution: if Image::Magick's Read method is used on a filename containing `é`
# on Windows 7, this script fails at the Write method)
foreach my $jpeg (@jpegs) {
	print "\n  Converting $jpeg ";
	my $jpegbn = substr $jpeg, 0, -4;
	# temporarily move the jpeg to an uncomplicated filename:
	move $jpeg, $jpgA;
#   $image->Read($jpeg);
    $image->Read($jpgA);
	foreach my $param (@params) {
		my $tmstmp = POSIX::strftime("%H%M%S", localtime);
		# neatly format the parameter strings for adding to changed filename:
		if ($resp eq 'o' || $resp eq 'v') {$prmstr = sprintf("%.1f", $param)}
		else {$prmstr = sprintf("%02s", $param)}
		if ($params[1]) {
			print $prmstr." ".$tmstmp." "  # - just reporting time as a progress check
		}
		eval $resph{$resp}; warn $@ if $@; # - do the conversion!
		$jpgname = "$jpegbn"."_$prmstr$resp.jpg";  # - adding in parameter tag to jpeg name
		# Here I'm again taking care not to feed an filename that might contain
		# something like an `é` to Image::Magick because on Windows 7,
		# that character becomes the Replacement character, fffd:
		$imgdone->Write(filename => "./$prmstr.jpg");
		move "$prmstr.jpg", $jpgname;
	}
	move $jpgA, "$ors/$jpeg";
	if ($params[0] < 0) {move $jpgname, "$jpegbn$resp.jpg"}  # - remove an unused parameter tag
	@$image = ();  # - empty the object, ready for next i/o
#print " - done!\n"
}
undef $image;
