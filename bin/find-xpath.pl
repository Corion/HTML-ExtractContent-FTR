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

sub myNodePath {
    my $node = shift;
    my @res;
    while( $node and $node->nodeName ne '#document') {
        my $el = $node->nodeName;
        warn $el;
        if( my $class = $node->attr('class') ) {
            $el .= "[contains(\@class, '$class')]";
        };
        push @res, $el;
        $node = $node->parent;
    }
    return join '/', reverse @res;
}

for my $node (@nodes) {
    print myNodePath($node), "\n";
    print $node->textContent;
}
