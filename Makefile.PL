# -*- mode: perl; c-basic-offset: 4; indent-tabs-mode: nil; -*-

use strict;
use ExtUtils::MakeMaker qw(WriteMakefile);
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

# Normalize version strings like 6.30_02 to 6.3002,
# so that we can do numerical comparisons on it.
my $eumm_version = $ExtUtils::MakeMaker::VERSION;
$eumm_version =~ s/_//;

# I should maybe use something like Shipwright...
regen_README('lib/HTML/ExtractContent/FTR.pm');
#regen_EXAMPLES();

my @tests = map { glob $_ } 't/*.t', 't/*/*.t';

my @signatures = eval 'use feature "signatures"; 1'
                 ? ()
                 : ('Filter::signatures' => 0.05);

WriteMakefile1(
    MIN_PERL_VERSION => '5.010', # This is just a wild guess
    NAME                => 'HTML::ExtractContent::FTR',
    AUTHOR              => q{Max Maischein <corion@cpan.org>},
    VERSION_FROM        => 'lib/HTML/ExtractContent/FTR.pm',
    ABSTRACT_FROM       => 'lib/HTML/ExtractContent/FTR.pm',
    META_MERGE => {
        resources => {
            repository => 'https://github.com/Corion/html-extractcontent-ftr',
        },
    },

    ($eumm_version >= 6.3001
      ? ('LICENSE'=> 'perl')
      : ()),

    PL_FILES            => {},
    PREREQ_PM => {
        @signatures,
        'Exporter' => 5, # for use Exporter 'import'
        'Carp' => 0,
        'File::Basename' => 0,
        
        'Moo' => 0,
        
        'Mojo::DOM' => 0, # the only sane parser I found that supports HTML5 tags :-(
        'Tree::XPathEngine' => 0, # For Tree::XPathEngine::Mojo
        'HTML::ExtractMain' => 0, # for HTML::ExtractContent::ExtractMain
        'HTML::HeadParser' => 0, # for HTML::ExtractContent::Guess - this should move to Mojo::DOM

        },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },

    test            => { TESTS => join( ' ', @tests ) },
);

1;

sub WriteMakefile1 {  #Written by Alexandr Ciornii, version 0.21. Added by eumm-upgrade.
    my %params=@_;
    my $eumm_version=$ExtUtils::MakeMaker::VERSION;
    $eumm_version=eval $eumm_version;
    die "EXTRA_META is deprecated" if exists $params{EXTRA_META};
    die "License not specified" if not exists $params{LICENSE};
    if ($params{BUILD_REQUIRES} and $eumm_version < 6.5503) {
        #EUMM 6.5502 has problems with BUILD_REQUIRES
        $params{PREREQ_PM}={ %{$params{PREREQ_PM} || {}} , %{$params{BUILD_REQUIRES}} };
        delete $params{BUILD_REQUIRES};
    }
    delete $params{CONFIGURE_REQUIRES} if $eumm_version < 6.52;
    delete $params{MIN_PERL_VERSION} if $eumm_version < 6.48;
    delete $params{META_MERGE} if $eumm_version < 6.46;
    delete $params{META_ADD} if $eumm_version < 6.46;
    delete $params{LICENSE} if $eumm_version < 6.31;
    delete $params{AUTHOR} if $] < 5.005;
    delete $params{ABSTRACT_FROM} if $] < 5.005;
    delete $params{BINARY_LOCATION} if $] < 5.005;
    
    WriteMakefile(%params);
}

sub regen_README {
    eval {
        require Pod::Readme;

        my $parser = Pod::Readme->new();

        # Read POD from Module.pm and write to README
        $parser->parse_from_file($_[0], 'README');
    };
    eval {
        require Pod::Markdown;

        my $parser = Pod::Markdown->new();

        # Read POD from Module.pm and write to README
        $parser->parse_from_file($_[0]);
        open my $fh, '>', 'README.mkdn'
            or die "Couldn't open 'README.mkdn': $!";
        print $fh $parser->as_markdown;
    };
}

