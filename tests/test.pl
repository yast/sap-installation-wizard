#!/usr/bin/perl

use SAPXML;
use Data::Dumper;
use strict;
my $sapInstEnv = shift;
my $products = SAPXML->get_products_for_media($sapInstEnv);
print Dumper($products);


