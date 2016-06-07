package SAPXML;

use 5.000000;
use strict;
use warnings;


use Fatal qw(:void open opendir chdir rename); 
use XML::LibXML;
use File::Basename;
#use Data::Dumper;
use YaST::YCP qw(:LOGGING Boolean sformat);
use Cwd;

require Exporter;

#use AutoLoader qw(AUTOLOAD);

our @ISA = qw(Exporter AutoLoader);


# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration        use SAPXML ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
#our %EXPORT_TAGS = ( 'all' => [ qw(
#        
#) ] );

#our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw( 
find_local_IM
is_instmaster
get_sapinst_version
get_sapinst_path
get_nw_products
get_products_for_media
set_sapinst_feature
products_on_instmaster
search_labelfiles
read_labelfile
compare_label
label_match
check_media
collect_labels_for_product
search_sapinst_id
type_of_product
);

our $VERSION = '0.08';

# for YCP
# ["function", return_TYPEINFO, argument0_TYPEINFO, argument1_TYPEINFO, ...]
our %TYPEINFO;

my $DEBUG=1;

my $PLATFORM = "LINUX";
my $ARCH     = `arch`; $ARCH=uc($ARCH); chomp($ARCH);
my @STANDALONE = ("TREX","GATEWAY","WEBDISPATCHER");
my @DATABASES  = ("ORA","SYB","DB2","HDB","MAX");
my %DBMAP      = ( 
			"ORA" => "ORA",
			"SYB" => "SYB",
			"DB2" => "DB6",
			"HDB" => "HDB",
			"MAX" => "ADA"
		);

####################################################################
# find_local_IM
# #
# # in  - start directory for label search ($PROD_PATH)
#         tmpTargetDir = /data/SAP_CDs
#         prodCount    = e.g 4
#         instMasterDir= Instmaster
#
# # out - list of path to alternative local installmaster
# #
BEGIN { $TYPEINFO{find_local_IM} = ["function", ["list", "string"], "string", "integer","string"]; }
sub find_local_IM {
   my $self         = shift;
   my $tmpTargetDir = shift; 
   my $prodCount    = shift;
   my $instMasterDir= shift; 

   my @list = ();
   logger("In find_local_IM") if ($DEBUG);

   my $CUR_IM_LABEL = _read_labelfile("$tmpTargetDir/$prodCount/$instMasterDir/LABEL.ASC");

   for (my $i = 0; $i < $prodCount; $i++) {
      my $IM_LABEL = _read_labelfile("$tmpTargetDir/$i/$instMasterDir/LABEL.ASC");
      logger("Try local Instmaster dir:$tmpTargetDir/$i/$instMasterDir") if ($DEBUG);

      if( $IM_LABEL eq $CUR_IM_LABEL ) {
         logger("Similar local Instmaster found at:$tmpTargetDir/$i/$instMasterDir") if ($DEBUG);
         push @list, "$tmpTargetDir/$i";
      }
   }
   return \@list;
}

####################################################################
# is_instmaster
# #
# # in  - start directory for label search ($PROD_PATH)
# # out - type of instmaster and path to installmaster
# #
# # example Label file ..../IM_LINUX_X86_64/LABEL.ASC
# #         data       SAP:WEBAS:7.00:SAPINST:*:LINUX_X86_64:*
# # new SWPM Label file
# #         data       "IND:SLTOOLSET:1.0:SWPM:*:LINUX_X86_64:*"
# #
# # or (unextracted)
# #
# #         data       "SAP:ROOT-LABEL-DVD-SWPM:720-2:IM-CD:*:AIX_PPC64 LINUX_I386 HPUX_IA64 OS390_32 OS400_PPC64 LINUX_S390X_64 LINUX_IA64 LINUX_PPC64 HPUX_PARISC SOLARIS_SPARC SOLARIS_X86_64 WINDOWS_I386 LINUX_X86_64 WINDOWS_X86_64 WINDOWS_IA64:*"
# #
BEGIN { $TYPEINFO{is_instmaster} = ["function", ["list", "string"], "string"]; }
sub is_instmaster {
   my $self = shift;
   my $prod_path = shift;
   my $FILE;

   my @instmaster;
   logger("in Function: is_instmaster") if ($DEBUG);
   logger("in Function: is_instmaster, prod_path='$prod_path'") if ($DEBUG);

   foreach my $label_file( search_labelfiles($prod_path) ){
      logger(" Checking Labelfile: $label_file") if ($DEBUG);
      my @filepath = split("/", $label_file);
      open ($FILE, $label_file);         
         while (<$FILE>) {
            chomp;
            my @fields = split(":");
            if ($filepath[-1] eq "info.txt") {
               @fields = split(" ");
            }
            # the HANA DVD includes a subcomponent with sapinst, so we must make sure that
            # HANA DB server component is found first!!
            if ($fields[1] eq "HANA ENTERPRISE" ) {
               #HDB:HANA ENTERPRISE:1.0:LINUXX86_64:media delivery SAP High-Performance Analytic Appliance Enterprise 1.0::D51041779
               $instmaster[0] = "HANA";
               $instmaster[1] = dirname($label_file);
               last;
            }elsif ($fields[0] eq "B1AH" or $fields[0] eq "B1A" or $fields[0] eq "B1H") {
               #B1AH 1.0.2.147
               #B1A 1.0.5.374
               $instmaster[0] = $fields[0];
               $instmaster[1] = dirname($label_file);
               last;
            # TODO - mehrstufiger Ansatz, da SWPM ungeschickterweise gepackt (SAPCAR) ist...
            # Erst globales Medium mit mehreren SWPM Plattformen und gepacktem SWPM.SAR erkennen
            # Dann auspacken und nochmals pruefen auf "SLTOOLSET"
            # ...
            }elsif ($fields[1] eq "SLTOOLSET" && ($fields[5] eq $PLATFORM."_".$ARCH || $fields[5] eq "*")) {
               # Erster Versuch: SWPM ist bereits entpackt
               #LABEL.ASC: IND:SLTOOLSET:1.0:SWPM:*:LINUX_X86_64:*
               $instmaster[0] = "SAPINST";
               $instmaster[1] = dirname($label_file);
	       $instmaster[2] = $fields[3];
               last;
            }elsif ($fields[3] eq "SAPINST" && ($fields[5] eq $PLATFORM."_".$ARCH || $fields[5] eq "*")) {
               #SAP:WEBAS:7.00:SAPINST:*:LINUX_X86_64:*
               $instmaster[0] = "SAPINST";
               $instmaster[1] = dirname($label_file);
	       $instmaster[2] = "NW70";
               last;
            }elsif ($fields[1] eq "BusinessObjects" ) {
               #SAP:BusinessObjects:3.1:BestPractices
               #SAP:BusinessObjects:3.1:BOE
               $instmaster[0] = "BOBJ";
               $instmaster[1] = dirname($label_file);
               last;
            }elsif ($fields[1] eq "ROOT-LABEL-DVD-SWPM" && ($fields[5] =~ $PLATFORM."_".$ARCH || $fields[5] eq "*")) { # TODO fields[1] ggf. verallgemeinern auf "*SWPM*" ?
               # Zweiter Versuch, SWPM ist noch nicht entpackt
               #LABEL.ASC: SAP:ROOT-LABEL-DVD-SWPM:720-2:IM-CD:*:AIX_PPC64 LINUX_I386 HPUX_IA64 OS390_32 OS400_PPC64 LINUX_S390X_64 LINUX_IA64 LINUX_PPC64 HPUX_PARISC SOLARIS_SPARC SOLARIS_X86_64 WINDOWS_I386 LINUX_X86_64 WINDOWS_X86_64 WINDOWS_IA64:*

               my $LABEL_PATH=dirname($label_file);
               if ( $LABEL_PATH =~ /IM_${PLATFORM}_$ARCH/ ) { # Linux Instmaster gefunden "*IM_LINUX_X86_64*"
                   my $SAPCAR=`find '$LABEL_PATH' -iname SAPCAR\* -print -quit`; # First match counts, just in case...
                   chomp($SAPCAR);
                   if ( $SAPCAR eq "" ) { print "Please provide a matching SWPM medium, that contains a usable SAPCAR executable - or provide an extracted SWPM medium.\n" };
                   if ( ! -x $SAPCAR ) { print "Please provide a matching SWPM medium, that also contains an executable SAPCAR executable - or provide an extracted SWPM medium.\n" };

                   #my $SWPM_PATH=`find $LABEL_PATH -iname \*SWPM\*.sar -print -quit`; # Example "70SWPM10SP01_1.SAR" or "SWPM10SP01_1.SAR". First match counts, just in case...
                   my @SWPM_PATH=`find '$LABEL_PATH' -iname '\*SWPM\*.sar'`; # Example "70SWPM10SP01_1.SAR" and/or "SWPM10SP01_1.SAR". It looks as if we can simply copy both together, but some files seem to be overwritten.. 
                   chomp(@SWPM_PATH);
                   my $SWPM_TMP="/dev/shm/InstMaster_SWPM/";

                   if ( ! @SWPM_PATH ) { print "Please provide a matching SWPM medium, that contains a packed SWPM archive (\"*SWPM*.SAR\").\n"; last };
                   foreach my $SWPM_PATH (@SWPM_PATH) {
                   	if ( ! -r $SWPM_PATH ) { print "Please provide a medium with a readable SWPM archive (\"*SWPM*.SAR\").\n"; last };
			$SWPM_PATH =~ /.*\/(.*)\.sar/i;
			$SWPM_TMP  = "/dev/shm/InstMaster_SWPM/$1";
			if ( -d $SWPM_TMP ) {
				print "Warning: It looks as if multiple SWPM archives were found. Copying them into a single directory...\n";
			} else {
				mkdir($SWPM_TMP,0755);
			}
			logger("Extracting $SWPM_PATH into $SWPM_TMP");
                   	system ("${SAPCAR} -xf $SWPM_PATH -R $SWPM_TMP/"); # TODO correctly remove /dev/shm/InstMaster_SWPM afterwards
		   }
		   $instmaster[0] = "SAPINST";
		   $instmaster[1] = "/dev/shm/InstMaster_SWPM/";
		   $instmaster[2] = "MULTISWPM";
                   last;
               } else {
                   print "Could not determine the Instmaster's platform / architecture. I am looking for a pathname containing the string \"IM_${PLATFORM}_$ARCH\". Found ${LABEL_PATH}. \nPlease change the pathname accordingly if you think this medium should be the correct one - or better provide an already extracted SWPM medium.\n"
               }
            }
         }
         close ($FILE);
         last if @instmaster;
   }
   return \@instmaster;
}

####################################################################
# get_sapinst_version
#
#  in  :  path to instmaster
#  out :  sapinst version 
# 
# we get two types of output from sapinst
# 1) [==============================] - extracting...  done!
#    SAPinst build information:
#    --------------------------
#    abi version : 721
#    make variant: 720_REL
#    build       : 1110735
#    compile time: Nov 11 2009 06:34:30
#
# 2) [==============================] - extracting...  done!
#    This is SAPinst, version 701, make variant 700_REL, build 967243
#    compiled on Mar  6 2008, 21:44:08
#
#    done!
#
BEGIN { $TYPEINFO{get_sapinst_version} = ["function", "integer", "string"]; }
sub get_sapinst_version {

   my $self = shift;
   my $prod_path = shift;

   my $ver = 0;

   open(CMD,"$prod_path/sapinst -buildtime |") || return -1;
   while ( <CMD> )
   {
      chomp;
      # we need only the part with "make variant"
      if (/make variant/) {
         my @values = split(',', $_);
         foreach my $val (@values) {
             if ( $val =~ /make variant/) {
                $val =~ s/(.*)(\d\d\d)(.*)/$2/;
                $ver = $val;
                last;
             }
         }
      }
   }
   close (CMD);

  return $ver;
}

####################################################################
# ConfigValue
#  in  - product name + parameter name
#  out - value
#
BEGIN{ $TYPEINFO{ConfigValue} = ["function", "string", "string","string"]; } 
sub ConfigValue{
   my $self  = shift;
   my $prod  = shift;
   my $value = shift;

   my $x = XML::LibXML->new();
   #TODO Make it configurable
   my $d = $x->parse_file('/etc/sap-installation-wizard.xml');
   foreach my $node ($d->findnodes('//listentry')){
       my @f  = ();
       my %p  = ();
       my $ok = 0;
       foreach my $c ( $node->getChildNodes )
       {
         $ok = 1 if( 'name' eq $c->getName and $c->string_value eq $prod );
         if( 'search'       eq $c->getName ) {
	        push @f, $c->string_value;
		next;
	 }
         $p{$c->getName}  = $c->string_value;
       }
       if( $ok )
       {
          if( defined $p{$value} )
	  {
	     return $p{$value};
	  }
	  else
	  {
	     return "";
	  }
       }
   }
   return "";
}


####################################################################
# get_nw_products
BEGIN { $TYPEINFO{get_nw_products} = ["function",["list", ["map", "string", "string"]],"string","string","string"]; }
sub get_nw_products
{
   my $self    = shift;
   my $instEnv = shift;
   my $TYPE    = shift;
   my $DB      = shift;
   my $productDir = shift;
   my $imPath  = "$instEnv/Instmaster";
   my @FILTER  = ();
   my $PRODUCTS = {};
   my $x = XML::LibXML->new();
   #TODO Make it configurable
   my $d = $x->parse_file('/etc/sap-installation-wizard.xml');
   foreach my $node ($d->findnodes('//listentry')){
       my @f  = ();
       my $n  = "";
       my $a  = "";
       my $p  = "";
       my $s  = "";
       my $ok = 0;
       foreach my $c ( $node->getChildNodes )
       {
         push @f, $c->string_value if( 'search'       eq $c->getName );
         $n = $c->string_value     if( 'name'         eq $c->getName );
         $a = $c->string_value     if( 'ay_xml'       eq $c->getName );
         $p = $c->string_value     if( 'partitioning' eq $c->getName );
         $s = $c->string_value     if( 'script_name'  eq $c->getName );
         $ok = 1 if( 'type' eq $c->getName and $c->string_value eq $TYPE );
       }
       if( $ok ) {
         foreach( @f ){
	    $p = "base_partitioning" if ( $p eq "" );
	    $s = "sap_inst.sh"       if ( $s eq "" );
            push @FILTER, [ $n, $_ , $a, $p, $s ]
	 }
       }
   }
   
   my %products = ();
   my @NODES = ();
   if ( ! -e "$imPath/product.catalog" ) 
   {
      return [];
   }
   $d = $x->parse_file("$imPath/product.catalog");
   foreach my $tmp ( @FILTER )
   {
      foreach my $PD ( @{$productDir} )
      {
         my $xmlpath = $tmp->[1];
         $xmlpath =~ s/##DB##/$DB/;
         $xmlpath =~ s/##PD##/$PD/;
         foreach my $node ($d->findnodes($xmlpath))
         {
            push @NODES, [ $tmp->[0] , $node, $tmp->[2], $tmp->[3], $tmp->[4] ];
         }
      }
   }
   
   foreach my $tmp( @NODES )
   {
      my $name  = $tmp->[0];
      my $node  = $tmp->[1];
      my $ay    = $tmp->[2];
      my $part  = $tmp->[3];
      my $scr   = $tmp->[4];
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
      if( defined $1 ) {
        my $od = $1;
        $od =~ s#\.#/#;
        my @n = $d->findnodes('//components[@output-dir="'.$od.'"]/display-name');
        $gname = scalar @n ? $n[0]->string_value : $lname ;
      }
      else
      {
        $gname = $lname ;
      }
      if( $gname !~ /$name/ ){
        $gname = $name." ".$gname
      }
      $PRODUCTS->{$gname}->{id}   = $id;
      $PRODUCTS->{$gname}->{ay}   = $ay;
      $PRODUCTS->{$gname}->{part} = $part;
      $PRODUCTS->{$gname}->{scr}  = $scr;
   }
   my @ret = ();
   foreach my $name ( sort keys %$PRODUCTS )
   {
      push @ret, { 
           name         => $name,
	   id           => $PRODUCTS->{$name}->{id},
	   ay_xml       => $PRODUCTS->{$name}->{ay},
	   partitioning => $PRODUCTS->{$name}->{part},
	   script_name  => $PRODUCTS->{$name}->{scr}
       };
   }
   return \@ret;
}

####################################################################
# get_sapinst_path
#
# in : Path to the installation environment.
# out: list of output-dir of the possible products 
#
BEGIN { $TYPEINFO{get_products_for_media} = ["function", ["map", "string", "any"  ] , "string"]; }
sub get_products_for_media{

   my $self        = shift;
   my $prodEnvPath = shift;
   my @media       = split /\n/, `cat $prodEnvPath/start_dir.cd`;
   my @packages    = split /\n/, `cd $prodEnvPath; find -name "packages.xml"`;
   my @labels      = ();
   my @valid       = ();
   my $DB          = "";
   my $TREX        = "";

   foreach my $medium (@media)
   {
      my $label = `cat $medium/LABEL.ASC`; chomp $label;
      push @labels, $label;
   }

   foreach my $xml_file ( @packages )
   {
      my $x     = XML::LibXML->new() or        return ();
      my $doc   = $x->parse_file("$prodEnvPath/$xml_file") or next;
      my $found = 1;
      
      my $xpath = q{
          /packages/package
      };

      foreach my $label ( @labels )
      {
        my $foundLabel = 0;
        foreach my $node ($doc->findnodes($xpath)) {
           my $pattern = $node->getAttribute("label");
           #Hide the brackets () as special characters within regex ()=grouping
           $pattern =~ s/\Q(\E/\Q\(\E/;
           $pattern =~ s/\Q)\E/\Q\)\E/;
	   $pattern =~ s#/#\\/#g;
           
           # replace * with real regex operator group (.*)
           $pattern =~ s/\*/\(\.\*\)/g;

	   if( $label =~ /$pattern/ )
	   {
	     $foundLabel = 1;
	     last;
	   }
        }
	if( !$foundLabel )
	{
	  $found = 0;
	  last;
	}
	# Is it a DB medium
	foreach my $dbl ( @DATABASES )
	{
	   if( $label =~ /^$dbl/ )
	   {
	      $DB = $DBMAP{$dbl};
	      last;
	   }
	}
	# Is it a TREX medium
	if( $label =~ /^TREX/ )
	{
	   $TREX = 1;
	}
      }
      $xml_file =~ s#./Instmaster/##;
      $xml_file =~ s#/packages.xml##;
      push @valid, $xml_file if( $found );
   }
   return {
   		"productDir" => \@valid,
		"DB"         => $DB,
		"TREX"       => $TREX
	}
}

#TODO Do We need these:

####################################################################
# get_sapinst_path
#
# in : $INSTMASTER
# out: list of path to files 
#
BEGIN { $TYPEINFO{get_sapinst_path} = ["function", ["map", "string", "string" ] , "string"]; }
sub get_sapinst_path{

   my $self = shift;
   my $prod_path = shift;

   my @filepath;
   my %filehash;
   my $feature = "defval-for-inifile-generation";
   my $attlist = "<!ATTLIST parameter$/";
   my $newfeature = "  defval-for-inifile-generation  CDATA       #IMPLIED";
   my $found = 0;

   # do some checking
   if (!-d "$prod_path") {
      logger("ERROR(get_sapinst_path): Directory  $prod_path does not exist");
      return ();
   }
   
   # Traverse desired filesystems - generated from find2perl
   #my ($dev,$ino,$mode,$nlink,$uid,$gid);
   #find({wanted => sub {/^control\.dtd\z/s && (($dev,$ino,$mode,$nlink,$uid,$gid) = lstat($_)) && -f _ && push @filepath,$File::Find::name}},"$prod_path");
   @filepath = `find '$prod_path' -name control.dtd`;
   chomp( @filepath );

   # remember it as a key value pair 
   # fixme - what happens if we found more than one control.dtd
   $filehash{"control"} = $filepath[0];


   # add the sapinst executable also as key value pair
   $filehash{"sapinst"} = $prod_path."/sapinst" ;

   return \%filehash;
}

####################################################################
# set_sapinst_feature
#
# in:   $path + filename of the control.dtd
# out:  true if found or set
BEGIN { $TYPEINFO{set_sapinst_feature} = ["function", "boolean"  , "string"]; }
sub set_sapinst_feature{

   my $self = shift;
   my $file = shift;

   my $feature = "defval-for-inifile-generation";
   my $attlist = "<!ATTLIST parameter$/";
   my $newfeature = "  defval-for-inifile-generation  CDATA       #IMPLIED";
   my $found = 0;

   #look for the sapinst feature "defval-for-inifile-generation" within the control.dtd
   open(INFO, $file);      # Open the file
   my @lines = <INFO>;     # Read it into an array
   close(INFO);            # Close the file

   foreach (@lines) {
      # does this line contain the feature
      if ( /$feature/ ){
         logger("Found needed feature $feature within file $file") if ($DEBUG);
         $found = 1;
         last;
      }
   }

   # let's write it by ourselfs
   if ($found ==  0){
      open (FILE, ">$file") || return 0;
      foreach (@lines) {
        print FILE $_;
        if ( $_ eq $attlist ){
             print FILE "$newfeature$/";
             logger("Added needed feature ($feature) to file $file") if ($DEBUG);
        }
      }
      close FILE;
   }
   return 1;
}

####################################################################
# products_on_instmaster
# #
# # in:  $INSTMASTER $DATABASE $INSTALL
# # out: list_of_products
# #
BEGIN{$TYPEINFO{products_on_instmaster} = ["function", ["list", ["map", "string", "any"]], "string", "string"];}
#BEGIN { $TYPEINFO{products_on_instmaster} = ["function", ["list", ["map","string","sting"] ], "string", "string", "string","string"]; }
sub products_on_instmaster {
   my $self = shift;
   my $instmaster = shift;
   my $imversion  = shift;

   my @productList  = ();
   my @sProductList = ();
   my @products     = ();
   my $xpath        = "";
   my $catalog_file = "";
   my $database     = "ADA";
   my $install      = "PD";

   if( $imversion eq 'MULTISWPM' )
   { 
       my @IMS = `find '$instmaster' -mindepth 1 -maxdepth 1 -type d`;
       foreach my $i (@IMS)
       {
	   chomp $i;
           my @NWS = ();
	   logger("IM Path>>>> $i");
	   $catalog_file = "$i/product.catalog";
	   my $l = `cat $i/LABEL.ASC`;
	   my @label = split /:/, $l;
	   my $x = XML::LibXML->new() or return \@productList;
	   my $d = $x->parse_file($catalog_file) or return \@productList;
	   #First we search all NetWiever versions 
           $xpath = '//catalog/components/@output-dir';
	   foreach my $node ($d->findnodes($xpath)) {
               my   $prod = $node->to_literal;
               push @NWS, $prod if( $prod =~ /^NW/ );
	   }
	   #Start find the Products
           my $cwd = getcwd();
           chdir($i) or return \@productList;
           my $cmd = "find . ! -path '*/.*' -path \\*/$database/$install/packages.xml";
           logger(">> $cmd") if ($DEBUG);;
           @products = `$cmd`;
           chomp( @products );
	   foreach my $product_file (@products){
	       # remove trailing "./"
	       $product_file =~ s/^.\///;
	       # remove our searchstring
	       # $product_file =~ s/\/WEBAS\/$database\/$install\/packages.xml//;
	       $product_file =~ s/\/$database\/$install\/packages.xml//;
               $xpath = '//components[@output-dir="'.$product_file.'"]/display-name';
               my $displayname = " ";
               logger("xpath $xpath") if ($DEBUG);
               foreach my $node ($d->findnodes($xpath)) {
                  $displayname = $node->to_literal;
                  $displayname =~ s/\n//mg;
                  logger("---> $displayname") if ($DEBUG);
                  last if( "$displayname" );
               }
               push @productList, {
               			id   => $product_file,
               			name => $displayname,
               			im   => $i,
               			imv  => $label[3]
               		};
               logger("->$product_file = $displayname") if ($DEBUG);
	   }
	   #Start find Standalone Products
	   foreach my $nw ( sort @NWS )
	   {
	       foreach my $st ( @STANDALONE )
	       {
	    	push @sProductList, {
	    				id   => $nw.'-'.$st,
	    				name => "$st on $nw",
	    				im   => $i,
	    				imv  => $label[3],
	        			nw   => $nw
	    			};
	       	
	       }
	   }
	   chdir($cwd);
       }
       push @productList, @sProductList;
       return \@productList;
   }

   $catalog_file = "$instmaster/product.catalog";

   logger("in products_on_instmaster") if ($DEBUG);;
   # Jump into the directory to get usable output data
   my $cwd = getcwd();
   chdir($instmaster) or return \@productList;

   # Traverse desired filesystems
   # Don't follow .directories
   #my $cmd = "find . -path \\*/WEBAS/$database/$install/packages.xml";
   # my $cmd = "find . ! -path '*/.*' -path \\*/WEBAS/$database/$install/packages.xml";
   # new SWPM layout
   my $cmd = "find . ! -path '*/.*' -path \\*/$database/$install/packages.xml";
   logger(">> $cmd") if ($DEBUG);;

   @products = `$cmd`;
   chomp( @products );

   if ( grep(/^\.\/NW/,@products )){
      push(@products,@STANDALONE);
   }

   # add pseudo-product SBC to the list of products
   open (DATA, "$catalog_file") or return \@productList;
   while (<DATA>) {
      if ( /NW_StorageBasedCopy/ ) {
         logger(">> 'NW_StorageBasedCopy' found in $catalog_file") if ($DEBUG);;
         push(@products,"SBC");
         logger(">>>> @products");
      }
   }
   close (DATA);

   my $x = XML::LibXML->new() or return \@productList;
   my $d = $x->parse_file($catalog_file) or return \@productList;

   #'./NW731/ADA/PD'
   foreach my $product_file (@products){
      #logger("-->$product_file") if ($DEBUG);;

      # remove trailing "./"
      $product_file =~ s/^.\///;
      # remove our searchstring
      # $product_file =~ s/\/WEBAS\/$database\/$install\/packages.xml//;
      # new SWPM layout
      $product_file =~ s/\/$database\/$install\/packages.xml//;

      # get cleartext display values
      #STANDALONE = ("TREX","GATEWAY","WEBDISPATCHER");
      if($product_file eq "TREX") {
         $xpath = '//components[@output-dir="STANDALONE"]//components[@output-dir="TREX"]/display-name';
      }elsif($product_file eq "GATEWAY") {
         $xpath = '//components[@output-dir="STANDALONE"]//component[@output-dir="GW"]/display-name';
      }elsif($product_file eq "WEBDISPATCHER") {
         $xpath = '//components[@output-dir="STANDALONE"]//components[@output-dir="AS"]/display-name';
      # storagebased copy SBC
      }elsif($product_file eq "SBC") {
         $xpath = '//component[@output-dir="SBC"]/display-name';
      }else{
         $xpath = '//components[@output-dir="'.$product_file.'"]/display-name';
      }

      my $displayname = " ";
      logger("xpath $xpath") if ($DEBUG);
      foreach my $node ($d->findnodes($xpath)) {
         $displayname = $node->to_literal;
	 $displayname =~ s/\n//mg;
         logger("---> $displayname") if ($DEBUG);
	 last if( "$displayname" );
      }
      push @productList, {
      			id   => $product_file,
      			name => $displayname,
      			im   => $instmaster,
      			imv  => $imversion
      		};
      logger("->$product_file = $displayname") if ($DEBUG);
   }

   chdir($cwd);
   return \@productList;
}

####################################################################
# search_labelfiles
# #
# #  in : path to start the search
# #  out: list of label files
# #
BEGIN { $TYPEINFO{search_labelfiles} = ["function",["list", "string"], "string"]; }
sub search_labelfiles {

   my $prod_path = shift;

   my @file_list = ();

   logger(" in Function: search_labelfiles") if ($DEBUG);

   # Traverse desired filesystems - generated from find2perl
   #my ($dev,$ino,$mode,$nlink,$uid,$gid);
   #
   #     /^LABEL\.ASC\z/s &&
   #     (($dev,$ino,$mode,$nlink,$uid,$gid) = lstat($_)) &&
   #     -f _ &&
   #     print("$name\n");
   #
   #find({wanted => sub {/^LABEL\.ASC\z/s && (($dev,$ino,$mode,$nlink,$uid,$gid) = lstat($_)) && -f _ && push @file_list,$File::Find::name}},"$prod_path");
   #@file_list = `find $prod_path -name LABEL.ASC -o -name info.txt`;

   # Netapp filer do have a .snapshot where we also find LABEL Files
   # so then we get the wrong files back.
   # We exclude all .directories in the search
   #
   # Also, for some products it is essential that the top-level label file
   # is found first, otherwise some product parts may not be found and installed
   # So we sort by directory depth:
   # /mnt/LABEL.ASC
   # /mnt/bar/LABEL.ASC
   # /mnt/foo/LABEL.ASC
   # /mnt/bar/subdir/LABEL.ASC
   # /mnt/foo/subdir/LABEL.ASC
   chomp $prod_path;
   print ("find -L '$prod_path' -name LABEL.ASC -o -name info.txt") if($DEBUG);
   @file_list = `find -L '$prod_path' -name LABEL.ASC -o -name info.txt`;
   #@file_list = `find '$prod_path' ! -path '*/.*' -name LABEL.ASC -o -name info.txt | perl -lne 'print tr:/::, " \$_"' | sort -n | awk {'print \$2'}`;

   chomp(@file_list);

   return @file_list;
}

####################################################################
# _read_labelfile (perl local)
#  in : filename
#  out: labelstring
#
sub _read_labelfile {

   my $filename = shift;
   my $label;

   open (FILE, $filename) or return "";

   while (<FILE>) {
      chomp;
      $label = $_;                
   }
   close(FILE);

   return $label;
}
####################################################################
# read_labelfile for ycp
#
BEGIN { $TYPEINFO{read_labelfile} = ["function", "string", "string"]; }
sub read_labelfile {
  my $self = shift;
  my $filename = shift;
  return _read_labelfile($filename);
}

####################################################################
# compare_label
#  in : search label
#       data label
#  out: true if found
#
BEGIN { $TYPEINFO{compare_label} = ["function", "boolean", "string", "string"]; }
sub compare_label {

   my $searchlabel = shift;
   my $datalabel = shift;

   my $found = undef;

   logger("in compare_label") if ($DEBUG);     

   return $found if !$searchlabel;

   #Hide the brackets () as special characters within regex ()=grouping
   $searchlabel =~ s/\Q(\E/\Q\(\E/;
   $searchlabel =~ s/\Q)\E/\Q\)\E/;

   # replace * with real regex operator group (.*)
   $searchlabel =~ s/\*/\(\.\*\)/g;

   logger("     Search for      >$searchlabel< from our keyword") if ($DEBUG);
   logger("     compare it with >$datalabel< from our file") if ($DEBUG);
   
   if ( label_match($datalabel,$searchlabel) ) { # this will look for fields within the string
      $found = 1;
   };

   return $found;
}

####################################################################
# label_match
#
# compares the label strings field wise because of some specials e.g
# version number 72 should match 72x
# 
# in : label1
#    : label2
# out: true if found
#
BEGIN { $TYPEINFO{label_match} = ["function","boolean", "string", "string"]; }
sub label_match {

      my $data = shift;
      my $search_pattern = shift;

      my @data = split(/:/,$data);
      my @search_pattern = split(/:/,$search_pattern);

      my $data_len = @data;
      if( !$data_len )
      { #probably the label file could not be read
              return 0;
      }
      my $search_len = @search_pattern;

      my $found = 0;
      my $ret = 0;
      my $sum = 0;

      #logger("in label_match") if ($DEBUG);
      #compare fields  
      for (my $i = 0; $i < $search_len; $i++) {
         $found = grep(/^$search_pattern[$i]/,$data[$i]);
         logger("       [$i] ".$data[$i]." <-> ".$search_pattern[$i]." = ".$found) if ($DEBUG);

         # if we found the first difference we can break the loop
         if ( $found == 0) {
             last;
         }
         $sum = $sum+$found;

         if ($search_len eq $sum){
            logger("       ### match ###") if ($DEBUG);
            $ret=1;
            last; # break the loop
         }else{
            #print "NO match";
            $ret=0;
         }
     }
     return $ret;
}
####################################################################
# check_media
#   it checks if the label from labellist exists 
#   if yes it returns the matched labels
# 
# in : path to media
#      labellist
#      LABEL_HASH
#
# out: List of keys for the labels on this media or undef if error     
#


BEGIN { $TYPEINFO{check_media} = ["function", ["map", "string", "string"], "string", ["list", "string"], ["map", "string", [ "map", "string", "string"]] ]; }
sub check_media {
   my $self            = shift;
   my $media           = shift;
   my $ref_list2check  = shift;
   my $ref_label_hash  = shift;

   my @list2check = @$ref_list2check;
   my %label_hash = %$ref_label_hash;

   my %ret=();
   my $regex=0;

   logger("\n--------------") if ($DEBUG);
   logger("in check_media") if ($DEBUG);
   my @filelist = search_labelfiles($media);

   foreach my $file (@filelist){
      logger("\n File: $file") if ($DEBUG);

      my $label_from_file = _read_labelfile($file);

      foreach my $label (@list2check){
         logger("looking for ->Label: $label") if ($DEBUG);
            
         # regex search is not always usefull and leads to wrong results
         # so test if our searchcondition contains one
         if ( $label =~ /\^/ ){

            # only if we have a matching label in our LABEL_HASH
            my @hitkeys = grep /$label/, keys(%label_hash);

            foreach my $key (@hitkeys){
               logger("    RegexKEY: $key ") if ($DEBUG);
               $regex=1;
               if ( compare_label( $label_hash{$key}->{"label"}, $label_from_file ) ){
                     logger("   ## Label for $key found ##") if ($DEBUG);
                     #remember the label and file for later usage
                     $ret{$key} = dirname($file);
               }
            }
         } else {
            logger("   NO-RegexKEY: $label ") if ($DEBUG);
            if ( compare_label( $label_hash{$label}->{"label"}, $label_from_file ) ){
                 logger("  ## Label for $label found ##") if ($DEBUG);
                 #remember the label and file for later usage
                 $ret{$label} = dirname($file);
            }
         }
      }
  }

  return \%ret;
}
####################################################################
BEGIN { $TYPEINFO{collect_labels_for_product} = ["function",["map", "string", [ "map", "string", "string"]], "string", "string", "string", ["list","string"] ]; }
sub collect_labels_for_product {
   my $self = shift;
   my $prod = shift;
   my $instmaster = shift;
   my $components_prod_dir = shift;
   my $prd_labels_ref = shift;

   my @prd_labels = undef;

   my %LabelHash = ();
   my %neededMediaHash = ();


   logger("in collect_labels_for_product") if ($DEBUG);
   if ($prd_labels_ref) {
     @prd_labels = @$prd_labels_ref;
   }

   my $xml_file = "$instmaster/$components_prod_dir/packages.xml";

   # do some checking if file exists
   if (! -f $xml_file ){
      logger("WARNING: File $xml_file does not exist") if ($DEBUG);
      return \%neededMediaHash;
   }

   my $x   = XML::LibXML->new() or        return \%neededMediaHash;
   my $doc = $x->parse_file($xml_file) or return \%neededMediaHash;

   my $xpath = q{
       /packages/package
   };

   # build complete hash
   foreach my $node ($doc->findnodes($xpath)) {
      $LabelHash{ $node->getAttribute("name") }{"mediaName"} = $node->getAttribute("mediaName");
      $LabelHash{ $node->getAttribute("name") }{"label"} = $node->getAttribute("label") ;
   }

   # reduce the hash to the given list of search labels with wildcards (regex)
   if ( $prd_labels_ref ) {
      logger(">> use reduce list of labels") if ($DEBUG);
      foreach my $label (@prd_labels) {
         my @hitKeys = grep /$label/, keys(%LabelHash);
         foreach my $key( @hitKeys ) {
               $neededMediaHash{$key} = $LabelHash{$key};
         }
      }
   # full list   
   }else{
      logger(">> use all labels") if ($DEBUG);
      %neededMediaHash = %LabelHash;
   }   

   #print Dumper(%neededMediaHash);
   #print "XXXXXXX: ".$neededMediaHash{"UKERNEL"}."\n";
   #print "XXXXXXX: ".$neededMediaHash{"UKERNEL"}->{"mediaName"}."\n";
   #print "XXXXXXX: ".$neededMediaHash{"UKERNEL"}->{"label"}."\n";

   return \%neededMediaHash;

}
####################################################################
# search_sapinst_id
#
# in: path where the instmaster lives
#     which product we search for
# out:
#
BEGIN { $TYPEINFO{search_sapinst_id} = ["function",[ "list", "string" ], "string", "string","string", "string", "string", "string", "string", "string"]; }
sub search_sapinst_id {
   my $self = shift;
   my $INSTMASTER = shift;   
   my $IMVERSION  = shift;   

   my $PRODUCT  = shift;  # ERP,CRM,...
   my $STACK    = shift;  # AS-JAVA, AS-ABAP,AS
   my $DATABASE = shift;  # ADA,ORA,DB2,DB6  
   my $TYPE     = shift;  # CENTRAL,DISTRIBUTED,STANDALONE,DIALOG
   my $SEARCH   = shift || "";  # NW_ABAP_DB,NW_ABAP_OneHost,NW_Onehost,NW_Java_SCS,...
   my $INSTALL  = shift;  # PD, LM (Dialoginstance), COPY (Systemcopy) , ES (Enterprise Search), PI (PI System) TREX, GW, WD

        # max parameter (with systemcopy)
        # $1   $2     $3      $4     $5        $6      $7     $9     $9
        #$PRD,“LM“,$INSTALL,$STACK,$DATABASE,“SYSTEM“,$TYPE,$STACK,$SEARCH

   logger("\nPRODUCT $PRODUCT\nSTACK $STACK\nDATABASE $DATABASE\nTYPE $TYPE\nSEARCH $SEARCH\nINSTALL $INSTALL") if($DEBUG);

   if ($TYPE eq "DIALOG"){
     $STACK = "AS";
   }

        # build the search string - this is really crazy :((
   my $serials = '/';
   if( $IMVERSION eq '70SWPM' or $IMVERSION eq 'NW70' ) {
      $serials = $serials.'/components[@output-dir="'.$PRODUCT.'"]';
      print "\n1\n";
      
      if ($INSTALL eq "ES") {
              $serials = $serials.'/';
      }
      
      if ($INSTALL eq "COPY"){
         $serials = $serials.'/components[@output-dir="LM"]';
           print "2\n";
      
      }
      if ($TYPE ne "CENTRAL" && $TYPE ne "STANDALONE" && $INSTALL ne "ES" || $TYPE eq "CENTRAL" && $INSTALL eq "COPY" ) {
         $serials = $serials.'/components[@output-dir="'.$INSTALL.'"]';
           print "3\n";
      }
      if ($TYPE eq "CENTRAL" && $INSTALL eq "PD" || $TYPE eq "DIALOG" ){
         $serials = $serials.'/components[@output-dir="'.$STACK.'"]';
           print "4\n";
      }
      
      if ($DATABASE && $INSTALL ne "ES"){
           print "5\n";
         $serials = $serials.'/components[@output-dir="'.$DATABASE.'"]';
      }
      
      if ($INSTALL eq "COPY"){
         $serials = $serials.'/components[@output-dir="SYSTEM"]';
           print "6\n";
      }
      if ($TYPE eq "CENTRAL" || ($TYPE eq "STANDALONE" && $STACK eq "TREX" )){
           print "7\n";
         $serials = $serials.'/components[@output-dir="'.$TYPE.'"]';
      }
      if ($INSTALL eq "COPY" || ($TYPE eq "STANDALONE" && $STACK eq "TREX" ) ){
           print "8\n";
         $serials = $serials.'/components[@output-dir="'.$STACK.'"]';
      }
      if ($TYPE eq "STANDALONE" && $STACK ne "TREX") {
         $serials = $serials.'/';
      }
      $serials = $serials.'/component[@name="'.$SEARCH.'"]';
           print "9\n";
   } else {
      $SEARCH  = 'TREX_INSTALL' if( $SEARCH eq 'TREX_NW_CI_MAIN' );
      $DATABASE= 'ADA'          if( ! $DATABASE );
      $serials = '//components[@output-dir="'.$PRODUCT.'"]'.
                 '//components[@output-dir="'.$DATABASE.'"]'.
		 '//components[@output-dir="INSTALL"]';
      if( $SEARCH ) {
		 $serials = $serials.'//component[@name="'.$SEARCH.'"]';
      }
      else
      {
		 $serials = $serials.'//components[@output-dir="'.$DATABASE.'/STD"]//component';
      }
   }
   $serials = $serials.'/@id';

   my @PRODUCT_IDS = ();

   my $x = XML::LibXML->new() or return \@PRODUCT_IDS ;
   my $d = $x->parse_file("$INSTMASTER/product.catalog") or return \@PRODUCT_IDS ;
        
   logger("Query:\n".$serials) if ($DEBUG);;

   for my $serial ($d->findnodes($serials)) {
      logger(" PRODUCT_ID: ".$serial->value()) if ($DEBUG);
      push @PRODUCT_IDS,$serial->value();
   }

   return \@PRODUCT_IDS;

}
######################################################################################
# type_of_product
#  in : productname
#  out: type like: STANDALONE = does not need any Database
#                  DBBASED    = needs a Database and ABAP _or_ Java
#                  DOUBLESTACK= needs a Database and ABAP _and_ Java
#
BEGIN { $TYPEINFO{type_of_product} = ["function", "string", "string"]; }
sub type_of_product {
   my $self = shift;

   my $prod = shift;

   if (grep {$prod =~ /\-$_/} @STANDALONE) {
       return "STANDALONE";
   } elsif ( $prod =~ /ES(.*)/ || $prod eq "PI" ) {
       return "DOUBLESTACK";
   }else{
       return "DBBASED";
   }
}


######################################################################################
# internal (private functions/methods)
# ######################################################################################

sub logger {
     my $line = shift || "";
     my $logfile = "/var/log/SAPXML.log";

     open (FH, '>>',$logfile) or warn "Can't open $logfile: $!\n";
     print STDERR "$line\n";
     print FH "$line\n";
     close (FH);
}
   
# Preloaded methods go here.

# Autoload methods go after =cut, and are processed by the autosplit program.

1;
__END__

=head1 NAME

SAPXML - Perl extension for analyzing XML files on the SAP medias.

=head1 SYNOPSIS

  use SAPXML;

=head1 DESCRIPTION

This library provides functions which are uses within the YaST2 sap-installation-wizard module

=head2 EXPORT

All by default.



=head1 SEE ALSO

SAP Install Documentation 


=head1 AUTHOR

Peter Schinagl, E<lt>pschinagl@suse.deE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2010 by SUSE Linux Products GmbH

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.10.0 or,
at your option, any later version of Perl 5 you may have available.


=cut
