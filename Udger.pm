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
	my %opt				= @_;

	my %data;
	$self->{data} = \%data;

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

	#Parsing data
	$self->parse_browser(\%data) or return;
	$self->parse_os(\%data) or return;
	$self->parse_device(\%data) or return;
	$self->parse_uptodate(\%data);

	$self->parse_fragments(%data)
		if $opt{-parse_fragments};

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
		print("Cant define browser_id");
		return -1;
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


sub parse_os {
	my $self 				= shift;
	my $data 				= shift;
	my $dbh 				= $self->{dbh};
	my $ua					= $self->{ua} 			|| return;
	my $browser_id 			= $self->{browser_id};
	$self->{os_id}			= undef;

	if ($browser_id) {
		my $sth = $dbh->prepare(qq{SELECT os FROM c_browser_os WHERE browser=$browser_id}) or do{$self->error("Error: ". $dbh->errstr); return};
		$sth->execute() or do{$self->error("Error: " . $dbh->errstr); return};
		if (my $r = $sth->fetchrow_hashref()) {
			$self->{os_id}	= $r->{os};
		}
	}

	if (not $self->{os_id}) {
		#Найдем os_id по регулярке
		my $sth = $dbh->prepare(qq{SELECT os, regstring FROM reg_os ORDER BY sequence ASC}) or do{$self->error("Error: ". $dbh->errstr); return};
		$sth->execute() or do{$self->error("Error: " . $dbh->errstr); return};
		while (my $r = $sth->fetchrow_hashref()) {
			if (my ($match, $mod) = $r->{regstring} =~ /\/(.+)\/(.*)/) {
				$mod = '' if not $mod;
				if ($ua =~ /(?$mod)$match/) {
					$self->{os_id} = $r->{os};
					last;
				}
			}
		}
	}

	if ($self->{os_id}) {
		my $sth = $dbh->prepare(qq{SELECT name, family, url, company, company_url, icon FROM c_os WHERE id=$self->{os_id}}) or do{$self->error("Error: ". $dbh->errstr); return};
		$sth->execute() or do{$self->error("Error: " . $dbh->errstr); return};
		if (my $r = $sth->fetchrow_hashref()) {
			$data->{os_name}			= $r->{name};
			$data->{os_family}			= $r->{family};
			$data->{os_url}				= $r->{url};
			$data->{os_company}			= $r->{company};
			$data->{os_company_url}		= $r->{company_url};
			$data->{os_icon}			= $r->{icon};
			$data->{os_udger_url}		= $self->{resources_url} . "os-detail?os=$r->{name}";
		}
	}
	

	return 1;
}


sub parse_device {
	my $self 				= shift;
	my $data 				= shift;
	my $dbh 				= $self->{dbh};
	my $ua					= $self->{ua} 			|| return;
	$self->{device_id}		= undef;

	my $sth = $dbh->prepare(qq{SELECT device, regstring FROM reg_device ORDER BY sequence ASC}) or do{$self->error("Error: ". $dbh->errstr); return};
	$sth->execute() or do{$self->error("Error: " . $dbh->errstr); return};
	while (my $r = $sth->fetchrow_hashref()) {
		if (my ($match, $mod) = $r->{regstring} =~ /\/(.+)\/(.*)/) {
			$mod = '' if not $mod;
			if ($ua =~ /(?$mod)$match/) {
				$self->{device_id} = $r->devices;
				last;
			}
		}
	}

	if ($self->{device_id}) {
		my $sth = $dbh->prepare(qq{SELECT name, icon FROM c_device WHERE id=$self->{device_id}}) or do{$self->error("Error: ". $dbh->errstr); return};
		$sth->execute() or do{$self->error("Error: " . $dbh->errstr); return};
		if (my $r = fetchrow_hashref()) {
			$data->{device_name}			= $r->{name};
			$data->{device_icon}			= $r->{icon};
			$data->{device_udger_url}		= $self->{resources_url} . "device-detail?device=$r->{name}";

		}
	}
	elsif ($data->{type} eq 'Mobile Browser') {
		$data->{device_name} 		= 'Smartphone';
		$data->{device_icon}		= 'phone.png';
		$data->{device_udger_url}	= $self->{resources_url} . "device-detail?device=Smartphone";
	}
	elsif ($data->{type} eq 'Library' || $data->{type} eq 'Validator' || $data->{type} eq 'Other' || $data->{type} eq 'Useragent Anonymizer') {
		$data->{device_name}		= 'Other';
		$data->{device_icon}		= 'other.png';
		$data->{device_udger_url}	= $self->{resources_url} . "device-detail?device=Other";
	}

	return 1;
}


sub parse_uptodate {
	my $self 				= shift;
	my $data 				= shift;
	my $dbh 				= $self->{dbh};
	my $browser_id			= $self->{browser_id} || return;

	my ($ver_major) = $data->{ua_ver} =~ /(.+?)\./;
	my $sth = $dbh->prepare(qq{SELECT ver, url FROM c_browser_uptodate WHERE browser_id=$browser_id AND (os_independent = 1 OR os_family='$data->{os_family}')}) or do{$self->error("Error: ". $dbh->errstr); return};
	$sth->execute() or do{$self->error("Error: " . $dbh->errstr); return};
	if (my $r = $sth->fetchrow_hashref()) {
		$data->{uptodate_controlled} 	= 'true';
		$data->{uptodate_is} 			= $ver_major >= $r->{ver} ? 'true' : 'false';
		$data->{uptodate_ver}			= $r->{ver};
		$data->{uptodate_url}			= $r->{url};
	}

	return 1;
}


sub parse_fragments {
	my $self 				= shift;
	my $data 				= shift;
	my $dbh 				= $self->{dbh};
	my $browser_id			= $self->{browser_id} || return;

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

sub data {
	my $self = shift;
	$self->{data} ? $self->{data} : undef;
}

sub print {
	my $self = shift;
	$self->{data} ? p $self->{data} : undef;
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

=head1 EXAMPLES
use Udger;
use Data::Printer;

my $ua = 'Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:43.0) Gecko/20100101 Firefox/43.0';
my $client = Udger->new(-sqlite => '/tmp/udgerdb.dat');

$client->parse(ua) or die "Cant parse $ua " . $client->errstr;
my $data = $client->data();
p $data;  #Print $data hashref via Data::Printer

=head1 DESCRIPTION
$client = Udger->new(-sqlite => '/tmp/udgerdb.dat');

=over 4
=item $client->parse($ua, %opt)
Parse useragent string $ua. Return undef if error. Error message contain $client->errstr method
$opt{-parse_fragments} - Parsing fragments

=item $client->print()
Print data to screen. Return undef if error.

=item $client->data()
Return $hashref to data or undef if error.

=cut


1;
