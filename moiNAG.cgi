#! /usr/bin/perl
#
# $Header: /SPACE/cycle/cvsroot/moi-perl/progs/moiNAG/cgi-bin/moiNAG.cgi,v 1.6 2003/07/02 18:59:41 leo Exp $
#
# Copyright (c) 2003 Richard Leopold <moi-perl@leo.0n3.org>.
# All rights reserved.
#
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
##


use strict;
use warnings;

use CGI qw(:standard -no_xhtml *table);
use CGI::Carp qw(fatalsToBrowser);
use CGI::Pretty qw( :html3 );

use File::Spec;
use File::Path;
use File::Find;

use POSIX;

use Data::Dumper;

BEGIN { 
	# finding and setting my Perl-lib path
	use Config;
	my $dir = '/var/www/generator/moiNAG/';
	
	unshift @INC, File::Spec->catdir($dir,'local', 'share', 'perl', $Config{api_versionstring});
	unshift @INC, File::Spec->catdir($dir,'local', 'etc', 'perl');
	
	require MOI::NetArt::Generator::SearchEngine::Config;
}

my $VERSION = '$Id: moiNAG.cgi,v 1.6 2003/07/02 18:59:41 leo Exp $';

## my Configuration - simple
my $CFG = {
   # this script url 
   my_url   => sprintf('http://%s%s', $ENV{HTTP_HOST}, $ENV{REQUEST_URI}),
   # where to find the dada dir in the filesystem
   dada_dir => '/var/www/generator/moiNAG/dada/',
   # where to find the dada dir as URL
   dada_url => sprintf('http://%s/generator/moiNAG/dada/', $ENV{HTTP_HOST}),
   # give me a CSS file URL
   css_url  => sprintf('http://%s/generator/moiNAG/style.css', $ENV{HTTP_HOST}),
   # The moiNAG script
   moiNAG   => '/var/www/generator/moiNAG/local/bin/moiNAG'
};

# getting the configured SearchEngines 
my $search_engines = $MOI::NetArt::Generator::SearchEngine::Config::Backends;
delete $search_engines->{default} if exists $search_engines->{default};
$search_engines = [ keys %{ $search_engines } ];

$SIG{CHLD} = 'IGNORE';

# create new CGI object
my $q = CGI->new();

my $form_time = time();
my $html_text =<<EOF;
<p>
 The <em>moi NetArtGenerator</em> ( <b>moiNAG</b> ) is a work initiated by 
 <a href="http://www.artwarez.org">Cornelia Sollfrank</a>.
</p>
<p>
 The <b>moiNAG</b> generates HTML documents by a given <i>title</i>, 
 which is passed to searchengines as query string.
</p>
</>
 From the returned results a <i>search max</i> number of results can be returned.
 These will be downloaded, if they match a few conditions: They must be HTML documents
 and they don't have to be larger than <i>max doc size</i> bytes.
</p> 
<p>
The downloaded parseable documents will be feeded into storages of textual words
and nodes representing the HTML tags.<br>
This storages are not only simply storages, they build also 
<a href='http://page.inf.fu-berlin.de/~lind/lingausarb/node30.html'><em>Markov Chains</em></a>
out of the feeded stuff.<br> 
</p>
<p>
From the node storage will be built a new HTML document following randomly these 
<em>Markov Chains</em>. The limitation for this generation is a maximum number of nodes,
and a randomized break condition for the level of nested HTML elements resp. the depth
of the HTML node tree. 
</p>
<p>
After this the data of the text nodes will be rewritten with textual fragments given from 
the storage of textual words following their <em>Markov Chains</em>.
</p>
<p>
So <b>a Dada HTML structure filled with Dada text</b> is the result of this generator.<br>
your browser can display this result ?! - I don't know #o)<br>
To avoid some problems defined node types are filtered, e.g: <i>script noscript noframes frameset iframe</i>.
</p>
<hr width="50">
<p>
The generation of your peace of art takes a few seconds. So refresh this site until the 
state for your job is OK. <b>Or</b> follow the link and investigate the <i>log.txt</i> to see
what happen. - Don't forget to reload while following the log ... 
</p>
<p>
This is the <em>inititial HACK</em> release of <b>moiNAG</b>, - so it's not perfect !
If there are any suggestions or bugs, <a href="mailto:moinag-$form_time\@leo.0n3.org">let me know</a>.
</p>
<p>
regards - Richard Leopold
</p>
EOF

sub html_nag_form {
	start_form
	. 
	table( { -border => 0 },
		Tr( [
			th({-align => 'left' , -colspan => 2}, [ 
				b('initiate a new peace of art:')
			] ),
			td( [
				'define the title:', 
				textfield (-name => 'title',
					-default  => 'NetArt Generator',
					-override => 1,
					-size=>32,
					-maxlength=>64) 
			] ),
			td( [
				'your name:',
				textfield (-name => 'initiator',
					-default  => '',
					-override => 1,
					-size=>32,
					-maxlength=>64) 
			] ),
			td( { -class => 'tiny' }, [
				'search backends to use:',
				checkbox_group(
					-name       => 'sengine',
					-values     => $search_engines,
					-default    => $search_engines,
					-columns    => 3 )
			] ),
			td( { -align => 'right' }, [
				hidden(-name => 'form_ts', -value => $form_time),
				submit(-name => 'ACTION', -class => 'submit')
			] )
		] )
	)
	. 
	end_form,
}

sub gen_idx {
	my $skey = shift || 'ts';
	my @db = ();
	
	# bruce force #o)
	find( { 
			wanted => sub { if (/^bibl\.txt\z/s) {
					my $bibl = $File::Find::name;
					
					# reload the dumped bibl
					local $/ = undef;
					open my $fh, "< $bibl" or die "open $bibl - $!";
					my $dump = <$fh>;
					close $fh;
					$dump = eval $dump; die('loading bibl.txt: ' . $@) if $@;
					
					push @db, $dump;
				}
			},
		},
		$CFG->{dada_dir}
	);
	
	@db = sort { $b->{$skey} cmp $a->{$skey} } @db;
	
	return wantarray() ? @db : \@db;
}

sub html_archiv_list {
	my @rows = (
		th( [ 'title', 'initiator', 'date', 'state'] )
	);
	
	foreach (gen_idx('ts')) {
		my $url   = $CFG->{dada_url} . $_->{poa};
		push @rows, 
			td( { -class => 'title'}, [
				a({ -href => $url }, $_->{title}),
			] ) 
			. td( { -class => 'tiny' }, [
				$_->{initiator} ? $_->{initiator} : '',
				POSIX::strftime( "%d  %b  %Y  %H:%M:%S", gmtime($_->{ts})),
				(defined $_->{exit_code} 
					? ( $_->{exit_code} ? 'FAIL' : 'OK') 
					: 'wait'),
			]);
	};
	return table({-border => 0}, Tr(\@rows));
}

if ( param('ACTION') ) {
	## 
	# convert initiator title time to a pathstring
	my $ts = param('form_ts') || 0;
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday) = gmtime($ts);
	my $time = sprintf('%0.4d%0.2d%0.2d%0.2d%0.2d%0.2d', $year + 1900, $mon + 1, $mday, $hour, $min, $sec);
	my $title = param('title');
	# remove leading and trailing whitespaces
	$title =~ s/^\s*(.*)\s*$/$1/;
	# whitespaces to underscore
	$title =~ s/\s+/_/g;
	# remove NOT alnum chars
	$title =~ s/[^[:alnum:]_]//g;
	
	my $initiator = param('initiator');
	$initiator =~ s/^\s*(.*)\s*$/$1/;
	$initiator =~ s/\s+/_/g;
	$initiator =~ s/[^[:alnum:]_]//g;
	
	my $poa = File::Spec->catdir( (lc($initiator) || '_none_'), (lc($title) || '_none_'), $time);
	##
	
	my $path  = File::Spec->catdir($CFG->{dada_dir}, $poa);
	my $log   = File::Spec->catfile($path, 'log.txt');
	my $html  = File::Spec->catfile($path, 'index.html');
	my $bibl  = File::Spec->catfile($path, 'bibl.txt');
	
	my $url   = $CFG->{dada_url} . $poa;
	
	if ( ! -d $path ) {
		
		mkpath($path);
		
		##
		# Forking to do the external job ...
		#
		die "fork: $!" unless defined (my $pid = fork);
		if (! $pid) {
			## Child stuff
			
			# detach child from processgroup 
			POSIX::setsid() || die "Can't set sid: $!";
			open STDOUT, '>' . File::Spec->devnull() or die $!;
			open STDIN,  '<' . File::Spec->devnull() or die $!;
			open STDERR, ">&STDOUT" or die $!;
			
			my $dump = {
				title     => param('title'),
				initiator => param('initiator'),
				ts        => time(),
				poa       => $poa,
				exit_code => undef 
			};
			
			my $fh;
			open $fh, "> $bibl" or die $!;
			print $fh 'my ' . Dumper($dump);
			close $fh;
			
			# calulate the command
			my @para = (
				$CFG->{moiNAG},
				'--title', param('title'),
				'--initiator', param('initiator'),
				'--logfile', $log,
				'--outfile', $html,
#				'--debug'
			);
			foreach ( param('sengine') ) { push @para, '--search_engine', $_ }
			
			# do the external job
			$dump->{exit_code} = system '/usr/bin/perl', '-I', $INC[0], '-I', $INC[1], @para;
			
			# write a catalog file again
			open  $fh, "> $bibl" or die $!;
			print $fh 'my ' . Dumper($dump);
			close $fh;
			
			exit;
		} 
		## End forked stuff 
		
		print redirect($CFG->{my_url});
		
		exit;
	}
}

print
	header, 
	start_html(
		-title => 'moiNAG - moi NetArtGenerator',
		-head=>[
			Link({ -rel => "stylesheet", -type => "text/css", -href => $CFG->{css_url} } )
		]
	),
	table( { -border => 0 }, Tr( { -valign => 'top', -align => 'left'}, [
		td(  [ 
			html_nag_form() . $html_text,
			html_archiv_list(),
		] )
	])),
	$VERSION,
#	pre(Dumper(\%ENV)),
	end_html;

exit;
