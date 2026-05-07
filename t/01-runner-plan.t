use strict;
use warnings;

use Cwd qw(abs_path);
use File::Spec;
use File::Temp qw(tempdir);
use Test::More;
use Fcntl qw(:mode);

use lib 'lib';

use Markdown::Runner;

my $runner = Markdown::Runner->new(
    markdown_to_html => sub { return "<html><body>$_[0]</body></html>\n" },
    markdown_to_pdf  => sub {
        my ( $markdown, $to ) = @_;
        open my $fh, '>', $to or die "Unable to write $to: $!";
        print {$fh} "PDF\n$markdown";
        close $fh or die "Unable to close $to: $!";
        return 1;
    },
    html_to_markdown => sub { my ($html) = @_; $html =~ s/<[^>]+>//g; return $html; },
    pdf_to_markdown => sub { return "Recovered from PDF\n"; },
    docx_to_pdf     => sub {
        my ( $from, $to ) = @_;
        open my $fh, '>', $to or die "Unable to write $to: $!";
        print {$fh} "PDF from DOCX\n";
        close $fh or die "Unable to close $to: $!";
        return 1;
    },
    pdf_to_docx     => sub {
        my ( $from, $to ) = @_;
        open my $fh, '>', $to or die "Unable to write $to: $!";
        print {$fh} "DOCX from PDF\n";
        close $fh or die "Unable to close $to: $!";
        return 1;
    },
);

{
    my $tmp = tempdir( CLEANUP => 1 );
    my $from = File::Spec->catfile( $tmp, 'note.md' );
    open my $fh, '>', $from or die "Unable to write $from: $!";
    print {$fh} "# hello\n";
    close $fh or die "Unable to close $from: $!";

    my $result = $runner->convert( from => $from, to => File::Spec->catfile( $tmp, 'custom.html' ) );
    is( $result->{target_format}, 'html', 'markdown with an .html target selects html' );
    is( $result->{to}, File::Spec->catfile( $tmp, 'custom.html' ), 'html output keeps the provided extension' );
}

{
    my $tmp = tempdir( CLEANUP => 1 );
    my $from = File::Spec->catfile( $tmp, 'note.md' );
    open my $fh, '>', $from or die "Unable to write $from: $!";
    print {$fh} "# hello\n";
    close $fh or die "Unable to close $from: $!";

    my $result = $runner->convert( from => $from, to => File::Spec->catfile( $tmp, 'custom-output' ), to_pdf => 1 );
    is( $result->{target_format}, 'pdf', 'markdown with --to-pdf targets pdf' );
    is( $result->{to}, File::Spec->catfile( $tmp, 'custom-output.pdf' ), 'pdf output appends extension when missing' );
}

{
    my $tmp = tempdir( CLEANUP => 1 );
    my $from = File::Spec->catfile( $tmp, 'report.docx' );
    open my $fh, '>', $from or die "Unable to write $from: $!";
    print {$fh} "fake docx\n";
    close $fh or die "Unable to close $from: $!";

    my $result = $runner->convert( from => $from );
    is( $result->{source_format}, 'docx', 'docx source is detected' );
    is( $result->{target_format}, 'markdown', 'docx defaults to markdown output' );
    is( $result->{to}, File::Spec->catfile( $tmp, 'report.md' ), 'docx source defaults to sibling markdown output' );
}

{
    my $tmp = tempdir( CLEANUP => 1 );
    my $from = File::Spec->catfile( $tmp, 'report.docx' );
    open my $fh, '>', $from or die "Unable to write $from: $!";
    print {$fh} "fake docx\n";
    close $fh or die "Unable to close $from: $!";

    my $result = $runner->convert( from => $from, to => File::Spec->catfile( $tmp, 'report.pdf' ) );
    is( $result->{target_format}, 'pdf', 'docx still targets pdf explicitly when the output path ends in .pdf' );
    is( $result->{to}, File::Spec->catfile( $tmp, 'report.pdf' ), 'docx keeps the explicit pdf output path' );
}

{
    my $tmp = tempdir( CLEANUP => 1 );
    my $from = File::Spec->catfile( $tmp, 'report.docx' );
    open my $fh, '>', $from or die "Unable to write $from: $!";
    print {$fh} "fake docx\n";
    close $fh or die "Unable to close $from: $!";

    my $result = $runner->convert( from => $from, to => File::Spec->catfile( $tmp, 'report.md' ) );
    is( $result->{target_format}, 'markdown', 'docx can target markdown explicitly' );
    is( $result->{to}, File::Spec->catfile( $tmp, 'report.md' ), 'docx keeps the explicit markdown output path' );
}

{
    my $tmp = tempdir( CLEANUP => 1 );
    my $from = File::Spec->catfile( $tmp, 'scan.pdf' );
    open my $fh, '>', $from or die "Unable to write $from: $!";
    print {$fh} "%PDF fake\n";
    close $fh or die "Unable to close $from: $!";

    my $result = $runner->convert( from => $from, to => File::Spec->catfile( $tmp, 'scan.docx' ) );
    is( $result->{target_format}, 'docx', 'pdf can target docx explicitly' );
    is( $result->{to}, File::Spec->catfile( $tmp, 'scan.docx' ), 'pdf to docx keeps the provided output path' );
}

{
    my $tmp = tempdir( CLEANUP => 1 );
    my $from = File::Spec->catfile( $tmp, 'report.docx' );
    open my $fh, '>', $from or die "Unable to write $from: $!";
    print {$fh} "fake docx\n";
    close $fh or die "Unable to close $from: $!";

    my $error = eval { $runner->convert( from => $from, to => File::Spec->catfile( $tmp, 'report.html' ) ); 1 };
    ok( !$error, 'docx rejects non-pdf non-markdown targets' );
    like( $@, qr/^DOCX source can only convert to markdown or pdf/, 'docx reports the allowed targets clearly' );
}

{
    my $tmp = tempdir( CLEANUP => 1 );
    my $from = File::Spec->catfile( $tmp, 'report.docx' );
    open my $fh, '>', $from or die "Unable to write $from: $!";
    print {$fh} "fake docx\n";
    close $fh or die "Unable to close $from: $!";

    my $error = eval { $runner->convert( from => $from, paper => 'A4' ); 1 };
    ok( !$error, 'docx routes reject markdown-only pdf layout flags' );
    like( $@, qr/^PDF layout flags are only valid for markdown to PDF output/, 'docx layout-flag rejection is explicit' );
}

{
    my $tmp = tempdir( CLEANUP => 1 );
    my $from = File::Spec->catfile( $tmp, 'note.md' );
    my $seen;
    open my $fh, '>', $from or die "Unable to write $from: $!";
    print {$fh} "# hello\n";
    close $fh or die "Unable to close $from: $!";

    my $layout_runner = Markdown::Runner->new(
        markdown_to_html => sub { return "<html><body>$_[0]</body></html>\n" },
        markdown_to_pdf  => sub {
            my ( $markdown, $to, $layout ) = @_;
            $seen = $layout;
            open my $pdf, '>', $to or die "Unable to write $to: $!";
            print {$pdf} "PDF\n$markdown";
            close $pdf or die "Unable to close $to: $!";
            return 1;
        },
        html_to_markdown => sub { my ($html) = @_; $html =~ s/<[^>]+>//g; return $html; },
        pdf_to_markdown  => sub { return "Recovered from PDF\n"; },
    );

    my $result = $layout_runner->convert(
        from      => $from,
        to        => File::Spec->catfile( $tmp, 'layout.pdf' ),
        paper     => 'a3',
        landscape => 1,
    );
    is( $result->{paper}, 'A3', 'runner normalizes paper size into the json result' );
    is( $result->{orientation}, 'landscape', 'runner reports landscape orientation in the json result' );
    is( $seen->{paper}, 'A3', 'runner passes normalized paper size to the pdf renderer' );
    is( $seen->{orientation}, 'landscape', 'runner passes normalized orientation to the pdf renderer' );
}

{
    my $tmp = tempdir( CLEANUP => 1 );
    my $from = File::Spec->catfile( $tmp, 'note.md' );
    my $seen;
    open my $fh, '>', $from or die "Unable to write $from: $!";
    print {$fh} "# hello\n";
    close $fh or die "Unable to close $from: $!";

    my $layout_runner = Markdown::Runner->new(
        markdown_to_html => sub { return "<html><body>$_[0]</body></html>\n" },
        markdown_to_pdf  => sub {
            my ( $markdown, $to, $layout ) = @_;
            $seen = $layout;
            open my $pdf, '>', $to or die "Unable to write $to: $!";
            print {$pdf} "PDF\n$markdown";
            close $pdf or die "Unable to close $to: $!";
            return 1;
        },
        html_to_markdown => sub { my ($html) = @_; $html =~ s/<[^>]+>//g; return $html; },
        pdf_to_markdown  => sub { return "Recovered from PDF\n"; },
    );

    my $result = $layout_runner->convert(
        from  => $from,
        to    => File::Spec->catfile( $tmp, 'layout.pdf' ),
        paper => 'ansi-c',
    );
    is( $result->{paper}, 'ANSI-C', 'runner normalizes ANSI paper size into the json result' );
    is( $seen->{paper}, 'ANSI-C', 'runner passes normalized ANSI paper size to the pdf renderer' );
}

{
    my $tmp = tempdir( CLEANUP => 1 );
    my $from = File::Spec->catfile( $tmp, 'note.md' );
    my $seen;
    open my $fh, '>', $from or die "Unable to write $from: $!";
    print {$fh} "# hello\n";
    close $fh or die "Unable to close $from: $!";    

    my $layout_runner = Markdown::Runner->new(
        markdown_to_html => sub { return "<html><body>$_[0]</body></html>\n" },
        markdown_to_pdf  => sub {
            my ( $markdown, $to, $layout ) = @_;
            $seen = $layout;
            open my $pdf, '>', $to or die "Unable to write $to: $!";
            print {$pdf} "PDF\n$markdown";
            close $pdf or die "Unable to close $to: $!";
            return 1;
        },
        html_to_markdown => sub { my ($html) = @_; $html =~ s/<[^>]+>//g; return $html; },
        pdf_to_markdown  => sub { return "Recovered from PDF\n"; },
    );

    my $result = $layout_runner->convert(
        from  => $from,
        to    => File::Spec->catfile( $tmp, 'layout.pdf' ),
        paper => 'dl',
    );
    is( $result->{paper}, 'DL', 'runner normalizes DL paper size into the json result' );
    is( $seen->{paper}, 'DL', 'runner passes normalized DL paper size to the pdf renderer' );
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
    my $from = File::Spec->catfile( $tmp, 'report.docx' );
    my $to   = File::Spec->catfile( $tmp, 'report.pdf' );
    my @cmd;
    open my $fh, '>', $from or die "Unable to write $from: $!";
    print {$fh} "fake docx\n";
    close $fh or die "Unable to close $from: $!";

    my $linux_runner = Markdown::Runner->new(
        platform     => 'linux',
        find_binary  => sub { return '/usr/bin/soffice' if $_[0] eq 'soffice'; return; },
        run_command  => sub {
            @cmd = @_;
            open my $out, '>', $to or die "Unable to write $to: $!";
            print {$out} "PDF\n";
            close $out or die "Unable to close $to: $!";
            return 1;
        },
    );

    $linux_runner->_docx_to_pdf( $from, $to );
    is_deeply(
        \@cmd,
        [ '/usr/bin/soffice', '--headless', '--convert-to', 'pdf', '--outdir', $tmp, abs_path($from) ],
        'linux docx to pdf uses soffice conversion'
    );
}

{
    my $tmp = tempdir( CLEANUP => 1 );
    my $from = File::Spec->catfile( $tmp, 'scan.pdf' );
    my $to   = File::Spec->catfile( $tmp, 'scan.docx' );
    my @cmd;
    open my $fh, '>', $from or die "Unable to write $from: $!";
    print {$fh} "%PDF fake\n";
    close $fh or die "Unable to close $from: $!";

    my $linux_runner = Markdown::Runner->new(
        platform     => 'linux',
        find_binary  => sub { return '/usr/bin/soffice' if $_[0] eq 'soffice'; return; },
        run_command  => sub {
            @cmd = @_;
            open my $out, '>', $to or die "Unable to write $to: $!";
            print {$out} "DOCX\n";
            close $out or die "Unable to close $to: $!";
            return 1;
        },
    );

    $linux_runner->_pdf_to_docx( $from, $to );
    is_deeply(
        \@cmd,
        [ '/usr/bin/soffice', '--headless', '--convert-to', 'docx', '--outdir', $tmp, abs_path($from) ],
        'linux pdf to docx uses soffice conversion'
    );
}

{
    my $tmp = tempdir( CLEANUP => 1 );
    my $from = File::Spec->catfile( $tmp, 'report.docx' );
    my $to   = File::Spec->catfile( $tmp, 'report.pdf' );
    my @call;
    open my $fh, '>', $from or die "Unable to write $from: $!";
    print {$fh} "fake docx\n";
    close $fh or die "Unable to close $from: $!";

    my $windows_runner = Markdown::Runner->new(
        platform       => 'MSWin32',
        find_binary    => sub { return 'powershell.exe' if $_[0] eq 'powershell.exe'; return; },
        run_powershell => sub {
            @call = @_;
            open my $out, '>', $to or die "Unable to write $to: $!";
            print {$out} "PDF\n";
            close $out or die "Unable to close $to: $!";
            return 1;
        },
    );

    $windows_runner->_docx_to_pdf( $from, $to );
    is( $call[0], 'powershell.exe', 'windows docx to pdf uses powershell automation' );
    like( $call[1], qr/SaveAs2/, 'windows docx to pdf powershell script automates Word save-as' );
}

{
    my $tmp = tempdir( CLEANUP => 1 );
    my $from = File::Spec->catfile( $tmp, 'report.docx' );
    my $to   = File::Spec->catfile( $tmp, 'report.pdf' );
    my @cmd;
    open my $fh, '>', $from or die "Unable to write $from: $!";
    print {$fh} "fake docx\n";
    close $fh or die "Unable to close $from: $!";

    my $windows_runner = Markdown::Runner->new(
        platform    => 'MSWin32',
        find_binary => sub { return 'C:\\LibreOffice\\soffice.exe' if $_[0] =~ /LibreOffice/; return; },
    );
    local *Markdown::Runner::_windows_word_available = sub { return 0 };
    local *Markdown::Runner::_libreoffice_convert = sub { @cmd = @_; return 1 };

    $windows_runner->_default_docx_to_pdf( $from, $to );
    is_deeply(
        \@cmd,
        [ $windows_runner, $from, $to, 'pdf' ],
        'windows docx to pdf falls back to LibreOffice when Word is unavailable'
    );
}

{
    my $tmp = tempdir( CLEANUP => 1 );
    my $from = File::Spec->catfile( $tmp, 'report.docx' );
    open my $fh, '>', $from or die "Unable to write $from: $!";
    print {$fh} "fake docx\n";
    close $fh or die "Unable to close $from: $!";

    my $windows_runner = Markdown::Runner->new(
        platform    => 'MSWin32',
        find_binary => sub { return; },
    );
    local *Markdown::Runner::_windows_word_available = sub { return 0 };
    my $error = eval { $windows_runner->_default_docx_to_pdf( $from, File::Spec->catfile( $tmp, 'report.pdf' ) ); 1 };
    ok( !$error, 'windows docx to pdf fails clearly when neither Word nor LibreOffice is available' );
    like( $@, qr/^DOCX to PDF on Windows requires Microsoft Word or LibreOffice/, 'windows docx to pdf missing-backend error is explicit' );
}

{
    my $tmp = tempdir( CLEANUP => 1 );
    my $from = File::Spec->catfile( $tmp, 'report.docx' );
    my $to   = File::Spec->catfile( $tmp, 'report.pdf' );
    my @call;
    open my $fh, '>', $from or die "Unable to write $from: $!";
    print {$fh} "fake docx\n";
    close $fh or die "Unable to close $from: $!";

    my $mac_runner = Markdown::Runner->new(
        platform      => 'darwin',
        run_osascript => sub {
            @call = @_;
            open my $out, '>', $to or die "Unable to write $to: $!";
            print {$out} "PDF\n";
            close $out or die "Unable to close $to: $!";
            return 1;
        },
    );
    local *Markdown::Runner::_macos_word_available = sub { return 1 };

    $mac_runner->_docx_to_pdf( $from, $to );
    like( $call[0], qr/tell application id "com\.microsoft\.Word"/, 'mac docx to pdf uses Word AppleScript' );
    is( $call[1], $from, 'mac docx to pdf passes the input file path to osascript' );
    is( $call[2], $to, 'mac docx to pdf passes the output file path to osascript' );
}

{
    my $tmp = tempdir( CLEANUP => 1 );
    my $from = File::Spec->catfile( $tmp, 'report.docx' );
    my $to   = File::Spec->catfile( $tmp, 'report.pdf' );
    my @cmd;
    open my $fh, '>', $from or die "Unable to write $from: $!";
    print {$fh} "fake docx\n";
    close $fh or die "Unable to close $from: $!";

    my $mac_runner = Markdown::Runner->new(
        platform    => 'darwin',
        find_binary => sub { return '/Applications/LibreOffice.app/Contents/MacOS/soffice' if $_[0] =~ /soffice$/; return; },
    );
    local *Markdown::Runner::_macos_word_available = sub { return 0 };
    local *Markdown::Runner::_libreoffice_convert = sub { @cmd = @_; return 1 };

    $mac_runner->_default_docx_to_pdf( $from, $to );
    is_deeply(
        \@cmd,
        [ $mac_runner, $from, $to, 'pdf' ],
        'mac docx to pdf falls back to LibreOffice when Word is unavailable'
    );
}

{
    my $tmp = tempdir( CLEANUP => 1 );
    my $from = File::Spec->catfile( $tmp, 'report.docx' );
    open my $fh, '>', $from or die "Unable to write $from: $!";
    print {$fh} "fake docx\n";
    close $fh or die "Unable to close $from: $!";

    my $mac_runner = Markdown::Runner->new(
        platform    => 'darwin',
        find_binary => sub { return; },
    );
    local *Markdown::Runner::_macos_word_available = sub { return 0 };
    my $error = eval { $mac_runner->_default_docx_to_pdf( $from, File::Spec->catfile( $tmp, 'report.pdf' ) ); 1 };
    ok( !$error, 'mac docx to pdf fails clearly when neither Word nor LibreOffice is available' );
    like( $@, qr/^DOCX to PDF on macOS requires Microsoft Word or LibreOffice/, 'mac docx to pdf missing-backend error is explicit' );
}

{
    my $tmp = tempdir( CLEANUP => 1 );
    my $from = File::Spec->catfile( $tmp, 'report.docx' );
    open my $fh, '>', $from or die "Unable to write $from: $!";
    print {$fh} "fake docx\n";
    close $fh or die "Unable to close $from: $!";

    my $error = eval { Markdown::Runner->new( platform => 'linux', find_binary => sub { return; } )->_docx_to_pdf( $from, File::Spec->catfile( $tmp, 'report.pdf' ) ); 1 };
    ok( !$error, 'linux docx to pdf fails clearly when soffice is missing' );
    like( $@, qr/^DOCX to PDF on Linux requires LibreOffice or soffice/, 'linux docx to pdf missing-backend error is explicit' );
}

{
    my $tmp = tempdir( CLEANUP => 1 );
    my $from = File::Spec->catfile( $tmp, 'scan.pdf' );
    open my $fh, '>', $from or die "Unable to write $from: $!";
    print {$fh} "%PDF fake\n";
    close $fh or die "Unable to close $from: $!";

    my $error = eval { Markdown::Runner->new( platform => 'darwin', find_binary => sub { return; } )->_pdf_to_docx( $from, File::Spec->catfile( $tmp, 'scan.docx' ) ); 1 };
    ok( !$error, 'mac pdf to docx fails clearly when LibreOffice is missing' );
    like( $@, qr/^PDF to DOCX on macOS requires LibreOffice/, 'mac pdf to docx missing-backend error is explicit' );
}

{
    my $tmp = tempdir( CLEANUP => 1 );
    my $from = File::Spec->catfile( $tmp, 'scan.pdf' );
    my $to   = File::Spec->catfile( $tmp, 'scan.docx' );
    my @cmd;
    open my $fh, '>', $from or die "Unable to write $from: $!";
    print {$fh} "%PDF fake\n";
    close $fh or die "Unable to close $from: $!";

    my $windows_runner = Markdown::Runner->new(
        platform    => 'MSWin32',
        find_binary => sub { return 'C:\\LibreOffice\\soffice.exe' if $_[0] =~ /LibreOffice/; return; },
    );
    local *Markdown::Runner::_windows_word_available = sub { return 0 };
    local *Markdown::Runner::_libreoffice_convert = sub { @cmd = @_; return 1 };

    $windows_runner->_default_pdf_to_docx( $from, $to );
    is_deeply(
        \@cmd,
        [ $windows_runner, $from, $to, 'docx' ],
        'windows pdf to docx falls back to LibreOffice when Word is unavailable'
    );
}

{
    my $tmp = tempdir( CLEANUP => 1 );
    my $from = File::Spec->catfile( $tmp, 'scan.pdf' );
    open my $fh, '>', $from or die "Unable to write $from: $!";
    print {$fh} "%PDF fake\n";
    close $fh or die "Unable to close $from: $!";

    my $windows_runner = Markdown::Runner->new(
        platform    => 'MSWin32',
        find_binary => sub { return; },
    );
    local *Markdown::Runner::_windows_word_available = sub { return 0 };
    my $error = eval { $windows_runner->_default_pdf_to_docx( $from, File::Spec->catfile( $tmp, 'scan.docx' ) ); 1 };
    ok( !$error, 'windows pdf to docx fails clearly when neither Word nor LibreOffice is available' );
    like( $@, qr/^PDF to DOCX on Windows requires Microsoft Word or LibreOffice/, 'windows pdf to docx missing-backend error is explicit' );
}

{
    my $tmp = tempdir( CLEANUP => 1 );
    my $from = File::Spec->catfile( $tmp, 'scan.pdf' );
    open my $fh, '>', $from or die "Unable to write $from: $!";
    print {$fh} "%PDF fake\n";
    close $fh or die "Unable to close $from: $!";

    my $error = eval { Markdown::Runner->new( platform => 'linux', find_binary => sub { return; } )->_default_pdf_to_docx( $from, File::Spec->catfile( $tmp, 'scan.docx' ) ); 1 };
    ok( !$error, 'linux pdf to docx fails clearly when LibreOffice is missing' );
    like( $@, qr/^PDF to DOCX on Linux requires LibreOffice or soffice/, 'linux pdf to docx missing-backend error is explicit' );
}

{
    my $tmp = tempdir( CLEANUP => 1 );
    my $tool = File::Spec->catfile( $tmp, 'fake-tool' );
    open my $fh, '>', $tool or die "Unable to write $tool: $!";
    print {$fh} "#!/bin/sh\nexit 0\n";
    close $fh or die "Unable to close $tool: $!";
    chmod 0755, $tool or die "Unable to chmod $tool: $!";

    my $found_absolute = Markdown::Runner::_find_binary($tool);
    is( $found_absolute, $tool, 'find_binary returns an executable absolute path directly' );

    local $ENV{PATH} = $tmp;
    my $found_from_path = Markdown::Runner::_find_binary('fake-tool');
    is( $found_from_path, $tool, 'find_binary resolves executables from PATH' );
}

{
    my $tmp = tempdir( CLEANUP => 1 );
    my $cwd = File::Spec->catdir( $tmp, 'cwd' );
    my $bin = File::Spec->catdir( $cwd, 'bin' );
    my $tool = File::Spec->catfile( $bin, 'fake-tool' );
    require File::Path;
    File::Path::make_path($bin);
    open my $fh, '>', $tool or die "Unable to write $tool: $!";
    print {$fh} "#!/bin/sh\nexit 0\n";
    close $fh or die "Unable to close $tool: $!";
    chmod 0755, $tool or die "Unable to chmod $tool: $!";

    my $original = Cwd::getcwd();
    chdir $cwd or die "Unable to chdir to $cwd: $!";
    my $found_relative = Markdown::Runner::_find_binary( File::Spec->catfile( 'bin', 'fake-tool' ) );
    chdir $original or die "Unable to restore cwd to $original: $!";

    is( $found_relative, File::Spec->catfile( 'bin', 'fake-tool' ), 'find_binary returns an executable relative path containing a slash directly' );
}

{
    my $missing = Markdown::Runner::_find_binary('definitely-missing-tool-no-hit');
    ok( !defined $missing, 'find_binary returns undef when no executable candidate is found' );
}

{
    my $tmp = tempdir( CLEANUP => 1 );
    my $home = File::Spec->catdir( $tmp, 'home' );
    my $word_app = File::Spec->catdir( $home, 'Applications', 'Microsoft Word.app' );
    require File::Path;
    File::Path::make_path($word_app);
    local $ENV{HOME} = $home;
    ok( Markdown::Runner->new( platform => 'darwin' )->_macos_word_available, 'macOS Word availability is detected from ~/Applications' );
}

{
    my $tmp = tempdir( CLEANUP => 1 );
    my $home = File::Spec->catdir( $tmp, 'home' );
    require File::Path;
    File::Path::make_path($home);
    local $ENV{HOME} = $home;
    ok( !Markdown::Runner->new( platform => 'darwin' )->_macos_word_available, 'macOS Word availability returns false when no supported app bundle exists' );
}

{
    my $tmp = tempdir( CLEANUP => 1 );
    my $missing_dir = File::Spec->catdir( $tmp, 'missing' );
    my $target = File::Spec->catfile( $missing_dir, 'report.pdf' );
    my $error = eval { Markdown::Runner->new()->_ensure_output_dir($target); 1 };
    ok( !$error, 'ensure_output_dir rejects a missing parent directory' );
    like( $@, qr/^\QOutput directory does not exist: $missing_dir\E/, 'ensure_output_dir reports the missing parent directory clearly' );
}

{
    my $ok = eval { Markdown::Runner::_run_command('/bin/true'); 1 };
    ok( $ok, 'run_command succeeds when the subprocess exits zero' );
}

{
    my $ok = eval { Markdown::Runner::_run_powershell( '/bin/true', 'ignored', 'a', 'b' ); 1 };
    ok( $ok, 'run_powershell succeeds when the subprocess exits zero' );
}

{
    my $tmp = tempdir( CLEANUP => 1 );
    my $fake = File::Spec->catfile( $tmp, 'osascript' );
    open my $fh, '>', $fake or die "Unable to write $fake: $!";
    print {$fh} "#!/bin/sh\ncat >/dev/null\nexit 0\n";
    close $fh or die "Unable to close $fake: $!";
    chmod 0755, $fake or die "Unable to chmod $fake: $!";
    local $ENV{PATH} = join ':', $tmp, ( $ENV{PATH} || '' );

    my $ok = eval { Markdown::Runner::_run_osascript( "on run argv\nreturn\nend run\n", 'a', 'b' ); 1 };
    ok( $ok, 'run_osascript succeeds when the osascript subprocess exits zero' );
}

{
    my $tmp = tempdir( CLEANUP => 1 );
    my $from = File::Spec->catfile( $tmp, 'scan.pdf' );
    my $to   = File::Spec->catfile( $tmp, 'scan.docx' );
    my @call;
    open my $fh, '>', $from or die "Unable to write $from: $!";
    print {$fh} "%PDF fake\n";
    close $fh or die "Unable to close $from: $!";

    my $mac_runner = Markdown::Runner->new(
        platform      => 'darwin',
        run_osascript => sub {
            @call = @_;
            open my $out, '>', $to or die "Unable to write $to: $!";
            print {$out} "DOCX\n";
            close $out or die "Unable to close $to: $!";
            return 1;
        },
    );

    $mac_runner->_word_macos_convert( $from, $to, 'docx' );
    like( $call[0], qr/format document default/, 'mac pdf to docx Word AppleScript uses the docx save format' );
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

    my $error = eval { $runner->convert( from => $from, to => File::Spec->catfile( $tmp, 'note.pdf' ), landscape => 1, portrait => 1 ); 1 };
    ok( !$error, 'conflicting pdf orientation flags are rejected' );
    like( $@, qr/^Choose only one of --landscape or --portrait/, 'orientation conflict is reported clearly' );
}

{
    my $tmp = tempdir( CLEANUP => 1 );
    my $from = File::Spec->catfile( $tmp, 'note.md' );
    open my $fh, '>', $from or die "Unable to write $from: $!";
    print {$fh} "# hello\n";
    close $fh or die "Unable to close $from: $!";

    my $error = eval { $runner->convert( from => $from, to => File::Spec->catfile( $tmp, 'note.pdf' ), paper => 'A11' ); 1 };
    ok( !$error, 'unsupported paper sizes are rejected' );
    like( $@, qr/^Unsupported paper size: A11/, 'unsupported paper size is reported clearly' );
}

{
    my $tmp = tempdir( CLEANUP => 1 );
    my $from = File::Spec->catfile( $tmp, 'note.md' );
    open my $fh, '>', $from or die "Unable to write $from: $!";
    print {$fh} "# hello\n";
    close $fh or die "Unable to close $from: $!";

    my $error = eval { $runner->convert( from => $from, to => File::Spec->catfile( $tmp, 'note.html' ), paper => 'A3' ); 1 };
    ok( !$error, 'paper flags are rejected on non-pdf output routes' );
    like( $@, qr/^PDF layout flags are only valid for PDF output/, 'paper flag rejection is explicit on non-pdf output' );
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
    my $from = File::Spec->catfile( $tmp, 'note.md' );
    open my $fh, '>', $from or die "Unable to write $from: $!";
    print {$fh} "# hello\n";
    close $fh or die "Unable to close $from: $!";

    my $result = $runner->convert( from => $from, to => File::Spec->catfile( $tmp, 'note.docx' ) );
    is( $result->{target_format}, 'docx', 'markdown can target docx explicitly' );
    is( $result->{to}, File::Spec->catfile( $tmp, 'note.docx' ), 'markdown keeps the explicit docx output path' );
}

{
    my $tmp = tempdir( CLEANUP => 1 );
    my $from = File::Spec->catfile( $tmp, 'report.docx' );
    open my $fh, '>', $from or die "Unable to write $from: $!";
    print {$fh} "fake docx\n";
    close $fh or die "Unable to close $from: $!";

    my @steps;
    my $chain_runner = Markdown::Runner->new(
        markdown_to_html => sub { return "<html><body>ignored</body></html>\n" },
        markdown_to_pdf  => sub { die "markdown to pdf should not be used here\n" },
        html_to_markdown => sub { die "html to markdown should not be used here\n" },
        pdf_to_markdown  => sub {
            my ($pdf_path) = @_;
            push @steps, [ pdf_to_markdown => $pdf_path ];
            return "# recovered\n";
        },
        docx_to_pdf      => sub {
            my ( $in, $pdf_path ) = @_;
            push @steps, [ docx_to_pdf => $pdf_path ];
            open my $pdf, '>', $pdf_path or die "Unable to write $pdf_path: $!";
            print {$pdf} "PDF from DOCX\n";
            close $pdf or die "Unable to close $pdf_path: $!";
            return 1;
        },
    );

    my $result = $chain_runner->convert( from => $from );
    is( $result->{target_format}, 'markdown', 'docx chaining route reports markdown output' );
    is_deeply(
        [ map { $_->[0] } @steps ],
        [ 'docx_to_pdf', 'pdf_to_markdown' ],
        'docx to markdown chains through docx to pdf and pdf to markdown'
    );
    my $markdown = $chain_runner->_read_text( $result->{to} );
    is( $markdown, "# recovered\n", 'docx to markdown writes the recovered markdown output' );
}

{
    my $tmp = tempdir( CLEANUP => 1 );
    my $from = File::Spec->catfile( $tmp, 'note.md' );
    open my $fh, '>', $from or die "Unable to write $from: $!";
    print {$fh} "# hello\n";
    close $fh or die "Unable to close $from: $!";

    my @steps;
    my $chain_runner = Markdown::Runner->new(
        markdown_to_html => sub { return "<html><body>ignored</body></html>\n" },
        markdown_to_pdf  => sub {
            my ( $markdown, $pdf_path ) = @_;
            push @steps, [ markdown_to_pdf => $pdf_path, $markdown ];
            open my $pdf, '>', $pdf_path or die "Unable to write $pdf_path: $!";
            print {$pdf} "PDF from markdown\n";
            close $pdf or die "Unable to close $pdf_path: $!";
            return 1;
        },
        html_to_markdown => sub { die "html to markdown should not be used here\n" },
        pdf_to_markdown  => sub { die "pdf to markdown should not be used here\n" },
        pdf_to_docx      => sub {
            my ( $pdf_path, $docx_path ) = @_;
            push @steps, [ pdf_to_docx => $pdf_path, $docx_path ];
            open my $docx, '>', $docx_path or die "Unable to write $docx_path: $!";
            print {$docx} "DOCX from PDF\n";
            close $docx or die "Unable to close $docx_path: $!";
            return 1;
        },
    );

    my $result = $chain_runner->convert( from => $from, to => File::Spec->catfile( $tmp, 'note.docx' ) );
    is( $result->{target_format}, 'docx', 'markdown chaining route reports docx output' );
    is_deeply(
        [ map { $_->[0] } @steps ],
        [ 'markdown_to_pdf', 'pdf_to_docx' ],
        'markdown to docx chains through markdown to pdf and pdf to docx'
    );
    ok( -f $result->{to}, 'markdown to docx writes the chained docx output' );
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
    my @logs;
    my $tmp = tempdir( CLEANUP => 1 );
    my $from = File::Spec->catfile( $tmp, 'note.md' );
    open my $fh, '>', $from or die "Unable to write $from: $!";
    print {$fh} "# hello\n";
    close $fh or die "Unable to close $from: $!";

    my $logging_runner = Markdown::Runner->new(
        markdown_to_html => sub { return "<html><body>$_[0]</body></html>\n" },
        markdown_to_pdf  => sub { return 1 },
        html_to_markdown => sub { return $_[0] },
        pdf_to_markdown  => sub { return "Recovered\n" },
        logger           => sub { push @logs, $_[0] },
    );

    $logging_runner->convert( from => $from, to_pdf => 1 );
    ok( scalar grep { $_ eq "source=$from" } @logs, 'runner logs the source path' );
    ok( scalar grep { $_ eq 'target_format=pdf' } @logs, 'runner logs the target format' );
    ok( scalar grep { $_ eq 'step=markdown_to_pdf.perl' } @logs, 'runner logs the pure perl pdf step' );
}

{
    my $tmp = tempdir( CLEANUP => 1 );
    my $from = File::Spec->catfile( $tmp, 'note.md' );
    my $to   = File::Spec->catfile( $tmp, 'note.html' );
    open my $fh, '>', $from or die "Unable to write $from: $!";
    print {$fh} "# hello\n";
    close $fh or die "Unable to close $from: $!";

    no warnings 'redefine';
    no warnings 'once';
    local $INC{'Markdown/Perl.pm'} = __FILE__;
    local *Markdown::Perl::new = sub { return bless {}, 'Markdown::Perl' };
    local *Markdown::Perl::convert = sub { return "<html><body>stub html</body></html>\n" };

    my $default_runner = Markdown::Runner->new;
    $default_runner->_markdown_to_html( $from, $to );
    open my $out, '<', $to or die "Unable to read $to: $!";
    my $html = do { local $/; <$out> };
    close $out or die "Unable to close $to: $!";
    like( $html, qr/stub html/, 'default markdown to html path uses Markdown::Perl' );
}

{
    my $tmp = tempdir( CLEANUP => 1 );
    my $from = File::Spec->catfile( $tmp, 'table.md' );
    my $to   = File::Spec->catfile( $tmp, 'table.html' );
    open my $fh, '>', $from or die "Unable to write $from: $!";
    print {$fh} <<'MARKDOWN';
| Name | Value |
| --- | --- |
| `alpha` | beta |
MARKDOWN
    close $fh or die "Unable to close $from: $!";

    no warnings 'redefine';
    no warnings 'once';
    local $INC{'Markdown/Perl.pm'} = __FILE__;
    local *Markdown::Perl::new = sub { return bless {}, 'Markdown::Perl' };
    local *Markdown::Perl::convert = sub { return $_[1] };

    my $default_runner = Markdown::Runner->new;
    $default_runner->_markdown_to_html( $from, $to );
    open my $out, '<', $to or die "Unable to read $to: $!";
    my $html = do { local $/; <$out> };
    close $out or die "Unable to close $to: $!";
    like( $html, qr/<table\b[^>]*border="1"[^>]*>/, 'default markdown to html renders markdown tables as html tables with border=1' );
    unlike( $html, qr/\|\s*Name\s*\|/, 'default markdown to html does not leave raw pipe-table syntax behind' );
    like( $html, qr/<code>alpha<\/code>/, 'default markdown to html renders inline code without backticks' );
}

{
    my $tmp = tempdir( CLEANUP => 1 );
    my $from = File::Spec->catfile( $tmp, 'page.html' );
    my $to   = File::Spec->catfile( $tmp, 'page.md' );
    open my $fh, '>', $from or die "Unable to write $from: $!";
    print {$fh} "<h1>hello</h1>\n";
    close $fh or die "Unable to close $from: $!";

    no warnings 'redefine';
    no warnings 'once';
    local $INC{'HTML/WikiConverter.pm'} = __FILE__;
    local *HTML::WikiConverter::new = sub { return bless {}, 'HTML::WikiConverter' };
    local *HTML::WikiConverter::html2wiki = sub { return "# stub markdown\n" };

    my $default_runner = Markdown::Runner->new;
    $default_runner->_html_to_markdown( $from, $to );
    open my $out, '<', $to or die "Unable to read $to: $!";
    my $markdown = do { local $/; <$out> };
    close $out or die "Unable to close $to: $!";
    like( $markdown, qr/stub markdown/, 'default html to markdown path uses HTML::WikiConverter' );
}

{
    my $tmp = tempdir( CLEANUP => 1 );
    my $to = File::Spec->catfile( $tmp, 'note.pdf' );
    my @page_calls;
    my @drawn_text;

    no warnings 'redefine';
    no warnings 'once';
    my $pdf_obj = bless {}, 'PDF::API2';
    my $page_obj = bless {}, 'PDF::API2::Page';
    my $text_obj = bless {}, 'PDF::API2::Content';
    my $gfx_obj = bless {}, 'PDF::API2::Content';
    my $font_obj = bless {}, 'PDF::API2::Resource::Font::CoreFont';
    my @drawn_rects;

    local $INC{'PDF/API2.pm'} = __FILE__;
    local *PDF::API2::new      = sub { return $pdf_obj };
    local *PDF::API2::page     = sub { push @page_calls, 1; return $page_obj };
    local *PDF::API2::corefont = sub { return $font_obj };
    local *PDF::API2::saveas   = sub {
        my ( $self, $path ) = @_;
        open my $pdf, '>', $path or die "Unable to write $path: $!";
        print {$pdf} "pdf";
        close $pdf or die "Unable to close $path: $!";
        return 1;
    };
    local *PDF::API2::Page::mediabox = sub { return 1 };
    local *PDF::API2::Page::text     = sub { return $text_obj };
    local *PDF::API2::Page::gfx      = sub { return $gfx_obj };
    local *PDF::API2::Content::font      = sub { return 1 };
    local *PDF::API2::Content::translate = sub { return 1 };
    local *PDF::API2::Content::text      = sub { push @drawn_text, $_[1]; return 1 };
    local *PDF::API2::Content::rect      = sub { push @drawn_rects, [ @_[ 1 .. 4 ] ]; return 1 };
    local *PDF::API2::Content::stroke    = sub { return 1 };
    local *PDF::API2::Resource::Font::CoreFont::width = sub { return length( $_[1] || '' ) * 500 };

    my $markdown = join "\n",
      '# Main Heading',
      '## Sub Heading',
      '### Minor Heading',
      '- bullet item',
      '| Production class | Planned test file | Status | Current line coverage |',
      '| --- | --- | --- | --- |',
      '| `AdditionalAllocationEmailServiceImpl.java` | `AdditionalAllocationEmailServiceImplTest.java` | present and contributing | `15.6%` (`24/151`) |',
      '| `AssignmentHelperDTO.java` | `AssignmentHelperDTOTest.java` | present and contributing | `100%` (`48/48`) |',
      ('word ' x 120),
      ( map { "body line $_" } 1 .. 220 );

    my $default_runner = Markdown::Runner->new;
    ok( $default_runner->{markdown_to_pdf}->( $markdown, $to ), 'default markdown to pdf path uses PDF::API2' );
    ok( -f $to, 'default markdown to pdf path writes the target file' );
    ok( scalar(@page_calls) > 1, 'default markdown to pdf path can start a new page when the content is long enough' );
    ok( scalar @drawn_rects >= 12, 'default markdown to pdf draws table cell rectangles for the markdown table' );
    ok(
        scalar( grep { defined $_ && $_ !~ /`/ } @drawn_text )
          && scalar( grep { defined $_ && $_ =~ /ServiceImpl\.java/ } @drawn_text ),
        'default markdown to pdf strips inline-code backticks before drawing table text'
    );
    ok( scalar grep { defined $_ && $_ =~ /Production class/ } @drawn_text, 'default markdown to pdf renders the table header text' );
    ok( scalar grep { defined $_ && $_ =~ /Current line/ } @drawn_text, 'default markdown to pdf renders wrapped table header text' );
    ok( !scalar grep { defined $_ && /\|/ } @drawn_text, 'default markdown to pdf does not draw raw pipe-table characters' );
}

{
    my $tmp = tempdir( CLEANUP => 1 );
    my $to = File::Spec->catfile( $tmp, 'layout.pdf' );
    my @mediabox_args;

    no warnings 'redefine';
    no warnings 'once';
    my $pdf_obj = bless {}, 'PDF::API2';
    my $page_obj = bless {}, 'PDF::API2::Page';
    my $text_obj = bless {}, 'PDF::API2::Content';
    my $gfx_obj = bless {}, 'PDF::API2::Content';
    my $font_obj = bless {}, 'PDF::API2::Resource::Font::CoreFont';

    local $INC{'PDF/API2.pm'} = __FILE__;
    local *PDF::API2::new      = sub { return $pdf_obj };
    local *PDF::API2::page     = sub { return $page_obj };
    local *PDF::API2::corefont = sub { return $font_obj };
    local *PDF::API2::saveas   = sub {
        my ( $self, $path ) = @_;
        open my $pdf, '>', $path or die "Unable to write $path: $!";
        print {$pdf} "pdf";
        close $pdf or die "Unable to close $path: $!";
        return 1;
    };
    local *PDF::API2::Page::mediabox = sub { @mediabox_args = @_[ 1 .. $#_ ]; return 1 };
    local *PDF::API2::Page::text     = sub { return $text_obj };
    local *PDF::API2::Page::gfx      = sub { return $gfx_obj };
    local *PDF::API2::Content::font      = sub { return 1 };
    local *PDF::API2::Content::translate = sub { return 1 };
    local *PDF::API2::Content::text      = sub { return 1 };
    local *PDF::API2::Content::rect      = sub { return 1 };
    local *PDF::API2::Content::stroke    = sub { return 1 };
    local *PDF::API2::Resource::Font::CoreFont::width = sub { return length( $_[1] || '' ) * 500 };

    my $default_runner = Markdown::Runner->new;
    ok(
        $default_runner->{markdown_to_pdf}->(
            "# hello\n",
            $to,
            { paper => 'A3', orientation => 'landscape' }
        ),
        'default markdown to pdf path accepts explicit layout settings'
    );
    is_deeply( \@mediabox_args, [ 0, 0, 1191, 842 ], 'default markdown to pdf path sets the expected A3 landscape media box' );
}

{
    no warnings 'redefine';
    no warnings 'once';
    local *PDF::API2::Resource::Font::CoreFont::width = sub { return length( $_[1] || '' ) * 500 };
    my @segments = Markdown::Runner::_wrap_text(
        bless( {}, 'PDF::API2::Resource::Font::CoreFont' ),
        11,
        'src/test/java/com/example/really/long/path/ManualPaymentNoteHelperTest.java',
        60,
    );
    ok( scalar(@segments) > 1, 'wrap_text splits a long path-like token into multiple segments' );

    is_deeply(
        [ Markdown::Runner::_token_fragments('.json') ],
        ['.json'],
        'token_fragments handles a generic dot-prefixed fragment'
    );
    is_deeply(
        [ Markdown::Runner::_token_fragments('100%') ],
        ['100%'],
        'token_fragments handles numeric fragments'
    );
    is_deeply(
        [ Markdown::Runner::_token_fragments('__') ],
        ['__'],
        'token_fragments handles punctuation fragments'
    );
    is_deeply(
        [ Markdown::Runner::_token_fragments('@') ],
        ['@'],
        'token_fragments falls back to single-character fragments'
    );
    ok(
        !defined Markdown::Runner::_rebalance_extension_fragment(
            bless( {}, 'PDF::API2::Resource::Font::CoreFont' ),
            11,
            'AlphaBeta',
            '.json',
            4,
        ),
        'rebalance_extension_fragment returns undef when no readable rebalance fits'
    );
}

is_deeply( [ Markdown::Runner::_paper_dimensions('A0') ], [ 2384, 3370 ], 'A0 paper dimensions are supported' );
is_deeply( [ Markdown::Runner::_paper_dimensions('A10') ], [ 74, 105 ], 'A10 paper dimensions are supported' );
is_deeply( [ Markdown::Runner::_paper_dimensions('B0') ], [ 2835, 4008 ], 'B0 paper dimensions are supported' );
is_deeply( [ Markdown::Runner::_paper_dimensions('B10') ], [ 88, 125 ], 'B10 paper dimensions are supported' );
is_deeply( [ Markdown::Runner::_paper_dimensions('C0') ], [ 2599, 3677 ], 'C0 paper dimensions are supported' );
is_deeply( [ Markdown::Runner::_paper_dimensions('C7') ], [ 230, 323 ], 'C7 paper dimensions are supported' );
is_deeply( [ Markdown::Runner::_paper_dimensions('DL') ], [ 312, 624 ], 'DL paper dimensions are supported' );
is_deeply( [ Markdown::Runner::_paper_dimensions('ANSI-A') ], [ 612, 792 ], 'ANSI-A paper dimensions are supported' );
is_deeply( [ Markdown::Runner::_paper_dimensions('ANSI-E') ], [ 2448, 3168 ], 'ANSI-E paper dimensions are supported' );

for my $paper ( map( { "A$_" } 0 .. 10 ), map( { "B$_" } 0 .. 10 ), map( { "C$_" } 0 .. 7 ), 'DL', map( { "ANSI-$_" } qw(A B C D E) ) ) {
    my $ok = eval { Markdown::Runner::_validate_pdf_layout( paper => $paper ); 1 };
    ok( $ok, "$paper is accepted as a supported paper size" ) or diag $@;
}

{
    my $tmp = tempdir( CLEANUP => 1 );
    my $to = File::Spec->catfile( $tmp, 'overlap.pdf' );
    my @drawn_text;
    my @drawn_rects;

    no warnings 'redefine';
    no warnings 'once';
    my $pdf_obj = bless {}, 'PDF::API2';
    my $page_obj = bless {}, 'PDF::API2::Page';
    my $text_obj = bless {}, 'PDF::API2::Content';
    my $gfx_obj = bless {}, 'PDF::API2::Content';
    my $font_obj = bless {}, 'PDF::API2::Resource::Font::CoreFont';

    local $INC{'PDF/API2.pm'} = __FILE__;
    local *PDF::API2::new      = sub { return $pdf_obj };
    local *PDF::API2::page     = sub { return $page_obj };
    local *PDF::API2::corefont = sub { return $font_obj };
    local *PDF::API2::saveas   = sub {
        my ( $self, $path ) = @_;
        open my $pdf, '>', $path or die "Unable to write $path: $!";
        print {$pdf} "pdf";
        close $pdf or die "Unable to close $path: $!";
        return 1;
    };
    local *PDF::API2::Page::mediabox = sub { return 1 };
    local *PDF::API2::Page::text     = sub { return $text_obj };
    local *PDF::API2::Page::gfx      = sub { return $gfx_obj };
    local *PDF::API2::Content::font      = sub { return 1 };
    local *PDF::API2::Content::translate = sub { return 1 };
    local *PDF::API2::Content::text      = sub { push @drawn_text, $_[1]; return 1 };
    local *PDF::API2::Content::rect      = sub { push @drawn_rects, [ @_[ 1 .. 4 ] ]; return 1 };
    local *PDF::API2::Content::stroke    = sub { return 1 };
    local *PDF::API2::Resource::Font::CoreFont::width = sub { return length( $_[1] || '' ) * 500 };

    my $markdown = <<'MARKDOWN';
| Order | Target files | Action | Module coverage now |
| --- | --- | --- | --- |
| 1 | src/test/java/com/example/really/long/path/ManualPaymentNoteHelperTest.java | MakeManualPaymentNoteHelperTest.javacovertheregressionpathwithoutoverlap | confirm coverage branch |
MARKDOWN

    my $default_runner = Markdown::Runner->new;
    ok( $default_runner->{markdown_to_pdf}->( $markdown, $to, { paper => 'A4', orientation => 'portrait' } ), 'default markdown to pdf handles long-table-token regression input' );
    ok( scalar(@drawn_rects) >= 8, 'long-table-token regression still draws the table rectangles' );
    ok( scalar grep { defined $_ && $_ =~ /src\/test\/java\/com\// } @drawn_text, 'long path text is still rendered into the table' );
    ok( scalar grep { defined $_ && $_ =~ /HelperTest\.java/ } @drawn_text, 'long path token is wrapped into later cell segments' );
    ok( scalar grep { defined $_ && $_ =~ /MakeManualPayment/ } @drawn_text, 'long action token is rendered into the action cell' );
}

{
    no warnings 'redefine';
    no warnings 'once';
    local $INC{'CAM/PDF.pm'} = __FILE__;
    local *CAM::PDF::new      = sub { return bless {}, 'CAM::PDF' };
    local *CAM::PDF::numPages = sub { return 2 };
    local *CAM::PDF::getPageText = sub {
        my ( $self, $page ) = @_;
        return $page == 1 ? " page one \n\n" : "page two";
    };

    my $default_runner = Markdown::Runner->new;
    my $markdown = $default_runner->{pdf_to_markdown}->('stub.pdf');
    like( $markdown, qr/page one/, 'default pdf to markdown path uses CAM::PDF' );
    like( $markdown, qr/page two/, 'default pdf to markdown path keeps later page text' );
}

{
    my @new_page_calls;
    my @table_text;
    my $pdf_obj = bless {}, 'PDF::API2';
    my $page_obj = bless {}, 'PDF::API2::Page';
    my $text_obj = bless {}, 'PDF::API2::Content';
    my $gfx_obj = bless {}, 'PDF::API2::Content';
    my $font_obj = bless {}, 'PDF::API2::Resource::Font::CoreFont';

    no warnings 'redefine';
    no warnings 'once';
    local *Markdown::Runner::_new_pdf_page = sub {
        push @new_page_calls, 1;
        return ( $page_obj, $text_obj, $gfx_obj, 742 );
    };
    local *PDF::API2::Content::font      = sub { return 1 };
    local *PDF::API2::Content::translate = sub { return 1 };
    local *PDF::API2::Content::text      = sub { push @table_text, $_[1]; return 1 };
    local *PDF::API2::Content::rect      = sub { return 1 };
    local *PDF::API2::Content::stroke    = sub { return 1 };
    local *PDF::API2::Resource::Font::CoreFont::width = sub { return length( $_[1] || '' ) * 500 };

    my ( undef, undef, undef, $y ) = Markdown::Runner::_render_pdf_table(
        pdf          => $pdf_obj,
        page         => $page_obj,
        text         => $text_obj,
        gfx          => $gfx_obj,
        y            => 60,
        rows         => [
            [ 'Production class', 'Status' ],
            [ '`AdditionalAllocationEmailServiceImpl.java`', 'present and contributing' ],
        ],
        x            => 50,
        width        => 495,
        font_regular => $font_obj,
        font_bold    => $font_obj,
    );

    ok( scalar @new_page_calls >= 1, 'pdf table renderer starts a new page when the remaining vertical space is too small' );
    ok( scalar grep { $_ =~ /AdditionalAllocation/ && $_ !~ /`/ } @table_text, 'pdf table renderer strips backticks from cell text on page-break path' );
    ok( $y < 742, 'pdf table renderer consumes space after the new page is allocated' );
}

{
    my @blank = Markdown::Runner::_pdf_lines_for_block( { type => 'blank' } );
    is_deeply( \@blank, [''], 'pdf block renderer keeps blank blocks as empty lines' );
}

{
    my @code = Markdown::Runner::_pdf_lines_for_block( { type => 'code', lines => [ 'my $x = 1;', 'return $x;' ] } );
    is_deeply( \@code, [ 'my $x = 1;', 'return $x;' ], 'pdf block renderer returns code block lines unchanged' );
}

{
    my @unknown = Markdown::Runner::_pdf_lines_for_block( { type => 'mystery' } );
    is_deeply( \@unknown, [], 'pdf block renderer returns no lines for unknown block types' );
}

done_testing;
