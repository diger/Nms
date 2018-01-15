package Nms::HTMLelem v0.0.1;

use strict;
use Abills::HTML;

use Exporter;
our @ISA    = qw/ Exporter /;
our @EXPORT = qw(
label_w_txt
table_header2
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
	my ($label,$text,$attr) = @_;
  my $html = Abills::HTML->new();
	my $class = ($attr->{COLOR}) ? "label-$attr->{COLOR}" : '' ;
  $class = ($attr->{ICON})? ' has-feedback' : '' ;
  my $flabel =  $html->element(($attr->{INP})? 'span' : 'label', $label, {
    class => 'control-label col-sm-' . ($attr->{LCOL}||'2'),
    for => $attr->{ID} || $label
  });
  my %ex_attr = (
    class => ($attr->{INP})?'form-control':'form-control-static',
    id => $attr->{ID} || $label,
    name => $attr->{ID} || $label,
    type => $attr->{TYPE} || undef,
    placeholder => ($attr->{HOLDER})? $attr->{HOLDER} : undef
  );
  my @sels;
  if ($attr->{SELECT} && ref($attr->{SELECT}) eq 'ARRAY'){
    foreach my $opt (@{$attr->{SELECT}}){
      my $op = $html->element('option', $opt, { value => $opt});
      $op =~ s/<option /<option selected / if $text eq $opt ;
      push @sels, $op
    }
    $text = "@sels";
  }
  elsif ($attr->{SELECT} && ref($attr->{SELECT}) eq 'HASH') {
    while ( my ($key, $value) = each (%{$attr->{SELECT}}) ){
      my $op = $html->element('option', $value, { value => $key});
      $op =~ s/<option /<option selected / if $text eq $key ;
      push @sels, $op
    }
    $text = "@sels";
  }
  $ex_attr{value} = ($attr->{INP} && $attr->{INP} eq 'input')? $text : undef;
  $text = (!$attr->{INP} || $attr->{INP} ne 'input')? $text : '';
  my $ftext =  $html->element(($attr->{INP})?$attr->{INP}:'p', $text, \%ex_attr);
  $ftext .= $html->element('span', undef,
    {
      id    => $attr->{ID} || $label,
      class => $attr->{ICON} . ' form-control-feedback'
    }) if $attr->{ICON};
  $ftext = $html->element('div', $ftext, { class => 'col-sm-' . ($attr->{RCOL}||'3') . $class });
	
	return $html->element('div', $flabel.$ftext, { class => 'form-group' . $class });
}

#**********************************************************
=head2 table_header2() - Table header function button

=cut
#**********************************************************
sub table_header2 {
  my ($header_arr, $attr) = @_;
  my $html = Abills::HTML->new();
  my $active = '';
  my @navs;
  foreach my $elem ( @{ $header_arr } ) {
    my $drop = ($elem->[2])? 'dropdown':undef;
    my @dr_menu;
    my $lidr;
    if ($elem->[2]){
      $lidr = $html->element('a', $elem->[0].$html->element('span',undef,{ class=>'caret'}), {
        href          => '#',
        class         => 'dropdown-toggle',
        'data-toggle' => 'dropdown'
      });
      foreach my $mn ( @{$elem->[2]} ) {
        push @dr_menu, $html->li($html->element('a', $mn->[0],{href=>$mn->[1]}));
      }
      $lidr = $html->li($lidr . $html->element('ul', "@dr_menu", { class => 'dropdown-menu'}), { class => 'dropdown' });
    }
    else {
      $lidr = $html->element('a', $elem->[0],{href=>$elem->[1]});
    }
    push @navs, $html->li($lidr, { class => $drop });
  }

  return $html->element('ul', "@navs", { class => 'nav navbar-nav' })
}

1;