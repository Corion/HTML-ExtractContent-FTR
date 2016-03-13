package HTML::ExtractContent::FTR;
use strict;
use 5.016; # for fc
use URI;
use Carp qw(croak);
use HTML::TreeBuilder::XPath;
use HTML::Selector::XPath 'selector_to_xpath';
use App::scrape 'scrape';
use Data::Dumper;
use HTML::ExtractContent::Pluggable;
use File::Basename;

use vars qw(%rules @rules);

=head1 NAME

HTML::ExtractContent::FTR - extract content using Full-Test-RSS rules

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
    body => 'extract',
    author => 'extract',
    date => 'extract',
    title => 'extract',
    strip => 'restructure',
);

my $phase;
%phases = (map { $_ => $phase++ } qw<
    prepare
    fetch
    restructure
    extract
>);

sub new {
    my( $class, %options ) = @_;
    
    # If needed, we'll use the packaged rules
    if( ! exists $options{ rules } ) {
        if( exists $options{ rules_folder } ) {
            opendir my $rules,  $options{ rules_folder }
                or croak "Couldn't read '$options{ rules_folder }': $!";
            my @rules = grep { /\.txt$/i } readdir $rules;
            my @parsed = map { $class->parse_file("$options{ rules_folder }/$_") } @rules;
            %rules = map { $_->{host} => $_ } @parsed;
        } elsif( ! keys %rules) {
            my @parsed = $class->parse(\@rules);
            %rules = map { $_->{host} => $_ } @parsed;
        }
        $options{ rules } ||= \%rules;
        
    };
    
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

sub extract {
    my( $self, $html, %options ) = @_;
    my $url = $options{ url };
    if( ! ref $url ) {
        $url = URI->new( $url );
    };
    my $host = $url->host;
    (my $match) = grep {
        my $partial = substr($host,length($host)-length($_), length $_);
        fc( $_ ) eq fc( $partial )
    } sort keys %{ $self->{rules} };
    if( my $rule = $self->{rules}->{$match} ) {
        return $self->apply_rules( $rule, $html, $url, %options );
    } else {
        warn "No host match found for '$host' in ". join "\n", sort keys %{ $self->{rules} };
    };
}

sub parse_html_string {
    my( $self, $html ) = @_;
    my $tree = HTML::TreeBuilder::XPath->new;
    $tree->parse( $html );
    $tree->eof();
    $tree
}

sub apply_rules {
    my( $self, $rule, $html, $url, %options ) = @_;
    
REPARSE:
    # This needs to happen only after the ->fetch stage...
    my $tree = $self->parse_html_string( $html );
    $tree->dump;
    
    my $info = {};
    # How do we fetch-and-restart the program with
    # single_page_link?
    for my $phase (@{ $rule->{commands} }) {
        for my $step (@{ $phase }) {
            #$tree->dump;
            #warn "$step->{command} $step->{target}\n";
            $tree = $step->{compiled}->($rule, $tree, $info);
            
            if( $info->{fetch} ) {
                warn "Refetching as $info->{url}";
                if( my $fetcher = $self->{do_fetch}) {
                    $html = $fetcher->( $info->{url} );
                    warn "Restarting with [[$html]]";
                    goto REPARSE;
                } else {
                    return $info
                };
            };
            last if delete $info->{done};
        };
    };
    return HTML::ExtractContent::Info->new( $info );
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
        #my @res = scrape undef, { value => $rule->{target} }, { tree => $tree };
        my @res = $tree->findnodes($rule->{target});
        warn Dumper @res;
        if( @res ) {
            warn Dumper $res[0];
            my $target = $res[0]->{href};
            $info->{url} = $target;
            $info->{fetch} = 1;
            warn "Found single page link to $info->{url}";
            exit;
        };
        exit;
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

=head2 C<< ->_compile_selector_fetch >>

The internal generator for compiling a rule that fetches an
XPath selector and stores it as an attribute.

=cut

sub _compile_selector_fetch {
    my( $self, $program, $rule ) = @_;
    return sub {
        my($r, $tree, $info) = @_;
        warn "Scanning for '$rule->{target}'";
        #my @res = scrape undef, { value => $rule->{target} }, { tree => $tree };
        my @res = $tree->findnodes($rule->{target});
        if( @res ) {
            # We append
            if(! $info->{ $rule->{command} }) {
                 $info->{ $rule->{command}} = HTML::Element->new('div');
            };
            my $storage = $info->{ $rule->{command} };
            for my $node (@res) {
                $storage->push_content($node);
                #$node->detach;
            };
        } else {
            warn "No selector found for '$rule->{target}'";
        };
        return $tree
    }
}

=head2 C<< ->compile_if_page_contains >>

A no-op currently

=cut

sub compile_if_page_contains {
    my( $self, $program, $rule ) = @_;
    return ()
}

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
        for my $node ($tree->findnodes($xpath)) {
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
        for my $node ($tree->findnodes($xpath)) {
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
        for my $node ($tree->findnodes($xpath)) {
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
        for my $node ($tree->findnodes($xpath)) {
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
        $text =~ s!$rule->{args}!$rule->{target}!;
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
        for my $target ($tree->findnodes($target_xpath)) {
            for my $node ($tree->findnodes($source_xpath)) {
                my $new = $node->clone;
                $node->delete;
                $target->postinsert( $new );
            }
        };
        return $tree
    }
}


@rules = (

# (re)fetch them from
# https://github.com/fivefilters/ftr-site-config

<<'RULE',
host: lwn.net

# HTML5 anyone? The 1980s called, they want their HTML4 back.
# LWN uses so little markup that you really have to be creative.

tidy: yes
prune: no

single_page_link: //div[@class='ArticleText']//a[contains(text(), 'Full Story')]/@href
single_page_link: concat(//div[@class='ArticleText']//a[contains(text(), 'Read more')]/@href, 'bigpage')

title: //h1

# After tiding the document, <b> becomes <strong>.
author: //div[@class='FeatureByline']/strong
date: //div[@class='FeatureByline']/text()[preceding-sibling::br]
strip: //div[@class='FeatureByline']
author: substring-after(//div[@class='GAByline']/p[2], 'by ')
date: //div[@class='GAByline']/p[1]
strip: //div[@class='GAByline']

# tidy will take care of fixing the tag mess that we make here.
replace_string(<p class="Cat1HL">): <h1>
replace_string(<h2 class="SummaryHL">): <h3>
replace_string(<p class="Cat2HL">): <h2>

# Make extracting the content before "Log in to post comments" easier.
# And by "easier" I mean possible in all cases without going through
# a lot of XPath pain.
replace_string(<hr width="60%" align="left">): <div class="ftrss-strip">
replace_string(to post comments)): </div>
strip: //div[@class='ftrss-strip']
body: //div[@class='ArticleText']

test_url: http://lwn.net/Articles/668318/
test_url: http://lwn.net/Articles/668695/
test_url: http://lwn.net/Articles/669114/
test_url: http://lwn.net/Articles/670209/
test_url: http://lwn.net/Articles/670209/rss
test_url: http://lwn.net/Articles/668318/rss
test_url: http://lwn.net/Articles/670062/
RULE

<<'RULE',
host: www.kickstarter.com

title: //h1[@id='name']
body: //*[@id='leftcol']

strip_id_or_class: 'share-box'
strip_id_or_class: 'project-faqs'
strip_id_or_class: 'report-issue-wrap'
test_url: http://www.kickstarter.com/projects/hop/elevation-dock-the-best-dock-for-iphone
RULE

<<'RULE',
# Author: zinnober
# Template should work well with either desktop or mobile version (m.heise.de)
host: heise.de

prune: no

title: //article/h1 | //h1
date: //p[@class='news_datum']
author: //h4[@class='author']

body: //article | //div[@class='meldung_wrapper']

# General cleanup
strip: //time
strip: //header
strip: //h4[@class='author']
strip: //div[@class='gallery compact']/h3
strip: //div[@class='gallery compact']/figcaption
strip: //p[@class='news_datum']
strip: //p[@class='artikel_datum']
strip: //p[@class='news_navi']
strip: //p[@class='printversion']
strip: //a[contains(@href, 'mailto')]
strip: //div[@class='gallery compact']/h2
strip: //p[@class='themen_foren']
strip: //style
strip: //span[@class='source']
#strip: //div[@class='gallery compact']/figcaption
strip_id_or_class: comments
strip_id_or_class: ISI_IGNORE
strip_id_or_class: clear

strip_id_or_class: linkurl_grossbild
strip_id_or_class: image-num
strip_id_or_class: heisebox_right
strip_id_or_class: dossier
strip_id_or_class: latest_posting_snippet

# Strip Ads
strip_id_or_class: ad_

# Some optimizations
replace_string(<h5>): <h2>
replace_string(</h5>): </h2>
replace_string(<span class="bild_rechts" style="width:): <p "
replace_string(<div class="heisebox">): <blockquote>


next_page_link: //a[@class='next']
next_page_link: //a[@title='vor']

test_url: http://www.heise.de/open/artikel/Die-Neuerungen-von-Linux-3-15-2196231.html
test_url: http://m.heise.de/open/artikel/Die-Neuerungen-von-Linux-3-15-2196231.html
test_url: http://www.heise.de/newsticker/meldung/Ueberwachungstechnik-Die-globale-Handy-Standortueberwachung-2301494.html

RULE

);

=head1 SEE ALSO 

L<http://help.fivefilters.org/customer/portal/articles/223153-site-patterns>

L<https://github.com/fivefilters/ftr-site-config>

1;