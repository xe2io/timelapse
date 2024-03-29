#!/usr/bin/perl

# Source: http://ubuntuforums.org/showthread.php?t=2022316
# Deps:
# libclass-methodmaker-perl
# libfile-type-perl
# libgstreamer-perl
# libterm-progressbar-perl
# libterm-readkey-perl
# perlmagick


# Script for simple and fast photo deflickering using imagemagick library
# Copyright Vangelis Tasoulas (cyberang3l@gmail.com)
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

# Needed packages
use Getopt::Std;
use strict "vars";
use feature "say";
use Image::Magick;
use Data::Dumper;
use File::Basename 'basename';
use File::Spec::Functions 'catfile';
use File::Type;
use Term::ProgressBar;
use MCE::Loop;

#use File::Spec;

# Global variables
my $VERBOSE       = 0;
my $DEBUG         = 0;
my $RollingWindow = 15;
my $Passes        = 1;
my $Geometry      = "";
my $g_jobprogress = 0;
my $g_progress;
my $data_dir = ".";
my $OUTPUT_DIR    = "Deflickered";

#####################
# Function to calculate luminance, MCE
sub worker_calculate_luminance
{
    my $index = shift;
    my $file = shift;

    #print MCE->wid . " Processing $file [$index]\n";

    my $image = Image::Magick->new;
    $image->Read($file);
    my @statistics = $image->Statistics();
    my $R          = @statistics[ ( 0 * 7 ) + 3 ];
    my $G          = @statistics[ ( 1 * 7 ) + 3 ];
    my $B          = @statistics[ ( 2 * 7 ) + 3 ];

    # Magic values
    # 0.2126 * $R + 0.7152 * $G + 0.0722 * $B;
    my $luminance = 0.299 * $R + 0.587 * $G + 0.114 * $B;

    my $luminance_H_ref = {};
    $luminance_H_ref->{'filename'} = $file;
    $luminance_H_ref->{'value'} = $luminance;
    $luminance_H_ref->{'original'} = $luminance;

    # Print some status message
    
    # Update progressbar
    MCE->do("update_progressbar");
    MCE->gather($index, $luminance_H_ref);
}

# Function to update the global progressbar
sub update_progressbar() 
{
    $g_progress->update(++$g_jobprogress);
}

# Function to change luminance, MCE
sub worker_change_luminance
{
    my $luminance_H_ref = shift;
    my $geometry = shift || "";


    # probably not thread-safe
    verbose("Changing luminance of $luminance_H_ref->{filename} from $luminance_H_ref->{original} to $luminance_H_ref->{value}.\n");

    my $brightness = ( 1 / ( $luminance_H_ref->{original} / $luminance_H_ref->{value} ) ) * 100;

    my $image = Image::Magick->new;
    $image->Read( $luminance_H_ref->{filename} );

    # Resize if geometry is provided
    if($geometry ne "") 
    {
        my $err = $image->Resize(geometry => $geometry);
        warn "$err" if "$err";
    }

    $image->Mogrify( 'modulate', brightness => $brightness );

    #$image->Gamma( gamma => $gamma, channel => 'All' );
    $image->Write( catfile($OUTPUT_DIR, basename($luminance_H_ref->{filename})) );
    MCE->do("update_progressbar");
}

#####################
# handle flags and arguments
# Example: c == "-c", c: == "-c argument"
my $opt_string = 'hvdw:p:r:i:o:';
getopts( "$opt_string", \my %opt ) or usage() and exit 1;

# print help message if -h is invoked
if ( $opt{'h'} ) {
  usage();
  exit 0;
}

$VERBOSE       = 1         if $opt{'v'};
$DEBUG         = 1         if $opt{'d'};
$RollingWindow = $opt{'w'} if defined( $opt{'w'} );
$Passes        = $opt{'p'} if defined( $opt{'p'} );
$Geometry      = $opt{'r'} if defined( $opt{'r'} );
$data_dir      = $opt{'i'} if defined( $opt{'i'} );
$OUTPUT_DIR    = $opt{'o'} if defined( $opt{'o'} );

die "The rolling average window for luminance smoothing should be a positive number greater or equal to 2" if ( $RollingWindow < 2 );
die "The number of passes should be a positive number greater or equal to 1"                               if ( $Passes < 1 );

# main program content

my %luminance;


opendir( DATA_DIR, $data_dir ) || die "Cannot open $data_dir\n";
my @files = readdir(DATA_DIR);
@files = sort @files;

# Make sure we only use image files
my @img_files = ();
foreach my $filename (@files) {
    $filename = catfile($data_dir, $filename);
    my $ft   = File::Type->new();
    my $type = $ft->mime_type($filename);

    my ( $filetype, $fileformat ) = split( /\//, $type );
    if($filetype eq "image")
    {
        push(@img_files, $filename);
    }   
}

my $num_images = scalar(@img_files);

if ( $num_images > 1 ) {
    say "Original luminance of Images is being calculated";
    say "Please be patient as this might take several minutes...";

    # Autocalculate workers
    MCE::Loop::init { chunk_size => 1 };

    $g_progress = Term::ProgressBar->new( { count => $num_images } );

    %luminance = mce_loop { worker_calculate_luminance($_, $img_files[$_]) } (0..$num_images-1);
} 

say "$num_images images found in the folder which will be processed further.";


my $CurrentPass = 1;

while ( $CurrentPass <= $Passes ) {
  say "\n-------------- LUMINANCE SMOOTHING PASS $CurrentPass/$Passes --------------\n";
  luminance_calculation();
  $CurrentPass++;
}

say "\n\n-------------- CHANGING OF BRIGHTNESS WITH THE CALCULATED VALUES --------------\n";
# Create the output directory if it doesn't exist
if(! -d $OUTPUT_DIR)
{
    mkdir($OUTPUT_DIR) || die "Error creating directory: $!\n";
}

# Create the progress bar
$g_jobprogress = 0;
$g_progress = Term::ProgressBar->new( { count => $num_images } );
my %ret_status = mce_loop { worker_change_luminance($luminance{$_}, $Geometry) } (0..$num_images-1);

#luminance_change();
say "\n\nJob completed";
say "$num_images files have been processed";

#####################
# Helper routines

sub luminance_calculation {
  my $max_entries = scalar( keys %luminance );
  my $progress    = Term::ProgressBar->new( { count => $max_entries } );
  my $low_window  = int( $RollingWindow / 2 );
  my $high_window = $RollingWindow - $low_window;

  for ( my $i = 0; $i < $max_entries; $i++ ) {
    my $sample_avg_count = 0;
    my $avg_lumi         = 0;
    for ( my $j = ( $i - $low_window ); $j < ( $i + $high_window ); $j++ ) {
      if ( $j >= 0 and $j < $max_entries ) {
        $sample_avg_count++;
        $avg_lumi += $luminance{$j}{value};
      }
    }
    $luminance{$i}{value} = $avg_lumi / $sample_avg_count;

    $progress->update( $i + 1 );
  }
}

sub usage {

  # prints the correct use of this script
  say "Usage:";
  say "-i    Input directory with files";
  say "-o    Output directory to write deflickered images";
  say "-w    Choose the rolling average window for luminance smoothing (Default 15)";
  say "-p    Number of luminance smoothing passes (Default 1)";
  say "       Sometimes 2 passes might give better results.";
  say "       Usually you would not want a number higher than 2.";
  say "-r    [Optional] Resize the deflickered image per the given string, e.g.:";
  say "       1920x1080^";
  say "       See http://www.imagemagick.org/script/command-line-processing.php#geometry for more info";
  say "-h    Usage";
  say "-v    Verbose";
  say "-d    Debug";
}

sub verbose {
  print $_[0] if ($VERBOSE);
}

sub debug {
  print $_[0] if ($DEBUG);
}
