# $Header: /SPACE/cycle/cvsroot/moi-perl/MOI/NetArt/Generator/lib/MOI/NetArt/Generator.pm,v 1.10 2003/07/01 23:20:07 leo Exp $
#
# Copyright (c) 2003 Richard Leopold <rl@0n3.org>. All rights reserved.
#
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
##

package MOI::NetArt::Generator;

use 5.008;
use strict;
use warnings;

use Carp;
use WWW::Search;
use LWP::UserAgent;

use XML::LibXML;

use URI::WithBase;

use IO::File;
use IO::Dir;

use MOI::Base qw(:moiLogger);
use MOI::Error qw(:try);

use MOI::NetArt::Generator::SearchEngine;

use MOI::NetArt::Dada::Text;
use MOI::NetArt::Dada::LibXMLnodes;

# Package Variables

our $VERSION = '0.01';
#our $VERSION = sprintf("%d.%02d", q$Revision: 1.10 $ =~ /(\d+)\.(\d+)/o);

our @ISA = qw(MOI::Base);

our $_Debug = 0; # Debug switch for functions

sub new {
	my $proto  = shift;
	my $class  = ref($proto) || $proto;
	my $parent = ref($proto) && $proto;
	
	my $self = {  title           => 'MOI art of net',
	
	              initiator       => '',
	
	              outfile         => '/tmp/RESULT.html',
	
	              search_cfg      => undef, # use default if not set
	              search_backends => [],
	              search_maximum  => 10,
	              search_randomly => 1,
	
	              max_doc_size    => '200k',
	
	              ignored_tags    => [qw(script noscript noframes frameset iframe)],
	
	              tidx            => {},
	
	              useragent      => { #see: LWP::UserAgent->new() options
	                                   agent     => "moiNAG $VERSION",
	                                   from      => undef,
	                                   env_proxy => 1,
	                                   timeout   => 1,
	                                 },
	
	              dadatext       => { # see MOI::NetArt::Dada::Text->new options
	                                },
	
	              dadanodes      => { # see MOI::NetArt::Dada::Nodes->new options
	                                   max_stack_out_size => 7,
	                                   max_nodes_out      => 777,
	                                },
	
	              xmlparser      => { # see XML::LibXML->new() options
	                                   validation => 1,
	                                   pedantic_parser => 1,
	                                   keep_blanks => 1,
	                                 },
	
	              test            => 0,
	              offline_dir     => undef,
	              _useragent      => undef,
	              _dadatext       => undef,
	              _xmlparser      => undef,
	              _search         => undef,
	              _resultdoc      => undef,
	             @_
	           };
	
	$self = $class->SUPER::new( %{ $self } );
	bless ($self, $class);
	return $self->_init__MOI_NetArt_Generator();
}
##
# private methods
#

sub _init__MOI_NetArt_Generator() {
#
# base inititialisation the NAG
#
##
	my $self = shift;
	
	return $self if $self->{test};
	
	$self->useragent($self->{useragent});   # init useragent
	$self->xmlparser($self->{xmlparser});   # init libXML-parser
	
	$self->search_cfg($self->{search_cfg})
		or $self->{_search} = MOI::NetArt::Generator::SearchEngine->new(
		                          useragent => $self->{_useragent},
		                          debug     => $self->{debug}
		                      ); # init search_engine
	
	$self->max_doc_size($self->{max_doc_size});
	
	$self->dadatext($self->{dadatext});
	$self->dadanodes($self->{dadanodes});
	
	if ($self->{offline_dir}) {
		$self->_read_offline_dir();
	} else {
		$self->_query_search_engine();
		$self->_fetch_resources();
	}
	
	$self->_parse_docs();
	$self->_work_on_parsed_documents();
	
	return $self;
}

sub _read_offline_dir {
#
# reads the HTML files out of the offline_dir and builds
# the tidx hash.
#
# the filenames of the files are URLstrings where the slashes are
# substituted with @@ so http://www.0n3.org goes http:@@@@www.0n3.org
#
	my $self = shift;
	
	my $path  = $self->{offline_dir} or croak 'missing offline_dir';
	my $count = 0;
	
	my $dh = IO::Dir->new($path) or croak "Can't open offline directory $path";
	while (my $file = $dh->read) {
		next if $file =~ m/^\./;
		next if $file !~ m|^\w+:@@@@|;  # http:, ftp: ...
		my $name = $file;
		$name =~ s|@@|/|g;
		
		local $/;
		my $fh = IO::File->new("< $path/$file") or die "Can't open $path/$file";
		my $content = <$fh>;
		undef $fh;
		# faking a HTTP Response
		$self->{tidx}->{$name} = HTTP::Response->new();
		$self->{tidx}->{$name}->content($content);
		logger("offline file: $path/$file");
		$count++;
	}
	undef $dh;
	
	return $count;
}

sub _query_search_engine {
#
# query the searchengine and store the URLs to the tidx hash
##
	my $self = shift;
	
	$self->{_search}->query($self->{title}, @{ $self->{search_backends} });
	%{ $self->{tidx} } = ( %{ $self->{tidx} }, 
	                       %{ $self->{_search}->fetch_result($self->{search_maximum},
	                                                         $self->{search_randomly}) } );
	
	return $self;
}

sub _fetch_resources {
#
# looping through the tidx URL keys and fetch the resource storing it as value ...
## 
	my $self = shift;
	
	# first get only the HEAD for further selection
	my @urls = sort {rand > 0.5 ? 1 : -1} keys %{ $self->{tidx} };
	logger(sprintf("%d documents to fetch", scalar(@urls)), INFO);
	for my $url ( @urls ) {
		my $req = HTTP::Request->new(HEAD => $url);
		
		my $res = $self->{_useragent}->request($req);
		do { 
			logger("HEAD $url FAILED", INFO);
			delete $self->{tidx}->{$url};
			next;
		} if $res->is_error || $res->code != 200;
		
		logger("HEAD $url OK", INFO);
		
		# we need only text/html
		my $type = $res->headers->header('Content-Type');
		if ($type !~ m|^text/html|i) {
			logger("we don't need $type", INFO);
			delete $self->{tidx}->{$url};
			next;
			
		}
		my $size = $res->headers->header('Content-Length') || $self->{max_doc_size} + 1;
		if ($size > $self->{max_doc_size}) {
			logger("maximum docsize reached with $size bytes", INFO);
			delete $self->{tidx}->{$url};
			next;
		}
		
		# fetch the rest
		$req = HTTP::Request->new(GET => $url);
		$res = $self->{_useragent}->request($req);
		do { 
			logger("GET $url FAILED", INFO);
			delete $self->{tidx}->{$url};
			next;
		} if $res->is_error || $res->code != 200;
		
		logger("GET $url OK", INFO);
		$self->{tidx}->{$url} = $res;
		
		if ($self->{debug}) {
			# on DEBUG drop the sourcefile to /tmp
			try {
				my $fn = $url;
				$fn  =~ s|/|@@|g;
				$fn  = "/tmp/$fn";
				
				my $fh = IO::File->new("> $fn") or die "can't open $fn";
				print $fh $self->{tidx}->{$url}->content();
				undef $fh;
				
				logger("dropped document to $fn");
			} otherwise {
				my $err = shift;
				logger($err, WARNING);
			};
		}
		
	}
	
	return $self;
}

sub _parse_docs {
## replace stored docs with their valid parse trees
# - if the parser throws an exception, the doc is deleted from the index.
## 
	my $self = shift;
	
	my @urls = keys %{ $self->{tidx} };
	logger(sprintf("%d documents left to parse", scalar(@urls)), INFO);
	for my $url ( @urls ) {
		logger("parse $url => " . ref $self->{tidx}->{$url}) if $self->{debug};
		die (sprintf("expected HTTP::Response met '%s'", ref $self->{tidx}->{$url}))
			if ref $self->{tidx}->{$url} ne 'HTTP::Response';
		
		my $doc = $self->{tidx}->{$url}->content();
		try {
			$self->{tidx}->{$url} = $self->{_xmlparser}->parse_html_string($doc);
		}
		otherwise {
			my $err = shift;
			
			logger("parse $url FAILED", WARNING);
			dumper($err) if $self->{debug};
			
			delete $self->{tidx}->{$url};
		};
	}
	return $self;
}

sub _work_on_parsed_documents {
	my $self = shift;
	
	local $_Debug = $self->{debug};
	
	my $filter = sprintf('not(name() = "%s")', join('" or name() = "', @{ $self->{ignored_tags} }));
	logger("XPath filter: $filter") if $self->{debug};
	
	my @urls = keys %{ $self->{tidx} };
	logger(sprintf("%d documents left to dada", scalar(@urls)), INFO);
	foreach my $url ( @urls ) {
		logger("process $url", INFO);
		my @nodes = ();
		try {
			push @nodes, $self->{tidx}->{$url}->findnodes("descendant::*[$filter]");
			push @nodes, $self->{tidx}->{$url}->findnodes("descendant::text()");
		} otherwise {
			my $err = shift;
			
			logger("findnodes on $url FAILED", WARNING);
			dumper($err) if $self->{debug};
			
			delete $self->{tidx}->{$url};
		};
		foreach my $n (@nodes) {
			_exp_url_attr_cb($url, $n);
			$self->_feed_dada_cb($n);
		}
	}
	return $self;
}

sub _merge_uris {
#
# helper function to *merge* two URIs !
#
# Examples:
#          http://www.ne.jp/asahi/nsc/gon
#        + 51.html
#        = http://www.ne.jp//asahi/nsc/gon/51.html
#
	my $uri_a = shift || croak('NEED just one URL ...');
	my $uri_b = shift || '';
	
	my $uri = URI::WithBase->new($uri_b, $uri_a);
	my $r   = $uri->abs();
	
	logger(sprintf('merge_uri: %s + %s => %s', $uri_a, $uri_b, $r )) if $_Debug;
	return $r;
}

sub _exp_url_attr_cb {
#
# helper function
# look for attributed URL in the given node. The basepath must be prepended to find
# further document sources like pictures, etc.
# 
	my $url   = shift;
	my $node  = shift;
	
	return if ! $node->isa('XML::LibXML::Node');
	
	if ($node->isa('XML::LibXML::Element')) {
		my $attributes = $node->attributes();
		# How to access this shit XML::LibXML::NamedNodeMap ?! - directly HACK !
		foreach my $attr (keys %{ $attributes->{NodeMap} }) {
			
			if ($attr =~ m/^src|href$/) {
				my $val  = $attributes->{NodeMap}->{$attr}->getValue;
				
				my $merge = _merge_uris($url, $val);
				$node->setAttribute($attr, $merge); # and now via API - ugly !
				
				logger("reset attribute '$attr' from '$val' to '$merge'") if $_Debug;
			}
		}
	}
	
	return 1;
}

sub _feed_dada_cb {
	my $self = shift;
	my $node = shift;
	
	for (ref $node) {
			
		/XML::LibXML::Text/ and do {
			# feed the dadatext
			
			my $str = $node->nodeValue;
			
			# don't feed empty textnodes
			return if $str =~ m/^\s*$/;
			
			$self->dadatext->feed($str);
			
			if ( $self->{debug} ) {
				my $s = substr($str, 0, 31);
				$s =~ s/\s+/ /g;
				$s =~ s/^\s+|\s+$//g;
				$s .= ' ...' if length($str) > 32;
				logger("feed dadatext: '$s'");
			}
		};
	}
	
	$self->dadanodes->feed($node);
	logger("feed dadanode: " . ($node->localname || ref $node)) if $self->{debug};
	
	return 1;
}

# small output beautifier
# helper function.
sub _beautify {
	my $x     = shift;
	
	$x =~ s/\s+/ /g;
	$x =~ s/\s*\n\s*//g;
	$x =~ s/>\s+</></g;
	$x =~ s|(</?[^>]*>)|\n$1\n|g;
	$x =~ s/^\s+//;
	
	return $x;
};

sub _do_tidx_xpath {
#
# search all DOMs in tidx with xpath
#
	my $self  = shift;
	my $xpath = shift; # /html/head/meta[normalize-space(@http-equiv)='content-type']
	
	my @ret = ();
	foreach my $url (keys %{ $self->{tidx} } ) {
		push @ret, $self->{tidx}->{$url}->findnodes($xpath);
	}
	return wantarray() ? @ret : \@ret;
}

sub _insert_head {
#
# This helper generates a HTML <head>
#
	my $self = shift;
	
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday) = gmtime();
	my $time = sprintf('%0.4d-%0.2d-%0.2dT%0.2d:%0.2d:%0.2d+00:00', 
	                    $year + 1900, $mon + 1, $mday, $hour, $min, $sec);
	
	# dadaing keywords
	my $keywords = MOI::NetArt::Dada::Text->new(); 
	foreach ($self->_do_tidx_xpath( q(/html/head/meta[normalize-space(@name)='keywords']) )) {
			foreach my $a ( $_->attributes() ) {
				if ($a->localname() eq 'content')  { $keywords->feed($a->getValue()) }
			}
	}
	# dadaing description
	my $desc = MOI::NetArt::Dada::Text->new(); 
	foreach ($self->_do_tidx_xpath( q(/html/head/meta[normalize-space(@name)='description']) )) {
			foreach my $a ( $_->attributes() ) {
				if ($a->localname() eq 'content')  { $desc->feed($a->getValue()) }
			}
	}
	
	my $str = sprintf('<head>
<title>\'%s\'%s</title>
<meta name="content-type"   content="text/html; charset=UTF-8" />
<meta name="generator"      content="moiNAG %s" />
<meta name="date"           content="%s" />
<meta name="robots"         content="noindex, nofollow" />
<meta name="keywords"       content="%s" />
<meta name="description"    content="%s" />
</head>
',
	$self->{title},
	($self->{initiator} ? ' (by ' . $self->{initiator} . ')' : ''),
	$VERSION,
	$time,
	$keywords->give_dada(),
	$desc->give_dada()
	);
	
	my $gen = $self->{_xmlparser}->parse_html_string($str);
	my $head = $gen->findnodes('/html/head')->pop();
	my $root = $self->{_resultdoc}->documentElement();
	$root->insertBefore( $head, undef);
	
	return ;#$head;
}

##
# public methods
#

sub generate {
#
# generate a peace of art and write it to outfile
##
	my $self = shift;
	
	## setting possible Values for ONE document - HACKY
	$self->{_dadanodes}->{namemap}->{'html'}->{'body'}  = 1;    # one body
	delete $self->{_dadanodes}->{namemap}->{'html'}->{'head'};  # No head
	
	my $root = $self->{_dadanodes}->give_dada();
	
	if (! defined $root) {
		logger("No LibXMLnodes DaDa generated - A possible reason is: There no valid Documents found,"
		       ." and so no nodes feeded to the Dada engine", INFO);
		return 0;
	}
	
	# shortcuts
	my $doc = $self->{_resultdoc} =  XML::LibXML::Document->new("1.0", "UTF8");
	my $dt  = $self->{_dadatext};
	
	$doc->createInternalSubset( "HTML", "-//W3C//DTD HTML 4.01//EN", undef );
	$self->{_resultdoc}->setDocumentElement( $root );
	
	foreach my $n ($doc->findnodes("descendant::text()")) {
		my $text = $dt->give_dada();
		$n->setData($text);
	}
	
	## inserting the HEAD of document
	$self->_insert_head();
	
	my $str = $doc->toStringHTML();
	# a small HTML beautyfier
	$str = _beautify($str);
	
	my $fh = IO::File->new("> " . $self->{outfile}) or die "Can't open " . $self->{outfile};
	print $fh $str;
	undef $fh;
	
	return 1;
}

##
# get-/setter - NOT  public by this time ... only needed by _init..()

sub title {
#
# gets/sets the title of the piece of art
##
	my $self = shift;
	my $val  = shift;
	
	if (defined $val) {
		$self->{title} = $val;
		dumper('SET title TO:', $self->{title}) if $self->{debug};
	}
	
	return $self->{title};
}

sub initiator {
#
# gets/sets the initiator of the piece of art
##
	my $self = shift;
	my $val  = shift;
	
	if (defined $val) {
		$self->{initiator} = $val;
		dumper('SET initiator TO:', $self->{initiator}) if $self->{debug};
	}
	
	return $self->{initiator};
}

sub outfile {
#
# gets/sets the outfilename of the piece of art
##
	my $self = shift;
	my $val  = shift;
	
	if (defined $val) {
		$self->{outfile} = $val;
		dumper('SET outfile TO:', $self->{outfile}) if $self->{debug};
	}
	
	return $self->{outfile};
}

sub search_cfg {
#
# gets/sets the search_cfg config HASH ref or filename 
##
	my $self = shift;
	my $val  = shift;
	
	if (defined $val) {
		$self->{search_cfg} = $val;
		$self->{_search}  = MOI::NetArt::Generator::SearchEngine->new(
		                       useragent => $self->{_useragent},
		                       debug     => $self->{debug},
		                       cfg       => $self->{search_cfg}
		                    );
		dumper('SET search_cfg TO:', $self->{search_cfg}) if $self->{debug};
	}
	
	return $self->{search_cfg};
}

sub search_backends {
#
# gets/sets the search_baqckends to query
##
	my $self = shift;
	my $val  = shift;
	
	if (defined $val) {
		$self->{search_backends} = $val;
		dumper('SET search_backends TO:', $self->{search_backends}) if $self->{debug};
	}
	
	return $self->{search_backends};
}

sub max_doc_size {
# 
# gets/sets the max_doc_size in Bytes to retrieve.
##
	my $self = shift;
	my $val  = shift;
	
	if (defined $val) {
		# check
		if ($val =~ m/^(\d+)(|k|M|G){1}$/) {
			my $fac = { '' => 1, k => 1024, M => 1024*1024, G => 1024*1024*1024};
			$val = $1 * $fac->{$2}
		} else { croak('max_doc_size should match /^(\d+)(|k|M|G){1}$/') }
		
		$self->{max_doc_size} = $val;
		
		dumper('SET max_doc_size TO:', $self->{max_doc_size}) if $self->{debug};
	}
	
	return $self->{max_doc_size};
}

sub offline_dir {
# 
# Sets/gets the offline directory
##
	my $self = shift;
	my $val  = shift;
	
	
	if (defined $val) {
		$self->{offline_dir} = $val;
		dumper('SET test TO:', $self->{offline_dir}) if $self->{debug};
	}
	
	return $self->{offline_dir};
}

sub test {
# 
# Sets/gets test as BOOL
##
	my $self = shift;
	my $val  = shift;
	
	if (defined $val) {
		$self->{test} = ($val ? 1 : 0);
		dumper('SET test TO:', $self->{test}) if $self->{debug};
	}
	
	return $self->{test};
}

sub useragent {
#
# Sets/creates the needed LWP::UserAgent with the given HASH ref as options.
# Even when no HASH ref is given the LWP::UserAgent is returned.
##
	my $self = shift;
	my $val  = shift;
	
	if (defined $val) {
		%{ $self->{useragent} } = (%{ $self->{useragent} }, %{ $val }); # merge hashes
		
		dumper('SET useragent WITH:', $self->{useragent}) if $self->{debug};
		
		$self->{_useragent} = LWP::UserAgent->new(%{ $self->{useragent},  });
		
		logger(sprintf('using useragent "%s" from "%s"', 
		               $self->{_useragent}->agent,
		               $self->{_useragent}->from || ''), INFO) if $self->{debug};
	}
	
	return $self->{_useragent};
}

sub xmlparser {
#
# Sets/creates the needed XML::LibXML with the given HASH ref as options.
# Even when no HASH ref is given the XML::LibXML parser is returned.
##
	my $self = shift;
	my $val  = shift;
	
	if (defined $val) {
		%{ $self->{xmlparser} }  = (%{ $self->{xmlparser} }, %{ $val });
		
		dumper('SET xmlparser WITH:', $self->{xmlparser}) if $self->{debug};
		
		$self->{_xmlparser} = XML::LibXML->new();
		
		# can't pass options directly ...
		foreach my $key (keys %{ $self->{xmlparser} }) {
			try {
				eval sprintf('$self->{_xmlparser}->%s(%s)', $key, $self->{xmlparser}->{$key});
				die($@) if $@;
			}
			otherwise {
				my $err = shift;
				logger("can't set parser option: $_", WARNING);
				dumper($err);
			};
		}
	}
	
	return $self->{_xmlparser};
}

sub dadatext {
#
# Sets/creates the needed MOI::NetArt::Dada::Text with the given HASH ref
# as options. Even when no HASH ref is given the MOI::NetArt::Dada::Text
# is returned.
##
	my $self = shift;
	my $val  = shift;
	
	if (defined $val) {
		%{ $self->{dadatext} }  = (%{ $self->{dadatext} }, %{ $val });
		
		dumper('SET dadatext WITH:', $self->{dadatext}) if $self->{debug};
		
		$self->{_dadatext} = MOI::NetArt::Dada::Text->new(%{ $self->{dadatext} })
	}
	
	return $self->{_dadatext};
}

sub dadanodes {
#
# Sets/creates the needed MOI::NetArt::Dada::Nodes with the given HASH ref
# as options. Even when no HASH ref is given the MOI::NetArt::Dada::Nodes
# is returned.
##
	my $self = shift;
	my $val  = shift;
	
	if (defined $val) {
		%{ $self->{dadanodes} } = (%{ $self->{dadanodes} }, %{ $val });
		
		dumper('SET dadanodes WITH:', $self->{dadanodes}) if $self->{debug};
		
		$self->{_dadanodes} = MOI::NetArt::Dada::LibXMLnodes->new(%{ $self->{dadanodes} })
	}
	
	return $self->{_dadanodes};
}

1;

=head1 NAME

MOI::NetArt::Generator - shortly NAG


=head1 ABSTRACT

B<MOI::NetArt::Generator> - is the attempt to get rich while I<the machine
does the work> by generating unique peaces of art.


=head1 SYNOPSIS

 use MOI::NetArt::Generator;
 
 my $nag = MOI::NetArt::Generator->new(
	title           => 'MOI art of net',
	outfile         => '/tmp/RESULT.html',
	search_engines  => [qw(AltaVista)],
	search_maximum  => 10,
	max_doc_size    => 200k
 );
 
 $nag->generate();

=head1 DESCRIPTION

The B<MOI::NetArt::Generator> offers a class to generate I<NetArt>.

I<NetArt>, that means a special kind of, is a HTML-document that is
randomly generated from the source of given HTML-documents.
The source URLs can be given and/or fund by search-backends via a 
given searchstring; - the title of the peace of NetArt.  

=head1 METHODS

=head2 new( [option=>value ...])

Member function and global function.

Creates a new instance of this class.

Example:

    my $nag = MOI::NetArt::Generator->new( title => 'MOI art of net' );

=over 10

=item I<title>

giving this peace of art a title.

default: 'MOI art of net'

=item I<initiator>

the initiators name.

default: ''

=item I<search_cfg>

reference to a backend definition HASH for the search engine module.
Or, if the HASH is placed in a file: the filename of this file

If L<undef> the L<MOI::NetArt::Generator::SearchEngine> default ist used.

default: undef

=item I<search_backends>

reference to an array of search backends to query. The given backends can be 
configured using the I<search_cfg> attribute.

See L<MOI::NetArt::Generator::SearchEngine/query()> for more info.

default: []

=item I<search_maximum>

The maximum number of fetched results from the search engine.

default: 10

=item I<max_doc_size>

The maximum size of document to be accepted as source. 
This term should match:  C<^(\d+)(|k|M|G){1}$>

default: 200k

=item I<ignored_tags>

default:
 [qw(script noscript noframes frameset)]

=item I<tidx>

default: {}

=item I<useragent>

see: LWP::UserAgent->new() options

default: { 
   agent     => "moiNAG $VERSION",
   from      => undef,
   env_proxy => 1,
   timeout   => 1
 }

=item I<dadatext>

see MOI::NetArt::Dada::Text->new() options

default: {}

=item I<dadanodes>

see MOI::NetArt::Dada::Nodes->new() options

default: {}

=item I<xmlparser>

see XML::LibXML->new() options

default: { 
   validation      => 1,
   pedantic_parser => 1,
   keep_blanks     => 1 
 }

=item I<test>

only used for testing ...

default: 0

=item I<offline_dir>

only used for testing ...

default: undef

=back

=head2 I<generate()> 

generates a document object from the feeded documents and write it to the
outfile as a HTML document.

=head1 EXPORT

None by default.


=head1 SEE ALSO

L<Perl>
L<MOI>, L<MOI::Error>, L<MOI::Logger>,
L<MOI::NetArt::Dada>, L<MOI::NetArt::Dada::Text>, L<MOI::NetArt::Dada::LibXMLnodes>
L<MOI::NetArt::Generator::SearchEngine>

=head1 AUTHOR

Richard Leopold, E<lt>moi-perl@leo.0n3.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2003 by Richard Leopold

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut
