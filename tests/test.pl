#!/usr/bin/perl
use SAPXML;
use Data::Dumper;
my $valid = SAPXML->get_products_for_media("/data/SAP_INST/2");
print Dumper($valid);

