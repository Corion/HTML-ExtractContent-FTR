#!perl -w
use strict;
use warnings;

use Test::More;
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
    ['http://www.example.com/2017/01/01/foo-is-bad.html' => '<date>2017-01-01</date>' ],
    ['https://www.jwz.org/blog/2017/03/scenes-from-our-dystopian-cyberpunk-present/' => undef, ], # but a hint? '<date>2017-03-00</date>' ],
    ['http://www.newyorker.com/magazine/2017/03/27/daniel-dennetts-science-of-the-soul' => '<date>2017-03-27</date>' ],
);

plan tests => 0+ @url_tests;

for my $test (@url_tests) {
    my ($url, $expected) = @$test;
    my $extractor = HTML::ExtractContent::Guess::Date->new;
    my $info = $extractor->extract(undef, url => $url);
    my $d = $info ? $info->date : undef;
    is $d, $expected, $url;
};

done_testing;