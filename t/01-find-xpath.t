#!perl -w

use strict;
use warnings;

use Test::More tests => 7;
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
my @nodes = $extractor->find_xpath( $html,
    substring => 'Leipzig' );

if( not is 0+@nodes, 1, "We find one node containing 'Leipzig' in the text" ){
    diag $_ for @nodes;
};
is_deeply [grep { !/Leipzig/ } map { "$_" } @nodes ], [], "And they contain 'Leipzig'";

@nodes = $extractor->find_xpath( $html,
    attr => 'Leipzig' );

if( not is 0+@nodes, 1, "We find one node containing 'Leipzig' in the attribute" ){
    diag $_ for @nodes;
};
is_deeply [grep { !/Leipzig/ } map { "$_" } @nodes ], [], "And they contain 'Leipzig'";

@nodes = $extractor->find_xpath( $html,
    #url => $url,
    attr => 'post-body' );

if( not is 0+@nodes, 1, "We find one node containing 'post-body' in the attribute" ){
    diag $_ for @nodes;
};
is_deeply [grep { !/post-body/ } map { "$_" } @nodes ], [], "And they contain 'post-body'";

my $info = $extractor->extract( $html, url => 'http://der-postillon.com/fff' );
like $info->body, qr/\QLeipzig (dpo) - body .../, "We find the body";

done_testing;