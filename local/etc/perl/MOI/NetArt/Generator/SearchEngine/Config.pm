# $Header: /SPACE/cycle/cvsroot/moi-perl/MOI/NetArt/Generator/lib/MOI/NetArt/Generator/SearchEngine/Config.pm,v 1.1 2003/06/28 23:57:27 leo Exp $
#
# Copyright (c) 2003 Richard Leopold <rl@0n3.org>. All rights reserved.
#
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
##

package MOI::NetArt::Generator::SearchEngine::Config;

use 5.008;
use strict;
use warnings;

our $VERSION = '0.01';

our $Backends = {
	Yahoo     => {},
	AltaVista => {},
	Google    => {
		new_options => { 
			key=>'wOxiwvtQFHJIGSHY3R7yPIErAo+bS+ij',
		},
	},
	default => {
		new_options => { 
			maximum_to_retrieve => 100,
		},
		query_options => {}
	}
};

1;

__END__

=head1 NAME

B<MOI::NetArt::Generator::SearchEngine::Config> - Configuration for L<MOI::NetArt::Generator::SearchEngine>

=head1 SYNOPSIS

 use MOI::NetArt::Generator::SearchEngine::Config;
 
 my @search_backends = keys %{ $MOI::NetArt::Generator::SearchEngine::Config::Backends }
 
=head1 DESCRIPTION

This module is a customizeable module to configure the L<MOI::NetArt::Generator::SearchEngine>.

=head1 Variables

=head2 $Backends

is a reference to a HASH defining search backends and their options for instancing and
querying.

 our $Backends => {
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

Example:

 our $Backends = {
     AltaVista => {},
     HotBot    => {},
     default => {
         new_options => { 
             maximum_to_retrieve => 10,
         }
     }
 }

this definition can be overwritten by the I<search_cfg> attribute of 
L<MOI::NetArt::Generator::SearchEngine>.

=head1 SEE ALSO

L<MOI::NetArt::Generator::SearchEngine> 

=head1 AUTHOR

Richard Leopold, E<lt>moi-perl@leo.0n3.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2003 by Richard Leopold

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut
