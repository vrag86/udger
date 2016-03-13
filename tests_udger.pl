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
my $SQLITE = '/tmp/udgercache/udgerdb.dat';

require_ok ('Udger');

my $u = Udger->new(-sqlite => $SQLITE);
isa_ok ($u, 'Udger');




