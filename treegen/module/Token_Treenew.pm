package Token_Treenew;
use strict;

use Graph;
use Template;

#use Database;
#use Token;
#use Entry;

my ($debug_text,$sanity);

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = {};
    $self->{tree} = "";
    $self->{title} = "";
    $self->{sentence_id} = "";
    bless $self,$class;

    if (@_ == 1 && $_[0] =~ /^\d+$/) {
      $self->from_sentence_id(shift);
    } else {
      my %args = @_;
      if ($args{sentence_id}) { $self->from_sentence_id($args{sentence_id}); }
      elsif ($args{bracket_string}) {
	$self->bracket_parser($args{bracket_string});
      }
      elsif ($args{bracket_tokens}) {
	$self->parse_bracket_output(@{$args{bracket_tokens}});
      }
      elsif ($args{bracketed_terminal_tokens}) {
	$self->parse_bracketed_terminal_tokens($args{bracketed_terminal_tokens});
      }
      elsif ($args{entry_id_string}) {
	$self->from_entry_id_string($args{entry_id_string});
      }
      else { $self->parse_bracket_output(@_); }
    }

    return $self;
}

sub id_tree {
  my $self = shift;
  if (@_) { $self->{tree} = shift; }
  return $self->{tree};
}

sub get_terminal_tokens {
  my $self = shift;
  return $self->get_generation_ids_sorted(1);
}

sub title {
  my $self = shift;
  if (@_) { $self->{title} = shift; }
  return  $self->{title};
}

sub sentence_id {
  my $self = shift;
  if (@_) { $self->{sentence_id} = shift; }
  return $self->{sentence_id};
}

#--------------- debugging -----------------

sub get_debug_info {
  my $self = shift;
  return $debug_text;
}

sub get_sanity_info {
  my $self = shift;
  return $sanity;
}

#---------------- filling the tree -----------------



sub parse_bracket_output {
  my $self = shift;
  my $tree = Graph->new;

  foreach (@_) {
    my ($id,$father,$name) = split /\|/;

    # unser root node hat keinen Vater, wird aber durch das Verfahren
    # trotzdem gesetzt:
    if ($father) { $tree->add_edge($father,$id); }

    # für die erste Generation ist die $id auch gleich die order
    # innerhalb der Generation, für die anderen wird es später
    # überschrieben (->set_order_within_generations).
    $tree->set_attribute("order",$id,$id);
    $tree->set_attribute("content",$id,$name);
  }

  $self->id_tree($tree);
  #$self->set_generations;
  #$self->set_order_within_generations;
}

sub parse_file {
  my $self = shift;
  my $file = shift;
  open(IN,$file) or die "cannot open $file: $!";
  my @lines;
  while (<IN>) {
    if (/|.*|/) { chomp $_; push @lines,$_; }
  }
  close IN;
  $self->parse_bracket_output(@lines);
}

sub parse_bracketed_terminal_tokens {
  my $self = shift;
  my $tstring = shift;
  my @token =  ($tstring =~ /\[([^\[\]]*)\]/g );
  my $tree = Graph->new;
  my $n = 0;
  foreach my $t (@token) {
    $n++;
    $tree->add_vertex($n);
    $tree->set_attribute("order",$n,$n);
    $tree->set_attribute("content",$n,$t);
  }
  $self->id_tree($tree);
}

sub from_entry_id_string { # terminal tokens only
  my $self = shift;
  my $string = shift;
  my $version = shift;
  my @ids = ($string =~ /<([^<>]*)>/g);
  my $tree = Graph->new;
  my $n = 0;
  foreach my $id (@ids) {
    $n++;
    $tree->add_vertex($n);
    $tree->set_attribute("order",$n,$n);
    $tree->set_attribute("entry_id",$n,$id);

    unless ($version) {
      $tree->set_attribute("content",$n,$id); # tmp
    }
  }
  $self->id_tree($tree);
}

#------------------ generations -------------------

sub set_generations {
  my $self = shift;
  my $tree = $self->id_tree;

  my %generations = $self->collect_generations_from_leaves($tree);
  $self->{generations} = \%generations;

  my @generations = sort {$a <=> $b} keys %generations;
  my $max = $generations[$#generations];
  $self->{number_of_generations} = $max;

  foreach my $g (keys %generations) {
    foreach my $id (@{$generations{$g}}) {
      $tree->set_attribute("generation",$id,$g);
    }
  }

  $tree->set_attribute("generation_type","from_leaves");
  $self->id_tree($tree);
}

sub collect_generations_from_leaves {
  my $self = shift;
  my ($tree_orig,$generations,$n) = @_;
  my $tree = $tree_orig->copy;
  my %generations;
  if ($generations) { %generations = %{$generations}; }
  $n++;

  #my @source = $tree->source_vertices;
  my @leaves = $tree->sink_vertices;
  push @leaves,$tree->isolated_vertices;
  if (@leaves) {
    $generations{$n} = \@leaves;
    $tree->delete_vertices(@leaves);
    $self->collect_generations_from_leaves($tree,\%generations,$n);
  } else { return %generations; }
}

sub get_number_of_generations {
  my $self = shift;
  unless ($self->{number_of_generations}) { $self->set_generations; }
  return $self->{number_of_generations};
}

sub get_generation_hash {
  my $self = shift;
  unless ($self->{generations}) { $self->set_generations; }
  return %{$self->{generations}};
}

sub set_order_within_generations {
  my $self = shift;
  my $tree = $self->id_tree;
  my %generations = $self->get_generation_hash;

#  $debug_text .= "<br>\n";
#  $debug_text .= "* in set_order_within_generations<br>\n";

  # bei der ersten Generation entspricht die order der id (siehe
  # ->parse_bracket_output), von dort aus können wir die order der
  # anderen innerhalb ihrer Generation neu bestimmen:

  foreach my $g (sort {$a <=> $b} keys %generations) {
    #$debug_text .= "generation $g<br>\n";
    if ($g == 1) { next; } # unsere erste Generation ... die haben wir schon
    my @ids = @{$generations{$g}};

    # die nodes dieser Generation werden nach der "order" ihres ersten
    # Nachkommen sortiert (obwohl es wahrscheinlich jeder beliebige
    # Nachkomme täte ..."

    my %first;
    foreach my $id (@ids) {
      my @suc = $tree->successors($id);
      @suc = sort { $tree->get_attribute("order",$a)
		      <=> $tree->get_attribute("order",$b) } @suc;

      # wir holen uns die order des ersten successors
      $first{$id} = $tree->get_attribute("order",$suc[0]);

      foreach my $s (@suc) {
	unless ($tree->get_attribute("order",$s)) {
	  $debug_text .= "no order for $s!<br>\n";
	}
      }
    }

    my $n;
    foreach my $id (sort {$first{$a} <=> $first{$b}} @ids) {
      $n++;
      $tree->set_attribute("order",$id,$n);
    }
  }

  $tree->set_attribute("order","1");
  $self->id_tree($tree);
}

sub get_generation_ids_sorted {
  my $self = shift;
  my $generation = shift;
  my $tree = $self->id_tree;

  unless ($tree->get_attribute("order")) {
    $self->set_order_within_generations;
  }

  my %generations = $self->get_generation_hash;
  my @members;
  if ($generations{$generation}) {
    @members = sort {
      $tree->get_attribute("order",$a) <=> $tree->get_attribute("order",$b)
    } @{$generations{$generation}};
  }
  return @members;
}

#------------------- Lehmann Tabellen Berechnung -----------------

sub get_table {
  my $self = shift;
  my ($caption,$template) = @_;
  unless ($template) { $template = 'tree_table.tmpl'; }
  my %params = $self->get_table_params;
  $params{caption} = $caption;
  my $t = HTML::Template->new(filename => $template);
  $t->param( %params );
  return $t->output;
}

sub get_table_root_on_bottom {
  my $self = shift;
  my ($caption,$template) = @_;
  unless ($template) { $template = 'tree_table.tmpl'; }
  my %params = $self->get_table_params_root_on_bottom;
  $params{caption} = $caption;
  my $t = HTML::Template->new(filename => $template);
  $t->param( %params );
  return $t->output;
}

sub print_table {
  my $self = shift;
  print $self->get_table(@_);
}

sub print_table_root_on_bottom {
  my $self = shift;
  print $self->get_table_root_on_bottom(@_);
}

sub set_table_positions {
  my $self = shift;
  my $tree = $self->id_tree;
  my %generations = $self->get_generation_hash;

  # bei den tokens der ersten Generation entpricht die linke table
  # position der doppelten "order" -1

  foreach my $id (@{$generations{1}}) {
    my $order = $tree->get_attribute("order",$id);
    my $pos = 2 * $order - 1;
    $tree->set_attribute("pos",$id,$pos);
  }

  # jetzt können wir von den terminal tokens aus die position der anderen
  # bestimmen:

  foreach my $g (sort {$a <=> $b} keys %generations) {
    if ($g == 1) { next; } # unsere erste Generation ... die haben wir schon
    foreach my $id (@{$generations{$g}}) {
      my @suc = $tree->successors($id);
      @suc = sort { $tree->get_attribute("pos",$a)
		      <=> $tree->get_attribute("pos",$b) } @suc;
      my $first = $tree->get_attribute("pos",$suc[0]);
      my $last  = $tree->get_attribute("pos",$suc[$#suc]);
      my $pos   = int(($first + $last ) / 2);
      $tree->set_attribute("pos",$id,$pos);
    }
  }

  $tree->set_attribute("pos","1");
  $self->id_tree($tree);
}

sub get_table_params { # für tree_table.tmpl
  my $self = shift;
  $self->set_table_positions;

  my $tree = $self->id_tree;
  my $width = $self->get_terminal_tokens * 2;

  my @tr_loop;

  my %open_lines; # für generationen übergreifende linien ...
  my $generations = $self->get_number_of_generations;

  while ($generations) {

    my @ids = $self->get_generation_ids_sorted($generations);

    ### content row ###

    my @td_loop;

    my $cur = 1;
    foreach my $id (@ids) {

      my $content = $tree->get_attribute("content",$id);
      unless ($content) { $content = "<br>"; }
      my $pos = $tree->get_attribute("pos",$id);

#      $debug_text .= "id $id, content $content, pos $pos<br>";

      # etwaige Zellen vor unserem Feld
      unless ($pos == 1) {
	my $diff = $pos - $cur;
	for ( 1 .. $diff) {
	  if ($open_lines{$cur} &&
	      $open_lines{$cur} < $generations) {
	    push @td_loop,{ class => "border_l" }
	  } else {
	    push @td_loop,{};
	  }
	  $cur++;
	}
      }

      # das Feld selbst
      push @td_loop,{ content => $content };
      $cur += 2;

      # etwaige Schlußzellen
      if ($id eq $ids[$#ids]) {

	my $rest = $width - $cur + 1;
	if ($rest) {
	  for ( 1 .. $rest) {
	    if ($open_lines{$cur} &&
	      $open_lines{$cur} < $generations) {
	      push @td_loop,{ class => "border_l" }
	    } else {
	      push @td_loop,{};
	    }
	    $cur++;
	  }
	}
      }
    }

    ### line row ###

    my @tl_loop;

    unless ($generations == 1) {

      # unter der ersten haben wir keine Lininen mehr, oder doch?
      # -> Kategorien - Einträge ...

      my $cur = 1;
      foreach my $id (@ids) {

	my @suc = $tree->successors($id);
	@suc = sort { $tree->get_attribute("pos",$a)
			<=> $tree->get_attribute("pos",$b) } @suc;

	# bis zu welcher generation gehen die Nachkommen?

	foreach my $suc (@suc) {
	  my $pos = $tree->get_attribute("pos",$suc);
	  my $gen = $tree->get_attribute("generation",$suc);
	  $open_lines{$pos + 1} = $gen;
	}

	my $first_pos = $tree->get_attribute("pos",$suc[0]);
	my $last_pos = $tree->get_attribute("pos",$suc[$#suc]);

	# wir behandeln alle Zellen von $cur bis $last_pos ...
	# ... es sei denn, es handelt sich um die letzte id

	my $last = $last_pos + 1;
	if ($id eq $ids[$#ids]) { $last = $width; }

	foreach my $n ($cur .. $last) {
	  $cur++;
	  my $lines = "";

	  # innerhalb unseres Nachkommen ranges? -> t
	  if ($n > $first_pos && $n <= $last_pos) {
	    $lines .= "t";
	  }

	  # offene Generationen übergreifende Linien?
	  if ($open_lines{$n} &&
	      $open_lines{$n} < $generations) {
	    $lines .= "l";
	  }

	  if ($lines) {
	    push @tl_loop,{ class => "border_".$lines, };
	  } else {
	    push @tl_loop,{};
	  }
	}
      }

    }

    push @tr_loop,{ td => \@td_loop };
    if (@tl_loop) { push @tr_loop,{ td => \@tl_loop }; }

    $generations--;

  }

  # parameter für template ...
  my %param = (
	       caption => $self->title,
	       tr => \@tr_loop,
	      );

}

sub get_table_params_root_on_bottom { # für tree_table.tmpl
  my $self = shift;
  $self->set_table_positions;

  my $tree = $self->id_tree;
  my $width = $self->get_terminal_tokens * 2;

  my @tr_loop;

  my %open_lines; # für generationen übergreifende linien ...
  my $generations = $self->get_number_of_generations;

  while ($generations) {

    my @ids = $self->get_generation_ids_sorted($generations);

    ### content row ###

    my @td_loop;

    my $cur = 1;
    foreach my $id (@ids) {

      my $content = $tree->get_attribute("content",$id);
      unless ($content) { $content = "<br>"; }
      my $pos = $tree->get_attribute("pos",$id);

#      $debug_text .= "id $id, content $content, pos $pos<br>";

      # etwaige Zellen vor unserem Feld
      unless ($pos == 1) {
	my $diff = $pos - $cur;
	for ( 1 .. $diff) {
	  if ($open_lines{$cur} &&
	      $open_lines{$cur} < $generations) {
	    push @td_loop,{ class => "border_l" }
	  } else {
	    push @td_loop,{};
	  }
	  $cur++;
	}
      }

      # das Feld selbst
      push @td_loop,{ content => $content };
      $cur += 2;

      # etwaige Schlußzellen
      if ($id eq $ids[$#ids]) {

	my $rest = $width - $cur + 1;
	if ($rest) {
	  for ( 1 .. $rest) {
	    if ($open_lines{$cur} &&
	      $open_lines{$cur} < $generations) {
	      push @td_loop,{ class => "border_l" }
	    } else {
	      push @td_loop,{};
	    }
	    $cur++;
	  }
	}
      }
    }

    ### line row ###

    my @tl_loop;

    unless ($generations == 1) {

      # unter der ersten haben wir keine Lininen mehr, oder doch?
      # -> Kategorien - Einträge ...

      my $cur = 1;
      foreach my $id (@ids) {

	my @suc = $tree->successors($id);
	@suc = sort { $tree->get_attribute("pos",$a)
			<=> $tree->get_attribute("pos",$b) } @suc;

	# bis zu welcher generation gehen die Nachkommen?

	foreach my $suc (@suc) {
	  my $pos = $tree->get_attribute("pos",$suc);
	  my $gen = $tree->get_attribute("generation",$suc);
	  $open_lines{$pos + 1} = $gen;
	}

	my $first_pos = $tree->get_attribute("pos",$suc[0]);
	my $last_pos = $tree->get_attribute("pos",$suc[$#suc]);

	# wir behandeln alle Zellen von $cur bis $last_pos ...
	# ... es sei denn, es handelt sich um die letzte id

	my $last = $last_pos + 1;
	if ($id eq $ids[$#ids]) { $last = $width; }

	foreach my $n ($cur .. $last) {
	  $cur++;
	  my $lines = "";

	  # innerhalb unseres Nachkommen ranges? -> t
	  if ($n > $first_pos && $n <= $last_pos) {
	    $lines .= "b";
#	    $lines .= "t";
	  }

	  # offene Generationen übergreifende Linien?
	  if ($open_lines{$n} &&
	      $open_lines{$n} < $generations) {
	    $lines .= "l";
	  }

	  if ($lines) {
	    push @tl_loop,{ class => "border_".$lines, };
	  } else {
	    push @tl_loop,{};
	  }
	}
      }

    }

    push @tr_loop,{ td => \@td_loop };
    if (@tl_loop) { push @tr_loop,{ td => \@tl_loop }; }

    $generations--;

  }

  @tr_loop = reverse @tr_loop;

  # parameter für template ...
  my %param = (
	       caption => $self->title,
	       tr => \@tr_loop,
	      );

}

#----------------- Klammern -----------------

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

sub bracket_parser {
  my $self = shift;
  my $brackets = shift;

  $brackets =~ s/ {2,}/ /g;
  $brackets =~ s/\'( *?[^\[\]\']+?)\]/\'\[$1\]\]/g;
  $brackets =~ s/\[( *?[^\[\]\']+?)\'/\[\[$1\]\'/g;
  $brackets =~ s/\[ \]//g;


  my @brackets = $brackets =~ /$utf8a/gox;	#generate a utf8 array of chars

  my @tokenlist = tokenize(@brackets) if (checkBrackets($brackets));
  $self-> parse_bracket_output(@tokenlist);
}

sub checkBrackets { # if ( = ) returns 1 else 0
    my $muster = shift;
	return (($muster =~ tr/\(// == $muster =~ tr/\)//) && ($muster ne "") && ($muster !~ /\(\)/) && ($muster =~ tr/\[// == $muster =~ tr/\]//)) ? 1 : 0;
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


sub tokenize_old {		# parameter @ utf8 chars array

  my @arr = @_;		# utf8 array of the current generation
  my @tmp = ();		# substitute array
  my @tokenlist;	# token list with child|father|nodename
  my @childs;		# which are the childs of the current token
  my $input;		# fathers name
  my ($tokstart, $tokend);# start and end of a token in @arr
  my $end =  $#arr;	# how many chars in @arr
  my $start = 0;	# init $start for creating substitute array @tmp
  my $count = -1;	# init @arr counter
  my $token;		# found token in @arr
  my $tokencount = 1;	# init token counter
	
  my $k;			# general counter var
	
  # at first numerize the basic tokens
  while ($count < $end) {		# search for ( from left to right of arr
    if ($arr[$count++] eq "(") {	
      if ($arr[$count] ne "(") {	# if don't come a bracket it could be a token
	$tokstart = $count++;
	while ($arr[$count] !~ /[\(\)]/) { $count++; };	#look for the end of the token
	if ($arr[$count] ne "(") {	# it is a token
	  $tokend = $count;	# stores the end
	  $token = "";		# init token
	  for ($k=$tokstart; $k<$tokend; $k++) { $token .= $arr[$k]; }	# build the token from arr
	  push(@tokenlist, $tokencount . "||" . $token);	#push token in tokenlist
	  $token = "\$".$tokencount . "\$". $token;	# substitute token with $token_counter$+token
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
	
	
  while (join("", @arr) =~ /\(/) {	# do while a bracket is in @arr
	
    while ($count < $end) {		# search for ( from left to right of arr
      if ($arr[$count++] eq "(") {	
	if ($arr[$count] ne "(") {	# if don't come a bracket it could be a token
	  $tokstart = $count++;
	  while ($arr[$count] !~ /[\(\)]/) { $count++; };	#look for the end of the token
	  if ($arr[$count] ne "(") {	# it is a token
	    $tokend = $count;	# stores the end
	    $token = "";		# init token
	    for ($k=$tokstart; $k<$tokend; $k++) { $token .= $arr[$k]; }	# build the token from arr
	    $token =~ /(\[.*?\])/ ;
	    $input = $1;
	    $input =~ s/\[//g;
	    $input =~ s/\]//g;
	    $tokencount++;
	    push(@tokenlist, $tokencount . "||" . $input);	# push the new found token in the tokenlist
	    @childs = $token =~ /\$(.*?)\$/g;		# get all childs of the token - between $ . $
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

sub bracket_string {
  my $self = shift;
  if (@_) { $self->{bracket_string} = shift; }
#  unless ($self->{bracket_string}) {
#    $self->collect_brackets;
#  }
  return $self->{bracket_string};
}

sub bracket_version {
  my $self = shift;
  $self->set_order_within_generations;
  my $tree = $self->id_tree;

  # TODO: wie markieren wir operator-operand1-operand2?

  my ($front,$end);
  $self->collect_brackets();
  return $self->bracket_string
}

sub collect_brackets {
  my $self = shift;
  my $node = shift;
  my $tree = $self->id_tree;

  my @nodes;
  if ($node) {
    my $content = $tree->get_attribute("content",$node);
    if ($tree->get_attribute("generation",$node) > 1) {
      $content = "[$content]";
    }
    $self->bracket_string($self->bracket_string."|".$content);
#    $self->{front} .= "($content";
#    $self->{end} = ")".$self->{end};
    @nodes = $tree->successors($node);
  } else {
    @nodes = $tree->source_vertices;
  }

  foreach my $node (sort { $tree->get_attribute("order",$a) <=>
			     $tree->get_attribute("order",$b) }
		    @nodes) {
    $self->collect_brackets($node);
  }
}

#----------------------- comparing trees --------------------

sub compare_trees {
  my $self = shift;
  my ($tree1,$tree2) = @_;
  my @errors;

  # inwieweit stimmen die terminal token entry ids überein?
  my @tt1 = $tree1->get_terminal_tokens;
  my @tt2 = $tree2->get_terminal_tokens;

  unless (scalar @tt1 eq scalar @tt2) {
    push @errors,"different numbers of terminal tokens";
  }

  my $n;
  while (@tt1 || @tt2) {
    $n++;
    my $t1 = shift @tt1;
    my $t2 = shift @tt2;
    my $id1 = $tree1->get_attribute("entry_id",$t1);
    my $id2 = $tree2->get_attribute("entry_id",$t2);
    unless ($id1 eq $id2) {
      push @errors,"different ids on position $n: $id1 <-> $id2";
    }
  }
}

1;


__END__

=head1 NAME

Token_Tree

=head1 NECCESSARY OTHER MODULES AND FILES

  CPAN:       Graph, HTML::Template
  templates:  'tree_table_page.tmpl', 'tree_table.tmpl'
  Jachimume:  Database, Token, Entry, mltd

=head1 SYNOPSIS

  use Token_Tree;

  my $tree = Token_Tree->new($sentence_id);
  my $tree = Token_Tree->new(@bracket_script_output);
  my $tree = Token_Tree->new(sentence_id => $sentence_id);
  my $tree = Token_Tree->new(bracket_tokens => \@bracket_script_output);
  my $tree = Token_Tree->new(bracket_string => $bracket_string);
  my $tree = Token_Tree->new(bracketed_terminal_tokens => $bracketed_tokens);
  my $tree = Token_Tree->new(entry_id_string => $entry_id_string);

  # or:
  my $tree = Token_Tree->new();
  tree->parse_file($file); # file im format wie @bracket_script_output

  my $caption = "Demo Tree";
  my $template = "tree_table.tmpl";

  $tree->print_table($caption,$template);
  $tree->print_table($caption); # default: "tree_table.tmpl"

  # or:
  my $table = $tree->get_table($caption,$template);
  my $table = $tree->get_table($caption);

=head1 DESCRIPTION

Der Tree, der von ->id_tree zurückgegeben wird, ist ein
Graph::Directed von tokens und ihren Eltern-Token, mit den
vertex-attributen "content" und "order". Der Wert von "content" wird
als Knoten im HTML-Baum ausgedruckt, "order" wird benötigt, um die
Position der Knoten zu berechnen.

Die Knoten selbst bestehen zur Zeit aus selbst gegebenen IDs
bzw. token-ids aus der Datenbank. Für einen Tree-Vergleich brauchen
wir auch die entry_ids. Sie eignen sich nicht als vertices, da die
selbe entry id mehrmals in einem Satz vorkommen kann. Sie werden jetzt
bei ->from_sentence_id als vertice attribute "entry_id"
mitabgespeichert.

