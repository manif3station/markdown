package Markdown::Runner;

use strict;
use warnings;

use File::Basename qw(fileparse);
use File::Spec;
use Cwd qw(abs_path);
use File::Temp qw(tempdir);
use File::Copy qw(move);

use Markdown::Enhancer;

sub new {
    my ( $class, %args ) = @_;
    my $enhancer = $args{enhancer} || Markdown::Enhancer->new;
    my $self = bless {
        markdown_to_html => $args{markdown_to_html} || sub { return _default_markdown_to_html( $_[0], $enhancer ); },
        markdown_to_pdf  => $args{markdown_to_pdf}  || sub { return _default_markdown_to_pdf( $_[0], $_[1], $_[2], $enhancer ); },
        html_to_markdown => $args{html_to_markdown} || \&_default_html_to_markdown,
        pdf_to_markdown  => $args{pdf_to_markdown} || \&_default_pdf_to_markdown,
        docx_to_pdf      => $args{docx_to_pdf},
        pdf_to_docx      => $args{pdf_to_docx},
        logger           => $args{logger} || sub { },
        enhancer         => $enhancer,
        platform         => $args{platform} || $^O,
        find_binary      => $args{find_binary} || \&_find_binary,
        run_command      => $args{run_command} || \&_run_command,
        run_osascript    => $args{run_osascript} || \&_run_osascript,
        run_powershell   => $args{run_powershell} || \&_run_powershell,
    }, $class;
    return $self;
}

sub convert {
    my ( $self, %args ) = @_;
    my $from = $args{from} || die "Missing --from\n";
    die "Source file not found: $from\n" if !-f $from;

    my $source_format = $self->_detect_source_format($from);
    my $target_format = $self->_target_format_for(
        source_format => $source_format,
        to            => $args{to},
        to_pdf        => $args{to_pdf},
        to_html       => $args{to_html},
        paper         => $args{paper},
        landscape     => $args{landscape},
        portrait      => $args{portrait},
    );
    my $output_path = $self->_output_path(
        from          => $from,
        to            => $args{to},
        target_format => $target_format,
    );

    $self->_log("source=$from");
    $self->_log("source_format=$source_format");
    $self->_log("target_format=$target_format");
    $self->_log("output=$output_path");
    if ( $target_format eq 'pdf' ) {
        my $layout = $self->_pdf_layout(
            paper     => $args{paper},
            landscape => $args{landscape},
            portrait  => $args{portrait},
        );
        $self->_log( 'paper=' . $layout->{paper} );
        $self->_log( 'orientation=' . $layout->{orientation} );
    }

    if ( $source_format eq 'markdown' && $target_format eq 'html' ) {
        $self->_markdown_to_html( $from, $output_path );
    }
    elsif ( $source_format eq 'markdown' && $target_format eq 'pdf' ) {
        $self->_markdown_to_pdf(
            $from,
            $output_path,
            $self->_pdf_layout(
                paper     => $args{paper},
                landscape => $args{landscape},
                portrait  => $args{portrait},
            )
        );
    }
    elsif ( $source_format eq 'html' && $target_format eq 'markdown' ) {
        $self->_html_to_markdown( $from, $output_path );
    }
    elsif ( $source_format eq 'pdf' && $target_format eq 'markdown' ) {
        $self->_pdf_to_markdown( $from, $output_path );
    }
    elsif ( $source_format eq 'docx' && $target_format eq 'pdf' ) {
        $self->_docx_to_pdf( $from, $output_path );
    }
    elsif ( $source_format eq 'docx' && $target_format eq 'markdown' ) {
        $self->_docx_to_markdown( $from, $output_path );
    }
    elsif ( $source_format eq 'pdf' && $target_format eq 'docx' ) {
        $self->_pdf_to_docx( $from, $output_path );
    }
    elsif ( $source_format eq 'markdown' && $target_format eq 'docx' ) {
        $self->_markdown_to_docx( $from, $output_path );
    }
    else {
        die "Unsupported conversion route: $source_format -> $target_format\n";
    }

    return {
        from          => $from,
        to            => $output_path,
        source_format => $source_format,
        target_format => $target_format,
        ( $target_format eq 'pdf'
            ? (
                paper       => $self->_pdf_layout(
                    paper     => $args{paper},
                    landscape => $args{landscape},
                    portrait  => $args{portrait},
                )->{paper},
                orientation => $self->_pdf_layout(
                    paper     => $args{paper},
                    landscape => $args{landscape},
                    portrait  => $args{portrait},
                )->{orientation},
              )
            : () ),
    };
}

sub _detect_source_format {
    my ( $self, $path ) = @_;
    my ( undef, undef, $suffix ) = fileparse( $path, qr/\.[^.]*/ );
    $suffix = lc( $suffix || '' );
    return 'markdown' if $suffix eq '.md' || $suffix eq '.markdown';
    return 'html'     if $suffix eq '.html' || $suffix eq '.htm';
    return 'pdf'      if $suffix eq '.pdf';
    return 'docx'     if $suffix eq '.docx';
    die "Unsupported source extension: $suffix\n";
}

sub _target_format_for {
    my ( $self, %args ) = @_;
    my $source_format = $args{source_format};
    my $to            = $args{to};
    my $to_pdf        = $args{to_pdf}  ? 1 : 0;
    my $to_html       = $args{to_html} ? 1 : 0;
    my $paper         = $args{paper};
    my $landscape     = $args{landscape} ? 1 : 0;
    my $portrait      = $args{portrait}  ? 1 : 0;

    die "Choose only one of --pdf/--to-pdf or --html/--to-html\n" if $to_pdf && $to_html;
    die "Choose only one of --landscape or --portrait\n" if $landscape && $portrait;

    if ( $source_format eq 'markdown' ) {
        if ( !$to_pdf && !$to_html && defined $to && $to ne '' ) {
            my $ext = lc( ( fileparse( $to, qr/\.[^.]*/ ) )[2] || '' );
            if ( $ext eq '.pdf' ) {
                _validate_pdf_layout( paper => $paper, landscape => $landscape, portrait => $portrait );
            }
        }
        return 'pdf'  if $to_pdf;
        return 'html' if $to_html;
        if ( defined $to && $to ne '' ) {
            my $ext = lc( ( fileparse( $to, qr/\.[^.]*/ ) )[2] || '' );
            _validate_pdf_layout( paper => $paper, landscape => $landscape, portrait => $portrait ) if $ext eq '.pdf';
            die "PDF layout flags are only valid for PDF output\n"
              if ( ( defined $paper && $paper ne '' ) || $landscape || $portrait ) && $ext ne '.pdf';
            return 'pdf'  if $ext eq '.pdf';
            return 'html' if $ext eq '.html' || $ext eq '.htm';
            return 'docx' if $ext eq '.docx';
            die "Markdown source needs --pdf/--to-pdf, --html/--to-html, or a .pdf/.html output path\n";
        }
        die "PDF layout flags are only valid for PDF output\n"
          if ( defined $paper && $paper ne '' ) || $landscape || $portrait;
        die "Markdown source needs a target format\n";
    }

    if ( $source_format eq 'docx' ) {
        die "PDF layout flags are only valid for markdown to PDF output\n"
          if ( defined $paper && $paper ne '' ) || $landscape || $portrait;
        die "DOCX source can only convert to markdown or pdf\n" if $to_html;
        return 'pdf' if $to_pdf;
        if ( defined $to && $to ne '' ) {
            my $ext = lc( ( fileparse( $to, qr/\.[^.]*/ ) )[2] || '' );
            return 'pdf'      if $ext eq '.pdf';
            return 'markdown' if $ext eq '.md' || $ext eq '.markdown' || $ext eq '';
            die "DOCX source can only convert to markdown or pdf\n";
        }
        return 'markdown';
    }

    die "HTML source can only convert to markdown\n" if $source_format eq 'html' && ( $to_pdf || $to_html );
    die "PDF source can only convert to markdown or docx\n"  if $source_format eq 'pdf'  && ( $to_pdf || $to_html );
    die "PDF layout flags are only valid for PDF output\n"
      if ( defined $paper && $paper ne '' ) || $landscape || $portrait;

    if ( defined $to && $to ne '' ) {
        my $ext = lc( ( fileparse( $to, qr/\.[^.]*/ ) )[2] || '' );
        return 'docx' if $source_format eq 'pdf' && $ext eq '.docx';
        die "Only markdown output is supported for $source_format input\n"
          if $ext ne '' && $ext ne '.md' && $ext ne '.markdown';
    }

    return 'markdown';
}

sub _output_path {
    my ( $self, %args ) = @_;
    my $from          = $args{from};
    my $to            = $args{to};
    my $target_format = $args{target_format};
    my %suffix_for = (
        markdown => '.md',
        html     => '.html',
        pdf      => '.pdf',
        docx     => '.docx',
    );
    my $suffix = $suffix_for{$target_format} || die "Missing target suffix for $target_format\n";

    if ( defined $to && $to ne '' ) {
        return $self->_with_extension( $to, $target_format, $suffix );
    }

    my ( $name, $dir ) = fileparse( $from, qr/\.[^.]*/ );
    return File::Spec->catfile( $dir, $name . $suffix );
}

sub _with_extension {
    my ( $self, $path, $target_format, $suffix ) = @_;
    my $lower = lc($path);
    return $path if $lower =~ /\Q$suffix\E\z/i;
    return $path if $target_format eq 'markdown' && $lower =~ /\.markdown\z/;
    return $path if $target_format eq 'html'     && $lower =~ /\.htm\z/;
    $path =~ s/\.[^.]+\z// if $path =~ /\/?[^\/]+\.[^.]+\z/;
    return $path . $suffix;
}

sub _markdown_to_html {
    my ( $self, $from, $to ) = @_;
    $self->_log("step=markdown_to_html.perl");
    my $markdown = $self->_read_text($from);
    my $html = $self->{markdown_to_html}->($markdown);
    $self->_write_text( $to, $html );
    return 1;
}

sub _html_to_markdown {
    my ( $self, $from, $to ) = @_;
    $self->_log("step=html_to_markdown.perl");
    my $html = $self->_read_text($from);
    my $markdown = $self->{html_to_markdown}->($html);
    $self->_write_text( $to, $markdown );
    return 1;
}

sub _markdown_to_pdf {
    my ( $self, $from, $to, $layout ) = @_;
    my $markdown = $self->_read_text($from);
    $self->_log("step=markdown_to_pdf.perl");
    $self->{markdown_to_pdf}->( $markdown, $to, $layout );
    return 1;
}

sub _docx_to_pdf {
    my ( $self, $from, $to ) = @_;
    $self->_log("step=docx_to_pdf.platform");
    if ( $self->{docx_to_pdf} ) {
        return $self->{docx_to_pdf}->( $from, $to );
    }
    return $self->_default_docx_to_pdf( $from, $to );
}

sub _pdf_layout {
    my ( $self, %args ) = @_;
    return _validate_pdf_layout(%args);
}

sub _pdf_to_markdown {
    my ( $self, $from, $to ) = @_;
    $self->_log("step=pdf_to_markdown.perl");
    my $markdown = $self->{pdf_to_markdown}->($from);
    $self->_write_text( $to, $markdown );
    return 1;
}

sub _pdf_to_docx {
    my ( $self, $from, $to ) = @_;
    $self->_log("step=pdf_to_docx.platform");
    if ( $self->{pdf_to_docx} ) {
        return $self->{pdf_to_docx}->( $from, $to );
    }
    return $self->_default_pdf_to_docx( $from, $to );
}

sub _docx_to_markdown {
    my ( $self, $from, $to ) = @_;
    $self->_log("step=docx_to_markdown.chain");
    my $tmpdir = tempdir( CLEANUP => 1 );
    my $intermediate = File::Spec->catfile( $tmpdir, 'intermediate.pdf' );
    $self->_docx_to_pdf( $from, $intermediate );
    return $self->_pdf_to_markdown( $intermediate, $to );
}

sub _markdown_to_docx {
    my ( $self, $from, $to ) = @_;
    $self->_log("step=markdown_to_docx.chain");
    my $tmpdir = tempdir( CLEANUP => 1 );
    my $intermediate = File::Spec->catfile( $tmpdir, 'intermediate.pdf' );
    $self->_markdown_to_pdf( $from, $intermediate, $self->_pdf_layout() );
    return $self->_pdf_to_docx( $intermediate, $to );
}

sub _read_text {
    my ( $self, $path ) = @_;
    open my $fh, '<:raw', $path or die "Unable to read $path: $!\n";
    local $/;
    my $content = <$fh>;
    close $fh or die "Unable to close $path: $!\n";
    return $content;
}

sub _write_text {
    my ( $self, $path, $content ) = @_;
    open my $fh, '>:raw', $path or die "Unable to write $path: $!\n";
    print {$fh} $content;
    close $fh or die "Unable to close $path: $!\n";
    return 1;
}

sub _log {
    my ( $self, $message ) = @_;
    $self->{logger}->($message);
    return 1;
}

sub _default_markdown_to_html {
    my ( $markdown, $enhancer ) = @_;
    $enhancer ||= Markdown::Enhancer->new;
    return $enhancer->markdown_to_html($markdown);
}

sub _default_html_to_markdown {
    my ($html) = @_;
    require HTML::WikiConverter;
    my $converter = HTML::WikiConverter->new( dialect => 'Markdown' );
    return $converter->html2wiki($html);
}

sub _default_docx_to_pdf {
    my ( $self, $from, $to ) = @_;
    $self->_ensure_output_dir($to);
    my $platform = $self->{platform} || '';

    if ( $platform eq 'MSWin32' ) {
        return $self->_word_windows_convert( $from, $to, 'pdf' ) if $self->_windows_word_available;
        return $self->_libreoffice_convert( $from, $to, 'pdf' ) if $self->_soffice_binary;
        die "DOCX to PDF on Windows requires Microsoft Word or LibreOffice\n";
    }

    if ( $platform eq 'darwin' ) {
        return $self->_word_macos_convert( $from, $to, 'pdf' ) if $self->_macos_word_available;
        return $self->_libreoffice_convert( $from, $to, 'pdf' ) if $self->_soffice_binary;
        die "DOCX to PDF on macOS requires Microsoft Word or LibreOffice\n";
    }

    return $self->_libreoffice_convert( $from, $to, 'pdf' ) if $self->_soffice_binary;
    die "DOCX to PDF on Linux requires LibreOffice or soffice\n";
}

sub _default_pdf_to_docx {
    my ( $self, $from, $to ) = @_;
    $self->_ensure_output_dir($to);
    my $platform = $self->{platform} || '';

    # Microsoft Word can genuinely reflow a PDF into editable text on open,
    # so prefer real Word automation when it's available.
    return $self->_word_windows_convert( $from, $to, 'docx' )
      if $platform eq 'MSWin32' && $self->_windows_word_available;

    # LibreOffice cannot do this at all, on any platform: soffice always
    # imports a PDF as a Draw document (there is no Writer-compatible PDF
    # import filter), and Draw documents have no export filter to DOCX
    # ("no export filter for ... found, aborting"). So instead of shelling
    # out to a conversion that is guaranteed to fail, recover the text with
    # the same pure-Perl extractor used for pdf-to-markdown and write a real
    # DOCX package directly.
    my $markdown = _default_pdf_to_markdown($from);
    return _default_markdown_to_docx( $markdown, $to, $self->{enhancer} );
}

sub _default_markdown_to_pdf {
    my ( $markdown, $to, $layout, $enhancer ) = @_;
    require PDF::API2;
    $enhancer ||= Markdown::Enhancer->new;
    $layout ||= _validate_pdf_layout();

    my $pdf = PDF::API2->new;
    my $font_regular = $pdf->corefont( 'Helvetica',      -encoding => 'utf8' );
    my $font_bold    = $pdf->corefont( 'Helvetica-Bold', -encoding => 'utf8' );
    my $x = 50;
    my ( $page, $text, $gfx, $y, $page_width, $page_height ) = _new_pdf_page( $pdf, $layout );
    my $width = $page_width - 100;

    for my $block ( @{ $enhancer->parse_blocks($markdown) } ) {
        if ( $block->{type} eq 'table' ) {
            ( $page, $text, $gfx, $y, $page_width, $page_height ) = _render_pdf_table(
                pdf          => $pdf,
                page         => $page,
                text         => $text,
                gfx          => $gfx,
                y            => $y,
                rows         => $block->{rows},
                x            => $x,
                width        => $width,
                font_regular => $font_regular,
                font_bold    => $font_bold,
                layout       => $layout,
            );
            $width = $page_width - 100;
            next;
        }

        my @lines = _pdf_lines_for_block($block);
        for my $raw_line (@lines) {
            my $line = $raw_line;
            my $font = $font_regular;
            my $size = 12;
            my $leading = 16;

            if ( $line =~ s/^###\s+// ) {
                $font = $font_bold;
                $size = 14;
                $leading = 20;
            }
            elsif ( $line =~ s/^##\s+// ) {
                $font = $font_bold;
                $size = 18;
                $leading = 24;
            }
            elsif ( $line =~ s/^#\s+// ) {
                $font = $font_bold;
                $size = 24;
                $leading = 30;
            }
            elsif ( $line =~ s/^[-*]\s+/* / ) {
                $size = 12;
            }

            my @wrapped = _wrap_text( $font, $size, $line, $width );
            @wrapped = ('') if !@wrapped;

            for my $segment (@wrapped) {
                if ( $y < 50 ) {
                    ( $page, $text, $gfx, $y, $page_width, $page_height ) = _new_pdf_page( $pdf, $layout );
                    $width = $page_width - 100;
                }
                $text->font( $font, $size );
                $text->translate( $x, $y );
                $text->text($segment);
                $y -= $leading;
            }

            $y -= 6 if $raw_line =~ /^\s*$/;
        }
    }

    $pdf->saveas($to);
    return 1;
}

sub _new_pdf_page {
    my ( $pdf, $layout ) = @_;
    $layout ||= _validate_pdf_layout();
    $layout->{paper}       ||= 'A4';
    $layout->{orientation} ||= 'portrait';
    my ( $width, $height ) = _paper_dimensions( $layout->{paper} );
    ( $width, $height ) = ( $height, $width ) if $layout->{orientation} eq 'landscape';
    my $page = $pdf->page;
    $page->mediabox( 0, 0, $width, $height );
    my $text = $page->text;
    my $gfx  = $page->gfx;
    my $y    = $height - 50;
    return ( $page, $text, $gfx, $y, $width, $height );
}

sub _pdf_lines_for_block {
    my ($block) = @_;
    return ( '#' x $block->{level} . ' ' . $block->{text} ) if $block->{type} eq 'heading';
    return ( '* ' . $block->{text} ) if $block->{type} eq 'bullet';
    return ( 'Quote: ' . $block->{text} ) if $block->{type} eq 'blockquote';
    return @{ $block->{lines} } if $block->{type} eq 'code';
    return ( $block->{text} ) if $block->{type} eq 'paragraph';
    return ('') if $block->{type} eq 'blank';
    return;
}

sub _render_pdf_table {
    my (%args) = @_;
    my $pdf          = $args{pdf};
    my $page         = $args{page};
    my $text         = $args{text};
    my $gfx          = $args{gfx};
    my $y            = $args{y};
    my $rows         = $args{rows} || [];
    my $x            = $args{x};
    my $width        = $args{width};
    my $font_regular = $args{font_regular};
    my $font_bold    = $args{font_bold};
    my $layout       = $args{layout} || _validate_pdf_layout();
    $layout->{paper}       ||= 'A4';
    $layout->{orientation} ||= 'portrait';
    my $padding      = 6;
    my $size         = 11;
    my $leading      = 14;
    my $columns      = scalar @{ $rows->[0] || [] } || 1;
    my $cell_width   = $width / $columns;

    for my $row_index ( 0 .. $#$rows ) {
        my $row  = $rows->[$row_index];
        my $font = $row_index == 0 ? $font_bold : $font_regular;
        my @cell_lines;
        my $max_lines = 1;

        for my $cell (@{$row}) {
            my $plain_cell = Markdown::Enhancer->_plain_inline($cell);
            my @wrapped = _wrap_text( $font, $size, $plain_cell, $cell_width - ( $padding * 2 ) );
            @wrapped = ('') if !@wrapped;
            push @cell_lines, \@wrapped;
            $max_lines = @wrapped if @wrapped > $max_lines;
        }

        my $row_height = ( $max_lines * $leading ) + ( $padding * 2 );
        if ( $y - $row_height < 50 ) {
            my ( $new_page, $new_text, $new_gfx, $new_y, $new_width, $new_height ) = _new_pdf_page( $pdf, $layout );
            ( $page, $text, $gfx, $y ) = ( $new_page, $new_text, $new_gfx, $new_y );
            if ( !defined $new_width ) {
                my ( $fallback_width, $fallback_height ) = _paper_dimensions( $layout->{paper} );
                ( $fallback_width, $fallback_height ) = ( $fallback_height, $fallback_width )
                  if $layout->{orientation} eq 'landscape';
                $new_width = $fallback_width;
            }
            $width      = $new_width - 100;
            $cell_width = $width / $columns;
        }

        for my $col_index ( 0 .. $#$row ) {
            my $cell_x = $x + ( $col_index * $cell_width );
            $gfx->rect( $cell_x, $y - $row_height, $cell_width, $row_height );
            $gfx->stroke;
            my $line_y = $y - $padding - $size;
            for my $segment ( @{ $cell_lines[$col_index] } ) {
                $text->font( $font, $size );
                $text->translate( $cell_x + $padding, $line_y );
                $text->text($segment);
                $line_y -= $leading;
            }
        }

        $y -= $row_height;
    }

    $y -= 8;
    my ( $page_width, $page_height ) = _paper_dimensions( $layout->{paper} );
    ( $page_width, $page_height ) = ( $page_height, $page_width ) if $layout->{orientation} eq 'landscape';
    return ( $page, $text, $gfx, $y, $page_width, $page_height );
}

sub _validate_pdf_layout {
    my (%args) = @_;
    my $paper = _normalize_paper_name( $args{paper} || 'A4' );
    my %valid = map { $_ => 1 } qw(
      A0 A1 A2 A3 A4 A5 A6 A7 A8 A9 A10
      B0 B1 B2 B3 B4 B5 B6 B7 B8 B9 B10
      C0 C1 C2 C3 C4 C5 C6 C7
      DL
      ANSI-A ANSI-B ANSI-C ANSI-D ANSI-E
    );
    die "Unsupported paper size: $paper\n" if !$valid{$paper};
    die "Choose only one of --landscape or --portrait\n" if ( $args{landscape} && $args{portrait} );
    my $orientation = $args{landscape} ? 'landscape' : 'portrait';
    return {
        paper       => $paper,
        orientation => $orientation,
    };
}

sub _paper_dimensions {
    my ($paper) = @_;
    $paper = _normalize_paper_name( $paper || 'A4' );
    my %size = (
        A0 => [ 2384, 3370 ],
        A1 => [ 1684, 2384 ],
        A2 => [ 1191, 1684 ],
        A3 => [ 842, 1191 ],
        A4 => [ 595, 842 ],
        A5 => [ 420, 595 ],
        A6 => [ 298, 420 ],
        A7 => [ 210, 298 ],
        A8 => [ 147, 210 ],
        A9 => [ 105, 147 ],
        A10 => [ 74, 105 ],
        B0 => [ 2835, 4008 ],
        B1 => [ 2004, 2835 ],
        B2 => [ 1417, 2004 ],
        B3 => [ 1001, 1417 ],
        B4 => [ 709, 1001 ],
        B5 => [ 499, 709 ],
        B6 => [ 354, 499 ],
        B7 => [ 249, 354 ],
        B8 => [ 176, 249 ],
        B9 => [ 125, 176 ],
        B10 => [ 88, 125 ],
        C0 => [ 2599, 3677 ],
        C1 => [ 1837, 2599 ],
        C2 => [ 1298, 1837 ],
        C3 => [ 918, 1298 ],
        C4 => [ 649, 918 ],
        C5 => [ 459, 649 ],
        C6 => [ 323, 459 ],
        C7 => [ 230, 323 ],
        DL => [ 312, 624 ],
        'ANSI-A' => [ 612, 792 ],
        'ANSI-B' => [ 792, 1224 ],
        'ANSI-C' => [ 1224, 1584 ],
        'ANSI-D' => [ 1584, 2448 ],
        'ANSI-E' => [ 2448, 3168 ],
    );
    my $dims = $size{$paper} || die "Unsupported paper size: $paper\n";
    return @{$dims};
}

sub _normalize_paper_name {
    my ($paper) = @_;
    $paper = uc( $paper || '' );
    $paper =~ s/\s+//g;
    $paper =~ s/_/-/g;
    $paper = "ANSI-$1" if $paper =~ /^ANSI-?([A-E])$/;
    return $paper;
}

sub _wrap_text {
    my ( $font, $size, $line, $width ) = @_;
    return ('') if !defined $line || $line eq '';
    my @lines;
    my $current = '';
    my @tokens = split /(\s+)/, $line;

    for my $token (@tokens) {
        next if !defined $token || $token eq '';

        if ( $token =~ /^\s+$/ ) {
            next if $current eq '';
            my $candidate = $current . ' ';
            if ( _text_width( $font, $size, $candidate ) <= $width ) {
                $current = $candidate;
                next;
            }
            $current =~ s/\s+\z//;
            push @lines, $current if $current ne '';
            $current = '';
            next;
        }

        my @parts = _split_long_token( $font, $size, $token, $width );
        for my $part (@parts) {
            my $candidate = $current . $part;
            if ( $current eq '' ) {
                $current = $part;
                next;
            }
            if ( _text_width( $font, $size, $candidate ) <= $width ) {
                $current = $candidate;
                next;
            }
            $current =~ s/\s+\z//;
            push @lines, $current if $current ne '';
            $current = $part;
        }
    }

    $current =~ s/\s+\z// if defined $current;
    push @lines, $current if defined $current;
    return @lines;
}

sub _split_long_token {
    my ( $font, $size, $token, $width ) = @_;
    return ('') if !defined $token || $token eq '';
    return ($token) if _text_width( $font, $size, $token ) <= $width;

    my @segments;
    my $current = '';

    for my $fragment ( _token_fragments($token) ) {
        my $candidate = $current . $fragment;

        if ( $current ne '' && _text_width( $font, $size, $candidate ) <= $width ) {
            $current = $candidate;
            next;
        }

        if ( $current ne '' && $fragment =~ /^\./ ) {
            my ( $prefix, $tail ) = _rebalance_extension_fragment( $font, $size, $current, $fragment, $width );
            if ( defined $prefix && defined $tail ) {
                push @segments, $prefix if $prefix ne '';
                $current = $tail;
                next;
            }
        }

        if ( $current ne '' ) {
            push @segments, $current;
            $current = '';
        }

        if ( _text_width( $font, $size, $fragment ) <= $width ) {
            $current = $fragment;
            next;
        }

        my @hard = _hard_wrap_fragment( $font, $size, $fragment, $width );
        push @segments, @hard[ 0 .. $#hard - 1 ] if @hard > 1;
        $current = $hard[-1] // '';
    }

    push @segments, $current if $current ne '';
    return @segments;
}

sub _token_fragments {
    my ($token) = @_;
    my @fragments;

    while ( length $token ) {
        if ( $token =~ s/\A(\/+)// ) {
            push @fragments, $1;
            next;
        }

        if ( $token =~ s/\A(\.(?:java|md|html|pdf|txt))//i ) {
            push @fragments, $1;
            next;
        }

        if ( $token =~ s/\A(\.[A-Za-z0-9]+)// ) {
            push @fragments, $1;
            next;
        }

        if ( $token =~ s/\A([A-Z]+(?=[A-Z][a-z]|\d|[._:\/-]|\z))// ) {
            push @fragments, $1;
            next;
        }

        if ( $token =~ s/\A([A-Z]?[a-z]+)// ) {
            push @fragments, $1;
            next;
        }

        if ( $token =~ s/\A(\d+(?:\.\d+)?%?)// ) {
            push @fragments, $1;
            next;
        }

        if ( $token =~ s/\A([._:-]+)// ) {
            push @fragments, $1;
            next;
        }

        $token =~ s/\A(.)//;
        push @fragments, $1;
    }

    return @fragments;
}

sub _hard_wrap_fragment {
    my ( $font, $size, $fragment, $width ) = @_;
    return ('') if !defined $fragment || $fragment eq '';

    my @parts;
    my $remaining = $fragment;
    while ( length $remaining ) {
        my $part = '';
        for my $char ( split //, $remaining ) {
            my $candidate = $part . $char;
            last if length($part) && _text_width( $font, $size, $candidate ) > $width;
            $part = $candidate;
        }
        $part = substr( $remaining, 0, 1 ) if $part eq '';
        push @parts, $part;
        $remaining = substr( $remaining, length($part) );
    }

    return @parts;
}

sub _rebalance_extension_fragment {
    my ( $font, $size, $current, $fragment, $width ) = @_;
    my @parts = _token_fragments($current);
    return if @parts < 2;

    for my $take ( reverse 1 .. $#parts ) {
        my $prefix = join '', @parts[ 0 .. $#parts - $take ];
        my $tail   = join( '', @parts[ $#parts - $take + 1 .. $#parts ] ) . $fragment;
        next if $prefix eq '';
        next if _text_width( $font, $size, $prefix ) > $width;
        next if _text_width( $font, $size, $tail ) > $width;
        return ( $prefix, $tail );
    }

    return;
}

sub _text_width {
    my ( $font, $size, $text ) = @_;
    my $raw = $font->width($text);
    return 0 if !defined $raw;
    return $raw > 50 ? ( $raw / 1000 ) * $size : $raw * $size;
}

sub _default_pdf_to_markdown {
    my ($from) = @_;
    require CAM::PDF;
    my $pdf = CAM::PDF->new($from)
      or do {
        no warnings 'once';
        die 'Unable to read PDF: ' . ( $CAM::PDF::errstr || $from ) . "\n";
      };
    my $pages = $pdf->numPages();
    my @chunks;
    for my $page ( 1 .. $pages ) {
        _pdf_strip_marked_content( $pdf, $page );
        my $tree = $pdf->getPageContentTree($page);
        my $cmaps = defined $tree ? _pdf_page_font_cmaps( $pdf, $page ) : {};
        my $text = defined $tree ? _pdf_render_page_text( $tree, $cmaps ) : '';
        $text = '' if !defined $text;
        $text =~ s/\r\n?/\n/g;
        $text =~ s/[ \t]+\n/\n/g;
        $text =~ s/\n{3,}/\n\n/g;
        $text =~ s/\A\s+|\s+\z//g;
        push @chunks, $text if length $text;
    }
    my $markdown = join "\n\n", @chunks;
    $markdown .= "\n" if length $markdown;
    return $markdown;
}

# BDC/BMC ... EMC "marked content" operators tag spans of a page (for
# accessibility structure trees, or "Artifact" spans such as a decorative
# clip-path setup) and have no rendering effect of their own. Real-world
# producers - LibreOffice's own PDF export included - routinely interleave
# them with the q/Q graphics-state stack in ways that are fully valid PDF but
# that CAM::PDF's single-stack block matcher cannot follow: it dies with
# "Wrong block ending (expected 'Q', got 'EMC')" internally and
# getPageContentTree silently returns undef for the whole page, which is
# exactly why docx-to-markdown (which chains through a LibreOffice-rendered
# intermediate PDF) was producing an empty file instead of an error. Since
# marked-content tags carry no positioning or text of their own, stripping
# them out of the raw content stream before parsing sidesteps the mismatch
# without touching anything that affects layout or text.
sub _pdf_strip_marked_content {
    my ( $pdf, $page ) = @_;
    my $raw = $pdf->getPageContent($page);
    return if !defined $raw;

    my $stripped = $raw;
    $stripped =~ s{ /[A-Za-z0-9_.\#]+ \s* (?: <<(?:[^<>]|<<[^<>]*>>)*>> | /[A-Za-z0-9_.\#]+ )? \s* B(?:DC|MC) }{}gx;
    $stripped =~ s{ \b EMC \b }{}gx;

    $pdf->setPageContent( $page, $stripped ) if $stripped ne $raw;
    return;
}

# Office producers (LibreOffice, Word, ...) commonly embed a subsetted font
# and remap its character codes for smaller embedding size, so the bytes
# inside Tj/TJ strings are just that font's internal codes - not ASCII, not
# UTF-16, not anything CAM::PDF::PageText's plain byte-concatenation can turn
# into real text. A subsetted font's /ToUnicode entry is exactly the CMap
# that maps those codes back to real Unicode text; without consulting it, a
# page like this decodes to unreadable control-character noise instead of
# words. This resolves each page's fonts to their ToUnicode maps up front so
# _pdf_render_page_text can translate codes through the font that was active
# via Tf when each string was shown.
sub _pdf_page_font_cmaps {
    my ( $pdf, $page ) = @_;
    my %cmaps;

    my $page_obj  = eval { $pdf->getPage($page) };
    my $resources = $page_obj && $page_obj->{Resources} ? eval { $pdf->getValue( $page_obj->{Resources} ) } : undef;
    my $fonts     = $resources && $resources->{Font} ? eval { $pdf->getValue( $resources->{Font} ) } : undef;
    return \%cmaps if !$fonts || ref $fonts ne 'HASH';

    require CAM::PDF::Node;

    for my $name ( keys %{$fonts} ) {
        my $font = eval { $pdf->getValue( $fonts->{$name} ) };
        next if !$font || ref $font ne 'HASH' || !$font->{ToUnicode};

        my $cmap_text = eval {
            my $dict = $pdf->getValue( $font->{ToUnicode} );
            $pdf->decodeOne( CAM::PDF::Node->new( 'dictionary', $dict ) );
        };
        next if !defined $cmap_text || ref $cmap_text;

        $cmaps{$name} = _pdf_parse_tounicode_cmap($cmap_text);
    }

    return \%cmaps;
}

sub _pdf_parse_tounicode_cmap {
    my ($text) = @_;
    my %map;
    my $width = 1;

    if ( $text =~ / begincodespacerange \s* < ( [0-9A-Fa-f]+ ) > /xs ) {
        $width = int( ( length($1) + 1 ) / 2 );
        $width = 1 if $width < 1;
    }

    while ( $text =~ / beginbfchar (.*?) endbfchar /xsg ) {
        my $block = $1;
        while ( $block =~ / <([0-9A-Fa-f]+)> \s* <([0-9A-Fa-f]+)> /xsg ) {
            $map{ hex($1) } = _pdf_unicode_hex_to_chars($2);
        }
    }

    while ( $text =~ / beginbfrange (.*?) endbfrange /xsg ) {
        my $block = $1;
        while ( $block =~ / <([0-9A-Fa-f]+)> \s* <([0-9A-Fa-f]+)> \s* (\[[^\]]*\]|<[0-9A-Fa-f]+>) /xsg ) {
            my ( $start, $end, $dest ) = ( hex($1), hex($2), $3 );

            if ( $dest =~ / \A \[ (.*) \] \z /xs ) {
                my $code = $start;
                for my $hex_val ( $1 =~ /<([0-9A-Fa-f]+)>/g ) {
                    $map{$code} = _pdf_unicode_hex_to_chars($hex_val);
                    $code++;
                }
            }
            elsif ( $dest =~ / \A <([0-9A-Fa-f]+)> \z /xs ) {
                my $base_hex = $1;
                my $base     = hex($base_hex);
                my $digits   = length $base_hex;
                my $range_end = $end - $start > 20000 ? $start + 20000 : $end;    # guard against a pathological/malformed range
                for my $code ( $start .. $range_end ) {
                    $map{$code} = _pdf_unicode_hex_to_chars( sprintf( '%0' . $digits . 'X', $base + ( $code - $start ) ) );
                }
            }
        }
    }

    return { width => $width, map => \%map };
}

sub _pdf_unicode_hex_to_chars {
    my ($hex) = @_;
    my @units = map { hex($_) } ( $hex =~ /(....)/g );

    my @codepoints;
    my $i = 0;
    while ( $i <= $#units ) {
        my $unit = $units[$i];
        if ( $unit >= 0xD800 && $unit <= 0xDBFF && $i + 1 <= $#units && $units[ $i + 1 ] >= 0xDC00 && $units[ $i + 1 ] <= 0xDFFF ) {
            push @codepoints, 0x10000 + ( ( $unit - 0xD800 ) << 10 ) + ( $units[ $i + 1 ] - 0xDC00 );
            $i += 2;
        }
        else {
            push @codepoints, $unit;
            $i++;
        }
    }

    return join q{}, map { chr($_) } @codepoints;
}

sub _pdf_decode_font_bytes {
    my ( $bytes, $cmaps, $font ) = @_;
    return $bytes if !defined $bytes || $bytes eq '';
    return $bytes if !$font || !$cmaps || !$cmaps->{$font};

    my $entry = $cmaps->{$font};
    my $width = $entry->{width} || 1;
    my $map   = $entry->{map}   || {};

    my $decoded = q{};
    for ( my $i = 0; $i < length $bytes; $i += $width ) {
        my $chunk = substr( $bytes, $i, $width );
        last if $chunk eq '';
        my $code = 0;
        $code = ( $code << 8 ) | ord($_) for split //, $chunk;
        $decoded .= exists $map->{$code} ? $map->{$code} : $chunk;
    }

    require Encode;
    return Encode::encode( 'UTF-8', $decoded );
}

# CAM::PDF::PageText->render only ever breaks a line on the relative Td/TD
# operator (or T*). PDF::API2's $text->translate($x, $y) - the call this
# module itself uses to lay out generated PDFs, and one many other PDF
# writers use too - instead emits an absolute Tm text matrix, which
# CAM::PDF::PageText never looks at. The result is every line on a page
# getting joined with a single space, so extracted text collapses into one
# unreadable blob with all paragraph/heading/list structure lost. This walks
# the same page content tree CAM::PDF::PageText uses, reusing its string-
# building heuristics for TJ/Tj/'/"/Td/TD/T*, but also breaks lines on Tm's
# vertical movement (and treats an unusually large vertical jump as a
# paragraph break).
sub _pdf_render_page_text {
    my ( $pagetree, $cmaps ) = @_;
    $cmaps ||= {};

    my $str          = q{};
    my @stack        = ( [ @{ $pagetree->{blocks} } ] );
    my $in_textblock = 0;
    my $last_y;
    my $last_gap;
    my $font;

    while ( @stack > 0 ) {
        my $node = $stack[-1];
        if ( ref $node ) {
            if ( @{$node} > 0 ) {
                my $block = shift @{$node};
                if ( $block->{type} eq 'block' ) {
                    if ( $block->{name} eq 'BT' ) {
                        push @stack, 'BT';
                        $in_textblock = 1;
                        undef $last_y;
                        undef $last_gap;
                    }
                    push @stack, [ @{ $block->{value} } ];
                }
                elsif ($in_textblock) {
                    next if $block->{type} ne 'op';
                    my @args = @{ $block->{args} };

                    if    ( $block->{name} eq 'TJ' )  { $str = _pdf_op_TJ( $str, \@args, $cmaps, $font ); }
                    elsif ( $block->{name} eq 'Tj' )  { $str = _pdf_op_Tj( $str, \@args, $cmaps, $font ); }
                    elsif ( $block->{name} eq q{\'} ) { $str = _pdf_op_Tquote( $str, \@args, $cmaps, $font ); }
                    elsif ( $block->{name} eq q{\"} ) { $str = _pdf_op_Tquote( $str, \@args, $cmaps, $font ); }
                    elsif ( $block->{name} eq 'Td' )  { $str = _pdf_op_Td( $str, \@args ); }
                    elsif ( $block->{name} eq 'TD' )  { $str = _pdf_op_Td( $str, \@args ); }
                    elsif ( $block->{name} eq 'T*' )  { $str = _pdf_op_Tstar($str); }
                    elsif ( $block->{name} eq 'Tm' )  { $str = _pdf_op_Tm( $str, \@args, \$last_y, \$last_gap ); }
                    elsif ( $block->{name} eq 'Tf' )  { $font = _pdf_op_Tf( \@args ); }
                }
            }
            else {
                pop @stack;
            }
        }
        else {
            pop @stack;
            $in_textblock = 0;
            $str =~ s/ [ ]* \z /\n/xms;
        }
    }

    return $str;
}

sub _pdf_op_Tf {
    my ($args_ref) = @_;
    return $args_ref->[0] && $args_ref->[0]->{type} eq 'label' ? $args_ref->[0]->{value} : undef;
}

sub _pdf_op_TJ {
    my ( $str, $args_ref, $cmaps, $font ) = @_;
    return $str if @{$args_ref} != 1 || $args_ref->[0]->{type} ne 'array';

    $str =~ s/ (\S) \z /$1 /xms;
    for my $node ( @{ $args_ref->[0]->{value} } ) {
        if ( $node->{type} eq 'string' || $node->{type} eq 'hexstring' ) {
            $str .= _pdf_decode_font_bytes( $node->{value}, $cmaps, $font );
        }
        elsif ( $node->{type} eq 'number' ) {
            if ( $node->{value} < -250 ) {
                $str =~ s/ (\S) \z /$1 /xms;
            }
        }
    }
    return $str;
}

sub _pdf_op_Tj {
    my ( $str, $args_ref, $cmaps, $font ) = @_;
    return $str
      if @{$args_ref} < 1
      || ( $args_ref->[-1]->{type} ne 'string' && $args_ref->[-1]->{type} ne 'hexstring' );

    $str =~ s/ (\S) \z /$1 /xms;
    return $str . _pdf_decode_font_bytes( $args_ref->[-1]->{value}, $cmaps, $font );
}

sub _pdf_op_Tquote {
    my ( $str, $args_ref, $cmaps, $font ) = @_;
    return $str
      if @{$args_ref} < 1
      || ( $args_ref->[-1]->{type} ne 'string' && $args_ref->[-1]->{type} ne 'hexstring' );

    $str =~ s/ [ ]* \z /\n/xms;
    return $str . _pdf_decode_font_bytes( $args_ref->[-1]->{value}, $cmaps, $font );
}

sub _pdf_op_Td {
    my ( $str, $args_ref ) = @_;
    return $str
      if @{$args_ref} != 2
      || $args_ref->[0]->{type} ne 'number'
      || $args_ref->[1]->{type} ne 'number';

    if ( $args_ref->[1]->{value} < 0 && 2 * ( abs $args_ref->[1]->{value} ) > abs $args_ref->[0]->{value} ) {
        $str =~ s/ [ ]* \z /\n/xms;
    }
    return $str;
}

sub _pdf_op_Tstar {
    my ($str) = @_;
    $str =~ s/ [ ]* \z /\n/xms;
    return $str;
}

sub _pdf_op_Tm {
    my ( $str, $args_ref, $last_y_ref, $last_gap_ref ) = @_;
    return $str if @{$args_ref} != 6;
    for my $arg ( @{$args_ref} ) {
        return $str if $arg->{type} ne 'number';
    }

    my $y = $args_ref->[5]->{value};
    if ( defined ${$last_y_ref} ) {
        my $dy = ${$last_y_ref} - $y;
        if ( abs($dy) > 0.01 ) {
            if ( $dy > 0 && defined ${$last_gap_ref} && $dy > ${$last_gap_ref} * 1.6 ) {
                $str =~ s/ [ ]* \z /\n\n/xms;
            }
            else {
                $str =~ s/ [ ]* \z /\n/xms;
            }
            ${$last_gap_ref} = $dy if $dy > 0;
        }
    }
    ${$last_y_ref} = $y;
    return $str;
}

# Builds a real .docx (Office Open XML WordprocessingML) package directly,
# without any external Office backend. A .docx is just a zip of a few XML
# parts, so this needs no dependency beyond Archive::Zip. Formatting fidelity
# intentionally matches the existing PDF renderer: headings are bold/sized
# text (no literal '#'), bullets/blockquotes get a plain text prefix, and
# inline markdown markers like **bold** are left as literal characters,
# since block->{text} is already plain text by the time it reaches here.
sub _default_markdown_to_docx {
    my ( $markdown, $to, $enhancer ) = @_;
    require Archive::Zip;
    $enhancer ||= Markdown::Enhancer->new;

    my $body_xml = join q{}, map { _docx_block_xml($_) } @{ $enhancer->parse_blocks($markdown) };
    $body_xml = '<w:p/>' if !length $body_xml;

    my $zip = Archive::Zip->new;
    $zip->addString( _docx_content_types_xml(), '[Content_Types].xml' );
    $zip->addString( _docx_rels_xml(),           '_rels/.rels' );
    my $doc_member = $zip->addString( _docx_document_xml($body_xml), 'word/document.xml' );
    $doc_member->desiredCompressionMethod( Archive::Zip::COMPRESSION_DEFLATED() );

    my $write_result = $zip->writeToFileNamed($to);
    die "Unable to write DOCX file: $to\n" if $write_result != Archive::Zip::AZ_OK();

    return 1;
}

sub _docx_block_xml {
    my ($block) = @_;
    my $type = $block->{type};

    return _docx_table_xml( $block->{rows} ) if $type eq 'table';
    return '<w:p/>' if $type eq 'blank';

    if ( $type eq 'code' ) {
        my @lines = @{ $block->{lines} };
        return '<w:p/>' if !@lines;
        return join q{}, map { _docx_paragraph_xml( $_, mono => 1 ) } @lines;
    }

    return _docx_paragraph_xml( $block->{text}, bold => 1, size => _docx_heading_point_size( $block->{level} ) )
      if $type eq 'heading';
    return _docx_paragraph_xml( '* ' . $block->{text} )      if $type eq 'bullet';
    return _docx_paragraph_xml( 'Quote: ' . $block->{text} ) if $type eq 'blockquote';
    return _docx_paragraph_xml( $block->{text} )              if $type eq 'paragraph';

    return '';
}

sub _docx_heading_point_size {
    my ($level) = @_;
    my @sizes = ( 24, 18, 14, 13, 12, 11 );
    return $sizes[ ( $level || 1 ) - 1 ] || 11;
}

sub _docx_paragraph_xml {
    my ( $text, %opt ) = @_;
    $text = '' if !defined $text;
    return '<w:p/>' if $text eq '';

    my $half_points = ( $opt{size} || 12 ) * 2;
    my $rpr = '<w:rPr>';
    $rpr .= '<w:rFonts w:ascii="Courier New" w:hAnsi="Courier New" w:cs="Courier New"/>' if $opt{mono};
    $rpr .= '<w:b/><w:bCs/>' if $opt{bold};
    $rpr .= qq{<w:sz w:val="$half_points"/><w:szCs w:val="$half_points"/>};
    $rpr .= '</w:rPr>';

    return qq{<w:p><w:r>$rpr<w:t xml:space="preserve">} . _docx_escape($text) . qq{</w:t></w:r></w:p>};
}

sub _docx_table_xml {
    my ($rows) = @_;
    $rows ||= [];
    return '' if !@{$rows};

    my $columns = scalar @{ $rows->[0] || [] } || 1;
    my $xml = '<w:tbl><w:tblPr><w:tblStyle w:val="TableGrid"/><w:tblW w:w="0" w:type="auto"/><w:tblBorders>'
      . join( q{}, map { qq{<w:$_ w:val="single" w:sz="4" w:space="0" w:color="auto"/>} } qw(top left bottom right insideH insideV) )
      . '</w:tblBorders></w:tblPr>'
      . ( '<w:tblGrid>' . ( '<w:gridCol w:w="2000"/>' x $columns ) . '</w:tblGrid>' );

    for my $row_index ( 0 .. $#$rows ) {
        my $row = $rows->[$row_index];
        $xml .= '<w:tr>';
        for my $cell ( @{$row} ) {
            my $plain = Markdown::Enhancer->_plain_inline($cell);
            $xml .= '<w:tc>' . _docx_paragraph_xml( $plain, bold => ( $row_index == 0 ? 1 : 0 ) ) . '</w:tc>';
        }
        $xml .= '</w:tr>';
    }

    $xml .= '</w:tbl>';
    return $xml;
}

sub _docx_document_xml {
    my ($body_xml) = @_;
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      . '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
      . '<w:body>'
      . $body_xml
      . '<w:sectPr><w:pgSz w:w="11906" w:h="16838"/><w:pgMar w:top="1417" w:right="1417" w:bottom="1417" w:left="1417"/></w:sectPr>'
      . '</w:body></w:document>';
}

sub _docx_content_types_xml {
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      . '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
      . '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
      . '<Default Extension="xml" ContentType="application/xml"/>'
      . '<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>'
      . '</Types>';
}

sub _docx_rels_xml {
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      . '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      . '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>'
      . '</Relationships>';
}

sub _docx_escape {
    my ($text) = @_;
    $text = '' if !defined $text;
    $text =~ s/&/&amp;/g;
    $text =~ s/</&lt;/g;
    $text =~ s/>/&gt;/g;
    $text =~ s/"/&quot;/g;
    return $text;
}

sub _ensure_output_dir {
    my ( $self, $path ) = @_;
    my ( undef, $dir ) = fileparse($path);
    return 1 if !defined $dir || $dir eq '' || -d $dir;
    die "Output directory does not exist: $dir\n";
}

sub _soffice_binary {
    my ($self) = @_;
    for my $candidate (
        'soffice',
        'libreoffice',
        '/Applications/LibreOffice.app/Contents/MacOS/soffice',
        'C:\\Program Files\\LibreOffice\\program\\soffice.exe',
        'C:\\Program Files (x86)\\LibreOffice\\program\\soffice.exe',
      )
    {
        my $found = $self->{find_binary}->($candidate);
        return $found if $found;
    }
    return;
}

sub _windows_word_available {
    my ($self) = @_;
    return $self->{find_binary}->('powershell.exe') || $self->{find_binary}->('powershell');
}

sub _macos_word_available {
    my ($self) = @_;
    return 1 if -d '/Applications/Microsoft Word.app';
    return 1 if $ENV{HOME} && -d File::Spec->catdir( $ENV{HOME}, 'Applications', 'Microsoft Word.app' );
    return;
}

sub _libreoffice_convert {
    my ( $self, $from, $to, $format ) = @_;
    my $binary = $self->_soffice_binary || die "LibreOffice or soffice was not found\n";
    my ( undef, $outdir, undef ) = fileparse($to);
    my $abs_from = abs_path($from) || $from;
    my $abs_dir  = abs_path($outdir) || $outdir;

    # soffice always names its output after the SOURCE basename inside
    # --outdir, ignoring whatever target filename was actually requested, and
    # happily overwrites anything already sitting at that path. Converting
    # into a dedicated scratch directory (rather than the real output
    # directory) means that renaming the result into place can never clobber
    # an unrelated pre-existing file that happens to share the source's
    # basename.
    my $scratch_dir = tempdir( CLEANUP => 1 );
    my @cmd = ( $binary, '--headless', '--convert-to', $format, '--outdir', $scratch_dir, $abs_from );
    $self->{run_command}->(@cmd);

    if ( !-f $to ) {
        my ($from_name) = fileparse( $from, qr/\.[^.]*/ );
        my $produced = File::Spec->catfile( $scratch_dir, "$from_name.$format" );
        move( $produced, $to ) if -f $produced;
    }

    die "Converted file was not created: $to\n" if !-f $to;
    return 1;
}

sub _word_windows_convert {
    my ( $self, $from, $to, $target_format ) = @_;
    my $ps = $self->{find_binary}->('powershell.exe') || $self->{find_binary}->('powershell') || 'powershell.exe';
    my $format_value = $target_format eq 'pdf' ? 17 : 16;
    my $script = join "\n",
      '$inputPath = $args[0]',
      '$outputPath = $args[1]',
      '$word = New-Object -ComObject Word.Application',
      '$word.Visible = $false',
      '$word.DisplayAlerts = 0',
      '$doc = $null',
      'try {',
      '  $doc = $word.Documents.Open($inputPath, $false, $true, $false)',
      "  \$doc.SaveAs2(\$outputPath, $format_value)",
      '} finally {',
      '  if ($doc -ne $null) { $doc.Close(0) }',
      '  $word.Quit()',
      '}';
    $self->{run_powershell}->( $ps, $script, $from, $to );
    die "Converted file was not created: $to\n" if !-f $to;
    return 1;
}

sub _word_macos_convert {
    my ( $self, $from, $to, $target_format ) = @_;
    my $script;
    if ( $target_format eq 'pdf' ) {
        $script = <<'APPLESCRIPT';
on run argv
    set inPath to item 1 of argv
    set outPath to item 2 of argv
    tell application id "com.microsoft.Word"
        open POSIX file inPath
        set docRef to active document
        save as docRef file name ((POSIX file outPath) as text) file format format PDF
        close docRef saving no
    end tell
end run
APPLESCRIPT
    }
    else {
        $script = <<'APPLESCRIPT';
on run argv
    set inPath to item 1 of argv
    set outPath to item 2 of argv
    tell application id "com.microsoft.Word"
        open POSIX file inPath
        set docRef to active document
        save as docRef file name ((POSIX file outPath) as text) file format format document default
        close docRef saving no
    end tell
end run
APPLESCRIPT
    }
    $self->{run_osascript}->( $script, $from, $to );
    die "Converted file was not created: $to\n" if !-f $to;
    return 1;
}

sub _find_binary {
    my ($candidate) = @_;
    return $candidate if defined $candidate && File::Spec->file_name_is_absolute($candidate) && -x $candidate;
    return $candidate if defined $candidate && $candidate =~ /^[A-Za-z]:\\/ && -x $candidate;
    if ( defined $candidate && $candidate =~ m{[/\\]} && -x $candidate ) {
        return $candidate;
    }
    return if !defined $candidate || $candidate eq '';
    for my $dir ( split /[:;]/, $ENV{PATH} || '' ) {
        my $path = File::Spec->catfile( $dir, $candidate );
        return $path if -x $path;
    }
    return;
}

sub _run_command {
    my (@cmd) = @_;
    system(@cmd);
    die "Command failed: @cmd\n" if $? != 0;
    return 1;
}

sub _run_osascript {
    my ( $script, @args ) = @_;
    open my $osa, '|-', 'osascript', '-', @args or die "Could not run osascript: $!\n";
    print {$osa} $script;
    close $osa or die "AppleScript conversion failed\n";
    return 1;
}

sub _run_powershell {
    my ( $binary, $script, @args ) = @_;
    system( $binary, '-NoProfile', '-NonInteractive', '-Command', $script, @args );
    die "PowerShell conversion failed\n" if $? != 0;
    return 1;
}

1;
