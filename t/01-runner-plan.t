use strict;
use warnings;

use File::Spec;
use File::Temp qw(tempdir);
use Test::More;

use lib 'lib';

use Markdown::Runner;

my $runner = Markdown::Runner->new( run_command => sub { 1 } );

{
    my $tmp = tempdir( CLEANUP => 1 );
    my $from = File::Spec->catfile( $tmp, 'note.md' );
    open my $fh, '>', $from or die "Unable to write $from: $!";
    print {$fh} "# hello\n";
    close $fh or die "Unable to close $from: $!";

    my $result = $runner->convert( from => $from, to_html => 1 );
    is( $result->{target_format}, 'html', 'markdown with --to-html targets html' );
    is( $result->{to}, File::Spec->catfile( $tmp, 'note.html' ), 'default html output keeps basename' );
}

{
    my $tmp = tempdir( CLEANUP => 1 );
    my $from = File::Spec->catfile( $tmp, 'note.md' );
    open my $fh, '>', $from or die "Unable to write $from: $!";
    print {$fh} "# hello\n";
    close $fh or die "Unable to close $from: $!";

    my $result = $runner->convert( from => $from, to_pdf => 1, to => File::Spec->catfile( $tmp, 'custom-output' ) );
    is( $result->{target_format}, 'pdf', 'markdown with --to-pdf targets pdf' );
    is( $result->{to}, File::Spec->catfile( $tmp, 'custom-output.pdf' ), 'pdf output appends extension when missing' );
}

{
    my $tmp = tempdir( CLEANUP => 1 );
    my $from = File::Spec->catfile( $tmp, 'page.html' );
    open my $fh, '>', $from or die "Unable to write $from: $!";
    print {$fh} "<h1>hello</h1>\n";
    close $fh or die "Unable to close $from: $!";

    my $result = $runner->convert( from => $from );
    is( $result->{target_format}, 'markdown', 'html defaults to markdown output' );
    is( $result->{to}, File::Spec->catfile( $tmp, 'page.md' ), 'html source defaults to md sibling path' );
}

{
    my $tmp = tempdir( CLEANUP => 1 );
    my $from = File::Spec->catfile( $tmp, 'scan.pdf' );
    open my $fh, '>', $from or die "Unable to write $from: $!";
    print {$fh} "%PDF fake\n";
    close $fh or die "Unable to close $from: $!";

    my $result = $runner->convert( from => $from, to => File::Spec->catfile( $tmp, 'restored.markdown' ) );
    is( $result->{target_format}, 'markdown', 'pdf converts back to markdown' );
    is( $result->{to}, File::Spec->catfile( $tmp, 'restored.markdown' ), 'markdown output path accepts the .markdown extension' );
}

{
    my $tmp = tempdir( CLEANUP => 1 );
    my $from = File::Spec->catfile( $tmp, 'scan.pdf' );
    open my $fh, '>', $from or die "Unable to write $from: $!";
    print {$fh} "%PDF fake\n";
    close $fh or die "Unable to close $from: $!";

    my $error = eval { $runner->convert( from => $from, to_pdf => 1 ); 1 };
    ok( !$error, 'pdf source rejects a pdf target flag' );
    like( $@, qr/^PDF source can only convert to markdown/, 'pdf source reports unsupported target format clearly' );
}

{
    my $tmp = tempdir( CLEANUP => 1 );
    my $from = File::Spec->catfile( $tmp, 'note.md' );
    open my $fh, '>', $from or die "Unable to write $from: $!";
    print {$fh} "# hello\n";
    close $fh or die "Unable to close $from: $!";

    my $error = eval { $runner->convert( from => $from, to_pdf => 1, to_html => 1 ); 1 };
    ok( !$error, 'conflicting markdown target flags are rejected' );
    like( $@, qr/^Choose only one/, 'conflicting target flags explain the conflict' );
}

{
    my $tmp = tempdir( CLEANUP => 1 );
    my $from = File::Spec->catfile( $tmp, 'note.md' );
    open my $fh, '>', $from or die "Unable to write $from: $!";
    print {$fh} "# hello\n";
    close $fh or die "Unable to close $from: $!";

    my $error = eval { $runner->convert( from => $from, to => File::Spec->catfile( $tmp, 'ambiguous' ) ); 1 };
    ok( !$error, 'markdown without a target extension or format flag is rejected' );
    like( $@, qr/^Markdown source needs/, 'ambiguous markdown target is explained clearly' );
}

{
    my $tmp = tempdir( CLEANUP => 1 );
    my $from = File::Spec->catfile( $tmp, 'plain.md' );
    open my $fh, '>', $from or die "Unable to write $from: $!";
    print {$fh} "# hello\n";
    close $fh or die "Unable to close $from: $!";

    my $error = eval { $runner->convert( from => $from ); 1 };
    ok( !$error, 'markdown without any target selector is rejected directly by the runner' );
    like( $@, qr/^Markdown source needs a target format/, 'runner explains the missing markdown target format clearly' );
}

{
    my $tmp = tempdir( CLEANUP => 1 );
    my $from = File::Spec->catfile( $tmp, 'page.html' );
    open my $fh, '>', $from or die "Unable to write $from: $!";
    print {$fh} "<h1>hello</h1>\n";
    close $fh or die "Unable to close $from: $!";

    my $error = eval { $runner->convert( from => $from, to => File::Spec->catfile( $tmp, 'bad.pdf' ) ); 1 };
    ok( !$error, 'html source rejects non-markdown output extensions' );
    like( $@, qr/^Only markdown output is supported for html input/, 'html source explains the allowed output type' );
}

{
    my $tmp = tempdir( CLEANUP => 1 );
    my $from = File::Spec->catfile( $tmp, 'page.txt' );
    open my $fh, '>', $from or die "Unable to write $from: $!";
    print {$fh} "plain text\n";
    close $fh or die "Unable to close $from: $!";

    my $error = eval { $runner->convert( from => $from ); 1 };
    ok( !$error, 'unsupported source extensions are rejected' );
    like( $@, qr/^Unsupported source extension: \.txt/, 'unsupported source extension is reported clearly' );
}

{
    my $tmp = tempdir( CLEANUP => 1 );
    my $from = File::Spec->catfile( $tmp, 'note.md' );
    open my $fh, '>', $from or die "Unable to write $from: $!";
    print {$fh} "# hello\n";
    close $fh or die "Unable to close $from: $!";

    local *Markdown::Runner::_target_format_for = sub { return 'weird' };
    local *Markdown::Runner::_output_path = sub { return File::Spec->catfile( $tmp, 'out.weird' ) };
    my $error = eval { $runner->convert( from => $from, to_html => 1 ); 1 };
    ok( !$error, 'unsupported internal conversion routes still fail safely' );
    like( $@, qr/^Unsupported conversion route: markdown -> weird/, 'unsupported route includes both formats' );
}

{
    my $ok = eval { Markdown::Runner::_default_run_command( ['perl', '-e', 'exit 0'] ); 1 };
    ok( $ok, 'default command runner succeeds for a zero exit status' );
}

{
    my $ok = eval { Markdown::Runner::_default_run_command( ['perl', '-e', 'exit 1'] ); 1 };
    ok( !$ok, 'default command runner dies for a non-zero exit status' );
    like( $@, qr/^Failed to run perl -e exit 1/, 'default command runner reports the failed command' );
}

done_testing;
