use strict;
use warnings;

use Test::More;

ok( -f 'config/config.json', 'skill keeps a config/config.json file' );
ok( -f 'aptfile', 'skill declares Linux host dependencies in aptfile' );
ok( -f 'brewfile', 'skill declares macOS host dependencies in brewfile' );
ok( -f 'cpanfile', 'skill declares Perl module dependencies in cpanfile' );
ok( -x 'cli/convert', 'skill ships an executable cli/convert entrypoint' );

my $cpanfile = do {
    open my $fh, '<', 'cpanfile' or die "Unable to read cpanfile: $!";
    local $/;
    <$fh>;
};
like( $cpanfile, qr/requires 'Markdown::Perl'/, 'cpanfile includes Markdown::Perl' );
like( $cpanfile, qr/requires 'HTML::WikiConverter'/, 'cpanfile includes HTML::WikiConverter' );
like( $cpanfile, qr/requires 'PDF::API2'/, 'cpanfile includes PDF::API2' );
like( $cpanfile, qr/requires 'CAM::PDF'/, 'cpanfile includes CAM::PDF' );

my $aptfile = do {
    open my $fh, '<', 'aptfile' or die "Unable to read aptfile: $!";
    local $/;
    <$fh>;
};
like( $aptfile, qr/\blibreoffice\b/, 'aptfile includes LibreOffice for docx/pdf host conversion support' );

my $brewfile = do {
    open my $fh, '<', 'brewfile' or die "Unable to read brewfile: $!";
    local $/;
    <$fh>;
};
like( $brewfile, qr/\blibreoffice\b/, 'brewfile includes LibreOffice for docx/pdf host conversion support' );

done_testing;
