#!perl -w
use strict;
use LWP::Simple;
use HTML::ExtractContent::FTR;
use Getopt::Long;

GetOptions(
    'html' => \my $output_html,
    'rules:s' => \my $rules_folder,
);

my( $url, $substring ) = @ARGV;
my $html = get $url;
$rules_folder ||= './ftr-site-config';

my $extractor = HTML::ExtractContent::FTR->new(
    rules_folder => $rules_folder,
);
my @nodes = $extractor->find_xpath( $html,
    url => $url,
    substring => $substring );
push @nodes, $extractor->find_xpath( $html,
    url => $url,
    attr => $substring );

sub myNodePath {
    my $node = shift;
    my @res;
    while( $node and $node->nodeName ne '#document') {
        my $el = $node->nodeName;
        if( my $class = $node->attr('class') ) {
            $el .= "[contains(\@class, '$class')]";
        } elsif( $el eq 'meta' and my $name = $node->attr('name')) {
            $el .= qq([\@name="$name"]);
        } elsif( $el eq 'meta' and my $prop = $node->attr('property')) {
            $el .= qq([\@property="$prop"]);
        } elsif( $el eq 'href' and my $rel = $node->attr('rel')) {
            $el .= qq([\@rel="$rel"]);
        };
        push @res, $el;
        $node = $node->parent;
    }
    return join '/', '', reverse @res;
}

for my $node (@nodes) {
    next if $node->nodeName eq 'script';
    print myNodePath($node), "\n";
    print $node->textContent;
    if ($node->nodeName eq 'meta' ) {
        print $node->toString;
    };
}
