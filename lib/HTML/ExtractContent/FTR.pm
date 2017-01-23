package HTML::ExtractContent::FTR;
use strict;
use 5.016; # for fc
use if $] < 5.020, 'Filter::signatures';
use feature 'signatures';
no warnings 'experimental::signatures';
use URI;
use Carp qw(croak);
use Mojo::DOM;
use Tree::XPathEngine::Mojo;
use HTML::Selector::XPath 'selector_to_xpath';
use HTML::ExtractContent::Pluggable;
use File::Basename;

use vars qw(%rules $VERSION);
$VERSION = '0.01';

=head1 NAME

HTML::ExtractContent::FTR - extract content using Full-Text-RSS rules

=head1 SYNOPSIS

  use HTML::ExtractContent::FTR;
  use LWP::UserAgent;

  my $agent = LWP::UserAgent->new;
  my $res = $agent->get('http://www.example.com/');

  my $extractor = HTML::ExtractContent::FTR->new;
  my $info = $extractor->extract($res->decoded_content, url => $url);
  print $info->title, "\n";
  print $info->as_text, "\n";

=cut

use vars qw(%command_phase %phases);
%command_phase = (
    http_header => 'prepare',
    rewrite_url => 'prepare', # I can imagine that
    fetch => 'fetch',
    body => 'extract',
    author => 'extract_metadata',
    date => 'extract_metadata',
    title => 'extract_metadata',
    strip => 'restructure',
    body => 'extract',
);

my $phase;
%phases = (map { $_ => $phase++ } qw<
    prepare
    fetch
    extract_metadata
    restructure
    extract
>);

sub new {
    my( $class, %options ) = @_;
    
    # If needed, we'll use the packaged rules
    # XXX do we really want to use packaged rules or shouldn't we
    #     make the user(s) download them?!
    if( ! exists $options{ rules } ) {
        if( exists $options{ rules_folder } ) {
            opendir my $rules,  $options{ rules_folder }
                or croak "Couldn't read '$options{ rules_folder }': $!";
            my @rules = grep { /\.txt$/i && ! $_ eq 'LICENSE.txt' } readdir $rules;
            my @parsed = map {
                               my $f = "$options{ rules_folder }/$_";
                               my $r = eval {
                                   $class->parse_file($f);
                               };
                               if( $@ ) {
                                   warn "$@, ignoring $f";
                               };
                               $r ? $r : ()
                             } @rules;
            %rules = map { $_->{host} => $_ } @parsed;
        } elsif( ! keys %rules) {
            croak "No rules given";
            #my @parsed = $class->parse(\@rules);
            #%rules = map { $_->{host} => $_ } @parsed;
        }
        $options{ rules } ||= \%rules;
        
    };
    
    # We should turn this module into a state machine that
    # returns "Need URL" instead of going out and fetching things
    # itself (or doing a callback).
    if( ! exists $options{ fetcher } ) {
        $options{ fetcher } = sub {
            my ($url) = @_;
            my $agent = LWP::UserAgent->new;
            warn "Fetching <$url>";
            my $res = $agent->get($url);
            return $res->decoded_content
        }
    }

    bless \%options => $class
}

sub find_xpath {
    my( $self, $html, %options ) = @_;
    
    my $query;
    if( my $substring = $options{substring} ) {
        $substring =~ s!(["'\\])!\\$1!;
        $query = "//*[contains(text(),'$substring')]";
    };
    
    if( my $attr = $options{ attr }) {
        $attr =~ s!(["'\\])!\\$1!;
        $query = "//*[\@*[contains(.,'$attr')]]";
    };
    
    # brute-force traverse our tree and output the node path(s)
    # where we find the text. Consider simplifying the path
    # or turning it into a CSS(-like) selector by using @class
    # or @id.
    my $tree = $self->parse_html_string($html);
    my @res;
    for my $node ($self->findnodes($tree, $query)) {
        push @res, $node;
    };
    
    @res
}

sub findnodes( $self, $tree, $xpath ) {
    croak "No xpath expression" unless defined $xpath;
    my $ctx = Tree::XPathEngine::Mojo->new($tree);
    my $e = Tree::XPathEngine->new();

    # Unwrap from Tree::XPathEngine::Mojo back to the real nodes
    my @nodes = map {
        $_->{node}
    } $e->findnodes($xpath, $ctx);

    wantarray ? @nodes : \@nodes;
};

=head2 C<< $extractor->can_extract %options >>

  if( $extractor->can_extract(url => 'http://example.com/foo' )) {
      ...
  };

Returns whether the extractor has a set of rules
for extracting content. This is convenient as a sanity check before
you make a long network request.

=cut

sub can_extract( $self, %options ) {
    $options{ messages } ||= $self->{messages} || [];
    my $url = $options{ url };
    if( ! ref $url ) {
        $url = URI->new( $url );
    };
    my $host = $url->host;
    (my $match) = grep {
        my $partial = substr($host,length($host)-length($_), length $_);
        fc( $_ ) eq fc( $partial )
    } sort keys %{ $self->{rules} };
    if( ! $match) {
        push @{ $options{ messages }}, "No host match found for '$host' in rules.";
    };
    $match
}

=head2 C<< $extractor->extract $html, %options >>

  my $info = $extractor->extract($html, url => 'http://example.com/foo' );
  if( $info ) {
      print $info->title, "\n";
      print $info->as_text, "\n";
  };

=cut

sub extract {
    my( $self, $html, %options ) = @_;
    $options{ messages } ||= $self->{messages} || [];

    my $match = $self->can_extract( %options );    
    my $url = $options{ url };
    if( $match and my $rule = $self->{rules}->{$match} ) {
        return $self->apply_rules( $rule, $html, $url, %options );
    } else {
        return
    };
}

sub parse_html_string {
    my( $self, $html) = @_;
    
    Mojo::DOM->new( $html );
}

sub apply_rules {
    my( $self, $rule, $html, $url, %options ) = @_;
    
REPARSE:
    # This needs to happen only after the ->fetch stage...
    my $tree = $self->parse_html_string( $html, { url => $url } );
    
    my $info = {};
    # How do we fetch-and-restart the program with
    # single_page_link?
    for my $phase (@{ $rule->{commands} }) {
        for my $step (@{ $phase }) {
            #warn "$step->{command} $step->{target}\n";
            $tree = $step->{compiled}->($rule, $tree, $info);
            
            if( $info->{fetch} ) {
                #warn "Refetching as $info->{url}";
                # No, this should be(come) a state machine
                # Return state, wanted URL and explanatory message
                # to the user here
                if( my $fetcher = $self->{do_fetch}) {
                    $html = $fetcher->( $info->{url} );
                    #warn "Restarting with [[$html]]";
                    goto REPARSE;
                } else {
                    return $info
                };
            };
            last if delete $info->{done};
        };
    };
    my $res = HTML::ExtractContent::Info->new( $info );
    return $res
}

sub parse {
    my( $self, $rules, %info ) = @_;
    return map { $self->parse_rule( $_, %info )} @$rules;
}

sub parse_file {
    my( $self, $filename, %info ) = @_;
    (my $host = basename $filename) =~ s!\.txt$!!i;
    my $content = do {
        local $/;
        open my $fh, '<', $filename
            or croak "$filename: $!";
        binmode $fh, ':encoding(UTF-8)';
        <$fh>;
    };
    $content =~ s/\x{FEFF}//g;
    return $self->parse_rule( $content, host => $host );
}

sub parse_rule {
    my( $self, $rule, %info ) = @_;
    my( @lines ) = split /\r?\n/, $rule;
    
    my $result = {
        %info,
        commands => [],
    };
    for my $line (@lines) {
        if( my $cmd = $self->parse_line( $result, $line )) {
            my $d = $cmd->{command};
            my $p = $command_phase{ $d } || 'restructure';
            my $phase = $phases{ $p };
            $result->{commands}->[$phase] ||= [];
            push @{ $result->{commands}->[$phase] }, $cmd if( $cmd );
        }
    };
    $result
}

sub parse_line {
    my( $self, $rule, $line ) = @_;
    return unless $line =~ /\S/;
    return if $line =~ /^\s*#/;
    return if $line =~ m!^\s*//!;
    $line =~ /^(\w+)(?:\s*\((.*?)\))?\s*:\s*(.*)$/
        or croak "Malformed line '$line'";
    my( $directive, $args, $value ) = (lc $1,$2,$3);
    my $method = "compile_$directive";
    my $info = { command => $directive, args => $args, target => $value };
    my $compile = $self->can($method);
    if( ! $compile ) {
        croak "Unknown command '$directive' in line [$line].";
    } else {
        my $compiled = $self->$method( $rule, $info );
        if( $compiled ) {
            return { compiled => $compiled, %$info };
        };
    };
}

sub compile_host { # a setting
    my( $self, $program, $rule ) = @_;
    $program->{host} = $rule->{target};
    return ()
}

sub compile_parser { # a setting
    my( $self, $program, $rule ) = @_;
    return ()
}

sub compile_footnotes { # a setting
    my( $self, $program, $rule ) = @_;
    return ()
}

sub compile_autodetect_on_failure { # a setting
    my( $self, $program, $rule ) = @_;
    return ()
}

sub compile_strip_comments { # a setting
    my( $self, $program, $rule ) = @_;
    return ()
}

sub compile_http_header { # a setting
    my( $self, $program, $rule ) = @_;
    return ()
}

sub compile_convert_double_br_tags { # a setting
    my( $self, $program, $rule ) = @_;
    $program->{convert_double_br_tags} = $rule->{target} eq 'yes' ? 1 : undef;
    return ()
}

sub compile_autodetect_next_page { # a setting
    my( $self, $program, $rule ) = @_;
    $program->{autodetect_next_page} = $rule->{target} eq 'yes' ? 1 : undef;
    return ()
}

sub compile_tidy { # a no-op/setting
    my( $self, $program, $rule ) = @_;
    return ()
}

sub compile_prune { # a no-op/setting
    my( $self, $program, $rule ) = @_;
    return ()
}

sub compile_test_url { # a no-op
    my( $self, $program, $rule ) = @_;
    return ()
}

sub compile_test_contains { # a no-op
    my( $self, $program, $rule ) = @_;
    return ()
}

sub compile_wrap_in { # a no-op
    my( $self, $program, $rule ) = @_;
    return ()
}

sub compile_find_string { # a no-op
    my( $self, $program, $rule ) = @_;
    return ()
}

sub compile_single_page_link {
    my( $self, $program, $rule ) = @_;
    #warn "Compiled link fetcher with $rule->{target}";
    return sub {
        my($r, $tree, $info) = @_;
        
        warn "Scanning for single page link in '$rule->{target}'";
        my @res = $self->findnodes($tree, $rule->{target});
        
        #warn Dumper \@res;
        if( @res ) {
            warn Dumper $res[0];
            my $target = $res[0]->{href};
            $info->{url} = $target;
            $info->{fetch} = 1;
            warn "Found single page link to $info->{url}";
            # We should switch to a Promises/Future based fetching approach here
        };
        return $tree
    }
}

sub compile_single_page_link_in_feed { # a no-op
    my( $self, $program, $rule ) = @_;
    return ()
}

sub compile_next_page_link { # a no-op
    my( $self, $program, $rule ) = @_;
    return ()
}

sub compile_dissolve { # a no-op
    my( $self, $program, $rule ) = @_;
    return ()
}

sub compile_title {
    my( $self, $program, $rule ) = @_;
    return $self->_compile_selector_fetch($program, $rule);
}

sub compile_author {
    my( $self, $program, $rule ) = @_;
    return $self->_compile_selector_fetch($program, $rule);
}

sub compile_date {
    my( $self, $program, $rule ) = @_;
    return $self->_compile_selector_fetch($program, $rule);
}

sub compile_body {
    my( $self, $program, $rule ) = @_;
    return $self->_compile_selector_fetch($program, $rule);
}

sub unique_nodes {
    # Returns the forest containing $new_node and @nodes,
    # with subtrees merged. To prevent quadratical performance in every
    # step, we assume linear building of the set by adding one element after
    # another. This still means quadratical performance overall, but at least
    # adding one element is linear in the number of already stored elements.
    
    # Simply keep track of all the XPath ->nodePath()s for each node
    # and do a direct string compare. Prestochangodone. (at least for
    # those implementations where the XPath expression is canonical)
    my( $self, $new_node, @nodes ) = @_;
    return @nodes,$new_node;
    my @new_ancestors = $new_node->ancestors;
    grep {
        my( $node ) = $_;
        my @ancestors = $node->ancestors;
        grep { $_->isSameNode( $new_node ) } @ancestors;
    } @nodes;
}

=head2 C<< ->_compile_selector_fetch >>

The internal generator for compiling a rule that fetches an
XPath selector and stores it as an attribute.

This routine should also take care that we only select the ancestor node
if two nodes get selected and one is a descendant of the other.

=cut

sub _compile_selector_fetch {
    my( $self, $program, $rule ) = @_;
    return sub {
        my($r, $tree, $info) = @_;
        #warn "Scanning for '$rule->{target}'";
        my @res = $self->findnodes($tree,$rule->{target});
        if( @res ) {
            # We append
            if(! $info->{ $rule->{command} }) {
                 #$info->{ $rule->{command}} = HTML::Element->new('div');
                 $info->{ $rule->{command}} = [];
            };
            
            my $storage = $info->{ $rule->{command} };
            
            # Copy the node
            for my $node (@res) {
                # Attributes need special handling
                $node = $node->getValue
                    if $node->can('getValue');
                # XXX This should be adapted to Mojo::DOM

                if( ref $node) {
                    # Check whether this node is already contained in $storage
                    # Check whether nodes in $storage are already contained in
                    # this node. Hello quadratic performance.
                    @$storage = $self->unique_nodes($node, @$storage);
                } else {
                    push @$storage, $node;
                };
                
            };
        } else {
            warn "No node found for '$rule->{target}'";
        };
        return $tree
    }
}

=head2 C<< ->compile_if_page_contains >>

A no-op currently, until I figure out how to
structure conditional statements

=cut

sub compile_if_page_contains {
    my( $self, $program, $rule ) = @_;
    return ()
}

=head2 C<< ->compile_strip >>

Strip all elements from the page that match a selector

=cut

sub compile_strip {
    my( $self, $program, $rule ) = @_;
    my $sel = $rule->{target};
    $sel = '//*' . $sel
        if $sel =~ /^\[/;
    $sel = '//' . $sel
        if $sel =~ /^\*/;
    my $xpath = $sel;
    if( $sel !~ m!^/! ) {
        $xpath = selector_to_xpath( $sel);
    };
    return sub {
        # Strip implicitly operates on the 'body' attribute
        my($r, $tree, $info) = @_;
        
        #warn "removing $xpath";
        for my $node ($self->findnodes($tree,$xpath)) {
            #$node->dump;
            $node->delete
        }
        return $tree
    }
}

sub compile_strip_id_or_class {
    my( $self, $program, $rule ) = @_;
    my $xpath = join " | ", selector_to_xpath( "#" . $rule->{target}), selector_to_xpath( "." . $rule->{target});
    return sub {
        my($r, $tree, $info) = @_;
        for my $node ($self->findnodes($tree,$xpath)) {
            $node->delete
        }
        return $tree
    }
}

sub compile_strip_image_src {
    my( $self, $program, $rule ) = @_;
    my $xpath = sprintf 'img[@src="%s"]', $rule->{target};
    return sub {
        my($r, $tree, $info) = @_;
        for my $node ($self->findnodes($tree,$xpath)) {
            $node->delete
        }
        return $tree
    }
}

sub compile_native_ad_clue {
    my( $self, $program, $rule ) = @_;
    my $xpath = $rule->{target};
    return sub {
        my($r, $tree, $info) = @_;
        for my $node ($self->findnodes($tree,$xpath)) {
            $node->delete
        }
        return $tree
    }
}

sub compile_replace_string {
    my( $self, $program, $rule ) = @_;
    my( $source ) = $rule->{args};
    my( $target ) = $rule->{target};
    return sub {
        my($r, $tree, $info) = @_;
        # serialize to text
        my $text = $tree->as_HTML;
        # do string replacement
        $text =~ s!$rule->{args}!$rule->{target}!g;
        # parse to HTML::TreeBuilder again
        
        return $self->parse_html_string( $text );
    }
}

sub compile_move_into {
    my( $self, $program, $rule ) = @_;
    my( $source ) = $rule->{args};
    my( $target ) = $rule->{target};
    my $target_xpath = selector_to_xpath($target);
    my $source_xpath = selector_to_xpath($source);
    return sub {
        my($r, $tree, $info) = @_;
        for my $target ($self->findnodes($tree,$target_xpath)) {
            for my $node ($self->findnodes($tree,$source_xpath)) {
                my $new = $node->clone;
                $node->delete;
                $target->postinsert( $new );
            }
        };
        return $tree
    }
}

=head1 SEE ALSO 

L<http://help.fivefilters.org/customer/portal/articles/223153-site-patterns>

L<https://github.com/fivefilters/ftr-site-config>

1;