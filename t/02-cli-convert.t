use strict;
use warnings;

use File::Spec;
use File::Temp qw(tempdir);
use Test::More;

use lib 'lib';

use Markdown::CLI ();
use Markdown::Runner;

{
    package TestMarkdownRunner;
}

{
    my $tmp = tempdir( CLEANUP => 1 );
    my $from = File::Spec->catfile( $tmp, 'note.md' );
    open my $fh, '>', $from or die "Unable to write $from: $!";
    print {$fh} "# hello\n";
    close $fh or die "Unable to close $from: $!";

    my $stdout = '';
    my $stderr = '';
    open my $out, '>', \$stdout or die "Unable to open stdout scalar: $!";
    open my $err, '>', \$stderr or die "Unable to open stderr scalar: $!";
    local *STDOUT = $out;
    local *STDERR = $err;

    my $exit = Markdown::CLI::main(
        argv   => [ $from, File::Spec->catfile( $tmp, 'note.pdf' ) ],
        runner => Markdown::Runner->new(
            markdown_to_html => sub { return "<html><body># hello</body></html>\n" },
            markdown_to_pdf  => sub {
                my ( $markdown, $to ) = @_;
                open my $pdf, '>', $to or die "Unable to write $to: $!";
                print {$pdf} "PDF\n$markdown";
                close $pdf or die "Unable to close $to: $!";
                return 1;
            },
            html_to_markdown => sub { return "# hello\n" },
            pdf_to_markdown => sub { return "Recovered from PDF\n"; },
            logger          => sub { print STDERR "[markdown] $_[0]\n" },
        ),
    );

    is( $exit, 0, 'markdown to pdf flow exits successfully' );
    like( $stdout, qr/"target_format":"pdf"/, 'markdown to pdf reports the target format as json' );
    like( $stderr, qr/\[markdown\] target_format=pdf/, 'markdown to pdf logs progress to stderr' );
    ok( -f File::Spec->catfile( $tmp, 'note.pdf' ), 'markdown to pdf flow creates the expected pdf file' );
}

{
    my $tmp = tempdir( CLEANUP => 1 );
    my $from = File::Spec->catfile( $tmp, 'note.md' );
    open my $fh, '>', $from or die "Unable to write $from: $!";
    print {$fh} "# hello\n";
    close $fh or die "Unable to close $from: $!";

    my $stdout = '';
    my $stderr = '';
    my $seen;
    open my $out, '>', \$stdout or die "Unable to open stdout scalar: $!";
    open my $err, '>', \$stderr or die "Unable to open stderr scalar: $!";
    local *STDOUT = $out;
    local *STDERR = $err;

    my $exit = Markdown::CLI::main(
        argv   => [ $from, File::Spec->catfile( $tmp, 'note.pdf' ), '--paper', 'A3', '--landscape' ],
        runner => Markdown::Runner->new(
            markdown_to_html => sub { return "<html><body># hello</body></html>\n" },
            markdown_to_pdf  => sub {
                my ( $markdown, $to, $layout ) = @_;
                $seen = $layout;
                open my $pdf, '>', $to or die "Unable to write $to: $!";
                print {$pdf} "PDF\n$markdown";
                close $pdf or die "Unable to close $to: $!";
                return 1;
            },
            html_to_markdown => sub { return "# hello\n" },
            pdf_to_markdown  => sub { return "Recovered from PDF\n"; },
            logger           => sub { print STDERR "[markdown] $_[0]\n" },
        ),
    );

    is( $exit, 0, 'pdf flow accepts paper and orientation flags' );
    is( $seen->{paper}, 'A3', 'cli passes paper selection to the runner' );
    is( $seen->{orientation}, 'landscape', 'cli passes orientation selection to the runner' );
    like( $stdout, qr/"paper":"A3"/, 'pdf json result includes paper size' );
    like( $stdout, qr/"orientation":"landscape"/, 'pdf json result includes orientation' );
}

{
    my $tmp = tempdir( CLEANUP => 1 );
    my $from = File::Spec->catfile( $tmp, 'note.md' );
    open my $fh, '>', $from or die "Unable to write $from: $!";
    print {$fh} "# hello\n";
    close $fh or die "Unable to close $from: $!";

    my $seen;
    my $stdout = '';
    open my $out, '>', \$stdout or die "Unable to open stdout scalar: $!";
    local *STDOUT = $out;

    my $exit = Markdown::CLI::main(
        argv   => [ $from, File::Spec->catfile( $tmp, 'note.pdf' ), '-A', '2' ],
        runner => Markdown::Runner->new(
            markdown_to_html => sub { return "<html><body># hello</body></html>\n" },
            markdown_to_pdf  => sub {
                my ( $markdown, $to, $layout ) = @_;
                $seen = $layout;
                open my $pdf, '>', $to or die "Unable to write $to: $!";
                print {$pdf} "PDF\n$markdown";
                close $pdf or die "Unable to close $to: $!";
                return 1;
            },
            html_to_markdown => sub { return "# hello\n" },
            pdf_to_markdown  => sub { return "Recovered from PDF\n"; },
            logger           => sub { },
        ),
    );

    is( $exit, 0, 'pdf flow accepts the -A shorthand' );
    is( $seen->{paper}, 'A2', 'A shorthand maps the requested paper size to A2' );
    like( $stdout, qr/"paper":"A2"/, 'pdf json result includes the normalized shorthand paper size' );
}

{
    my $tmp = tempdir( CLEANUP => 1 );
    my $from = File::Spec->catfile( $tmp, 'note.md' );
    open my $fh, '>', $from or die "Unable to write $from: $!";
    print {$fh} "# hello\n";
    close $fh or die "Unable to close $from: $!";

    my $stdout = '';
    my $stderr = '';
    open my $out, '>', \$stdout or die "Unable to open stdout scalar: $!";
    open my $err, '>', \$stderr or die "Unable to open stderr scalar: $!";
    local *STDOUT = $out;
    local *STDERR = $err;

    my $exit = Markdown::CLI::main(
        argv   => [ $from, File::Spec->catfile( $tmp, 'page.html' ) ],
        runner => Markdown::Runner->new(
            markdown_to_html => sub { return "<html><body># hello</body></html>\n" },
            markdown_to_pdf  => sub { die "should not render pdf\n" },
            html_to_markdown => sub { return "# hello\n" },
            pdf_to_markdown  => sub { return "Recovered from PDF\n"; },
            logger           => sub { print STDERR "[markdown] $_[0]\n" },
        ),
    );

    is( $exit, 0, 'markdown to html flow exits successfully' );
    like( $stdout, qr/"target_format":"html"/, 'markdown to html reports the target format as json' );
    like( $stderr, qr/\[markdown\] step=markdown_to_html\.perl/, 'markdown to html logs the pure perl conversion step' );
    ok( -f File::Spec->catfile( $tmp, 'page.html' ), 'markdown to html flow creates the expected html file' );
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
        argv   => [ $from ],
        runner => Markdown::Runner->new(
            markdown_to_html => sub { return "<html><body># hello</body></html>\n" },
            markdown_to_pdf  => sub { die "should not render pdf\n" },
            html_to_markdown => sub { return "# hello\n" },
            pdf_to_markdown  => sub { return "Recovered from PDF\n"; },
            logger           => sub { },
        ),
    );

    is( $exit, 0, 'html to markdown flow exits successfully' );
    like( $stdout, qr/"target_format":"markdown"/, 'html to markdown reports markdown output as json' );
    ok( -f File::Spec->catfile( $tmp, 'page.md' ), 'html to markdown flow creates the expected markdown file' );
}

{
    my $tmp = tempdir( CLEANUP => 1 );
    my $from = File::Spec->catfile( $tmp, 'scan.pdf' );
    open my $fh, '>', $from or die "Unable to write $from: $!";
    print {$fh} "%PDF fake\n";
    close $fh or die "Unable to close $from: $!";

    my $stdout = '';
    my $stderr = '';
    open my $out, '>', \$stdout or die "Unable to open stdout scalar: $!";
    open my $err, '>', \$stderr or die "Unable to open stderr scalar: $!";
    local *STDOUT = $out;
    local *STDERR = $err;

    my $exit = Markdown::CLI::main(
        argv   => [ $from ],
        runner => Markdown::Runner->new(
            markdown_to_html => sub { return "<html><body># hello</body></html>\n" },
            markdown_to_pdf  => sub { die "should not render pdf\n" },
            html_to_markdown => sub { return "# hello\n" },
            pdf_to_markdown  => sub { return "Recovered from PDF\n"; },
            logger           => sub { print STDERR "[markdown] $_[0]\n" },
        ),
    );

    is( $exit, 0, 'pdf to markdown flow exits successfully' );
    like( $stdout, qr/"source_format":"pdf"/, 'pdf to markdown reports the source format as json' );
    like( $stderr, qr/\[markdown\] step=pdf_to_markdown\.perl/, 'pdf to markdown logs the pure perl step' );
    ok( -f File::Spec->catfile( $tmp, 'scan.md' ), 'pdf to markdown flow creates the expected markdown file' );
}

{
    my $stderr = '';
    open my $err, '>', \$stderr or die "Unable to open stderr scalar: $!";
    local *STDERR = $err;

    my $exit = Markdown::CLI::main( argv => [ 'a.md', 'b.html', 'c.pdf' ] );
    is( $exit, 1, 'more than two positional args return a usage error' );
    like( $stderr, qr/^Unexpected arguments: a\.md b\.html c\.pdf/m, 'too many positional args are reported clearly' );
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

    my $exit = Markdown::CLI::main( argv => [ $from, File::Spec->catfile( $tmp, 'note.pdf' ), '--paper', 'A3', '-A', '4' ] );
    is( $exit, 1, 'multiple paper size selectors are rejected' );
    like( $stderr, qr/^Choose only one paper size selection/m, 'multiple paper size selectors report a clear error' );
}

{
    my $tmp = tempdir( CLEANUP => 1 );
    my $from = File::Spec->catfile( $tmp, 'page.html' );
    open my $fh, '>', $from or die "Unable to write $from: $!";
    print {$fh} "<h1>hello</h1>\n";
    close $fh or die "Unable to close $from: $!";

    my $stderr = '';
    open my $err, '>', \$stderr or die "Unable to open stderr scalar: $!";
    local *STDERR = $err;

    my $exit = Markdown::CLI::main( argv => [ $from, '--paper', 'A3' ] );
    is( $exit, 1, 'non-pdf routes reject pdf-only paper flags' );
    like( $stderr, qr/^PDF layout flags are only valid for PDF output/m, 'paper flag rejection explains the scope clearly' );
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

    my $exit = Markdown::CLI::main( argv => [ '--from', $from, '--to', 'out.html', 'extra' ] );
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

    my $runner = Markdown::Runner->new(
        markdown_to_html => sub { die "tool failed\n" },
        markdown_to_pdf  => sub { return 1 },
        html_to_markdown => sub { return "# hello\n" },
        pdf_to_markdown  => sub { return "Recovered from PDF\n"; },
    );
    my $exit = Markdown::CLI::main( argv => [ $from, File::Spec->catfile( $tmp, 'note.html' ) ], runner => $runner );
    is( $exit, 1, 'runner failures return a non-zero exit' );
    like( $stderr, qr/^tool failed$/m, 'runner failures are reported clearly' );
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

    my $exit = Markdown::CLI::main( argv => [ $from ] );
    is( $exit, 1, 'markdown source without a target still returns a non-zero exit' );
    like( $stderr, qr/^Markdown source needs a target format/m, 'missing target still explains the markdown requirement' );
}

{
    my $tmp = tempdir( CLEANUP => 1 );
    my $from = File::Spec->catfile( $tmp, 'page.html' );
    my $to   = File::Spec->catfile( $tmp, 'page.md' );
    open my $fh, '>', $from or die "Unable to write $from: $!";
    print {$fh} "<h1>hello</h1>\n";
    close $fh or die "Unable to close $from: $!";

    my $stdout = '';
    my $stderr = '';
    open my $out, '>', \$stdout or die "Unable to open stdout scalar: $!";
    open my $err, '>', \$stderr or die "Unable to open stderr scalar: $!";
    local *STDOUT = $out;
    local *STDERR = $err;

    no warnings 'redefine';
    no warnings 'once';
    local *Markdown::Runner::new = sub {
        my ( $class, %args ) = @_;
        return bless \%args, 'TestMarkdownRunner';
    };
    local *TestMarkdownRunner::convert = sub {
        my ( $self, %args ) = @_;
        $self->{logger}->('default logger proof');
        return {
            from          => $args{from},
            to            => $args{to},
            source_format => 'html',
            target_format => 'markdown',
        };
    };

    my $exit = Markdown::CLI::main( argv => [ $from, $to ] );
    is( $exit, 0, 'cli can instantiate a default runner with the built-in logger path' );
    like( $stderr, qr/\[markdown\] default logger proof/, 'default logger writes progress to stderr' );
    like( $stdout, qr/"target_format":"markdown"/, 'default runner path still prints json to stdout' );
}

done_testing;
