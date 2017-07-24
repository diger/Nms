#!/usr/bin/perl
use strict;
use warnings FATAL => 'all';

my $libpath;
our %conf;
BEGIN {
  use FindBin '$Bin';
  $libpath = $Bin . '/../';
}

use lib $libpath;
use lib $libpath . 'lib';
use lib $libpath . 'Abills/mysql';
use lib $libpath . 'Abills';

do $Bin . 'libexec/config.pl';

use Abills::Base qw/_bp parse_arguments in_array/;
use Abills::Misc;
use Abills::SQL;
use Nms;
use Admins;

my $db = Abills::SQL->connect($conf{dbtype}, $conf{dbhost}, $conf{dbname}, $conf{dbuser}, $conf{dbpasswd});
my $Admin = Admins->new($db, \%conf);
$Admin->info($conf{SYSTEM_ADMIN_ID}, { IP => '127.0.0.1' });
my $Nms = Nms->new( $db, $Admin, \%conf );

my $argv = parse_arguments(\@ARGV);

main();
exit 0;

#**********************************************************
=head2 main()

=cut
#**********************************************************
sub main {
	
	my $iana_data = '';
	my @iana_entries;
	my $iana_sysoid_addr = 'http://www.iana.org/assignments/enterprise-numbers';
	my $WGET = 'wget -qO-';
	if (-f '/usr/bin/fetch') {
		$WGET = '/usr/bin/fetch -q -o -';
	}
	$iana_data .= `$WGET $iana_sysoid_addr`;
	$iana_data =~ /\| \| \| \|/;
	$iana_data = $';
	$iana_data =~ s/\n+[ |\x0d]*/\n/g;
	$iana_data =~ s/\'/\"/g;
	$iana_data =~ s/\n*End of Document$//g;
	$iana_data =~ s/\n(\d+)\n/\n::=$1\n/g;
	@iana_entries = split /::=/, $iana_data;
    $db->{db}->{AutoCommit} = 0;
    $db->{TRANSACTION} = 1;
	foreach (@iana_entries) {
  		if(/^(\d+)\n([^\n]*)\n([^\n]*)\n([^\n]*)/) {
			print "$1 $2 \n" if $argv->{DEBUG};
			$Nms->vendor_add({
				ID      => $1,
				NAME    => $2,
			})
  		}
  	}
    $db->{db}->commit();
    $db->{db}->{AutoCommit} = 1;
	
	return 1;
}



