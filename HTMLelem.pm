package Nms::HTMLelem v0.0.1;

use strict;
use Abills::HTML;

use Exporter;
our @ISA    = qw/ Exporter /;
our @EXPORT = qw(
  label_w_txt
  table_header2
  make_tree
  oid_enums
  oid_conv
  flowchart
);

#**********************************************************

=head2 label_w_txt($label,$text,$attr); - return formated text with label

  Arguments:
    $label - text of label
    $text 
    $attr -
      CTRL - for form with input control
      COLOR - color of label
      ID - 
      TYPE -
      LCOL
      RCOL
      
  Returns:
    String with element

=cut

#**********************************************************
sub label_w_txt {
    my ( $label, $text, $attr ) = @_;
    my $html = Abills::HTML->new();
    my $class = ( $attr->{COLOR} ) ? "label-$attr->{COLOR}" : '';
    $class = ( $attr->{ICON} ) ? ' has-feedback' : '';
    my $flabel = $html->element(
        ( $attr->{INP} ) ? 'span' : 'label',
        $label,
        {
            class => 'control-label col-sm-' . ( $attr->{LCOL} || '2' ),
            for => $attr->{ID} || $label
        }
    );
    my %ex_attr = (
        class => ( $attr->{INP} ) ? 'form-control' : 'form-control-static',
        id   => $attr->{ID}   || $label,
        name => $attr->{ID}   || $label,
        type => $attr->{TYPE} || undef,
        placeholder => ( $attr->{HOLDER} ) ? $attr->{HOLDER} : undef
    );
    my @sels;
    if ( $attr->{SELECT} && ref( $attr->{SELECT} ) eq 'ARRAY' ) {

        foreach my $opt ( @{ $attr->{SELECT} } ) {
            my $op = $html->element( 'option', $opt, { value => $opt } );
            $op =~ s/<option /<option selected / if $text eq $opt;
            push @sels, $op;
        }
        $text = "@sels";
    }
    elsif ( $attr->{SELECT} && ref( $attr->{SELECT} ) eq 'HASH' ) {
        while ( my ( $key, $value ) = each( %{ $attr->{SELECT} } ) ) {
            my $op = $html->element( 'option', $value, { value => $key } );
            $op =~ s/<option /<option selected / if $text eq $key;
            push @sels, $op;
        }
        $text = "@sels";
    }
    $ex_attr{value} =
      ( $attr->{INP} && $attr->{INP} eq 'input' ) ? $text : undef;
    $text = ( !$attr->{INP} || $attr->{INP} ne 'input' ) ? $text : '';
    my $ftext =
      $html->element( ( $attr->{INP} ) ? $attr->{INP} : 'p', $text, \%ex_attr );
    $ftext .= $html->element(
        'span', undef,
        {
            id => $attr->{ID} || $label,
            class => $attr->{ICON} . ' form-control-feedback'
        }
    ) if $attr->{ICON};
    $ftext = $html->element( 'div', $ftext,
        { class => 'col-sm-' . ( $attr->{RCOL} || '3' ) . $class } );

    return $html->element(
        'div',
        $flabel . $ftext,
        { class => 'form-group' . $class }
    );
}

#**********************************************************

=head2 table_header2() - Table header function button

=cut

#**********************************************************
sub table_header2 {
    my ( $header_arr, $attr ) = @_;
    my $html   = Abills::HTML->new();
    my $active = '';
    my @navs;
    foreach my $elem ( @{$header_arr} ) {
        my $drop = ( $elem->[2] ) ? 'dropdown' : undef;
        my @dr_menu;
        my $lidr;
        if ( $elem->[2] && ref( $elem->[2] ) eq 'ARRAY' ) {
            $lidr = $html->element(
                'a',
                $elem->[0]
                  . $html->element( 'span', undef, { class => 'caret' } ),
                {
                    href          => '#',
                    class         => 'dropdown-toggle',
                    'data-toggle' => 'dropdown'
                }
            );
            foreach my $mn ( @{ $elem->[2] } ) {
                push @dr_menu,
                  $html->li(
                    $html->element( 'a', $mn->[0], { href => $mn->[1] } ) );
            }
            $lidr = $html->li(
                $lidr
                  . $html->element(
                    'ul', "@dr_menu", { class => 'dropdown-menu' }
                  ),
                { class => 'dropdown' }
            );
        }
        else {
            $lidr = $html->element(
                'a',
                $elem->[0],
                {
                    href          => $elem->[1],
                    'data-toggle' => ( $elem->[2] ) ? 'tab' : undef
                }
            );
        }
        push @navs, $html->li( $lidr, { class => $drop } );
    }

    return $html->element( 'ul', "@navs", { class => 'nav navbar-nav' } );
}

#**********************************************************

=head2 make_tree($attr) - Make different charts

   If given only one series and X_TEXT as YYYY-MM, will build columned compare chart

   Arguments:
     $attr
       DATA    - Data array of hashes
   Result:
     TRUE or FALSE

=cut

#**********************************************************
sub make_tree {
    my ( $attr, $id ) = @_;
    my $result = '';
    my $TREE_ID = ( !$id ) ? 'MY_TREE' : $id;
    my %all;

    $all{core}{themes} = ( { variant => 'medium', responsive => 'true' } )
      if !$attr->{core}->{themes};
    $all{plugins} = ( $attr->{plugins} ) ? $attr->{plugins} : 'search';
    $all{search} =
      ( $attr->{search} )
      ? $attr->{search}
      : ( { case_insensitive => 'true', show_only_matches => 'false' } );
    %all = ( %all, %$attr );
    my $DATA = JSON->new->indent->encode( \%all );
    $DATA =~ s/"false"/false/g;
    $DATA =~ s/"true"/true/g;
    $DATA =~ s/\"\*|\*\"/ /g;
    $DATA =~ s/"/'/g;

    $result .= qq{
    <link rel='stylesheet' href='/styles/lte_adm/plugins/jstree/themes/default/style.min.css' />
    <script type='text/javascript' src='/styles/lte_adm/plugins/jstree/jstree.min.js'></script>
    <div id=$TREE_ID></div>
  };
    $result .= qq(
    <script>
      jQuery('#$TREE_ID').jstree($DATA);
	  </script>
   );

    return $result;
}

#**********************************************************

=head2 oid_enums()

=cut

#**********************************************************
sub oid_enums {
    my ( $oid, $attr ) = @_;
    my %enums;
    my $str = '';
    foreach my $el ( keys %{ $SNMP::MIB{$oid}{enums} } ) {
        $enums{ $SNMP::MIB{$oid}{enums}{$el} } = $el;
    }
    if ($attr) {
        foreach my $key ( sort keys %enums ) {
            $str .= "$key = $enums{$key} </br>";
        }
        return $str;
    }

    return %enums;
}

#**********************************************************

=head2 oid_conv($attr) - conv oid to html link
 STR conv numerical oid to human

=cut

#**********************************************************
sub oid_conv {
    my ( $text, $attr ) = @_;
    my $html = Abills::HTML->new();
    if ( !$attr->{STR} ) {
        my $html_str = $html->element(
            'a',
            $SNMP::MIB{$text}{label},
            {
                title => $text,
                id    => 'trap',
                value => $attr->{VALUES}->{ID}
            }
        );
        return $html_str;
    }

    return $SNMP::MIB{$text}{label};
}

#**********************************************************

=head2 flowchart($attr) - Make flowchart

=cut

#**********************************************************
sub flowchart {
    my ( $oprs, $links, $attr ) = @_;
    my $html = Abills::HTML->new();
    my %all;
    $all{data}{operators} = $oprs;
    $all{data}{links}     = $links;
    $all{linkWidth} = 5 if !$attr->{linkWidth};
    %all = ( %all, %$attr );
    my $DATA = JSON->new->indent->encode( \%all );
    $DATA =~ s/"false"/false/g;
    $DATA =~ s/"true"/true/g;
    $DATA =~ s/\"\*|\*\"/ /g;
    my $scr = qq(
  <link rel='stylesheet' href='/styles/lte_adm/plugins/flowchart/jquery.flowchart.min.css' />
  <script type='text/javascript' src='/styles/lte_adm/plugins/flowchart/jquery.flowchart.min.js'></script>
  <div id='flow' style='position:unset;'>
  <script type="text/javascript">
      jQuery('#flow').flowchart($DATA);
  </script>
  );
    return $scr;
}

1;
