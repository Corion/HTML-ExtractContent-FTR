#!perl -w

use strict;
use warnings;

use Test::More tests => 9;
use Tree::XPathEngine::Mojo;
use Mojo::DOM;

my $html = <<'HTML';
<html>
<head>
<meta name="content" value="Leipzig (dpo) via meta">
</head>
<body>
<div class="post-body funny">
Leipzig (dpo) - body ...
</div>
<div>unstyled</div>
</body>
</html>
HTML

my $tree = Mojo::DOM->new($html);
my $ctx = Tree::XPathEngine::Mojo->new($tree);
my $e = Tree::XPathEngine->new();

# Unwrap from Tree::XPathEngine::Mojo back to the real nodes
sub query {
    my( $xpath ) = @_;
    my @nodes = map {
        $_->{node}
    } $e->findnodes($xpath, $ctx);
};
my @nodes;
@nodes = query('//div');
if( not is 0+@nodes, 2, "We find two div nodes" ){
    diag $_ for @nodes;
};
@nodes = query('//div[contains(text(),"Leipzig")]');
if( not is 0+@nodes, 1, "We find two div nodes with 'Leipzig'" ){
    diag $_ for @nodes;
};
is_deeply [grep { !/Leipzig/ } map { "$_" } @nodes ], [], "And they contain 'Leipzig'";

@nodes = query('//meta[@name]');
if( not is 0+@nodes, 1, "We find one node via its attribute" ){
    diag $_ for @nodes;
};

@nodes = query('//*[@name]');
if( not is 0+@nodes, 1, "We find one arbitrary node via its attribute" ){
    diag $_ for @nodes;
};

@nodes = query('//meta[contains(@value,"Leipzig")]');
if( not is 0+@nodes, 1, "We find one node via its attribute value" ){
    diag $_ for @nodes;
};

@nodes = query('//div[@class="post-body"]');
if( not is 0+@nodes, 0, "We find no node via its partial attribute value" ){
    diag $_ for @nodes;
};

@nodes = query('//div[contains(@class,"post-body")]');
if( not is 0+@nodes, 1, "We find one node via its partial attribute value via contains()" ){
    diag $_ for @nodes;
};

@nodes = query('//div[contains(concat(" ",normalize-space(@class)," ")," post-body ")]');
if( not is 0+@nodes, 1, "We find one node via its partial attribute value via contains()" ){
    diag $_ for @nodes;
};


done_testing;