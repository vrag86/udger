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
use DBI;
use Carp qw/croak/;
use Data::Printer;


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
    $self->{resources_url} = 'https://udger.com/resources/ua-list/';
	$self->{error} = {};

	bless $self, $class;
	return $self;
}


sub db_connect {
	my $fname = shift;
	my $dbh = DBI->connect("dbi:SQLite:dbname=$fname") or return;
	return $dbh;
}


sub parse {
	my $self 			= shift;
	$self->{ua} 		= shift || do {$self->error('Error parse: You must specify useragent $self->parse(\'UserAgent\')'); return};

	my %data;
	$data{"type"}             = "unknown";
	$data{"ua_name"}          = "unknown";
	$data{"ua_ver"}           = "";
	$data{"ua_family"}        = "unknown";
	$data{"ua_url"}           = "unknown";
	$data{"ua_company"}       = "unknown";
	$data{"ua_company_url"}   = "unknown";
	$data{"ua_icon"}          = "unknown.png";
	$data{"ua_engine"}        = "n/a";
	$data{"ua_udger_url"}     = "";
	$data{"os_name"}          = "unknown";
	$data{"os_family"}        = "unknown";
	$data{"os_url"}           = "unknown";
	$data{"os_company"}       = "unknown";
	$data{"os_company_url"}   = "unknown";
	$data{"os_icon"}          = "unknown.png";
	$data{"os_udger_url"}     = "";
	$data{"device_name"}      = "Personal computer";
	$data{"device_icon"}      = "desktop.png";
	$data{"device_udger_url"} = $self->{resources_url}."device-detail?device=Personal%20computer";

	$self->parse_browser(\%data) or return;

}


sub parse_browser {
	my $self 				= shift;
	my $data 				= shift;
	my $ua					= $self->{ua} || return;
	my $dbh 				= $self->{dbh};
	$self->{browser_id} 	= undef;
	my $ua_ver;

	my $sth = $dbh->prepare(qq{SELECT browser, regstring FROM reg_browser ORDER by sequence ASC}) or do{$self->error("Error: " . $dbh->errstr); return};
	$sth->execute() or do{$self->error("Error: " . $dbh->errstr); return};
	while (my $r = $sth->fetchrow_hashref()) {
		if (my ($match, $mod) = $r->{regstring} =~ /\/(.+)\/(.*)/) {
			$mod = '' if not $mod;
			if ($ua =~ /(?$mod)$match/) {
				$self->{browser_id} 	= $r->{'browser'};
				$ua_ver = $1 || '';
				last;
			}	
		}
	}
	if (not $self->{browser_id}) {
		$self->error("Cant define browser_id");
		return;
	}
	
	#Get info from c_browser table
	$sth = $dbh->prepare(qq{SELECT type, name, engine, url, company, company_url, icon FROM c_browser WHERE id=$self->{browser_id}}) or do{$self->error("Error: " . $dbh->errstr); return};
	$sth->execute() or do{$self->error("Error: " . $dbh->errstr); return};
	if (my $r = $sth->fetchrow_hashref()) {
		$data->{'ua_name'} 			= $r->{'name'};
		$data->{'ua_name'} 			.= " " . $ua_ver if $ua_ver;
		$data->{'ua_ver'}			= $ua_ver;
		$data->{'ua_family'}		= $r->{'name'};
		$data->{'ua_url'}       	= $r->{'url'};
		$data->{'ua_company'}  		= $r->{'company'};
		$data->{'ua_company_url'}   = $r->{'company_url'};
		$data->{'ua_icon'}          = $r->{'icon'};
		$data->{'ua_engine'}        = $r->{'engine'};
		$data->{'ua_udger_url'}     = $self->{resources_url} . "browser-detail?browser=$r->{name}";

		#Get info from c_browser_type table
		$sth = $dbh->prepare(qq{SELECT name FROM c_browser_type WHERE type=$r->{type}}) or do{$self->error("Error: " . $dbh->errstr); return};
		$sth->execute() or do{$self->error("Error: " . $dbh->errstr); return};
		if (my $t = $sth->fetchrow_hashref()) {
			$data->{'type'}				= $t->{'name'};
		}
	}

	return 1;
}

sub error {
	my $self = shift;
	push @{$self->{error}}, @_;
	return 1;
}

sub errstr {
	my $self = shift;
	$self->{error} ? join("\n", @{$self->{error}}) : undef;
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
