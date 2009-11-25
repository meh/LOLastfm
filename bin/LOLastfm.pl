#! /usr/bin/perl
use strict;
use warnings;
use Getopt::Std;
use XML::Simple qw(:strict);
use Net::LastFM::Submission;

my %options;
getopts('p:f:h', \%options);

if ($options{h}) {
    print usage();
    exit(0);
}

my $Config = XMLin($options{f} || '/etc/LOLastfm.xml', KeyAttr => 1, ForceArray => 1);

my $Player = $options{p} || $Config->{player}[0];

print $Player, "\n";

sub usage {
    return << "USAGE";
Usage: LOLlastfm [options]

-h        : show this help.
-f file   : use the given file as config file
-p player : use the passed player as scrobbling one
USAGE
}
