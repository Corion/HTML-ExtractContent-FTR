#!perl -w

use strict;
use warnings;

use Test::More tests => 1;
use HTML::ExtractContent::FTR;

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

my $rules_folder ||= './ftr-site-config';

my $extractor = HTML::ExtractContent::FTR->new(
    rules_folder => $rules_folder,
);
my $info = $extractor->extract( $html, url => 'http://nonexistent.example.com/fff' );
is $info, undef, "FTR can't extract information from an unknown site";

done_testing;