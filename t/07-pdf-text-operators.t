use strict;
use warnings;

use File::Spec;
use File::Temp qw(tempdir);
use Test::More;

use lib 'lib';

use Markdown::Runner;
use Markdown::Enhancer;

# The Tm-aware page-text renderer mirrors CAM::PDF::PageText's operator
# handling, but the mocked suites only ever drove it through TJ/Tj/Tm/Tf.
# These tests exercise the remaining operators directly through the same
# content-tree shape CAM::PDF produces, and prove the ToUnicode CMap path
# against a real hand-built PDF parsed by the real CAM::PDF, so the decode
# logic is verified against genuine PDF object structure instead of only
# hand-rolled fakes.

sub _op {
    my ( $name, @args ) = @_;
    return { type => 'op', name => $name, args => [@args] };
}

sub _num    { return { type => 'number', value => $_[0] } }
sub _str    { return { type => 'string', value => $_[0] } }
sub _tm     { return _op( 'Tm', map { _num($_) } 1, 0, 0, 1, $_[0], $_[1] ) }
sub _bt     { return { type => 'block', name => 'BT', value => [@_] } }

{
    my $tree = {
        blocks => [
            _bt(
                _tm( 72, 700 ),
                _op( 'TJ', { type => 'array', value => [ _str('one'), _num(-100), _str('kernclose'), _num(-300), _str('kernwide') ] } ),
                _tm( 72, 690 ),
                _op( 'Tj', _str('two') ),
                _tm( 72, 650 ),
                _op( 'Tj', _str('three') ),
            ),
        ],
    };
    my $text = Markdown::Runner::_pdf_render_page_text($tree);
    like( $text, qr/onekernclose kernwide/, 'TJ appends array strings and only breaks on kerning below -250' );
    like( $text, qr/kernwide\ntwo/,         'a small Tm vertical move becomes a single line break' );
    like( $text, qr/two\n\nthree/,          'an unusually large Tm vertical move becomes a paragraph break' );
}

{
    my $tree = {
        blocks => [
            _bt(
                _op( 'Tj',   _str('lead') ),
                _op( 'Td',   _num(0), _num(-20) ),
                _op( 'Tj',   _str('tdline') ),
                _op( 'TD',   _num(100), _num(-1) ),
                _op( 'Tj',   _str('sameline') ),
                _op( 'T*' ),
                _op( 'Tj',   _str('starline') ),
                _op( q{\'},  _str('quoteline') ),
                _op( q{\"},  _num(1), _num(2), _str('dquoteline') ),
            ),
        ],
    };
    my $text = Markdown::Runner::_pdf_render_page_text($tree);
    like( $text, qr/lead\ntdline/,          'Td with a dominant negative vertical move breaks the line' );
    like( $text, qr/tdline sameline/,       'TD with a dominant horizontal move keeps the same line' );
    like( $text, qr/sameline\nstarline/,    'T* breaks the line' );
    like( $text, qr/starline\nquoteline/,   q{' breaks the line and appends its string} );
    like( $text, qr/quoteline\ndquoteline/, q{" breaks the line and appends its trailing string} );
}

{
    my $tree = {
        blocks => [
            _bt(
                _op( 'Tj', _str('guarded') ),
                _op( 'TJ', _str('not-an-array') ),
                _op( 'Td', _num(0) ),
                _op( q{\'} ),
            ),
        ],
    };
    my $text = Markdown::Runner::_pdf_render_page_text($tree);
    like( $text, qr/\Aguarded\n\z/, 'malformed TJ, Td, and quote operators are ignored without corrupting output' );
}

# Build a real single-page PDF by hand: an uncompressed content stream, one
# font whose /ToUnicode CMap uses a surrogate-pair bfchar and an array-form
# bfrange, and a second font whose /ToUnicode points at a missing object.
sub _build_pdf {
    my (@objects) = @_;
    my $pdf = "%PDF-1.4\n";
    my @offsets;
    for my $i ( 1 .. scalar @objects ) {
        push @offsets, length $pdf;
        $pdf .= "$i 0 obj\n$objects[ $i - 1 ]\nendobj\n";
    }
    my $xref_pos = length $pdf;
    my $count    = scalar(@objects) + 1;
    $pdf .= "xref\n0 $count\n";
    $pdf .= "0000000000 65535 f \n";
    $pdf .= sprintf "%010d 00000 n \n", $_ for @offsets;
    $pdf .= "trailer\n<< /Size $count /Root 1 0 R >>\nstartxref\n$xref_pos\n%%EOF\n";
    return $pdf;
}

sub _stream_obj {
    my ($content) = @_;
    return '<< /Length ' . length($content) . " >>\nstream\n$content\nendstream";
}

{
    my $content = <<'CONTENT';
BT
/F1 12 Tf
1 0 0 1 72 700 Tm
<41> Tj
<42> Tj
<50> Tj
(plain) Tj
ET
BT
/F2 12 Tf
(rawbytes) Tj
ET
CONTENT
    chomp $content;

    my $cmap = <<'CMAP';
/CIDInit /ProcSet findresource begin
12 dict begin
begincmap
/CMapName /Test-UCS def
1 begincodespacerange
<00> <FF>
endcodespacerange
2 beginbfchar
<41> <D83DDE00>
<42> <0048>
endbfchar
1 beginbfrange
<50> <52> [<0058> <0059> <005A>]
endbfrange
endcmap
CMAP
    chomp $cmap;

    my $pdf = _build_pdf(
        '<< /Type /Catalog /Pages 2 0 R >>',
        '<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
        '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Contents 4 0 R'
          . ' /Resources << /Font << /F1 5 0 R /F2 7 0 R >> >> >>',
        _stream_obj($content),
        '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /ToUnicode 6 0 R >>',
        _stream_obj($cmap),
        '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /ToUnicode 99 0 R >>',
    );

    my $tmp      = tempdir( CLEANUP => 1 );
    my $pdf_path = File::Spec->catfile( $tmp, 'tounicode.pdf' );
    open my $fh, '>:raw', $pdf_path or die "Unable to write $pdf_path: $!";
    print {$fh} $pdf;
    close $fh or die "Unable to close $pdf_path: $!";

    my $markdown = Markdown::Runner::_default_pdf_to_markdown($pdf_path);

    require Encode;
    my $emoji = Encode::encode( 'UTF-8', chr 0x1F600 );
    like( $markdown, qr/\Q$emoji\E/, 'a surrogate-pair bfchar mapping decodes to the real supplementary-plane character' );
    like( $markdown, qr/H X plain/,  'bfchar and array-form bfrange mappings decode through the active font CMap' );
    like( $markdown, qr/rawbytes/,   'a font whose ToUnicode is unreadable falls back to raw bytes instead of dying' );
}

{
    my $tmp      = tempdir( CLEANUP => 1 );
    my $bad_path = File::Spec->catfile( $tmp, 'not-a.pdf' );
    open my $fh, '>', $bad_path or die "Unable to write $bad_path: $!";
    print {$fh} "this is not a pdf\n";
    close $fh or die "Unable to close $bad_path: $!";

    my $error = eval { Markdown::Runner::_default_pdf_to_markdown($bad_path); 1 } ? '' : $@;
    like( $error, qr/Unable to read PDF/, 'an unreadable PDF dies with a clear error instead of returning empty text' );
}

{
    is(
        Markdown::Runner::_docx_block_xml( { type => 'code', lines => [ 'my $x = 1;', 'print $x;' ] } ),
        Markdown::Runner::_docx_paragraph_xml( 'my $x = 1;', mono => 1 ) . Markdown::Runner::_docx_paragraph_xml( 'print $x;', mono => 1 ),
        'code blocks render each line as a mono paragraph'
    );
    is( Markdown::Runner::_docx_block_xml( { type => 'code', lines => [] } ), '<w:p/>', 'an empty code block renders an empty paragraph' );
    is( Markdown::Runner::_docx_block_xml( { type => 'mystery' } ), '', 'an unknown block type renders nothing' );
}

{
    my $tmp  = tempdir( CLEANUP => 1 );
    my $from = File::Spec->catfile( $tmp, 'report.pdf' );
    my $to   = File::Spec->catfile( $tmp, 'converted.docx' );
    open my $fh, '>', $from or die "Unable to write $from: $!";
    print {$fh} "%PDF-1.4 stub\n";
    close $fh or die "Unable to close $from: $!";

    my $runner = Markdown::Runner->new(
        platform    => 'linux',
        find_binary => sub { return '/usr/bin/soffice' if $_[0] eq 'soffice'; return; },
        run_command => sub {
            my @cmd = @_;
            my $outdir;
            for my $i ( 0 .. $#cmd - 1 ) {
                $outdir = $cmd[ $i + 1 ] if $cmd[$i] eq '--outdir';
            }
            die "run_command did not receive --outdir\n" if !defined $outdir;
            open my $out, '>', File::Spec->catfile( $outdir, 'report.docx' ) or die "Unable to write produced file: $!";
            print {$out} 'DOCX';
            close $out or die "Unable to close produced file: $!";
            return 1;
        },
    );

    ok( $runner->_libreoffice_convert( $from, $to, 'docx' ), 'soffice conversion succeeds when the produced file needs renaming into place' );
    ok( -f $to, 'the soffice output named after the source basename is moved to the requested target path' );
}

done_testing;
