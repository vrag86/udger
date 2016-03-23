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
use Digest::MD5 qw(md5_hex);

sub new {
	my ($class, %opt) 		= @_;
	my $self 				= {};
	$self->{dbh_main}		= $opt{-dbh} if $opt{-dbh};
	$self->{sqlite}			= $opt{-sqlite} if $opt{-sqlite};
	$self->{sqlite_v3}		= $opt{-sqlite_v3} if $opt{-sqlite_v3};
    $self->{resources_url} = 'https://udger.com/resources/ua-list/';
	$self->{error} = [];

	bless $self, $class;
	return $self;
}


sub db_connect {
	my $fname = shift;
	my $dbh = DBI->connect("dbi:SQLite:dbname=$fname") or return;
	return $dbh;
}


sub parse_ua {
	my $self 			= shift;
	$self->{ua} 		= shift || do {$self->error('Error parse: You must specify useragent $self->parse_ua(\'UserAgent\')'); return};
	my %opt				= @_;
	my $sqlite 			= $self->{sqlite} || $opt{-sqlite};

	if ($self->{dbh_main}) {
		$self->{dbh} = $self->{dbh_main};
	}
	else {
		if ($sqlite) {
			croak "Not exist sqlite file $sqlite" if not -e $sqlite;
			$self->{dbh} = db_connect( $sqlite ) or croak "Cant create connect to sqlite";
		}
		else {
			croak "You must specify -sqlite or -dbh";
		}
	}

	my %data;
	$self->{data} = \%data;

	$data{"type"}             	= "unknown";
	$data{"ua_name"}          	= "unknown";
	$data{"ua_ver"}           	= "";
	$data{"ua_family"}        	= "unknown";
	$data{"ua_url"}           	= "unknown";
	$data{"ua_company"}       	= "unknown";
	$data{"ua_company_url"}   	= "unknown";
	$data{"ua_icon"}          	= "unknown.png";
	$data{"ua_engine"}        	= "n/a";
	$data{"ua_udger_url"}     	= "";
	$data{"os_name"}          	= "unknown";
	$data{"os_family"}        	= "unknown";
	$data{"os_url"}           	= "unknown";
	$data{"os_company"}      	= "unknown";
	$data{"os_company_url"}  	= "unknown";
	$data{"os_icon"}         	= "unknown.png";
	$data{"os_udger_url"}  	  	= "";
	$data{"device_name"}      	= "Personal computer";
	$data{"device_icon"}      	= "desktop.png";
	$data{"device_udger_url"} 	= $self->{resources_url}."device-detail?device=Personal%20computer";
	$data{uptodate_controlled} 	= 'false';
	$data{uptodate_is} 			= 'false';
	$data{uptodate_ver}			= '';
	$data{uptodate_url}			= '';

	#Parsing data
	my $is_bot = $self->parse_bot(\%data) or return;
	return 1 if $is_bot == 1;

	$self->parse_browser(\%data) or return;
	$self->parse_os(\%data) or return;
	$self->parse_device(\%data) or return;
	$self->parse_uptodate(\%data);

	$self->{data}->{fragments} = {};
	$self->parse_fragments($self->{data}->{fragments})
		if $opt{-parse_fragments};

	return 1;

}


sub parse_bot {
	my $self 				= shift;
	my $data 				= shift;
	my $ua					= $self->{ua} || return;
	my $dbh 				= $self->{dbh};
	$self->{bot} 			= 0;

	my $md5 = md5_hex($ua);
	my $sth = $dbh->prepare(qq{SELECT name, family, url, company, url_company, icon FROM c_robots where md5='$md5'}) or do{$self->error("Error: " . $dbh->errstr); return};;
	$sth->execute() or do{$self->error("Error: " . $dbh->errstr); return};
	if (my $r = $sth->fetchrow_hashref()) {
		$data->{type}				= 'Robot';
		$data->{ua_name} 			= $r->{name};
		$data->{ua_family}			= $r->{family};
		$data->{ua_url}				= $r->{url};
		$data->{ua_company}			= $r->{company};
		$data->{ua_company_url}		= $r->{url_company};
		$data->{ua_icon}			= $r->{icon};
		$data->{ua_udger_url}		= $self->{resources_url} . "bot-detail?bot=$r->{family}";
		$data->{device_name}		= 'Other';
		$data->{device_icon}		= 'other.png';
		$data->{device_udger_url}	= $self->{resources_url} . "device-detail?device=Other";
		return 1;
	}

	return -1;
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
			$mod =~ s/ //g;
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
				$mod =~ s/ //g;
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
			$mod =~ s/ //g;
			if ($ua =~ /(?$mod)$match/) {
				$self->{device_id} = $r->{device};
				last;
			}
		}
	}

	if ($self->{device_id}) {
		my $sth = $dbh->prepare(qq{SELECT name, icon FROM c_device WHERE id=$self->{device_id}}) or do{$self->error("Error: ". $dbh->errstr); return};
		$sth->execute() or do{$self->error("Error: " . $dbh->errstr); return};
		if (my $r = $sth->fetchrow_hashref()) {
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
	my $ua					= $self->{ua} 			|| return;
	my $browser_id			= $self->{browser_id} 	|| return;

	my $fragments = get_fragments($ua);

	FRAGMENT:	foreach my $frag (@$fragments) {
#					print "Process fragment: $frag\n";

					my $sth = $dbh->prepare(qq{SELECT note, regstring, regstring2, regstring3, regstring3 FROM reg_fragment ORDER BY sequence ASC}) or do{$self->error("Error: ". $dbh->errstr); return};
					$sth->execute() or do{$self->error("Error: " . $dbh->errstr); return};
					while (my $r = $sth->fetchrow_hashref()) {
						if (my ($match, $mod) = $r->{regstring} =~ /\/(.+)\/(.*)/) {
							$mod = '' if not $mod;
							$mod =~ s/ //g;
							if (my @replace = $frag =~ /(?$mod)$match/) {
								my $note = $r->{note};
								#Заменим части, найденные в фрагменте
								$note =~ s/##(\d)##/$replace[$1-1]/g;
								$data->{'['.$frag.']'} = $note;
								next FRAGMENT;
							}
						}
					}
				}

	return 1;
}


sub get_fragments {
	my $ua = shift;
	my @fragments;

	if ($ua =~ s/(.+?\(.+?\))//) {
		my $frag = $1;
		#Удалим ненужные символы
		$frag =~ s/(\(|\)|;|\|)/ /g;
		$frag =~ s/  / /g;
		push @fragments, split / /, $frag;
	}

	#Вытащим значения в скобках, если такие есть
	while ($ua =~ s/ ?(\(.+?\)) ?//) {
		push @fragments, $1;
	}


	$ua =~ s/^ //g;
	$ua =~ s/ $//g;
	push @fragments, split / /, $ua;

	return \@fragments;

}



#*******************************************************************************************************
#
#
#					PARSE IP via v3 db
#
#*******************************************************************************************************
#


sub parse_ip {
	my $self 			= shift;
	$self->{ip} 		= shift || do {$self->error('Error parse: You must specify ip_address $self->parse_ip(\'8.8.8.8\')'); return};
	my %opt				= @_;
	my $sqlite 			= $self->{sqlite_v3} || $opt{-sqlite_v3};

	if ($self->{dbh_main}) {
		$self->{dbh} = $self->{dbh_main};
	}
	else {
		if ($sqlite) {
			croak "Not exist sqlite file $sqlite" if not -e $sqlite;
			$self->{dbh} = db_connect( $sqlite ) or croak "Cant create connect to sqlite_v3";
		}
		else {
			croak "You must specify -sqlite_v3 or -dbh";
		}
	}

	my %data;
	$self->{data}->{ip} = \%data;

	$data{"ip_last_seen"}      	= "";
	$data{"ip_hostname"}        = "";
	$data{"ip_country"}         = "";
	$data{"ip_country_code"}    = "";
	$data{"ip_city"}        	= "unknown";
	$data{"is_bot"}				= 0;
	foreach my $key (qw/ua_string name ver ver_major class_id last_seen respect_robotstxt family family_code family_homepage family_icon vendor vendor_code vendor_homepage/) {
		$data{$key} 			= '';
	}

	$self->get_ip_info (\%data) or return;
	$self->{crawler_id} = 16808;
	$self->get_crawler_info (\%data) or return;

	return 1;

}


sub get_ip_info
{
	my $self = shift;
	my $data = shift;
	my $ip = $self->{ip};
	my $dbh = $self->{dbh};
	
	my $sth = $dbh->prepare(qq{SELECT ip_last_seen, crawler_id, ip_hostname, ip_country, ip_city, ip_country_code FROM udger_ip_list WHERE ip='$ip'}) or do{$self->error("Error: ". $dbh->errstr); return};
	$sth->execute() or do{$self->error("Error: ". $dbh->errstr); return};

	if (my $r = $sth->fetchrow_hashref()) {
		$data->{is_bot} 				= 1;
		$self->{bot_v3} 					= 1;
		$data->{ip_last_seen}			= $r->{ip_last_seen};
		$self->{crawler_id}				= $r->{crawler_id};
		$data->{ip_hostname}			= $r->{ip_hostname};
		$data->{ip_country}				= $r->{ip_country};
		$data->{ip_city}				= $r->{ip_city};
		$data->{ip_country_code}		= $r->{ip_country_code};
	}

	return 1;
}


sub get_crawler_info
{
	my $self = shift;
	my $data = shift;
	my $ip = $self->{ip};
	my $dbh = $self->{dbh};
	my $crawler_id = $self->{crawler_id} or return 1;
	
	my $sth = $dbh->prepare(qq{SELECT ua_string, name, ver, ver_major, class_id, last_seen, respect_robotstxt, family, family_code, family_homepage, family_icon, vendor, vendor_code, vendor_homepage
															FROM udger_crawler_list WHERE id='$crawler_id'}) or do{$self->error("Error: ". $dbh->errstr); return};
	$sth->execute() or do{$self->error("Error: ". $dbh->errstr); return};

	if (my $r = $sth->fetchrow_hashref()) {
		foreach my $key (keys %$r) {
			$data->{$key}		= $r->{$key};
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

sub is_bot {
	my $self = shift;
	$self->{bot} ? 1 : undef;
}

sub is_bot_v3 {
	my $self = shift;
	$self->{bot_v3} ? 1 : undef;
}

sub data {
	my $self = shift;
	$self->{data} ? $self->{data} : undef;
}

sub print {
	my $self = shift;
	return if not $self->{data};
	foreach my $key (keys %{$self->{data}}) {
		print "\n$key ======> ";
		if (ref ($self->{data}->{$key}) =~ 'HASH') {
			foreach my $key2 (keys %{$self->{data}->{$key}}) {
				print "\n\t\t$key2 =====> $self->{data}->{$key}->{$key2}";
			}
		}
		else {
			print "$self->{data}->{$key}";
		}
	}
	return 1;
}

=pod

=encoding utf-8

=head1 Name
Udger - Perl agent string parser based on Udger https://udger.com/products/local_parser

=head1 SYNOPSIS
use Udger;
my $client = Udger->new(%opt);

$opt{-sqlite}	 	- 	Path to Sqlite3 udger db version 1 file
$opt{-sqlite_v3} 	- 	Path to Sqlite3 udger db version 3 file
$opt{-dbh}				Reference to dbh (DBI object) to database which contains udger DB

=head1 EXAMPLES
use Udger;
use Data::Printer;

my $ua = 'Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:43.0) Gecko/20100101 Firefox/43.0';
my $client = Udger->new(-sqlite => '/tmp/udgerdb.dat');

$client->parse_ua(ua) or die "Cant parse $ua " . $client->errstr;
my $data = $client->data();
p $data;  #Print $data hashref via Data::Printer

=head1 DESCRIPTION
$client = Udger->new(-sqlite => '/tmp/udgerdb.dat');

=over 4
=item $client->parse($ua, %opt)
Parse useragent string $ua. Return undef if error. Error message contain $client->errstr method
$opt{-parse_fragments} - Parsing fragments

=item $client->data()
Return $hashref to data or undef if error.

=item1 $client->is_bot()
Return 1 if bot, undef - otherwise

=cut


1;
