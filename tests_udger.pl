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
my $SQLITE = '/home/anna/Downloads/udgerdb.dat';
my $ua = 'Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:43.0) Gecko/20100101 Firefox/43.0';

require_ok ('Udger');

my $u = Udger->new(-sqlite => $SQLITE);
isa_ok ($u, 'Udger');

ok ($u->parse($ua));



