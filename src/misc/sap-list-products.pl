#!/usr/bin/perl
use XML::LibXML;
use Data::Dumper;
use strict;
my $TYPE = shift;
my $DB   = shift;
my @FILTER = ();
my %PRODUCTS = ();
my $x = XML::LibXML->new();
my $d = $x->parse_file('sap-installation-wizard.xml');
foreach my $node ($d->findnodes('//listentry')){
    my $f  = "";
    my $n  = "";
    my $ok = 0;
    foreach my $c ( $node->getChildNodes )
    {
      $f = $c->string_value if( 'search' eq $c->getName );
      $n = $c->string_value if( 'name'   eq $c->getName );
      $ok = 1 if( 'type' eq $c->getName and $c->string_value eq $TYPE );
    }
    push @FILTER, [ $n, $f ] if( $ok )
}

my %products = ();
my @NODES = ();
$d = $x->parse_file('product.catalog');
foreach my $tmp ( @FILTER )
{
   my $name    = $tmp->[0];
   my $xmlpath = $tmp->[1];
   $xmlpath =~ s/##DB##/$DB/;
   foreach my $node ($d->findnodes($xmlpath))
   {
      push @NODES, [ $name , $node ];
   }
}

foreach my $tmp( @NODES )
{
   my $name = $tmp->[0];
   my $node = $tmp->[1];
   my $gname = "";
   my $lname = "";
   #Get ID
   my $id = $node->getAttribute('id');
   #Get Local Name
   foreach my $c ( $node->getChildNodes )
   {
      $lname = $c->string_value if( 'display-name' eq $c->getName );
   }
   #Get Global Name
   $id =~ /.*:(.*)\.$DB\./;
   my $od = $1;
   $od =~ s#\.#/#;
   my @n = $d->findnodes('//components[@output-dir="'.$od.'"]/display-name');
   $gname = scalar @n ? $n[0]->string_value : $lname ;
   $PRODUCTS{$name." ".$gname} = $id;
}

foreach my $name ( sort keys %PRODUCTS )
{
   print $name." ".$PRODUCTS{$name}."\n";
}
