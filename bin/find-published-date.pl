#!perl -w
use strict;
use warnings;
use HTML::ExtractContent::Guess::Date;

my $ua;
my $extractor = HTML::ExtractContent::Guess::Date->new;

for my $url (@ARGV) {
    my $from_url = $extractor->extract(undef, url => $url);
    
    if( my $date = $from_url->date ) {
        print "$date\n";
    } else {
        require Mojo::UserAgent;
        $ua ||= Mojo::UserAgent->new;
        my $html = $ua->get($url)->result;
        my $from_html = $extractor->extract($html, url => $url);
        print $from_html->date;
    };
};
