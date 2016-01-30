#!perl -w
use strict;
use LWP::Simple;
use HTML::ExtractContent::FTR;

my( $url ) = @ARGV;
my $html = get $url;

#warn $html;

my $extractor = HTML::ExtractContent::FTR->new(
    rules_folder => 'rules/',
);
my $info = $extractor->extract( $html, url => $url );
print $info->title, "\n";
print join " - ", $info->date, $info->author, "\n";
print $info->body, "\n";