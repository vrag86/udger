#!/usr/bin/env perl 
#===============================================================================
#
#         FILE: tests_udger.pl
#
#        USAGE: ./tests_udger.pl  
#
#  DESCRIPTION: 
#
#      OPTIONS: ---
# REQUIREMENTS: ---
#         BUGS: ---
#        NOTES: ---
#       AUTHOR: YOUR NAME (), 
# ORGANIZATION: 
#      VERSION: 1.0
#      CREATED: 13.03.2016 19:10:43
#     REVISION: ---
#===============================================================================

use strict;
use warnings;
use utf8;
use open qw(:std :utf8);
use FindBin qw '$Bin';
use Test::More qw 'no_plan';
my $SQLITE 		= '/home/anna/Downloads/udgerdb.dat';
my $SQLITE_v3 	= '/home/anna/Downloads/udgerdb_v3.dat';
my $ua = 'Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:43.0) Gecko/20100101 Firefox/43.0';
my $ip = '1.0.137.64';

require_ok ('Udger');

my $u = Udger->new(-sqlite => $SQLITE, -sqlite_v3 => $SQLITE_v3);
isa_ok ($u, 'Udger');

ok ($u->parse_ua($ua, -parse_fragments => 1) or die $u->errstr());
ok ($u->parse_ip($ip) or die $u->errstr());
ok ($u->print());



