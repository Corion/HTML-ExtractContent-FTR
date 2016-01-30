#!perl -w
use strict;
use LWP::Simple;
use HTML::ExtractContent::FTR;
use Getopt::Long;

GetOptions(
    'html' => \my $output_html,
);

my( $url ) = @ARGV;
my $html = get $url;

#warn $html;

my $extractor = HTML::ExtractContent::FTR->new(
    rules_folder => 'rules/',
);
my $info = $extractor->extract( $html, url => $url );

sub get_html {
    my( $el ) = @_;
    if( $el ) {
        return join "", map { $_->as_HTML } $el->content_list
    } else {
        return ''
    }
}

if( $output_html ) {
    print <<HTML;
<html>
<head><title>@{[ get_html( $info->title_tree ) ]}</title>
<body>
<h1>@{[ get_html( $info->title_tree ) ]}</h1>
<small>
@{[ get_html( $info->date_tree ) ]} - @{[ get_html( $info->author_tree ) ]}
</small>
@{[ get_html( $info->body_tree ) ]}
</body>
</html>
HTML
} else {
    print $info->title, "\n";
    print join " - ", $info->date, $info->author, "\n";
    print $info->body, "\n";
}
