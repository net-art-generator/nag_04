# $Header: /SPACE/cycle/cvsroot/moi-perl/MOI/Error/Error.pm,v 1.3 2003/06/30 09:51:34 leo Exp $
#
# Copyright (c) 2003 Richard Leopold <moi-perl@leo.0n3.org>.
# All rights reserved.
#
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
##

package MOI::Error;

use 5.008;
use strict;
use warnings;

use Error 0.15 qw(:try);

require Exporter;

our @ISA = qw(
              Exporter
              Error
             );

our @EXPORT_OK   = qw(try with finally except otherwise);
our %EXPORT_TAGS = (try => \@EXPORT_OK);

# $Version$
our $VERSION = '0.02';

package MOI::Error::Simple;

@MOI::Error::Simple::ISA = qw(Error::Simple);

1;
__END__

=head1 NAME

MOI::Error - Perl extension for a MOI error eg exception handling

=head1 SYNOPSIS

 use MOI::Error qw(:try);
 try {
     throw MOI::Error::Simple("ERROR", 2);
     # never reached 
 }
 catch MOI::Error::Simple with {
     my $err = shift;
     # got the reference to the error-object
     print $err->value;
     print $err->text;
 }
 finally {
    # do something final 
 };

=head1 ABSTRACT

This module is a Clone of the L<Error> module. It imports the whole L<Error>
module and provides to you its functions and classes.
So this module is only a wrap of L<Error> to the L<MOI> namespace.

=head1 DESCRIPTION

For a detailed description please look at the L<Error>-module documentation.

=head2 EXPORT

:try - try with finally except otherwise

=head1 SEE ALSO

L<Error> orginally from Graham Barr E<lt>gbarr@ti.comE<gt>
distributed by Arun Kumar U E<lt>u_arunkumar@yahoo.comE<gt> on CPAN.

=head1 AUTHOR

Richard Leopold, E<lt>moi-perl@leo.0n3.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2003 by Richard Leopold

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut
