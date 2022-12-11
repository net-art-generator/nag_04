# $Header: /SPACE/cycle/cvsroot/moi-perl/MOI/NetArt/Generator/lib/MOI/NetArt/Dada/Text.pm,v 1.3 2003/06/30 13:50:41 leo Exp $
#
# Copyright (c) 2003 Richard Leopold <rl@0n3.org>. All rights reserved.
#
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
##

package MOI::NetArt::Dada::Text;

use 5.008;
use strict;
use warnings;

require Exporter;

use MOI::Base qw(:moiLogger);

our @ISA = qw(Exporter MOI::Base);

our $VERSION = '0.02';

my $_StartEnd = '.';

sub new {
	my $proto  = shift;
	my $class  = ref($proto) || $proto;
	my $parent = ref($proto) && $proto;
	
	my $self = { punct          => ',;.:?!',
	             concat         => 0,
	             last_word_in   => $_StartEnd = '.',
	             last_word_out  => $_StartEnd = '.',
	             wordmap        => undef,
	             textbase       => '',
	             @_
	           };
	
	$self = $class->SUPER::new( %{ $self } );
	bless ($self, $class);
	return $self->_init__MOI_NetArt_Dada_Text();
}

##
# private methods
#

sub _init__MOI_NetArt_Dada_Text {
	my $self = shift;
	
	$self->{last_word_in}  = $self->{start_end};
	$self->{last_word_out} = $self->{start_end};
	
	return $self;
}

##
# public methods
#

sub feed {
	my $self   = shift;
	my $text   = shift;
	
	return 0 unless defined $text;
	
	logger("feed() dada engine with: $text", INFO);
	
	my $word = '';
	my $b4   = $self->{concat} ? $self->{last_word_in} : $_StartEnd;
	
	# seperate punct-symbols as word
	$text =~ s/(\S)([$self->{punct}]\s)/$1 $2 /g;
	$text =~ s/\s([$self->{punct}])(\D)/ $1 $2/g;
	$text =~ s/\s+/ /g;
	
	$self->{textbase} .= ' ';
	$self->{textbase} .= $self->{concat} ? $text : "\n#--$text";
	
	my $wc = 0;
	while ($text =~ s/^\s*(\S+)(.*)/$2/) {
		$word = $1;
		
		if ( exists $self->{wordmap}->{$b4}->{$word} ) { 
			$self->{wordmap}->{$b4}->{$word}++;
		}
		else { $self->{wordmap}->{$b4}->{$word} = 1; }
		
		$b4 = $word;
		$wc++;
	}
	$self->{last_word_in} = $word;
	
	logger("added $wc words to textbase and wordmap") if $self->{debug};
	
	return $wc;
}

sub get_word {
	my $self = shift;
	my $b4   = shift || $self->{last_word_out} || $_StartEnd;
	
	my $ret     = '';
	my $wordmap = $self->{wordmap};
	if (exists $wordmap->{$b4}) {
		my @words = keys %{ $wordmap->{$b4} };
		
		my @statlist = ();
		foreach my $w (@words) {
			my $count = 0;
			while ($wordmap->{$b4}->{$w} > $count) {
				push @statlist, $w;
				$count++;
			}
		}
		my $word = $statlist[int(rand(scalar(@statlist)))];
		
		delete $wordmap->{$b4}->{$word} if --$wordmap->{$b4}->{$word} < 1 ;
		
		@words = keys %{ $wordmap->{$b4} };
		delete $wordmap->{$b4} if $#words == -1;
		
		$ret = $word;
	}
	
	$ret = $self->get_random_word() if (! $ret) && ($b4 eq $_StartEnd);
	$self->{last_word_out} = $ret;
	
	logger("get_word():'$ret'") if $self->{debug};
	
	return $ret;
}

sub give_dada {
	my $self   = shift;
	my $b4     = shift || $self->{last_word_out} || $_StartEnd;
	my $last   = shift || $_StartEnd;
	
	my $ret  = '';
	
	while (my $word = $self->get_word($b4, ($b4 ne $last) )) {
		
		my $t = ($word =~ m/^([$self->{punct}])$/) ? '' : ' ';
		$ret .=  $t.$word;
		
		last if $word eq $last;
		
		$b4 = '';
	}
	
	logger("give_dada() returns: $ret", INFO) if $ret;
	
	return $ret;
}

sub get_random_word {
	my $self = shift;
	
	my $ret = '';
	
	my @words = keys %{ $self->{wordmap} };
	my $num   = scalar(@words);
	if ($num) {
		$ret = $words[int(rand($num))];
	}
	logger("random word:'$ret' /$num") if $self->{debug};
	
	return $ret;
}

## getter and setter

sub punct {
	my $self = shift;
	my $val  = shift;
	
	if (defined $val) {
		$self->{punct} = $val;
		logger('SET punct TO:', $self->{punct}) if $self->{debug};
	}
	
	return $self->{concat};
}

sub concat {
	my $self = shift;
	my $val  = shift;
	
	if (defined $val) {
		$self->{concat} = $val ? 1 : 0;
		logger('SET concat TO:', $self->{concat}) if $self->{debug};
	}
	
	return $self->{concat};
}

1;

__END__

=head1 NAME

MOI::NetArt::Dada::Text - DaDaing text ... 

=head1 SYNOPSIS

  use MOI::NetArt::Dada::Text;
  
  my $dada = MOI::NetArt::Dada::Text->new(
                  punct  => ',;.:?!',
                  concat => 1,
                  debug  => 0,
  );
  
  local $/ = undef;
  while (<STDIN>) { $dada->add($_) }

=head1 DESCRIPTION

This module can be used to dada text in a Markov way. Search for 'Markov-Chains',
if you wan't more to know.

Feeding various text(fragment)s to a textbase. The words will be mapped to the
word before and the word. In this map a every of this word-pairs will be counted.

Then if the text is already feeded, you can query a text from this pool of words.
The counter of the map will be decremented for each returned pair, so the number
of words is limited to the textbase ...
You can query the text word by word, or you can query a whole dada of text.

=head1 METHODS

=head2  new( [option=>value ...])

Creates a new instance of this class.

Example:

 my $dada = MOI::NetArt::Dada::Text->new();

=over 10

=item I<punct>

defining the punctuation chars

default: ',;.:?!'

=item I<concat>

If concat is set, the feeded text is appended to the text before

default: 0

=back

=head2  feed( $text )

feeds the C<$text> string to the wordmap and returns the number of feeded words.

=head2  get_word( [ $b4 ] )

returns a word wich is mapped after C<$b4>. If C<$b4> is not set the last
returned word is used.

The pair C<$b4> - returned word in decremented in the word map.

=head2  give_dada( [ $nw ] )

returns a comlete dadatext wich is mapped after C<$nw>. 
If C<$nw> is not the I<last word out> is used.

The resulted b4-word-pairs are decremented/removed in the wordmap.

=head2  get_random_word()

returns a randomly chosen word from the wordmap. This is used to find
a first word, if no more words with the b4 C<.> are given in the wordmap.

=head1 SEE ALSO

L<MOI::Base>

=head1 AUTHOR

Richard Leopold, E<lt>moi-perl@leo.0n3.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2003 by Richard Leopold

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut
