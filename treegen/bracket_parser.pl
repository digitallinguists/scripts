#!/usr/bin/perl -w

use strict;
use CGI::Carp qw(fatalsToBrowser);

# search path for needed modules
use lib "XXXXXXXXXXX/cgi-bin/module";

use Token_Treenew;


my @pairs;
my $buffer;
my $pair;
my %params;

my $utf8a = q{
	 	[\x00-\x7F]
	|	[\xC2-\xDF][\x80-\xBF]
	|	\xE0[\xA0-\xBF][\x80-\xBF]
	|	[\xE1-\xEF][\x80-\xBF][\x80-\xBF]
	|	\xF0[\x90-\xBF][\x80-\xBF][\x80-\xBF]
	|	[\xF1-\xF7][\x80-\xBF][\x80-\xBF][\x80-\xBF]
	|	\xF8[\x88-\xBF][\x80-\xBF][\x80-\xBF][\x80-\xBF]
	|	[\xF9-\xFB][\x88-\xBF][\x88-\xBF][\x88-\xBF][\x88-\xBF]
	|	\xFC[\x84-\xBF][\x88-\xBF][\x88-\xBF][\x88-\xBF][\x88-\xBF]
	|	\xFD[\x88-\xBF][\x88-\xBF][\x88-\xBF][\x88-\xBF][\x88-\xBF]
	     };


if ($ENV{'REQUEST_METHOD'} eq 'GET') {
 @pairs = split(/&/, $ENV{'QUERY_STRING'});
 $buffer = " ";
}
elsif ($ENV{'REQUEST_METHOD'} eq 'POST') {
 read(STDIN, $buffer, $ENV{'CONTENT_LENGTH'});
 @pairs = split(/&/, $buffer);
}

printhead();

foreach $pair (@pairs) { #erzeuge CGI-Datenhash
 (my $name, my $value) = split(/=/, $pair);
 $name =~ tr/+/ /;
 $name =~ s/%([a-fA-F0-9][a-fA-F0-9])/pack("C", hex($1))/eg;
 $name =~ s/\n//g;
 $value =~ tr/+/ /;
 $value =~ s/%([a-fA-F0-9][a-fA-F0-9])/pack("C", hex($1))/eg;
 $value =~ s/\n//g;
 $params{$name} = $value;
}

my $muster = (exists $params{SuchBegriff}) ? $params{SuchBegriff} : "[A]";  #globales Suchmuster


my $orgmuster = $muster;

$muster =~ s/ {2,}/ /g;
$muster =~ s/\'( *?[^\[\]\']+?)\]/\'\[$1\]\]/g;
$muster =~ s/\[( *?[^\[\]\']+?)\'/\[\[$1\]\'/g;
$muster =~ s/\[ \]//g;

my @muster = $muster =~ /$utf8a/gox;	#generate a utf8 array of chars
my @tokenlist;

my @err;
@err = checkBrackets($muster);

if ($err[0] == 1 && $err[1] == 1 && $err[2] == 1 && $err[3] == 0 && $err[4] == 1) {
	@tokenlist = tokenize(@muster);
	
	foreach(@tokenlist) { s/~/&nbsp;/g; } #~ in non breaking space
	
	print "<center>";
	print "<h3>Lehmannscher HTML-Baum</h3><br>";
	
	my $table;
	my $tree = Token_Treenew->new(@tokenlist);;
	
	my $caption = "";
	my $template = "tree_table.tmpl";
	
	if (exists($params{V})) { 	# parameter 'V' (reversed tree) passed via calling HTML page
		$tree->print_table_root_on_bottom($caption,$template);
		$table = $tree->get_table_root_on_bottom($caption,$template);
	}
	else {
		$tree->print_table($caption,$template);
		$table = $tree->get_table($caption,$template);
	}
	$table =~ s/</&lt;/g;
	$table =~ s/>/&gt;/g;

	print "</center>";
	print "<h2>Quelltext</h2>\n";
	print "<p style=\"background-color:white; font-size:9pt;\">";
	print "&lt;html&gt;\n&lt;head&gt;\n&lt;title&gt;...&lt;/title&gt;\n";
	print "&lt;meta http-equiv=\"Content-Type\" content=\"text/html; charset=utf-8\"&gt;\n";
	print "&lt;meta http-equiv=\"Content-Style-Type\" content=\"text/css\"&gt;\n";
	print "&lt;style type=\"text/css\"&gt;\n";
	print "&lt;!--\n";
	print "   table  { margin-top:8pt; font-family:\"Arial Unicode MS\",Arial,sans-serif; font-size:11pt;\n      border-color:#9999cc; border-collapse:collapse; }\n";
	print "   table.insert { background-color:#ffffff; color:#000033; align:\"center\"; }\n";
	print "   caption { position:absolute; left:0px; padding-bottom:8pt; font-style:italic; }\n\n";
	print "   td { padding-left:6px; padding-right:6px; border-color:#9999cc; }\n";
	print "   *.border_trbl { border-style:solid; border-width:1px; }\n";
	print "   *.border_t { border-top-style:solid; border-width:1px }\n";
	print "   *.border_r { border-right-style:solid; border-width:1px; }\n";
	print "   *.border_b { border-bottom-style:solid; border-width:1px; }\n";
	print "   *.border_l { border-left-style:solid; border-width:1px; }\n";
	print "   *.border_tr { border-top-style:solid; border-right-style:solid; border-width:1px; }\n";
	print "   *.border_tb { border-top-style:solid; border-bottom-style:solid; border-width:1px; }\n";
	print "   *.border_tl { border-top-style:solid; border-left-style:solid; border-width:1px; }\n";
	print "   *.border_rb { border-right-style:solid; border-bottom-style:solid; border-width:1px; }\n";
	print "   *.border_rl { border-right-style:solid; border-left-style:solid; border-width:1px; }\n";
	print "   *.border_bl { border-bottom-style:solid; border-left-style:solid; border-width:1px; }\n";
	print "   *.border_trb { border-top-style:solid; border-right-style:solid; border-bottom-style:solid; border-width:1px; }\n";
	print "   *.border_trl { border-top-style:solid; border-right-style:solid; border-left-style:solid; border-width:1px; }\n";
	print "   *.border_tbl { border-top-style:solid; border-bottom-style:solid; border-left-style:solid; border-width:1px; }\n";
	print "   *.border_rbl { border-right-style:solid; border-bottom-style:solid; border-left-style:solid; border-width:1px; }\n";
	print "--&gt;\n";
	print "&lt;/style&gt;\n";
	print "&lt;/head&gt;\n";
	print "&lt;body&gt;\n\n";
	
	print $table;
	print "&lt;/body&gt;\n";
	print "&lt;/html&gt;\n";
	print "</p>";
 	
} else {
	
	print "<h2><font color=red>Eingabefehler:</font></h2>\n\n";
	print "<table><tr><td>$muster</td></tr></table>\n";
	print "Ein Kategorialname ist leer!\n\n" if ($err[4] == 0);
	print "Es wurde kein Klammerausdruck &uuml;bergeben!\n\n" if ($err[1] == 0);
	print "Ein Baumelemement ist leer!\n\n" if ($err[2] == 0);
	my $sy = int((($muster =~ tr/\'//) / 2));
	print "Fehler in der Markierung der Kategorialsymbole!\n gefundene Kategoriesymbole: $sy\n\n" if ($err[3] == 1);
	my $ko = $muster =~tr/\[//;
	my $kg = $muster =~tr/\]//;
	print "Klammerfehler!\n ge&ouml;ffnete Klammer: $ko\n geschlossene Klammern: $kg\n\n" if ($err[0] == 0);
	$orgmuster =~ s/\[/[<br>/g;
	print $orgmuster if ($err[4] == 0 || $err[2] == 0 || $err[3] == 1 || $err[0] == 0);
}


print "</pre></body></html>";

#______________________________________________________SUB______________________________________________________________

sub checkBrackets { # if ( = ) returns 1 else 0
	my $muster = shift;
	my @err;
	my $a = ($muster =~ tr/\[// == $muster =~ tr/\]//) ? 1 : 0;
	my $b = ($muster ne "") ? 1 : 0;
	my $c = ($muster !~ /\[\]/)  ? 1 : 0;
	my $d = (($muster =~ tr/\'//) % 2);
	my $e = ($muster !~ /\'\'/) ? 1 : 0;
	
	push(@err, $a);
	push(@err, $b);
	push(@err, $c);
	push(@err, $d);
	push(@err, $e);
	return(@err); 
}

sub tokenize {		# parameter @ utf8 chars array

	my @arr = @_;		# utf8 array of the current generation
    	my @tmp = ();		# substitute array
    	my @tokenlist;		# token list with child|father|nodename
	my @childs;		# which are the childs of the current token
	my $input;		# fathers name
	my ($tokstart, $tokend);# start and end of a token in @arr
	my $end =  $#arr;	# how many chars in @arr
	my $start = 0;		# init $start for creating substitute array @tmp
	my $count = -1;		# init @arr counter
	my $token;		# found token in @arr
	my $tokencount = 1;	# init token counter
	
	my $k;			# general counter var
	
	# at first numerize the basic tokens
	while ($count < $end) {		# search for ( from left to right of arr
		if ($arr[$count++] eq "[") {	
			if ($arr[$count] ne "[") {	# if don't come a bracket it could be a token
				$tokstart = $count++;
				while ($arr[$count] !~ /[\[\]]/) { $count++; };	#look for the end of the token
	        		if ($arr[$count] ne "[") {	# it is a token
					$tokend = $count;	# stores the end
					$token = "";		# init token
					for ($k=$tokstart; $k<$tokend; $k++) { $token .= $arr[$k]; }	# build the token from arr
					push(@tokenlist, $tokencount . "||" . $token);	#push token in tokenlist
					$token = "\$".$tokencount . "\$". $token;	# substitute token with #token_counter#+token
					for($k=$start;$k<$tokstart-1;$k++) { push(@tmp, $arr[$k]); }	# build the the next generation in @tmp - get all before the token
					push(@tmp, $token =~ /$utf8a/gox);	# push the the numerized token in utf8!
					$start = $tokend+1;	# store the end of the last token for @tmp
					$tokencount++;
				}
				
			}
			
	    }    
	
	}	
	push(@tmp, @arr[$start .. $end]);	# push the rest in @tmp
	$tokencount--;
	@arr = @tmp;	# @arr becomes the numerized generation
	@tmp = ();	# delete @tmp
	$count = -1;	# init a new run
	$start = 0;
	$end = $#arr;
	
	
    	while (join("", @arr) =~ /\[/) {	# do while a bracket is in @arr
	
		while ($count < $end) {		# search for ( from left to right of arr
			if ($arr[$count++] eq "[") {	
				if ($arr[$count] ne "[") {	# if don't come a bracket it could be a token
					$tokstart = $count++;
					while ($arr[$count] !~ /[\[\]]/) { $count++; };	#look for the end of the token
		        		if ($arr[$count] ne "[") {	# it is a token
						$tokend = $count;	# stores the end
						$token = "";		# init token
						for ($k=$tokstart; $k<$tokend; $k++) { $token .= $arr[$k]; }	# build the token from arr
							$token =~ /(\'.*?\')/ ;
							$input = $1;
							$input =~ s/\'//g;
							$input =~ s/\'//g;
							$tokencount++;
							push(@tokenlist, $tokencount . "||" . $input);	# push the new found token in the tokenlist
							@childs = $token =~ /\$(.*?)\$/g;		# get all childs of the token - between # . #
							foreach (@childs) { $tokenlist[$_-1] =~ s/\|\|/\|$tokencount\|/; }	# store in the tokenlist the parent of each child
							$input = "\$".$tokencount . "\$". $input;	# substitute token with #token_counter#+token
							for($k=$start;$k<$tokstart-1;$k++) { push(@tmp, $arr[$k]); }	# build the the next generation in @tmp - get all before the token
							push(@tmp, $input =~ /$utf8a/gox);	# push the the new token in utf8!
							$start = $tokend+1;	# store the end of the last token for @tmp
						
					}
					
				}
				
		    }    
		
		}
		push(@tmp, @arr[$start .. $end]);	# push the rest in @tmp
		@arr = @tmp;	# @arr becomes the new generation
		@tmp = ();	# delete @tmp
		$count = -1;	# init a new run
		$start = 0;
		$end = $#arr;
    	}
    	return(@tokenlist);
}


sub printhead() { # print the HTML header including JAVASCRIPTS
print <<HEAD;
Content-type: text/html\n
<html><head><title>Generator Lehmannscher HTML-B&auml;ume - (C) Uni. Erfurt Programmierung Ulrike Schmidt + Hans-J&ouml;rg Bibiko 2003</title>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8">
<meta http-equiv="Content-Style-Type" content="text/css">
<style type="text/css">
<!--
	table  { margin-top:8pt; font-family:"Arial Unicode MS",Arial,sans-serif; font-size:11pt; border-color:#9999cc; border-collapse:collapse; }
	table.insert { background-color:#ffffff; color:#000033; align:"center"; }
	caption { position:absolute; left:0px; padding-bottom:8pt; font-style:italic; }

	
	td { padding-left:6px; padding-right:6px; border-color:#9999cc; }
	*.border_trbl { border-style:solid; border-width:1px; }
	*.border_t { border-top-style:solid; border-width:1px }
	*.border_r { border-right-style:solid; border-width:1px; }
	*.border_b { border-bottom-style:solid; border-width:1px; }
	*.border_l { border-left-style:solid; border-width:1px; }
	*.border_tr { border-top-style:solid; border-right-style:solid; border-width:1px; }
	*.border_tb { border-top-style:solid; border-bottom-style:solid; border-width:1px; }
	*.border_tl { border-top-style:solid; border-left-style:solid; border-width:1px; }
	*.border_rb { border-right-style:solid; border-bottom-style:solid; border-width:1px; }
	*.border_rl { border-right-style:solid; border-left-style:solid; border-width:1px; }
	*.border_bl { border-bottom-style:solid; border-left-style:solid; border-width:1px; }
	*.border_trb { border-top-style:solid; border-right-style:solid; border-bottom-style:solid; border-width:1px; }
	*.border_trl { border-top-style:solid; border-right-style:solid; border-left-style:solid; border-width:1px; }
	*.border_tbl { border-top-style:solid; border-bottom-style:solid; border-left-style:solid; border-width:1px; }
	*.border_rbl { border-right-style:solid; border-bottom-style:solid; border-left-style:solid; border-width:1px; }
	
	
	*.lateral_padding { padding-left:6px; padding-right:6px }
	BODY {background-color:#fffff0; text-color:#000000; margin: 1cm 1cm 1cm 1cm;}
-->
</style>
</head>
<body>
<pre>
HEAD
}

