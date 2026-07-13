use strict;
use warnings;

use File::Spec;
use File::Temp qw(tempdir);
use Test::More;

use lib 'lib';

use Markdown::Runner;
use Markdown::Enhancer;

# These tests deliberately use the real PDF::API2 / CAM::PDF / Archive::Zip
# backends instead of mocking them, unlike the rest of the suite. The two
# bugs this file guards against - PDF::API2's Tm-based text layout being
# invisible to CAM::PDF::PageText, and LibreOffice being structurally unable
# to export a PDF-derived document to DOCX - only show up when the real
# libraries actually run; a suite that mocks every conversion boundary can
# report 100% coverage while both bugs sit undetected in production.

{
    my $tmp = tempdir( CLEANUP => 1 );
    my $md_path  = File::Spec->catfile( $tmp, 'source.md' );
    my $pdf_path = File::Spec->catfile( $tmp, 'source.pdf' );
    my $md_out   = File::Spec->catfile( $tmp, 'recovered.md' );

    open my $fh, '>', $md_path or die "Unable to write $md_path: $!";
    print {$fh} <<'MARKDOWN';
# Heading One

First paragraph line.

## Heading Two

- bullet one
- bullet two
MARKDOWN
    close $fh or die "Unable to close $md_path: $!";

    my $runner = Markdown::Runner->new;
    ok( $runner->{markdown_to_pdf}->( $runner->_read_text($md_path), $pdf_path, { paper => 'A4', orientation => 'portrait' } ), 'real markdown to pdf succeeds' );
    ok( -f $pdf_path, 'real markdown to pdf writes a pdf file' );

    my $recovered = $runner->{pdf_to_markdown}->($pdf_path);
    my @lines = grep { length } split /\n/, $recovered;

    ok( scalar(@lines) >= 5, 'real pdf to markdown recovers multiple distinct lines instead of one collapsed blob' )
      or diag("recovered text was: $recovered");
    like( $recovered, qr/Heading One\n+First paragraph line\./, 'heading and following paragraph land on separate lines' );
    like( $recovered, qr/bullet one\n\* bullet two/, 'consecutive bullets stay on separate lines' );
}

{
    my $tmp = tempdir( CLEANUP => 1 );
    my $md_path  = File::Spec->catfile( $tmp, 'source.md' );
    my $pdf_path = File::Spec->catfile( $tmp, 'source.pdf' );
    my $docx_path = File::Spec->catfile( $tmp, 'source.docx' );

    open my $fh, '>', $md_path or die "Unable to write $md_path: $!";
    print {$fh} "# Title\n\nBody text for the docx conversion check.\n";
    close $fh or die "Unable to close $md_path: $!";

    my $runner = Markdown::Runner->new;
    $runner->{markdown_to_pdf}->( $runner->_read_text($md_path), $pdf_path, { paper => 'A4', orientation => 'portrait' } );

    my $result = eval { $runner->convert( from => $pdf_path, to => $docx_path ); 1 };
    ok( $result, 'real pdf to docx succeeds with no Office backend involved' ) or diag $@;
    ok( -f $docx_path, 'real pdf to docx writes a docx file' );

    require Archive::Zip;
    my $zip = Archive::Zip->new;
    is( $zip->read($docx_path), Archive::Zip::AZ_OK(), 'generated docx is a well-formed zip archive' );
    ok( $zip->memberNamed('word/document.xml'), 'generated docx contains word/document.xml' );
    ok( $zip->memberNamed('[Content_Types].xml'), 'generated docx contains [Content_Types].xml' );

    my $document_xml = $zip->contents('word/document.xml');
    like( $document_xml, qr/Title/, 'recovered heading text is present in the docx body' );
    like( $document_xml, qr/Body text for the docx conversion check/, 'recovered paragraph text is present in the docx body' );
}

{
    my $tmp = tempdir( CLEANUP => 1 );
    my $docx_path = File::Spec->catfile( $tmp, 'table.docx' );
    my $markdown = "# Report\n\n| Name | Score |\n| --- | --- |\n| Alice | 92 |\n| Bob | 81 |\n";

    my $ok = eval {
        Markdown::Runner::_default_markdown_to_docx( $markdown, $docx_path, Markdown::Enhancer->new );
        1;
    };
    ok( $ok, 'direct markdown to docx writer succeeds on markdown containing a real table' ) or diag $@;

    require Archive::Zip;
    my $zip = Archive::Zip->new;
    $zip->read($docx_path);
    my $document_xml = $zip->contents('word/document.xml');

    like( $document_xml, qr/<w:tbl>/, 'a table sourced directly from markdown is rendered as a real OOXML table' );
    like( $document_xml, qr/Alice/, 'table cell text is present' );
    like( $document_xml, qr/<w:tc>/, 'table cells are present' );
}

SKIP: {
    my $soffice = Markdown::Runner::_find_binary('soffice') || Markdown::Runner::_find_binary('libreoffice');
    skip 'soffice/libreoffice not found on PATH', 6 if !$soffice;

    # This is the real docx-to-markdown chain end to end: docx -> (real
    # LibreOffice) -> pdf -> (real CAM::PDF) -> markdown. It guards two bugs
    # that only show up against a genuine LibreOffice-rendered PDF, not one
    # this module generates itself: LibreOffice tags its PDF export with
    # BDC/BMC/EMC marked-content spans interleaved with the q/Q graphics
    # stack in a way CAM::PDF's block matcher can't parse (silently
    # returning empty text for the whole page), and LibreOffice embeds a
    # subsetted font whose Tj/TJ bytes are meaningless without resolving the
    # font's ToUnicode CMap (silently returning unreadable control-character
    # noise instead of words).
    my $tmp = tempdir( CLEANUP => 1 );
    my $md_path   = File::Spec->catfile( $tmp, 'source.md' );
    my $docx_path = File::Spec->catfile( $tmp, 'source.docx' );
    my $md_out    = File::Spec->catfile( $tmp, 'recovered.md' );

    open my $fh, '>', $md_path or die "Unable to write $md_path: $!";
    print {$fh} <<'MARKDOWN';
# Quarterly Report

First paragraph discussing real quarterly results.

- alpha item
- beta item
MARKDOWN
    close $fh or die "Unable to close $md_path: $!";

    my $runner = Markdown::Runner->new;
    $runner->convert( from => $md_path, to => $docx_path );
    ok( -f $docx_path, 'real markdown to docx (chained through pdf) writes a docx file' );

    my $result = eval { $runner->convert( from => $docx_path, to => $md_out ); 1 };
    ok( $result, 'real docx to markdown succeeds against a genuine LibreOffice-rendered intermediate pdf' ) or diag $@;
    ok( -f $md_out, 'real docx to markdown writes an output file' );

    my $recovered = $runner->_read_text($md_out);
    ok( length $recovered, 'real docx to markdown output is not silently empty' );
    like( $recovered, qr/Quarterly Report/, 'the heading text survives the real docx -> pdf -> markdown chain, not control-character noise' );
    like( $recovered, qr/alpha item/, 'bullet text survives the real docx -> pdf -> markdown chain' );
}

done_testing;
