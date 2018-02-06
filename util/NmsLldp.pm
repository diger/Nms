#!perl

=head1 NAME

  Lldp for NMS

=cut

use strict;
use warnings FATAL => 'all';
use Nms::db::Lldp;
use Nms::HTMLelem qw(oid_enums oid_conv);

our(
  %lang,
  $Nms,
  $html,
  %conf,
  $admin,
  $db
);

my $Lldp = Lldp->new( $db, $admin, \%conf );
SNMP::addMibDirs( '../../var/snmp/mibs' );
SNMP::addMibDirs( '../../var/snmp/mibs/private' );
SNMP::initMib();

#**********************************************************
=head2 neighbors()

=cut
#**********************************************************
sub neighbors {
  my ($attr) = @_;
 
  return 1;
}



1;