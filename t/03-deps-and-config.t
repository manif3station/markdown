use strict;
use warnings;

use Test::More;

ok( -f 'config/config.json', 'skill keeps a config/config.json file' );
ok( -f 'aptfile', 'skill declares Debian-family packages in aptfile' );
ok( -f 'brewfile', 'skill declares macOS packages in brewfile' );
ok( -x 'cli/convert', 'skill ships an executable cli/convert entrypoint' );

my $aptfile = do {
    open my $fh, '<', 'aptfile' or die "Unable to read aptfile: $!";
    local $/;
    <$fh>;
};
like( $aptfile, qr/^pandoc$/m, 'aptfile includes pandoc' );
like( $aptfile, qr/^poppler-utils$/m, 'aptfile includes poppler-utils' );
like( $aptfile, qr/^wkhtmltopdf$/m, 'aptfile includes wkhtmltopdf' );

my $brewfile = do {
    open my $fh, '<', 'brewfile' or die "Unable to read brewfile: $!";
    local $/;
    <$fh>;
};
like( $brewfile, qr/^pandoc$/m, 'brewfile includes pandoc' );
like( $brewfile, qr/^poppler$/m, 'brewfile includes poppler' );
like( $brewfile, qr/^weasyprint$/m, 'brewfile includes weasyprint for markdown to pdf on macOS' );
unlike( $brewfile, qr/^wkhtmltopdf$/m, 'brewfile no longer references the unavailable wkhtmltopdf package' );

done_testing;
