# $Header: /SPACE/cycle/cvsroot/moi-perl/MOI/NetArt/Generator/lib/MOI/NetArt/Generator/SearchEngine.pm,v 1.9 2003/07/02 18:59:41 leo Exp $
#
# Copyright (c) 2003 Richard Leopold <rl@0n3.org>. All rights reserved.
#
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
##

package MOI::NetArt::Generator::SearchEngine;

use 5.008;
use strict;
use warnings;

use MOI::Base qw(:moiLogger);
use MOI::Error qw(:try);

use Carp;
use WWW::Search;
use URI;

eval { require MOI::NetArt::Generator::SearchEngine::Config };

# Package Variables

our $VERSION = '0.01';

our @ISA = qw(MOI::Base);

# Constructor

sub new {
	my $proto  = shift;
	my $class  = ref($proto) || $proto;
	my $parent = ref($proto) && $proto;
	
	my $self = {  cfg          => (defined $MOI::NetArt::Generator::SearchEngine::Config::Backends
	                               ? $MOI::NetArt::Generator::SearchEngine::Config::Backends
	                               : {} ),
	              useragent    => undef,
	              _result      => {},
	              _fetch_stack => [],
	             @_
	           };
	
	$self = $class->SUPER::new( %{ $self } );
	bless ($self, $class);
	return $self->_init__MOI_NetArt_Generator_SearchEngine();
}

##
# private methods
#

sub _init__MOI_NetArt_Generator_SearchEngine {
	my $self = shift;
	
	$self->cfg($self->{cfg});
	$self->useragent($self->{useragent});
	
	return $self;
}

sub _get_options {
	my $self    = shift;
	my $backend = shift;
	my $type    = shift || 'new';
	
	$type .= '_options';
	
	my $opt = exists $self->{cfg}->{$backend}->{$type}
	        ? $self->{cfg}->{$backend}->{$type}
	        : {};
	
	my $def = exists $self->{cfg}->{default}->{$type}
	        ? $self->{cfg}->{default}->{$type}
	        : {};
	
	return (%{ $def }, %{ $opt });
}

##
# public methods
#
sub query {
	my $self   = shift;
	my $query  = shift || '-- NO QUERY GIVEN --';
	
	my @backends = @_;
	@backends = keys %{ $self->{cfg} } if scalar(@backends) == 0;
	
	$self->{_result} = {}; # delete result
	
	# prepare the query
	$query =~ s/^\s*(\S.*\S)\s*$/$1/;
	
	logger('search query: '. $query, INFO);
	
	$query = WWW::Search::escape_query($query);
	
	logger('escaped search query: '. $query) if $self->{debug};
	
	# requesting the search engines
	
	foreach my $backend ( @backends ) {
		next if $backend eq 'default';
		
		logger('search backend: ' . $backend) if $self->{debug};
		
		$self->{_result}->{$backend} = [] if ! exists $self->{_result}->{$backend};
		
		my %new_options = $self->_get_options($backend, 'new');
		
		try {
		
			my $se = new WWW::Search($backend, %new_options);
			
			# HACK - setting the oSearch->{user_agent} directly ! 
			$se->{user_agent} = $self->{useragent} if defined $self->{useragent};
			
			my %query_options = $self->_get_options($backend, 'query');
			$se->native_query($query, %query_options);
			
			while ( my $ro = $se->next_result() ) {
				my $url = $ro->url();
				logger("search result: $url") if $self->{debug};
				
				my $uri = URI->new($url);
				if ( $uri->scheme() ) { 
					# storing the result in an array per backend
					unshift @{ $self->{_result}->{$backend} }, $url
				} else {
					logger("got shit from the $backend backend: $url", WARNING);
				} 
			}
		
		} otherwise {
			my $err = shift;
			logger("Can't query $backend: " . $err, WARNING);
			dumper($err) if $self->{debug};
		};
		
		
		
		logger(sprintf('found %d accepted results on %s', 
		               scalar(@{ $self->{_result}->{$backend} }),
		               $backend), INFO);
	}
	
	return 1;
}

sub fetch_result {
	my $self     = shift;
	my $num      = shift || 1;
	my $randly   = shift || 0;
	
	my $ret = {};
	while (scalar(keys( %{ $ret } )) < $num) {
		my @backends = keys %{ $self->{_result} };
		last if scalar(@backends) == 0;
		$self->{_fetch_stack} = \@backends if (scalar(@{ $self->{_fetch_stack} }) == 0);
		
		my $b = shift @{ $self->{_fetch_stack} };
		
		if (scalar( @{ $self->{_result}->{$b} } ) == 0 ) {
			delete $self->{_result}->{$b};
			next;
		}
		
		my $url;
		if ($randly) {
			my $n = rand( scalar( @{ $self->{_result}->{$b} } ) );
			$url  = splice(@{ $self->{_result}->{$b} }, $n, 1);
		} else {
			$url = shift @{ $self->{_result}->{$b} };
		}
		
		if (exists $ret->{$url}) { logger($url . " already got from " . $ret->{$url}, INFO) }
		else { $ret->{$url} = $b }
	}
	
	dumper('fetch_result returns:', $ret) if $self->{debug};
	
	return $ret;
}


# get-/setter

sub cfg {
	my $self = shift;
	my $val  = shift;
	if (defined $val) {
		# setting the backends options
		if (ref($val) eq '') {
			# must be a filename to source in ...
			
			open my $fh, "< $val" or die("can't open file $val");
			local $/ = undef;
			my $s = <$fh>;
			close $fh;
			
			$self->{cfg} = eval $s ;
			die("can't evaluate content of $val: $@") if ($@);
			
		} elsif (ref($val) eq 'HASH') {
			# must be a HASH ...
			$self->{cfg} = $val if $self->{cfg} != $val;
		} else { croak("expected option HASH ref or SCALAR as filename") }
		
		dumper('SET cfg WITH:', $self->{cfg}) if $self->{debug};
	}
	
	return $self->{cfg};
}

sub useragent {
	my $self = shift;
	my $val  = shift;
	
	
	if (defined $val) {
		croak("useragent must be an LWP::UserAgent object reference") 
			if ref($val) ne 'LWP::UserAgent';
		
		$self->{useragent} = $val if $self->{useragent} != $val;
	}
	
	if ($self->{debug} && defined $val) { 
		dumper('SET useragent WITH:', $self->{useragent}) if $self->{debug};
	}
	
	return $self->{useragent};
}

1;
__END__

=head1 NAME

B<MOI::NetArt::Generator::SearchEngine> - Bundeling a query to serveral 
Search-backends.

=head1 SYNOPSIS

 use MOI::NetArt::Generator::SearchEngine;
 
 my $se = MOI::NetArt::Generator::SearchEngine->new(
     backends => {
         AltaVista => {},
         Google    => {
             new_options     => { key => '__place your key here__' },
             query_options   => {}
         },
     },
     useragent => $ref_to_the_UA
 );

or:

 my $se = MOI::NetArt::Generator::SearchEngine->new( backends => 'my_config_filename' );
 
 $se->query('NetArt Generator');
 
 my @url = keys %{ $se->fetch_result(10) };

=head1 DESCRIPTION

This module offers an object wich bundeles a query to serveral 
Search-backends of L<WWW::Search>. The options to instance the 
backends and to generate a I<native_query> for each backend can 
be configured by a given HASH or a file. If a filename is given,
it's content would be evaluated to the HASH. So a customization
is possible.

This module is written to work in the L<MOI> enviroment to feed the
L<MOI::NetArt::Generator>

=head1 METHODS

=head2 new( backend => {} value [, ...] ), new( 'my_config_filename' )

Creates a new instance of this class.

Example:

 my $se = MOI::NetArt::Generator::SearchEngine->new(  
     backends => { AltaVista => {} }
 );
 
or:
 
 my $se = MOI::NetArt::Generator::SearchEngine->new( 
     backends => 'my_config_filename';
 );

=over 10

=item I<cfg>

a HASH reference or a filename.

The HASH must have the following structure:

 {
     backend1 => {
        new_options   => { HASH of new() options },
        query_options => { HASH of the native_query() options },
     },
     backend2 => {
         new_options   => {},
         query_options => {},
     },
     # ...
     default => {
         new_options => {
             maximum_to_retrieve => 10,
             search_debug        =>  1,
             # ...
         }
     }
 }

Please see L<WWW::Search/new> for the new_options and 
L<WWW::Search/native_query> for the query_options.

Special is the C<default> section. This defines the default values for all
search backends. But the default only makes sense with the C<new_options> ...
The UserAgent related options like I<env_proxy> will be overwritten by a given
I<useragent>.

If you will use the filename variant, so the file must contain the HASH source.
This will be loaded and evaluated to get the HASH. The filecontent looks like:

 my $cfg = {
     AltaVista => {},
     HotBot    => {},
     default => {
         new_options => { 
             maximum_to_retrieve => 10,
             search_debug        =>  7,
         }
     }
 }

If the value is C<undef> the basic configuration via 
L<MOI::NetArt::Generator::SearchEngine::Config> is used.

default: undef


=item I<useragent>

set a custom L<LWP::UserAgent> object to use. If C<undef> the L<WWW::Search> 
 internal useragent is used.

default: undef

=back


=head2 cfg( [ HASHref  | filname ] )

Sets/Gets the attribute C<cfg> ...


=head2 useragent( [ $ua ] )

Sets/Gets the attribute C<useragent> ...


=head2 query( $string [, @backends] )

pass the querystring to the given search backends. If no backend is given,
the query is passed to the configured Backends by the I<cfg> attribute.
If a backend not configured within, then the default configuration is used.


=head2 fetch_result( $num )

fetches the given number of results as a HASH reference. The keys of the HASH
are the result URLs, and the value is the first backend we found this URL ...


=head1 SEE ALSO

L<MOI::Base>, L<WWW::Search>, L<MOI::NetArt::Generator::SearchEngine::Config> 

=head1 AUTHOR

Richard Leopold, E<lt>moi-perl@leo.0n3.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2003 by Richard Leopold

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut
