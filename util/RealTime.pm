#!perl

=head1 NAME

  Cable tester for NMS

=cut

use strict;
use warnings FATAL => 'all';
use Abills::Base qw(mk_unique_value);
use Dv;

our ( %lang, $Nms, $html, %conf, $admin, $db, %utils_menu, %actions );

my %snmpparms;
$snmpparms{Version} = 2;
$snmpparms{Retries} = 1;
$snmpparms{Timeout} = 2000000;

$utils_menu{RealTime} = (
    {
        user_menu => 'LIVE',
    }
);
$actions{'LIVE'} = (
    {
        user_act => \&live_stats,
    }
);
$FUNCTIONS_LIST{"31:0:Live:get_stats:PORT"} = 8;

#**********************************************************

=head2 get_stats()

=cut

#**********************************************************
sub get_stats {
    my ($attr) = @_;
    my @mibs;
    push @mibs,
      SNMP::Varbind->new( [ 'ifHCOutOctets', $attr->{PORT} || $FORM{PORT} ] );
    push @mibs,
      SNMP::Varbind->new( [ 'ifHCInOctets', $attr->{PORT} || $FORM{PORT} ] );

    my $vb   = SNMP::VarList->new(@mibs);
    my $sess = SNMP::Session->new(
        %snmpparms,
        Community => $conf{NMS_COMMUNITY_RO},
        DestHost  => $attr->{IP} || $FORM{IP},
    );

    $sess->get($vb);

    my %result;

    foreach my $val (@$vb) {
        $result{ $val->[0] } = $val->[2];
    }

    $html->{JSON_OUTPUT} = JSON->new->indent->encode( \%result );
    print $html->{JSON_OUTPUT} if $FORM{json};

    return \@$vb;
}

#**********************************************************

=head2 live_stats()

=cut

#**********************************************************
sub live_stats {
    my ($attr) = @_;

    my $curr = get_stats(
        {
            PORT => $attr->{PORT},
            IP   => $attr->{IP}
        }
    );

    my $ctime = time;
    my @params;
    foreach my $key (@$curr) {
        push @params, $key->[0];
    }

    print $html->make_charts3(
        "$lang{PORT} $attr->{PORT}",
        'Line',
        {
            data      => '',
            ykeys     => \@params,
            xkey      => 'y',
            labels    => \@params,
            element   => $attr->{PORT},
            postUnits => 'Mb/s',
            hideHover => 'auto',
            resize    => 'true'
        }
    );
    print qq(
    <script>
    var interval = 5000;
    var link = '?get_index=get_stats&header=2&json=1&PORT=$attr->{PORT}&IP=$attr->{IP}';
    jQuery(document).ready(function() {
      var chartData = [];
      jQuery.getJSON(link, function(preData) {
        //console.log(preData);
        setInterval(function() {
          jQuery.getJSON(link, function(results) {
              for (var item in results) {
                odds = (results[item] - preData[item]) / (interval / 1000) / 1048576 * 8 ;
                preData[item] = results[item];
                chartData.push({
                  [item]: odds.toFixed(2),
                  'y': Date.now()
                });
              };
              while ( chartData.length > 40 ) {
                 chartData.shift();
              }
              chart.setData(chartData);
              //console.log(chartData);
          });
        }, interval);
      });
    });
    </script>
    );

    return 1;
}

1;
