use strict;
use warnings;

use File::Spec;
use File::Temp qw(tempdir);
use Test::More;

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

    my $error = eval { $runner->convert( from => $from, to => File::Spec->catfile( $tmp, 'note.pdf' ), paper => 'A9' ); 1 };
    ok( !$error, 'unsupported paper sizes are rejected' );
    like( $@, qr/^Unsupported paper size: A9/, 'unsupported paper size is reported clearly' );
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
    ok( scalar grep { defined $_ && $_ =~ /ServiceImpl\.java/ && $_ !~ /`/ } @drawn_text, 'default markdown to pdf strips inline-code backticks before drawing table text' );
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
