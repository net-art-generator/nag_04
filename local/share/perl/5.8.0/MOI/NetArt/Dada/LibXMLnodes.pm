# $Header: /SPACE/cycle/cvsroot/moi-perl/MOI/NetArt/Generator/lib/MOI/NetArt/Dada/LibXMLnodes.pm,v 1.4 2003/06/28 23:57:27 leo Exp $
#
# Copyright (c) 2003 Richard Leopold <moi-perl@leo.0n3.org>. All rights reserved.
#
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
##

package MOI::NetArt::Dada::LibXMLnodes;

use 5.008;
use strict;
use warnings;

require Exporter;
use MOI::Base qw(:moiLogger);

our @ISA = qw(Exporter MOI::Base);

our $VERSION = '0.01';

sub new {
	my $proto  = shift;
	my $class  = ref($proto) || $proto;
	my $parent = ref($proto) && $proto;
	
	my $self = { 
	             max_stack_out_size => 7,
	             max_nodes_out      => 777,
	             names_out_stack    => [''],
	             nodes_count        => {in => 0, out => 0, stored => 0},
	             namemap            => {},
	             nodebase           => {},
	             @_
	           };
	$self = $class->SUPER::new( %{ $self } );
	bless ($self, $class);
	return $self->_init__MOI_NetArt_Dada_LibXMLnodes();
}

##
# private methods
#

sub _init__MOI_NetArt_Dada_LibXMLnodes {
	my $self = shift;
	
	return $self;
}

##
# public methods
#

sub feed {
	my $self   = shift;
	my $node   = shift;
	
	return if $node->isa('XML::LibXML::Document');
	
	my $b4 = '';
	
	my $name   = $node->localname() || ref $node;
	my $parent = $node->parentNode;
	
	if ($parent->isa('XML::LibXML::Node')) {
		$b4     = $parent->localname() || ref $parent;
	}
	
	# entry to the name map
	if ( exists $self->{namemap}->{$b4}->{$name} ) { 
		$self->{namemap}->{$b4}->{$name}++;
	}
	else { $self->{namemap}->{$b4}->{$name} = 1; }
	
	# put pointer to the nodebase
	if ( exists $self->{nodebase}->{$name} ) {
		my @nodes = keys %{ $self->{nodebase}->{$name} };
		$self->{nodebase}->{$name}->{$#nodes + 1} = $node;
	} else { $self->{nodebase}->{$name}->{0} = $node }
	
	$self->{nodes_count}->{in}++;
	$self->{nodes_count}->{stored}++;
	
	return $name;
}


sub get_node {
	my $self = shift;
	my $b4   = shift || $self->{names_out_stack}->[0];
	
	my $name     = undef;
	my $node    = undef;
	if ( rand(scalar @{ $self->{names_out_stack} } ) > $self->{max_stack_out_size} ) {
		logger(sprintf('randomized max_stack_out_size reached: %i > %i',
		               scalar @{ $self->{names_out_stack} },
		               $self->{max_stack_out_size}), INFO);
		$b4 = '--thisnameneverexitssowebreakdown--';
	}
	
	my $map = $self->{namemap};
	if (exists $map->{$b4}) {
		# get name from namemap
		my @names = keys %{ $map->{$b4} };
		
		my @statlist = ();
		foreach my $w (@names) {
			my $count = 0;
			while ($map->{$b4}->{$w} > $count) {
				push @statlist, $w;
				$count++;
			}
		}
		$name = $statlist[int(rand(scalar(@statlist)))];
		
		# handle namemap
		delete $map->{$b4}->{$name} if --$map->{$b4}->{$name} < 1 ;
		@names = keys %{ $map->{$b4} };
		delete $map->{$b4} if $#names == -1;
		
		if (exists $self->{nodebase}->{$name} ) {
			# get node from nodebase
			my @n = keys %{ $self->{nodebase}->{$name} };
			my $n = $n[int(rand($#n + 1))];
			$node = $self->{nodebase}->{$name}->{$n};
			# handle the nodebase
			delete $self->{nodebase}->{$name}->{$n};
			my @names = keys %{ $self->{nodebase}->{$name} };
			delete $self->{nodebase}->{$name} if $#names == -1;
			
			$self->{nodes_count}->{out}++;
			$self->{nodes_count}->{stored}--;
		}
		
		unshift @{ $self->{names_out_stack} }, $name;
	} else {
		$b4 = shift @{ $self->{names_out_stack} };
	}
	return $node;
}

sub give_dada {
	my $self = shift;
	my $b4 = shift || 'XML::LibXML::Document';
	
	my $ret    = undef;
	my $last   = undef;
	my $count  = 0;
	
	while (1) {
			
		if ( $self->{nodes_count}->{out} >= $self->{max_nodes_out} ) {
			logger('max_nodes_out reached: '. $self->{max_nodes_out}, INFO);
			last;
		}
		
		my $node  = $self->get_node($b4);
		
		if (defined $node) {
			
			my $clone = $node->cloneNode(0);
			
			# copy the attributes 
			if ($clone->isa('XML::LibXML::Element')) {
				my $attributes = $node->attributes();
				
				# How to access this shit XML::LibXML::NamedNodeMap - directly HACK
				foreach my $attr (keys %{ $attributes->{NodeMap} }) {
					my $val  = $attributes->{NodeMap}->{$attr}->getValue;
					$clone->setAttribute($attr, $val);
				}
			}
			
			if (defined $ret) { # root already existent
				
				$last->insertAfter($clone, undef);
				
				$last = $clone;
				
			}
			else {  # create root / document node
				$last = $ret = $clone;
			}
			
			$b4 = undef;
			$count++;
			
		} elsif (defined $last) {
			
			$last = $last->parentNode;
			last if ! defined $last;
			
			$b4 = $last->localname() || ref $last;
		} else {
			logger('leaving give_dada() loop - No node given from get_node() ?!', WARNING);
			last;
		}
	}
	
	logger("give_dada() returns dada with $count document nodes", INFO);
	
	return $ret;
}

## getter and setter

1;

#__END__

=head1 NAME

MOI::NetArt::Dada::LibXMLnodes - DaDaing LibXML Nodes ... 

=head1 SYNOPSIS

  use MOI::NetArt::Dada::LibXMLnodes;
  
  my $dada = MOI::NetArt::Dada::LibXMLnodes->new(
                  max_stack_out_size  => 7,
                  max_nodes_out       => 777,
                  debug  => 0,
  );

=head1 DESCRIPTION

This module can be used to dada LibXML-nodes in a Markov way. 
Search for 'Markov-Chains', if you wan't more to know.

Adding various document nodes to a nodebase. The nodes will be mapped to the
parent nodenaqme and the nodename. In this namemap every of this nodename-pairs
will be counted.

Then if the nodes are already feeded, you can query a document from this pool
of nodes.
The counter of the namemap will be decremented for each returned pair, so the 
umber of nodes is limited to the nodebase ...
You can query the nodebase node by node, or you can query a whole dada of 
LibXMLnodes.

=head1 METHODS

=head2  new( [option=>value ...])

Creates a new instance of this class.

Example:

 my $dada = MOI::NetArt::Dada::LibXMLnodes->new();

=over 10

=item I<max_stack_out_size>

defining the maximum depth of LibXMLnodes while generating a Dada.

default: 7

=item I<max_nodes_out>

defining the maximum number of nodes for generating a Dada.

default: 777

=back

=head2  feed( $node )

feeds the LibXML-C<$node> (reference) to the nodemap. Returns the nodename.

Document nodes will not be feeded to the nodebase. Please feed the
$doc->documentElement() instead.

=head2  get_node( [ $b4 ] )

returns a node wich is mapped after the node with the name C<$b4>. 
If C<$b4> is not set the last returned nodename is used. If no one
returned before, then the name is a empty string.

The pair "parentname - nodename" will be decremented in the node map.

=head2  give_dada( [ $nw ] )

returns a comlete DocumentObjectModel wich is mapped after the nodename 
C<$nw>. If C<$nw> is not set 'XML::LibXML::Document' is used; - this 
means the dada starts at the document root node.

The resulted nodename-pairs are decremented/removed in the wordmap.

=head1 SEE ALSO

L<MOI::Base>

=head1 AUTHOR

Richard Leopold, E<lt>moi-perl@leo.0n3.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2003 by Richard Leopold

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut
