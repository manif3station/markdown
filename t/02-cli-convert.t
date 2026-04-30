use strict;
use warnings;

use File::Path qw(make_path);
use File::Spec;
use File::Temp qw(tempdir);
use Test::More;

use lib 'lib';

use Markdown::CLI ();

sub slurp {
    my ($path) = @_;
    open my $fh, '<', $path or die "Unable to read $path: $!";
    local $/;
    return <$fh>;
}

sub fake_runner {
    return sub {
        my ($argv) = @_;
        if ( $argv->[0] eq 'pandoc' ) {
            my $from = $argv->[-1];
            my ($to) = grep { defined } map { $argv->[$_] eq '--output' ? $argv->[ $_ + 1 ] : undef } 0 .. $#$argv;
            my $source = slurp($from);
            if ( grep { $_ eq 'html5' } @{$argv} ) {
                open my $fh, '>', $to or die "Unable to write $to: $!";
                print {$fh} "<html><body>$source</body></html>\n";
                close $fh or die "Unable to close $to: $!";
                return 1;
            }
            open my $fh, '>', $to or die "Unable to write $to: $!";
            $source =~ s/<[^>]+>//g;
            print {$fh} $source;
            close $fh or die "Unable to close $to: $!";
            return 1;
        }
        if ( $argv->[0] eq 'wkhtmltopdf' ) {
            open my $fh, '>', $argv->[2] or die "Unable to write $argv->[2]: $!";
            print {$fh} "PDF\n" . slurp( $argv->[1] );
            close $fh or die "Unable to close $argv->[2]: $!";
            return 1;
        }
        if ( $argv->[0] eq 'pdftohtml' ) {
            open my $fh, '>', $argv->[5] or die "Unable to write $argv->[5]: $!";
            print {$fh} "<html><body>Recovered from PDF</body></html>\n";
            close $fh or die "Unable to close $argv->[5]: $!";
            return 1;
        }
        die "Unexpected command: @$argv";
    };
}

{
    my $tmp = tempdir( CLEANUP => 1 );
    my $from = File::Spec->catfile( $tmp, 'note.md' );
    open my $fh, '>', $from or die "Unable to write $from: $!";
    print {$fh} "# hello\n";
    close $fh or die "Unable to close $from: $!";

    my $stdout = '';
    open my $out, '>', \$stdout or die "Unable to open stdout scalar: $!";
    local *STDOUT = $out;

    my $exit = Markdown::CLI::main(
        argv   => [ '--from', $from, '--pdf' ],
        runner => Markdown::Runner->new( run_command => fake_runner() ),
    );

    is( $exit, 0, 'markdown to pdf flow exits successfully' );
    like( $stdout, qr/"target_format":"pdf"/, 'markdown to pdf reports the target format as json' );
    my $pdf = File::Spec->catfile( $tmp, 'note.pdf' );
    ok( -f $pdf, 'markdown to pdf flow creates the expected pdf file' );
    like( slurp($pdf), qr/^PDF/m, 'fake pdf converter wrote the target file' );
}

{
    my $tmp = tempdir( CLEANUP => 1 );
    my $from = File::Spec->catfile( $tmp, 'note.md' );
    open my $fh, '>', $from or die "Unable to write $from: $!";
    print {$fh} "# hello\n";
    close $fh or die "Unable to close $from: $!";

    my $stdout = '';
    open my $out, '>', \$stdout or die "Unable to open stdout scalar: $!";
    local *STDOUT = $out;

    my $exit = Markdown::CLI::main(
        argv   => [ '--from', $from, '--html', '--to', File::Spec->catfile( $tmp, 'page' ) ],
        runner => Markdown::Runner->new( run_command => fake_runner() ),
    );

    is( $exit, 0, 'markdown to html flow exits successfully' );
    like( $stdout, qr/"target_format":"html"/, 'markdown to html reports the target format as json' );
    my $html = File::Spec->catfile( $tmp, 'page.html' );
    ok( -f $html, 'markdown to html flow creates the expected html file' );
    like( slurp($html), qr/<html>/, 'fake html converter wrote the html output' );
}

{
    my $tmp = tempdir( CLEANUP => 1 );
    my $from = File::Spec->catfile( $tmp, 'page.html' );
    open my $fh, '>', $from or die "Unable to write $from: $!";
    print {$fh} "<h1>hello</h1>\n";
    close $fh or die "Unable to close $from: $!";

    my $stdout = '';
    open my $out, '>', \$stdout or die "Unable to open stdout scalar: $!";
    local *STDOUT = $out;

    my $exit = Markdown::CLI::main(
        argv   => [ '--from', $from ],
        runner => Markdown::Runner->new( run_command => fake_runner() ),
    );

    is( $exit, 0, 'html to markdown flow exits successfully' );
    like( $stdout, qr/"target_format":"markdown"/, 'html to markdown reports markdown output as json' );
    my $md = File::Spec->catfile( $tmp, 'page.md' );
    ok( -f $md, 'html to markdown flow creates the expected markdown file' );
    unlike( slurp($md), qr/<h1>/, 'html tags were stripped by the fake markdown route' );
}

{
    my $tmp = tempdir( CLEANUP => 1 );
    my $from = File::Spec->catfile( $tmp, 'scan.pdf' );
    open my $fh, '>', $from or die "Unable to write $from: $!";
    print {$fh} "%PDF fake\n";
    close $fh or die "Unable to close $from: $!";

    my $stdout = '';
    open my $out, '>', \$stdout or die "Unable to open stdout scalar: $!";
    local *STDOUT = $out;

    my $exit = Markdown::CLI::main(
        argv   => [ '--from', $from ],
        runner => Markdown::Runner->new( run_command => fake_runner() ),
    );

    is( $exit, 0, 'pdf to markdown flow exits successfully' );
    like( $stdout, qr/"source_format":"pdf"/, 'pdf to markdown reports the source format as json' );
    my $md = File::Spec->catfile( $tmp, 'scan.md' );
    ok( -f $md, 'pdf to markdown flow creates the expected markdown file' );
    like( slurp($md), qr/Recovered from PDF/, 'fake pdf restore content reached the markdown file' );
}

{
    my $stderr = '';
    open my $err, '>', \$stderr or die "Unable to open stderr scalar: $!";
    local *STDERR = $err;

    my $exit = Markdown::CLI::main( argv => [] );
    is( $exit, 1, 'missing arguments return a usage error' );
    like( $stderr, qr/^Usage: dashboard markdown\.convert/, 'usage error explains the markdown command syntax' );
}

{
    my $stderr = '';
    open my $err, '>', \$stderr or die "Unable to open stderr scalar: $!";
    local *STDERR = $err;

    my $exit = Markdown::CLI::main( argv => [ '--bogus' ] );
    is( $exit, 1, 'unknown getopt flags return a usage error' );
    like( $stderr, qr/Usage: dashboard markdown\.convert/s, 'unknown getopt flags still print usage guidance' );
}

{
    my $tmp = tempdir( CLEANUP => 1 );
    my $from = File::Spec->catfile( $tmp, 'note.md' );
    open my $fh, '>', $from or die "Unable to write $from: $!";
    print {$fh} "# hello\n";
    close $fh or die "Unable to close $from: $!";

    my $stderr = '';
    open my $err, '>', \$stderr or die "Unable to open stderr scalar: $!";
    local *STDERR = $err;

    my $exit = Markdown::CLI::main( argv => [ '--from', $from, 'extra' ] );
    is( $exit, 1, 'unexpected trailing args return a usage error' );
    like( $stderr, qr/^Unexpected arguments: extra/m, 'unexpected trailing args are listed' );
}

{
    my $tmp = tempdir( CLEANUP => 1 );
    my $from = File::Spec->catfile( $tmp, 'note.md' );
    open my $fh, '>', $from or die "Unable to write $from: $!";
    print {$fh} "# hello\n";
    close $fh or die "Unable to close $from: $!";

    my $stderr = '';
    open my $err, '>', \$stderr or die "Unable to open stderr scalar: $!";
    local *STDERR = $err;

    my $runner = Markdown::Runner->new( run_command => sub { die "tool failed\n" } );
    my $exit = Markdown::CLI::main( argv => [ '--from', $from, '--html' ], runner => $runner );
    is( $exit, 1, 'runner failures return a non-zero exit' );
    like( $stderr, qr/^tool failed$/m, 'runner failures are reported clearly' );
}

done_testing;
