package Token_Tree_Bibiko;
use strict;

use Graph;
use Template;

#require "/home/strato/www/bi/www.bibiko.com/htdocs/cgi-bin/module/Template.pm";
#require "/home/strato/www/bi/www.bibiko.com/htdocs/cgi-bin/module/Graph/Base.pm";
#require "/home/strato/www/bi/www.bibiko.com/htdocs/cgi-bin/module/Graph/BFS.pm";
#require "/home/strato/www/bi/www.bibiko.com/htdocs/cgi-bin/module/Graph/DFS.pm";
#require "/home/strato/www/bi/www.bibiko.com/htdocs/cgi-bin/module/Graph/Directed.pm";
#require "/home/strato/www/bi/www.bibiko.com/htdocs/cgi-bin/module/Graph/HeapElem.pm";
#require "/home/strato/www/bi/www.bibiko.com/htdocs/cgi-bin/module/Graph/Traversal.pm";
#require "/home/strato/www/bi/www.bibiko.com/htdocs/cgi-bin/module/Graph/Unidirected.pm";

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = {};
    $self->{tree} = "";
    bless $self,$class;

    $self->parse_bracket_output(@_) if @_;

    return $self;
}

sub id_tree {
  my $self = shift;
  if (@_) { $self->{tree} = shift; }
  return $self->{tree};
}

sub parse_bracket_output {
  my $self = shift;
  my $tree = Graph->new;
  foreach (@_) {
    my ($id,$father,$name) = split /\|/;

    # unser root node hat keinen Vater, wird aber durch das Verfahren
    # trotzdem gesetzt:
    if ($father) { $tree->add_edge($father,$id); }

    # fuer die erste Generation ist die $id auch gleich die order
    # innerhalb der Generation, fuer die anderen wird es spaeter
    # ueberschrieben (->set_order_within_generations).
    $tree->set_attribute("order",$id,$id);
    $tree->set_attribute("name",$id,$name);
  }
  $self->id_tree($tree);
  $self->set_generations;
  $self->set_order_within_generations;
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

sub get_terminal_tokens {
  my $self = shift;
  return $self->get_generation_ids_sorted(1);
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

  # bei der ersten Generation entspricht die order der id (siehe
  # ->parse_bracket_output), von dort aus koennen wir die order der
  # anderen innerhalb ihrer Generation neu bestimmen:

  foreach my $g (sort {$a <=> $b} keys %generations) {
    if ($g == 1) { next; } # unsere erste Generation ... die haben wir schon
    my @ids = @{$generations{$g}};

    # die nodes dieser Generation werden nach der "order" ihres ersten
    # Nachkommen sortiert (obwohl es wahrscheinlich jeder beliebige
    # Nachkomme taete ..."

    my %first;
    foreach my $id (@ids) {
      my @suc = $tree->successors($id);
      @suc = sort { $tree->get_attribute("order",$a)
		      <=> $tree->get_attribute("order",$b) } @suc;

      # wir holen uns die order des ersten successors
      $first{$id} = $tree->get_attribute("order",$suc[0])
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

sub print_table {
  my $self = shift;
  print $self->get_table(@_);
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

  # jetzt koennen wir von den terminal tokens aus die position der anderen
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

sub get_table_params { # fuer tree_table.tmpl
  my $self = shift;
  $self->set_table_positions;

  my $tree = $self->id_tree;
  my $width = $self->get_terminal_tokens * 2;

  my @tr_loop;

  my %open_lines; # fuer generationen uebergreifende linien ...
  my $generations = $self->get_number_of_generations;
  while ($generations) {

    my @ids = $self->get_generation_ids_sorted($generations);

    ### content row ###

    my @td_loop;

    my $cur = 1;
    foreach my $id (@ids) {

      my $content = $tree->get_attribute("name",$id);
      my $pos = $tree->get_attribute("pos",$id);

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

      # etwaige Schluﬂzellen
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
      # -> Kategorien - Eintraege ...

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

	  # offene Generationen uebergreifende Linien?
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

  # parameter fuer template ...
  my %param = ( tr => \@tr_loop, );

}


1;


__END__

=head1 NAME

Token_Tree_Bibiko

=head1 NECCESSARY OTHER MODULES AND FILES

  CPAN:       Graph, HTML::Template
  templates:  'tree_table_page.tmpl', 'tree_table.tmpl'

=head1 SYNOPSIS

  use Token_Tree_Bibiko;

  my $tree = Token_Tree_Bibiko->new(@bracket_script_output);

  # or:
  my $tree = Token_Tree_Bibiko->new();
  tree->parse_file($file);

  my $caption = "Demo Tree";
  my $template = "tree_table.tmpl";

  $tree->print_table($caption,$template);
  $tree->print_table($caption); # default: "tree_table.tmpl"

  # or:
  my $table = $tree->get_table($caption,$template);
  my $table = $tree->get_table($caption);


