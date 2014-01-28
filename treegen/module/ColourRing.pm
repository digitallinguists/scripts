package ColourRing;
sub TIESCALAR {
	my($class, @values) = @_;
	bless \@values, $class;
	return \@values;
}
sub FETCH {
	my $self = shift;
	push(@$self,shift(@$self));
	return $self->[-1];
}
sub STORE {
	my ($self, $value) = @_;
	unshift @$self, $value;
	return $value;
}
1;