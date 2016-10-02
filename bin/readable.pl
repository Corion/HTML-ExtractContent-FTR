#!perl -w
use strict;
use LWP::Simple;
use HTML::ExtractContent::FTR;
use Getopt::Long;

GetOptions(
    'html' => \my $output_html,
    'rules:s' => \my $rules_folder,
);

my( $url ) = @ARGV;
my $html = get $url;
$rules_folder ||= './ftr-site-config';

my @messages;
my $extractor = HTML::ExtractContent::FTR->new(
    rules_folder => $rules_folder,
    messages => \@messages,
);

if( !$extractor->can_extract( url => $url )) {
    die "Don't know how to extract pages from '$url'\n";
};

my $info = $extractor->extract( $html, url => $url );
if( ! $info ) {
    warn "$_\n"
        for @messages;
    exit 1
};

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
    #system 'chcp 65001';
    no warnings;
    binmode STDOUT, 'UTF-8';
    print $info->title, "\n";
    print join " - ", $info->date, $info->author, "\n";
    print $info->body, "\n";
}
