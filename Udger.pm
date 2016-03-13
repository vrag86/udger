#
#===============================================================================
#
#         FILE: Udger.pm
#
#  DESCRIPTION: 
#
#        FILES: ---
#         BUGS: ---
#        NOTES: ---
#       AUTHOR: YOUR NAME (), 
# ORGANIZATION: 
#      VERSION: 1.0
#      CREATED: 13.03.2016 18:46:48
#     REVISION: ---
#===============================================================================
package Udger;

use strict;
use warnings;
use utf8;
use open qw(:std :utf8);
use Log::Any qw($log);
use Log::Any::Adapter ('Stdout');
use DBI;
use Carp qw/croak/;


sub new {
	my ($class, %opt) = @_;
	my $self = {};
	$self->{dbh} = $opt{-dbh} if $opt{-dbh};
	if ($opt{-sqlite}) {
		croak "Not exist sqlite file $opt{-sqlite}" if not -e $opt{-sqlite};
		$self->{dbh} = db_connect( $opt{-sqlite} ) or croak "Cant create connect to sqlite";
	}

	croak "You must specify -sqlite => <path to sqlite fname> or -dbh => ref to dbh connection" 
		if not $self->{dbh};

	bless $self, $class;
	return $self;
}


sub db_connect {
	my $fname = shift;
	my $dbh = DBI->connect("dbi:SQLite:dbname=$fname") or return;
	return 1;
}


=pod

=encoding utf-8

=head1 Name
Udger - Perl agent string parser based on Udger https://udger.com/products/local_parser

=head1 SYNOPSIS
use Udger;
my $client = Udger->new(%opt);

$opt{-sqlite} - 	Path to Sqlite3 udger file
$opt{-dbh}			Reference to dbh (DBI object) to database which contains udger DB
=cut

1;
