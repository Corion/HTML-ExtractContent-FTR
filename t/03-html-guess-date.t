#!perl -w
use strict;
use warnings;

use Test::More tests => 1;
use HTML::ExtractContent::Guess::Date;

my $html = <<'HTML';
<html>
<head>
<meta name="content" value="Leipzig (dpo) via meta">
</head>
<body>
<div class="post-body funny">
Leipzig (dpo) - body ...
</div>
</body>
</html>
HTML

my @url_tests = (
    [' http://www.example.com/2017/01/01/foo-is-bad.html' => '<date>2017-01-01</date>' ],
);
for my $test (@url_tests) {
    my ($url, $expected) = @$test;
    my $extractor = HTML::ExtractContent::Guess::Date->new;
    my $info = $extractor->extract(undef, url => $url);
    is $info->date, $expected, $url;
};

done_testing;