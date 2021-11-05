#!/usr/bin/perl -wT
# wl2url - converts MacOSX .webloc files to Microsoft style .url files.
#
# MacOSX .webloc files historically stored the url in their resource fork 
# while .url files were simple text documents with the following format:
#
# [InternetShortcut]
# URL=<url>
#
# wl2url extracts the url from a .webloc file using DeRez as follows:
# 
# $ DeRez -e [file] -only 'url '
# 
# The output is similar to the following:
#
# data 'url ' (256, "Sriranga Veeraraghavan.webloc") {
#   $"6874 7470 3A2F 2F77 7777 2E63 7375 612E"       /* http://www.csua. */
#   $"6265 726B 656C 6579 2E65 6475 2F7E 7261"       /* berkeley.edu/~ra */
#   $"6E67 612F"                                     /* nga/ */
# };
#
# The url is stored in the c-style comment at the end of the line. 
#
# For more information see:
#
# http://www.macosxhints.com/article.php?story=20040111200114634&mode=print
# http://www.macosxhints.com/article.php?story=20040728185233128&mode=print
#
# If DeRez is not available, then strings is used instead:
#
# /usr/bin/strings [file]/..namedfork/rsrc
#
# The first line that starts with a ';' contains the url
#
# This tool is probably no longer needed, as modern version of MacOSX have
# converted .webloc files to an xml format.
#
# Copyright (c) 2003-2005, 2021 Sriranga Veeraraghavan <ranga@calalum.org>
#
# Permission is hereby granted, free of charge, to any person
# obtaining a copy of this software and associated documentation
# files (the "Software"), to deal in the Software without
# restriction, including without limitation the rights to use, copy,
# modify, merge, publish, distribute, sublicense, and/or sell copies
# of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
# BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
# ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
# CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#

use strict;
use Getopt::Std;
use File::Spec;
use vars qw/ %OPTS /;

#
# main
#

delete @ENV{qw(IFS CDPATH ENV BASH_ENV)};
$ENV{'PATH'} = "/bin:/sbin:/usr/bin:/usr/sbin";

my %PGMINFO = ( 'NAME'    => 'wl2url',
                'VERSION' => '0.4' );

my @DEREZ_DIRS = ("/Developer/Tools/", "/usr/bin/");
my $DEREZ_BIN="DeRez";
my $DEREZ="";
my $DIR="";
my $STRINGS="/usr/bin/strings";
my $FILE = "";
my $OUTFILE = "";
my $RC = 0;
my $URL = "";
my $NOFILE = 0;
my $DELFILE = 0;
my $QUIET = 0;
my $USESTRINGS = 0;
my @TMPFILES = ();
my $OPTSTR = "o:ndqhvs";
my $OUTDIR = "";
my $RSRC_PATH = '/..namedfork/rsrc';

# process the command line arguments

if (getopts($OPTSTR, \%OPTS)) {

    # -n - don't create an output file

    $NOFILE = 1 if ($OPTS{'n'});

    # -d - delete the webloc file

    $DELFILE = 1 if ($OPTS{'d'});

    # -q - be quiet, no output

    $QUIET = 1 if ($OPTS{'q'});

    # -s - don't use DeRez (even if available)

    $USESTRINGS = 1 if ($OPTS{'s'});
    
    # -h - print help and exist

    if ($OPTS{'h'}) {
        printUsage();
        exit(0);
    }

    # -v - print version and exist

    if ($OPTS{'v'}) {
        printVersion();
        exit(0);
    }
    
    # -o output directory for files

    $OUTDIR = $OPTS{'o'};
    if (defined($OUTDIR)) {
        if (! -d $OUTDIR) {
            printError("No such directory: '$OUTDIR'");
            exit(1);
        }    
    } else {
        $OUTDIR = "";
    }

} else {
    printUsage();
    exit(1);
}

if (scalar(@ARGV) < 1) {
    printUsage();
    exit(1);
}

# if we aren't using strings, try to find DeRez

if ($USESTRINGS != 1) {
    foreach $DIR (@DEREZ_DIRS) {
        if (-x "$DIR/$DEREZ_BIN") {
            $DEREZ="$DIR/$DEREZ_BIN";
            last;
        }
    }
}

foreach $FILE (@ARGV) {

    $URL = extractUrl($FILE);
    
    unless (defined($URL) && $URL ne "") {
        $RC = 1;
        next;
    }

    print "$URL\n" unless ($QUIET);
    
    next if ($NOFILE);

    $OUTFILE = $FILE;
    if ($OUTDIR ne "" && -d $OUTDIR) {
        $OUTFILE =~ s/^.*\///;
        $OUTFILE = "$OUTDIR/$OUTFILE";
    }
    $OUTFILE =~ s/\.webloc$//i;
    $OUTFILE =~ s/\.ftploc$//i;
    $OUTFILE .= ".url";

    if (createInternetShortcut($URL, $OUTFILE) < 0) {
        $RC = 1;
    } elsif ($DELFILE) {
        $RC = 1 if (deleteWebloc($FILE) < 0);
    }
}

exit($RC);

#
# subroutines
#

# extractUrl - extract the url from a webloc file

sub extractUrl
{
    my $haveDeRez = 0;
    my $url = "";
    my $filePath = "";
    my $xmlformat = 0;
    my @parts = ();
    my $wlf = shift @_;

    $haveDeRez = 1 if (-x $DEREZ && $USESTRINGS == 0);

    if (defined($wlf) && -f $wlf && -r $wlf) {
        if ($wlf =~ /^(.*)$/) {
            $wlf = $1;
        } else {
            return $url;
        }
    } else {
        printError("Cannot read webloc file: '$wlf'");
        return $url;
    }
    
    # Open a pipe to use for DeRez (implicit fork)

    my $pid = open(FH,"-|");
    
    # Check if open/fork worked

    if (!defined($pid)) {
        printError("Cannot fork()");
        return $url;
    }

    # If pid is 0, this is the child, exec the cmd 

    if ($pid == 0) {
        if ($haveDeRez == 1) {
            exec($DEREZ, '-e', $wlf, '-only', "'url '");
        } else {
            $filePath = $wlf . $RSRC_PATH;
            if (-r $filePath) {
                exec($STRINGS, $wlf . $RSRC_PATH);
            }
        }
        exit(127);
    } 
    
    # This is the parent
    #
    # If we have DeRez then look for the url in a c-style
    # comment. Otherwise use strings to look at the resource 
    # fork
    
    if ($haveDeRez == 1) {
        while (<FH>) {
            next unless (/\/\*/);
            @parts = split;
            $url .= "$parts[$#parts-1]"
                if (defined($parts[$#parts-1]));
        }
    } else {
        while (<FH>) {

            # xml format .webloc

            if (/^TEXT/)
            {
                $xmlformat = 1;
                next;
            }
            
            if ($xmlformat == 1) {
                next unless (/^9/);
                chomp();
                s/^9//;
                $url = $_;
                last;
            }

            # traditional format .webloc file

            next unless (/^\;/);
            chomp();
            s/^\;//;
            $url = $_;
            last;
        }
    }

    close(FH);

    return $url;
}

# createInternetShortcut - creates an internet shortcut file

sub createInternetShortcut
{
    my $url = shift @_;
    return -1 unless (defined($url) && $url ne "");

    my $file = shift @_;
    return -1 unless (defined($file) && $file ne "");

    if (-f $file || -r $file) {
        printError("Outfile file already exists: '$file'");
        return -1;
    }

    if ($file =~ /^(.*)$/) {
        $file = $1;
    } else {
        return -1;
    }

    if (open(OUTFILE,">$file")) {
        print OUTFILE "[InternetShortcut]\r\nURL=$url\r\n";
        close(OUTFILE);
    } else {
        return -1;
    }
    
    return 0;
}

# deleteWebloc - delete the webloc file

sub deleteWebloc
{
    my $file = shift @_;
    return -1 unless (defined($file) && -f $file);

    if ($file =~ /^(.*)$/) {
        $file = $1;
    } else {
        return -1;
    }

    return (unlink($file) != 1 ? -1 : 0)
}

# printError - format and print an error message

sub printError
{
    print STDERR "ERROR: @_\n";
}

# printUsage - print the usage statement

sub printUsage
{
    print STDERR "$PGMINFO{'NAME'} [-dhnqsv] [-o dir] files\n"
}

# printVersion - print the version number

sub printVersion
{
    print "$PGMINFO{'NAME'} version $PGMINFO{'VERSION'}\n";
}
